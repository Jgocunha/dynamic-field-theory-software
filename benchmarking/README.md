# DFT Framework Benchmark Report (1D)

Throughput (steps/second) of **N independent 1D neural fields** across six framework
variants, swept over four canonical DFT regimes and two field sizes. The 2D
counterpart lives in [`../benchmarking-2d/`](../benchmarking-2d/).

## Test Machine

| Property | Value |
|---|---|
| CPU | AMD Ryzen 5 3600 (6 cores / 12 threads, 3.6 GHz base, ~4.2 GHz boost) |
| RAM | 32 GB DDR4 |
| OS | Windows 11 Pro (build 10.0.22621), 64-bit |
| Power plan | High performance (no CPU down-throttling during runs) |
| Compiler (Cedar / dnfc) | MSVC 19.44 (Visual Studio 2022 Community), C++20 |
| Release flags | `/O2 /Ob2 /DNDEBUG` (CMake Release); dnfc additionally built with `/arch:AVX2` |
| MATLAB version | R2023a, `maxNumCompThreads(1)` |
| Python version | 3.11; numpy 2.2.1; numba 0.65.1 |
| dnfc version | 2.4.1 (optimized build: AVX2 convolution + sigmoid, dead-work elision) |
| Cedar version | 6.1.0 — **both** convolution engines benchmarked: OpenCV (spatial) and FFTW (spectral); `cv::setNumThreads(0)` |
| Cosivina version | 1.4.0 (MATLAB) |
| cosivina-python version | 0.1.0 (numba JIT and pure-NumPy paths both benchmarked) |

**Single-threading is enforced, not assumed.** Each runner pins its math-library thread pools to 1
before timing: Python sets `OMP_NUM_THREADS=OPENBLAS_NUM_THREADS=MKL_NUM_THREADS=NUMBA_NUM_THREADS=1`
(before numpy import); MATLAB calls `maxNumCompThreads(1)`; the Cedar runner calls
`cv::setNumThreads(0)` to disable OpenCV's internal threading; dnfc's loop is plain scalar C++ with no
thread pool. No CPU-affinity pinning was applied (single-threaded workloads do not require it).

---

## Benchmark Design

Each run creates **N independent neural fields** (N ∈ {5, 10, 50, 100}), tiled copies of one
**canonical DFT regime**, and times the integration loop. The matrix is fully crossed:

**6 variants × 4 regimes × 2 field sizes × 4 N × 5 runs.**

| Axis | Values |
|---|---|
| Framework variants | dnfc · Cedar (OpenCV) · Cedar (FFTW) · Cosivina (MATLAB) · cosivina-python (numba) · cosivina-python (NumPy) |
| Canonical regimes | detection · selection · memory · multi-peak |
| Field size (1D) | 100, 500 cells |
| N (independent fields) | 5, 10, 50, 100 |
| Runs per cell | 5 (warm-up: 200 steps, discarded; timed: 2 000 steps) |

**Canonical regimes** reuse the representative parameters of the cross-platform-validation suite:

| Regime | h | Lateral kernel | Stimuli |
|---|---|---|---|
| detection | −8 | Gauss (σ=3, a=8) | 1 |
| selection | −10 | Gauss (σ=3, a=5) + global inhibition −0.15 | 2 |
| memory | −5 | Mexican-hat (σ_exc=3.4 a=17.7, σ_inh=8.9 a=13.5) | 1 |
| multi-peak | −8 | Gauss (σ=2, a=5) | 2 |

**Noise is on:** every field includes a `NormalNoise` term with **amplitude A = 0.1**, so per-step
RNG cost is part of the measured workload.

**Kernel cutoff is unified across all six frameworks at the common library default of ±5σ**
(dnfc `cutOfFactor=5`, cosivina/-python `cutoffFactor=5.`, Cedar kernel `limit=5`), so every variant
convolves the same kernel support — no framework is favoured or handicapped by kernel truncation.

**Position scaling:** kernel σ values are absolute (a fixed interaction range), held constant across
field sizes; only stimulus/kernel *positions* scale with field size so each regime is the same model
on a larger grid.

**Timing protocol:** only the step loop is timed (build, `init`, file I/O excluded). Reported value is
the **median of 5 runs**, with a **95% confidence interval on the mean** (t-interval) in
`data/benchmark_summary.csv` and drawn as the ribbon / error bars in the figures.

See [`../TRADE_OFF_CAVEATS.md`](../TRADE_OFF_CAVEATS.md) for the full set of trade-off caveats
(precision, convolution method, single-machine, etc.).

---

## Results

