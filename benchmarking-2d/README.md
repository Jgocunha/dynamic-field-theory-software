# DFT Framework Benchmark Report (2D)

The 2D counterpart of [`../benchmarking/`](../benchmarking/README.md). Same design and protocol,
with each neural field promoted to a **100×100, 200×200, or 500×500 grid** (10 000/40 000/250 000
cells vs 100/500/1000 in 1D). This is the regime where the lateral **convolution cost dominates**, so the framework ranking
can differ from 1D — each framework's 2D convolution (OpenCV/FFTW vs direct separable, JIT vs
interpreted) scales differently with the number of grid points.

## Test Machine

| Property | Value |
|---|---|
| CPU | 13th Gen Intel Core i9-13900 (24 cores / 32 threads, up to 5.6 GHz boost) |
| RAM | 32 GB |
| OS | Windows 11 Pro (build 10.0.26200), 64-bit |
| Power plan | High performance |
| Compiler (Cedar / dnfc) | MSVC 19.44 (Visual Studio 2022 Community), C++20 |
| Release flags | `/O2 /Ob2 /DNDEBUG` (CMake Release) |
| MATLAB version | R2024b, `maxNumCompThreads(1)` |
| Python version | 3.11.9; numpy 2.2.1; numba 0.66.0 |
| dnfc version | 2.9.3 |
| Cedar version | 6.2.0 — **both** convolution engines benchmarked: OpenCV (spatial) and FFTW (spectral); `cv::setNumThreads(0)` |
| Cosivina version | 1.4.0 |
| cosivina-python version | 0.1.0 (numba JIT, pure-NumPy, and spectral `KernelFFT` paths all benchmarked) |

**Single-threading is enforced** the same way as the 1D study (Python thread-env pinned to 1 before
numpy import; MATLAB `maxNumCompThreads(1)`; Cedar `cv::setNumThreads(0)`; dnfc is scalar C++).
See [`../benchmarking/README.md`](../benchmarking/README.md) (*Test Machine*, *Data provenance*) and
[`../TRADE_OFF_CAVEATS.md`](../TRADE_OFF_CAVEATS.md) for the full environment, flags, and caveats —
they apply identically here.

---

## Benchmark Design

Each run creates **N independent neural fields** (N ∈ {5, 10, 50, 100}), tiled copies of one
**canonical DFT regime**, and times the integration loop — the same design as 1D, with each field
promoted to a 2D grid. The matrix is fully crossed:

**8 variants × 4 regimes × 3 grid sizes × 4 N × 10 runs.**

| Axis | Values |
|---|---|
| Framework variants | dnfc · Cedar (OpenCV) · Cedar (FFTW) · Cosivina (MATLAB) · Cosivina (MATLAB, FFT) · cosivina-python (numba) · cosivina-python (NumPy) · cosivina-python (FFT) |
| Canonical regimes | detection · selection · memory · multi-peak |
| Grid size (2D) | 100×100, 200×200, 500×500 |
| N (independent fields) | 5, 10, 50, 100 |
| Runs per cell | 10 (warm-up: 200 steps, discarded; timed: 500 steps) |

**Canonical regimes** are the 2D-adjusted counterparts of the 1D regimes (positions scale with grid
side, kernel σ values scale with the 2D amplitude adjustments used in cross-platform-validation):

| Regime | h | Lateral kernel | Stimuli |
|---|---|---|---|
| detection | −8 | Gauss (σ=3, a=8) | 1 |
| selection | −10 | Gauss (σ=3, a=20) + global inhibition −0.15 | 2 |
| memory | −5 | Mexican-hat (σ_exc=3.4 a=44.25, σ_inh=8.9 a=33.75, global −0.05) | 1 |
| multi-peak | −8 | Gauss (σ=2, a=5) | 2 |

**Noise is on:** every field includes a `NormalNoise2D` term with **amplitude A = 0.1**.

**Kernel cutoff, activation function, and the memory protocol are unified across frameworks the
same way as 1D** (see [`../benchmarking/README.md`](../benchmarking/README.md) *Benchmark Design*
for the full explanation of each): Cedar's `limit` is computed per σ/grid (`fairCedarLimit`) to
match dnfc's/cosivina's real tap count exactly (a flat `limit=5` would give Cedar roughly half the
real convolution work); Cedar uses `cedar.aux.math.ExpSigmoid` for *selection*, algebraically
identical to the other frameworks' logistic sigmoid; *memory* uses a two-phase protocol (100 steps
stimulus-on to establish the bump, then removed before the timed window) in every framework.

**Timing protocol:** only the step loop is timed (build, `init`, file I/O excluded). Reported value
is the **median of 10 runs**, with a **95% confidence interval on the mean** (t-interval) in
`data/benchmark_summary.csv` and drawn as the ribbon / error bars in the figures.

## How to reproduce

