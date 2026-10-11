#!/usr/bin/env bash
# Fully automated empirical randomness check for threefry_mod.
#
# None of PractRand, dieharder or TestU01 has a Homebrew formula, so this
# fetches and builds them from source on first run (cached under .tools/,
# which is gitignored) and reuses the builds on later runs. It then runs, in
# order:
#
#   1. PractRand RNG_test    -- up to $PRACTRAND_SIZE (default 8GB)
#   2. dieharder -a          -- the full standard battery
#   3. TestU01 Crush         -- skipped with --quick
#
# on threefry2x32, the unrolled version at 20 rounds that callers use, with
# the counter stepped. Each run's log goes to results/ with a provenance header
# (see lib.sh), and summary.md is rebuilt from all the logs:
#   practrand_r20_counter_<SIZE>.txt, dieharder_r20_counter_<full|quick>.txt,
#   testu01_crush_r20_counter.txt
#
# The fast checks (known-answer vectors, a statistical sanity check of the
# example draw routines) are in ../python: pixi run test.
#
# All batteries are fed by piping threefry_dump's stdout straight into the
# test tool (dieharder via its stdin_input_raw generator, -g 200) rather
# than writing a data file first: at the GiB-to-tens-of-GiB scale these
# batteries consume, a data file is both slow (written, then read back) and
# a real risk of filling the disk. threefry_dump is told to offer a huge
# upper bound (1 PiB, DUMP_BOUND in lib.sh) and just stops cleanly the moment
# its consumer closes the pipe -- see the comment above the write() in
# threefry_dump.f90 -- so nothing is ever actually generated beyond what each
# tool asks for.
#
# On an Apple M1 Pro (10 cores) this takes about 2 minutes for PractRand at
# the default 8GB, and about 36 minutes for dieharder's full battery:
# dieharder is CPU-bound on the statistics themselves, not on generating
# input. TestU01's Crush, single-threaded, adds about 13 minutes. Pass --quick
# for a much faster, less thorough run.
#
# Usage: ./run_empirical_tests.sh [--quick]
#   --quick   use small, fast settings instead of the thorough defaults

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [ "${1:-}" = "--quick" ]; then
  PRACTRAND_SIZE="${PRACTRAND_SIZE:-1GB}"
  DIEHARDER_ARGS="${DIEHARDER_ARGS:--a -p 10}"         # full battery, 10x fewer p-samples
  DIEHARDER_MODE="quick"
  TESTU01_BATTERY=""                                   # skipped
else
  PRACTRAND_SIZE="${PRACTRAND_SIZE:-8GB}"
  DIEHARDER_ARGS="${DIEHARDER_ARGS:--a}"               # the full battery
  DIEHARDER_MODE="full"
  TESTU01_BATTERY="crush"
fi
NPROC="$(ncpu)"

mkdir -p "$TOOLS"

if [ ! -x "$RNG_TEST" ]; then
  echo "==> Fetching and building PractRand (no Homebrew formula exists for it)..."
  rm -rf "$TOOLS/practrand"
  git clone --depth 1 https://github.com/rurban/PractRand.git "$TOOLS/practrand"
  ( cd "$TOOLS/practrand" && CXX="${CXX:-c++}" ./configure && make -j"$NPROC" )
fi

