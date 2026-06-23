# sim_061.py — type: insufficient
# Auto-generated. Do not edit manually.
# Run standalone:  python sim_061.py
# Or import and call run(output_dir).

import os
import sys
import numpy as np
from pathlib import Path

_COSIVINA_PYTHON_ROOT = Path(__file__).resolve().parents[4] / "cosivina_python"
if str(_COSIVINA_PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(_COSIVINA_PYTHON_ROOT))

from cosivina.nonumba import (
    Simulator, GaussStimulus1D, SumInputs,
    NeuralField, GaussKernel1D, LateralInteractions1D,
)

FIELD_SIZE = (1, 100)
TAU        = 25.0
BETA       = 100.0


def run(output_dir: str = r"C:/dev-files/dynamic-field-theory-software/cross-platform-validation/data/cosivina-python") -> None:
    sim = Simulator(deltaT=TAU)

    sim.addElement(
        GaussStimulus1D('stimulus', FIELD_SIZE,
                        sigma=5, amplitude=5.0, position=50,
                        circular=True, normalized=False))
    sim.addElement(SumInputs("stimulus sum", FIELD_SIZE), 'stimulus')
    sim.addElement(
        NeuralField("field u", FIELD_SIZE, tau=TAU, h=-12.0, beta=BETA),
        inputLabels="stimulus sum")
    sim.addElement(
        GaussKernel1D('u->u', FIELD_SIZE,
                      sigma=3, amplitude=3.0,
                      circular=True, normalized=True),
        inputLabels='field u', inputComponents='output',
        targetLabels='field u')

    os.makedirs(output_dir, exist_ok=True)

    # Phase 1: stimulus ON — 500 steps
    sim.init()
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_061_sigmoid_b100_with_stimulus.csv"),
               [u[0]], delimiter=",", fmt="%.15g")

    # Phase 2: stimulus OFF — 500 steps
    sim.setElementParameters('stimulus', 'amplitude', 0.0)
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_061_sigmoid_b100_without_stimulus.csv"),
               [u[0]], delimiter=",", fmt="%.15g")

    # Restore stimulus amplitudes
    sim.setElementParameters('stimulus', 'amplitude', 5.0)
    sim.init()


if __name__ == "__main__":
    run()
