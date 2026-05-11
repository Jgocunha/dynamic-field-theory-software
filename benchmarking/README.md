# DFT Framework Benchmark Report

## Test Machine

| Property | Value |
|---|---|
| CPU | AMD Ryzen 5 3600 (6 cores / 12 threads, 3.6 GHz base) |
| RAM | 32 GB DDR4 |
| OS | Windows 11 Pro (build 10.0.22621), 64-bit |
| Compiler (Cedar / dnfc) | MSVC 19.44 (Visual Studio 2022 Community) |
| MATLAB version | R2023a |
| dnfc version | 2.4.1 |
| Cedar version | 6.1.0 |
| Cosivina version | 1.4.0 |

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

### Table 1 — Steps per second (median of 3 runs)

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| Cedar | 5 798 | 1 252 | 621 | 119 | 61 |
| Cosivina | 2 443 | 496 | 244 | 45 | 22 |
| dnfc | 8 190 | 1 601 | 787 | 142 | 70 |

### Table 2 — Detailed: median [min – max] steps/second

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---|---|---|---|---|
| Cedar | 5798 [5439–5841] | 1252 [1213–1304] | 621 [616–632] | 119 [117–120] | 61 [60–62] |
| Cosivina | 2443 [2300–2483] | 496 [495–497] | 244 [242–245] | 45 [45–46] | 22 [22–22] |
| dnfc | 8190 [7726–8264] | 1601 [1587–1630] | 787 [757–811] | 142 [133–147] | 70 [69–70] |

---

## Statistical Summary

### Run-to-run variability

All frameworks show low variability (SD < 5% of median) across the 3 runs,
confirming stable, reproducible measurements.

| Framework | N | Median (sps) | Min | Max | SD |
|---|---|---:|---:|---:|---:|
| cedar | 10 | 5798 | 5439 | 5841 | 219 |
| cedar | 50 | 1252 | 1213 | 1304 | 47 |
| cedar | 100 | 621 | 616 | 632 | 9 |
| cedar | 500 | 119 | 117 | 120 | 2 |
| cedar | 1000 | 61 | 60 | 62 | 1 |
| cosivina | 10 | 2443 | 2300 | 2483 | 101 |
| cosivina | 50 | 496 | 495 | 497 | 1 |
| cosivina | 100 | 244 | 242 | 245 | 2 |
| cosivina | 500 | 45 | 45 | 46 | 1 |
| cosivina | 1000 | 22 | 22 | 22 | 0.2 |
| dnfc | 10 | 8190 | 7726 | 8264 | 283 |
| dnfc | 50 | 1601 | 1587 | 1630 | 22 |
| dnfc | 100 | 787 | 757 | 811 | 28 |
| dnfc | 500 | 142 | 133 | 147 | 7 |
| dnfc | 1000 | 70 | 69 | 70 | 0.4 |

### Speedup ratios (headless, relative to Cosivina)

| N | dnfc / Cosivina | Cedar / Cosivina | dnfc / Cedar |
|---|---:|---:|---:|
| 10 | 3.35× | 2.37× | 1.41× |
| 50 | 3.23× | 2.52× | 1.28× |
| 100 | 3.22× | 2.54× | 1.27× |
| 500 | 3.16× | 2.64× | 1.20× |
| 1000 | 3.18× | 2.77× | 1.15× |

Key observations:
- **dnfc is consistently the fastest** across all tested configurations.
- **dnfc is ~3.2× faster than Cosivina** across all N values — a stable ratio that indicates the advantage is structural (compiled native C++ vs MATLAB interpreter overhead), not tied to a specific working-set size.
- **Cedar is ~2.5× faster than Cosivina**. Cedar's runner uses float32 arithmetic (vs float64 in Cosivina and dnfc), which contributes to its advantage over Cosivina but limits it compared to dnfc (which uses float64 yet is still faster).
- **dnfc is ~1.2–1.4× faster than Cedar**. This gap narrows slightly at higher N, suggesting that at large element counts memory bandwidth (shared between float32 and float64 vectors of the same element count) becomes the dominant cost.