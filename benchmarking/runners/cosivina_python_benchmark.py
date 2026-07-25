"""
cosivina_python_benchmark.py
Benchmarks cosivina-python DFT simulations in headless mode.
Appends results to data/timings-cosivina-python.csv.

Prerequisites:
  - cosivina-python installed or available at C:/dev-files/cosivina_python
  - Run from the benchmarking/ root directory

Output rows (no header, 8 columns):
  cosivina-python,<variant>,<arch>,<field_size>,headless,<N>,<run>,<steps_per_second>

Usage:
  cd benchmarking
  python runners/cosivina_python_benchmark.py [arch] [variant] [N_csv] [field_size]
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
    silent fallback — so the paths are measured as distinct variants. The `fft`
    variant uses the spectral KernelFFT element (no numba path) on the nonumba
    backend."""
    module = "cosivina.numba" if variant == "numba" else "cosivina.nonumba"
    names = ["Simulator", "GaussStimulus1D", "NormalNoise",
             "SumInputs", "NeuralField", "GaussKernel1D", "LateralInteractions1D",
             "KernelFFT"]
    mod = __import__(module, fromlist=names)
    for name in names:
        globals()[name] = getattr(mod, name)


BASE_SIZE    = 100     # reference grid the arch positions are defined on
NOISE_AMP    = 0.1     # benchmark uses A>0 so the RNG cost is measured
WARMUP_STEPS = 200
TIMED_STEPS  = 2000
N_RUNS       = 5
N_VALUES     = [5, 10, 50, 100]

# Architecture definitions — reuse the representative validation sim of each band
# (detection 001, selection 021, memory 041, multi-peak 081). Matches the
# dnfc/Cedar benchmark Arch set and the validation generator's cosivina-python
# pattern (GaussKernel1D for plain Gauss; LateralInteractions1D for global
# inhibition and Mexican-hat).
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
    "multi-peak":   dict(h=-8.0,  stimuli=[(12.0, 5, 25), (12.0, 5, 75)],
                         kernel=("gauss", 2, 5.0, 0.0)),
}


def create_sim(n: int, arch: dict, field_size: int, variant: str = "numba"):
    """Build a Simulator with `n` independent fields of the given architecture."""
    fs = (1, field_size)
    pos_scale = field_size / BASE_SIZE
    sim = Simulator(deltaT=25.)
    for i in range(1, n + 1):
        name_s_list = []
        for s, (amp, sigma, pos) in enumerate(arch["stimuli"]):
            name_s = f"stimulus_{i}_{s}"
            name_s_list.append(name_s)
            sim.addElement(GaussStimulus1D(name_s, fs,
                                           sigma=sigma, amplitude=amp, position=pos * pos_scale,
                                           circular=True, normalized=False))
        name_n   = f"noise_{i}"
        name_sum = f"sum_{i}"
        name_f   = f"field_{i}"
        name_k   = f"kernel_{i}"

        sim.addElement(NormalNoise(name_n, fs, amplitude=NOISE_AMP))
        sim.addElement(SumInputs(name_sum, fs), name_s_list + [name_n])
        sim.addElement(NeuralField(name_f, fs, tau=25, h=arch["h"], beta=100),
                       inputLabels=name_sum)

        k = arch["kernel"]
        if variant == "fft":
            # Spectral KernelFFT element: full-field (untruncated) FFT convolution.
            if k[0] == "gauss":
                sim.addElement(KernelFFT(name_k, fs,
                                         sigmaExc=k[1], amplitudeExc=k[2],
                                         amplitudeInh=0.0, amplitudeGlobal=k[3],
                                         circular=True, normalized=True),
                               inputLabels=name_f, inputComponents="output",
                               targetLabels=name_f)
            else:  # mexican_hat
                sim.addElement(KernelFFT(name_k, fs,
                                         sigmaExc=k[1], amplitudeExc=k[2],
                                         sigmaInh=k[3], amplitudeInh=k[4],
                                         amplitudeGlobal=0.0,
                                         circular=True, normalized=True),
                               inputLabels=name_f, inputComponents="output",
                               targetLabels=name_f)
        elif k[0] == "gauss" and k[3] == 0.0:
            sim.addElement(GaussKernel1D(name_k, fs,
                                         sigma=k[1], amplitude=k[2],
                                         circular=True, normalized=True),
                           inputLabels=name_f, inputComponents="output",
                           targetLabels=name_f)
        elif k[0] == "gauss":
            sim.addElement(LateralInteractions1D(name_k, fs,
                                                 sigmaExc=k[1], amplitudeExc=k[2],
                                                 sigmaInh=0.0, amplitudeInh=0.0,
                                                 amplitudeGlobal=k[3],
                                                 circular=True, normalized=True),
                           inputLabels=name_f, inputComponents="output",
                           targetLabels=name_f)
        else:  # mexican_hat
            sim.addElement(LateralInteractions1D(name_k, fs,
                                                 sigmaExc=k[1], amplitudeExc=k[2],
                                                 sigmaInh=k[3], amplitudeInh=k[4],
                                                 amplitudeGlobal=0.0,
                                                 circular=True, normalized=True),
                           inputLabels=name_f, inputComponents="output",
                           targetLabels=name_f)
    return sim


