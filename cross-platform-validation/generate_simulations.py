"""
Generate all simulation files for the cross-framework algebraic equivalence test suite.

Outputs (relative to this script's directory):
  simulations/cosivina/sim_NNN.m                    (100 files)
  simulations/cosivina-python/sim_NNN.py            (100 files)
  simulations/dnfc/sim_NNN_abssigmoid_b100.json     (100)
  simulations/dnfc/sim_NNN_heaviside.json           (100)
  simulations/dnfc/sim_NNN_sigmoid_b100.json        (100)
  simulations/cedar/sim_NNN_abssigmoid_b100.json    (100)
  simulations/cedar/sim_NNN_heaviside.json          (100)

Total: 700 files.
"""

import json
import os
from pathlib import Path

ROOT = Path(__file__).parent

# ---------------------------------------------------------------------------
# Parameter table
# ---------------------------------------------------------------------------

# Each sim is a dict with keys:
#   id (str "001".."100"), type (str), h, tau=25, field_size=100
#   stimuli: list of dicts {amp, sigma, pos}
#   kernel: dict — one of:
#     {"type":"gauss", "sigma":, "amp":, "amp_global":}
#     {"type":"mexican_hat", "sigma_exc":, "amp_exc":, "sigma_inh":, "amp_inh":}

SIMS = []

# ── Detection (001–020) ─────────────────────────────────────────────────────
det_params = [
    # h,     stim_amp, stim_sigma, stim_pos, k_amp, k_sigma
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
    # h,     s1_amp, s1_pos, s2_amp, s2_pos, k_amp, k_sigma, amp_global
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
    # h,    stim_amp, stim_pos, sigma_exc, amp_exc, sigma_inh, amp_inh
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
    # n, h,    stimuli [(amp,pos,sig)...],                         k_amp, k_sig, ag
    (2, -8.0, [(12,25,5),(12,75,5)],                               5.0, 2, 0.0),
    (2, -8.0, [(12,25,5),(12,75,5)],                               4.0, 2, 0.0),
    (2, -8.0, [(12,25,5),(12,75,5)],                               3.0, 1, 0.0),
    (2, -8.0, [(12,20,5),(12,80,5)],                               5.0, 2, 0.0),
    (2, -8.0, [(12,30,5),(12,70,5)],                               5.0, 2, 0.0),
    (3, -8.0, [(12,20,5),(12,50,5),(12,80,5)],                     5.0, 2, 0.0),
    (3, -8.0, [(10,20,5),(12,50,5),(10,80,5)],                     4.0, 2, 0.0),
    (2, -7.0, [(12,25,5),(12,75,5)],                               5.0, 2, 0.0),
    (2, -9.0, [(14,25,5),(14,75,5)],                               5.0, 2, 0.0),
    (2, -8.0, [(12,25,4),(12,75,4)],                               5.0, 2, 0.0),
    (2, -8.0, [(12,25,6),(12,75,6)],                               5.0, 2, 0.0),
    (2, -8.0, [(12,25,5),(12,75,5)],                               6.0, 2, 0.0),
    (2, -8.0, [(12,25,5),(12,75,5)],                               5.0, 3, 0.0),
    (2, -8.0, [(12,25,5),(14,75,5)],                               5.0, 2, 0.0),
    (3, -8.0, [(12,17,4),(12,50,4),(12,83,4)],                     4.0, 2, 0.0),
    (2, -8.0, [(12,25,5),(12,75,5)],                               5.0, 2, -0.05),
    (2, -8.0, [(15,25,5),(15,75,5)],                               5.0, 2, 0.0),
    (3, -8.0, [(10,25,5),(10,50,5),(10,75,5)],                     4.0, 2, 0.0),
    (2, -8.0, [(12,25,5),(12,75,5)],                               7.0, 3, 0.0),
    (2, -8.0, [(12,25,3),(12,75,3)],                               5.0, 2, 0.0),
]
for i, (n, h, stims, ka, ks, ag) in enumerate(multi_params, 81):
    SIMS.append({"id": f"{i:03d}", "type": "multi_peak", "h": h,
                 "stimuli": [{"amp": a, "sigma": s, "pos": p} for a, p, s in stims],
                 "kernel": {"type": "gauss", "sigma": ks, "amp": ka, "amp_global": ag}})

