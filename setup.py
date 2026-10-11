# ruff: noqa  # type: ignore  -- not held to the linter or type checker; ruff format still applies
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import fortran2numba
from setuptools import setup
from setuptools.dist import Distribution


class BinaryDistribution(Distribution):
    def has_ext_modules(self):
        return True


build_dir = ROOT / "build"
fortran2numba.make_module(
    "threefry", [ROOT / "src/threefry_mod.f90"], out_dir=build_dir
)
fortran2numba.make_module(
    "rand_mod",
    [ROOT / "examples/rand_mod.f90"],
    deps=[ROOT / "src/threefry_mod.f90"],
    out_dir=build_dir,
)

setup(distclass=BinaryDistribution)
