"""
cosivina_python_runner.py
Runs all 100 cross-platform-validation simulations using cosivina-python
and saves activation profiles to data/cosivina-python/.

Each simulation follows the two-phase protocol:
  Phase 1: 500 steps (stimulus ON)  → sim_NNN_sigmoid_b100_with_stimulus.csv
  Phase 2: 500 steps (stimulus OFF) → sim_NNN_sigmoid_b100_without_stimulus.csv

Output CSVs: single row, 100 comma-separated float values (raw activation u).

Usage (from cross-platform-validation/):
  python runners/cosivina_python_runner.py
"""

import os
import sys
import numpy as np
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "cosivina_python"))

from cosivina.nonumba import (
    Simulator,
    GaussStimulus1D,
    SumInputs,
    NeuralField,
    GaussKernel1D,
    LateralInteractions1D,
)

# ---------------------------------------------------------------------------
# Parameter table (matches generate_simulations.py exactly)
# ---------------------------------------------------------------------------

SIMS = []

# ── Detection (001–020) ─────────────────────────────────────────────────────
det_params = [
    (-8.0,  12.0, 5, 50, 8.0, 3),
    (-8.0,  10.0, 5, 50, 8.0, 3),
    (-8.0,  14.0, 5, 50, 8.0, 3),
    (-9.0,  12.0, 5, 50, 8.0, 3),
    (-7.0,  12.0, 5, 50, 8.0, 3),
    (-8.0,  12.0, 3, 50, 8.0, 3),
    (-8.0,  12.0, 7, 50, 8.0, 3),
    (-8.0,  12.0, 5, 25, 8.0, 3),
    (-8.0,  12.0, 5, 75, 8.0, 3),
    (-8.0,  12.0, 5, 50, 6.0, 3),
    (-8.0,  12.0, 5, 50, 10.0, 3),
    (-8.0,  12.0, 5, 50, 8.0, 2),
    (-8.0,  12.0, 5, 50, 8.0, 4),
    (-8.0,  12.0, 5, 50, 8.0, 5),
    (-9.0,  14.0, 5, 50, 8.0, 3),
    (-7.0,  10.0, 5, 50, 8.0, 3),
    (-8.0,  12.0, 5, 33, 8.0, 3),
    (-8.0,  12.0, 5, 67, 8.0, 3),
    (-8.0,  15.0, 4, 50, 7.0, 4),
    (-10.0, 16.0, 6, 50, 9.0, 3),
]
for i, (h, sa, ss, sp, ka, ks) in enumerate(det_params, 1):
    SIMS.append({"id": f"{i:03d}", "type": "detection", "h": h,
                 "stimuli": [{"amp": sa, "sigma": ss, "pos": sp}],
                 "kernel": {"type": "gauss", "sigma": ks, "amp": ka, "amp_global": 0.0}})

# ── Selection (021–040) ─────────────────────────────────────────────────────
sel_params = [
    (-10.0, 10.0, 25, 10.5, 75, 5.0, 3, -0.15),
    (-10.0, 10.0, 25, 11.0, 75, 5.0, 3, -0.15),
    (-10.0, 12.0, 25, 12.5, 75, 5.0, 3, -0.15),
    (-10.0, 10.0, 30, 10.5, 70, 5.0, 3, -0.15),
    (-10.0, 10.0, 20, 10.5, 80, 5.0, 3, -0.15),
    (-11.0, 11.0, 25, 11.5, 75, 5.0, 3, -0.15),
    (-9.0,  10.0, 25, 10.5, 75, 5.0, 3, -0.15),
    (-10.0, 10.0, 25, 10.5, 75, 6.0, 3, -0.15),
    (-10.0, 10.0, 25, 10.5, 75, 5.0, 4, -0.15),
    (-10.0, 10.0, 25, 10.5, 75, 5.0, 3, -0.20),
    (-10.0, 10.0, 25, 10.5, 75, 5.0, 3, -0.10),
    (-10.0,  8.0, 25,  8.5, 75, 5.0, 3, -0.15),
    (-10.0, 14.0, 25, 14.5, 75, 5.0, 3, -0.15),
    (-10.0, 10.0, 25, 10.5, 50, 5.0, 3, -0.15),
    (-10.0, 10.0, 33, 10.5, 67, 5.0, 3, -0.15),
    (-10.0, 10.0, 25, 10.5, 75, 4.0, 3, -0.15),
    (-12.0, 13.0, 25, 13.5, 75, 5.0, 3, -0.15),
    (-10.0, 10.0, 25, 10.5, 75, 5.0, 2, -0.15),
    (-10.0, 10.0, 25, 10.5, 75, 7.0, 4, -0.20),
    (-10.0, 10.0, 25, 12.0, 75, 5.0, 3, -0.15),
]
for i, (h, s1a, s1p, s2a, s2p, ka, ks, ag) in enumerate(sel_params, 21):
    SIMS.append({"id": f"{i:03d}", "type": "selection", "h": h,
                 "stimuli": [{"amp": s1a, "sigma": 5, "pos": s1p},
                             {"amp": s2a, "sigma": 5, "pos": s2p}],
                 "kernel": {"type": "gauss", "sigma": ks, "amp": ka, "amp_global": ag}})

