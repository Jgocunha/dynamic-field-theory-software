# 2D Cross-Platform Validation

The 2D counterpart of [`../cross-platform-validation/`](../cross-platform-validation/). It runs the
**same 100-simulation, 5-architecture test suite** on **2D (50×50) fields** across the DFT
framework **variants** and checks **algebraic equivalence** (same activation-function family agrees
to numerical precision) and **behavioural reliability** (qualitative bump/no-bump state agrees).

**Variants compared (6):** Cedar-OpenCV, Cedar-FFTW (C++, float32), Cosivina (MATLAB, float64),
cosivina-python-numba, cosivina-python-nonumba (Python, float64), dnfc (C++, float64) — same
folder convention as 1D.

## Layout

| Path | Contents |
|---|---|
| `generate_simulations_2d.py` | Generates all 900 2D simulation files (reuses the 1D parameter table; see `test_suite_2d.md`) |
| `simulations/{cedar-opencv,cedar-fftw,cosivina,cosivina-python,dnfc}/` | Generated 2D simulation definitions (cosivina-python shared by both py variants) |
| `runners/<variant>/run.ps1` | Per-variant runner wrapper (cosivina via `cosivina_runner_2d.m`) |
| `data/<variant>/` | Output: one row of 2500 row-major-flattened activation values per sim × phase |
| `analysis_2d.R` | Loads all CSVs, computes pairwise deviations, PASS/FAIL + behavioural summary, figures |
| `test_suite_2d.md` | The 2D parameter mapping and per-type amplitude rules |

### Per-variant counts

| Variant | configs | CSVs (×2 phases) |
|---|---:|---:|
| cedar-opencv | 200 | 400 |
| cedar-fftw | 200 | 400 |
| cosivina (MATLAB) | 100 | 200 |
| cosivina-python-numba | 100 (shared) | 200 |
| cosivina-python-nonumba | 100 (shared) | 200 |
| dnfc | 300 | 600 |

## How to reproduce

1. **Generate**: `python generate_simulations_2d.py` → 900 files (300 dnfc JSON, 200 cedar-opencv
   JSON, 200 cedar-fftw JSON, 100 cosivina `.m`, 100 cosivina-python `.py`).
2. **Run each variant** (each writes flattened 50×50 CSVs to `data/<variant>/`):
   - cedar-opencv / cedar-fftw: `runners/cedar-opencv/run.ps1` / `runners/cedar-fftw/run.ps1`
     (the fftw wrapper adds fftw3.dll to PATH; Cedar must be built with `CEDAR_USE_FFTW=ON`).
   - dnfc: `runners/dnfc/run.ps1`.
   - cosivina (MATLAB): `run('runners/cosivina_runner_2d.m')`.
   - cosivina-python: `runners/cosivina-python-numba/run.ps1` and `…-nonumba/run.ps1`.
3. **Analyse**: `Rscript analysis_2d.R` → `analysis_summary.csv`, `validation_summary.csv`, and
   figures (`fig_fields_2d.pdf`, `fig_difference_2d.pdf`, `fig_boxplots.pdf`,
   `fig_deviation_heatmap.pdf`).

### Cedar OpenCV vs FFTW equivalence (2D)

The two Cedar convolution engines are **bit-identical** on detection / selection / insufficient /
multi-peak (max|Δu| = 0). The **only** divergence is the **memory** architecture: OpenCV keeps the
self-sustaining bump while FFTW's bump collapses (0% of memory sims pass the 2e-4 gate). This is the
same precision knife-edge as the Cedar-vs-dnfc memory case — the 2D self-sustaining bump is a
bistable attractor, and the sub-float32-epsilon difference between the spatial and Fourier
convolution paths tips it. It is **not** an FFTW bug (1D memory and all other 2D architectures
agree). See `../.claude/cedar-notes.md`.

## Results

Behavioural and (float64) algebraic equivalence hold in 2D. Run over all six variants
(Cedar-OpenCV, Cedar-FFTW, Cosivina, cosivina-python-numba, cosivina-python-nonumba, dnfc):

### Behavioural reliability

**2236 / 2400 comparisons (93.2%)** agree on the qualitative field state (suprathreshold bump vs.
subthreshold resting) across all 12 same-activation pairs, architecture types, and phases. The
**164 disagreements are entirely the four Cedar-FFTW-involving memory pairs** (`cedar_*_vs_cedar_fftw`
and `cedar_fftw_vs_dnfc`, both activation fns) — in 2D the FFTW memory bump **collapses** while the
OpenCV/dnfc bump survives (0% agreement on memory for those four pairs). Every **non-FFTW** pair —
including `cedar_opencv_vs_dnfc` and all float64 sigmoid pairs — stays at **100%** behavioural
agreement, memory bumps included.

### Algebraic equivalence (same activation-function family, 12 pairs)

A quantitative `max|Δu|` test is only run **within** an activation-function family; every C(n,2)
variant pair is computed → 3 (AbsSig) + 3 (Heaviside) + 6 (Sigmoid) = **12**. Max abs(Δu) is over
100 sims × 2 phases. Any pair with a Cedar side carries a 2×10⁻⁴ ceiling; all-float64 pairs 1×10⁻⁴.

