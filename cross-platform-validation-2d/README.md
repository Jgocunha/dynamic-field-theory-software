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
| `generate_simulations_2d.py` | Generates all 1100 2D simulation files (reuses the 1D parameter table; see `test_suite_2d.md`) |
| `simulations/{cedar-opencv,cedar-fftw,cosivina,cosivina-python,dnfc}/` | Generated 2D simulation definitions (cosivina-python shared by both py variants) |
| `runners/<variant>/run.ps1` | Per-variant runner wrapper (cosivina via `cosivina_runner_2d.m`) |
| `data/<variant>/` | Output: one row of 2500 row-major-flattened activation values per sim × phase |
| `analysis_2d.R` | Loads all CSVs, computes pairwise deviations, PASS/FAIL + behavioural summary, figures |
| `test_suite_2d.md` | The 2D parameter mapping and per-type amplitude rules |

### Per-variant counts

| Variant | configs | CSVs (×2 phases) |
|---|---:|---:|
| cedar-opencv | 300 | 600 |
| cedar-fftw | 300 | 600 |
| cosivina (MATLAB) | 100 | 200 |
| cosivina-python-numba | 100 (shared) | 200 |
| cosivina-python-nonumba | 100 (shared) | 200 |
| dnfc | 300 | 600 |

## How to reproduce

1. **Generate**: `python generate_simulations_2d.py` → 1100 files (300 dnfc JSON, 300 cedar-opencv
   JSON, 300 cedar-fftw JSON, 100 cosivina `.m`, 100 cosivina-python `.py`).
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
multi-peak (max|Δu| = 0). On **memory**, both engines now keep a self-sustaining bump — earlier
data showed FFTW's memory bump *collapsing* entirely, but that was traced to two now-fixed bugs
(the kernel-limit units mismatch meant FFTW's kernel didn't reliably fit, and the validation runner
had no exception guard, so a convolution-engine exception silently produced frozen/wrong output
instead of being skipped). With both fixed and the data regenerated, FFTW's memory bump behaves like
OpenCV's: present in both engines, differing only in the bistable attractor's *settled radius* (the
same precision knife-edge as the Cedar-vs-dnfc memory case, below) — not in whether a bump exists at
all.

## Results

Behavioural and (float64) algebraic equivalence hold in 2D. Run over all six variants
(Cedar-OpenCV, Cedar-FFTW, Cosivina, cosivina-python-numba, cosivina-python-nonumba, dnfc):

### Behavioural reliability

**4200 / 4200 comparisons (100%)** agree on the qualitative field state (suprathreshold bump vs.
subthreshold resting) across all 21 same-activation pairs, architecture types, and phases —
**including every memory pair on both Cedar engines.** This is an improvement over an earlier
measurement that showed FFTW-involving memory pairs disagreeing behaviourally (bump collapsed in
FFTW but not OpenCV/dnfc); that was traced to two bugs, not a real FFTW limitation — see "Cedar
OpenCV vs FFTW equivalence (2D)" above.

### Algebraic equivalence (same activation-function family, 21 pairs)

A quantitative `max|Δu|` test is only run **within** an activation-function family; every C(n,2)
variant pair is computed → 3 (AbsSig) + 3 (Heaviside) + 15 (Sigmoid, C(6,2) since Cedar now has a
working logistic-sigmoid variant too) = **21**. Max abs(Δu) is over 100 sims × 2 phases. Any pair
with a Cedar side carries a 2×10⁻⁴ ceiling; all-float64 pairs 1×10⁻⁴. **8/21 pass, 13/21 fail** —
every failure is isolated to the **memory** architecture type (confirmed per-type: all four other
types stay at the float32 rounding ceiling, ~1×10⁻⁴); the passing 8 are exactly the pairs with no
Cedar-vs-(dnfc/Cosivina/cosivina-python) leg at all (the two same-precision opencv↔fftw pairs, plus
all six all-float64 pairs).

