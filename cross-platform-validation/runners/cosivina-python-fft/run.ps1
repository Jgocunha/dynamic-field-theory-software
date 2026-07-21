# run.ps1 — cosivina-python (fft / spectral KernelFFT) validation runner (1D)
# Uses cosivina's KernelFFT element (NumPy-only, no numba path).
# Output -> data/cosivina-python-fft.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation/
python "$root\runners\cosivina_python_runner.py" fft
exit $LASTEXITCODE
