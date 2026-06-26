# benchmark_N50.py (2D) — cosivina-python benchmark setup, N=50 fields (50x50)
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
N = 50

# stimulus centers tiled across the 50x50 grid
CENTERS = [(3.1250, 3.5714), (9.3750, 3.5714), (15.6250, 3.5714), (21.8750, 3.5714), (28.1250, 3.5714), (34.3750, 3.5714), (40.6250, 3.5714), (46.8750, 3.5714), (3.1250, 10.7143), (9.3750, 10.7143), (15.6250, 10.7143), (21.8750, 10.7143), (28.1250, 10.7143), (34.3750, 10.7143), (40.6250, 10.7143), (46.8750, 10.7143), (3.1250, 17.8571), (9.3750, 17.8571), (15.6250, 17.8571), (21.8750, 17.8571), (28.1250, 17.8571), (34.3750, 17.8571), (40.6250, 17.8571), (46.8750, 17.8571), (3.1250, 25.0000), (9.3750, 25.0000), (15.6250, 25.0000), (21.8750, 25.0000), (28.1250, 25.0000), (34.3750, 25.0000), (40.6250, 25.0000), (46.8750, 25.0000), (3.1250, 32.1429), (9.3750, 32.1429), (15.6250, 32.1429), (21.8750, 32.1429), (28.1250, 32.1429), (34.3750, 32.1429), (40.6250, 32.1429), (46.8750, 32.1429), (3.1250, 39.2857), (9.3750, 39.2857), (15.6250, 39.2857), (21.8750, 39.2857), (28.1250, 39.2857), (34.3750, 39.2857), (40.6250, 39.2857), (46.8750, 39.2857), (3.1250, 46.4286), (9.3750, 46.4286)]


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