1. **Run each framework** (each appends to `data/timings-<framework>-2d.csv`):
   - dnfc: `runners/dnfc_benchmark/benchmark_headless_2d.cpp`, built inside the dnf-composer tree;
     run as `benchmark_headless_2d.exe <output_csv> <arch> <N_csv> <grid>`.
   - Cedar: `runners/cedar_benchmark/benchmark_2d.cpp`, built inside the Cedar tree
     (`cedar/executables/benchmark-2d/`); run as
     `benchmark_2d.exe <output_csv> <arch> <opencv|fftw> <N_csv> <grid>` with the dependency DLLs
     on PATH (see `../.claude/reports/cedar-notes.md`).
   - cosivina (MATLAB): `run('runners/cosivina_benchmark_2d.m')` (edit `ARCH_LIST`/`GRID_SIZES` to
     scope a re-run; defaults to the full 4-regime × 3-grid matrix).
   - cosivina-python: `python runners/cosivina_python_benchmark_2d.py <arch> <numba|nonumba|fft> <N_csv> <grid>`.
   - `run_2d_benchmark.ps1` drives the full matrix for dnfc/Cedar/cosivina-python in one call (must
     run from PowerShell — the Cedar exes silent-exit under Git Bash).
2. **Aggregate & plot**: `Rscript analysis_2d.R` → `data/benchmark_summary.csv`;
   `Rscript fig_benchmark_2d.R` → `fig_benchmark_throughput.png`, `fig_benchmark_speedup.png`.

---

## Results

Measured at the protocol described above: matched kernel tap count, matched activation
function, two-phase memory. All eight variants, all four regimes, all three grid sizes.

![Throughput](fig_benchmark_throughput.png)

![Speedup](fig_benchmark_speedup.png)

### Table 1 — Median steps/second at N=100 (10 runs)

Columns are *regime @ grid*. Higher is faster. See `data/benchmark_summary.csv` for per-cell mean,
SD, and 95% CI.

| Framework (variant) | det@100 | det@200 | det@500 | sel@100 | sel@200 | sel@500 | mem@100 | mem@200 | mem@500 | mp@100 | mp@200 | mp@500 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **dnfc** (C++, float64) | 77.7 | 19.0 | 2.99 | 72.4 | 17.8 | 2.75 | 60.4 | 14.0 | 2.04 | 73.7 | 19.0 | 2.97 |
| Cosivina (MATLAB, FFT) | 43.4 | 11.5 | 1.04 | 42.6 | 11.3 | 1.00 | 44.2 | 11.6 | 1.06 | 41.6 | 11.2 | 0.99 |
| Cedar (OpenCV, float32) | 39.7 | 11.0 | 1.66 | 40.7 | 11.1 | 1.67 | 16.3 | 6.2 | 1.08 | 41.7 | 11.7 | 1.76 |
| Cosivina (MATLAB) | 37.8 | 11.7 | 1.15 | 33.4 | 9.1 | 0.83 | 17.2 | 5.2 | 0.61 | 38.6 | 12.6 | 1.17 |
| Cedar (FFTW, float32) | 35.8 | 8.9 | 1.10 | 34.9 | 9.1 | 1.11 | 35.6 | 9.0 | 1.12 | 35.6 | 9.2 | 1.09 |
| cosivina-python (FFT) | 24.4 | 6.6 | 1.01 | 24.2 | 6.6 | 1.03 | 25.2 | 6.7 | 1.05 | 24.5 | 6.7 | 1.03 |
| cosivina-python (numba) | 19.9 | 5.2 | 0.83 | 18.7 | 4.8 | 0.74 | 9.9 | 2.5 | 0.41 | 20.3 | 5.5 | 0.90 |
| cosivina-python (NumPy) | 5.1 | 2.0 | 0.47 | 3.3 | 1.4 | 0.37 | 2.8 | 1.2 | 0.30 | 5.2 | 2.1 | 0.52 |

### Table 2 — Speedup relative to Cosivina (MATLAB), averaged across regimes at N=100

| Framework (variant) | grid=100 | grid=200 | grid=500 |
|---|---:|---:|---:|
| dnfc | 2.41× (1.91–3.51×) | 1.94× (1.50–2.71×) | 2.95× (2.54–3.34×) |
| Cosivina (MATLAB, FFT) | 1.52× (1.08–2.56×) | 1.34× (0.89–2.25×) | 1.17× (0.85–1.74×) |
| Cedar (FFTW) | 1.24× (0.92–2.07×) | 1.06× (0.73–1.75×) | 1.26× (0.93–1.83×) |
| Cedar (OpenCV) | 1.07× (0.95–1.22×) | 1.07× (0.92–1.21×) | 1.68× (1.44–2.01×) |
| Cosivina (MATLAB) | 1.0× | 1.0× | 1.0× |
| cosivina-python (FFT) | 0.87× (0.63–1.46×) | 0.78× (0.53–1.30×) | 1.18× (0.88–1.72×) |
| cosivina-python (numba) | 0.55× (0.53–0.57×) | 0.47× (0.44–0.53×) | 0.76× (0.67–0.89×) |
| cosivina-python (NumPy) | 0.13× (0.10–0.16×) | 0.18× (0.15–0.22×) | 0.45× (0.41–0.49×) |

