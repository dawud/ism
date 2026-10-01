"""Check the separately compiled Pulse table archive and runtime selection."""

import argparse
from pathlib import Path
import subprocess
import sys

import check_stream_artifacts as shared

SOURCES = (
    "Makefile", "migration/candidate.mk", "migration/toolchain.lock",
    "migration/check_toolchain.py", "migration/check_stream_artifacts.py",
    "migration/check_table_artifacts.py",
    "src/transport/DNS.QUIC.StreamModel.fst", "src/transport/DNS.QUIC.TableModel.fst",
    "src/transport/DNS.QUIC.TableModel.Tests.fst",
    "migration/DNS.Migration.PulseStream.fst",
    "migration/DNS.Migration.PulseMultiplexer.fst",
    "migration/DNS.Migration.PulseMultiplexer.Tests.fst",
    "migration/c/ism_pulse_stream.h", "migration/c/pulse_phase_decode.h",
    "migration/c/ism_pulse_table.h", "migration/c/ism_pulse_table.c",
    "migration/c/pulse_multiplexer_smoke.c", "migration/c/pulse_table_abi_smoke.c",
)
PRODUCTS = ("DNS_Migration_PulseMultiplexer.c", "DNS_Migration_PulseMultiplexer.h",
            "DNS_Migration_PulseMultiplexer.o", "ism_pulse_table.o", "libism_pulse_table.a")
MANIFEST = "table-manifest.json"


def check_archive(directory):
    archive = directory / "libism_pulse_table.a"
    members = subprocess.check_output(["ar", "t", str(archive)], text=True).splitlines()
    if sorted(members) != ["DNS_Migration_PulseMultiplexer.o", "ism_pulse_table.o"]:
        raise ValueError("Unexpected Pulse table archive members")
    allowed = {"DNS_Migration_PulseMultiplexer_" + name
               for name in ("find_stream", "allocate_stream", "close_stream")}
    allowed |= {"memcpy", "memmove", "memset", "__stack_chk_fail"}
    unexpected = shared.undefined_symbols(archive) - allowed
    if unexpected:
        raise ValueError("Unexpected Pulse table runtime dependencies: " + str(sorted(unexpected)))


def check_selection(shell_symbols, adapter_symbols):
    required = {"ism_pulse_table_find", "ism_pulse_table_open", "ism_pulse_table_close"}
    forbidden = {"DNS_ShellResponseBoundary_complete_response_send_for_stream",
                 "DNS_ShellBoundary_dispatch_response_send_finished_via_scheduler",
                 "DNS_ShellBoundary_dispatch_stream_reset_via_scheduler"}
    forbidden |= {s for s in shell_symbols if s.startswith("DNS_QUIC_Multiplexer_")}
    if not required <= shell_symbols or forbidden & shell_symbols:
        raise ValueError("Shell is not selecting Pulse table lifecycle")
    if not {"ism_pulse_table_apply", "ism_pulse_table_abi_version"} <= adapter_symbols:
        raise ValueError("Table adapter is not selecting the candidate ABI")


def options():
    return dict(sources=SOURCES, products=PRODUCTS, manifest=MANIFEST, archive_check=check_archive)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("record", "check", "selection"))
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--object", type=Path)
    parser.add_argument("--adapter", type=Path)
    parser.add_argument("--cc", default="cc")
    args = parser.parse_args()
    try:
        if args.mode == "selection":
            if args.object is None or args.adapter is None:
                raise ValueError("--object and --adapter are required")
            check_selection(shared.undefined_symbols(args.object), shared.undefined_symbols(args.adapter))
            print("Pulse table selected for shell find/open/reset/completion")
        else:
            if args.directory is None:
                raise ValueError("--directory is required")
            target = shared.target(args.cc)
            if args.mode == "record":
                shared.record(args.root, args.directory, target, **options())
            shared.validate(args.root, args.directory, target, **options())
            print("Pulse table C artifact handoff checked: " + str(args.directory / MANIFEST))
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print("Pulse table handoff failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
