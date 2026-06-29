# Trade-off Caveats

This is an honest, single-machine micro-benchmark. The cross-framework throughput
*ratios* are the portable result; absolute steps-per-second are machine-specific.
Every methodological choice below is disclosed so a reader can judge the comparison
on its own terms. The same caveats apply to the 1D and 2D suites.

## 1. Numerical precision is not equalized (float32 vs float64)

Cedar computes in **float32**; dnfc, Cosivina, and cosivina-python compute in
**float64**. Throughput is measured per *step*, not per FLOP or per bit. float32
halves memory traffic and doubles SIMD lane width, so Cedar's raw step rate carries
an intrinsic precision advantage that the other frameworks do not get.

This is a property of the frameworks as shipped — Cedar's field engine is float32 and
cannot be switched to float64 without modifying the library — so we report
*as-shipped default-precision throughput* rather than an architecture-normalized
figure. **Any Cedar-vs-(dnfc/Cosivina/cosivina-python) comparison should be read with
this precision difference in mind**; it flatters Cedar's numbers and is not removed by
our protocol. Same-precision comparisons (Cedar-OpenCV vs Cedar-FFTW; or
dnfc vs Cosivina vs cosivina-python) are not affected.

## 2. Convolution method differs by framework — and that is the point

Throughput differences partly reflect *how* each framework convolves, which is an
intrinsic property of the framework, not a confound:

| Framework / variant      | Convolution method                              |
|--------------------------|-------------------------------------------------|
| dnfc                     | Direct spatial convolution (truncated kernel)   |
| Cedar (OpenCV engine)    | Direct spatial convolution (`cv::filter2D`, zero-pad + wrap) |
| Cedar (FFTW engine)      | Spectral: FFT × FFT → inverse FFT (cyclic)      |
| Cosivina (MATLAB)        | FFT-based convolution                            |
| cosivina-python (numba)  | FFT-based convolution, numba-JIT host code      |
| cosivina-python (nonumba)| FFT-based convolution, pure NumPy               |

These are reported as a framework characteristic, not normalized away. Two important
structural facts follow:

- **Spatial vs spectral has a field-size cross-over.** Direct convolution cost grows
  with (kernel width × field size); spectral cost grows with (field size × log field
  size) independent of kernel width. So FFT-based engines pull ahead on convolution-
  heavy regimes (wide Mexican-hat) and large fields, while spatial engines can win on
  narrow kernels / small fields. The field-size sweep (§4) is designed to expose this.
- **Spectral (FFTW) requires kernel ≤ field.** Cyclic FFT convolution zero-pads the
  kernel to the field length; a kernel wider than the field aliases onto itself and
  Cedar's FFTW engine throws. This is why the smallest field sizes are bounded below by
  the widest kernel (§2, §4) — it is a real constraint of spectral convolution, not a
  tuning choice. The OpenCV (spatial) engine has no such constraint.

## 3. Single machine; absolute numbers are not portable

All measurements come from one CPU in one back-to-back session on an otherwise-idle
machine, single-threaded (each runner pins its math-library thread pools to 1; see the
Test Machine table). Results depend on this specific CPU, its boost/thermal state, and
the linked BLAS/FFT backend (NumPy/numba → the installed NumPy BLAS; MATLAB → its
bundled libraries; Cedar/dnfc → MSVC + AVX2). Ten runs per cell quantify run-to-run
noise *on this machine*, not the generality of the result across hardware. **Report the
cross-framework ratios as the finding; treat absolute sps as illustrative.**