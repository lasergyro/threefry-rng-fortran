#!/usr/bin/env bash
# Benchmark threefry2x32 (see threefry_bench.f90) and report ns and cycles per
# call. Works on macOS and Linux, arm64 and x86-64.
#
# Usage: tests/bench/run_bench.sh [FLAGS]     default FLAGS: -O2
#   FC selects the compiler (see ../fc.sh: default gfortran, else ifx); SRC
#   an alternative module file to benchmark instead of src/threefry_mod.f90.
#
# A run of src/threefry_mod.f90 is also logged to
# results/<cpu>_<compiler>_<flags>.txt, replacing any earlier run with the same
# name, with a '# key: value' provenance header; summary.md is then rebuilt
# from all the logs by summarize_bench.py. Runs with SRC set are exploratory and
# only printed.

set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
. "$here/../fc.sh"  # FC, FC_MODFLAG
flags="${*:--O2}"
src="${SRC:-$root/src/threefry_mod.f90}"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

cc -O2 "$here/clock.c" -o "$build/clock"
# shellcheck disable=SC2086  # flags is deliberately word-split
$FC $flags $FC_MODFLAG "$build" "$src" "$here/threefry_bench.f90" -o "$build/bench"

ghz="$("$build/clock")"
cpu="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1)"
os="$(uname -sm)$( [ ! -f /etc/os-release ] || { . /etc/os-release && echo ", $PRETTY_NAME"; } )"
compiler="$($FC --version | head -1)"
# the first version number in it: 16.2.0 for gfortran, 2026.1.1 for ifx
version="$(echo "$compiler" | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"
echo "$cpu, $os, $compiler, flags $flags"
echo "clock $ghz GHz (from a dependent add chain)"
"$build/bench" > "$build/out"
printf '  %-28s %9s %9s\n' "" "ns/call" "cycles"
awk -F'|' -v ghz="$ghz" '{ printf "  %-28s %9.2f %9.1f\n", $1, $2, $2 * ghz }' "$build/out"

[ -z "${SRC:-}" ] || exit 0

slug() { tr 'A-Z' 'a-z' | tr -c 'a-z0-9.\n' '-' | sed 's/--*/-/g; s/^-//; s/-$//'; }
log="$here/results/$(echo "$cpu" | slug)_$(basename "$FC")-${version}_$(echo "$flags" | slug).txt"
sha() { { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1"; } | cut -c1-16; }
mkdir -p "$here/results"
{
  echo "# date: $(date '+%Y-%m-%dT%H:%M:%S%z')"
  echo "# sha256 src/threefry_mod.f90: $(sha "$src")"
  echo "# machine: $cpu, $os"
  echo "# compiler: $compiler"
  echo "# flags: $flags"
  echo "# clock GHz: $ghz"
  echo "# columns: label|ns per call|checksum"
  cat "$build/out"
} > "$log"
"$here/summarize_bench.py" > "$here/summary.md"
echo "logged to ${log#"$root/"}; summary.md rebuilt"
