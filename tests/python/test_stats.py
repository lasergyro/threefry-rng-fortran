"""Statistical sanity check of the example draw routines in
examples/rand_mod.f90.
"""

import numpy as np
import pytest
import rand_mod

N = 5_000_000
NMAX = 6_000_000

I = np.arange(N + 1)  # counters 0..N along one axis; the other is 0


def test_index_chi2():
    idx = rand_mod.rand_index(I, 0, 0, NMAX)
    counts = np.bincount((idx - 1).astype(np.int64) * 100 // NMAX, minlength=100)
    expected = idx.size / 100
    chi2 = ((counts - expected) ** 2 / expected).sum()
    assert chi2 < 99 + 6 * np.sqrt(2 * 99)  # mean + 6 sd of chi-square with 99 dof


def test_uniform_moments():
    u = rand_mod.rand_uniform(I, 0, 0).astype(np.float64)
    assert abs(u.mean() - 0.5) < 0.01
    assert abs(u.var() - 1 / 12) < 0.005


@pytest.mark.parametrize("ctr0, ctr1", [(I, 0), (0, I)], ids=["particle", "time"])
def test_uniform_lag1_correlation(ctr0, ctr1):
    u = rand_mod.rand_uniform(ctr0, ctr1, 0).astype(np.float64)
    assert abs(np.corrcoef(u[:-1], u[1:])[0, 1]) < 0.01


def test_normal_moments():
    g = rand_mod.rand_normal_uniform(I, 0, 0)[0].astype(np.float64)
    assert abs(g.mean()) < 0.01
    assert abs(g.var() - 1) < 0.02
