#!/usr/bin/env bash
# Locate the round count at which Threefry-2x32 starts passing PractRand.
#
# The SC'11 paper (Salmon et al.) reports minimum Crush-resistant round
# counts for Threefry-2x64, -4x32 and -4x64 but never tests -2x32, so this
# measures it directly. For each round count and each stream layout it pipes
# threefry_dump into PractRand (nothing is written to disk) and records the
# data length at which PractRand first reports a FAIL, or that it passed up
# to $SIZE. PractRand stops at the first failing length (-tlfail, its
# default), so low round counts finish in seconds.
#
# Known result (results/, summary.md; the stream and PractRand are both
# deterministic, so a rerun reproduces it exactly): rounds 1-7 fail at 1 MB,
# 8 at 8 MB, 9 at 256 MB (counter) or 512 MB (key); 10 and above pass 32 GB,
# and 10, 11 and 20 pass 1 TB. So the default only rechecks the boundary,
# rounds 8-10, in about 4 minutes; the full sweep, rounds 1-20, takes about an
# hour (an M1 Pro, JOBS=1): ./find_round_threshold.sh 32GB $(seq 1 20)
#
# Every run, 20 rounds included, uses threefry2x32_r, the version with a
# variable round count; the other scripts test threefry2x32, the unrolled
# version at 20 rounds that callers use.
#
# Stream layouts (see threefry_dump.f90):
#   counter  key fixed at zero, 64-bit index stepped through the counter
#   key      counter fixed at zero, 64-bit index stepped through the key
#
# Needs the PractRand build from run_empirical_tests.sh (run it once first).
#
# Usage: [JOBS=N] ./find_round_threshold.sh [SIZE] [ROUNDS...]
#   SIZE     PractRand -tlmax, default 32GB
#   ROUNDS   round counts to test, default 8 9 10 (see above)
#   JOBS     (round, layout) runs to execute at once, default 1. Each run is
#            one generator plus PractRand, about 2 cores: PractRand's input
#            thread is the bottleneck, so independent runs side by side are
#            the only way to use more cores. A single long run can't be
#            split, since PractRand's statistics span the whole stream.
# Each run's full PractRand log goes to results/practrand_r<rounds>_<layout>_<SIZE>.txt
# with a provenance header (see lib.sh); summarize_results.py builds the
# results table from them.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SIZE="${1:-32GB}"
shift || true
if [ $# -gt 0 ]; then ROUNDS=("$@"); else ROUNDS=(8 9 10); fi

if [ ! -x "$RNG_TEST" ]; then
  echo "PractRand not built: run ./run_empirical_tests.sh --quick once first" >&2
  exit 1
fi
build_dump
PRACTRAND="$(practrand_tool)"

run_one() {  # rounds layout
  local log="$RESULTS/practrand_r${1}_${2}_${SIZE}.txt"
  local cmd="threefry_dump $DUMP_BOUND - $2 $1 | RNG_test stdin32 -tlmin 1MB -tlmax $SIZE -multithreaded"
  write_header "$log" "$PRACTRAND" "$cmd"
  # trap '' PIPE: see the matching comment in run_empirical_tests.sh.
  ( trap '' PIPE; "$DUMP" "$DUMP_BOUND" - "$2" "$1" ) \
    | "$RNG_TEST" stdin32 -tlmin 1MB -tlmax "$SIZE" -multithreaded >> "$log" 2>&1 || true
}

for r in "${ROUNDS[@]}"; do
  for mode in counter key; do
    run_limited run_one "$r" "$mode"
  done
done
wait
"$HERE/summarize_results.py" --practrand
