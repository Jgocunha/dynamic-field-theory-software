# sim_033.py — type: selection
# Auto-generated. Do not edit manually.
# Run standalone:  python sim_033.py
# Or import and call run(output_dir).

import os
import sys
import numpy as np
from pathlib import Path

_COSIVINA_PYTHON_ROOT = Path(__file__).resolve().parents[4] / "cosivina_python"
if str(_COSIVINA_PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(_COSIVINA_PYTHON_ROOT))

# Variant selected by the runner via the COSIVINA_VARIANT env var ("numba" |
# "nonumba"); defaults to nonumba. The two variants share this file.
_variant = os.environ.get("COSIVINA_VARIANT", "nonumba")
_mod = __import__(
    "cosivina.numba" if _variant == "numba" else "cosivina.nonumba",
    fromlist=["Simulator", "GaussStimulus1D", "SumInputs",
              "NeuralField", "GaussKernel1D", "LateralInteractions1D"],
)
Simulator, GaussStimulus1D, SumInputs = _mod.Simulator, _mod.GaussStimulus1D, _mod.SumInputs
NeuralField, GaussKernel1D, LateralInteractions1D = _mod.NeuralField, _mod.GaussKernel1D, _mod.LateralInteractions1D

FIELD_SIZE = (1, 100)
TAU        = 25.0
BETA       = 100.0


def run(output_dir: str = r"C:/dev-files/dynamic-field-theory-software/cross-platform-validation/data/cosivina-python") -> None:
    sim = Simulator(deltaT=TAU)

    sim.addElement(
        GaussStimulus1D('stimulus 1', FIELD_SIZE,
                        sigma=5, amplitude=14.0, position=25,
                        circular=True, normalized=False))
    sim.addElement(
        GaussStimulus1D('stimulus 2', FIELD_SIZE,
                        sigma=5, amplitude=14.5, position=75,
                        circular=True, normalized=False))
    sim.addElement(SumInputs("stimulus sum", FIELD_SIZE), ['stimulus 1', 'stimulus 2'])
    sim.addElement(
        NeuralField("field u", FIELD_SIZE, tau=TAU, h=-10.0, beta=BETA),
        inputLabels="stimulus sum")
    sim.addElement(
        LateralInteractions1D('u->u', FIELD_SIZE,
                              sigmaExc=3, amplitudeExc=5.0,
                              sigmaInh=0.0, amplitudeInh=0.0,
                              amplitudeGlobal=-0.15,
                              circular=True, normalized=True),
        inputLabels='field u', inputComponents='output',
        targetLabels='field u')

    os.makedirs(output_dir, exist_ok=True)

    # Phase 1: stimulus ON — 500 steps
    sim.init()
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_033_sigmoid_b100_with_stimulus.csv"),
               [u[0]], delimiter=",", fmt="%.15g")

    # Phase 2: stimulus OFF — 500 steps
    sim.setElementParameters('stimulus 1', 'amplitude', 0.0)
    sim.setElementParameters('stimulus 2', 'amplitude', 0.0)
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_033_sigmoid_b100_without_stimulus.csv"),
               [u[0]], delimiter=",", fmt="%.15g")

    # Restore stimulus amplitudes
    sim.setElementParameters('stimulus 1', 'amplitude', 14.0)
    sim.setElementParameters('stimulus 2', 'amplitude', 14.5)
    sim.init()


if __name__ == "__main__":
    run()
