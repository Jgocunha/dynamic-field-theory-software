# benchmark_N500.py — cosivina-python benchmark setup, N=500 neural fields
# Called by cosivina_python_benchmark.py via create_sim().
# Do NOT add stepping code here — the runner controls all stepping.

import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[4] / "cosivina_python"
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

try:
    from cosivina.numba import (
        Simulator, GaussStimulus1D, NormalNoise,
        SumInputs, NeuralField, GaussKernel1D,
    )
except ImportError:
    from cosivina.nonumba import (
        Simulator, GaussStimulus1D, NormalNoise,
        SumInputs, NeuralField, GaussKernel1D,
    )

FIELD_SIZE = (1, 100)
N = 500


def create_sim():
    sim = Simulator(deltaT=25.)
    for i in range(1, N + 1):
        pos_i = int((2 * i - 1) * 100 / (2 * N))
        name_s   = f"stimulus_{i}"
        name_n   = f"noise_{i}"
        name_sum = f"sum_{i}"
        name_f   = f"field_{i}"
        name_k   = f"kernel_{i}"

        sim.addElement(GaussStimulus1D(name_s, FIELD_SIZE,
                                       sigma=5, amplitude=10.0, position=pos_i,
                                       circular=True, normalized=False))
        sim.addElement(NormalNoise(name_n, FIELD_SIZE, amplitude=0.))
        sim.addElement(SumInputs(name_sum, FIELD_SIZE), [name_s, name_n])
        sim.addElement(NeuralField(name_f, FIELD_SIZE, tau=25, h=-5.0, beta=100),
                       inputLabels=name_sum)
        sim.addElement(GaussKernel1D(name_k, FIELD_SIZE,
                                     sigma=3, amplitude=5.0,
                                     circular=True, normalized=True),
                       inputLabels=name_f, inputComponents="output",
                       targetLabels=name_f)
    return sim
