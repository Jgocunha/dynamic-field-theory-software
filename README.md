# DFT Framework Benchmarking and Cross-Platform Validation

This repository documents two independent studies comparing four implementations of **Dynamic Field Theory (DFT)** — a mathematical framework for modelling neural population dynamics. The studies measure runtime performance and verify numerical correctness across frameworks.

---

## Frameworks

| Framework | Language | Precision | Version |
|---|---|---|---|
| [Cedar](https://github.com/cedar/cedar) | C++ | float32 | 6.2.0 |
| [Cosivina](https://github.com/cosivina/cosivina) | MATLAB | float64 | 1.4.0 |
| [cosivina-python](https://github.com/cosivina/cosivina_python) | Python / NumPy | float64 | 0.1.0 |
| [dnf-composer](https://github.com/Jgocunha/dynamic-neural-field-composer) | C++ | float64 | 2.9.3 |

All frameworks implement the 1D Amari equation:

```
τ · du/dt = −u + h + w * σ(u) + S
```

---

## Repository Layout

| Directory | Contents |
|---|---|
| [`benchmarking/`](benchmarking/README.md) | Performance benchmark (1D): N independent neural fields (N ∈ {5, 10, 50, 100}) across 4 canonical regimes and 2 field sizes, measuring simulation steps per second |
| [`benchmarking-2d/`](benchmarking-2d/README.md) | Same performance benchmark on 2D (100×100 / 200×200) fields |
| [`cross-platform-validation/`](cross-platform-validation/README.md) | Correctness study (1D): 100 DFT simulations across 5 architectures, verifying algebraic equivalence and behavioural reliability |
| [`cross-platform-validation-2d/`](cross-platform-validation-2d/README.md) | Same correctness study on 2D (50×50) fields |

---

## Benchmark Results (1D)

Each benchmark creates N independent neural fields (N ∈ {5, 10, 50, 100}), across 4 canonical
regimes (detection, selection, memory, multi-peak) and 2 field sizes, and measures wall-clock steps
per second (median of 5 runs × 2 000 steps each). All six framework variants convolve the same real
kernel support and use matched activation functions (see `TRADE_OFF_CAVEATS.md` and
`benchmarking/README.md` *Benchmark Design* for how).

### Steps per second at N=100 (median across regimes' range)

| Framework (variant) | field=100 | field=500 |
|---|---:|---:|
| dnfc | 6 735–7 884 | 1 527–1 746 |
| cosivina-python (numba) | 1 330–1 597 | 384–487 |
| Cedar (FFTW) | 984–1 112 | 283–678 |
| cosivina-python (NumPy) | 431–511 | 257–307 |
| Cedar (OpenCV) | 202–684 | 73–253 |
| Cosivina (MATLAB) | 173–195 | 118–142 |

**dnfc is by far the fastest** in every regime (38–44× Cosivina at field=100, 12–13× at field=500),
with **numba-JIT cosivina-python second** at both field sizes. See
[`benchmarking/README.md`](benchmarking/README.md) for the full per-regime breakdown, methodology,
and statistical detail.

---

## Benchmark Results (2D)

The same regime × N sweep on **2D (100×100 or 200×200) fields**, where the lateral convolution
dominates each step. All six variants, all four regimes, both grid sizes.

### Steps per second at N=100 (median across regimes' range)

| Framework (variant) | grid=100 | grid=200 |
|---|---:|---:|
| dnfc | 42.2–63.6 | 10.8–15.7 |
| Cosivina (MATLAB) | 16.4–38.6 | 5.3–12.6 |
| Cedar (OpenCV) | 16.5–43.2 | 6.2–11.6 |
| Cedar (FFTW) | 35.3–37.0 | 8.9–9.2 |
| cosivina-python (numba) | 9.8–20.2 | 2.5–5.5 |
| cosivina-python (NumPy) | 2.7–5.3 | 1.1–2.1 |

**dnfc wins every regime at both grids**, but narrowly (1.2–2.6×) compared to 1D — 2D's
convolution-dominated step gives Cedar's and Cosivina's convolution paths much more room to
compete. A genuinely surprising, investigated finding: **Cosivina (MATLAB) is competitive with, and
sometimes beats, both Cedar engines** — traced to Cedar's general-framework overhead (locking,
trigger dispatch, allocation), not a bug; see [`benchmarking-2d/README.md`](benchmarking-2d/README.md)
*Key observations* and [`TRADE_OFF_CAVEATS.md`](TRADE_OFF_CAVEATS.md) §5 for the full account.

---

## Cross-Platform Validation Results (1D)

100 simulations were run across 5 DFT architectures (detection, selection, memory, insufficient, multi-peak), each executed in two phases (stimulus ON / OFF), across **six framework variants** (Cedar-OpenCV, Cedar-FFTW, Cosivina, cosivina-python-numba, cosivina-python-nonumba, dnfc). Every same-activation-function-family pair is compared: **21 pairs** total (3 AbsSigmoid + 3 Heaviside + 15 logistic-sigmoid, since Cedar's built-in `ExpSigmoid` gives it a working logistic-sigmoid variant too).

### Algebraic equivalence (same activation function family)

**All 21 pairs PASS.** A representative subset:

| Comparison pair | Max abs(Δu) | Threshold | Result |
|---|---:|---:|---:|
| Cedar (OpenCV) AbsSigmoid vs dnfc AbsSigmoid | 1.00×10⁻⁴ | 2×10⁻⁴ | **PASS** |
| Cedar (OpenCV) Heaviside vs dnfc Heaviside | 1.00×10⁻⁴ | 2×10⁻⁴ | **PASS** |
| Cedar (OpenCV) Sigmoid vs dnfc Sigmoid | 1.00×10⁻⁴ | 2×10⁻⁴ | **PASS** |
| Cosivina Sigmoid β=100 vs dnfc Sigmoid β=100 | 5.00×10⁻⁵ | 1×10⁻⁴ | **PASS** |
| cosivina-python Sigmoid β=100 vs dnfc Sigmoid β=100 | 5.00×10⁻⁵ | 1×10⁻⁴ | **PASS** |
| cosivina-python Sigmoid β=100 vs Cosivina Sigmoid β=100 | 5.00×10⁻⁵ | 1×10⁻⁴ | **PASS** |

All same-family pairs pass; deviations are bounded by float32 rounding (Cedar) or accumulated float64 error over 500 integration steps (MATLAB / Python / dnfc). Full 21-pair table in [`cross-platform-validation/README.md`](cross-platform-validation/README.md).

### Behavioural reliability

**4200 / 4200 comparisons (100%)** show qualitative agreement across all frameworks, simulation types, phases, and activation function families. No simulation produces a qualitative discrepancy (bump in one framework, no bump in another).

See [`cross-platform-validation/README.md`](cross-platform-validation/README.md) for the full experimental design, cross-family deviation analysis, and figures.

---

## Cross-Platform Validation Results (2D)

The same 100-simulation, 5-architecture suite was run on **2D (50×50) fields** across all **six
framework variants** (Cedar-OpenCV, Cedar-FFTW, Cosivina, cosivina-python-numba,
cosivina-python-nonumba, dnfc) — same 21 comparison pairs as 1D. Stimuli are placed on the grid
diagonal and kernel amplitudes are re-tuned per architecture type (a normalized 2D Gaussian is
~7.5× weaker at peak than 1D); see [`cross-platform-validation-2d/test_suite_2d.md`](cross-platform-validation-2d/test_suite_2d.md).

### Algebraic equivalence (same activation function family)

**8/21 pairs PASS; 13/21 FAIL — every failure isolated to the `memory` architecture type only**
(all other types stay at the float32 rounding ceiling, ~1×10⁻⁴). The passing 8 are exactly the
pairs with no Cedar-vs-(dnfc/Cosivina/cosivina-python) leg: the two same-engine-family
opencv↔fftw pairs, plus all six all-float64 pairs.

| Comparison pair | Max abs(Δu) | Threshold | Result |
|---|---:|---:|---:|
| Cosivina Sigmoid β=100 vs dnfc Sigmoid β=100 | 5.00×10⁻⁵ | 1×10⁻⁴ | **PASS** (all types) |
| cosivina-python Sigmoid β=100 vs dnfc Sigmoid β=100 | 5.00×10⁻⁵ | 1×10⁻⁴ | **PASS** (all types) |
| cosivina-python β=100 vs Cosivina β=100 | 1.0×10⁻¹³ | 1×10⁻⁴ | **PASS** (all types) |
| Cedar (OpenCV) vs Cedar (FFTW), AbsSigmoid/Heaviside | 1.00×10⁻⁴ | 2×10⁻⁴ | **PASS** (all types) |
| Cedar (OpenCV/FFTW) vs dnfc, any activation function | up to 2.58 (memory) | 2×10⁻⁴ | **FAIL** memory only |

All six float64 pairs are algebraically equivalent in 2D to 5×10⁻⁵ across **every** architecture,
including memory. Every Cedar-involving pair agrees to ≤1×10⁻⁴ for detection, selection,
insufficient, and multi-peak; only the **memory** architecture exceeds the threshold, on **both**
Cedar engines and all three activation functions. The self-sustaining bistable bump locks into a
*different radius* in float32 vs float64 (e.g. 177 vs 166 cells), giving field-wide differences up
to ~2.6. This is a precision effect, not an algorithmic one: a parameter sweep only relocates which
sim lands on a ring boundary, and the float64 pairs reproduce the same bumps exactly. We checked
whether the activation function is responsible — it is not the cross-framework cause: Cedar's and
dnfc's AbsSigmoid are the identical double formula, and with the function held fixed Cedar's bump
is still a ring larger (the residual is Cedar's CV_32F truncated OpenCV convolution). The function
*choice* does affect bump size, but as a separate, compounding effect. See
[`cross-platform-validation-2d/README.md`](cross-platform-validation-2d/README.md) and
`.claude/reports/cedar-notes.md` for the full decomposition. Behaviour still agrees 100%.

### Behavioural reliability

**4200 / 4200 comparisons (100%)** show qualitative agreement across all frameworks, simulation
types, and phases — including the self-sustaining memory bumps on **both** Cedar engines. (An
earlier measurement showed Cedar-FFTW's memory bump disagreeing — traced to a kernel-limit units
bug plus a missing exception guard in the validation runner, both since fixed; see
[`cross-platform-validation-2d/README.md`](cross-platform-validation-2d/README.md) for the
before/after.)

See [`cross-platform-validation-2d/README.md`](cross-platform-validation-2d/README.md) for the full 2D design, per-type amplitude rules, and figures.
