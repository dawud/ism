import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from check_inventory import inventory, without_comments
from check_toolchain import check, read_lock
from check_stream_artifacts import SOURCES, PRODUCTS, digest, validate, check_selection, check_archive
import check_table_artifacts as table_checks
import check_response_artifacts as response_checks


ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "migration/toolchain.lock"


class ToolchainTests(unittest.TestCase):
    def setUp(self):
        self.lock = read_lock(LOCK)
        self.commands = {
            ("/candidate/bin/fstar.exe", "--version"):
                "F* " + self.lock["FSTAR_VERSION"][1:] + "\ncommit=" + self.lock["FSTAR_COMMIT"],
            ("/candidate/bin/krml", "-version"): "KaRaMeL version: " + self.lock["KARAMEL_COMMIT"],
            ("cc", "--version"): "test C compiler",
            ("cc", "-dumpmachine"): "test-target",
        }
        for version in self.lock["Z3_BUNDLED_VERSIONS"].split(","):
            self.commands[(f"/candidate/lib/fstar/z3-{version}/bin/z3", "--version")] = (
                "Z3 version " + version + " - 64 bit")

    def run_check(self):
        with patch("check_toolchain.output", side_effect=lambda *args: self.commands[args]):
            return check(Path("/candidate"), "cc", LOCK)

    def test_correct_bundle_records_separate_generator(self):
        report = self.run_check()
        self.assertEqual(report["selected_solver"], self.lock["Z3_VERSION"])
        self.assertEqual(report["c_target"], "test-target")
        self.assertIn("separate pinned baseline", report["everparse"])

    def test_wrong_compiler_release_fails(self):
        self.commands[("/candidate/bin/fstar.exe", "--version")] = "F* 2026.03.24\ncommit=old"
        with self.assertRaisesRegex(ValueError, "release"):
            self.run_check()

    def test_wrong_compiler_commit_fails(self):
        self.commands[("/candidate/bin/fstar.exe", "--version")] = (
            "F* " + self.lock["FSTAR_VERSION"][1:] + "\ncommit=wrong")
        with self.assertRaisesRegex(ValueError, "commit"):
            self.run_check()

    def test_wrong_karamel_fails(self):
        self.commands[("/candidate/bin/krml", "-version")] = "KaRaMeL version: wrong"
        with self.assertRaisesRegex(ValueError, "KaRaMeL"):
            self.run_check()

    def test_wrong_solver_fails(self):
        self.commands[("/candidate/lib/fstar/z3-4.13.3/bin/z3", "--version")] = "Z3 version 4.8.5"
        with self.assertRaisesRegex(ValueError, "solver"):
            self.run_check()


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ism-inventory-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ("src", "spec", "migration", "docs"):
            (self.root / folder).mkdir()
        (self.root / "src/A.fst").write_text("module A\nopen LowStar.Buffer\nlet x = 0\n")
        (self.root / "src/B.fst").write_text("module B\nopen A\nlet y = A.x\n")
        self.document = self.root / "docs/PULSE_MIGRATION_INVENTORY.md"
        self.rows = ("| `src/A.fst` | verify+extract | buffers | M4 port |\n"
                     "| `src/B.fst` | verify | model | reuse |\n")
        self.document.write_text(self.rows)

    def run_check(self):
        return inventory(self.root, ["src/A.fst", "src/B.fst"], ["src/A.fst"])["modules"]

    def test_transitive_dependencies_and_callers(self):
        report = self.run_check()
        self.assertEqual(report["src/A.fst"]["local_callers"], ["src/B.fst"])
        self.assertEqual(report["src/B.fst"]["direct_legacy_dependencies"], [])
        self.assertEqual(report["src/B.fst"]["transitive_legacy_dependencies"], ["LowStar.Buffer"])

    def test_undocumented_source_fails(self):
        (self.root / "src/New.fst").write_text("module New\nopen FStar.HyperStack.ST\n")
        with self.assertRaisesRegex(ValueError, "missing=.*src/New.fst"):
            self.run_check()

    def test_stale_entry_fails(self):
        self.document.write_text(self.rows + "| `spec/Gone.fsti` | verify | old | retire |\n")
        with self.assertRaisesRegex(ValueError, "stale=.*spec/Gone.fsti"):
            self.run_check()

    def test_duplicate_fails(self):
        self.document.write_text(self.rows + self.rows)
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            self.run_check()

    def test_extraction_coverage_drift_fails(self):
        with self.assertRaisesRegex(ValueError, "coverage drift"):
            inventory(self.root, ["src/A.fst", "src/B.fst"], ["src/A.fst", "src/B.fst"])

    def test_removed_verification_root_fails(self):
        with self.assertRaisesRegex(ValueError, "coverage drift"):
            inventory(self.root, ["src/A.fst"], ["src/A.fst"])

    def test_comments_do_not_create_dependencies(self):
        self.assertNotIn("Steel", without_comments("(* Steel (* nested *) *)\n// Steel\nlet x = 0"))

    def test_candidate_source_must_be_documented(self):
        (self.root / "migration/Pulse.fst").write_text("module Pulse\nopen A\n")
        with self.assertRaisesRegex(ValueError, "missing=.*migration/Pulse.fst"):
            self.run_check()

    def test_candidate_source_must_be_verified(self):
        (self.root / "migration/Pulse.fst").write_text("module Pulse\nopen A\n")
        self.document.write_text(self.rows +
            "| `migration/Pulse.fst` | candidate-verify | ownership | M2 port |\n")
        with self.assertRaisesRegex(ValueError, "coverage drift"):
            self.run_check()
        report = inventory(self.root, ["src/A.fst", "src/B.fst"], ["src/A.fst"],
                           ["src/B.fst", "migration/Pulse.fst"])["modules"]
        self.assertTrue(report["migration/Pulse.fst"]["candidate_verified"])
        self.assertTrue(report["src/B.fst"]["candidate_verified"])
        self.assertFalse(report["src/A.fst"]["candidate_verified"])
        self.assertIn("migration/Pulse.fst", report["src/A.fst"]["local_callers"])

    def test_nonexistent_candidate_root_fails(self):
        with self.assertRaisesRegex(ValueError, "inconsistent"):
            inventory(self.root, ["src/A.fst", "src/B.fst"], ["src/A.fst"],
                      ["migration/Missing.fst"])

    def test_candidate_extraction_requires_verification(self):
        with self.assertRaisesRegex(ValueError, "inconsistent"):
            inventory(self.root, ["src/A.fst", "src/B.fst"], ["src/A.fst"],
                      [], ["src/B.fst"])

    def test_candidate_extraction_coverage_is_recorded(self):
        report = inventory(self.root, ["src/A.fst", "src/B.fst"], ["src/A.fst"],
                           ["src/B.fst"], ["src/B.fst"])["modules"]
        self.assertTrue(report["src/B.fst"]["candidate_extracted"])