assert len(SIMS) == 100, f"Expected 100 sims, got {len(SIMS)}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Per-variant simulation folders. cosivina-python (numba/nonumba) share one sims
# folder — the .py files are identical, only the runner's import differs. Cedar
# splits opencv/fftw because the convolution-engine string is baked into the JSON.
COSIVINA_DIR        = ROOT / "simulations" / "cosivina"
COSIVINA_PYTHON_DIR = ROOT / "simulations" / "cosivina-python"
DNFC_DIR            = ROOT / "simulations" / "dnfc"
CEDAR_OPENCV_DIR    = ROOT / "simulations" / "cedar-opencv"
CEDAR_FFTW_DIR      = ROOT / "simulations" / "cedar-fftw"


def dnfc_act_fn(name: str) -> dict:
    if name == "abssigmoid_b100":
        return {"type": "abs_sigmoid", "beta": 100.0, "x_shift": 0.0}
    if name == "heaviside":
        return {"type": "heaviside", "x_shift": 0.0}
    if name == "sigmoid_b100":
        return {"type": "sigmoid", "steepness": 100.0, "x_shift": 0.0}
    raise ValueError(name)


def cedar_sigmoid(name: str) -> dict:
    if name == "abssigmoid_b100":
        return {"type": "cedar.aux.math.AbsSigmoid", "threshold": "0", "beta": "100"}
    if name == "heaviside":
        return {"type": "cedar.aux.math.HeavisideSigmoid", "threshold": "0"}
    if name == "sigmoid_b100":
        return {"type": "cedar.aux.math.ExpSigmoid", "threshold": "0", "beta": "100"}
    raise ValueError(name)


def fair_cedar_limit(sigma: float, field_size: int) -> float:
    """Cedar's Gauss kernel taps = ceil(limit*sigma), bumped to the next odd number
    (cedar::aux::kernel::Gauss::estimateWidth) — a kernel-WIDTH convention. dnfc's/
    cosivina's cutoffFactor=5 is a kernel-RADIUS convention: taps = 2*min(ceil(5*sigma),
    field-size cap)+1 (dnfc computeKernelRange). The two are NOT the same units —
    Cedar's `limit` must be roughly 2x dnfc's cutoff to reach the same tap count.
    Returns the Cedar limit that reproduces dnfc's exact tap count for this
    sigma/field size, so validated architectures do the same convolution work."""
    import math
    ceil_sigma5 = math.ceil(5.0 * sigma)
    half = (field_size - 1) / 2.0
    cap_floor = math.floor(half)
    cap_ceil = math.ceil(half)
    range_lo = min(ceil_sigma5, cap_floor)
    range_hi = min(ceil_sigma5, cap_ceil)
    target_taps = range_lo + range_hi + 1
    if target_taps % 2 == 0:
        target_taps -= 1
    return (target_taps - 0.5) / sigma


# ---------------------------------------------------------------------------
# dnfc JSON generator
# ---------------------------------------------------------------------------

