# Trade-off Caveats

This is an honest, single-machine micro-benchmark. The cross-framework throughput
*ratios* are the portable result; absolute steps-per-second are machine-specific.
Every methodological choice below is disclosed so a reader can judge the comparison
on its own terms. The same caveats apply to the 1D and 2D suites.

## 1. Numerical precision is not equalized (float32 vs float64)

Cedar computes in **float32**; dnfc, Cosivina, and cosivina-python compute in
**float64**. Throughput is measured per *step*, not per FLOP or per bit. float32
halves memory traffic and doubles SIMD lane width, so Cedar's raw step rate carries
an intrinsic advantage that the other frameworks do not get.

This is a property of the frameworks as shipped — Cedar's field engine is float32 and
cannot be switched to float64 without modifying the library — so we report
*as-shipped default-precision throughput* rather than an architecture-normalized
figure. **Any Cedar-vs-(dnfc/Cosivina/cosivina-python) comparison should be read with
this precision difference in mind**; it flatters Cedar's numbers and is not removed by
our protocol. Same-precision comparisons (Cedar-OpenCV vs Cedar-FFTW; or
dnfc vs Cosivina vs cosivina-python) are not affected.

## 2. Convolution method differs by framework

Throughput differences partly reflect *how* each framework convolves, which is an
intrinsic property of the framework, not a confound:

| Framework / variant      | Convolution method                              |
|--------------------------|-------------------------------------------------|
| dnfc                     | Hybrid: direct spatial (truncated kernel) below a tap-count threshold; FFTW spectral (full field) above it — see note below |
| Cedar (OpenCV engine)    | Direct spatial convolution (`cv::filter2D`, zero-pad + wrap) |
| Cedar (FFTW engine)      | Spectral: FFT × FFT → inverse FFT (cyclic)      |
| Cosivina (MATLAB)        | Direct spatial convolution (`conv2`, separable in 2D) |
| cosivina-python (numba)  | Direct spatial convolution (`np.convolve` / `parCircConv`), numba-JIT host code |
| cosivina-python (nonumba)| Direct spatial convolution (`np.convolve` / `parCircConv`), pure NumPy |
| cosivina-python (fft)    | Spectral: `KernelFFT` element, `rfft2(input) × rfft2(kernel)` → inverse FFT (cyclic, full untruncated kernel), pure NumPy |

**Five of the seven variants convolve spatially with a truncated kernel; two are spectral —
Cedar-FFTW (float32) and cosivina-python-fft (float64).** The cosivina-python-fft variant
instantiates cosivina's spectral `KernelFFT` element; the numba/nonumba variants use the spatial
`GaussKernel*` / `LateralInteractions*` elements. These are reported as a framework characteristic,
not normalized away. Two important structural facts follow:

- **Two spatial-vs-spectral cross-overs are exposed:** Cedar-FFTW vs the spatial engines, and
  cosivina-python-fft vs its own spatial numba/nonumba siblings. Direct convolution cost grows with
  (kernel width × field size); spectral cost grows with (field size × log field size) independent of
  kernel width. So the FFT variants pull ahead on convolution-heavy regimes (wide Mexican-hat) and
  large fields, while the five spatial engines can win on narrow kernels / small fields. The
  field-size sweep (`benchmarking/README.md` *Benchmark Design*) is designed to expose this. Because
  dnfc, both Cosivina variants, and the two spatial cosivina-python variants are all spatial at the
  *identical* truncated tap count (§1 of `benchmarking/README.md`), the dnfc-vs-Cosivina /
  dnfc-vs-cosivina-python(numba/nonumba) comparison is like-for-like — same algorithm, same kernel
  support — not a spatial-vs-spectral confound. The cosivina-python-fft variant additionally provides
  a *float64* spectral data point (the cross-platform-validation study confirms it is numerically
  equivalent to the spatial variants, so the FFT is a genuine throughput alternative, not a different
  computation).
