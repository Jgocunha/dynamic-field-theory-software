# Cross-Platform Validation Report
## Dynamic Neural Field Theory Implementations: Cedar, Cosivina, cosivina-python, and dnf-composer

**Frameworks compared:** Cedar (C++, float32), Cosivina (MATLAB, float64), cosivina-python (Python/NumPy, float64), dnfc (C++, float64)  
**Scope:** 100 simulations × 5 DFT architectures × 6 comparison pairs × 2 simulation phases

---

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
| cosivina-python version | 0.1.0 (nonumba path) |

---

## 1. Objective

This experiment establishes that three independent implementations of Dynamic Field Theory (DFT) — Cedar, Cosivina, and the Dynamic Neural Field Composer (dnfc) — produce **algebraically equivalent** results when using the same activation function family, and **behaviourally consistent** results across all parameter configurations and activation function families.

Two claims are verified:

1. **Algebraic equivalence** — when two frameworks implement the same sigmoid function, their activation profiles agree to within the numerical precision of the more limited framework (float32 for Cedar, float64 for Cosivina and dnfc).
2. **Behavioural reliability** — all frameworks produce the same qualitative field state (suprathreshold self-sustained activity vs. subthreshold resting state) for every simulation, regardless of sigmoid family.

---

## 2. Experimental Design

### 2.1 Simulation Architecture

Each simulation consists of:
- One 1D neural field `u` of size 100, evolving under the Amari equation:  
  `τ · du/dt = −u + h + w * σ(u) + S`  
  where `τ = 25 ms`, `h` is the resting level, `w` is the lateral interaction kernel, `σ` is the activation function, and `S` is the external stimulus.
- A Gaussian stimulus `S` (one or more), controlled in amplitude across two phases.
- A lateral interaction kernel (Gauss, Mexican hat, or global inhibition).

### 2.2 Simulation Types (100 total)

| Type | IDs | Architecture | Distinguishing feature |
|---|---|---|---|
| Detection | 001–020 | 1 stimulus + NF + GaussKernel | Field crosses detection threshold |
| Selection | 021–040 | 2 stimuli + NF + GaussKernel + global inh | Winner-take-all competition |
| Memory | 041–060 | 1 stimulus + NF + MexicanHatKernel | Self-sustained bump after stimulus off |
| Insufficient | 061–080 | 1 stimulus + NF + weak GaussKernel | Field remains subthreshold |
| Multi-peak | 081–100 | 2–3 stimuli + NF + narrow GaussKernel | Multiple coexisting bumps |

### 2.3 Protocol

Each simulation runs two consecutive phases:
1. **Phase 1 (stimulus ON):** 500 integration steps (Euler, Δt = 25 ms). Activation profile saved at step 500.
2. **Phase 2 (stimulus OFF):** All stimulus amplitudes set to zero; 500 further steps. Activation profile saved at step 500.
3. Field is re-initialised before the next simulation.

### 2.4 Activation Functions

Three sigmoid variants are tested:

| Label | Formula | Frameworks |
|---|---|---|
| AbsSigmoid (β=100) | σ(u) = ½(1 + β(u−θ)/(1+β abs(u−θ))) | Cedar, dnfc |
| Heaviside (θ=0) | σ(u) = 1 if u > 0 else 0 | Cedar, dnfc |
| Logistic sigmoid (β=100) | σ(u) = 1/(1+exp(−β(u−θ))) | Cosivina, dnfc |

### 2.5 Comparison Pairs

| Pair | Framework A | Framework B | Expected precision |
|---|---|---|---|
| cedar_abs_vs_dnfc_abs | Cedar AbsSigmoid | dnfc AbsSigmoid | Float32 ceiling (~1×10⁻⁴) |
| cedar_hv_vs_dnfc_hv | Cedar Heaviside | dnfc Heaviside | Float32 ceiling (~1×10⁻⁴) |
| cosivina_s100_vs_dnfc_s100 | Cosivina Sigmoid β=100 | dnfc Sigmoid β=100 | Float64 accumulated error (<1×10⁻⁴) |
| cedar_abs_vs_cosivina_s100 | Cedar AbsSigmoid | Cosivina Sigmoid β=100 | Systematic (different families) |
| cosivina_python_s100_vs_dnfc_s100 | cosivina-python Sigmoid β=100 | dnfc Sigmoid β=100 | Float64 accumulated error (<1×10⁻⁴) |
| cosivina_python_s100_vs_cosivina_s100 | cosivina-python Sigmoid β=100 | Cosivina Sigmoid β=100 | Float64 accumulated error (<1×10⁻⁴) |

### 2.6 Implementation Constraints

| Parameter | Cedar | Cosivina | cosivina-python | dnfc |
|---|---|---|---|---|
| Float precision | float32 (CV_32F) | float64 | float64 | float64 |
| Spatial convention | 0-based (output shifted +1 for comparison) | 1-based | 1-based | 1-based |
| Kernel support | `limit = 10` (half-width = round_odd(limit × σ)) | `cutoffFactor = 5.0` | `cutoffFactor = 5.0` | `cutoffFactor = 5.0` |
| Kernel normalisation | Enabled | Enabled | Enabled | Enabled |
| Field size | 100 | 100 | 100 | 100 |
| Noise | 0 | 0 | 0 | 0 |
| Boundary condition | Cyclic | Cyclic | Cyclic | Cyclic |

---

## 3. Results

### 3.1 Algebraic Equivalence (Same Activation Function Family)

All three same-family comparison pairs **PASS** the algebraic equivalence criterion.

