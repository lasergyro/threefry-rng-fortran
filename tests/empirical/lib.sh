# Shared by find_round_threshold.sh, run_testu01.sh and run_empirical_tests.sh.
# Source it, don't run it.
#
# Every result log those scripts write goes to results/ (tracked, so a run can
# be committed and published) and starts with '# key: value' lines recording
# what was tested and how; summarize_results.py reads the logs and builds the
# results tables from them.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TOOLS="$HERE/.tools"
RESULTS="$HERE/results"
SRC="$ROOT/src/threefry_mod.f90"
DUMP_SRC="$HERE/threefry_dump.f90"
. "$HERE/../fc.sh"  # FC, FC_MODFLAG
DUMP_BOUND=1125899906842624   # 1 PiB upper bound, above any test size; threefry_dump stops when its consumer closes the pipe

mkdir -p "$RESULTS"

# Builds threefry_dump with $FC into a private temporary directory and sets DUMP to it.
# Private per invocation, so a concurrent invocation rebuilding it can't swap
# the binary out mid-run. Removed on exit.
build_dump() {
  BUILD="$(mktemp -d)"
  trap 'rm -rf "$BUILD"' EXIT
  "$FC" -O3 "$FC_MODFLAG" "$BUILD" "$SRC" "$DUMP_SRC" -o "$BUILD/threefry_dump"
  DUMP="$BUILD/threefry_dump"
}

TESTU01_COMMIT=57e98bf33880daedc930739c81e39b89a8d24dba   # TestU01 1.2.3, umontreal-simul/TestU01-2009
TESTU01="$TOOLS/testu01"

# Builds TestU01 under .tools/ on first use (no Homebrew formula exists for
# it), then testu01_stdin.c into $BUILD, and sets TESTU01_STDIN to it. Call
# after build_dump, which creates $BUILD.
build_testu01() {
  if [ ! -f "$TESTU01/lib/libtestu01.a" ]; then
    echo "==> Fetching and building TestU01 (no Homebrew formula exists for it)..."
    rm -rf "$TOOLS/testu01-src" "$TESTU01"
    git clone -q https://github.com/umontreal-simul/TestU01-2009 "$TOOLS/testu01-src"
    (
      cd "$TOOLS/testu01-src"
      git checkout -q "$TESTU01_COMMIT"
      # git gives every file the checkout time, in no set order, so make can
      # find configure older than configure.ac and try to regenerate it with
      # the automake 1.10 the release was made with (it does on Linux).
      # Restore the order: sources, then what autotools generated from them.
      touch aclocal.m4 && touch configure include/config.h.in \
        && find . -name Makefile.in -exec touch {} +
      ./configure --prefix="$TESTU01" --disable-shared > build.log 2>&1
      make -j"$(ncpu)" >> build.log 2>&1
      make install >> build.log 2>&1
    )
  fi
  cc -O2 -I"$TESTU01/include" "$HERE/testu01_stdin.c" -L"$TESTU01/lib" \
    -ltestu01 -lprobdist -lmylib -lm -o "$BUILD/testu01_stdin"
  TESTU01_STDIN="$BUILD/testu01_stdin"
}

testu01_tool() {
  echo "TestU01 1.2.3 (git ${TESTU01_COMMIT:0:7}), sha256 tests/empirical/testu01_stdin.c: $(sha "$HERE/testu01_stdin.c")"
}

# Runs JOB with its arguments in the background, waiting first while JOBS
# (default 1) jobs are already running. Call 'wait' after the last one.
run_limited() {
  while [ "$(jobs -pr | wc -l)" -ge "${JOBS:-1}" ]; do sleep 1; done
  "$@" &
}

sha() { { sha256sum "$1" 2>/dev/null || shasum -a 256 "$1"; } | cut -c1-16; }

# CPU model on macOS (sysctl) or Linux (/proc/cpuinfo), else the architecture.
cpu_name() {
  sysctl -n machdep.cpu.brand_string 2>/dev/null \
    || sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo 2>/dev/null | head -1 | grep . \
    || uname -m
}

ncpu() { sysctl -n hw.ncpu 2>/dev/null || nproc; }

# PractRand's version and git commit, for the provenance header. Needs the
# PractRand build from run_empirical_tests.sh.
RNG_TEST="$TOOLS/practrand/RNG_test"
practrand_tool() {
  echo "PractRand $("$RNG_TEST" -version 2>&1 | grep -o '[0-9][0-9.]*' | head -1) (git $(git -C "$TOOLS/practrand" rev-parse --short HEAD))"
}

# write_header LOG TOOL COMMAND...: starts LOG with the provenance header. The
# sha256 lines identify what was tested (the files may be uncommitted).
write_header() {
  local log="$1" tool="$2"; shift 2
  {
    echo "# date: $(date '+%Y-%m-%dT%H:%M:%S%z')"
    echo "# sha256 src/threefry_mod.f90: $(sha "$SRC")"
    echo "# sha256 tests/empirical/threefry_dump.f90: $(sha "$DUMP_SRC")"
    echo "# compiler: $("$FC" --version | head -1), -O3"
    echo "# tool: $tool"
    echo "# machine: $(cpu_name), $(uname -sm)$( [ -f /etc/os-release ] && . /etc/os-release && echo ", $PRETTY_NAME")"
    echo "# command: $*"
  } > "$log"
}