# dieharder builds with autotools and links GSL (gsl-config finds it, on macOS
# from Homebrew or on Linux from the distribution's gsl-devel).
DIEHARDER="$TOOLS/dieharder/dieharder/dieharder"
if [ ! -x "$DIEHARDER" ]; then
  { command -v autoreconf && command -v gsl-config; } >/dev/null \
    || { echo "dieharder needs autotools (autoreconf) and GSL (gsl-config) to build" >&2; exit 1; }
  echo "==> Fetching and building dieharder (no Homebrew formula exists for it)..."
  rm -rf "$TOOLS/dieharder"
  git clone --depth 1 https://github.com/rurban/dieharder.git "$TOOLS/dieharder"
  GSL_PREFIX="$(gsl-config --prefix)"
  # cc is clang on macOS and gcc on Linux.
  DH_CC="${CC:-cc}"
  # -Wno-error=incompatible-function-pointer-types: dieharder's test
  # table (Test* vs a plain function pointer) predates strict C23
  # prototype checking, which newer clang treats as an error by default;
  # this is a known upstream compatibility gap, not something wrong with
  # the data being tested. Only clang knows the flag, so it is passed only
  # when the compiler accepts it.
  DH_CFLAGS=""
  if echo 'int main(void){return 0;}' \
      | "$DH_CC" -x c -Werror -Wno-error=incompatible-function-pointer-types - -o /dev/null 2>/dev/null; then
    DH_CFLAGS="-Wno-error=incompatible-function-pointer-types"
  fi
  (
    cd "$TOOLS/dieharder"
    ./autogen.sh
    # --disable-shared: building libdieharder.la as a dylib fails on macOS
    # (undefined symbols that are only ever defined in the main dieharder
    # binary, not the library -- macOS dylibs insist on full resolution at
    # link time where Linux .so's do not); the static lib only needs those
    # symbols resolved once, at the final executable link, which works.
    CC="$DH_CC" \
      CFLAGS="-O2 $DH_CFLAGS" \
      CPPFLAGS="-I$GSL_PREFIX/include" LDFLAGS="-L$GSL_PREFIX/lib" \
      ./configure --disable-shared --enable-static
    # The top-level Makefile has no target for the program alone; build the
    # library, then the program, each in its own directory.
    make -j"$NPROC" -C libdieharder
    make -j"$NPROC" -C dieharder
  )
fi

echo "==> Building threefry_dump with $FC..."
build_dump
[ -n "$TESTU01_BATTERY" ] && build_testu01

# log NAME TOOL COMMAND...: runs COMMAND, piping threefry_dump into it, with
# its output shown and appended to results/NAME after the provenance header,
# then the run's wall-clock time.
log() {
  local file="$RESULTS/$1" tool="$2"; shift 2
  write_header "$file" "$tool" "threefry_dump $DUMP_BOUND - | $(basename "$1") ${*:2}"
  local start=$SECONDS
  ( trap '' PIPE; "$DUMP" "$DUMP_BOUND" - ) | "$@" 2>&1 | tee -a "$file"
  echo "# elapsed seconds: $((SECONDS - start))" >> "$file"
}

echo
echo "==> 1/3 PractRand, up to $PRACTRAND_SIZE"
# trap '' PIPE: the consumer stops reading well before threefry_dump reaches
# $DUMP_BOUND, so threefry_dump's next write() hits a closed pipe. Without
# this, the default SIGPIPE disposition (inherited across exec) kills it
# outright; a trap set here is inherited too, so it ignores the signal
# instead, and the write fails with EPIPE, caught by iostat in
# threefry_dump.f90, which then exits 0. Needed because of 'set -e'/
# 'pipefail' above: an uncaught SIGPIPE would otherwise abort this script
# even though the consumer got everything it asked for.
log "practrand_r20_counter_${PRACTRAND_SIZE}.txt" "$(practrand_tool)" \
  "$RNG_TEST" stdin32 -tlmax "$PRACTRAND_SIZE" -multithreaded

echo
echo "==> 2/3 dieharder $DIEHARDER_ARGS, streamed (no data file written)"
# shellcheck disable=SC2086  # DIEHARDER_ARGS is deliberately word-split
log "dieharder_r20_counter_${DIEHARDER_MODE}.txt" \
  "dieharder (git $(git -C "$TOOLS/dieharder" rev-parse --short HEAD))" \
  "$DIEHARDER" -g 200 $DIEHARDER_ARGS

echo
if [ -n "$TESTU01_BATTERY" ]; then
  echo "==> 3/3 TestU01 $TESTU01_BATTERY, streamed"
  log "testu01_${TESTU01_BATTERY}_r20_counter.txt" \
    "$(testu01_tool)" \
    "$TESTU01_STDIN" "$TESTU01_BATTERY" "threefry2x32 counter"
else
  echo "==> 3/3 TestU01 skipped (--quick)"
fi

echo
"$HERE/summarize_results.py" > "$HERE/summary.md"
echo "==> logs in results/; summary.md rebuilt"
