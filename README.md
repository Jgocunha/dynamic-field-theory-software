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
| [`cross-platform-validation/`](cross-platform-validation/README.md) | Correctness study (1D): 100 DFT simulations across 5 architectures, verifying algebraic equivalence and behavioural reliability |
| [`cross-platform-validation-2d/`](cross-platform-validation-2d/README.md) | Same correctness study on 2D (50×50) fields |

---

## Benchmark Results (1D)

Each benchmark creates N independent neural fields and measures wall-clock steps per second (median of 3 runs × 5 000 steps each).

### Steps per second

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| Cedar | 3 056 | 610 | 297 | 49 | 25 |
| Cosivina | 2 443 | 496 | 244 | 46 | 22 |
| cosivina-python | 6 965 | 1 300 | 553 | 103 | 50 |
| dnfc | 67 098 | 12 654 | 6 355 | 1 059 | 416 |

### Speedup relative to Cosivina

| N | dnfc | Cedar | cosivina-python |
|---|---:|---:|---:|
| 10 | 27.5× | 1.25× | 2.85× |
| 50 | 25.5× | 1.23× | 2.62× |
| 100 | 26.0× | 1.22× | 2.27× |
| 500 | 23.0× | 1.07× | 2.24× |
| 1000 | 18.9× | 1.14× | 2.27× |

**dnfc is by far the fastest** (~19–27× Cosivina, ~17–22× Cedar) after its AVX2 convolution/sigmoid optimization, with **numba-JIT cosivina-python second** (~2.2–2.85× Cosivina). Cedar is modestly faster than Cosivina (~1.1–1.25×, narrowing at large N). Cedar is run through its real library API (OpenCV `CV_32F` convolution), so these figures reflect the full framework overhead. (dnfc figures are the optimized build; the other three are unchanged. cosivina-python is benchmarked on its numba path; the validation suite uses the slower pure-Python path.) See [`benchmarking/README.md`](benchmarking/README.md) for the full methodology and statistical breakdown.

---

## Benchmark Results (2D)

The same N-sweep on **2D (50×50) fields** (2500 cells vs 100 in 1D), where the lateral convolution dominates each step. Run over dnfc, Cedar, and cosivina-python (numba); **Cosivina/MATLAB pending**.

### Steps per second

| Framework | N=10 | N=50 | N=100 | N=500 | N=1000 |
|---|---:|---:|---:|---:|---:|
| dnfc | 2 671 | 436 | 194 | 40 | — † |
| Cedar | 1 545 | 297 | 144 | 27 | 14 |
| cosivina-python | 317 | 54 | 29 | 6 | 3 |

† dnfc N=1000 not run this round (2D sweep capped at N=500).

**dnfc is fastest in 2D after its convolution optimization.** Earlier builds had dnfc as the *slowest* 2D framework (its scalar separable convolution did not scale to 2500-cell fields). The AVX2-vectorized 2D convolution raised dnfc 2D throughput ~8–10× (N=10: 253 → 2 671 sps), so dnfc now leads at every measured N — **~1.4–1.7× faster than Cedar** and ~7–8× faster than numba cosivina-python. The lead over Cedar is much narrower than in 1D (~17–22×) because the SIMD convolution is a larger share of the 2D step (Cedar also uses OpenCV SIMD). See [`benchmarking-2d/README.md`](benchmarking-2d/README.md) for the full breakdown and the [dnfc 2D-convolution optimization plan](.claude/plans/dnfc-2d-convolution-optimization.md) (implemented).

---

## Cross-Platform Validation Results (1D)

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

---

## Cross-Platform Validation Results (2D)

The same 100-simulation, 5-architecture suite was run on **2D (50×50) fields** across all four frameworks (dnfc, Cedar, Cosivina, cosivina-python). Stimuli are placed on the grid diagonal and kernel amplitudes are re-tuned per architecture type (a normalized 2D Gaussian is ~7.5× weaker at peak than 1D); see [`cross-platform-validation-2d/test_suite_2d.md`](cross-platform-validation-2d/test_suite_2d.md).

### Algebraic equivalence (same activation function family)

| Comparison pair | Max abs(Δu) | Median | Threshold | Result |
|---|---:|---:|---:|---:|
| Cosivina Sigmoid β=100 vs dnfc Sigmoid β=100 | 5.00×10⁻⁵ | 5×10⁻⁶ | 1×10⁻⁴ | **PASS** (all types) |
| cosivina-python Sigmoid β=100 vs dnfc Sigmoid β=100 | 5.00×10⁻⁵ | 5×10⁻⁶ | 1×10⁻⁴ | **PASS** (all types) |
| cosivina-python β=100 vs Cosivina β=100 | 1.0×10⁻¹³ | 1×10⁻¹⁵ | 1×10⁻⁴ | **PASS** (all types) |
| Cedar AbsSigmoid vs dnfc AbsSigmoid | 1.00×10⁻⁴ (non-memory) | 1×10⁻⁵ | 2×10⁻⁴ | **PASS** 4/5; memory float32-limited |
| Cedar Heaviside vs dnfc Heaviside | 1.00×10⁻⁴ (non-memory) | 1×10⁻⁵ | 2×10⁻⁴ | **PASS** 4/5; memory float32-limited |

All three float64 pairs are algebraically equivalent in 2D to 5×10⁻⁵ across **every** architecture, including memory. Cedar (float32) vs dnfc agree to ≤1×10⁻⁴ for detection, selection, insufficient, and multi-peak; only the **memory** architecture exceeds the threshold. There all 20 memory sims deviate, ~10 by a full perimeter ring — the self-sustaining bistable bump locks into a *different radius* in float32 vs float64 (e.g. 177 vs 166 cells), giving field-wide differences up to ~3.3. This is a precision effect, not an algorithmic one: a parameter sweep only relocates which sim lands on a ring boundary, and the float64 pairs reproduce the same bumps exactly. We checked whether the activation function is responsible — it is not the cross-framework cause: Cedar's and dnfc's AbsSigmoid are the identical double formula, and with the function held fixed Cedar's bump is still a ring larger (the residual is Cedar's CV_32F truncated OpenCV convolution). The function *choice* does affect bump size, but as a separate, compounding effect. See [`cross-platform-validation-2d/README.md`](cross-platform-validation-2d/README.md) and `.claude/cedar-notes.md` for the full decomposition. Behaviour still agrees 100%.

### Behavioural reliability

**1200 / 1200 comparisons (100%)** show qualitative agreement across all frameworks, simulation types, and phases — including the self-sustaining memory bumps.

See [`cross-platform-validation-2d/README.md`](cross-platform-validation-2d/README.md) for the full 2D design, per-type amplitude rules, and figures.
