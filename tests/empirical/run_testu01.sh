#!/usr/bin/env bash
# Runs a TestU01 battery on threefry_dump's output, streamed through
# testu01_stdin.c with nothing written to disk.
#
# TestU01 (L'Ecuyer & Simard) is what the SC'11 paper used to find its
# minimum round counts, so these runs are the like-for-like counterpart of the
# paper's results for the 2x32 variant the paper doesn't test. It has no
# Homebrew formula, so the first run fetches and builds it under .tools/,
# from the authors' repository pinned to TESTU01_COMMIT.
#
# Tests threefry2x32, the unrolled version at 20 rounds that callers use, in
# both stream layouts (counter and key; see threefry_dump.f90).
#
# Usage: [JOBS=N] ./run_testu01.sh <small|crush|big>
#   JOBS     runs to execute at once, default 1 (at most 2 are useful, one per
#            layout). TestU01 is single-threaded.
# Rough durations on an M1 Pro: SmallCrush seconds, Crush about 15 minutes,
# BigCrush about 1.5 hours.
# Each run's log goes to results/testu01_<battery>_r20_<layout>.txt with
# a provenance header (see lib.sh).

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BATTERY="${1:?usage: run_testu01.sh <small|crush|big>}"

build_dump
build_testu01
TOOL="$(testu01_tool)"

run_one() {  # layout
  local log="$RESULTS/testu01_${BATTERY}_r20_${1}.txt"
  write_header "$log" "$TOOL" "threefry_dump $DUMP_BOUND - $1 | testu01_stdin $BATTERY"
  # trap '' PIPE: see the matching comment in run_empirical_tests.sh.
  ( trap '' PIPE; "$DUMP" "$DUMP_BOUND" - "$1" ) \
    | "$TESTU01_STDIN" "$BATTERY" "threefry2x32 $1" >> "$log" 2>&1 || true
}

for mode in counter key; do
  run_limited run_one "$mode"
done
wait
"$HERE/summarize_results.py" --testu01
