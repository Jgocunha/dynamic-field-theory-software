# DFT Framework Benchmark Report

## Test Machine

| Property | Value |
|---|---|
| CPU | AMD Ryzen 5 3600 (6 cores / 12 threads, 3.6 GHz base) |
| RAM | 32 GB DDR4 |
| OS | Windows 11 Pro (build 10.0.22621), 64-bit |
| Compiler (Cedar / dnfc) | MSVC 19.44 (Visual Studio 2022 Community) |
| MATLAB version | R2023a |
| Python version | 3.11 |
| dnfc version | 2.4.1 |
| Cedar version | 6.1.0 |
| Cosivina version | 1.4.0 |
| cosivina-python version | 0.1.0 (nonumba path for validation; numba path for benchmarks) |

All benchmarks ran single-threaded. No process pinning was applied.

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

Total elements: 4N. Fields are independent (no cross-field connections).

**Timing protocol:**
- 200 warm-up steps (discarded)
- 3 timed runs of 5 000 steps each
- Metric: steps per second (wall-clock via `std::chrono` or MATLAB `tic/toc`)
- Reported value: median of 3 runs

**Precision:** Cedar uses float32; Cosivina and dnfc use float64.

---

## Results

![Throughput](fig_benchmark_throughput.png)

![Speedup](fig_benchmark_speedup.png)

### Table 1 — Steps per second (median of 3 runs)

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| Cedar | 5 798 | 1 240 | 616 | 118 | 61 |
| Cosivina | 2 443 | 496 | 244 | 46 | 22 |
| cosivina-python | 2 091 | 426 | 209 | 42 | 20 |
| dnfc | 8 190 | 1 601 | 794 | 142 | 70 |

### Table 2 — Detailed: median [min – max] steps/second

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---|---|---|---|---|
| Cedar | 5798 [5439–5841] | 1240 [1213–1304] | 616 [616–632] | 118 [117–120] | 61 [60–62] |
| Cosivina | 2443 [2300–2483] | 496 [495–497] | 244 [242–245] | 46 [45–46] | 22 [22–22] |
| cosivina-python | 2091 [2081–2134] | 426 [425–430] | 209 [209–213] | 42 [42–42] | 20 [20–21] |
| dnfc | 8190 [7726–8264] | 1601 [1587–1630] | 794 [757–811] | 142 [133–147] | 70 [69–70] |

---

## Statistical Summary

### Run-to-run variability

All frameworks show low variability (SD < 5% of median) across the 3 runs,
confirming stable, reproducible measurements.

| Framework | N | Median (sps) | Min | Max | SD |
|---|---|---:|---:|---:|---:|
| cedar | 10 | 5798 | 5439 | 5841 | 219 |
| cedar | 50 | 1240 | 1213 | 1304 | 47 |
| cedar | 100 | 616 | 616 | 632 | 9 |
| cedar | 500 | 118 | 117 | 120 | 2 |
| cedar | 1000 | 61 | 60 | 62 | 1 |
| cosivina | 10 | 2443 | 2300 | 2483 | 101 |
| cosivina | 50 | 496 | 495 | 497 | 1 |
| cosivina | 100 | 244 | 242 | 245 | 2 |
| cosivina | 500 | 46 | 45 | 46 | 1 |
| cosivina | 1000 | 22 | 22 | 22 | 0.2 |
| cosivina-python | 10 | 2091 | 2081 | 2134 | 27 |
| cosivina-python | 50 | 426 | 425 | 430 | 3 |
| cosivina-python | 100 | 209 | 209 | 213 | 2 |
| cosivina-python | 500 | 42 | 42 | 42 | 0 |
| cosivina-python | 1000 | 20 | 20 | 21 | 0.7 |
| dnfc | 10 | 8190 | 7726 | 8264 | 283 |
| dnfc | 50 | 1601 | 1587 | 1630 | 22 |
| dnfc | 100 | 794 | 757 | 811 | 28 |
| dnfc | 500 | 142 | 133 | 147 | 7 |
| dnfc | 1000 | 70 | 69 | 70 | 0.4 |

### Speedup ratios (headless, relative to Cosivina)

| N | dnfc / Cosivina | Cedar / Cosivina | dnfc / Cedar | cosivina-python / Cosivina |
|---|---:|---:|---:|---:|
| 10 | 3.35× | 2.37× | 1.41× | 0.86× |
| 50 | 3.23× | 2.50× | 1.29× | 0.86× |
| 100 | 3.25× | 2.53× | 1.29× | 0.86× |
| 500 | 3.12× | 2.60× | 1.20× | 0.92× |
| 1000 | 3.13× | 2.73× | 1.15× | 0.92× |

### Scaling efficiency (steps/s relative to N=10 baseline; 1.0 = perfectly linear)

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| cedar | 1.000 | 1.070 | 1.063 | 1.022 | 1.047 |
| cosivina | 1.000 | 1.016 | 0.999 | 0.934 | 0.910 |
| cosivina-python | 1.000 | 1.019 | 1.002 | 1.004 | 0.977 |
| dnfc | 1.000 | 0.978 | 0.969 | 0.870 | 0.851 |

Key observations:
- **dnfc is consistently the fastest** across all tested configurations.
- **dnfc is ~3.1–3.4× faster than Cosivina** across all N values — a stable ratio that indicates the advantage is structural (compiled native C++ vs MATLAB interpreter overhead), not tied to a specific working-set size.
- **Cedar is ~2.4–2.7× faster than Cosivina**. Cedar's runner uses float32 arithmetic (vs float64 in Cosivina and dnfc), which contributes to its advantage over Cosivina but limits it compared to dnfc (which uses float64 yet is still faster).
- **dnfc is ~1.2–1.4× faster than Cedar**. This gap narrows slightly at higher N, suggesting that at large element counts memory bandwidth (shared between float32 and float64 vectors of the same element count) becomes the dominant cost.
- **cosivina-python is ~86–92% as fast as Cosivina (MATLAB)**. The gap is small because both implementations ultimately call into BLAS-backed array routines (NumPy vs MATLAB) for the convolution. Python object-dispatch overhead per `sim.step()` call accounts for the remaining difference. cosivina-python also shows near-perfect scaling efficiency (closest to 1.0 at all N), meaning its per-step cost is almost purely the convolution with minimal fixed overhead.