class MakeTests(unittest.TestCase):
    def dry_run(self, target, *args):
        return subprocess.check_output(["make", "-n", target, *args], cwd=ROOT, text=True)

    def test_candidate_artifacts_are_isolated_and_no_rust(self):
        commands = self.dry_run("candidate-check", "FSTAR_HOME=/candidate")
        self.assertIn("obj/candidate-v2026.09.13/pulse-pilot", commands)
        self.assertIn("dist/candidate-v2026.09.13/pulse-c", commands)
        self.assertNotIn("rustc", commands)
        self.assertNotIn("--odir obj/pulse-pilot", commands)
        self.assertIn("-fstar /candidate/bin/fstar.exe", commands)
        self.assertIn("--smt /candidate/lib/fstar/z3-4.13.3/bin/z3", commands)
        self.assertIn("-fsopt --cache_dir -fsopt dist/candidate-v2026.09.13/pulse-c/checked", commands)

    def test_exploration_artifacts_are_isolated(self):
        commands = self.dry_run("verify", "BUILD_LANE=exploration-test", "FSTAR_HOME=/other")
        self.assertIn("--cache_dir obj/exploration-test", commands)
        self.assertIn("for f in", commands)
        self.assertIn("$f || exit $?", commands)

    def test_real_stream_proofs_and_checked_extraction_are_required(self):
        commands = self.dry_run("candidate-check", "FSTAR_HOME=/candidate")
        loop = next(line for line in commands.splitlines()
                    if line.startswith("for f in src/transport/DNS.QUIC.StreamModel.fst"))
        for name in ("src/transport/DNS.QUIC.StreamModel.Tests.fst",
                     "migration/DNS.Migration.PulseStream.fst",
                     "migration/DNS.Migration.PulseStream.Tests.fst"):
            self.assertIn(name, loop)
        self.assertIn("--cache_dir obj/candidate-v2026.09.13/stream", commands)
        extraction = self.dry_run("candidate-stream-extract", "FSTAR_HOME=/candidate")
        self.assertIn("--codegen krml --extract 'DNS.QUIC.StreamModel DNS.Migration.PulseStream Pulse.Lib.Pervasives'", extraction)
        self.assertNotIn("--no_cmi", extraction)
        self.assertNotIn("--lax", extraction)
        self.assertIn("-warn-error @2@4@15", extraction)
        self.assertIn("pulse-stream/out.krml", extraction)
        self.assertIn("pulse-stream/libism_pulse_stream.a", commands)
        self.assertIn("check_stream_artifacts.py record", commands)

    def test_mixed_gate_selects_pulse_without_mixing_extraction_inputs(self):
        commands = self.dry_run("pulse-integration-check")
        self.assertIn("check_stream_artifacts.py check", commands)
        self.assertIn("check_stream_artifacts.py selection", commands)
        self.assertIn("-DISM_USE_PULSE_STREAM=1", commands)
        self.assertIn("SMOKE_DIR=dist/pulse-integration-v2026.09.13", commands)
        self.assertIn("SHELL_IMPL_SOURCE=obj/pulse-integration-v2026.09.13/ism_shell.o", commands)
        self.assertIn("msquic-runtime-stream-smoke", commands)
        self.assertIn("pulse_stream_differential.c", commands)
        self.assertNotIn("DNS_Migration_PulseStream.c", commands)
        self.assertNotIn("candidate-stream-extract", commands)

    def test_table_proofs_and_standalone_c_are_required(self):
        commands = self.dry_run("candidate-check", "FSTAR_HOME=/candidate")
        loop = next(line for line in commands.splitlines()
                    if line.startswith("for f in src/transport/DNS.QUIC.TableModel.fst"))
        for name in ("src/transport/DNS.QUIC.TableModel.Tests.fst",
                     "migration/DNS.Migration.PulseMultiplexer.fst",
                     "migration/DNS.Migration.PulseMultiplexer.Tests.fst"):
            self.assertIn(name, loop)
        self.assertIn("--cache_dir obj/candidate-v2026.09.13/multiplexer", commands)
        extraction = self.dry_run("candidate-multiplexer-extract", "FSTAR_HOME=/candidate")
        self.assertNotIn("--no_cmi", extraction)
        self.assertNotIn("--lax", extraction)
        self.assertIn("--warn_error +250", extraction)
        self.assertIn("-warn-error @2@4@15", extraction)
        self.assertIn("pulse-multiplexer/out.krml", extraction)
        self.assertIn("migration/c/pulse_multiplexer_smoke.c", commands)
        self.assertNotIn("DNS_Migration_PulseMultiplexer", self.dry_run("pulse-integration-check"))

    def test_table_model_regressions_stay_verification_only(self):
        commands = self.dry_run("migration-inventory-check")
        verified = commands.split("--verified ", 1)[1].split("--extracted", 1)[0]
        extracted = commands.split("--extracted ", 1)[1].split("--candidate", 1)[0]
        self.assertIn("src/transport/DNS.QUIC.TableModel.Tests.fst", verified)
        self.assertNotIn("src/transport/DNS.QUIC.TableModel.Tests.fst", extracted)
        self.assertIn("src/transport/DNS.QUIC.TableModel.fst", extracted)

    def test_table_abi_and_integrated_selection_are_required(self):
        candidate = self.dry_run("candidate-check", "FSTAR_HOME=/candidate")
        self.assertIn("pulse_table_abi_smoke.c", candidate)
        self.assertIn("check_table_artifacts.py record", candidate)
        commands = self.dry_run("pulse-table-integration-check")
        for expected in ("check_table_artifacts.py check", "check_table_artifacts.py selection",
                         "-DISM_USE_PULSE_TABLE=1", "shell/pulse_table_adapter.c",
                         "pulse_table_differential.c", "legacy_shell_oracle.c",
                         "libism_pulse_table.a", "msquic-runtime-stream-smoke",
                         "SMOKE_DIR=dist/pulse-table-integration-v2026.09.13"):
            self.assertIn(expected, commands)
        self.assertNotIn("DNS_Migration_PulseMultiplexer.c", commands)
        self.assertNotIn("candidate-multiplexer-extract", commands)
        self.assertNotIn("-DISM_USE_PULSE_TABLE=1", self.dry_run("pulse-integration-check"))

    def test_response_proofs_are_required_and_focused_gate_remains_proof_only(self):
        commands = self.dry_run("candidate-check", "FSTAR_HOME=/candidate")
        loop = next(line for line in commands.splitlines()
                    if line.startswith("for f in src/transport/DNS.QUIC.ResponseModel.fst"))
        for name in ("src/transport/DNS.QUIC.ResponseModel.Tests.fst",
                     "migration/DNS.Migration.PulseResponse.fst",
                     "migration/DNS.Migration.PulseResponse.Tests.fst"):
            self.assertIn(name, loop)
        proofs = self.dry_run("candidate-response-verify", "FSTAR_HOME=/candidate")
        self.assertIn("--cache_dir obj/candidate-v2026.09.13/response", proofs)
        self.assertIn("--include obj/candidate-v2026.09.13/stream", proofs)
        self.assertNotIn("--codegen", proofs)
        self.assertNotIn("--lax", proofs)
        self.assertNotIn("rustc", proofs)

    def test_response_inventory_distinguishes_stable_and_candidate_extraction(self):
        commands = self.dry_run("migration-inventory-check")
        verified = commands.split("--verified ", 1)[1].split("--extracted", 1)[0]
        extracted = commands.split("--extracted ", 1)[1].split("--candidate", 1)[0]
        candidate = commands.split("--candidate ", 1)[1].split("--candidate-extracted", 1)[0]
        candidate_extracted = commands.split("--candidate-extracted ", 1)[1]
        self.assertIn("src/transport/DNS.QUIC.ResponseModel.Tests.fst", verified)
        self.assertNotIn("src/transport/DNS.QUIC.ResponseModel.Tests.fst", extracted)
        self.assertIn("src/transport/DNS.QUIC.ResponseModel.fst", extracted)
        for name in ("src/transport/DNS.QUIC.ResponseModel.fst",
                     "src/transport/DNS.QUIC.ResponseModel.Tests.fst",
                     "migration/DNS.Migration.PulseResponse.fst",
                     "migration/DNS.Migration.PulseResponse.Tests.fst"):
            self.assertIn(name, candidate)
            if name.endswith(".Tests.fst"):
                self.assertNotIn(name, candidate_extracted)
            else:
                self.assertIn(name, candidate_extracted)

    def test_response_checked_extraction_and_abi_smoke_are_required(self):
        commands = self.dry_run("candidate-check", "FSTAR_HOME=/candidate")
        for expected in ("pulse_response_smoke.c", "check_response_artifacts.py record",
                         "pulse-response/libism_pulse_response.a"):
            self.assertIn(expected, commands)
        extraction = self.dry_run("candidate-response-extract", "FSTAR_HOME=/candidate")
        for expected in ("--warn_error +250", "-warn-error @2@4@15", "--codegen krml",
                         "pulse-response/out.krml"):
            self.assertIn(expected, extraction)
        self.assertNotIn("--lax", extraction)
        self.assertNotIn("--no_cmi", extraction)

    def test_response_mixed_gate_preserves_separate_older_lanes(self):
        commands = self.dry_run("pulse-response-integration-check")
        for expected in ("-DISM_USE_PULSE_STREAM=1", "-DISM_USE_PULSE_TABLE=1",
                         "-DISM_USE_PULSE_RESPONSE=1", "shell/pulse_response_adapter.c",
                         "check_response_artifacts.py check", "check_response_artifacts.py selection",
                         "pulse_response_differential.c", "legacy_shell_oracle.c",
                         "pulse_response_handoff_smoke.c", "response-handoff-smoke",
                         "libism_pulse_response.a", "msquic-runtime-stream-smoke",
                         "SHELL_IMPL_SOURCE=obj/pulse-response-integration-v2026.09.13/ism_shell.o"):
            self.assertIn(expected, commands)
        self.assertNotIn("DNS_Migration_PulseResponse.c", commands)
        self.assertNotIn("candidate-response-extract", commands)
        for target in ("pulse-integration-check", "pulse-table-integration-check"):
            self.assertNotIn("-DISM_USE_PULSE_RESPONSE=1", self.dry_run(target))

    def test_stream_regressions_remain_in_stable_verify_not_extraction(self):
        commands = self.dry_run("migration-inventory-check")
        verified = commands.split("--verified ", 1)[1].split("--extracted", 1)[0]
        extracted = commands.split("--extracted ", 1)[1].split("--candidate", 1)[0]
        self.assertIn("src/transport/DNS.QUIC.StreamModel.Tests.fst", verified)
        self.assertNotIn("src/transport/DNS.QUIC.StreamModel.Tests.fst", extracted)
        self.assertIn("src/transport/DNS.QUIC.StreamModel.fst", extracted)

    def test_verify_uses_single_roots_and_stops_at_first_failure(self):
        with tempfile.TemporaryDirectory(prefix="ism-verify-driver-test-") as directory:
            root = Path(directory)
            (root / "bin").mkdir()
            compiler = root / "bin/fstar.exe"
            compiler.write_text('#!/bin/sh\n[ "$#" -eq 1 ] || exit 99\n'
                                'printf "%s\\n" "$1" >> "$ISM_TEST_CALLS"\n'
                                '[ "$1" != fail.fst ] || exit 19\n')
            compiler.chmod(0o755)
            calls = root / "calls"
            result = subprocess.run(
                ["make", "verify", f"FSTAR_HOME={root}", f"OBJ_DIR={root}/obj",
                 "FSTAR_OPTS=", "ALL_FST_FILES=ok.fst fail.fst never.fst"],
                cwd=ROOT, env=dict(os.environ, ISM_TEST_CALLS=str(calls)),
                text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(calls.read_text().splitlines(), ["ok.fst", "fail.fst"])


class HandoffTests(unittest.TestCase):
    def setUp(self):
        import json
        self.temp = tempfile.TemporaryDirectory(prefix="ism-pulse-handoff-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "output"
        self.output.mkdir()
        for name in SOURCES:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("test source")
        (self.root / "migration/toolchain.lock").write_text(LOCK.read_text())
        for name in PRODUCTS:
            (self.output / name).write_text("test product")
        self.report = dict(abi=1, c_target="test-target", lock=read_lock(LOCK),
                           sources={name: digest(self.root / name) for name in SOURCES},
                           products={name: digest(self.output / name) for name in PRODUCTS})
        self.manifest = self.output / "stream-manifest.json"
        self.manifest.write_text(json.dumps(self.report))

    def run_check(self, target="test-target"):
        with patch("check_stream_artifacts.check_archive"):
            return validate(self.root, self.output, target)

    def test_matching_manifest_passes(self):
        self.assertEqual(self.run_check()["abi"], 1)

    def test_changed_source_fails(self):
        (self.root / SOURCES[0]).write_text("changed")
        with self.assertRaisesRegex(ValueError, "Stale or changed"):
            self.run_check()

    def test_changed_archive_fails(self):
        (self.output / "libism_pulse_stream.a").write_text("stale archive")
        with self.assertRaisesRegex(ValueError, "Stale or changed"):
            self.run_check()

    def test_wrong_target_fails(self):
        with self.assertRaisesRegex(ValueError, "target mismatch"):
            self.run_check("foreign-target")

    def test_wrong_abi_fails(self):
        import json
        self.report["abi"] = 2
        self.manifest.write_text(json.dumps(self.report))
        with self.assertRaisesRegex(ValueError, "ABI version"):
            self.run_check()

    def test_wrong_lock_fails(self):
        import json
        self.report["lock"]["FSTAR_COMMIT"] = "wrong"
        self.manifest.write_text(json.dumps(self.report))
        with self.assertRaisesRegex(ValueError, "lock mismatch"):
            self.run_check()

    def test_missing_manifest_entry_fails(self):
        import json
        del self.report["products"][PRODUCTS[0]]
        self.manifest.write_text(json.dumps(self.report))
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            self.run_check()

    def test_missing_pulse_fin_or_legacy_ingress_fails(self):
        with self.assertRaisesRegex(ValueError, "selecting Pulse"):
            check_selection({"ism_pulse_ingress_data"})
        with self.assertRaisesRegex(ValueError, "selecting Pulse"):
            check_selection({"ism_pulse_ingress_data", "ism_pulse_ingress_fin",
                             "DNS_ShellBoundary_dispatch_authenticated_stream_data_via_scheduler"})

    def test_all_pulse_entry_points_pass(self):
        check_selection({"ism_pulse_ingress_data", "ism_pulse_ingress_fin", "memset"})

    def test_unexpected_archive_member_fails(self):
        with patch("check_stream_artifacts.subprocess.check_output", return_value="mock_runtime.o\n"):
            with self.assertRaisesRegex(ValueError, "archive members"):
                check_archive(self.output)

    def test_missing_runtime_implementation_fails(self):
        members = "DNS_Migration_PulseStream.o\nism_pulse_stream.o\n"
        with patch("check_stream_artifacts.subprocess.check_output", return_value=members), \
                patch("check_stream_artifacts.undefined_symbols", return_value={"Pulse_Lib_Reference_op_Bang"}):
            with self.assertRaisesRegex(ValueError, "runtime dependencies"):
                check_archive(self.output)


class TableHandoffTests(unittest.TestCase):
    def setUp(self):
        import json
        self.temp = tempfile.TemporaryDirectory(prefix="ism-table-handoff-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "output"
        self.output.mkdir()
        for name in table_checks.SOURCES:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("test source")
        (self.root / "migration/toolchain.lock").write_text(LOCK.read_text())
        for name in table_checks.PRODUCTS:
            (self.output / name).write_text("test product")
        self.report = dict(abi=1, c_target="test-target", lock=read_lock(LOCK),
            sources={name: digest(self.root / name) for name in table_checks.SOURCES},
            products={name: digest(self.output / name) for name in table_checks.PRODUCTS})
        self.manifest = self.output / table_checks.MANIFEST
        self.manifest.write_text(json.dumps(self.report))

    def run_check(self, target="test-target"):
        with patch("check_table_artifacts.check_archive"):
            return validate(self.root, self.output, target, **table_checks.options())

    def test_matching_table_manifest_passes(self):
        self.assertEqual(self.run_check()["abi"], 1)

    def test_changed_table_abi_source_or_archive_fails(self):
        for path in (self.root / "migration/c/ism_pulse_table.h",
                     self.output / "libism_pulse_table.a"):
            with self.subTest(path=path):
                before = path.read_text()
                path.write_text("changed")
                with self.assertRaisesRegex(ValueError, "Stale or changed"):
                    self.run_check()
                path.write_text(before)

    def test_wrong_table_target_or_missing_product_fails(self):
        import json
        with self.assertRaisesRegex(ValueError, "target mismatch"):
            self.run_check("foreign-target")
        del self.report["products"][table_checks.PRODUCTS[0]]
        self.manifest.write_text(json.dumps(self.report))
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            self.run_check()

    def test_table_selection_rejects_missing_pulse_or_legacy_cleanup(self):
        shell = {"ism_pulse_table_find", "ism_pulse_table_open", "ism_pulse_table_close"}
        adapter = {"ism_pulse_table_apply", "ism_pulse_table_abi_version"}
        table_checks.check_selection(shell, adapter)
        for name in shell:
            with self.assertRaisesRegex(ValueError, "selecting Pulse"):
                table_checks.check_selection(shell - {name}, adapter)
        for name in ("DNS_ShellBoundary_dispatch_stream_reset_via_scheduler",
                     "DNS_ShellBoundary_dispatch_response_send_finished_via_scheduler",
                     "DNS_ShellResponseBoundary_complete_response_send_for_stream",
                     "DNS_QUIC_Multiplexer_close_stream"):
            with self.assertRaisesRegex(ValueError, "selecting Pulse"):
                table_checks.check_selection(shell | {name}, adapter)
        with self.assertRaisesRegex(ValueError, "candidate ABI"):
            table_checks.check_selection(shell, set())

    def test_table_archive_rejects_extra_members_and_runtime_shims(self):
        with patch("check_table_artifacts.subprocess.check_output", return_value="mock_runtime.o\n"):
            with self.assertRaisesRegex(ValueError, "archive members"):
                table_checks.check_archive(self.output)
        members = "DNS_Migration_PulseMultiplexer.o\nism_pulse_table.o\n"
        with patch("check_table_artifacts.subprocess.check_output", return_value=members), \
             patch("check_stream_artifacts.undefined_symbols", return_value={"Pulse_Lib_Reference_op_Bang"}):
            with self.assertRaisesRegex(ValueError, "runtime dependencies"):
                table_checks.check_archive(self.output)


class ResponseHandoffTests(unittest.TestCase):
    def setUp(self):
        import json
        self.temp = tempfile.TemporaryDirectory(prefix="ism-response-handoff-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "output"
        self.output.mkdir()
        for name in response_checks.SOURCES:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("test source")
        (self.root / "migration/toolchain.lock").write_text(LOCK.read_text())
        for name in response_checks.PRODUCTS:
            (self.output / name).write_text("test product")
        self.report = dict(abi=1, c_target="test-target", lock=read_lock(LOCK),
            sources={name: digest(self.root / name) for name in response_checks.SOURCES},
            products={name: digest(self.output / name) for name in response_checks.PRODUCTS})
        self.manifest = self.output / response_checks.MANIFEST
        self.manifest.write_text(json.dumps(self.report))

    def run_check(self, target="test-target"):
        with patch("check_response_artifacts.check_archive"):
            return validate(self.root, self.output, target, **response_checks.options())

    def test_matching_response_manifest_passes(self):
        self.assertEqual(self.run_check()["abi"], 1)

    def test_changed_response_sources_or_archive_fail(self):
        for path in (self.root / "migration/c/ism_pulse_response.h",
                     self.root / "migration/c/pulse_response_ranges.h",
                     self.root / "migration/DNS.Migration.PulseResponse.fst",
                     self.output / "libism_pulse_response.a"):
            with self.subTest(path=path):
                before = path.read_text()
                path.write_text("changed")
                with self.assertRaisesRegex(ValueError, "Stale or changed"):
                    self.run_check()
                path.write_text(before)

    def test_wrong_target_abi_lock_or_missing_product_fails(self):
        import copy
        import json
        with self.assertRaisesRegex(ValueError, "target mismatch"):
            self.run_check("foreign-target")
        for change, message in (("abi", "ABI version"), ("lock", "lock mismatch"),
                                ("products", "Incomplete")):
            report = copy.deepcopy(self.report)
            if change == "abi":
                report["abi"] = 2
            elif change == "lock":
                report["lock"]["FSTAR_COMMIT"] = "wrong"
            else:
                del report["products"][response_checks.PRODUCTS[0]]
            self.manifest.write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, message):
                self.run_check()

    def test_selection_requires_pulse_and_preserved_descriptor_handoff(self):
        shell = {"ism_pulse_prepare_doq_response"}
        adapter = {"ism_pulse_response_frame", "ism_pulse_response_abi_version",
                   "DNS_ShellResponseBoundary_prepare_response_send_for_stream"}
        response_checks.check_selection(shell, adapter)
        with self.assertRaisesRegex(ValueError, "selecting Pulse"):
            response_checks.check_selection(set(), adapter)
        for name in adapter:
            with self.assertRaisesRegex(ValueError, "candidate ABI"):
                response_checks.check_selection(shell, adapter - {name})
        for name in ("DNS_ShellResponseBoundary_prepare_doq_response_send_for_stream",
                     "DNS_ShellResponseBoundary_copy_response_bytes_with_prefix"):
            with self.assertRaisesRegex(ValueError, "selecting Pulse"):
                response_checks.check_selection(shell | {name}, adapter)
            with self.assertRaisesRegex(ValueError, "candidate ABI"):
                response_checks.check_selection(shell, adapter | {name})

    def test_archive_rejects_extra_members_and_runtime_shims(self):
        with patch("check_response_artifacts.subprocess.check_output", return_value="mock_runtime.o\n"):
            with self.assertRaisesRegex(ValueError, "archive members"):
                response_checks.check_archive(self.output)
        members = "DNS_Migration_PulseResponse.o\nism_pulse_response.o\n"
        with patch("check_response_artifacts.subprocess.check_output", return_value=members), \
             patch("check_stream_artifacts.undefined_symbols", return_value={"Pulse_Lib_Array_op_Array_Access"}):
            with self.assertRaisesRegex(ValueError, "runtime dependencies"):
                response_checks.check_archive(self.output)


if __name__ == "__main__":
    unittest.main()