- **Spectral requires kernel ≤ field.** Cyclic FFT convolution zero-pads the
  kernel to the field length; a kernel wider than the field aliases onto itself and
  Cedar's FFTW engine throws. This is why the smallest field sizes are bounded below by
  the widest kernel (see §2 above) — it is a real constraint of spectral convolution, not a
  tuning choice. The OpenCV (spatial) engine has no such constraint. (cosivina-python-fft's
  `KernelFFT` builds the kernel at the full field size by construction, so it never trips this,
  but it convolves the full untruncated kernel — the reason it is a distinct convolution method.)

**dnfc's hybrid dispatch (added after the 2D memory-regime cross-over above was
identified as dnfc's weakest margin — see `benchmarking-2d/README.md`):** dnfc now
carries a second, spectral convolution path (`tools/fft_convolution.h`, FFTW3 — the
same library Cedar-FFTW uses, so the comparison isolates framework overhead from
FFT-library quality rather than confounding the two) alongside its original direct
path. Currently wired for `MexicanHatKernel2D` only (the widest, and only
two-component, kernel among dnfc's element types); `GaussKernel2D` and the 1D
elements still use the direct path exclusively.

- **Dispatch rule, and how it was derived.** An element switches to the spectral
  path when `circular=true`, the grid is at least 100×100 (see next bullet), and the
  combined exc+inh tap count exceeds 120 taps/cell. That threshold comes from equating
  the two paths' FLOP costs — direct ≈ 2 × taps × cells, spectral ≈ 2 × (5 × cells ×
  log2(cells)) for a forward+inverse real FFT — which crosses at roughly 115–130
  taps/cell for the grid sizes this benchmark uses (100×100, 200×200). It was **not**
  fitted to this benchmark's own four regimes: only `memory` uses `MexicanHatKernel2D`
  at all, so `detection`/`selection`/`multi-peak` are structurally unaffected by this
  change regardless of where the threshold sits.
- **The ≥100×100 floor is a real, separate restriction, not a fit to dodge a test.**
  dnf-composer's own internal regression fixtures (`FieldDynamics2D.AllSimsMatchReference`,
  sims 049/050) exercise this exact kernel shape on a *50×50* grid, where the wide
  inhibitory kernel is clamped to near-full-field support by construction. That
  specific configuration sits on a **bistable abssigmoid memory attractor knife-edge**
  — the same class of fragility already documented in dnfc's own source (see the
  reverted "scalar symmetric folding" attempt in `tools/math.h` / `simd_dispatch_avx2.cpp`,
  which cites the identical sims and an identical "dev up to 3.7" failure signature).
  Restricting the spectral path to grids at least as large as anything this benchmark
  or the cross-platform-validation suite actually exercises avoids that known fragility
  without touching the fixtures or loosening the dispatch rule itself.
- **Numerically verified, with an important caveat about the *memory* regime specifically.**
  With the field's noise source disabled, the spectral and direct paths agree to below
  the printed-precision floor (deterministic control, `MexicanHatKernel2D` at grid=100) —
  confirming the FFT kernel construction (circular wrap-embedding, sign, centering) is
  correct, not merely "close." With noise enabled (as the benchmark itself runs), the two
  paths' final-activation trajectories diverge substantially (~10% relative) over the
  full 2000-step run. This is **not** a defect in either path: `memory` is a self-sustained,
  marginally-stable bump attractor, and continuous stochastic forcing makes such a system
  chaotically sensitive to *any* valid numerical perturbation — the same mechanism behind
  the 049/050 fragility above, just triggered by noise instead of a reordering. Both
  trajectories are equally valid realizations of the same stochastic dynamics; they are
  simply different realizations. Anyone who needs bit-comparable trajectories between the
  two paths for a noise-driven memory simulation should be aware of this and pin one path
  explicitly rather than rely on the automatic dispatch.
- **License.** dnf-composer is GPL-3.0; FFTW is GPL-licensed — compatible, no new
  restriction introduced.

## 3. Single machine; absolute numbers are not portable

