# benchmark_N100.py (2D) — cosivina-python benchmark setup, N=100 fields (50x50)
# Called by cosivina_python_benchmark_2d.py via create_sim().
# Do NOT add stepping code here — the runner controls all stepping.

import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[4] / "cosivina_python"
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

try:
    from cosivina.numba import (
        Simulator, GaussStimulus2D, NormalNoise,
        SumInputs, NeuralField, GaussKernel2D,
    )
except ImportError:
    from cosivina.nonumba import (
        Simulator, GaussStimulus2D, NormalNoise,
        SumInputs, NeuralField, GaussKernel2D,
    )

FIELD_SIZE = (50, 50)
N = 100

# stimulus centers tiled across the 50x50 grid
CENTERS = [(2.5000, 2.5000), (7.5000, 2.5000), (12.5000, 2.5000), (17.5000, 2.5000), (22.5000, 2.5000), (27.5000, 2.5000), (32.5000, 2.5000), (37.5000, 2.5000), (42.5000, 2.5000), (47.5000, 2.5000), (2.5000, 7.5000), (7.5000, 7.5000), (12.5000, 7.5000), (17.5000, 7.5000), (22.5000, 7.5000), (27.5000, 7.5000), (32.5000, 7.5000), (37.5000, 7.5000), (42.5000, 7.5000), (47.5000, 7.5000), (2.5000, 12.5000), (7.5000, 12.5000), (12.5000, 12.5000), (17.5000, 12.5000), (22.5000, 12.5000), (27.5000, 12.5000), (32.5000, 12.5000), (37.5000, 12.5000), (42.5000, 12.5000), (47.5000, 12.5000), (2.5000, 17.5000), (7.5000, 17.5000), (12.5000, 17.5000), (17.5000, 17.5000), (22.5000, 17.5000), (27.5000, 17.5000), (32.5000, 17.5000), (37.5000, 17.5000), (42.5000, 17.5000), (47.5000, 17.5000), (2.5000, 22.5000), (7.5000, 22.5000), (12.5000, 22.5000), (17.5000, 22.5000), (22.5000, 22.5000), (27.5000, 22.5000), (32.5000, 22.5000), (37.5000, 22.5000), (42.5000, 22.5000), (47.5000, 22.5000), (2.5000, 27.5000), (7.5000, 27.5000), (12.5000, 27.5000), (17.5000, 27.5000), (22.5000, 27.5000), (27.5000, 27.5000), (32.5000, 27.5000), (37.5000, 27.5000), (42.5000, 27.5000), (47.5000, 27.5000), (2.5000, 32.5000), (7.5000, 32.5000), (12.5000, 32.5000), (17.5000, 32.5000), (22.5000, 32.5000), (27.5000, 32.5000), (32.5000, 32.5000), (37.5000, 32.5000), (42.5000, 32.5000), (47.5000, 32.5000), (2.5000, 37.5000), (7.5000, 37.5000), (12.5000, 37.5000), (17.5000, 37.5000), (22.5000, 37.5000), (27.5000, 37.5000), (32.5000, 37.5000), (37.5000, 37.5000), (42.5000, 37.5000), (47.5000, 37.5000), (2.5000, 42.5000), (7.5000, 42.5000), (12.5000, 42.5000), (17.5000, 42.5000), (22.5000, 42.5000), (27.5000, 42.5000), (32.5000, 42.5000), (37.5000, 42.5000), (42.5000, 42.5000), (47.5000, 42.5000), (2.5000, 47.5000), (7.5000, 47.5000), (12.5000, 47.5000), (17.5000, 47.5000), (22.5000, 47.5000), (27.5000, 47.5000), (32.5000, 47.5000), (37.5000, 47.5000), (42.5000, 47.5000), (47.5000, 47.5000)]


def create_sim():
    sim = Simulator(deltaT=25.)
    for i in range(1, N + 1):
        px, py = CENTERS[i - 1]
        name_s   = f"stimulus_{i}"
        name_n   = f"noise_{i}"
        name_sum = f"sum_{i}"
        name_f   = f"field_{i}"
        name_k   = f"kernel_{i}"

        sim.addElement(GaussStimulus2D(name_s, FIELD_SIZE,
                                       sigmaY=5, sigmaX=5, amplitude=10.0,
                                       positionY=py, positionX=px,
                                       circularY=True, circularX=True, normalized=False))
        sim.addElement(NormalNoise(name_n, FIELD_SIZE, amplitude=0.))
        sim.addElement(SumInputs(name_sum, FIELD_SIZE), [name_s, name_n])
        sim.addElement(NeuralField(name_f, FIELD_SIZE, tau=25, h=-5.0, beta=100),
                       inputLabels=name_sum)
        sim.addElement(GaussKernel2D(name_k, FIELD_SIZE,
                                     sigmaY=3, sigmaX=3, amplitude=5.0,
                                     circularY=True, circularX=True, normalized=True),
                       inputLabels=name_f, inputComponents="output",
                       targetLabels=name_f)
    return sim