def build_dnfc_json(sim: dict, act_fn: str) -> dict:
    sid = sim["id"]
    stype = sim["type"]
    k = sim["kernel"]

    elements = []

    # Neural field
    elements.append({
        "uniqueName": "neural field u",
        "label": [1, "neural field"],
        "tau": 25.0,
        "restingLevel": sim["h"],
        "activationFunction": dnfc_act_fn(act_fn),
        "x_max": 100,
        "d_x": 1.0,
        "inputs": (
            [["gauss kernel", "output"]] if k["type"] == "gauss" else [["mexican hat kernel", "output"]]
        ) + [[f"gauss stimulus {i+1}", "output"] for i in range(len(sim["stimuli"]))]
    })

    # Stimuli
    for i, st in enumerate(sim["stimuli"]):
        name = f"gauss stimulus {i+1}" if len(sim["stimuli"]) > 1 else "gauss stimulus"
        # Fix inputs reference above for single stimulus
        elements[-1]["inputs"] = (
            [["gauss kernel", "output"]] if k["type"] == "gauss" else [["mexican hat kernel", "output"]]
        ) + [[f"gauss stimulus {j+1}" if len(sim["stimuli"]) > 1 else "gauss stimulus", "output"]
             for j in range(len(sim["stimuli"]))]

        elements.append({
            "uniqueName": name,
            "label": [2, "gauss stimulus"],
            "amplitude": float(st["amp"]),
            "width": float(st["sigma"]),
            "position": float(st["pos"]),
            "circular": True,
            "normalized": False,
            "x_max": 100,
            "d_x": 1.0,
            "inputs": None
        })

    # Kernel
    if k["type"] == "gauss":
        elements.append({
            "uniqueName": "gauss kernel",
            "label": [4, "gauss kernel"],
            "amplitude": float(k["amp"]),
            "amplitudeGlobal": float(k["amp_global"]),
            "width": float(k["sigma"]),
            "circular": True,
            "normalized": True,
            "x_max": 100,
            "d_x": 1.0,
            "inputs": [["neural field u", "output"]]
        })
    else:  # mexican_hat
        elements.append({
            "uniqueName": "mexican hat kernel",
            "label": [5, "mexican hat kernel"],
            "amplitudeExc": float(k["amp_exc"]),
            "widthExc": float(k["sigma_exc"]),
            "amplitudeInh": float(k["amp_inh"]),
            "widthInh": float(k["sigma_inh"]),
            "amplitudeGlobal": 0.0,
            "circular": True,
            "normalized": True,
            "x_max": 100,
            "d_x": 1.0,
            "inputs": [["neural field u", "output"]]
        })

    return {
        "identifier": f"sim-{sid}-{stype}-{act_fn}",
        "deltaT": 25.0,
        "elements": elements
    }


# Fix the NF inputs construction (cleaner rewrite):
def build_dnfc_json_v2(sim: dict, act_fn: str) -> dict:
    sid = sim["id"]
    stype = sim["type"]
    k = sim["kernel"]
    n_stim = len(sim["stimuli"])

    # stimulus unique names
    stim_names = [f"gauss stimulus {i+1}" if n_stim > 1 else "gauss stimulus"
                  for i in range(n_stim)]

    kernel_name = "gauss kernel" if k["type"] == "gauss" else "mexican hat kernel"

    # NF inputs: kernel + all stimuli
    nf_inputs = [[kernel_name, "output"]] + [[s, "output"] for s in stim_names]

    elements = []

    # Neural field
    elements.append({
        "uniqueName": "neural field u",
        "label": [1, "neural field"],
        "tau": 25.0,
        "restingLevel": float(sim["h"]),
        "activationFunction": dnfc_act_fn(act_fn),
        "x_max": 100,
        "d_x": 1.0,
        "inputs": nf_inputs
    })

    # Stimuli
    for name, st in zip(stim_names, sim["stimuli"]):
        elements.append({
            "uniqueName": name,
            "label": [2, "gauss stimulus"],
            "amplitude": float(st["amp"]),
            "width": float(st["sigma"]),
            "position": float(st["pos"]),
            "circular": True,
            "normalized": False,
            "x_max": 100,
            "d_x": 1.0,
            "inputs": None
        })

    # Kernel
    if k["type"] == "gauss":
        elements.append({
            "uniqueName": "gauss kernel",
            "label": [4, "gauss kernel"],
            "amplitude": float(k["amp"]),
            "amplitudeGlobal": float(k["amp_global"]),
            "width": float(k["sigma"]),
            "circular": True,
            "normalized": True,
            "x_max": 100,
            "d_x": 1.0,
            "inputs": [["neural field u", "output"]]
        })
    else:
        elements.append({
            "uniqueName": "mexican hat kernel",
            "label": [5, "mexican hat kernel"],
            "amplitudeExc": float(k["amp_exc"]),
            "widthExc": float(k["sigma_exc"]),
            "amplitudeInh": float(k["amp_inh"]),
            "widthInh": float(k["sigma_inh"]),
            "amplitudeGlobal": 0.0,
            "circular": True,
            "normalized": True,
            "x_max": 100,
            "d_x": 1.0,
            "inputs": [["neural field u", "output"]]
        })

    return {
        "identifier": f"sim-{sid}-{stype}-{act_fn}",
        "deltaT": 25.0,
        "elements": elements
    }


# ---------------------------------------------------------------------------
# Cedar JSON generator
# ---------------------------------------------------------------------------

# Cedar JSON uses string values for numbers.
# For multi-stimulus: two GaussInput steps with different "name" fields.
# For memory: two Gauss kernel entries with duplicate keys (Cedar-specific).

