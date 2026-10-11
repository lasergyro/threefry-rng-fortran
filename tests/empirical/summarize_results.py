#!/usr/bin/env python3
# ruff: noqa  # type: ignore  -- not held to the linter or type checker; ruff format still applies
"""Build Markdown results tables from the logs in results/.

Reads every practrand_*.txt, dieharder_*.txt and testu01_*.txt log written
by find_round_threshold.sh, run_testu01.sh and run_empirical_tests.sh,
including their '# key: value' provenance headers (see lib.sh), and prints one
table per tool. The logs are the record; the tables can be regenerated from
them at any time.

Usage: summarize_results.py [--practrand | --dieharder | --testu01] [RESULTS_DIR]
"""

import re
import sys
from pathlib import Path

FLAG = re.compile(r"\b(FAIL|VERY SUSPICIOUS|very suspicious|suspicious|unusual)\b")
UNITS = {"KB": 2**10, "MB": 2**20, "GB": 2**30, "TB": 2**40, "PB": 2**50}


def header(lines):
    return dict(l[2:].split(": ", 1) for l in lines if l.startswith("# ") and ": " in l)


def source(h):
    """The generator's source hash, the identity of what was tested."""
    return f"src {h.get('sha256 src/threefry_mod.f90', '?')[:8]}"


def function(h):
    """The routine threefry_dump called: threefry2x32_r when it was given a
    round count (after the layout, or before it in logs from before October
    2026), else threefry2x32."""
    variable = re.search(r"threefry_dump \S+ - (\w+ )?\d+", h.get("command", ""))
    return "`threefry2x32_r`" if variable else "`threefry2x32`"


def practrand(path):
    m = re.match(r"practrand_r(\d+)_(\w+?)_(\d+)([KMGTP]B)\.txt$", path.name)
    rounds, layout, size = int(m[1]), m[2], int(m[3]) * UNITS[m[4]]
    lines = path.read_text().splitlines()
    blocks = []  # (length text, [flagged result lines])
    for line in lines:
        if line.startswith("length="):
            blocks.append((re.match(r"length= *([^,(]*?) *\(", line)[1], []))
        elif blocks and FLAG.search(line):
            blocks[-1][1].append(" ".join(line.split()))
    if not blocks:
        result = "no output (run failed or still running)"
    else:
        reached, flags = blocks[-1]
        fails = [f for f in flags if "FAIL" in f]
        if fails:
            result = f"**FAIL at {reached}** ({len(fails)} failing results)"
        else:
            result = f"no failure up to {reached}"
            if flags:
                result += f"; final length flags: {'; '.join(flags)}"
    h = header(lines)
    return (rounds, layout, size), [str(rounds), function(h), layout, result, source(h)]


def p_distance(p):
    """Distance of a TestU01 p-value string from the nearer of 0 and 1."""
    p = p.replace(" ", "")
    if p == "eps":
        return 0.0
    if p.startswith("1-"):
        return 1e-15 if p[2:] == "eps1" else float(p[2:])
    v = float(p)
    return min(v, 1 - v)


def testu01(path):
    m = re.match(r"testu01_(\w+?)_r(\d+)_(\w+)\.txt$", path.name)
    battery, rounds, layout = m[1], int(m[2]), m[3]
    text = path.read_text()
    lines = text.splitlines()
    name = {"small": "SmallCrush", "crush": "Crush", "big": "BigCrush"}[battery]
    nstat = re.search(r"Number of statistics:\s*(\d+)", text)
    cpu = re.search(r"Total CPU time:\s*(\S+)", text)
    if "Summary results" not in text:
        result = "incomplete (run failed or still running)"
    elif "All tests were passed" in text:
        result = f"all {nstat[1]} statistics passed"
    else:
        # TestU01 lists every p-value outside [0.001, 0.999]; at that threshold
        # about 0.2% of statistics are flagged by chance. A failure, as in the
        # SC'11 paper, is a p-value within 1e-10 of 0 or 1.
        summary = text[text.index("Summary results") :]
        # Rows look like ' 11  BirthdaySpacings, t = 2         0.9994 ':
        # number, test name, then the p-value after a run of spaces.
        rows = re.findall(r"^\s*\d+\s+(\S.*?)\s{2,}(\S.*?)\s*$", summary, re.M)
        flagged = [f"{name} p = {p}" for name, p in rows]
        failed = [f for (name, p), f in zip(rows, flagged) if p_distance(p) < 1e-10]
        detail = "; ".join(flagged)
        if failed:
            result = f"**FAIL: {len(failed)} of {nstat[1]} within 1e-10 of 0 or 1**; flagged: {detail}"
        else:
            result = f"pass; {len(flagged)} of {nstat[1]} outside [0.001, 0.999] (about {0.002 * int(nstat[1]):.1f} expected by chance): {detail}"
    order = ["small", "crush", "big"].index(battery)
    h = header(lines)
    return (order, rounds, layout), [
        name,
        str(rounds),
        function(h),
        layout,
        result,
        cpu[1] if cpu else "",
        source(h),
    ]