| Family | Pair | Max abs(Δu) | Threshold | Result |
|---|---|---:|---:|---|
| AbsSig | cedar_opencv_vs_cedar_fftw | 1.0×10⁻⁴ | 2×10⁻⁴ | **PASS** |
| AbsSig | cedar_opencv_vs_dnfc | 2.58 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| AbsSig | cedar_fftw_vs_dnfc | 2.58 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Heaviside | cedar_opencv_vs_cedar_fftw | 1.0×10⁻⁴ | 2×10⁻⁴ | **PASS** |
| Heaviside | cedar_opencv_vs_dnfc | 0.021 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Heaviside | cedar_fftw_vs_dnfc | 0.021 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cedar_opencv_vs_cedar_fftw | 0.489 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cedar_opencv_vs_dnfc | 0.599 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cedar_fftw_vs_dnfc | 0.599 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cedar_opencv_vs_cosivina | 0.599 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cedar_opencv_vs_cpy_numba | 0.599 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cedar_opencv_vs_cpy_nonumba | 0.599 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cedar_fftw_vs_cosivina | 0.599 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cedar_fftw_vs_cpy_numba | 0.599 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cedar_fftw_vs_cpy_nonumba | 0.599 (memory) | 2×10⁻⁴ | **FAIL** memory only |
| Sigmoid | cosivina_vs_cpy_numba | 1.0×10⁻¹³ | 1×10⁻⁴ | **PASS** |
| Sigmoid | cosivina_vs_cpy_nonumba | 1.0×10⁻¹³ | 1×10⁻⁴ | **PASS** |
| Sigmoid | cosivina_vs_dnfc | 5.0×10⁻⁵ | 1×10⁻⁴ | **PASS** |
| Sigmoid | cpy_numba_vs_cpy_nonumba | 1.0×10⁻¹³ | 1×10⁻⁴ | **PASS** |
| Sigmoid | cpy_numba_vs_dnfc | 5.0×10⁻⁵ | 1×10⁻⁴ | **PASS** |
| Sigmoid | cpy_nonumba_vs_dnfc | 5.0×10⁻⁵ | 1×10⁻⁴ | **PASS** |

- **All six float64 sigmoid pairs are algebraically equivalent in 2D** to 5×10⁻⁵ across **every** sim
  and type, **including memory** (cosivina / cosivina-python / dnfc all 5×10⁻⁵; numba↔nonumba and
  cosivina↔cosivina-python ~1×10⁻¹³). This confirms the 2D separable convolution, border handling,
  and the self-sustaining bump's attractor are reproduced exactly across independent float64
  implementations.
- **Every Cedar-involving pair is PASS for detection, selection, insufficient, and multi-peak**
  (max ≤ 1×10⁻⁴) and **FAILs only on memory** — for every activation function and both engines alike.
  The self-sustaining bistable bump settles at a *different radius* in float32 (Cedar, either engine)
  vs float64 (e.g. sim 050: Cedar 177 cells vs dnfc 166), giving field-wide deviations up to **~2.6**
  — but the bump is **present in both**, so behaviour still agrees 100% (previous data showing FFTW's
  bump *absent* was the now-fixed bug described above, not a real engine difference).
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
  Cedar's actual design choice, so we report it rather than fork the library. Both Cedar engines vs
  dnfc agree behaviourally **100%** (the memory bump is present and centred identically in every
  engine/framework combination; only its settled radius differs) — see the "Cedar OpenCV vs FFTW
  equivalence (2D)" note above for why an earlier measurement showed FFTW disagreeing.

See `fig_difference_2d.pdf` for the per-type Cedar−dnfc difference maps (after the +1,+1 offset
correction) and `fig_fields_2d.pdf` for representative 2D fields.

## Notes / findings

- **Cedar 2D offset:** Cedar's 2D field is shifted **+1 in both axes** vs dnfc; `analysis_2d.R`
  corrects this with a 2D roll (the analog of the 1D `roll_left`). After correction, non-memory
  same-family deviations drop to ≤ 1×10⁻⁴ (memory remains float32-limited as described above).