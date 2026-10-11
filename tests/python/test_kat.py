"""Known-answer test of threefry2x32 and threefry2x32_r"""

from pathlib import Path

import pytest
import threefry

VECTORS = Path(__file__).parents[1] / "threefry_kat_vectors.txt"
ROWS = [
    line.split()
    for line in VECTORS.read_text().splitlines()
    if line.startswith("threefry2x32 ")
]


@pytest.mark.parametrize("row", ROWS, ids=lambda row: f"{row[1]}rounds-{row[2]}")
def test_vector(row):
    rounds = int(row[1])
    c0, c1, k0, k1 = (int(h, 16) for h in row[2:6])
    expected = f"{row[6]} {row[7]}".lower()

    def hex(o0, o1):
        return f"{int(o0):08x} {int(o1):08x}"

    assert hex(*threefry.threefry2x32_r(c0, c1, k0, k1, rounds)) == expected
    if rounds == 20:
        assert hex(*threefry.threefry2x32(c0, c1, k0, k1)) == expected