def dieharder(path):
    m = re.match(r"dieharder_r(\d+)_(\w+?)_(\w+)\.txt$", path.name)
    rounds, layout, mode = int(m[1]), m[2], m[3]
    lines = path.read_text().splitlines()
    h = header(lines)
    # Rows look like '   diehard_birthdays|   0|       100|     100|0.53940210|  PASSED  '.
    rows = [l.split("|") for l in lines if l.count("|") == 5 and not l.startswith("#")]
    assessments = [
        r[5].strip() for r in rows if r[5].strip() in ("PASSED", "WEAK", "FAILED")
    ]
    if "elapsed seconds" not in h:
        result = "incomplete (run failed or still running)"
    else:
        counts = {a: assessments.count(a) for a in ("PASSED", "WEAK", "FAILED")}
        result = f"{len(assessments)} test rows: {counts['PASSED']} PASSED, {counts['WEAK']} WEAK, {counts['FAILED']} FAILED"
        if counts["FAILED"]:
            result = f"**{result}**"
    secs = int(h.get("elapsed seconds", 0))
    time = f"{secs // 3600:02d}:{secs // 60 % 60:02d}:{secs % 60:02d}" if secs else ""
    args = h.get("command", "").split("dieharder", 1)[-1].strip()
    return (rounds, layout, mode), [
        str(rounds),
        function(h),
        layout,
        f"`{args}`",
        result,
        time,
        source(h),
    ]


def table(head, rows):
    out = ["| " + " | ".join(head) + " |", "|" + " --- |" * len(head)]
    out += ["| " + " | ".join(r) + " |" for _, r in sorted(rows)]
    return "\n".join(out)


def main(argv):
    flags = [a for a in argv if a.startswith("--")]
    args = [a for a in argv if not a.startswith("--")]
    results = Path(args[0]) if args else Path(__file__).resolve().parent / "results"
    show = {f[2:] for f in flags} or {"practrand", "dieharder", "testu01"}
    if "practrand" in show:
        rows = [practrand(p) for p in results.glob("practrand_*.txt")]
        print(
            "PractRand (stdin32, default test set; stops at the first failing length):\n"
        )
        print(table(["Rounds", "Function", "Layout", "Result", "Source"], rows) + "\n")
    if "dieharder" in show:
        rows = [dieharder(p) for p in results.glob("dieharder_*.txt")]
        if rows:
            print("dieharder (stdin_input_raw, -g 200):\n")
            print(
                table(
                    [
                        "Rounds",
                        "Function",
                        "Layout",
                        "Arguments",
                        "Result",
                        "Wall time",
                        "Source",
                    ],
                    rows,
                )
                + "\n"
            )
    if "testu01" in show:
        rows = [testu01(p) for p in results.glob("testu01_*.txt")]
        print("TestU01 1.2.3:\n")
        print(
            table(
                [
                    "Battery",
                    "Rounds",
                    "Function",
                    "Layout",
                    "Result",
                    "CPU time",
                    "Source",
                ],
                rows,
            )
            + "\n"
        )


if __name__ == "__main__":
    main(sys.argv[1:])