> ⚠️ **Numbers and figures below are pending re-measurement.** They were produced under the earlier
> 5000-step / 10-run protocol on a previous machine. All suites are being re-run at **2000 steps /
> 5 runs on a single faster machine** (1D + 2D together, for cross-suite comparability); the tables
> and figures will be refreshed from that data. Treat the current values as provisional.

![Throughput](fig_benchmark_throughput.png)

![Speedup](fig_benchmark_speedup.png)

### Table 1 — Median steps/second at N=100 (10 runs)

Columns are *regime @ field size*. Higher is faster. Run-to-run variability is low (SD ≤ 4 % of
median for every cell); see `data/benchmark_summary.csv` for per-cell mean, SD, and 95 % CI.

| Framework (variant) | det@100 | det@500 | sel@100 | sel@500 | mem@100 | mem@500 | mp@100 | mp@500 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **dnfc** (C++, float64) | 4 688 | 1 154 | 4 607 | 961 | 3 575 | 838 | 4 795 | 1 040 |
| cosivina-python (numba) | 628 | 157 | 617 | 156 | 574 | 169 | 664 | 166 |
| Cedar (FFTW, float32) | 532 | 383 | 524 | 365 | 537 | 377 | 527 | 369 |
| Cedar (OpenCV, float32) | 389 | 179 | 392 | 174 | 184 | 66 | 420 | 195 |
| Cosivina (MATLAB) | 251 | 171 | 214 | 149 | 225 | 136 | 218 | 156 |
| cosivina-python (NumPy) | 182 | 102 | 157 | 92 | 164 | 118 | 187 | 105 |

### Table 2 — Speedup relative to Cosivina (MATLAB), at N=100

Averaged across regimes (each framework / Cosivina, per cell, then averaged).

| Framework (variant) | field=100 | field=500 |
|---|---:|---:|
| dnfc | ~16–22× | ~6.2–6.8× |
| cosivina-python (numba) | ~2.5–3.0× | ~0.9–1.2× |
| Cedar (FFTW) | ~2.1–2.5× | ~2.2–2.8× |
| Cedar (OpenCV) | ~0.8–1.9× | ~0.5–1.3× |
| Cosivina (MATLAB) | 1.0× | 1.0× |
| cosivina-python (NumPy) | ~0.7–0.9× | ~0.6–0.9× |

---

## Key observations

- **dnfc is the fastest by a wide margin** in every regime and at both field sizes — roughly **7–8×**
  the next-fastest framework (~16–22× Cosivina at field=100). The lead is structural: compiled native
  C++ with a vectorized Euler loop and direct spatial convolution.

- **Second place flips with field size.** On the small field (100), **cosivina-python (numba)** is
  second (628 sps detection), its FFT-based convolution and JIT host code amortizing well on a small
  working set. On the large field (500), numba collapses (157 sps) and **Cedar (FFTW)** takes second
  (383 sps) — spectral convolution cost grows only as *field·log field*, so it degrades far more
  gently than the others as the field grows.

- **Cedar-FFTW vs Cedar-OpenCV** (a clean *same-precision, same-framework* comparison): FFTW wins on
  the convolution-heavy **memory** (Mexican-hat) regime and on the large field (memory@500: 377 vs
  66 sps), while OpenCV (spatial) is competitive on the light, narrow-kernel regimes at the small
  field. This is the spatial-vs-spectral cross-over made explicit.

- **The kernel-cutoff unification matters.** With all frameworks now convolving the same ±5σ support,
  Cedar-OpenCV's memory throughput is markedly lower than under the previous asymmetric setting — the
  comparison is now apples-to-apples on kernel work.

- **Field-size effect is consistent:** every framework slows from field=100 to field=500, most
  steeply for the wide-kernel **memory** regime (e.g. Cedar-OpenCV memory 184 → 66 sps).

> **Precision caveat:** Cedar runs **float32**, all others **float64**. Throughput is per step, not
> per FLOP; Cedar's float32 SIMD-width advantage flatters its raw step rate. Cedar-vs-others
> comparisons should be read with this in mind (full discussion in `THREATS_TO_VALIDITY.md`).

---

## Data provenance

All six variants were measured in a single back-to-back session on an otherwise-idle machine, so the
cross-framework ratios are internally consistent. Each `data/timings-*.csv` row is
`framework,variant,arch,field_size,mode,N,run,steps_per_second` (8 columns). Regenerate all tables
and figures with `Rscript analysis.R` and `Rscript fig_benchmark.R`.

| Data file | Variants | Rows |
|---|---|---:|
| `data/timings-dnfc.csv` | dnfc | 320 |
| `data/timings-cedar.csv` | OpenCV + FFTW | 640 |
| `data/timings-cosivina-python.csv` | numba + NumPy | 640 |
| `data/timings-cosivina.csv` | Cosivina (MATLAB) | 320 |
