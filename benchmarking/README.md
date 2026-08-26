# DFT Framework Benchmark Report (1D)

Throughput (steps/second) of **N independent 1D neural fields** across eight framework
variants, swept over four canonical DFT regimes and three field sizes. The 2D
counterpart lives in [`../benchmarking-2d/`](../benchmarking-2d/).

## Test Machine

| Property | Value |
|---|---|
| CPU | 13th Gen Intel Core i9-13900 (24 cores / 32 threads, up to 5.6 GHz boost) |
| RAM | 32 GB |
| OS | Windows 11 Pro (build 10.0.26200), 64-bit |
| Power plan | High performance (no CPU down-throttling during runs) |
| Compiler (Cedar / dnfc) | MSVC 19.44 (Visual Studio 2022 Community), C++20 |
| Release flags | `/O2 /Ob2 /DNDEBUG` (CMake Release) |
| MATLAB version | R2024b, `maxNumCompThreads(1)` |
| Python version | 3.11.9; numpy 2.2.1; numba 0.66.0 |
| dnfc version | 2.11.0  |
| Cedar version | 6.2.0 — **both** convolution engines benchmarked: OpenCV (spatial) and FFTW (spectral); `cv::setNumThreads(0)` |
| Cosivina version | 1.4.0 (MATLAB) |
| cosivina-python version | 0.1.0 (numba JIT, pure-NumPy, and spectral `KernelFFT` paths all benchmarked) |

**Single-threading is enforced, not assumed.** Each runner pins its math-library thread pools to 1
before timing: Python sets `OMP_NUM_THREADS=OPENBLAS_NUM_THREADS=MKL_NUM_THREADS=NUMBA_NUM_THREADS=1`
(before numpy import); MATLAB calls `maxNumCompThreads(1)`; the Cedar runner calls
`cv::setNumThreads(0)` to disable OpenCV's internal threading; dnfc has no thread pool by
construction (a flat loop over element handles), so its "single-threaded" status is a property of
the code, not a pinned setting — the orchestrator sets `OMP_NUM_THREADS`/`MKL_NUM_THREADS=1` for it
anyway, defensively, for parity with the other three variants' explicit pins. No CPU-affinity pinning
was applied (single-threaded workloads do not require it).

---

## Benchmark Design

Each run creates **N independent neural fields** (N ∈ {5, 10, 50, 100}), tiled copies of one
**canonical DFT regime**, and times the integration loop. The matrix is fully crossed:

**8 variants × 4 regimes × 3 field sizes × 4 N × 10 runs.**

| Axis | Values |
|---|---|
| Framework variants | dnfc · Cedar (OpenCV) · Cedar (FFTW) · Cosivina (MATLAB) · Cosivina (MATLAB, FFT) · cosivina-python (numba) · cosivina-python (NumPy) · cosivina-python (FFT) |
| Canonical regimes | detection · selection · memory · multi-peak |
| Field size (1D) | 100, 500, 1000 cells |
| N (independent fields) | 5, 10, 50, 100 |
| Runs per cell | 10 (warm-up: 200 steps, discarded; timed: 500 steps) |

**Canonical regimes** reuse the representative parameters of the cross-platform-validation suite:

| Regime | h | Lateral kernel | Stimuli |
|---|---|---|---|
| detection | −8 | Gauss (σ=3, a=8) | 1 |
| selection | −10 | Gauss (σ=3, a=5) + global inhibition −0.15 | 2 |
| memory | −5 | Mexican-hat (σ_exc=3.4 a=17.7, σ_inh=8.9 a=13.5) | 1 |
| multi-peak | −8 | Gauss (σ=2, a=5) | 2 |

**Noise is on:** every field includes a `NormalNoise` term with **amplitude A = 0.1**, so per-step
RNG cost is part of the measured workload.