CEDAR_BOILERPLATE_TAIL = """
    "triggers": {
        "cedar.processing.LoopedTrigger": {
            "name": "LoopedTrigger",
            "fake euler step": "false",
            "loop mode": "0",
            "step size": "1",
            "Steps": {
                "cedar.dynamics.NeuralField": {}
            }
        }
    },
    "connections": [
        {"source": "Gauss Input.output", "target": "Neural Field.input"},
        {"source": "Neural Field.lateral output", "target": "Neural Field.input"}
    ],
    "records": {},
    "ui": {},
    "ui view": {},
    "ui generic": {}
"""


def build_cedar_json_str(sim: dict, act_fn: str, engine: str = "cedar.aux.conv.OpenCV") -> str:
    """Return a Cedar JSON string. Built as a string because Cedar uses duplicate keys.

    `engine` selects the lateral-convolution backend: "cedar.aux.conv.OpenCV"
    (spatial filter2D) or "cedar.aux.conv.FFTW" (Fourier-domain). Same architecture
    either way; only the engine string differs."""
    k = sim["kernel"]
    n_stim = len(sim["stimuli"])
    sig_block = json.dumps(cedar_sigmoid(act_fn))

    # Build GaussInput steps block
    gauss_inputs = ""
    for i, st in enumerate(sim["stimuli"]):
        name = f"Gauss Input {i+1}" if n_stim > 1 else "Gauss Input"
        gauss_inputs += f"""
        "cedar.processing.sources.GaussInput": {{
            "name": "{name}",
            "dimensionality": "1",
            "sizes": ["100"],
            "amplitude": "{st['amp']}",
            "centers": ["{st['pos']}"],
            "sigma": ["{st['sigma']}"],
            "cyclic": "true",
            "comments": ""
        }},"""

    # Build lateral kernels block
    if k["type"] == "gauss":
        limit = fair_cedar_limit(k["sigma"], 100)
        lateral_kernels = f"""{{
                "cedar.aux.kernel.Gauss": {{
                    "dimensionality": "1",
                    "anchor": ["0"],
                    "amplitude": "{k['amp']}",
                    "sigmas": ["{k['sigma']}"],
                    "normalize": "true",
                    "shifts": ["0"],
                    "limit": "{limit}"
                }}
            }}"""
    else:
        # Two Gauss entries (duplicate key — Cedar-specific)
        limit_exc = fair_cedar_limit(k["sigma_exc"], 100)
        limit_inh = fair_cedar_limit(k["sigma_inh"], 100)
        lateral_kernels = f"""{{
                "cedar.aux.kernel.Gauss": {{
                    "dimensionality": "1",
                    "anchor": ["0"],
                    "amplitude": "{k['amp_exc']}",
                    "sigmas": ["{k['sigma_exc']}"],
                    "normalize": "true",
                    "shifts": ["0"],
                    "limit": "{limit_exc}"
                }},
                "cedar.aux.kernel.Gauss": {{
                    "dimensionality": "1",
                    "anchor": ["0"],
                    "amplitude": "-{k['amp_inh']}",
                    "sigmas": ["{k['sigma_inh']}"],
                    "normalize": "true",
                    "shifts": ["0"],
                    "limit": "{limit_inh}"
                }}
            }}"""

    # Global inhibition (selection only). Cedar's eulerStep adds
    # global_inhibition * sum(sigmoid(u)) to du, so the parameter must carry the
    # (negative) sign of the inhibition directly — same convention as dnfc's amp_global.
    global_inh = "0"
    if k["type"] == "gauss" and k.get("amp_global", 0.0) != 0.0:
        global_inh = str(k["amp_global"])

    # Build connections (one per stimulus).
    # Cedar slot name: GaussInput output = "Gauss input"; NeuralField input
    # collection = "input". The lateral interaction is applied INTERNALLY by the
    # field (it convolves its own sigmoided activation with the lateral kernel),
    # so there is no explicit self-connection (Cedar rejects it as a deadlock).
    connections = []
    for i in range(n_stim):
        name = f"Gauss Input {i+1}" if n_stim > 1 else "Gauss Input"
        connections.append(f'{{"source": "{name}.Gauss input", "target": "Neural Field.input"}}')
    conn_str = ",\n        ".join(connections)

    return f"""{{
    "meta": {{"format": "1"}},
    "steps": {{{gauss_inputs}
        "cedar.dynamics.NeuralField": {{
            "name": "Neural Field",
            "activation as output": "false",
            "discrete metric (workaround)": "false",
            "update stepIcon according to output": "true",
            "threshold for updating the stepIcon": "0.8",
            "dimensionality": "1",
            "sizes": ["100"],
            "time scale": "25",
            "resting level": "{sim['h']}",
            "input noise gain": "0",
            "multiplicative noise (input)": "false",
            "multiplicative noise (activation)": "false",
            "sigmoid": {sig_block},
            "global inhibition": "{global_inh}",
            "lateral kernels": {lateral_kernels},
            "lateral kernel convolution": {{
                "engine": {{"type": "{engine}"}},
                "borderType": "Cyclic",
                "mode": "Same",
                "alternate even kernel center": "false"
            }},
            "noise correlation kernel": {{
                "dimensionality": "1", "anchor": ["0"],
                "amplitude": "0", "sigmas": ["3"],
                "normalize": "true", "shifts": ["0"], "limit": "5"
            }},
            "comments": ""
        }}
    }},
    "triggers": {{
        "cedar.processing.LoopedTrigger": {{
            "name": "LoopedTrigger",
            "fake euler step": "false",
            "loop mode": "0",
            "step size": "1",
            "Steps": {{"cedar.dynamics.NeuralField": {{}}}}
        }}
    }},
    "connections": [
        {conn_str}
    ],
    "records": {{}},
    "ui": {{}},
    "ui view": {{}},
    "ui generic": {{}}
}}"""


