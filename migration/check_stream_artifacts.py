"""Validate the same-checkout, separately compiled Pulse C handoff.

Hashes detect accidental stale/mixed artifacts, not malicious provenance.
The proof/extraction/build tools and this manifest generator remain trusted.
"""

import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import sys

from check_toolchain import read_lock


SOURCES = (
    "Makefile",
    "src/transport/DNS.QUIC.StreamModel.fst",
    "src/transport/DNS.QUIC.StreamModel.Tests.fst",
    "migration/DNS.Migration.PulseStream.fst",
    "migration/DNS.Migration.PulseStream.Tests.fst",
    "migration/c/ism_pulse_stream.h",
    "migration/c/ism_pulse_stream.c",
    "migration/c/pulse_phase_decode.h",
    "migration/c/pulse_stream_smoke.c",
    "migration/candidate.mk",
    "migration/check_stream_artifacts.py",
    "migration/check_toolchain.py",
    "migration/toolchain.lock",
)
PRODUCTS = (
    "DNS_Migration_PulseStream.c", "DNS_Migration_PulseStream.h",
    "DNS_Migration_PulseStream.o", "ism_pulse_stream.o", "libism_pulse_stream.a",
)
MANIFEST = "stream-manifest.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def undefined_symbols(path):
    output = subprocess.check_output(["nm", "-u", str(path)], text=True)
    return {line.split()[-1] for line in output.splitlines()
            if len(line.split()) == 2 and line.split()[0] in ("U", "w", "v")}


def check_selection(symbols):
    required = {"ism_pulse_ingress_data", "ism_pulse_ingress_fin"}
    forbidden = {name for name in symbols
                 if name.startswith("DNS_ShellBoundary_dispatch_authenticated_stream_")}
    if not required <= symbols or forbidden:
        raise ValueError("Shell is not selecting Pulse for all data/FIN entry points")


def check_archive(directory):
    archive = directory / "libism_pulse_stream.a"
    members = subprocess.check_output(["ar", "t", str(archive)], text=True).splitlines()
    if sorted(members) != ["DNS_Migration_PulseStream.o", "ism_pulse_stream.o"]:
        raise ValueError("Unexpected Pulse archive members")
    allowed = {"DNS_Migration_PulseStream_handle_stream_data",
               "DNS_Migration_PulseStream_handle_stream_fin",
               "memcpy", "memmove", "memset", "__stack_chk_fail"}
    unexpected = undefined_symbols(archive) - allowed
    if unexpected:
        raise ValueError("Unexpected Pulse runtime dependencies: " + str(sorted(unexpected)))


def target(cc):
    return subprocess.check_output([*shlex.split(cc), "-dumpmachine"], text=True).strip()


def validate(root, directory, cc_target, *, sources=SOURCES, products=PRODUCTS,
             manifest=MANIFEST, archive_check=None):
    report = json.loads((directory / manifest).read_text())
    if report.get("abi") != 1 or report.get("c_target") != cc_target:
        raise ValueError("Pulse ABI version or C target mismatch")
    if report.get("lock") != read_lock(root / "migration/toolchain.lock"):
        raise ValueError("Pulse toolchain lock mismatch")
    for key, base, names in (("sources", root, sources), ("products", directory, products)):
        if set(report.get(key, {})) != set(names):
            raise ValueError("Incomplete Pulse manifest " + key)
        for name in names:
            if report[key][name] != digest(base / name):
                raise ValueError("Stale or changed Pulse artifact: " + name)
    (archive_check or check_archive)(directory)
    return report


def record(root, directory, cc_target, *, sources=SOURCES, products=PRODUCTS,
           manifest=MANIFEST, archive_check=None):
    provenance = json.loads((directory.parent / "toolchain.json").read_text())
    lock = read_lock(root / "migration/toolchain.lock")
    if provenance["lock"] != lock or provenance["c_target"] != cc_target:
        raise ValueError("Candidate provenance does not match the current build")
    (archive_check or check_archive)(directory)
    report = dict(abi=1, c_target=cc_target, lock=lock,
                  sources={name: digest(root / name) for name in sources},
                  products={name: digest(directory / name) for name in products},
                  provenance=provenance)
    temporary = directory / (manifest + ".tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n")
    temporary.replace(directory / manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("record", "check", "selection"))
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--object", type=Path)
    parser.add_argument("--cc", default="cc")
    args = parser.parse_args()
    try:
        if args.mode == "selection":
            if args.object is None:
                raise ValueError("--object is required")
            symbols = undefined_symbols(args.object)
            check_selection(symbols)
            print("Pulse selected for all shell data/FIN entry points: " + str(args.object))
        else:
            if args.directory is None:
                raise ValueError("--directory is required")
            if args.mode == "record":
                record(args.root, args.directory, target(args.cc))
            validate(args.root, args.directory, target(args.cc))
            print("Pulse stream C artifact handoff checked: " + str(args.directory / MANIFEST))
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print("Pulse handoff failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