**Kernel cutoff is unified across the five spatial-convolution variants by real tap count, not by a
shared nominal parameter.** dnfc and cosivina/cosivina-python (numba/NumPy) use `cutoffFactor=5` — a
kernel-*radius* multiplier (taps = 2·min(⌈5σ⌉, field-size cap)+1). Cedar's `limit` is a
kernel-*width* multiplier (taps = ⌈limit·σ⌉, rounded to odd) — a different unit, so naively setting
`limit=5` gives Cedar roughly **half** the real convolution work of the other frameworks. Cedar's `limit` is instead
computed per σ and field size (`fairCedarLimit`) to reproduce the *exact same tap count* dnfc uses,
so every spatial framework convolves the same real kernel support. (The spectral variants —
Cedar-FFTW and cosivina-python-FFT — convolve the full field in the Fourier domain, so tap count does
not apply; the validation study confirms they produce the same result as the truncated spatial
convolution.)

**Activation function is matched for the *selection* regime.** dnfc/cosivina/cosivina-python use a
logistic sigmoid; Cedar is configured with `cedar.aux.math.ExpSigmoid`, algebraically identical
(`1/(1+exp(-β(x-θ)))`) to the others' sigmoid — verified by source comparison, not assumed. An
earlier protocol revision used Cedar's `AbsSigmoid` here, which never reached winner-take-all.

**The *memory* regime uses a two-phase protocol** in every framework: the stimulus is applied for
100 steps to establish the bump, then removed before the timed 500-step window begins. This
measures genuine self-sustained memory maintenance, not stimulus-driven integration.

**Position scaling:** kernel σ values are absolute (a fixed interaction range), held constant across
field sizes; only stimulus/kernel *positions* scale with field size so each regime is the same model
on a larger grid.

**Timing protocol:** only the step loop is timed (build, `init`, file I/O excluded). Reported value is
the **median of 10 runs**, with a **95% confidence interval on the mean** (t-interval) in
`data/benchmark_summary.csv` and drawn as the ribbon / error bars in the figures.

See [`../TRADE_OFF_CAVEATS.md`](../TRADE_OFF_CAVEATS.md) for the full set of trade-off caveats
(precision, convolution method, single-machine, etc.).

---

## Results

Measured at the fair protocol described above: matched kernel tap count, matched activation
function, two-phase memory. All eight variants, all four regimes, all three field sizes.

![Throughput](fig_benchmark_throughput.png)

![Speedup](fig_benchmark_speedup.png)

### Table 1 — Median steps/second at N=100 (10 runs)

Columns are *regime @ field size*. Higher is faster. See `data/benchmark_summary.csv` for per-cell
mean, SD, and 95% CI.

| Framework (variant) | det@100 | det@500 | det@1000 | sel@100 | sel@500 | sel@1000 | mem@100 | mem@500 | mem@1000 | mp@100 | mp@500 | mp@1000 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **dnfc** (C++, float64) | 10 629 | 2 367 | 1 240 | 9 141 | 2 208 | 1 083 | 8 695 | 1 921 | 1 028 | 10 027 | 2 351 | 1 232 |
| cosivina-python (numba) | 1 546 | 467 | 251 | 1 506 | 456 | 238 | 1 343 | 393 | 193 | 1 591 | 487 | 260 |
| Cedar (FFTW, float32) | 993 | 485 | 297 | 987 | 479 | 299 | 1 122 | 680 | 455 | 1 016 | 484 | 299 |
| Cosivina (MATLAB, FFT) | 864 | 513 | 340 | 755 | 461 | 314 | 810 | 433 | 278 | 769 | 473 | 322 |
| cosivina-python (NumPy) | 494 | 276 | 172 | 435 | 248 | 168 | 474 | 288 | 195 | 518 | 288 | 192 |
| cosivina-python (FFT) | 312 | 201 | 140 | 311 | 201 | 142 | 331 | 227 | 170 | 309 | 200 | 145 |
| Cedar (OpenCV, float32) | 564 | 204 | 114 | 555 | 202 | 113 | 201 | 73 | 41 | 676 | 250 | 140 |
| Cosivina (MATLAB) | 867 | 478 | 317 | 736 | 427 | 291 | 716 | 348 | 216 | 778 | 458 | 316 |

### Table 2 — Speedup relative to Cosivina (MATLAB), averaged across regimes at N=100