# ---------------------------------------------------------------------------
# Cosivina MATLAB generator
# ---------------------------------------------------------------------------

def _cosivina_stimuli_block(sim: dict) -> tuple[str, str, str]:
    """Return (add_elements_str, stim_sum_inputs_str, set_zero_str)."""
    stims = sim["stimuli"]
    n = len(stims)
    lines = []
    names = []
    for i, st in enumerate(stims):
        name = f"stimulus {i+1}" if n > 1 else "stimulus"
        names.append(f"'{name}'")
        lines.append(
            f"sim.addElement(GaussStimulus1D('{name}', fieldSize, "
            f"{st['sigma']}, {st['amp']}, {st['pos']}, true, false));"
        )
    add_str = "\n".join(lines)
    sum_inputs = "{" + ", ".join(names) + "}"
    # set-to-zero lines
    zero_lines = [
        f"sim.setElementParameters('{n_}', {{'amplitude'}}, {{0}});"
        for n_ in [n.strip("'") for n in names]
    ]
    zero_str = "\n".join(zero_lines)
    return add_str, sum_inputs, zero_str


def _cosivina_restore_stim(sim: dict) -> str:
    stims = sim["stimuli"]
    n = len(stims)
    lines = []
    for i, st in enumerate(stims):
        name = f"stimulus {i+1}" if n > 1 else "stimulus"
        lines.append(
            f"sim.setElementParameters('{name}', {{'amplitude'}}, {{{st['amp']}}});"
        )
    return "\n".join(lines)


