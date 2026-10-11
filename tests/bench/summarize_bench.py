#!/usr/bin/env python3
"""Build a Markdown table of cycles per call from the logs in results/.

Reads every log written by run_bench.sh, including its '# key: value'
provenance header, and prints one row per machine, compiler and flags. The
logs are the record; the table can be regenerated from them at any time.

Usage: summarize_bench.py [RESULTS_DIR]
"""

import sys
from pathlib import Path

COLUMNS = [
    ("threefry2x32 latency", "`threefry2x32` latency"),
    ("threefry2x32 throughput", "`threefry2x32` throughput"),
    ("threefry2x32_r latency", "`threefry2x32_r` latency"),
    ("empty call latency", "empty call"),
]


def row(path):
    lines = path.read_text().splitlines()
    h = dict(l[2:].split(": ", 1) for l in lines if l.startswith("# ") and ": " in l)
    ghz = float(h["clock GHz"])
    ns = {
        label: float(t)
        for label, t, _ in (
            l.split("|") for l in lines if "|" in l and not l.startswith("#")
        )
    }
    cycles = [f"{ns[label] * ghz:.1f}" if label in ns else "" for label, _ in COLUMNS]
    source = f"src {h['sha256 src/threefry_mod.f90'][:8]}"
    return [
        h["machine"],
        h["compiler"],
        h["flags"],
        *cycles,
        f"{ghz:.2f}",
        h["date"][:10],
        source,
    ]


def main(argv):
    results = Path(argv[0]) if argv else Path(__file__).resolve().parent / "results"
    head = [
        "Machine",
        "Compiler",
        "Flags",
        *(c for _, c in COLUMNS),
        "Clock GHz",
        "Date",
        "Source",
    ]
    print("Cycles per call (run_bench.sh; best of five repetitions of 2·10⁷ calls).")
    # one sentence per line, as sembr formats Markdown
    print(
        "Latency feeds each call's output into the next call's counter; "
        "throughput uses independent counters, as particles do.\n"
    )
    print("| " + " | ".join(head) + " |")
    print("|" + " --- |" * len(head))
    for r in sorted(row(p) for p in results.glob("*.txt")):
        print("| " + " | ".join(r) + " |")


if __name__ == "__main__":
    main(sys.argv[1:])
