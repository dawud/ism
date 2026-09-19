"""Check inventory coverage and emit conservative lexical dependency/caller data.

This is a drift detector, not an F* dependency resolver or a proof checker.
Imports/qualified references conservatively count as callers, even if unused.
"""

import argparse
import json
from pathlib import Path
import re
import sys


def without_comments(source):
    # Preserve newlines and nested F* comments; don't count mentions in prose.
    return re.sub(r"//[^\n]*", "", strip_block_comments(source))


def strip_block_comments(source):
    result = []
    depth = 0
    index = 0
    while index < len(source):
        pair = source[index:index + 2]
        if pair == "(*":
            depth += 1
            index += 2
        elif pair == "*)" and depth:
            depth -= 1
            index += 2
        else:
            result.append(source[index] if not depth or source[index] == "\n" else " ")
            index += 1
    return "".join(result)


def inventory(root, verified, extracted):
    paths = sorted(path.relative_to(root).as_posix()
                   for directory in ("src", "spec")
                   for path in (root / directory).rglob("*.fst*")
                   if path.suffix in (".fst", ".fsti"))
    document = (root / "docs/PULSE_MIGRATION_INVENTORY.md").read_text()
    rows = {}
    for match in re.finditer(r"^\| `((?:src|spec)/[^`]+)` \| ([^|]+) \| ([^|]+) \| ([^|]+) \|$",
                             document, re.MULTILINE):
        path, gate, contract, disposition = (value.strip() for value in match.groups())
        if path in rows:
            raise ValueError("Duplicate inventory row: " + path)
        rows[path] = {"gate": gate, "contract": contract, "disposition": disposition}
    if set(paths) != set(rows):
        raise ValueError("Inventory drift: missing=" + str(sorted(set(paths) - set(rows)))
                         + ", stale=" + str(sorted(set(rows) - set(paths))))
    verified, extracted = set(verified), set(extracted)
    if not extracted <= verified or not verified <= set(paths):
        raise ValueError("Make verification/extraction roots are inconsistent with inventory")
    sources = {path: without_comments((root / path).read_text()) for path in paths}
    names = {path: re.search(r"^module\s+([\w.]+)", source).group(1)
             for path, source in sources.items()}
    deps = {path: {other for other in paths if other != path and
                  re.search(r"(?<![\w.])" + re.escape(names[other]) + r"(?=\.|\b)",
                            re.sub(r"^module\s+[\w.]+", "", source, count=1))}
            for path, source in sources.items()}
    direct = {path: sorted(set(re.findall(
        r"\b(?:LowStar(?:\.[A-Z]\w*)+|FStar\.(?:Monotonic\.)?HyperStack(?:\.[A-Z]\w*)*|Steel(?:\.[A-Z]\w*)+)",
        source))) for path, source in sources.items()}
    adapter = "src/protocol/DNS.Protocol.Parser.EverParseAdapter.fst"
    result = {}
    for path in paths:
        expected = ("verify+extract" if path in extracted else "verify" if path in verified
                    else "everparse-verify" if path == adapter else "uncovered")
        if expected == "uncovered" or rows[path]["gate"] != expected:
            raise ValueError("Build coverage drift for " + path + ": expected " + expected)
        closure = set()
        pending = [path]
        while pending:
            item = pending.pop()
            if item not in closure:
                closure.add(item)
                pending.extend(deps[item])
        result[path] = dict(rows[path], module=names[path],
                            direct_legacy_dependencies=direct[path],
                            transitive_legacy_dependencies=sorted({d for p in closure for d in direct[p]}),
                            local_dependencies=sorted(deps[path]),
                            local_callers=sorted(p for p in paths if path in deps[p]))
    return {"method": __doc__, "modules": result}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--verified", nargs="+", required=True)
    parser.add_argument("--extracted", nargs="+", required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(inventory(args.root, args.verified, args.extracted), indent=2))
    except (OSError, ValueError) as error:
        print("Migration inventory check failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
