"""
Generate all simulation files for the 2D cross-framework algebraic equivalence test suite.

This is the 2D counterpart of ../cross-platform-validation/generate_simulations.py.
It reuses the exact same 100-simulation parameter table (imported from the 1D
generator) and the same two-phase protocol (500 steps stimulus ON, 500 OFF), but
emits 2D elements on a 50x50 grid.

Field / grid:  x_max = y_max = 50, d_x = d_y = 1.0, tau = 25, deltaT = 25, cyclic.

Position mapping (1D -> 2D):  the 1D table places stimuli on a 0..100 axis. We
rescale each position by 1/2 onto the 0..50 grid and place the stimulus on the
grid diagonal at (p/2, p/2). This keeps multi-stimulus / selection bumps well
separated (e.g. selection 25,75 -> (12.5,12.5) and (37.5,37.5)).

Kernel widths / amplitudes are carried over unchanged from the 1D table as a
starting point. NOTE: a normalized 2D Gaussian integrates to 1 over the plane,
so the same amplitude yields different dynamics than 1D; the sanity gate
(see plan 02) verifies each architecture type still shows its intended
behaviour and records any per-type amplitude adjustment in test_suite_2d.md.

Outputs (relative to this script's directory):
  simulations/cosivina/sim_NNN.m                    (100)
  simulations/cosivina-python/sim_NNN.py            (100)
  simulations/dnfc/sim_NNN_abssigmoid_b100.json     (100)
  simulations/dnfc/sim_NNN_heaviside.json           (100)
  simulations/dnfc/sim_NNN_sigmoid_b100.json        (100)
  simulations/cedar/sim_NNN_abssigmoid_b100.json    (100)
  simulations/cedar/sim_NNN_heaviside.json          (100)
Total: 700 files.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).parent
ONE_D = ROOT.parent / "cross-platform-validation"

# Reuse the exact 100-sim parameter table + activation-function helpers from the
# 1D generator so the two suites stay in lockstep.
sys.path.insert(0, str(ONE_D))
from generate_simulations import SIMS, dnfc_act_fn, cedar_sigmoid  # noqa: E402

# ---------------------------------------------------------------------------
# 2D configuration
# ---------------------------------------------------------------------------

FIELD = 50          # x_max = y_max
DX = 1.0
TAU = 25.0
DELTA_T = 25.0


def pos2d(p):
    """Map a 1D position (0..100 axis) to a 2D diagonal grid coordinate (0..50)."""
    return p / 2.0


# ---------------------------------------------------------------------------
# Per-type 2D amplitude adjustment
# ---------------------------------------------------------------------------
# A normalized 2D Gaussian's peak is ~1/(2*pi*sigma^2) vs ~1/(sigma*sqrt(2*pi))
# in 1D — roughly 7.5x smaller for sigma=3 — so the same kernel amplitude gives
# far weaker lateral coupling in 2D. With the 1D amplitudes carried over verbatim,
# detection / insufficient / multi-peak still behave correctly (verified), but
# memory does not self-sustain and selection produces no bump.
#
# Empirically-tuned fixes (sanity gate, plan 02; see test_suite_2d.md):
#   detection, insufficient, multi_peak : keep 1D amplitudes (already correct in 2D)
#   selection   : kernel excitatory amplitude x4 (global inhibition unchanged) -> clean WTA
#   memory      : excitatory & inhibitory amplitudes x2.5 + global inhibition -0.05
#                 -> localized self-sustaining bump (without it the bump either
#                    collapses or floods the whole field)
SELECTION_KERNEL_SCALE = 4.0
MEMORY_AMP_SCALE        = 2.5
MEMORY_GLOBAL_INH       = -0.05


def to_2d_params(sim: dict) -> dict:
    """Return a copy of the sim dict with kernel amplitudes adjusted for 2D."""
    import copy
    s = copy.deepcopy(sim)
    k = s["kernel"]
    if s["type"] == "selection":
        k["amp"] = k["amp"] * SELECTION_KERNEL_SCALE          # global inhibition unchanged
    elif s["type"] == "memory":
        k["amp_exc"] = k["amp_exc"] * MEMORY_AMP_SCALE
        k["amp_inh"] = k["amp_inh"] * MEMORY_AMP_SCALE
        k["amp_global"] = MEMORY_GLOBAL_INH                   # mexican-hat gains a global term in 2D
    return s


# Per-variant simulation folders (see generate_simulations.py for the rationale).
COSIVINA_DIR        = ROOT / "simulations" / "cosivina"
COSIVINA_PYTHON_DIR = ROOT / "simulations" / "cosivina-python"
DNFC_DIR            = ROOT / "simulations" / "dnfc"
CEDAR_OPENCV_DIR    = ROOT / "simulations" / "cedar-opencv"
CEDAR_FFTW_DIR      = ROOT / "simulations" / "cedar-fftw"


# ---------------------------------------------------------------------------
# dnfc JSON generator (2D)
# ---------------------------------------------------------------------------

def build_dnfc_json_2d(sim: dict, act_fn: str) -> dict:
    sid = sim["id"]
    stype = sim["type"]
    k = sim["kernel"]
    n_stim = len(sim["stimuli"])

    stim_names = [f"gauss stimulus 2d {i+1}" if n_stim > 1 else "gauss stimulus 2d"
                  for i in range(n_stim)]
    kernel_name = "gauss kernel 2d" if k["type"] == "gauss" else "mexican hat kernel 2d"
    nf_inputs = [[kernel_name, "output"]] + [[s, "output"] for s in stim_names]

    elements = [{
        "uniqueName": "neural field u",
        "label": [13, "neural field 2d"],
        "tau": TAU,
        "restingLevel": float(sim["h"]),
        "activationFunction": dnfc_act_fn(act_fn),
        "x_max": FIELD, "y_max": FIELD, "d_x": DX, "d_y": DX,
        "inputs": nf_inputs,
    }]

    for name, st in zip(stim_names, sim["stimuli"]):
        elements.append({
            "uniqueName": name,
            "label": [14, "gauss stimulus 2d"],
            "width": float(st["sigma"]),
            "amplitude": float(st["amp"]),
            "position_x": pos2d(st["pos"]),
            "position_y": pos2d(st["pos"]),
            "circular": True, "normalized": False,
            "x_max": FIELD, "y_max": FIELD, "d_x": DX, "d_y": DX,
            "inputs": None,
        })

    if k["type"] == "gauss":
        elements.append({
            "uniqueName": "gauss kernel 2d",
            "label": [15, "gauss kernel 2d"],
            "width": float(k["sigma"]),
            "amplitude": float(k["amp"]),
            "amplitudeGlobal": float(k["amp_global"]),
            "circular": True, "normalized": True,
            "x_max": FIELD, "y_max": FIELD, "d_x": DX, "d_y": DX,
            "inputs": [["neural field u", "output"]],
        })
    else:  # mexican_hat
        elements.append({
            "uniqueName": "mexican hat kernel 2d",
            "label": [16, "mexican hat kernel 2d"],
            "widthExc": float(k["sigma_exc"]),
            "amplitudeExc": float(k["amp_exc"]),
            "widthInh": float(k["sigma_inh"]),
            "amplitudeInh": float(k["amp_inh"]),
            "amplitudeGlobal": float(k.get("amp_global", 0.0)),
            "circular": True, "normalized": True,
            "x_max": FIELD, "y_max": FIELD, "d_x": DX, "d_y": DX,
            "inputs": [["neural field u", "output"]],
        })

    return {
        "identifier": f"sim-{sid}-{stype}-{act_fn}-2d",
        "deltaT": DELTA_T,
        "elements": elements,
    }


# ---------------------------------------------------------------------------
# Cedar JSON generator (2D) — drives the real Cedar API (see plan 01 / cedar-notes.md)
# ---------------------------------------------------------------------------

def build_cedar_json_2d(sim: dict, act_fn: str, engine: str = "cedar.aux.conv.OpenCV") -> str:
    k = sim["kernel"]
    n_stim = len(sim["stimuli"])
    sig_block = json.dumps(cedar_sigmoid(act_fn))

    # GaussInput steps (2D: dimensionality 2, sizes [50,50], centers [y,x], sigma [s,s])
    gauss_inputs = ""
    for i, st in enumerate(sim["stimuli"]):
        name = f"Gauss Input {i+1}" if n_stim > 1 else "Gauss Input"
        c = pos2d(st["pos"])
        gauss_inputs += f"""
        "cedar.processing.sources.GaussInput": {{
            "name": "{name}",
            "dimensionality": "2",
            "sizes": ["{FIELD}", "{FIELD}"],
            "amplitude": "{st['amp']}",
            "centers": ["{c}", "{c}"],
            "sigma": ["{st['sigma']}", "{st['sigma']}"],
            "cyclic": "true",
            "comments": ""
        }},"""

    # Lateral kernels (2D Gauss, or two Gauss for mexican hat)
    if k["type"] == "gauss":
        lateral_kernels = f"""{{
                "cedar.aux.kernel.Gauss": {{
                    "dimensionality": "2",
                    "anchor": ["0", "0"],
                    "amplitude": "{k['amp']}",
                    "sigmas": ["{k['sigma']}", "{k['sigma']}"],
                    "normalize": "true",
                    "shifts": ["0", "0"],
                    "limit": "10"
                }}
            }}"""
    else:
        lateral_kernels = f"""{{
                "cedar.aux.kernel.Gauss": {{
                    "dimensionality": "2",
                    "anchor": ["0", "0"],
                    "amplitude": "{k['amp_exc']}",
                    "sigmas": ["{k['sigma_exc']}", "{k['sigma_exc']}"],
                    "normalize": "true",
                    "shifts": ["0", "0"],
                    "limit": "10"
                }},
                "cedar.aux.kernel.Gauss": {{
                    "dimensionality": "2",
                    "anchor": ["0", "0"],
                    "amplitude": "-{k['amp_inh']}",
                    "sigmas": ["{k['sigma_inh']}", "{k['sigma_inh']}"],
                    "normalize": "true",
                    "shifts": ["0", "0"],
                    "limit": "10"
                }}
            }}"""

    # Global inhibition: Cedar adds global_inhibition * sum(sigmoid(u)); carry the
    # signed (negative) value directly, same as dnfc amp_global (see cedar-notes.md).
    # Applies to selection (gauss kernel) and 2D memory (mexican hat) alike.
    global_inh = "0"
    if k.get("amp_global", 0.0) != 0.0:
        global_inh = str(k["amp_global"])

    # Connections: each GaussInput -> field input. No lateral self-connection
    # (the field's kernel is internal). Slot name is "Gauss input".
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
            "dimensionality": "2",
            "sizes": ["{FIELD}", "{FIELD}"],
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
                "dimensionality": "2", "anchor": ["0", "0"],
                "amplitude": "0", "sigmas": ["3", "3"],
                "normalize": "true", "shifts": ["0", "0"], "limit": "5"
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
# Cosivina (MATLAB) generator (2D)
# ---------------------------------------------------------------------------

def _cosivina_2d_stimuli(sim):
    stims = sim["stimuli"]
    n = len(stims)
    lines, names = [], []
    for i, st in enumerate(stims):
        name = f"stimulus {i+1}" if n > 1 else "stimulus"
        names.append(name)
        c = pos2d(st["pos"])
        # GaussStimulus2D(label, size, sigmaY, sigmaX, amplitude, positionY, positionX, circY, circX, normalized)
        lines.append(
            f"sim.addElement(GaussStimulus2D('{name}', fieldSize, "
            f"{st['sigma']}, {st['sigma']}, {st['amp']}, {c}, {c}, true, true, false));"
        )
    add_str = "\n".join(lines)
    sum_inputs = "{" + ", ".join(f"'{n_}'" for n_ in names) + "}"
    zero_str = "\n".join(
        f"sim.setElementParameters('{n_}', {{'amplitude'}}, {{0}});" for n_ in names
    )
    restore_str = "\n".join(
        f"sim.setElementParameters('{names[i]}', {{'amplitude'}}, {{{st['amp']}}});"
        for i, st in enumerate(stims)
    )
    return add_str, sum_inputs, zero_str, restore_str


def build_cosivina_script_2d(sim: dict, output_dir: str) -> str:
    sid, stype, k = sim["id"], sim["type"], sim["kernel"]
    add_stim, sum_inputs, set_zero, restore_stim = _cosivina_2d_stimuli(sim)

    if k["type"] == "gauss" and k.get("amp_global", 0.0) == 0.0:
        # GaussKernel2D(label, size, sigmaY, sigmaX, amplitude, circY, circX, normalized)
        kernel_line = (
            f"sim.addElement(GaussKernel2D('u -> u', fieldSize, "
            f"{k['sigma']}, {k['sigma']}, {k['amp']}, true, true, true), "
            f"'field u', 'output', 'field u');"
        )
    elif k["type"] == "gauss":
        # LateralInteractions2D(label,size,sigmaExcY,sigmaExcX,ampExc,sigmaInhY,sigmaInhX,ampInh,ampGlobal,circY,circX,normalized)
        kernel_line = (
            f"sim.addElement(LateralInteractions2D('u -> u', fieldSize, "
            f"{k['sigma']}, {k['sigma']}, {k['amp']}, 0, 0, 0, {k['amp_global']}, true, true, true), "
            f"'field u', 'output', 'field u');"
        )
    else:
        kernel_line = (
            f"sim.addElement(LateralInteractions2D('u -> u', fieldSize, "
            f"{k['sigma_exc']}, {k['sigma_exc']}, {k['amp_exc']}, "
            f"{k['sigma_inh']}, {k['sigma_inh']}, {k['amp_inh']}, {k.get('amp_global', 0.0)}, true, true, true), "
            f"'field u', 'output', 'field u');"
        )

    out_dir_str = output_dir.replace("\\", "/")
    return f"""%% Simulation sim_{sid} (2D) — type: {stype}
