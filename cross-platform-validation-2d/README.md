# 2D Cross-Platform Validation

The 2D counterpart of [`../cross-platform-validation/`](../cross-platform-validation/). It runs the
**same 100-simulation, 5-architecture test suite** on **2D (50×50) fields** across the four DFT
frameworks and checks **algebraic equivalence** (same activation-function family agrees to numerical
precision) and **behavioural reliability** (qualitative bump/no-bump state agrees).

**Frameworks compared:** Cedar (C++, float32), Cosivina (MATLAB, float64), cosivina-python
(Python/NumPy, float64), dnfc (C++, float64) — same as 1D.

## Layout

| Path | Contents |
|---|---|
| `generate_simulations_2d.py` | Generates all 700 2D simulation files (reuses the 1D parameter table; see `test_suite_2d.md`) |
| `simulations/{dnfc,cedar,cosivina,cosivina-python}/` | Generated 2D simulation definitions |
| `runners/` | One runner per framework (see below) |
| `data/{...}/` | Output: one row of 2500 row-major-flattened activation values per sim × phase |
| `analysis_2d.R` | Loads all CSVs, computes pairwise deviations, PASS/FAIL + behavioural summary, figures |
| `test_suite_2d.md` | The 2D parameter mapping and per-type amplitude rules |

## How to reproduce

1. **Generate**: `python generate_simulations_2d.py` → 700 files (300 dnfc JSON, 200 Cedar JSON,
   100 cosivina `.m`, 100 cosivina-python `.py`).
2. **Run each framework** (each writes flattened 50×50 CSVs to `data/<framework>/`):
   - dnfc: build `runners/dnfc_runner_2d/cross_platform_validation_runner_2d.cpp` inside the
     dnf-composer project (add it to `examples/CMakeLists.txt` via `add_example_executable`), then
     run it with `<simulations/dnfc> <data/dnfc>`.
   - Cedar: build `runners/cedar_runner_2d/cross_platform_validation_2d.cpp` inside the Cedar tree
     (`cedar/executables/cross-platform-validation-2d/`, `cedar_add_executable`); run with the
     dependency DLLs on PATH (see `../.claude/cedar-notes.md`).
   - cosivina (MATLAB): `run('runners/cosivina_runner_2d.m')`.
   - cosivina-python: `python runners/cosivina_python_runner_2d.py`.
3. **Analyse**: `Rscript analysis_2d.R` → `analysis_summary.csv`, `validation_summary.csv`, and
   figures (`fig_fields_2d.pdf`, `fig_difference_2d.pdf`, `fig_boxplots.pdf`,
   `fig_deviation_heatmap.pdf`).

## Results

Behavioural and (float64) algebraic equivalence hold in 2D. Run over dnfc, Cedar, and
cosivina-python (Cosivina/MATLAB pending a MATLAB run):

### Behavioural reliability

**600 / 600 comparisons (100%)** agree on the qualitative field state (suprathreshold bump vs.
subthreshold resting) across all frameworks, architecture types, and phases — including the
self-sustaining memory bumps.

### Algebraic equivalence (same activation-function family)

| Comparison pair | Max abs(Δu) | Median | Threshold | Result |
|---|---:|---:|---:|---|
| cosivina-python Sigmoid vs dnfc Sigmoid | 5.0×10⁻⁵ | 5×10⁻⁶ | 1×10⁻⁴ | **PASS** |
| Cedar AbsSigmoid vs dnfc AbsSigmoid | 2.89 | 1×10⁻⁵ | 2×10⁻⁴ | see note |
| Cedar Heaviside vs dnfc Heaviside | 1.03 | 1×10⁻⁵ | 2×10⁻⁴ | see note |

- **Two float64 frameworks (cosivina-python vs dnfc) are algebraically equivalent in 2D** to
  5×10⁻⁵ — the same precision tier as 1D, confirming the 2D separable convolution and border
  handling match across independent implementations.
- **Cedar (float32) vs dnfc (float64)** agree to a **median of 1×10⁻⁵**, and for **detection,
  insufficient, multi-peak, and selection the max deviation is ≤ 1×10⁻⁴** (all PASS). The headline
  max of 2.89 comes **entirely from the memory architecture** (with-stimulus max 0.55, without
  2.89): the self-sustaining bistable memory bump has a steep 2D activation perimeter where the
  float32/float64 difference is amplified — the bumps agree in location, peak, and size (e.g. sim
  041: both peak at (24,24), ~17.4, ~121 cells) but differ by up to a few units at the edge cells.
  This is a precision/bistability effect, not an algorithmic discrepancy, and behaviour still
  agrees 100%. It is the 2D analog of the memory sensitivity seen in 1D (sims 050/053).

See `fig_difference_2d.pdf` for the per-type Cedar−dnfc difference maps (after the +1,+1 offset
correction) and `fig_fields_2d.pdf` for representative 2D fields.

## Notes / findings

- **Cedar 2D offset:** Cedar's 2D field is shifted **+1 in both axes** vs dnfc; `analysis_2d.R`
  corrects this with a 2D roll (the analog of the 1D `roll_left`). After correction, non-memory
  same-family deviations drop to ≤ 1×10⁻⁴.
- **dnfc 2D loader fix:** dnfc's 2D JSON loader did not handle the `abs_sigmoid` activation function
  (and lacked a null-guard), crashing on load. Fixed in `simulation_file_manager.cpp` to match the
  1D path (see `../.claude/cedar-notes.md`).
- **2D kernel re-normalization:** memory and selection required per-type amplitude adjustment for 2D
  (a normalized 2D Gaussian is ~7.5× weaker at peak than 1D). See `test_suite_2d.md`.