All measurements come from one CPU on an otherwise-idle machine, single-threaded (each
runner pins its math-library thread pools to 1; see the Test Machine table). Results
depend on this specific CPU, its boost/thermal state, and the linked BLAS/FFT backend
(NumPy/numba → the installed NumPy BLAS; MATLAB → its bundled libraries; Cedar/dnfc →
MSVC. dnfc's own code is compiled with `/arch:AVX2`; Cedar's own code has no arch flag,
but its OpenCV and FFTW backends dispatch AVX2+ at runtime regardless — see §4). Five
runs per cell (`analysis.R`/`analysis_2d.R` report median, SD, SEM, and a 95% CI per
cell) quantify short-timescale run-to-run noise *on this machine*, not the generality
of the result across hardware. **The cross-framework ratios are the finding; treat
absolute sps as illustrative.**

## 4. SIMD parity is achieved at runtime, not via compile flags

dnfc's library is compiled with `/arch:AVX2` (MSVC) / `-mavx2 -mfma` (GCC/Clang), and its
convolution hot path is a hand-written AVX2+FMA intrinsic kernel. A naive reading might
call this an unfair advantage. It is not, once the other three frameworks' actual SIMD
mechanism is accounted for:

| Framework / variant | SIMD mechanism | AVX2-class code executes on this machine? |
|---|---|---|
| dnfc | Compile-time `/arch:AVX2`, hand-written intrinsics (`tools/math.h`), with a portable runtime-dispatched fallback for non-AVX2 CPUs (see below) | Yes |
| Cedar (OpenCV engine) | Cedar's own code has no arch flag (SSE2 baseline); OpenCV is built with an SSE-baseline binary that **dispatches to AVX2/AVX-512 code paths at runtime via `cpuid`** (`CV_CPU_DISPATCH_COMPILE_AVX2`, `cv_cpu_helper.h`) | Yes |
| Cedar (FFTW engine) | FFTW selects SIMD codelets at runtime by default | Yes |
| cosivina-python (numba) | numba JIT-compiles via LLVM targeting the host CPU by default, auto-vectorizing to AVX2 on this machine | Yes |
| Cosivina (MATLAB) | MATLAB's bundled BLAS/conv routines use runtime-dispatched vendor kernels | Yes |

**All variants execute AVX2-class SIMD on the test machine.** dnfc's flag selects its own
hand-written kernel at compile time; the other three frameworks reach the same instruction
class through runtime dispatch (OpenCV, FFTW) or JIT host-targeting (numba, MATLAB) — a
mechanism this benchmark does not control and could not disable without patching each
framework's linked library. **Removing dnfc's `/arch:AVX2` would not equalize the
comparison — it would make dnfc the only participant running scalar code**, which is
*less* fair, not more. `/arch:AVX2` is also not a benchmark-only flag: it is dnfc's real
shipped library default (every dnf-composer executable inherits it), not a setting tuned
for this measurement.

