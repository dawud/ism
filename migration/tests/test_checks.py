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
        for folder in ("src", "spec", "docs"):
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


if __name__ == "__main__":
    unittest.main()
