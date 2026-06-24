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

Behavioural and (float64) algebraic equivalence hold in 2D. Run over all four frameworks
(dnfc, Cedar, Cosivina, cosivina-python):

### Behavioural reliability

**1200 / 1200 comparisons (100%)** agree on the qualitative field state (suprathreshold bump vs.
subthreshold resting) across all frameworks, architecture types, and phases — including the
self-sustaining memory bumps.

### Algebraic equivalence (same activation-function family)

| Comparison pair | Max abs(Δu) | Median | Threshold | Result |
|---|---:|---:|---:|---|
| Cosivina Sigmoid vs dnfc Sigmoid | 5.0×10⁻⁵ | 5×10⁻⁶ | 1×10⁻⁴ | **PASS** (all types) |
| cosivina-python Sigmoid vs dnfc Sigmoid | 5.0×10⁻⁵ | 5×10⁻⁶ | 1×10⁻⁴ | **PASS** (all types) |
| cosivina-python Sigmoid vs Cosivina Sigmoid | 1.0×10⁻¹³ | 1×10⁻¹⁵ | 1×10⁻⁴ | **PASS** (all types) |
| Cedar AbsSigmoid vs dnfc AbsSigmoid | 2.89 (memory only) | 1×10⁻⁵ | 2×10⁻⁴ | **PASS** 4/5 types; memory: float32 limit (see note) |
| Cedar Heaviside vs dnfc Heaviside | 1.03 (memory only) | 1×10⁻⁵ | 2×10⁻⁴ | **PASS** 4/5 types; memory: float32 limit (see note) |

- **All three float64 pairs are algebraically equivalent in 2D** to 5×10⁻⁵ across **every** sim
  and type, **including memory** (cosivina ↔ dnfc, cosivina-python ↔ dnfc both 5×10⁻⁵;
  cosivina-python ↔ cosivina ~1×10⁻¹³). This confirms the 2D separable convolution, border
  handling, and the self-sustaining bump's attractor are reproduced exactly across independent
  float64 implementations.
- **Cedar (float32) vs dnfc (float64)** is **PASS for detection, selection, insufficient, and
  multi-peak** (max ≤ 1×10⁻⁴). The **memory architecture is the sole exception**: **all 20 memory
  sims exceed the 2×10⁻⁴ threshold** (both Cedar pairs, both phases — 80 comparisons). Of these,
  **~10 diverge by a full perimeter ring** — the self-sustaining bistable bump settles at a
  *different radius* in float32 vs float64 (e.g. sim 050: Cedar 177 cells vs dnfc 164; heaviside
  041–043: 137 vs 121), producing **field-wide** deviations up to **2.89**. The remaining memory
  comparisons differ by ~0.06–0.12 at the bump rim.
- This is **intrinsic to float32, not tunable and not a bug.** A parameter sweep (global inhibition
  −0.05→−0.18; inhibitory amplitude ×2.5→×4.0) only **relocates** which sim's equilibrium radius
  lands on a ring boundary — it never eliminates the divergence, and stronger settings instead
  collapse the weaker bumps' self-sustain. Because the bistable bump radius is effectively
  quantized (a whole ring of cells switches at once), for any parameter set some sim sits within
  float32 epsilon of a ring boundary and tips the opposite way from float64. The float64 pairs
  agree to 5×10⁻⁵ on these *same* sims, so the cause is precision, not the architecture. **Removing
  it would require running Cedar's core in CV_64F (CV_32F is hard-wired across ~131 Cedar source
  files), i.e. a non-standard double-precision build — float32 is Cedar's actual design choice, so
  we report it rather than fork the library.** Behaviour agrees **100%** (every memory bump is
  present and centred identically in all frameworks).

See `fig_difference_2d.pdf` for the per-type Cedar−dnfc difference maps (after the +1,+1 offset
correction) and `fig_fields_2d.pdf` for representative 2D fields.

## Notes / findings

- **Cedar 2D offset:** Cedar's 2D field is shifted **+1 in both axes** vs dnfc; `analysis_2d.R`
  corrects this with a 2D roll (the analog of the 1D `roll_left`). After correction, non-memory
  same-family deviations drop to ≤ 1×10⁻⁴ (memory remains float32-limited as described above).
- **dnfc 2D loader fix:** dnfc's 2D JSON loader did not handle the `abs_sigmoid` activation function
  (and lacked a null-guard), crashing on load. Fixed in `simulation_file_manager.cpp` to match the
  1D path (see `../.claude/cedar-notes.md`).
- **2D kernel re-normalization:** memory and selection required per-type amplitude adjustment for 2D
  (a normalized 2D Gaussian is ~7.5× weaker at peak than 1D). See `test_suite_2d.md`.