def build_cosivina_script(sim: dict, output_dir: str) -> str:
    sid = sim["id"]
    stype = sim["type"]
    k = sim["kernel"]

    add_stim, sum_inputs, set_zero = _cosivina_stimuli_block(sim)
    restore_stim = _cosivina_restore_stim(sim)

    if k["type"] == "gauss":
        kernel_line = (
            f"sim.addElement(GaussKernel1D('u -> u', fieldSize, "
            f"{k['sigma']}, {k['amp']}, true, true), 'field u', 'output', 'field u');"
        )
        if k.get("amp_global", 0.0) != 0.0:
            # Use LateralInteractions1D with sigma_inh=0, amp_inh=0
            kernel_line = (
                f"sim.addElement(LateralInteractions1D('u -> u', fieldSize, "
                f"{k['sigma']}, {k['amp']}, 0, 0, {k['amp_global']}, true, true), "
                f"'field u', 'output', 'field u');"
            )
    else:
        kernel_line = (
            f"sim.addElement(LateralInteractions1D('u -> u', fieldSize, "
            f"{k['sigma_exc']}, {k['amp_exc']}, {k['sigma_inh']}, {k['amp_inh']}, 0.0, true, true), "
            f"'field u', 'output', 'field u');"
        )

    out_dir_str = output_dir.replace("\\", "/")

    return f"""%% Simulation sim_{sid} — type: {stype}
% Auto-generated. Do not edit manually.

fieldSize = 100;
sim = Simulator();
sim.deltaT = 25;

{add_stim}
sim.addElement(SumInputs('stimulus sum', fieldSize), {sum_inputs});

sim.addElement(NeuralField('field u', fieldSize, 25, {sim['h']}, 100), 'stimulus sum');

{kernel_line}

outputDir = '{out_dir_str}';

%% Phase 1: stimulus ON — 500 steps
sim.init();
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(u, fullfile(outputDir, 'sim_{sid}_sigmoid_b100_with_stimulus.csv'));

%% Phase 2: stimulus OFF — 500 steps
{set_zero}
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(u, fullfile(outputDir, 'sim_{sid}_sigmoid_b100_without_stimulus.csv'));

%% Re-initialise (restores all parameters to construction values)
{restore_stim}
sim.init();
"""


# ---------------------------------------------------------------------------
# cosivina-python script generator
# ---------------------------------------------------------------------------

def _python_stimuli_block(sim: dict) -> tuple[str, str, str]:
    """Return (add_elements_str, sum_input_arg, set_zero_str)."""
    stims = sim["stimuli"]
    n = len(stims)
    lines = []
    names = []
    for i, st in enumerate(stims):
        name = f"stimulus {i+1}" if n > 1 else "stimulus"
        names.append(name)
        lines.append(
            f"    sim.addElement(\n"
            f"        GaussStimulus1D('{name}', FIELD_SIZE,\n"
            f"                        sigma={st['sigma']}, amplitude={st['amp']}, "
            f"position={st['pos']},\n"
            f"                        circular=True, normalized=False))"
        )
    add_str = "\n".join(lines)
    sum_arg = repr(names) if n > 1 else repr(names[0])
    zero_lines = [
        f"    sim.setElementParameters('{name}', 'amplitude', 0.0)"
        for name in names
    ]
    zero_str = "\n".join(zero_lines)
    return add_str, sum_arg, zero_str


def _python_restore_stim(sim: dict) -> str:
    stims = sim["stimuli"]
    n = len(stims)
    lines = []
    for i, st in enumerate(stims):
        name = f"stimulus {i+1}" if n > 1 else "stimulus"
        lines.append(
            f"    sim.setElementParameters('{name}', 'amplitude', {st['amp']})"
        )
    return "\n".join(lines)


def build_cosivina_python_script(sim: dict, output_dir: str) -> str:
    sid   = sim["id"]
    stype = sim["type"]
    k     = sim["kernel"]

    add_stim, sum_arg, set_zero = _python_stimuli_block(sim)
    restore_stim = _python_restore_stim(sim)

    if k["type"] == "gauss" and k.get("amp_global", 0.0) == 0.0:
        kernel_lines = (
            f"    sim.addElement(\n"
            f"        GaussKernel1D('u->u', FIELD_SIZE,\n"
            f"                      sigma={k['sigma']}, amplitude={k['amp']},\n"
            f"                      circular=True, normalized=True),\n"
            f"        inputLabels='field u', inputComponents='output',\n"
            f"        targetLabels='field u')"
        )
    elif k["type"] == "gauss":
        kernel_lines = (
            f"    sim.addElement(\n"
            f"        LateralInteractions1D('u->u', FIELD_SIZE,\n"
            f"                              sigmaExc={k['sigma']}, amplitudeExc={k['amp']},\n"
            f"                              sigmaInh=0.0, amplitudeInh=0.0,\n"
            f"                              amplitudeGlobal={k['amp_global']},\n"
            f"                              circular=True, normalized=True),\n"
            f"        inputLabels='field u', inputComponents='output',\n"
            f"        targetLabels='field u')"
        )
    else:
        kernel_lines = (
            f"    sim.addElement(\n"
            f"        LateralInteractions1D('u->u', FIELD_SIZE,\n"
            f"                              sigmaExc={k['sigma_exc']}, amplitudeExc={k['amp_exc']},\n"
            f"                              sigmaInh={k['sigma_inh']}, amplitudeInh={k['amp_inh']},\n"
            f"                              amplitudeGlobal=0.0,\n"
            f"                              circular=True, normalized=True),\n"
            f"        inputLabels='field u', inputComponents='output',\n"
            f"        targetLabels='field u')"
        )

    out_dir_str = output_dir.replace("\\", "/")

    return f'''# sim_{sid}.py — type: {stype}
# Auto-generated. Do not edit manually.
# Run standalone:  python sim_{sid}.py
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


def run(output_dir: str = r"{out_dir_str}") -> None:
    sim = Simulator(deltaT=TAU)

{add_stim}
    sim.addElement(SumInputs("stimulus sum", FIELD_SIZE), {sum_arg})
    sim.addElement(
        NeuralField("field u", FIELD_SIZE, tau=TAU, h={sim['h']}, beta=BETA),
        inputLabels="stimulus sum")
{kernel_lines}

    os.makedirs(output_dir, exist_ok=True)

    # Phase 1: stimulus ON — 500 steps
    sim.init()
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_{sid}_sigmoid_b100_with_stimulus.csv"),
               [u[0]], delimiter=",", fmt="%.15g")

    # Phase 2: stimulus OFF — 500 steps
{set_zero}
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_{sid}_sigmoid_b100_without_stimulus.csv"),
               [u[0]], delimiter=",", fmt="%.15g")

    # Restore stimulus amplitudes
{restore_stim}
    sim.init()


if __name__ == "__main__":
    run()
'''


