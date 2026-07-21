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
| dnfc                     | Direct spatial convolution (truncated kernel)   |
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
  field-size sweep (§4) is designed to expose this. Because dnfc, both Cosivina variants, and the two
  spatial cosivina-python variants are all spatial at the *identical* truncated tap count (§1 of
  `benchmarking/README.md`), the dnfc-vs-Cosivina / dnfc-vs-cosivina-python(numba/nonumba) comparison
  is like-for-like — same algorithm, same kernel support — not a spatial-vs-spectral confound. The
  cosivina-python-fft variant additionally provides a *float64* spectral data point (the
  cross-platform-validation study confirms it is numerically equivalent to the spatial variants, so
  the FFT is a genuine throughput alternative, not a different computation).
- **Spectral requires kernel ≤ field.** Cyclic FFT convolution zero-pads the
  kernel to the field length; a kernel wider than the field aliases onto itself and
  Cedar's FFTW engine throws. This is why the smallest field sizes are bounded below by
  the widest kernel (§2, §4) — it is a real constraint of spectral convolution, not a
  tuning choice. The OpenCV (spatial) engine has no such constraint. (cosivina-python-fft's
  `KernelFFT` builds the kernel at the full field size by construction, so it never trips this,
  but it convolves the full untruncated kernel — the reason it is a distinct convolution method.)

## 3. Single machine; absolute numbers are not portable

All measurements come from one CPU on an otherwise-idle machine, single-threaded (each
runner pins its math-library thread pools to 1; see the Test Machine table). Results
depend on this specific CPU, its boost/thermal state, and the linked BLAS/FFT backend
(NumPy/numba → the installed NumPy BLAS; MATLAB → its bundled libraries; Cedar/dnfc →
MSVC + AVX2). Five runs per cell (`analysis.R`/`analysis_2d.R` report median, SD, SEM,
and a 95% CI per cell) quantify short-timescale run-to-run noise *on this machine*, not
the generality of the result across hardware. **The cross-framework ratios are the
finding; treat absolute sps as illustrative.**


## 4. Cross-framework ranking reflects framework architecture, not implementation quality

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