% Auto-generated. Do not edit manually.

fieldSize = [{FIELD}, {FIELD}];
sim = Simulator();
sim.deltaT = {int(DELTA_T)};

{add_stim}
sim.addElement(SumInputs('stimulus sum', fieldSize), {sum_inputs});

sim.addElement(NeuralField('field u', fieldSize, {int(TAU)}, {sim['h']}, 100), 'stimulus sum');

{kernel_line}

outputDir = '{out_dir_str}';

%% Phase 1: stimulus ON — 500 steps
sim.init();
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_{sid}_sigmoid_b100_with_stimulus.csv'));

%% Phase 2: stimulus OFF — 500 steps
{set_zero}
for t = 1:500
    sim.step();
end
u = sim.getComponent('field u', 'activation');
writematrix(reshape(u', 1, []), fullfile(outputDir, 'sim_{sid}_sigmoid_b100_without_stimulus.csv'));

%% Re-initialise (restores all parameters to construction values)
{restore_stim}
sim.init();
"""


# ---------------------------------------------------------------------------
# cosivina-python generator (2D)
# ---------------------------------------------------------------------------

def _python_2d_stimuli(sim):
    stims = sim["stimuli"]
    n = len(stims)
    lines, names = [], []
    for i, st in enumerate(stims):
        name = f"stimulus {i+1}" if n > 1 else "stimulus"
        names.append(name)
        c = pos2d(st["pos"])
        lines.append(
            f"    sim.addElement(\n"
            f"        GaussStimulus2D('{name}', FIELD_SIZE,\n"
            f"                        sigmaY={st['sigma']}, sigmaX={st['sigma']}, amplitude={st['amp']},\n"
            f"                        positionY={c}, positionX={c},\n"
            f"                        circularY=True, circularX=True, normalized=False))"
        )
    add_str = "\n".join(lines)
    sum_arg = repr(names) if n > 1 else repr(names[0])
    zero_str = "\n".join(
        f"    sim.setElementParameters('{name}', 'amplitude', 0.0)" for name in names
    )
    restore_str = "\n".join(
        f"    sim.setElementParameters('{names[i]}', 'amplitude', {st['amp']})"
        for i, st in enumerate(stims)
    )
    return add_str, sum_arg, zero_str, restore_str


def build_cosivina_python_script_2d(sim: dict, output_dir: str) -> str:
    sid, stype, k = sim["id"], sim["type"], sim["kernel"]
    add_stim, sum_arg, set_zero, restore_stim = _python_2d_stimuli(sim)

    if k["type"] == "gauss" and k.get("amp_global", 0.0) == 0.0:
        kernel_lines = (
            f"    sim.addElement(\n"
            f"        GaussKernel2D('u->u', FIELD_SIZE,\n"
            f"                      sigmaY={k['sigma']}, sigmaX={k['sigma']}, amplitude={k['amp']},\n"
            f"                      circularY=True, circularX=True, normalized=True),\n"
            f"        inputLabels='field u', inputComponents='output',\n"
            f"        targetLabels='field u')"
        )
    elif k["type"] == "gauss":
        kernel_lines = (
            f"    sim.addElement(\n"
            f"        LateralInteractions2D('u->u', FIELD_SIZE,\n"
            f"                              sigmaExcY={k['sigma']}, sigmaExcX={k['sigma']}, amplitudeExc={k['amp']},\n"
            f"                              sigmaInhY=0.0, sigmaInhX=0.0, amplitudeInh=0.0,\n"
            f"                              amplitudeGlobal={k['amp_global']},\n"
            f"                              circularY=True, circularX=True, normalized=True),\n"
            f"        inputLabels='field u', inputComponents='output',\n"
            f"        targetLabels='field u')"
        )
    else:
        kernel_lines = (
            f"    sim.addElement(\n"
            f"        LateralInteractions2D('u->u', FIELD_SIZE,\n"
            f"                              sigmaExcY={k['sigma_exc']}, sigmaExcX={k['sigma_exc']}, amplitudeExc={k['amp_exc']},\n"
            f"                              sigmaInhY={k['sigma_inh']}, sigmaInhX={k['sigma_inh']}, amplitudeInh={k['amp_inh']},\n"
            f"                              amplitudeGlobal={k.get('amp_global', 0.0)},\n"
            f"                              circularY=True, circularX=True, normalized=True),\n"
            f"        inputLabels='field u', inputComponents='output',\n"
            f"        targetLabels='field u')"
        )

    out_dir_str = output_dir.replace("\\", "/")
    return f'''# sim_{sid}.py (2D) — type: {stype}
# Auto-generated. Do not edit manually.

import os
import sys
import numpy as np
from pathlib import Path

_COSIVINA_PYTHON_ROOT = Path(__file__).resolve().parents[4] / "cosivina_python"
if str(_COSIVINA_PYTHON_ROOT) not in sys.path:
    sys.path.insert(0, str(_COSIVINA_PYTHON_ROOT))

# Variant selected by the runner via the COSIVINA_VARIANT env var ("numba" |
# "nonumba"); defaults to nonumba for standalone execution. The two variants share
# this file — only the imported backend differs.
_variant = os.environ.get("COSIVINA_VARIANT", "nonumba")
_mod = __import__(
    "cosivina.numba" if _variant == "numba" else "cosivina.nonumba",
    fromlist=["Simulator", "GaussStimulus2D", "SumInputs",
              "NeuralField", "GaussKernel2D", "LateralInteractions2D"],
)
Simulator, GaussStimulus2D, SumInputs = _mod.Simulator, _mod.GaussStimulus2D, _mod.SumInputs
NeuralField, GaussKernel2D, LateralInteractions2D = _mod.NeuralField, _mod.GaussKernel2D, _mod.LateralInteractions2D

FIELD_SIZE = ({FIELD}, {FIELD})
TAU        = {TAU}
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
               [u.ravel()], delimiter=",", fmt="%.15g")

    # Phase 2: stimulus OFF — 500 steps
{set_zero}
    for _ in range(500):
        sim.step()
    u = sim.getComponent("field u", "activation")
    np.savetxt(os.path.join(output_dir, "sim_{sid}_sigmoid_b100_without_stimulus.csv"),
               [u.ravel()], delimiter=",", fmt="%.15g")

    # Restore stimulus amplitudes
{restore_stim}
    sim.init()


if __name__ == "__main__":
    run()
'''


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    dnfc_act_fns  = ["abssigmoid_b100", "heaviside", "sigmoid_b100"]
    cedar_act_fns = ["abssigmoid_b100", "heaviside"]

    cosivina_out        = str(ROOT / "data" / "cosivina")
    cosivina_python_out = str(ROOT / "data" / "cosivina-python")

    for d in (COSIVINA_DIR, COSIVINA_PYTHON_DIR, DNFC_DIR,
              CEDAR_OPENCV_DIR, CEDAR_FFTW_DIR):
        d.mkdir(parents=True, exist_ok=True)

    n_written = 0
    for sim_1d in SIMS:
        sim = to_2d_params(sim_1d)   # apply per-type 2D amplitude adjustment
        sid = sim["id"]

        (COSIVINA_DIR / f"sim_{sid}.m").write_text(
            build_cosivina_script_2d(sim, cosivina_out), encoding="utf-8")
        n_written += 1

        (COSIVINA_PYTHON_DIR / f"sim_{sid}.py").write_text(
            build_cosivina_python_script_2d(sim, cosivina_python_out), encoding="utf-8")
        n_written += 1

        for afn in dnfc_act_fns:
            (DNFC_DIR / f"sim_{sid}_{afn}.json").write_text(
                json.dumps(build_dnfc_json_2d(sim, afn), indent=4), encoding="utf-8")
            n_written += 1

        for afn in cedar_act_fns:
            for cedar_dir, engine in (
                (CEDAR_OPENCV_DIR, "cedar.aux.conv.OpenCV"),
                (CEDAR_FFTW_DIR,   "cedar.aux.conv.FFTW"),
            ):
                (cedar_dir / f"sim_{sid}_{afn}.json").write_text(
                    build_cedar_json_2d(sim, afn, engine=engine), encoding="utf-8")
                n_written += 1

    print(f"Written {n_written} 2D simulation files.")
    print(f"  cosivina:        {len(SIMS)} .m files")
    print(f"  cosivina-python: {len(SIMS)} .py files")
    print(f"  dnfc:            {len(SIMS) * len(dnfc_act_fns)} .json files")
    print(f"  cedar-opencv:    {len(SIMS) * len(cedar_act_fns)} .json files")
    print(f"  cedar-fftw:      {len(SIMS) * len(cedar_act_fns)} .json files")


if __name__ == "__main__":
    main()