# ── Memory (041–060) ────────────────────────────────────────────────────────
mem_params = [
    (-5.0, 15.0, 50, 3.4, 17.7, 8.9, 13.5),
    (-5.0, 12.0, 50, 3.4, 17.7, 8.9, 13.5),
    (-5.0, 18.0, 50, 3.4, 17.7, 8.9, 13.5),
    (-6.0, 15.0, 50, 3.4, 17.7, 8.9, 13.5),
    (-4.0, 15.0, 50, 3.4, 17.7, 8.9, 13.5),
    (-5.0, 15.0, 25, 3.4, 17.7, 8.9, 13.5),
    (-5.0, 15.0, 75, 3.4, 17.7, 8.9, 13.5),
    (-5.0, 15.0, 50, 3.0, 17.7, 8.9, 13.5),
    (-5.0, 15.0, 50, 4.0, 17.7, 8.9, 13.5),
    (-5.0, 15.0, 50, 3.4, 17.7, 8.9,  9.0),
    (-5.0, 15.0, 50, 3.4, 20.0, 8.9, 13.5),
    (-5.0, 15.0, 50, 3.4, 17.7, 7.0, 13.5),
    (-5.0, 15.0, 50, 3.4, 19.0, 8.9, 13.5),
    (-5.0, 15.0, 50, 3.4, 17.7, 8.9, 11.0),
    (-5.0, 15.0, 50, 3.4, 17.7, 8.9, 16.0),
    (-5.0, 15.0, 33, 3.4, 17.7, 8.9, 13.5),
    (-5.0, 15.0, 67, 3.4, 17.7, 8.9, 13.5),
    (-6.0, 18.0, 50, 3.4, 17.7, 8.9, 13.5),
    (-5.5, 17.0, 50, 3.4, 20.0, 8.9, 13.5),
    (-5.0, 15.0, 50, 3.4, 20.0, 8.5, 13.0),
]
for i, (h, sa, sp, se, ae, si, ai) in enumerate(mem_params, 41):
    SIMS.append({"id": f"{i:03d}", "type": "memory", "h": h,
                 "stimuli": [{"amp": sa, "sigma": 5, "pos": sp}],
                 "kernel": {"type": "mexican_hat", "sigma_exc": se, "amp_exc": ae,
                            "sigma_inh": si, "amp_inh": ai}})

