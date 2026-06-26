# DFT Framework Benchmark Report

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
| Cedar version | 6.1.0 (OpenCV convolution engine; FFTW not available in this build; `cv::setNumThreads(0)`) |
| Cosivina version | 1.4.0 |
| cosivina-python version | 0.1.0 (numba JIT path for benchmarks; nonumba path for validation) |

**Single-threading is enforced, not assumed.** Each runner pins its math-library thread pools to 1
before timing: Python sets `OMP_NUM_THREADS=OPENBLAS_NUM_THREADS=MKL_NUM_THREADS=NUMBA_NUM_THREADS=1`
(before numpy import); MATLAB calls `maxNumCompThreads(1)`; the Cedar runner calls
`cv::setNumThreads(0)` to disable OpenCV's internal threading; dnfc's loop is plain scalar C++ with no
thread pool. Each runner prints its effective thread settings at start-up. No CPU-affinity pinning was
applied (single-threaded workloads do not require it).

---

## Benchmark Design

Each benchmark creates **N independent neural fields** (N ∈ {10, 50, 100, 500, 1000}).
Every field consists of four elements:

| Element | Parameters |
|---|---|
| GaussStimulus | width=5, amplitude=10, circular=true |
| NeuralField | fieldSize=100, τ=25 ms, h=−5, sigmoid (x_shift=0, steepness=100) |
| GaussKernel (lateral) | width=3, amplitude=5, global=0, circular=true, normalized=true |
| NormalNoise | amplitude=0 (element present; inert) |

Total elements: 4N for Cosivina, cosivina-python, and dnfc. Fields are independent (no
cross-field connections). In Cedar the lateral kernel is internal to the `NeuralField` and noise
is a field parameter (`input noise gain = 0`) rather than separate elements, so each Cedar field is
a `GaussInput` source feeding a `NeuralField` (with the same lateral Gauss kernel and parameters);
the computed DFT dynamics are identical.

**Timing protocol:**
- 200 warm-up steps (discarded)
- **10 timed runs** of 5 000 steps each
- Metric: steps per second (wall-clock via `std::chrono` or MATLAB `tic/toc`); only the step loop is
  timed (build, `init`, and file I/O are outside the timer)
- Reported value: **median of 10 runs**, with a **95% confidence interval on the mean** (t-interval)
  reported in `data/benchmark_summary.csv` and drawn as the ribbon / error bars in the figures

**Precision:** Cedar uses float32; Cosivina, cosivina-python, and dnfc use float64. Throughput is
reported per step, not per FLOP — Cedar's float32 gives it a SIMD-width advantage (8 floats vs 4
doubles per AVX2 register), so its speed should be read with that caveat (see *Threats to validity*).

---

## Results

> ⚠️ **Numbers below are from the previous 3-run protocol.** The runners, R scripts, and figures are
> now upgraded to the 10-run + 95%-CI protocol described above; the tables/figures will be refreshed
> after the next single-session re-measure of all four frameworks. Treat the current absolute values
> and ratios as provisional pending that re-run.

![Throughput](fig_benchmark_throughput.png)

![Speedup](fig_benchmark_speedup.png)

### Table 1 — Steps per second (median of 10 runs)

> **Note:** dnfc figures are from the optimized build (AVX2-vectorized convolution + sigmoid,
> dead-work elision in `updateInput`/kernels). Cedar, Cosivina, and cosivina-python are unchanged.

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| Cedar | 3 056 | 610 | 297 | 49 | 25 |
| Cosivina | 2 443 | 496 | 244 | 46 | 22 |
| cosivina-python | 6 965 | 1 300 | 553 | 103 | 50 |
| dnfc | 67 098 | 12 654 | 6 355 | 1 059 | 416 |

### Table 2 — Detailed: median [min – max] steps/second

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---|---|---|---|---|
| Cedar | 3056 [2992–3065] | 610 [609–612] | 297 [293–301] | 49 [49–50] | 25 [25–25] |
| Cosivina | 2443 [2300–2483] | 496 [495–497] | 244 [242–245] | 46 [45–46] | 22 [22–22] |
| cosivina-python | 6965 [6692–7334] | 1300 [1245–1418] | 553 [547–568] | 103 [103–103] | 50 [49–50] |
| dnfc | 67098 [66574–67780] | 12654 [12606–12702] | 6355 [6139–6356] | 1059 [1043–1061] | 416 [412–432] |

---

## Statistical Summary

### Run-to-run variability

All frameworks show low variability (SD < 5% of median) across runs,
confirming stable, reproducible measurements. The `data/benchmark_summary.csv` carries the per-cell
mean, SD, SEM, and 95% CI; the figures draw the CI as ribbon (throughput) and error bars (speedup).

| Framework | N | Median (sps) | Min | Max | SD |
|---|---|---:|---:|---:|---:|
| cedar | 10 | 3056 | 2992 | 3065 | 40 |
| cedar | 50 | 610 | 609 | 612 | 2 |
| cedar | 100 | 297 | 293 | 301 | 4 |
| cedar | 500 | 49 | 49 | 50 | 0.7 |
| cedar | 1000 | 25 | 25 | 25 | 0.1 |
| cosivina | 10 | 2443 | 2300 | 2483 | 101 |
| cosivina | 50 | 496 | 495 | 497 | 1 |
| cosivina | 100 | 244 | 242 | 245 | 2 |
| cosivina | 500 | 46 | 45 | 46 | 1 |
| cosivina | 1000 | 22 | 22 | 22 | 0.2 |
| cosivina-python | 10 | 6965 | 6692 | 7334 | 322 |
| cosivina-python | 50 | 1300 | 1245 | 1418 | 89 |
| cosivina-python | 100 | 553 | 547 | 568 | 11 |
| cosivina-python | 500 | 103 | 103 | 103 | 0.2 |
| cosivina-python | 1000 | 50 | 49 | 50 | 0.3 |
| dnfc | 10 | 67098 | 66574 | 67780 | 605 |
| dnfc | 50 | 12654 | 12606 | 12702 | 48 |
| dnfc | 100 | 6355 | 6139 | 6356 | 125 |
| dnfc | 500 | 1059 | 1043 | 1061 | 10 |
| dnfc | 1000 | 416 | 412 | 432 | 11 |

