"""Check the Pulse response archive and actual shell framing selection."""

import argparse
from pathlib import Path
import subprocess
import sys

import check_stream_artifacts as shared

SOURCES = (
    "Makefile", "migration/candidate.mk", "migration/toolchain.lock",
    "migration/check_toolchain.py", "migration/check_stream_artifacts.py",
    "migration/check_response_artifacts.py",
    "src/transport/DNS.QUIC.StreamModel.fst", "migration/DNS.Migration.PulseStream.fst",
    "src/transport/DNS.QUIC.ResponseModel.fst", "src/transport/DNS.QUIC.ResponseModel.Tests.fst",
    "migration/DNS.Migration.PulseResponse.fst", "migration/DNS.Migration.PulseResponse.Tests.fst",
    "migration/c/ism_pulse_response.h", "migration/c/ism_pulse_response.c",
    "migration/c/pulse_response_ranges.h", "migration/c/pulse_response_smoke.c",
)
PRODUCTS = ("DNS_Migration_PulseResponse.c", "DNS_Migration_PulseResponse.h",
            "DNS_Migration_PulseResponse.o", "ism_pulse_response.o", "libism_pulse_response.a")
MANIFEST = "response-manifest.json"


def check_archive(directory):
    archive = directory / "libism_pulse_response.a"
    members = subprocess.check_output(["ar", "t", str(archive)], text=True).splitlines()
    if sorted(members) != ["DNS_Migration_PulseResponse.o", "ism_pulse_response.o"]:
        raise ValueError("Unexpected Pulse response archive members")
    allowed = {"DNS_Migration_PulseResponse_frame_response",
               "memcpy", "memmove", "memset", "__stack_chk_fail"}
    unexpected = shared.undefined_symbols(archive) - allowed
    if unexpected:
        raise ValueError("Unexpected Pulse response runtime dependencies: " + str(sorted(unexpected)))


def check_selection(shell_symbols, adapter_symbols):
    forbidden = {"DNS_ShellResponseBoundary_prepare_doq_response_send_for_stream",
                 "DNS_ShellResponseBoundary_copy_response_bytes_with_prefix"}
    if "ism_pulse_prepare_doq_response" not in shell_symbols or forbidden & shell_symbols:
        raise ValueError("Shell is not selecting Pulse response framing")
    required = {"ism_pulse_response_frame", "ism_pulse_response_abi_version",
                "DNS_ShellResponseBoundary_prepare_response_send_for_stream"}
    if not required <= adapter_symbols or forbidden & adapter_symbols:
        raise ValueError("Response adapter is not selecting the candidate ABI and stable descriptor handoff")


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
            print("Pulse selected for shell response framing; stable descriptor handoff retained")
        else:
            if args.directory is None:
                raise ValueError("--directory is required")
            target = shared.target(args.cc)
            if args.mode == "record":
                shared.record(args.root, args.directory, target, **options())
            shared.validate(args.root, args.directory, target, **options())
            print("Pulse response C artifact handoff checked: " + str(args.directory / MANIFEST))
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print("Pulse response handoff failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
