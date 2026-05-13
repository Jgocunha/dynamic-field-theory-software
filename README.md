# DFT Framework Benchmarking and Cross-Platform Validation

This repository documents two independent studies comparing four implementations of **Dynamic Field Theory (DFT)** — a mathematical framework for modelling neural population dynamics. The studies measure runtime performance and verify numerical correctness across frameworks.

---

## Frameworks

| Framework | Language | Precision | Version |
|---|---|---|---|
| [Cedar](https://github.com/cedar/cedar) | C++ | float32 | 6.1.0 |
| [Cosivina](https://github.com/cosivina/cosivina) | MATLAB | float64 | 1.4.0 |
| [cosivina-python](https://github.com/cosivina/cosivina_python) | Python / NumPy | float64 | 0.1.0 |
| [dnf-composer](https://github.com/Jgocunha/dynamic-neural-field-composer) | C++ | float64 | 2.4.1 |

All frameworks implement the 1D Amari equation:

```
τ · du/dt = −u + h + w * σ(u) + S
```

---

## Repository Layout

| Directory | Contents |
|---|---|
| [`benchmarking/`](benchmarking/README.md) | Performance benchmark: N independent neural fields (N ∈ {10, 50, 100, 500, 1000}), measuring simulation steps per second |
| [`cross-platform-validation/`](cross-platform-validation/README.md) | Correctness study: 100 DFT simulations across 5 architectures, verifying algebraic equivalence and behavioural reliability |

---

## Benchmark Results

Each benchmark creates N independent neural fields and measures wall-clock steps per second (median of 3 runs × 5 000 steps each).

### Steps per second

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| Cedar | 5 798 | 1 240 | 616 | 118 | 61 |
| Cosivina | 2 443 | 496 | 244 | 46 | 22 |
| cosivina-python | 2 091 | 426 | 209 | 42 | 20 |
| dnfc | 8 190 | 1 601 | 794 | 142 | 70 |

### Speedup relative to Cosivina

| N | dnfc | Cedar | cosivina-python |
|---|---:|---:|---:|
| 10 | 3.35× | 2.37× | 0.86× |
| 50 | 3.23× | 2.50× | 0.86× |
| 100 | 3.25× | 2.53× | 0.86× |
| 500 | 3.12× | 2.60× | 0.92× |
| 1000 | 3.13× | 2.73× | 0.92× |

**dnfc is consistently the fastest**. Cedar is ~2.4–2.7× faster than Cosivina; cosivina-python runs at ~86–92% of Cosivina speed. See [`benchmarking/README.md`](benchmarking/README.md) for the full methodology and statistical breakdown.

---

## Cross-Platform Validation Results

100 simulations were run across 5 DFT architectures (detection, selection, memory, insufficient, multi-peak), each executed in two phases (stimulus ON / OFF). Results were compared across 6 framework pairs.

### Algebraic equivalence (same activation function family)

| Comparison pair | Max abs(Δu) | Threshold | Result |
|---|---:|---:|---:|
| Cedar AbsSigmoid vs dnfc AbsSigmoid | 1.00×10⁻⁴ | 2×10⁻⁴ | **PASS** |
| Cedar Heaviside vs dnfc Heaviside | 1.00×10⁻⁴ | 2×10⁻⁴ | **PASS** |
| Cosivina Sigmoid β=100 vs dnfc Sigmoid β=100 | 5.00×10⁻⁵ | 1×10⁻⁴ | **PASS** |
| cosivina-python Sigmoid β=100 vs dnfc Sigmoid β=100 | 5.00×10⁻⁵ | 1×10⁻⁴ | **PASS** |
| cosivina-python Sigmoid β=100 vs Cosivina Sigmoid β=100 | 5.00×10⁻⁵ | 1×10⁻⁴ | **PASS** |

All same-family pairs pass; deviations are bounded by float32 rounding (Cedar) or accumulated float64 error over 500 integration steps (MATLAB / Python / dnfc).

### Behavioural reliability

**800 / 800 comparisons (100%)** show qualitative agreement across all frameworks, simulation types, phases, and activation function families. No simulation produces a qualitative discrepancy (bump in one framework, no bump in another).

See [`cross-platform-validation/README.md`](cross-platform-validation/README.md) for the full experimental design, cross-family deviation analysis, and figures.
