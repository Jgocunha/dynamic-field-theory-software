"""
cosivina_python_benchmark_2d.py
Benchmarks cosivina-python 2D DFT simulations (50x50) in headless mode.
Appends results to data/timings-cosivina-python-2d.csv.

Prerequisites:
  - cosivina-python installed or available at C:/dev-files/cosivina_python
  - Run from the benchmarking-2d/ root directory

Output rows (no header): cosivina-python,headless,<N>,<run>,<steps_per_second>

Usage:
  cd benchmarking-2d
  python runners/cosivina_python_benchmark_2d.py
"""

import os

# Pin all math-library thread pools to 1 BEFORE numpy/numba are imported (must precede
# any import that loads numpy). Guarantees the "single-threaded" benchmark claim.
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
           "NUMEXPR_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "NUMBA_NUM_THREADS"):
    os.environ[_v] = "1"

import sys
import time
from pathlib import Path

ROOT     = Path(__file__).resolve().parent.parent   # benchmarking-2d/
DATA_DIR = ROOT / "data"
OUTPUT   = DATA_DIR / "timings-cosivina-python-2d.csv"

_COSIVINA_ROOT = Path(__file__).resolve().parents[3] / "cosivina_python"
if str(_COSIVINA_ROOT) not in sys.path:
    sys.path.insert(0, str(_COSIVINA_ROOT))

try:
    from cosivina.numba import (
        Simulator, GaussStimulus2D, NormalNoise,
        SumInputs, NeuralField, GaussKernel2D, LateralInteractions2D,
    )
except ImportError:
    from cosivina.nonumba import (
        Simulator, GaussStimulus2D, NormalNoise,
        SumInputs, NeuralField, GaussKernel2D, LateralInteractions2D,
    )

FIELD_SIZE   = (50, 50)
WARMUP_STEPS = 200
TIMED_STEPS  = 5000
N_RUNS       = 10
N_VALUES     = [10, 50, 100, 500, 1000]

# Architecture definitions (2D) — representative validation sim of each band with
# the 2D amplitude adjustments from generate_simulations_2d.py (positions halved;
# selection kernel amp x4; memory exc/inh x2.5 + global -0.05).
#   stimuli: list of (amplitude, sigma, position)
#   kernel : ("gauss", sigma, amp, amp_global)
#         or ("mexican_hat", sigmaExc, ampExc, sigmaInh, ampInh, amp_global)
ARCHS = {
    "detection":    dict(h=-8.0,  stimuli=[(12.0, 5, 25)],
                         kernel=("gauss", 3, 8.0, 0.0)),
    "selection":    dict(h=-10.0, stimuli=[(10.0, 5, 12.5), (10.5, 5, 37.5)],
                         kernel=("gauss", 3, 20.0, -0.15)),
    "memory":       dict(h=-5.0,  stimuli=[(15.0, 5, 25)],
                         kernel=("mexican_hat", 3.4, 44.25, 8.9, 33.75, -0.05)),
    "insufficient": dict(h=-12.0, stimuli=[(5.0, 5, 25)],
                         kernel=("gauss", 3, 3.0, 0.0)),
    "multi-peak":   dict(h=-8.0,  stimuli=[(12.0, 5, 12.5), (12.0, 5, 37.5)],
                         kernel=("gauss", 2, 5.0, 0.0)),
}


def create_sim(n: int, arch: dict):
    """Build a Simulator with `n` independent 50x50 fields of the given architecture."""
    sim = Simulator(deltaT=25.)
    for i in range(1, n + 1):
        name_s_list = []
        for s, (amp, sigma, pos) in enumerate(arch["stimuli"]):
            name_s = f"stimulus_{i}_{s}"
            name_s_list.append(name_s)
            sim.addElement(GaussStimulus2D(name_s, FIELD_SIZE,
                                           sigmaY=sigma, sigmaX=sigma, amplitude=amp,
                                           positionY=pos, positionX=pos,
                                           circularY=True, circularX=True, normalized=False))
        name_n   = f"noise_{i}"
        name_sum = f"sum_{i}"
        name_f   = f"field_{i}"
        name_k   = f"kernel_{i}"

        sim.addElement(NormalNoise(name_n, FIELD_SIZE, amplitude=0.))
        sim.addElement(SumInputs(name_sum, FIELD_SIZE), name_s_list + [name_n])
        sim.addElement(NeuralField(name_f, FIELD_SIZE, tau=25, h=arch["h"], beta=100),
                       inputLabels=name_sum)

        k = arch["kernel"]
        if k[0] == "gauss" and k[3] == 0.0:
            sim.addElement(GaussKernel2D(name_k, FIELD_SIZE,
                                         sigmaY=k[1], sigmaX=k[1], amplitude=k[2],
                                         circularY=True, circularX=True, normalized=True),
                           inputLabels=name_f, inputComponents="output",
                           targetLabels=name_f)
        elif k[0] == "gauss":
            sim.addElement(LateralInteractions2D(name_k, FIELD_SIZE,
                                                 sigmaExcY=k[1], sigmaExcX=k[1], amplitudeExc=k[2],
                                                 sigmaInhY=0.0, sigmaInhX=0.0, amplitudeInh=0.0,
                                                 amplitudeGlobal=k[3],
                                                 circularY=True, circularX=True, normalized=True),
                           inputLabels=name_f, inputComponents="output",
                           targetLabels=name_f)
        else:  # mexican_hat: (type, sigmaExc, ampExc, sigmaInh, ampInh, amp_global)
            sim.addElement(LateralInteractions2D(name_k, FIELD_SIZE,
                                                 sigmaExcY=k[1], sigmaExcX=k[1], amplitudeExc=k[2],
                                                 sigmaInhY=k[3], sigmaInhX=k[3], amplitudeInh=k[4],
                                                 amplitudeGlobal=k[5],
                                                 circularY=True, circularX=True, normalized=True),
                           inputLabels=name_f, inputComponents="output",
                           targetLabels=name_f)
    return sim


def main():
    # Usage: cosivina_python_benchmark_2d.py [arch] [N_csv]
    arch_name = sys.argv[1] if len(sys.argv) > 1 else "detection"
    if arch_name not in ARCHS:
        print(f"Unknown arch '{arch_name}'; defaulting to detection")
        arch_name = "detection"
    arch = ARCHS[arch_name]
    n_values = ([int(x) for x in sys.argv[2].split(",") if x]
                if len(sys.argv) > 2 else N_VALUES)

    DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Report the pinned thread environment for reproducibility.
    print("Thread pinning:", {v: os.environ.get(v) for v in
          ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "NUMBA_NUM_THREADS")})
    try:
        import numba
        print(f"numba {numba.__version__}, NUMBA_NUM_THREADS effective = {numba.get_num_threads()}")
    except Exception:
        pass

    print(f"cosivina-python 2D headless benchmark [arch={arch_name}] -> {OUTPUT}")

    with open(OUTPUT, "a") as fid:
        for n in n_values:
            print(f"=== cosivina-python 2D  {arch_name}  N={n} ===")

            sim = create_sim(n, arch)
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
                fid.write(f"cosivina-python,{arch_name},headless,{n},{r},{sps:.2f}\n")
                fid.flush()
                print(f"  headless  run={r}  {sps:.1f} steps/s")

    print(f"\nDone. Results appended to {OUTPUT}")


if __name__ == "__main__":
    main()
