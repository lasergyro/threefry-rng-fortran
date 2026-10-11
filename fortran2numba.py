# ruff: noqa  # type: ignore  -- not held to the linter or type checker; ruff format still applies
"""Builds Fortran modules as Python modules exposing each public procedure as a
NumPy ufunc using Numba (vectorize for functions, guvectorize for subroutines).
"""

from __future__ import annotations

import argparse
import contextlib
import ctypes
import io
import os
import re
import subprocess
from pathlib import Path
from typing import Any

import numpy as np
from numpy.f2py import crackfortran

ROOT = Path(__file__).resolve().parent

C_TYPES = {
    "void": None,
    "int": ctypes.c_int,
    "long": ctypes.c_int64,
    "float": ctypes.c_float,
    "double": ctypes.c_double,
}

CTYPE_STRS = {
    None: "None",
    ctypes.c_int: "ctypes.c_int",
    ctypes.c_int64: "ctypes.c_int64",
    ctypes.c_float: "ctypes.c_float",
    ctypes.c_double: "ctypes.c_double",
    ctypes.c_void_p: "ctypes.c_void_p",
}

KIND_MAP = {
    # Standard Fortran 2008+ (iso_fortran_env)
    ("integer", "int32"): "c_int32_t",
    ("integer", "int64"): "c_int64_t",
    ("real", "real32"): "c_float",
    ("real", "real64"): "c_double",
    # Fortran 90/95 defaults & literals
    ("integer", "kind(0)"): "c_int32_t",
    ("real", "kind(0.0)"): "c_float",
    ("real", "kind(1.0d0)"): "c_double",
    ("real", "kind(0.0d0)"): "c_double",
    # Universal scientific Fortran conventions (FLEXPART, Threefry, etc.)
    ("integer", "i4"): "c_int32_t",
    ("integer", "i8"): "c_int64_t",
    ("real", "r4"): "c_float",
    ("real", "r8"): "c_double",
    ("real", "sp"): "c_float",
    ("real", "dp"): "c_double",
}


def c_interface(
    sources: list[Path | str], mod_name: str, use_modules: list[str] | None = None
) -> str:
    """Fortran source of a module wrapping each public procedure of sources in a
    bind(C) procedure: inputs by value, intent(out) by reference."""
    sources = [Path(s) for s in sources]
    with contextlib.redirect_stdout(io.StringIO()):
        modules = crackfortran.crackfortran([str(s) for s in sources])
    kinds, procs = {}, []
    extra_uses = list(use_modules or [])
    for m in modules:
        extra_uses.extend(m.get("use", {}).keys())
        listed = {n for n, v in m["vars"].items() if "public" in v.get("attrspec", [])}
        for p in m["body"]:
            name, v, args = p["name"], p["vars"], ", ".join(p["args"])
            if (
                (name not in listed)
                if listed
                else "private" in m["vars"].get(name, {}).get("attrspec", [])
            ):
                continue

            def ctype(var):
                t, k = (
                    v[var]["typespec"],
                    (v[var].get("kindselector") or {}).get("kind"),
                )
                k = k or ("kind(0)" if t == "integer" else "kind(0.0)")
                expr = "-1"
                c = KIND_MAP.get((t, k), None)
                if c:
                    expr = f"merge({c}, {expr}, {k} == {c})"
                kinds.setdefault(expr, f"ck{len(kinds)}")
                return f"{t}({kinds[expr]})"

            if p["block"] == "function":
                procs.append(
                    f"  {ctype(p.get('result') or name)} function c_{name}({args}) bind(C, name='{name}')"
                )
                body = f"    c_{name} = {name}({args})"
            else:
                procs.append(f"  subroutine c_{name}({args}) bind(C, name='{name}')")
                body = f"    call {name}({args})"
            for a in p["args"]:
                attr = "value" if v[a].get("intent") == ["in"] else "intent(out)"
                procs.append(f"    {ctype(a)}, {attr} :: {a}")
            procs += [body, f"  end {p['block']}"]

    all_uses = list(dict.fromkeys([m["name"] for m in modules] + extra_uses))
    head = [
        f"module c_interface_{mod_name}",
        "  use iso_c_binding",
        *[f"  use {u}" for u in all_uses],
        "  implicit none",
        *[f"  integer, parameter :: {n} = {e}" for e, n in kinds.items()],
        "contains",
    ]
    return "\n".join(head + procs + [f"end module c_interface_{mod_name}", ""])


def prototypes(
    fc: str, build_dir: Path | str, wrapper: Path | str
) -> dict[str, tuple[Any, list[tuple[Any, bool, str]]]]:
    """Extracts procedure signatures from gfortran's -fc-prototypes."""
    cmd = [fc, "-fc-prototypes", "-fsyntax-only", "-J", str(build_dir), str(wrapper)]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    return {
        name: (
            C_TYPES[result],
            [
                (C_TYPES[a.split()[0]], "*" in a, a.split()[-1].strip("*"))
                for a in args.split(", ")
            ],
        )
        for result, name, args in re.findall(r"^(\w+) (\w+) \((.*)\);$", out, re.M)
    }


def extract_docs(sources: list[Path | str]) -> dict[str, str]:
    """Extracts !> doc comments immediately preceding functions or subroutines."""
    docs = {}
    for source in sources:
        for m in re.finditer(
            r"((?:^ *!>.*\n)+) *(?:\w+ )*?(?:function|subroutine) (\w+)",
            Path(source).read_text(),
            re.M,
        ):
            docs[m[2].lower()] = " ".join(
                line.strip()[2:].strip() for line in m[1].splitlines()
            )
    return docs