def establish_then_remove_stimulus(stimuli, sim):
    """For "memory": establish the bump with the stimulus on for 100 steps, then
    remove it — the timed measurement covers genuine self-sustained memory
    maintenance, not stimulus-driven activity.
    sim.init() (called once per run, right before this) rebuilds every element's
    output from its current attributes, including GaussStimulus1D.output from its
    (untouched) amplitude — so the stimulus is correctly re-established for free at
    the top of each run. Downstream elements (e.g. SumInputs) cache a direct
    reference to that output ARRAY OBJECT at sim.init() time (Simulator.init():
    `el.inputs.append(getattr(ie, ...))`), so removing the stimulus must mutate the
    array IN PLACE (stim.output[:] = 0) rather than reassign stim.output — a
    reassignment would silently stop propagating to already-wired consumers."""
    for _ in range(100):
        sim.step()
    for stim in stimuli:
        stim.output[:] = 0.0


def main():
    # Usage: cosivina_python_benchmark.py [arch] [variant] [N_csv] [field_size]
    #   arch        detection|selection|memory|multi-peak (default detection)
    #   variant     numba|nonumba  (default numba)
    #   N_csv       comma-separated field counts (default 5,10,50,100)
    #   field_size  field length (default 100)
    arch_name = sys.argv[1] if len(sys.argv) > 1 else "detection"
    if arch_name not in ARCHS:
        print(f"Unknown arch '{arch_name}'; defaulting to detection")
        arch_name = "detection"
    arch = ARCHS[arch_name]
    variant = sys.argv[2] if len(sys.argv) > 2 else "numba"
    if variant not in ("numba", "nonumba", "fft"):
        print(f"Unknown variant '{variant}'; defaulting to numba")
        variant = "numba"
    n_values = ([int(x) for x in sys.argv[3].split(",") if x]
                if len(sys.argv) > 3 else N_VALUES)
    field_size = int(sys.argv[4]) if len(sys.argv) > 4 else BASE_SIZE

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

    print(f"cosivina-python headless benchmark [arch={arch_name} variant={variant} fs={field_size}] -> {OUTPUT}")

    with open(OUTPUT, "a") as fid:
        for n in n_values:
            print(f"=== cosivina-python/{variant}  {arch_name}  fs={field_size}  N={n} ===")

            sim = create_sim(n, arch, field_size, variant)

            stimuli = []
            if arch_name == "memory":
                stimuli = [el for el in sim.elements if isinstance(el, GaussStimulus1D)]

            sim.init()
            if arch_name == "memory":
                # Establish-then-remove before warm-up too (matches the Cedar driver), so
                # the discarded warm-up steps reflect the same post-establish state the
                # timed runs start from, rather than the stimulus sitting at its initial value.
                establish_then_remove_stimulus(stimuli, sim)
            for _ in range(WARMUP_STEPS):
                sim.step()

            for r in range(1, N_RUNS + 1):
                sim.init()
                if arch_name == "memory":
                    establish_then_remove_stimulus(stimuli, sim)
                t0 = time.perf_counter()
                for _ in range(TIMED_STEPS):
                    sim.step()
                elapsed = time.perf_counter() - t0
                sps = TIMED_STEPS / elapsed
                fid.write(f"cosivina-python,{variant},{arch_name},{field_size},headless,{n},{r},{sps:.2f}\n")
                fid.flush()
                print(f"  headless  run={r}  {sps:.1f} steps/s")

    print(f"\nDone. Results appended to {OUTPUT}")


if __name__ == "__main__":
    main()
