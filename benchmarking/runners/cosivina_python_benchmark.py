"""
cosivina_python_benchmark.py
Benchmarks cosivina-python DFT simulations in headless mode.
Appends results to data/timings-cosivina-python.csv.

Prerequisites:
  - cosivina-python installed or available at C:/dev-files/cosivina_python
  - Run from the benchmarking/ root directory

Output rows (no header): cosivina-python,headless,<N>,<run>,<steps_per_second>

Usage:
  cd benchmarking
  python runners/cosivina_python_benchmark.py
"""

import importlib.util
import os
import sys
import time
from pathlib import Path

ROOT     = Path(__file__).resolve().parent.parent   # benchmarking/
SIM_DIR  = ROOT / "simulations" / "cosivina-python"
DATA_DIR = ROOT / "data"
OUTPUT   = DATA_DIR / "timings-cosivina-python.csv"

WARMUP_STEPS = 200
TIMED_STEPS  = 5000
N_RUNS       = 3
N_VALUES     = [10, 50, 100, 500, 1000]


def load_benchmark_module(n: int):
    path = SIM_DIR / f"benchmark_N{n}.py"
    if not path.exists():
        raise FileNotFoundError(f"Benchmark script not found: {path}")
    spec = importlib.util.spec_from_file_location(f"benchmark_N{n}", path)
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    with open(OUTPUT, "a") as fid:
        for n in N_VALUES:
            print(f"=== cosivina-python  N={n} ===")

            try:
                mod = load_benchmark_module(n)
            except FileNotFoundError as exc:
                print(f"  SKIP: {exc}")
                continue

            # Build simulator and warm up
            sim = mod.create_sim()
            sim.init()
            for _ in range(WARMUP_STEPS):
                sim.step()

            for r in range(1, N_RUNS + 1):
                sim.init()
                t0 = time.perf_counter()
                for _ in range(TIMED_STEPS):
                    sim.step()
                elapsed = time.perf_counter() - t0
                sps = TIMED_STEPS / elapsed
                fid.write(f"cosivina-python,headless,{n},{r},{sps:.2f}\n")
                fid.flush()
                print(f"  headless  run={r}  {sps:.1f} steps/s")

    print(f"\nDone. Results appended to {OUTPUT}")


if __name__ == "__main__":
    main()
