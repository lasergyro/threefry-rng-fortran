# threefry-rng

A Fortran implementation of Threefry-2x32, a stateless, counter-based pseudorandom number generator, plus a handful of draw helpers built on top of it.

This was written as an offshoot of a personal project (making [FLEXPART](https://gitlab.phaidra.org/flexpart/flexpart) runs scheduling-independent).

The code is a translation of Threefry (Salmon, Moraes, Dror & Shaw, [*Parallel random numbers: as easy as 1, 2, 3*](https://doi.org/10.1145/2063384.2063405), SC'11).

Their counter PRNG maps a 2 word counter and a 2 word key to 2 words output.
For a fixed key, the mapping is a permutation.
Output bits are empirically statistically independent; part can be thrown out to make repeats possible.

Plenty of open source implementations exist (the [original](https://github.com/DEShawResearch/random123/blob/v1.14.0/include/Random123/threefry.h#L195-L296), [JAX](https://github.com/jax-ml/jax/blob/8bc0ae6da4f6d334d03be7b76be841d72a56d330/jax/_src/prng.py#L871-L921), [XLA](https://github.com/openxla/xla/blob/059baad1789d47bf7c59c045bbce5750a7b8ff1c/xla/hlo/builder/lib/prng.cc#L65-L133)), but this one is pure Fortran 95 + the usual integer size assumptions (asserted on compilation).

Pseudo-code with addition modulo 2^32 (human checked against JAX's and this implementation's code):

```
constants
    C        = 0x1BD11BDA                        # key schedule
    ROT[0:8] = 13, 15, 26, 6, 17, 29, 16, 24     # rotation values
    R        = 20                                # rounds

function threefry2x32(c0, c1, k0, k1) -> (o0, o1)
    # key schedule: two key words plus their parity with C
    ks[0] = k0
    ks[1] = k1
    ks[2] = k0 xor k1 xor C

    # key injection (i = 0)
    x0 = c0 + ks[0]
    x1 = c1 + ks[1]

    for r = 0 .. R-1
        # one MIX: add, rotate, xor
        x0 = x0 + x1
        x1 = rotl(x1, ROT[r mod 8])
        x1 = x1 xor x0

        # key injection after every 4th round (i = 1, 2, ..., R/4)
        if (r + 1) mod 4 == 0
            i  = (r + 1) / 4
            x0 = x0 + ks[i mod 3]
            x1 = x1 + ks[(i + 1) mod 3] + i

    return (x0, x1)
```

## AI use disclosure

AI wrote a prototype; I read the Threefry paper, guided an optimization pass (on gfortran and ifx), verified the pseudo-code and 'threefry_mod.f90' matches JAX's implementation, cleaned up code and docs, verified that `tests/threefry_kat_test.f90` correctly tests it against Random123's published vectors, and wrote `examples/rand_mod.f90`.
AI then wrote the statistical tests and benchmarks.
Three different test suites all agree.

## Usage

The generator is in `src/threefry_mod.f90`, with two functions: a test version, and an unrolled version, which takes 35-70% fewer cycles, depending on the compiler.
```fortran
program raw
  use threefry_mod, only: i8, threefry2x32   ! src/threefry_mod.f90
  implicit none
  integer(kind=i8) :: c0, c1, k0, k1, o0, o1

  c0 = 42_i8; c1 = 7_i8   ! counter: e.g. a particle number and a time step
  k0 = 1_i8;  k1 = 0_i8   ! key: e.g. which quantity is being drawn
  call threefry2x32(c0, c1, k0, k1, o0, o1)
  print '(2z9.8)', o0, o1  ! two 32-bit words, each held in an i8
end program raw
```

```sh
gfortran src/threefry_mod.f90 raw.f90 -o raw && ./raw    # E1E092AB 57748C8D
```

The draw routines in [`examples/rand_mod.f90`](examples/rand_mod.f90) show how to build on top of it.


## Correctness and statistics

`tests/threefry_kat_test.f90` is a check in Fortran against Random123 published values.

```sh
cd tests
gfortran -O2 ../src/threefry_mod.f90 threefry_kat_test.f90 -o threefry_kat_test
./threefry_kat_test
```

`tests/empirical` contains statistical tests.
- [PractRand](https://sourceforge.net/projects/pracrand/) : up to 1TB of streamed output.
- [TestU01](https://simul.iro.umontreal.ca/testu01/tu01.html) : Crush (144 statistics, ~13 min) and BigCrush (160 statistics, ~1.5 h) at 20 rounds, with the counter or the key stepped, on an Apple M1 Pro.
- [dieharder](https://webhome.phy.duke.edu/~rgb/General/dieharder.php) : the full standard battery (`-a`), about 36 min on a 10-core Apple M1 Pro.

Every run is logged to `tests/empirical/results/`, and the results are tabulated in [`tests/empirical/summary.md`](tests/empirical/summary.md).
The search for the round count where the output starts failing uses `threefry2x32_r`; every other run tests `threefry2x32` at 20 rounds.

Install and run with:
```sh
cd tests/empirical
./run_empirical_tests.sh --quick    # fast: 1GB PractRand + dieharder -a with 10x fewer samples, no TestU01
./run_empirical_tests.sh            # thorough: 8GB PractRand + full dieharder -a + TestU01 Crush (~1 h)
```

## Performance

Cycles per call, one isolated call at a time (`tests/bench/run_bench.sh`, `-O2`), taken from [`tests/bench/summary.md`](tests/bench/summary.md):

| | AMD Ryzen 7 5800X, Rocky 9, gfortran 11.5.0 | AMD Ryzen 7 5800X, Rocky 9, ifx 2026.1.1 | Apple M1 Pro, macOS, gfortran 16.2.0 |
| --- | --- | --- | --- |
| `threefry2x32_r`, loop with run-time rotation amounts | 151 | 173 | 114 |
| `threefry2x32`, rotation amounts unrolled | 77 | 49 | 72 |




## Interop

As an exploration of the glue code possible between Python and Fortran, the python module builds the fortran code as shared library with the `gfortran` on `PATH` (targeting Fortran 2018) and calls it as [Numba](https://numba.pydata.org) (g)ufuncs, so the generator broadcasts over arrays like any NumPy function.
Using it, [`tests/python/`](tests/python/) contains the same test against known input/output pairs ([`test_kat.py`](tests/python/test_kat.py)) and fast stat tests of `examples/rand_mod.f90` ([`test_stats.py`](tests/python/test_stats.py)).
Run them with [pixi](https://pixi.sh): `pixi run test`


## License

BSD-3-Clause; see [LICENSE](LICENSE).
The generator, `src/threefry_mod.f90`, is a translation of the reference implementation, [Random123](https://github.com/DEShawResearch/random123) (BSD-3-Clause, D. E. Shaw Research), and the known-answer vectors come from it too, so LICENSE also reproduces Random123's license.
