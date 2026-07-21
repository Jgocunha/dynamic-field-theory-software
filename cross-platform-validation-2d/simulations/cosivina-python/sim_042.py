# sim_042.py (2D) — type: memory
# Auto-generated. Do not edit manually.

import os
import sys
import numpy as np
from pathlib import Path

_COSIVINA_PYTHON_ROOT = Path(__file__).resolve().parents[4] / "cosivina_python"
if str(_COSIVINA_PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(_COSIVINA_PYTHON_ROOT))

# Variant selected by the runner via the COSIVINA_VARIANT env var ("numba" |
# "nonumba" | "fft"); defaults to nonumba for standalone execution. All variants
# share this file — the numba/nonumba variants use the spatial kernel element and
# the matching backend; the fft variant uses the spectral KernelFFT element, which
# has no numba path and so always runs on the nonumba backend.
_variant = os.environ.get("COSIVINA_VARIANT", "nonumba")
_mod = __import__(
    "cosivina.numba" if _variant == "numba" else "cosivina.nonumba",
    fromlist=["Simulator", "GaussStimulus2D", "SumInputs",
              "NeuralField", "GaussKernel2D", "LateralInteractions2D", "KernelFFT"],
)
Simulator, GaussStimulus2D, SumInputs = _mod.Simulator, _mod.GaussStimulus2D, _mod.SumInputs
NeuralField, GaussKernel2D, LateralInteractions2D = _mod.NeuralField, _mod.GaussKernel2D, _mod.LateralInteractions2D
KernelFFT = _mod.KernelFFT

FIELD_SIZE = (50, 50)
TAU        = 25.0
BETA       = 100.0


def run(output_dir: str = r"C:/dev-files/dynamic-field-theory-software/cross-platform-validation-2d/data/cosivina-python") -> None:
    sim = Simulator(deltaT=TAU)

    sim.addElement(
        GaussStimulus2D('stimulus', FIELD_SIZE,
                        sigmaY=5, sigmaX=5, amplitude=12.0,
                        positionY=25.0, positionX=25.0,
                        circularY=True, circularX=True, normalized=False))
    sim.addElement(SumInputs("stimulus sum", FIELD_SIZE), 'stimulus')
    sim.addElement(
        NeuralField("field u", FIELD_SIZE, tau=TAU, h=-5.0, beta=BETA),
        inputLabels="stimulus sum")
    if _variant == "fft":
        sim.addElement(
            KernelFFT('u->u', FIELD_SIZE,
                      sigmaExc=[3.4, 3.4], amplitudeExc=44.25,
                      sigmaInh=[8.9, 8.9], amplitudeInh=33.75,
                      amplitudeGlobal=-0.05,
                      circular=[True, True], normalized=True),
            inputLabels='field u', inputComponents='output',
            targetLabels='field u')
    else:
        sim.addElement(
            LateralInteractions2D('u->u', FIELD_SIZE,
                                  sigmaExcY=3.4, sigmaExcX=3.4, amplitudeExc=44.25,
                                  sigmaInhY=8.9, sigmaInhX=8.9, amplitudeInh=33.75,
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
    np.savetxt(os.path.join(output_dir, "sim_042_sigmoid_b100_with_stimulus.csv"),
               [u.ravel()], delimiter=",", fmt="%.15g")

    # Phase 2: stimulus OFF — 500 steps
    sim.setElementParameters('stimulus', 'amplitude', 0.0)
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_042_sigmoid_b100_without_stimulus.csv"),
               [u.ravel()], delimiter=",", fmt="%.15g")

    # Restore stimulus amplitudes
    sim.setElementParameters('stimulus', 'amplitude', 12.0)
    sim.init()


if __name__ == "__main__":
    run()
