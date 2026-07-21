# 2D cross-platform validation — test suite

The 2D suite reuses the **exact same 100-simulation parameter table** as the 1D suite
(`../cross-platform-validation/test_suite.md`), grouped into the same five architecture types
(20 sims each): detection (001–020), selection (021–040), memory (041–060), insufficient
(061–080), multi-peak (081–100). Each sim is run in two phases — 500 steps with the stimulus ON,
then 500 steps with the stimulus OFF — across all four frameworks.

What differs from 1D is purely the **2D embedding** of those parameters, described below.

## Grid and protocol

| Quantity | 1D | 2D |
|---|---|---|
| Field | 100 | 50 × 50 (2500 cells) |
| Spacing | d_x = 1 | d_x = d_y = 1 |
| τ / Δt | 25 / 25 ms | 25 / 25 ms (unchanged) |
| Boundary | cyclic | cyclic (both axes) |
| Output CSV | 1 row × 100 | 1 row × 2500 (row-major flatten of the 50×50 field) |

## Position mapping (1D → 2D)

The 1D table places stimuli on a 0–100 axis. Each position `p` is rescaled by ½ onto the 50-grid
and placed on the **grid diagonal** at `(p/2, p/2)`. This keeps multi-stimulus / selection bumps
well separated, e.g. selection stimuli at 25 and 75 map to `(12.5, 12.5)` and `(37.5, 37.5)`.
Stimulus and kernel widths (σ) are isotropic (σ_x = σ_y = the 1D σ).

## Per-type 2D amplitude adjustment (the one non-mechanical change)

A normalized 2D Gaussian's peak is `~1/(2πσ²)` versus `~1/(σ√(2π))` in 1D — roughly **7.5× smaller**
for σ = 3. So the same kernel `amplitude` gives far weaker lateral coupling in 2D. Carrying the 1D
amplitudes over verbatim, three of the five types already behave correctly, but **memory** does not
self-sustain and **selection** produces no bump. The sanity gate (running one sim per type through
the frameworks and checking the intended phenomenon) produced these adjustments:

| Type | 2D amplitude rule vs 1D | Verified 2D behaviour |
|---|---|---|
| detection | unchanged | ON: centred bump (~145 cells); OFF: decays to resting |
| insufficient | unchanged | ON & OFF: stays sub-threshold (no bump) |
| multi-peak | unchanged | ON: multiple coexisting bumps; OFF: decay |
| selection | kernel excitatory amplitude **× 4** (global inhibition unchanged) | ON: winner-take-all (one bump > 0, other ≤ 0) |
| memory | excitatory & inhibitory amplitudes **× 2.5** + global inhibition **−0.05** | ON: localized bump; OFF: **self-sustaining** localized bump |

These rules are applied by `to_2d_params()` in `generate_simulations_2d.py`; everything else (h,
σ, positions, the full parameter sweep within each type) is inherited unchanged from the 1D table.
Without the memory adjustment the bump either collapses (too weak) or floods the whole field (no
containment); the chosen values give a compact bump that persists after stimulus removal.

## Frameworks and activation functions

Identical to 1D: dnfc (3 activation functions: abs_sigmoid β=100, heaviside, sigmoid β=100),
Cedar (abs_sigmoid β=100, heaviside; float32), Cosivina and cosivina-python (sigmoid β=100;
float64). The 100 generated cosivina-python `.py` files are shared by all three cosivina-python
variants — **numba** and **nonumba** use the spatial kernel element, **fft** uses cosivina's
spectral `KernelFFT` element (full untruncated FFT convolution) — selected at run time via the
`COSIVINA_VARIANT` env var, so no extra sim files are generated.
