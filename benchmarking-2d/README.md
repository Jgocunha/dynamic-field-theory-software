# DFT Framework Benchmark Report (2D, 50×50 fields)

The 2D counterpart of [`../benchmarking/`](../benchmarking/README.md). Same design and protocol,
with each neural field promoted to a **fixed 50×50 grid** (2500 cells vs 100 in 1D). This is the
regime where the lateral **convolution cost dominates**, so the framework ranking can differ from
1D — each framework's 2D convolution (OpenCV vs direct separable, JIT vs interpreted) scales
differently with the number of grid points.

## Test Machine

| Property | Value |
|---|---|
| CPU | AMD Ryzen 5 3600 (6 cores / 12 threads, 3.6 GHz base, ~4.2 GHz boost) |
| RAM | 32 GB DDR4 |
| OS | Windows 11 Pro (build 10.0.22621), 64-bit |
| Power plan | High performance |
| Compiler (Cedar / dnfc) | MSVC 19.44 (VS 2022), C++20, Release `/O2 /Ob2 /DNDEBUG`; dnfc `/arch:AVX2` |
| MATLAB version | R2023a, `maxNumCompThreads(1)` |
| Python version | 3.11; numpy 2.2.1; numba 0.65.1 |
| dnfc version | 2.4.1 (optimized build: AVX2 2D convolution + sigmoid, dead-work elision) |
| Cedar version | 6.1.0 (OpenCV engine, `cv::setNumThreads(0)`) |
| Cosivina version | 1.4.0 |
| cosivina-python version | 0.1.0 (numba JIT path for benchmarks) |

**Single-threading is enforced** the same way as the 1D study (Python thread-env pinned to 1 before
numpy import; MATLAB `maxNumCompThreads(1)`; Cedar `cv::setNumThreads(0)`; dnfc is scalar C++).
See [`../benchmarking/README.md`](../benchmarking/README.md) (*Test Machine*, *Threats to Validity*,
*Data provenance*) for the full environment, flags, and caveats — they apply identically here.

---

## Benchmark Design

Each benchmark creates **N independent neural fields** (N ∈ {10, 50, 100, 500, 1000}) on a fixed
**50×50** grid. Every field consists of four elements (identical parameters to the 1D study, only
the grid is 2D):

| Element | Parameters |
|---|---|
| GaussStimulus2D | width=5, amplitude=10, circular=true |
| NeuralField2D | 50×50, τ=25 ms, h=−5, sigmoid (x_shift=0, steepness=100) |
| GaussKernel2D (lateral) | width=3, amplitude=5, global=0, circular=true, normalized=true |
| NormalNoise2D | amplitude=0 (element present; inert) |

Stimulus centres are tiled across the 50×50 grid (row-major) so the N fields are distinct. Fields
are independent (no cross-field connections). As in 1D, in Cedar the lateral kernel is internal to
the `NeuralField` and noise is a field parameter (`input noise gain = 0`), so each Cedar field is a
2D `GaussInput` feeding a 2D `NeuralField` with the same lateral Gauss kernel; the computed DFT
dynamics are identical.

**Timing protocol** (same as 1D):
- 200 warm-up steps (discarded)
- **10 timed runs** of 5 000 steps each
- Metric: steps per second (only the step loop is timed)
- Reported value: **median of 10 runs**, with a 95% CI on the mean in `data/benchmark_summary.csv`
  and drawn as the figure ribbon / error bars

**Precision:** Cedar uses float32; Cosivina, cosivina-python, and dnfc use float64 — throughput is
per step, not per FLOP (see *Threats to validity* in the 1D README).

## How to reproduce

1. **Generate** the N-field setups (already committed): `simulations/{cosivina,cosivina-python}/benchmark_N{N}.{m,py}`.
2. **Run each framework** (each appends to `data/timings-<framework>-2d.csv`):
   - dnfc: build `runners/dnfc_benchmark/benchmark_headless_2d.cpp` inside the dnf-composer tree
     (`add_example_executable(benchmark_headless_2d ...)`), run with `<output_csv>`.
   - Cedar: build `runners/cedar_benchmark/benchmark_2d.cpp` inside the Cedar tree
     (`cedar/executables/benchmark-2d/`, `cedar_add_executable(benchmark_2d)`); run with the
     dependency DLLs on PATH (see `../.claude/cedar-notes.md`).
   - cosivina (MATLAB): `run('runners/cosivina_benchmark_2d.m')`.
   - cosivina-python: `python runners/cosivina_python_benchmark_2d.py`.