| Framework (variant) | field=100 | field=500 | field=1000 |
|---|---:|---:|---:|
| dnfc | 12.4× (12.1–12.9×) | 5.2× (5.0–5.5×) | 4.1× (3.7–4.8×) |
| cosivina-python (numba) | 1.9× (1.8–2.0×) | 1.1× (1.0–1.1×) | 0.8× (0.8–0.9×) |
| Cedar (FFTW) | 1.3× (1.1–1.6×) | 1.3× (1.0–2.0×) | 1.3× (0.9–2.1×) |
| Cosivina (MATLAB, FFT) | 1.0× (1.0–1.1×) | 1.1× (1.0–1.2×) | 1.1× (1.0–1.3×) |
| cosivina-python (NumPy) | 0.6× (0.6–0.7×) | 0.7× (0.6–0.8×) | 0.7× (0.5–0.9×) |
| cosivina-python (FFT) | 0.4× (0.4–0.5×) | 0.5× (0.4–0.7×) | 0.5× (0.4–0.8×) |
| Cedar (OpenCV) | 0.6× (0.3–0.9×) | 0.4× (0.2–0.5×) | 0.3× (0.2–0.4×) |
| Cosivina (MATLAB) | 1.0× | 1.0× | 1.0× |

---

## Key observations

- **dnfc is the fastest by a wide margin** in every regime and at all three field sizes — 12.1–12.9×
  Cosivina at field=100, 5.0–5.5× at field=500, 3.7–4.8× at field=1000.

- **Second place is field-size-dependent.** cosivina-python (numba) holds second at field=100 — its
  numba-JIT-compiled host code over direct spatial convolution (`np.convolve` / `parCircConv`, the
  same truncated kernel support dnfc uses) is fastest there — but Cedar-FFTW overtakes it at field=500
  and field=1000, where the spectral engine's flat per-step FFT cost scales better than numba's
  per-element JIT-dispatch overhead on the larger fields.

- **Cedar-FFTW vs Cedar-OpenCV** (a clean *same-precision, same-framework* comparison): FFTW wins on
  the convolution-heavy **memory** (Mexican-hat) regime at all three field sizes, and the margin
  widens with size — memory@100: 1 122 vs 201 sps (5.6×); memory@500: 680 vs 73 (9.3×); memory@1000:
  455 vs 41 (11.2×) — its fused Fourier-domain multiply avoids the second spatial convolution OpenCV
  pays for. OpenCV is closer on the narrow-kernel regimes.

- **cosivina-python (FFT)** is the slowest of the three cosivina-python paths in 1D (numba > NumPy >
  FFT: ~310 sps at field=100 vs NumPy's ~435–520 and numba's ~1340–1590). Its spectral `KernelFFT`
  pays a fixed per-step FFT overhead that dominates at these 1D field sizes, where the truncated
  spatial kernel is cheap; the gap to NumPy narrows as the field grows (field=1000: FFT ~140–170 vs
  NumPy ~168–195) and narrows further still on the wide-kernel **memory** regime at field=1000 (170
  vs 195, the closest the two paths get). It is included as the honest *float64 spectral* data
  point — the cross-platform-validation study confirms it computes the same result as the spatial
  variants, so this is a pure algorithm-cost comparison, not accuracy.

---

## Data provenance

All eight variants were measured on one machine (see *Test Machine* above); see
[`../TRADE_OFF_CAVEATS.md`](../TRADE_OFF_CAVEATS.md) §3 for what single-machine measurement does
and doesn't bound. Each `data/timings-*.csv` row is
`framework,variant,arch,field_size,mode,N,run,steps_per_second` (8 columns). Regenerate all tables
and figures with `Rscript analysis.R` and `Rscript fig_benchmark.R`.

| Data file | Variants | Rows |
|---|---|---:|
| `data/timings-dnfc.csv` | dnfc | 480 |
| `data/timings-cedar.csv` | OpenCV + FFTW | 960 |
| `data/timings-cosivina-python.csv` | numba + NumPy + FFT | 1440 |
| `data/timings-cosivina.csv` | Cosivina (MATLAB) + Cosivina (MATLAB, FFT) | 960 |
