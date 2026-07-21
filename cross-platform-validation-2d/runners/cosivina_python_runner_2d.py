"""
cosivina_python_runner_2d.py
Runs all 100 cosivina-python 2D simulation scripts in simulations/cosivina-python/
and saves flattened (row-major) 50x50 activation profiles to data/cosivina-python/.

Each generated sim_NNN.py embeds the two-phase protocol and a run(output_dir)
function that writes the CSVs (single row of 2500 values, u.ravel()).

Usage (from cross-platform-validation-2d/):
  python runners/cosivina_python_runner_2d.py
"""

import importlib.util
import os
import sys
from pathlib import Path

# Variant ("numba" | "nonumba" | "fft") chosen from argv; set BEFORE loading sim
# modules so the shared sim_*.py import the matching cosivina backend and kernel
# element (they read COSIVINA_VARIANT). The fft variant uses the spectral KernelFFT
# element (NumPy-only, no numba path).
VARIANT = sys.argv[1] if len(sys.argv) > 1 else "nonumba"
if VARIANT not in ("numba", "nonumba", "fft"):
    print(f"Unknown variant '{VARIANT}'; defaulting to nonumba")
    VARIANT = "nonumba"
os.environ["COSIVINA_VARIANT"] = VARIANT

ROOT    = Path(__file__).resolve().parent.parent      # cross-platform-validation-2d/
SIM_DIR = ROOT / "simulations" / "cosivina-python"
OUT_DIR = ROOT / "data" / f"cosivina-python-{VARIANT}"


def load_sim(path: Path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"cosivina-python 2D variant: {VARIANT}  ->  {OUT_DIR}")
    scripts = sorted(SIM_DIR.glob("sim_*.py"))
    print(f"Found {len(scripts)} 2D simulation scripts.")

    n_ok = n_failed = 0
    for i, path in enumerate(scripts, 1):
        print(f"[{i:3d}/{len(scripts)}] Running {path.name} ... ", end="", flush=True)
        try:
            load_sim(path).run(str(OUT_DIR))
            n_ok += 1
            print("OK")
        except Exception as exc:
            n_failed += 1
            print(f"FAILED: {exc}")

    print(f"\nDone: {n_ok} OK, {n_failed} failed.")
    print(f"Output: {OUT_DIR}")


if __name__ == "__main__":
    main()