3. **Aggregate & plot**: `Rscript analysis_2d.R` → `data/benchmark_summary.csv`;
   `Rscript fig_benchmark_2d.R` → `fig_benchmark_throughput.png`, `fig_benchmark_speedup.png`.

---

## Results

> ⚠️ **Numbers below are from the previous 3-run protocol.** The runners/scripts/figures are upgraded
> to the 10-run + 95%-CI protocol; tables/figures will be refreshed after the next single-session
> re-measure of all frameworks. Treat current values as provisional.

Collected over dnfc, Cedar, and cosivina-python (numba). **Cosivina (MATLAB) 2D is pending a MATLAB
run** via `runners/cosivina_benchmark_2d.m`; the speedup figure (relative to Cosivina) and the
Cosivina row will be added once it is run.

![Throughput](fig_benchmark_throughput.png)

> **Note:** dnfc figures are from the optimized build (AVX2-vectorized 2D convolution + sigmoid,
> dead-work elision). Cedar and cosivina-python are unchanged. dnfc was measured at N=10/50/100/500
> (N=1000 not run this round).

### Table 1 — Steps per second (median of 10 runs), 50×50

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| dnfc | 2 671 | 436 | 194 | 40 | — † |
| Cedar | 1 545 | 297 | 144 | 27 | 14 |
| cosivina-python (numba) | 317 | 54 | 29 | 6 | 3 |
| Cosivina (MATLAB) | *pending* | *pending* | *pending* | *pending* | *pending* |

† dnfc N=1000 not measured this round (sweep capped at N=500).

### Table 2 — Detailed: median [min–max] steps/second

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---|---|---|---|---|
| dnfc | 2671 [2636–2675] | 436 [421–440] | 194 [193–198] | 40 [40–41] | — |
| Cedar | 1545 [1533–1545] | 297 [296–302] | 144 [143–146] | 27 [27–27] | 14 [14–14] |
| cosivina-python | 317 [305–318] | 54 [49–59] | 29 [27–29] | 6 [6–7] | 3 [3–3] |

### The headline 2D result — dnfc is fastest in 2D after the convolution optimization

Earlier (pre-optimization) builds had dnfc as the **slowest** framework in 2D — its hand-rolled
scalar separable convolution did not scale to 2500-cell fields, and both Cedar (OpenCV `filter2D`)
and numba cosivina-python overtook it. The AVX2-vectorized 2D convolution (plus sigmoid
vectorization and dead-work elision) **reverses that**: dnfc 2D throughput rose ~8–10× (e.g. N=10:
253 → 2 671 sps; N=500: 3 → 40 sps) and dnfc is now the fastest framework at every measured N.

| N | dnfc / Cedar | dnfc / cosivina-python |
|---|---:|---:|
| 10 | 1.73× faster | 8.4× faster |
| 50 | 1.47× faster | 8.1× faster |
| 100 | 1.35× faster | 6.7× faster |
| 500 | 1.49× faster | 6.7× faster |

**Why:** at 50×50 the field has 2500 cells (vs 100 in 1D), so the **lateral convolution dominates
every step**. Cedar routes its 2D convolution through OpenCV's SIMD-tuned `filter2D`; once dnfc's
separable convolution is itself AVX2-vectorized, dnfc's lean per-step loop (no framework locking,
no typed-slot overhead, fused Euler update) reclaims the lead. dnfc's lead over Cedar is smaller
in 2D (~1.4–1.7×) than in 1D (~17–22×) because the convolution — where both now use SIMD — is a
larger share of the 2D step. The optimization that produced this is described in
[`../.claude/plans/dnfc-2d-convolution-optimization.md`](../.claude/plans/dnfc-2d-convolution-optimization.md)
(implemented).

### Scaling efficiency (steps/s relative to N=10 baseline; 1.0 = perfectly linear)

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| dnfc | 1.000 | 0.816 | 0.725 | 0.753 | — |
| cedar | 1.000 | 0.960 | 0.933 | 0.879 | 0.882 |
| cosivina-python | 1.000 | 0.845 | 0.899 | 0.970 | 0.999 |
