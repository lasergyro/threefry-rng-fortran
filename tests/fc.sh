# Picks the Fortran compiler for the test scripts (tests/bench, tests/empirical).
# Source it, don't run it.
#
# FC, the usual variable for this, selects the compiler. Unset, it is gfortran
# if installed, else ifx. Sets FC_MODFLAG to its flag for where .mod files go:
# gfortran's -J, Intel's -module.

if [ -z "${FC:-}" ]; then
  if command -v gfortran > /dev/null; then FC=gfortran
  elif command -v ifx > /dev/null; then FC=ifx
  else echo "no Fortran compiler: install gfortran or ifx, or set FC" >&2; exit 1
  fi
fi
case "$(basename "$FC")" in
  ifx* | ifort*) FC_MODFLAG=-module ;;
  *) FC_MODFLAG=-J ;;
esac