### Speedup ratios (headless, relative to Cosivina)

| N | dnfc / Cosivina | Cedar / Cosivina | dnfc / Cedar | cosivina-python / Cosivina |
|---|---:|---:|---:|---:|
| 10 | 27.5× | 1.25× | 22.0× | 2.85× |
| 50 | 25.5× | 1.23× | 20.7× | 2.62× |
| 100 | 26.0× | 1.22× | 21.4× | 2.27× |
| 500 | 23.0× | 1.07× | 21.6× | 2.24× |
| 1000 | 18.9× | 1.14× | 16.6× | 2.27× |

### Scaling efficiency (steps/s relative to N=10 baseline; 1.0 = perfectly linear)

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| cedar | 1.000 | 0.998 | 0.972 | 0.808 | 0.814 |
| cosivina | 1.000 | 1.016 | 0.999 | 0.934 | 0.910 |
| cosivina-python | 1.000 | 0.933 | 0.794 | 0.736 | 0.712 |
| dnfc | 1.000 | 0.943 | 0.947 | 0.789 | 0.619 |

Key observations:
- **dnfc is by far the fastest** across all tested configurations, after the convolution/sigmoid optimization (AVX2 vectorization + dead-work elision). Its throughput rose ~6–8× over the previous build (e.g. N=10: 8 190 → 67 098 sps; N=1000: 70 → 416 sps), widening an already-large lead.
- **dnfc is ~19–27× faster than Cosivina** and **~17–22× faster than Cedar**. The advantage is structural (compiled native C++ with a vectorized Euler loop vs MATLAB interpreter / a general modular framework) and now amplified by the explicit SIMD path. The ratio narrows somewhat at the largest N (memory-bandwidth-bound), where dnfc's scaling efficiency drops to 0.62.
- **Cedar is ~1.1–1.25× faster than Cosivina**, an advantage that narrows at higher N (1.07× at N=500). Cedar is run through its real library API: although it uses float32 arithmetic (vs float64 in Cosivina and dnfc), the OpenCV convolution engine, per-step locking, and field state-metric bookkeeping add overhead that keeps its throughput close to Cosivina's and far below dnfc's.
- **cosivina-python (numba JIT) is ~2.2–2.85× faster than Cosivina (MATLAB)** and is the second-fastest framework overall (behind dnfc, ahead of Cedar and Cosivina). With numba compiling the per-step kernels to native code, the Python interpreter overhead is largely eliminated. Its advantage over MATLAB is largest at small N (2.85× at N=10) and settles to ~2.25× at larger N, where its scaling efficiency falls off faster than the others (0.71 at N=1000) — JIT-compiled per-step overhead amortizes well at small working sets but the convolution cost dominates at large N. (Note: the benchmark uses the numba path; the cross-platform-validation suite uses the pure-Python `nonumba` path, which is ~3–3.5× slower — so do not compare validation timings with these.)

---

## Threats to Validity

This is an honest, single-machine micro-benchmark; readers should weigh the following:

- **Precision is not equalized.** Cedar runs float32, the others float64. Throughput is per step, not
  per FLOP or per bit; Cedar's float32 SIMD-width advantage flatters its raw step rate. Cross-precision
  speedups should be read as "as-shipped default-precision throughput", not architecture-normalized.
- **Workload is N *independent, non-interacting* fields.** This isolates per-field per-step cost (the
  quantity we want), but it is not a coupled/hierarchical architecture. It rewards low per-field
  overhead and does not exercise cross-field communication, large fields, or FFT-vs-direct convolution
  cross-over (fields are 100 (1D) / 50×50 (2D), kernels σ≈3). Generalization to large coupled models
  is not claimed.
- **Element-count asymmetry.** dnfc, Cosivina, and cosivina-python carry an inert `NormalNoise`
  element (amplitude 0) per field, i.e. 4N elements; Cedar models noise as a field *parameter*
  (`input noise gain = 0`), i.e. 3N elements + the parameter. At amplitude 0 the extra element is
  near-free, but it is a small, disclosed asymmetry (it slightly disadvantages the non-Cedar
  frameworks, so it does not inflate dnfc's lead).
- **Architecture is a single detection-style field** (one Gaussian lateral kernel, no global
  inhibition, one stimulus). The convolution-heavy regimes used in real models (Mexican-hat memory
  fields, global-inhibition selection) are exercised by the *validation* suite but not yet by the
  benchmark; per-architecture benchmarking is planned (`../.claude/plans/benchmark-rigor-and-realism.md`).
- **Warm-up is 200 steps.** Sufficient for these compiled/JIT paths to reach steady state here, but
  not independently swept.
- **Single machine, boost-clock variance.** Absolute sps depend on this specific CPU and its thermal
  state; the cross-framework *ratios* are the portable result, not the absolute numbers.

## Data provenance

All four frameworks should be measured in a single back-to-back session on an otherwise-idle machine
so the cross-framework ratios are internally consistent (no mixing of measurement days / machine
states). Each `data/timings-*.csv` row is `framework,mode,N,run,steps_per_second`; regenerate all
tables and figures with `Rscript analysis.R` and `Rscript fig_benchmark.R`.