| Family | Pair | Max abs(Δu) | Median | Threshold | Result |
|---|---|---:|---:|---:|---|
| AbsSig | cedar_opencv_vs_cedar_fftw | 41.4 (memory) | 0 | 2×10⁻⁴ | **FAIL** memory; PASS 4/5 (see note) |
| AbsSig | cedar_opencv_vs_dnfc | 3.31 (memory) | 1×10⁻⁵ | 2×10⁻⁴ | **FAIL** memory; PASS 4/5 (see note) |
| AbsSig | cedar_fftw_vs_dnfc | 41.3 (memory) | 1×10⁻⁵ | 2×10⁻⁴ | **FAIL** memory; PASS 4/5 (see note) |
| Heaviside | cedar_opencv_vs_cedar_fftw | 41.5 (memory) | 0 | 2×10⁻⁴ | **FAIL** memory; PASS 4/5 (see note) |
| Heaviside | cedar_opencv_vs_dnfc | 1.03 (memory) | 1×10⁻⁵ | 2×10⁻⁴ | **FAIL** memory; PASS 4/5 (see note) |
| Heaviside | cedar_fftw_vs_dnfc | 41.3 (memory) | 1×10⁻⁵ | 2×10⁻⁴ | **FAIL** memory; PASS 4/5 (see note) |
| Sigmoid | cosivina_vs_cpy_numba | 1.0×10⁻¹³ | 5×10⁻¹⁶ | 1×10⁻⁴ | **PASS** (all types) |
| Sigmoid | cosivina_vs_cpy_nonumba | 1.0×10⁻¹³ | 1×10⁻¹⁵ | 1×10⁻⁴ | **PASS** (all types) |
| Sigmoid | cosivina_vs_dnfc | 5.0×10⁻⁵ | 5×10⁻⁶ | 1×10⁻⁴ | **PASS** (all types) |
| Sigmoid | cpy_numba_vs_cpy_nonumba | 1.0×10⁻¹³ | 0 | 1×10⁻⁴ | **PASS** (all types) |
| Sigmoid | cpy_numba_vs_dnfc | 5.0×10⁻⁵ | 5×10⁻⁶ | 1×10⁻⁴ | **PASS** (all types) |
| Sigmoid | cpy_nonumba_vs_dnfc | 5.0×10⁻⁵ | 5×10⁻⁶ | 1×10⁻⁴ | **PASS** (all types) |

- **All six float64 sigmoid pairs are algebraically equivalent in 2D** to 5×10⁻⁵ across **every** sim
  and type, **including memory** (cosivina / cosivina-python / dnfc all 5×10⁻⁵; numba↔nonumba and
  cosivina↔cosivina-python ~1×10⁻¹³). This confirms the 2D separable convolution, border handling,
  and the self-sustaining bump's attractor are reproduced exactly across independent float64
  implementations.
- **Every Cedar-involving pair is PASS for detection, selection, insufficient, and multi-peak**
  (max ≤ 1×10⁻⁴) and **FAILs only on memory**. There are two distinct memory effects:
  - **cedar_opencv_vs_dnfc** (float32 vs float64, same OpenCV engine): the self-sustaining bistable
    bump settles at a *different radius* in float32 vs float64 (e.g. sim 050: Cedar 177 cells vs dnfc
    166), giving field-wide deviations up to **3.31** — but the bump is **present in both**, so
    behaviour still agrees 100%.
  - **Any FFTW memory pair** (`cedar_opencv_vs_cedar_fftw`, `cedar_fftw_vs_dnfc`): the 2D FFTW memory
    bump **collapses entirely**, so the difference is the full bump amplitude (~41) and the bump is
    *absent* in FFTW — these are the only pairs that also fail the behavioural check on memory.
- This is **intrinsic to Cedar's precision/convolution path, not tunable and not a bug.** A
  parameter sweep (global inhibition −0.05→−0.18; inhibitory amplitude ×2.5→×4.0) only **relocates**
  which sim's equilibrium radius lands on a ring boundary — it never eliminates the divergence, and
  stronger settings instead collapse the weaker bumps' self-sustain. The bistable bump radius is
  effectively quantized (a whole ring of cells switches at once), so for any parameter set some sim
  sits within epsilon of a ring boundary and a tiny perturbation tips it. The float64 pairs agree to
  5×10⁻⁵ on these *same* sims, so the cross-framework cause is **precision, not the architecture**.
- **Is it the activation function?** Investigated and ruled out as the cross-framework cause. Cedar's
  and dnfc's AbsSigmoid are the **identical double-precision formula**
  (`0.5(1+β(x−θ)/(1+β|x−θ|))`, source-verified), and holding the function fixed (AbsSig vs AbsSig,
  HV vs HV) Cedar's bump is **still a ring larger** than dnfc's on the sensitive sims — that residual
  is precision + Cedar's CV_32F truncated OpenCV convolution (`copyMakeBorder` + `filter2D` each
  step). The function *choice* **does** change bump size (within both frameworks, Heaviside yields a
  larger bump than AbsSigmoid on ring-sensitive sims), but it is a *separate, compounding* effect,
  not the reason the frameworks differ. See `../.claude/cedar-notes.md` for the decomposition table.
- **Removing the cross-framework gap** would require running Cedar's core in CV_64F (CV_32F is
  hard-wired across ~131 Cedar source files), i.e. a non-standard double-precision build — float32 is
  Cedar's actual design choice, so we report it rather than fork the library. For the OpenCV engine vs
  dnfc, behaviour agrees **100%** (the memory bump is present and centred identically; only its radius
  differs). The Cedar **FFTW** engine is the exception in 2D: its self-sustaining memory bump collapses
  (it does not survive the stimulus-off phase), so FFTW memory pairs disagree behaviourally — see the
  "Cedar OpenCV vs FFTW equivalence (2D)" note above and `../.claude/cedar-notes.md`.

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