## Key observations

- **dnfc wins every regime at all three grids**, but by a much narrower margin than 1D (1.5–3.5× vs
  12.1–12.9× at 1D field=100) — in 2D the lateral convolution dominates the step, and Cedar/Cosivina's
  convolution paths (OpenCV `filter2D`, FFTW spectral, MATLAB's separable spatial `conv2`) are
  competitive with dnfc's cache-blocked separable convolution in a way that 1D's cheaper convolution
  never exposed.

- **Cosivina (MATLAB) is competitive with, and sometimes beats, both Cedar engines** — e.g.
  `multi-peak@200`: Cosivina 12.6 sps vs Cedar-OpenCV 11.7 vs Cedar-FFTW 9.2. This was surprising
  enough to investigate directly: it is not an artifact of the N=100 replication (the N=5→N=100
  scaling ratio is ~20–26× for every framework, matching the ideal linear-in-N ratio, so it isn't a
  per-instance-overhead effect), and it isn't a bug. Cedar is a general robotics/cognitive-
  architecture framework — every field-step pays a structural tax (Qt read/write locks,
  `Step::onTrigger` dispatch, `cv::copyMakeBorder` allocation for cyclic OpenCV convolution, a
  non-fused multi-pass Euler update) that MATLAB's comparatively lean cosivina loop does not, so a
  "slow, interpreted" MATLAB toolbox can beat a compiled C++ framework once that framework is
  spending most of its time on generality rather than the convolution itself. The pattern is grid-size
  dependent: Cosivina beats Cedar-OpenCV in the memory regime at grid=100 and in detection/multi-peak
  at grid=200, but loses to it in every regime at grid=500 — Cedar-FFTW is the one Cosivina keeps
  beating in detection/multi-peak at all three grids, including grid=500 (1.15 vs 1.10, 1.17 vs 1.09).

- **Cedar-FFTW wins the `memory` regime specifically, over Cedar-OpenCV, at all three grids** — its
  fused Mexican-hat Fourier multiply (one FFT pair instead of two spatial convolutions) is the one
  place FFTW's structural advantage shows through Cedar's overhead. The margin is clear at grid=100
  (35.6 vs 16.3 sps) and grid=200 (9.0 vs 6.2), but narrows to near parity at grid=500 (1.12 vs 1.08)
  as Cedar's per-step structural tax comes to dominate both engines equally at that grid size.

- **cosivina-python (FFT) is the fastest of the three cosivina-python variants at every 2D grid
  size** — the reverse of 1D, where it was the slowest. At grid=100 it runs ≈24–25 sps vs numba's
  10–20 and NumPy's 3–5; at grid=200, ≈6.6–6.7 vs 2.5–5.5 and 1.2–2.1; at grid=500, ≈1.0–1.05 vs
  0.41–0.90 and 0.30–0.52. This is the spatial-vs-spectral crossover made visible *within a single
  framework*: FFT convolution costs O(G²·log G) **independent of kernel width**, while the spatial
  variants cost O(G²·taps). Two consequences show in the data: (1) FFT overtakes the spatial variants
  once the field is 2D (the O(taps) term grows with the 2D kernel), and (2) FFT is **flat across
  regimes** (24.2–25.2 at grid=100) while numba drops to 9.9 on the wide-kernel **memory** regime —
  the spatial variants pay for the Mexican-hat's ~91-tap kernel, FFT does not. The
  cross-platform-validation study confirms the FFT and spatial paths compute the same result, so this
  is a pure algorithm-cost comparison. (It is still below dnfc, and roughly on par with or ahead of
  Cosivina MATLAB depending on grid size.)

---

## Data provenance

All eight variants were measured on one machine (see *Test Machine* above); see
[`../TRADE_OFF_CAVEATS.md`](../TRADE_OFF_CAVEATS.md) §3 for what single-machine measurement does
and doesn't bound. Each `data/timings-*-2d.csv` row is
`framework,variant,arch,field_size,mode,N,run,steps_per_second` (8 columns; `field_size` is the
grid side length). Regenerate all tables and figures with `Rscript analysis_2d.R` and
`Rscript fig_benchmark_2d.R`. All eight variants (including cosivina-python-FFT and the MATLAB
cosivina-FFT variant) were measured in one continuous, unified rerun (2026-07-28 to 2026-08-02);
the earlier caveat about cosivina-python-FFT being measured in a separate session no longer applies.

| Data file | Variants | Rows |
|---|---|---:|
| `data/timings-dnfc-2d.csv` | dnfc | 480 |
| `data/timings-cedar-2d.csv` | OpenCV + FFTW | 960 |
| `data/timings-cosivina-python-2d.csv` | numba + NumPy + FFT | 1440 |
| `data/timings-cosivina-2d.csv` | Cosivina (MATLAB) + Cosivina (MATLAB, FFT) | 960 |