The one genuine gap this exposes is **portability**, not fairness: dnfc's ISA selection
was compile-time-only, so an `/arch:AVX2` binary would not run on a pre-2013 (Intel) /
pre-2015 (AMD) x86-64 CPU. This has been fixed by adding runtime `cpuid` dispatch between
the existing AVX2 kernel and the existing scalar fallback (mirroring how OpenCV/FFTW
already behave), and by adding the `-mfma` flag GCC/Clang builds need alongside `-mavx2`
(MSVC's `/arch:AVX2` already implies FMA; GCC/Clang's `-mavx2` does not, which was a latent
build break given the kernel's use of `_mm256_fmadd_pd`).

## 5. Cross-framework ranking reflects framework architecture, not implementation quality

Throughput differences are driven substantially by each framework's *architectural*
design, not purely by the DFT algorithm or its numerical implementation. Cedar is a
general robotics/cognitive-architecture framework: every field-step pays a structural
tax — Qt read/write locks, `Step::onTrigger` dispatch (state checks, validity checks,
timestamp comparisons), `cv::copyMakeBorder` allocation for cyclic OpenCV convolution,
and a non-fused multi-pass Euler update — that a framework built purely for DFT
simulation does not. dnfc and Cosivina/cosivina-python are comparatively lean: a flat
loop over element handles with no locking or generic typed-data-slot indirection. This
was verified by source-level inspection of Cedar's `Step::onTrigger` /
`NeuralField::eulerStep` (see `cedar-notes.md`), not inferred from the timings alone.
**The correct claim from this benchmark is "purpose-built lean engines beat Cedar's
general-framework overhead on raw per-step throughput," not a blanket claim that any one
framework's implementation of the DFT equations is categorically better** — Cedar's
overhead is the price of generality (typed data slots, thread-safe triggers, GUI/robotics
integration) that the other frameworks don't provide.

## 6. Authorship and conflict of interest

All seven benchmark drivers — dnfc's own, and the six competitor drivers for Cedar,
Cosivina, and cosivina-python — were written by the dnfc author. dnfc is the author's own
framework and is the fastest variant in every regime of both suites. No Cedar, Cosivina,
or cosivina-python maintainer has reviewed these drivers for idiomaticity or fairness.
This is a real conflict of interest that a reader should weigh independently of the
methodology disclosed elsewhere in this document — the fairness controls in §7 describe
what was done to mitigate it, not a substitute for external review, which is invited.

## 7. Fairness controls: everything done to equalize the comparison

Set against §1, §4, and §6 above, the following measures were taken so the comparison is
as fair as a single-author benchmark can be, each independently verifiable in the driver
source:

- **Identical timed region.** All eight drivers (1D/2D × 4 frameworks) time a bare
  step-loop with no I/O, allocation, or metrics inside it.
- **Identical protocol.** 200-step discarded warmup, 5 runs, per-run reset
  (`init()`/`callReset()`), and the same two-phase memory protocol (stimulus established,
  then removed) in every driver.
- **Identical model parameters.** Field/grid sizes, τ, dt, stimulus/kernel amplitudes and
  positions, and noise amplitude (0.1, always on, so RNG cost is measured) match exactly
  across all four driver families for every regime.
- **Kernel tap-count parity.** dnfc, Cosivina, and cosivina-python share the identical
  cutoff=5 radius formula; Cedar's width-convention `limit` parameter is back-computed
  per kernel (`fairCedarLimit`) so Cedar convolves the *same number of taps* as dnfc,
  correcting for the two frameworks' different truncation-parameter conventions.
- **Activation-function parity.** All four frameworks are configured to the identical
  logistic sigmoid (β=100) for the throughput benchmark — including Cedar, whose
  `cedar.aux.math.ExpSigmoid` is selected via its own JSON config mechanism, overriding
  Cedar's factory-default `AbsSigmoid`. This is a native, stock Cedar class; no Cedar
  library code was modified. See `cross-platform-validation/README.md` for the full
  activation-function equivalence table across frameworks and the validation coverage of
  every function pair that exists in more than one framework.
- **Single-threading enforced everywhere a thread pool exists.** `cv::setNumThreads(0)`
  (Cedar/OpenCV), six pinned `*_NUM_THREADS=1` environment variables (cosivina-python),
  `maxNumCompThreads(1)` (MATLAB); dnfc has no thread pool by construction, with the same
  environment variables set defensively.
- **dnfc's own overhead was not minimized.** Its per-step state-metrics/bump-detection
  pass (`computeStateMetrics_`) is left on in the benchmark rather than disabled, so dnfc
  pays cost it did not have to.
- **Identical measurement and reporting.** Same 8-column CSV schema, same wall-clock
  steps-per-second formula, and the same median-of-5 statistic (with SD/SEM/95% CI) for
  every variant; the R analysis/figure scripts apply no per-variant filtering.

These controls establish the baseline against which §1 (precision), §4 (SIMD/build), and
§6 (authorship) should be read as the disclosed, remaining exceptions — not as evidence
the comparison was left unexamined.
