# sim_055.py (2D) — type: memory
# Auto-generated. Do not edit manually.

import os
import sys
import numpy as np
from pathlib import Path

_COSIVINA_PYTHON_ROOT = Path(__file__).resolve().parents[4] / "cosivina_python"
if str(_COSIVINA_PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(_COSIVINA_PYTHON_ROOT))

from cosivina.nonumba import (
    Simulator, GaussStimulus2D, SumInputs,
    NeuralField, GaussKernel2D, LateralInteractions2D,
)

FIELD_SIZE = (50, 50)
TAU        = 25.0
BETA       = 100.0


def run(output_dir: str = r"C:/dev-files/dynamic-field-theory-software/cross-platform-validation-2d/data/cosivina-python") -> None:
    sim = Simulator(deltaT=TAU)

    sim.addElement(
        GaussStimulus2D('stimulus', FIELD_SIZE,
                        sigmaY=5, sigmaX=5, amplitude=15.0,
                        positionY=25.0, positionX=25.0,
                        circularY=True, circularX=True, normalized=False))
    sim.addElement(SumInputs("stimulus sum", FIELD_SIZE), 'stimulus')
    sim.addElement(
        NeuralField("field u", FIELD_SIZE, tau=TAU, h=-5.0, beta=BETA),
        inputLabels="stimulus sum")
    sim.addElement(
        LateralInteractions2D('u->u', FIELD_SIZE,
                              sigmaExcY=3.4, sigmaExcX=3.4, amplitudeExc=44.25,
                              sigmaInhY=8.9, sigmaInhX=8.9, amplitudeInh=40.0,
                              amplitudeGlobal=-0.05,
                              circularY=True, circularX=True, normalized=True),
        inputLabels='field u', inputComponents='output',
        targetLabels='field u')

    os.makedirs(output_dir, exist_ok=True)

    # Phase 1: stimulus ON — 500 steps
    sim.init()
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_055_sigmoid_b100_with_stimulus.csv"),
               [u.ravel()], delimiter=",", fmt="%.15g")

    # Phase 2: stimulus OFF — 500 steps
    sim.setElementParameters('stimulus', 'amplitude', 0.0)
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_055_sigmoid_b100_without_stimulus.csv"),
               [u.ravel()], delimiter=",", fmt="%.15g")

    # Restore stimulus amplitudes
    sim.setElementParameters('stimulus', 'amplitude', 15.0)
    sim.init()


if __name__ == "__main__":
    run()