# ---------------------------------------------------------------------------
# Main: write all files
# ---------------------------------------------------------------------------

def main():
    dnfc_act_fns  = ["abssigmoid_b100", "heaviside", "sigmoid_b100"]
    cedar_act_fns = ["abssigmoid_b100", "heaviside", "sigmoid_b100"]

    cosivina_out        = str(ROOT / "data" / "cosivina")
    cosivina_python_out = str(ROOT / "data" / "cosivina-python")

    for d in (COSIVINA_DIR, COSIVINA_PYTHON_DIR, DNFC_DIR,
              CEDAR_OPENCV_DIR, CEDAR_FFTW_DIR):
        d.mkdir(parents=True, exist_ok=True)

    n_written = 0

    for sim in SIMS:
        sid = sim["id"]

        # ── Cosivina (MATLAB) ───────────────────────────────────────────────
        script = build_cosivina_script(sim, cosivina_out)
        path = COSIVINA_DIR / f"sim_{sid}.m"
        path.write_text(script, encoding="utf-8")
        n_written += 1

        # ── cosivina-python ─────────────────────────────────────────────────
        py_script = build_cosivina_python_script(sim, cosivina_python_out)
        path = COSIVINA_PYTHON_DIR / f"sim_{sid}.py"
        path.write_text(py_script, encoding="utf-8")
        n_written += 1

        # ── dnfc ────────────────────────────────────────────────────────────
        for afn in dnfc_act_fns:
            data = build_dnfc_json_v2(sim, afn)
            path = DNFC_DIR / f"sim_{sid}_{afn}.json"
            path.write_text(json.dumps(data, indent=4), encoding="utf-8")
            n_written += 1

        # ── Cedar (two variants: OpenCV + FFTW engine) ──────────────────────
        for afn in cedar_act_fns:
            for cedar_dir, engine in (
                (CEDAR_OPENCV_DIR, "cedar.aux.conv.OpenCV"),
                (CEDAR_FFTW_DIR,   "cedar.aux.conv.FFTW"),
            ):
                cedar_str = build_cedar_json_str(sim, afn, engine=engine)
                path = cedar_dir / f"sim_{sid}_{afn}.json"
                path.write_text(cedar_str, encoding="utf-8")
                n_written += 1

    print(f"Written {n_written} simulation files.")
    print(f"  cosivina:        {len(SIMS)} .m files")
    print(f"  cosivina-python: {len(SIMS)} .py files")
    print(f"  dnfc:            {len(SIMS) * len(dnfc_act_fns)} .json files")
    print(f"  cedar-opencv:    {len(SIMS) * len(cedar_act_fns)} .json files")
    print(f"  cedar-fftw:      {len(SIMS) * len(cedar_act_fns)} .json files")


if __name__ == "__main__":
    main()