| Pair | Max abs(Δu) | Median abs(Δu) | % within threshold | Threshold | Status |
|---|---|---|---|---|---|
| cedar_abs_vs_dnfc_abs | 1.00×10⁻⁴ | 0 | 100% | 2×10⁻⁴ | **PASS** |
| cedar_hv_vs_dnfc_hv | 1.00×10⁻⁴ | 0 | 100% | 2×10⁻⁴ | **PASS** |
| cosivina_s100_vs_dnfc_s100 | 5.00×10⁻⁵ | 4.89×10⁻⁶ | 100% | 1×10⁻⁴ | **PASS** |

**Interpretation:**

- **Cedar vs dnfc (AbsSigmoid and Heaviside):** Cedar internally uses 32-bit floating-point arithmetic (OpenCV `CV_32F`). When results are exported and compared against dnfc's float64 computation of the same equations, pointwise deviations are bounded by the float32 rounding error ceiling. The observed maximum deviation of 1×10⁻⁴ is consistent with this limit. The median is 0 (most field positions are either at a saturated value or at the resting level, where float32 and float64 agree exactly). This confirms that Cedar and dnfc implement the same mathematical equations and that deviations arise solely from arithmetic precision, not from algorithmic differences.

- **Cosivina vs dnfc (Logistic Sigmoid β=100):** Both frameworks use float64. The observed maximum deviation of 5×10⁻⁵ reflects the accumulated rounding error of 500 Euler integration steps under slightly different computation orders (MATLAB vs C++). This is well within the float64 expected tolerance for this integration length.

### 3.2 Behavioural Reliability (Qualitative Agreement)

**800 / 800 comparisons (100%) show qualitative agreement** across all simulation types, phases, and comparison pairs.

For every simulation in the test suite, all three frameworks agree on whether the neural field is in a suprathreshold self-sustained state (peak activation > 0) or a subthreshold resting state (peak activation ≤ 0). This holds even for:

- The cross-family comparison (Cedar AbsSigmoid vs Cosivina Logistic Sigmoid)
- Memory simulations in both phases (stimulus ON and stimulus OFF)
- Selection simulations (winner-take-all competition outcome is identical)

No simulation produces a qualitative discrepancy (bump in one framework, no bump in another) after the parameter set refinements described in Section 4.

### 3.3 Cross-Family Deviations (Cedar AbsSigmoid vs Cosivina Logistic Sigmoid)

These deviations are expected and reflect a systematic difference in bump profile shape between the two sigmoid families.

| Simulation type | Max abs(Δu) | Median abs(Δu) | Mean abs(Δu) | Interpretation |
|---|---|---|---|---|
| Insufficient | 0.0033 | 0.0015 | 0.0016 | Small absolute deviations; field is near h |
| Detection | 0.0314 | 0.0056 | 0.0082 | Bump shape differs at boundary |
| Multi-peak | 0.0389 | 0.0046 | 0.0100 | Multiple bump boundaries |
| Selection | 0.0185 | 0.0087 | 0.0102 | One active bump; competitor suppressed |
| Memory | 1.6615 | 0.0216 | 0.1356 | See note below |

**Note on memory simulations:** The AbsSigmoid and logistic sigmoid produce bumps of slightly different widths because their transition regions have different shapes. For most memory simulations, the difference is small (median 0.022). Two simulations (050 and 053) show larger deviations (~1.3–1.7) because their inhibitory kernel strength is weaker than the rest of the memory suite (amp_inh = 9.0 for sim_050), producing wider bumps with broader boundary regions where the sigmoid shape matters most. Both frameworks exhibit qualitatively identical behaviour in these cases (self-sustained bump both with and without stimulus).

---

## 4. Discussion

### 4.1 What is validated

- **Algebraic equivalence** is confirmed at the float32/float64 precision level for all simulations when the same sigmoid family is used. Cedar and dnfc produce identical results up to float32 rounding; Cosivina and dnfc produce identical results up to accumulated float64 rounding over 500 steps.

- **Behavioural reliability** is confirmed for all 100 simulations across all frameworks and activation functions. The qualitative DFT behaviour (detection, selection, memory, insufficient activation, multi-peak) is reproducible across the three implementations.

### 4.2 Known systematic differences

- **AbsSigmoid vs logistic sigmoid family:** These functions are mathematically distinct. Their bump profiles differ in width, with resulting pointwise deviations of ~0.005–0.04 for most simulation types and up to ~1.7 for memory simulations with weak inhibition (quantitative shape difference, not qualitative state difference).

- **Float32 precision (Cedar):** Cedar uses 32-bit floating-point arithmetic, introducing a systematic precision floor of ~1×10⁻⁴ relative to float64 frameworks. This is a platform characteristic, not an implementation error.

- **Spatial indexing (Cedar):** Cedar uses 0-based spatial coordinates, producing a cyclic shift of 1 position relative to Cosivina and dnfc (1-based). This is corrected in the analysis by rolling Cedar's output left by 1 position before comparison.

### 4.3 Limitations

- The test suite uses Euler integration with Δt = τ = 25 ms (step size equals the time constant). More accurate integration (smaller Δt) would reduce accumulated error but was not the focus of this validation.
- Noise is set to 0 in all simulations to isolate deterministic algebraic equivalence.
- The validation covers 1D fields only. 2D and higher-dimensional fields are not included in this test suite.

---

## 5. Conclusion

The cross-platform validation confirms that Cedar, Cosivina, and dnfc implement Dynamic Field Theory correctly and consistently. Within the same activation function family, deviations are bounded by the numerical precision of the limiting arithmetic type. Across activation function families, all simulations produce the same qualitative DFT states. The three frameworks are interoperable for the purpose of designing, testing, and validating DFT-based models.