def generate_python(
    name: str, signatures: dict, sources: list[Path | str], so_name: str
) -> str:
    """Generates the Python wrapper source file defining Numba ufuncs."""
    docs = extract_docs(sources)
    lines = [
        f'"""NumPy/Numba interface to Fortran module {name}."""',
        "from __future__ import annotations",
        "",
        "import ctypes",
        "from pathlib import Path",
        "import numba",
        "import numpy as np",
        "",
        f'_lib = ctypes.CDLL(str(Path(__file__).resolve().with_name("{so_name}")))',
        "",
    ]
    for fn_name, (result_type, args) in sorted(signatures.items()):
        argtypes = [CTYPE_STRS[ctypes.c_void_p if out else t] for t, out, _ in args]
        lines.append(f"_f_{fn_name} = _lib.{fn_name}")
        lines.append(f"_f_{fn_name}.restype = {CTYPE_STRS[result_type]}")
        lines.append(f"_f_{fn_name}.argtypes = [{', '.join(argtypes)}]")
        lines.append("")
        ins = [(t, n) for t, out, n in args if not out]
        outs = [(t, n) for t, out, n in args if out]
        wide = [
            {"i": "int64", "u": "uint64"}.get(np.dtype(t).kind, np.dtype(t).name)
            for t, _ in ins
        ]
        in_names = [n for _, n in ins]
        out_names = [n for _, n in outs]
        call_args = ", ".join(f"{n}.ctypes.data" if out else n for _, out, n in args)
        doc = docs.get(fn_name, fn_name)
        if not outs:
            ret_dtype = np.dtype(result_type).name
            sig_str = f'"{ret_dtype}({", ".join(wide)})"'
            lines.append(f"@numba.vectorize([{sig_str}])")
            lines.append(f"def {fn_name}({', '.join(in_names)}):")
            lines.append(f'    """{doc}"""')
            lines.append(f"    return _f_{fn_name}({call_args})")
        else:
            out_sigs = [f"{np.dtype(t).name}[:]" for t, _ in outs]
            sig_str = f'"void({", ".join(wide + out_sigs)})"'
            layout = f'"{",".join(["()"] * len(ins))}->{",".join(["()"] * len(outs))}"'
            lines.append(f"@numba.guvectorize([{sig_str}], {layout})")
            lines.append(f"def {fn_name}({', '.join(in_names + out_names)}):")
            lines.append(f'    """{doc}"""')
            lines.append(f"    _f_{fn_name}({call_args})")
        lines.append("")

    all_names = ", ".join(f'"{n}"' for n in sorted(signatures.keys()))
    lines.append(f"__all__ = [{all_names}]")
    lines.append("")
    return "\n".join(lines)


def generate_stub(name: str, signatures: dict, sources: list[Path | str]) -> str:
    """Generates the .pyi typing stub for editors and static type checkers."""
    docs = extract_docs(sources)
    lines = [
        f"# Generated by fortran2numba for module {name}; do not edit.",
        "import numpy as np",
        "from numpy.typing import ArrayLike, NDArray",
        "",
    ]
    for fn_name, (result_type, args) in sorted(signatures.items()):
        params = ", ".join([f"{n}: ArrayLike" for _, o, n in args if not o])
        results = [f"NDArray[np.{np.dtype(t).name}]" for t, o, _ in args if o] or [
            f"NDArray[np.{np.dtype(result_type).name}]"
        ]
        ret = results[0] if len(results) == 1 else f"tuple[{', '.join(results)}]"
        doc = docs.get(fn_name, fn_name)
        lines.append(f"def {fn_name}({params}) -> {ret}:")
        lines.append(f'    """{doc}"""')
        lines.append("")
    return "\n".join(lines)


def make_module(
    name: str,
    sources: tuple[Path | str],
    deps: tuple[Path | str] = (),
    out_dir: Path | str = ROOT / "build",
    fc: str | None = None,
) -> Path:
    """Builds a Fortran module into a Python package and shared library."""
    fc = fc or os.environ.get("FC", "gfortran")
    out_dir = Path(out_dir).resolve()
    pkg_dir = out_dir / name
    pkg_dir.mkdir(parents=True, exist_ok=True)
    sources = [Path(s).resolve() for s in sources]
    deps = [Path(d).resolve() for d in (deps or [])]

    build_dir = out_dir / f"fortran_{name}"
    build_dir.mkdir(parents=True, exist_ok=True)

    wrapper = build_dir / f"c_interface_{name}.f90"
    wrapper.write_text(c_interface(sources, name))

    so_name = f"lib{name}.so"
    so_path = pkg_dir / so_name
    compile_sources = [*deps, *sources, wrapper]
    cmd = [
        fc,
        "-O2",
        "-shared",
        "-fPIC",
        "-J",
        str(build_dir),
        *[str(s) for s in compile_sources],
        "-o",
        str(so_path),
    ]
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as exc:
        print(exc.stderr)
        raise
    signatures = prototypes(fc, build_dir, wrapper)
    (pkg_dir / "__init__.py").write_text(
        generate_python(name, signatures, sources, so_name)
    )
    (pkg_dir / "__init__.pyi").write_text(generate_stub(name, signatures, sources))
    (pkg_dir / "py.typed").touch()
    return pkg_dir / "__init__.py"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Build Fortran module to Python/Numba")
    parser.add_argument("name", help="Module name")
    parser.add_argument("sources", nargs="+", help="Fortran source file(s)")
    parser.add_argument(
        "--deps", nargs="*", default=(), help="Fortran dependency source file(s)"
    )
    parser.add_argument(
        "--out-dir", default=str(ROOT / "build"), help="Output directory"
    )
    args = parser.parse_args()
    make_module(args.name, args.sources, deps=args.deps, out_dir=args.out_dir)