# ── Insufficient activation (061–080) ───────────────────────────────────────
ins_params = [
    (-12.0, 5.0, 5, 50, 3.0, 3),
    (-12.0, 4.0, 5, 50, 3.0, 3),
    (-12.0, 6.0, 5, 50, 3.0, 3),
    (-14.0, 5.0, 5, 50, 3.0, 3),
    (-10.0, 5.0, 5, 50, 3.0, 3),
    (-12.0, 5.0, 3, 50, 3.0, 3),
    (-12.0, 5.0, 7, 50, 3.0, 3),
    (-12.0, 5.0, 5, 25, 3.0, 3),
    (-12.0, 5.0, 5, 75, 3.0, 3),
    (-12.0, 5.0, 5, 50, 2.0, 3),
    (-12.0, 5.0, 5, 50, 4.0, 3),
    (-12.0, 5.0, 5, 50, 3.0, 2),
    (-12.0, 5.0, 5, 50, 3.0, 4),
    (-15.0, 7.0, 5, 50, 3.0, 3),
    (-12.0, 3.0, 5, 50, 3.0, 3),
    (-12.0, 5.0, 5, 50, 1.0, 3),
    (-12.0, 5.0, 5, 33, 3.0, 3),
    (-12.0, 5.0, 5, 67, 3.0, 3),
    (-11.0, 6.0, 4, 50, 4.0, 3),
    (-13.0, 7.0, 6, 50, 3.5, 3),
]
for i, (h, sa, ss, sp, ka, ks) in enumerate(ins_params, 61):
    SIMS.append({"id": f"{i:03d}", "type": "insufficient", "h": h,
                 "stimuli": [{"amp": sa, "sigma": ss, "pos": sp}],
                 "kernel": {"type": "gauss", "sigma": ks, "amp": ka, "amp_global": 0.0}})

# ── Multi-peak (081–100) ─────────────────────────────────────────────────────
multi_params = [
    (2, -8.0, [(12, 25, 5), (12, 75, 5)],                           5.0, 2, 0.0),
    (2, -8.0, [(12, 25, 5), (12, 75, 5)],                           4.0, 2, 0.0),
    (2, -8.0, [(12, 25, 5), (12, 75, 5)],                           3.0, 1, 0.0),
    (2, -8.0, [(12, 20, 5), (12, 80, 5)],                           5.0, 2, 0.0),
    (2, -8.0, [(12, 30, 5), (12, 70, 5)],                           5.0, 2, 0.0),
    (3, -8.0, [(12, 20, 5), (12, 50, 5), (12, 80, 5)],              5.0, 2, 0.0),
    (3, -8.0, [(10, 20, 5), (12, 50, 5), (10, 80, 5)],              4.0, 2, 0.0),
    (2, -7.0, [(12, 25, 5), (12, 75, 5)],                           5.0, 2, 0.0),
    (2, -9.0, [(14, 25, 5), (14, 75, 5)],                           5.0, 2, 0.0),
    (2, -8.0, [(12, 25, 4), (12, 75, 4)],                           5.0, 2, 0.0),
    (2, -8.0, [(12, 25, 6), (12, 75, 6)],                           5.0, 2, 0.0),
    (2, -8.0, [(12, 25, 5), (12, 75, 5)],                           6.0, 2, 0.0),
    (2, -8.0, [(12, 25, 5), (12, 75, 5)],                           5.0, 3, 0.0),
    (2, -8.0, [(12, 25, 5), (14, 75, 5)],                           5.0, 2, 0.0),
    (3, -8.0, [(12, 17, 4), (12, 50, 4), (12, 83, 4)],              4.0, 2, 0.0),
    (2, -8.0, [(12, 25, 5), (12, 75, 5)],                           5.0, 2, -0.05),
    (2, -8.0, [(15, 25, 5), (15, 75, 5)],                           5.0, 2, 0.0),
    (3, -8.0, [(10, 25, 5), (10, 50, 5), (10, 75, 5)],              4.0, 2, 0.0),
    (2, -8.0, [(12, 25, 5), (12, 75, 5)],                           7.0, 3, 0.0),
    (2, -8.0, [(12, 25, 3), (12, 75, 3)],                           5.0, 2, 0.0),
]
for i, (n, h, stims, ka, ks, ag) in enumerate(multi_params, 81):
    SIMS.append({"id": f"{i:03d}", "type": "multi_peak", "h": h,
                 "stimuli": [{"amp": a, "sigma": s, "pos": p} for a, p, s in stims],
                 "kernel": {"type": "gauss", "sigma": ks, "amp": ka, "amp_global": ag}})

assert len(SIMS) == 100

# ---------------------------------------------------------------------------
# Simulation builder
# ---------------------------------------------------------------------------

FIELD_SIZE = (1, 100)
TAU        = 25.0
BETA       = 100.0


