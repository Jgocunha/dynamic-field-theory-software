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

import os

# Pin all math-library thread pools to 1 BEFORE numpy/numba are imported (must precede
# any import that loads numpy). Guarantees the "single-threaded" benchmark claim.
for _v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
           "NUMEXPR_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "NUMBA_NUM_THREADS"):
    os.environ[_v] = "1"

import sys
import time
from pathlib import Path

ROOT     = Path(__file__).resolve().parent.parent   # benchmarking/
DATA_DIR = ROOT / "data"
OUTPUT   = DATA_DIR / "timings-cosivina-python.csv"

_COSIVINA_ROOT = Path(__file__).resolve().parents[3] / "cosivina_python"
if str(_COSIVINA_ROOT) not in sys.path:
    sys.path.insert(0, str(_COSIVINA_ROOT))


def load_cosivina(variant: str):
    """Import the cosivina element classes from the chosen variant module
    (`numba` JIT path or `nonumba` pure-Python/NumPy path) and bind them as
    module globals so create_sim() can use them. Explicit selection — NOT a
    silent fallback — so the two paths are measured as distinct variants."""
    module = "cosivina.numba" if variant == "numba" else "cosivina.nonumba"
    mod = __import__(module, fromlist=[
        "Simulator", "GaussStimulus1D", "NormalNoise",
        "SumInputs", "NeuralField", "GaussKernel1D", "LateralInteractions1D",
    ])
    for name in ("Simulator", "GaussStimulus1D", "NormalNoise",
                 "SumInputs", "NeuralField", "GaussKernel1D", "LateralInteractions1D"):
        globals()[name] = getattr(mod, name)


FIELD_SIZE   = (1, 100)
WARMUP_STEPS = 200
TIMED_STEPS  = 5000
N_RUNS       = 10
N_VALUES     = [10, 50, 100]

# Architecture definitions — reuse the representative validation sim of each band
# (detection 001, selection 021, memory 041, insufficient 061, multi-peak 081).
# Matches the dnfc/Cedar benchmark Arch set and the validation generator's
# cosivina-python pattern (GaussKernel1D for plain Gauss; LateralInteractions1D
# for global inhibition and Mexican-hat).
#   stimuli: list of (amplitude, sigma, position)
#   kernel : ("gauss", sigma, amp, amp_global)
#         or ("mexican_hat", sigmaExc, ampExc, sigmaInh, ampInh)
ARCHS = {
    "detection":    dict(h=-8.0,  stimuli=[(12.0, 5, 50)],
                         kernel=("gauss", 3, 8.0, 0.0)),
    "selection":    dict(h=-10.0, stimuli=[(10.0, 5, 25), (10.5, 5, 75)],
                         kernel=("gauss", 3, 5.0, -0.15)),
    "memory":       dict(h=-5.0,  stimuli=[(15.0, 5, 50)],
                         kernel=("mexican_hat", 3.4, 17.7, 8.9, 13.5)),
    "insufficient": dict(h=-12.0, stimuli=[(5.0, 5, 50)],
                         kernel=("gauss", 3, 3.0, 0.0)),
    "multi-peak":   dict(h=-8.0,  stimuli=[(12.0, 5, 25), (12.0, 5, 75)],
                         kernel=("gauss", 2, 5.0, 0.0)),
}


def create_sim(n: int, arch: dict):
    """Build a Simulator with `n` independent fields of the given architecture."""
    sim = Simulator(deltaT=25.)
    for i in range(1, n + 1):
        name_s_list = []
        for s, (amp, sigma, pos) in enumerate(arch["stimuli"]):
            name_s = f"stimulus_{i}_{s}"
            name_s_list.append(name_s)
            sim.addElement(GaussStimulus1D(name_s, FIELD_SIZE,
                                           sigma=sigma, amplitude=amp, position=pos,
                                           circular=True, normalized=False))
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
            sim.addElement(GaussKernel1D(name_k, FIELD_SIZE,
                                         sigma=k[1], amplitude=k[2],
                                         circular=True, normalized=True),
                           inputLabels=name_f, inputComponents="output",
                           targetLabels=name_f)
        elif k[0] == "gauss":
            sim.addElement(LateralInteractions1D(name_k, FIELD_SIZE,
                                                 sigmaExc=k[1], amplitudeExc=k[2],
                                                 sigmaInh=0.0, amplitudeInh=0.0,
                                                 amplitudeGlobal=k[3],
                                                 circular=True, normalized=True),
                           inputLabels=name_f, inputComponents="output",
                           targetLabels=name_f)
        else:  # mexican_hat
            sim.addElement(LateralInteractions1D(name_k, FIELD_SIZE,
                                                 sigmaExc=k[1], amplitudeExc=k[2],
                                                 sigmaInh=k[3], amplitudeInh=k[4],
                                                 amplitudeGlobal=0.0,
                                                 circular=True, normalized=True),
                           inputLabels=name_f, inputComponents="output",
                           targetLabels=name_f)
    return sim


def main():
    # Usage: cosivina_python_benchmark.py [arch] [variant] [N_csv]
    #   arch     detection|selection|memory|insufficient|multi-peak (default detection)
    #   variant  numba|nonumba  (default numba)
    #   N_csv    comma-separated field counts (default 10,50,100)
    arch_name = sys.argv[1] if len(sys.argv) > 1 else "detection"
    if arch_name not in ARCHS:
        print(f"Unknown arch '{arch_name}'; defaulting to detection")
        arch_name = "detection"
    arch = ARCHS[arch_name]
    variant = sys.argv[2] if len(sys.argv) > 2 else "numba"
    if variant not in ("numba", "nonumba"):
        print(f"Unknown variant '{variant}'; defaulting to numba")
        variant = "numba"
    n_values = ([int(x) for x in sys.argv[3].split(",") if x]
                if len(sys.argv) > 3 else N_VALUES)

    load_cosivina(variant)

    DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Report the pinned thread environment for reproducibility.
    print("Thread pinning:", {v: os.environ.get(v) for v in
          ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "NUMBA_NUM_THREADS")})
    if variant == "numba":
        try:
            import numba
            print(f"numba {numba.__version__}, NUMBA_NUM_THREADS effective = {numba.get_num_threads()}")
        except Exception:
            pass

    print(f"cosivina-python headless benchmark [arch={arch_name} variant={variant}] -> {OUTPUT}")

    with open(OUTPUT, "a") as fid:
        for n in n_values:
            print(f"=== cosivina-python/{variant}  {arch_name}  N={n} ===")

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
                fid.write(f"cosivina-python,{variant},{arch_name},headless,{n},{r},{sps:.2f}\n")
                fid.flush()
                print(f"  headless  run={r}  {sps:.1f} steps/s")

    print(f"\nDone. Results appended to {OUTPUT}")


if __name__ == "__main__":
    main()
