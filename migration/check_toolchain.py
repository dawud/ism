"""Fail closed on candidate identity; print build provenance as JSON."""

import argparse
import json
from pathlib import Path
import platform
import shlex
import subprocess
import sys


def read_lock(path):
    return dict(line.split("=", 1) for line in path.read_text().splitlines()
                if line and not line.startswith("#"))


def output(*command):
    return subprocess.check_output(command, text=True, stderr=subprocess.STDOUT).strip()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check(fstar_home, cc, lock_path):
    lock = read_lock(lock_path)
    require(lock["Z3_VERSION"] in lock["Z3_BUNDLED_VERSIONS"].split(","),
            "selected solver is not in the pinned bundle")
    version = output(str(fstar_home / "bin/fstar.exe"), "--version")
    require(version.splitlines()[0] == "F* " + lock["FSTAR_VERSION"].removeprefix("v"),
            "F* release does not match migration/toolchain.lock")
    require("commit=" + lock["FSTAR_COMMIT"] in version.splitlines(),
            "F* commit does not match migration/toolchain.lock")
    krml_version = output(str(fstar_home / "bin/krml"), "-version")
    require(krml_version == "KaRaMeL version: " + lock["KARAMEL_COMMIT"],
            "bundled KaRaMeL commit does not match migration/toolchain.lock")
    solvers = {}
    for expected in lock["Z3_BUNDLED_VERSIONS"].split(","):
        solver = fstar_home / "lib/fstar" / ("z3-" + expected) / "bin/z3"
        actual = output(str(solver), "--version")
        require(actual.split()[:3] == ["Z3", "version", expected],
                "bundled solver version mismatch: " + str(solver))
        solvers[expected] = actual
    cc_version = output(*shlex.split(cc), "--version")
    return {
        "lock": lock,
        "fstar": version,
        "karamel": krml_version,
        "bundled_solvers": solvers,
        "selected_solver": lock["Z3_VERSION"],
        "c_compiler": cc_version,
        "c_target": output(*shlex.split(cc), "-dumpmachine"),
        "host": platform.platform(),
        "os_release": Path("/etc/os-release").read_text(),
        "everparse": "separate pinned baseline generator; not run by candidate gate",
        "scope": "shared stream/table/response and Pulse proofs, including proof-only sealed pending-send ownership; pilots and real stream/table/response C extraction/ABI smokes; mixed ingress, table and response integration checked separately; send runtime integration and whole-toolchain promotion remain open",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fstar-home", type=Path, required=True)
    parser.add_argument("--cc", default="cc")
    parser.add_argument("--lock", type=Path, default=Path("migration/toolchain.lock"))
    args = parser.parse_args()
    try:
        print(json.dumps(check(args.fstar_home.resolve(), args.cc, args.lock), indent=2))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print("Candidate toolchain check failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