def build_sim(sim_params: dict) -> tuple:
    """Build a cosivina-python Simulator for the given parameter dict.

    Returns (sim, stim_names) where stim_names is the list of stimulus
    element labels (needed to zero them in phase 2).
    """
    k = sim_params["kernel"]
    n_stim = len(sim_params["stimuli"])
    h = float(sim_params["h"])

    sim = Simulator(deltaT=TAU)

    # Stimuli
    stim_names = []
    for i, st in enumerate(sim_params["stimuli"]):
        name = f"stimulus {i+1}" if n_stim > 1 else "stimulus"
        stim_names.append(name)
        sim.addElement(
            GaussStimulus1D(name, FIELD_SIZE,
                            sigma=float(st["sigma"]),
                            amplitude=float(st["amp"]),
                            position=float(st["pos"]),
                            circular=True,
                            normalized=False)
        )

    # Sum stimuli into one input
    stim_input_names = stim_names if n_stim > 1 else stim_names[0]
    sim.addElement(SumInputs("stimulus sum", FIELD_SIZE), stim_input_names)

    # Neural field
    sim.addElement(
        NeuralField("field u", FIELD_SIZE, tau=TAU, h=h, beta=BETA),
        inputLabels="stimulus sum"
    )

    # Lateral kernel
    if k["type"] == "gauss" and k.get("amp_global", 0.0) == 0.0:
        sim.addElement(
            GaussKernel1D("u->u", FIELD_SIZE,
                          sigma=float(k["sigma"]),
                          amplitude=float(k["amp"]),
                          circular=True,
                          normalized=True),
            inputLabels="field u", inputComponents="output",
            targetLabels="field u"
        )
    elif k["type"] == "gauss":
        # Gauss kernel with global inhibition (selection type)
        sim.addElement(
            LateralInteractions1D("u->u", FIELD_SIZE,
                                  sigmaExc=float(k["sigma"]),
                                  amplitudeExc=float(k["amp"]),
                                  sigmaInh=0.0,
                                  amplitudeInh=0.0,
                                  amplitudeGlobal=float(k["amp_global"]),
                                  circular=True,
                                  normalized=True),
            inputLabels="field u", inputComponents="output",
            targetLabels="field u"
        )
    else:
        # Mexican hat (memory type)
        sim.addElement(
            LateralInteractions1D("u->u", FIELD_SIZE,
                                  sigmaExc=float(k["sigma_exc"]),
                                  amplitudeExc=float(k["amp_exc"]),
                                  sigmaInh=float(k["sigma_inh"]),
                                  amplitudeInh=float(k["amp_inh"]),
                                  amplitudeGlobal=0.0,
                                  circular=True,
                                  normalized=True),
            inputLabels="field u", inputComponents="output",
            targetLabels="field u"
        )

    return sim, stim_names


def save_activation(sim: object, path: str) -> None:
    u = sim.getComponent("field u", "activation")  # shape (1, 100)
    np.savetxt(path, [u[0]], delimiter=",", fmt="%.15g")


def run_sim(sim_params: dict, output_dir: str) -> None:
    sid = sim_params["id"]
    sim, stim_names = build_sim(sim_params)

    # Phase 1: stimulus ON — 500 steps
    sim.init()
    for _ in range(500):
        sim.step()
    save_activation(sim, os.path.join(output_dir,
                                      f"sim_{sid}_sigmoid_b100_with_stimulus.csv"))

    # Phase 2: stimulus OFF — 500 steps (continue from phase 1 state)
    for name in stim_names:
        sim.setElementParameters(name, "amplitude", 0.0)
    for _ in range(500):
        sim.step()
    save_activation(sim, os.path.join(output_dir,
                                      f"sim_{sid}_sigmoid_b100_without_stimulus.csv"))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    root = Path(__file__).resolve().parent.parent
    out_dir = root / "data" / "cosivina-python"
    out_dir.mkdir(parents=True, exist_ok=True)

    n_ok = 0
    n_failed = 0

    for i, sim_params in enumerate(SIMS, 1):
        sid = sim_params["id"]
        print(f"[{i:3d}/100] Running sim_{sid} ({sim_params['type']}) ... ", end="", flush=True)
        try:
            run_sim(sim_params, str(out_dir))
            n_ok += 1
            print("OK")
        except Exception as exc:
            n_failed += 1
            print(f"FAILED: {exc}")

    print(f"\nDone: {n_ok} OK, {n_failed} failed.")
    print(f"Output: {out_dir}")


if __name__ == "__main__":
    main()
