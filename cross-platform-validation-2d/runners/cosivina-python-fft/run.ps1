# run.ps1 — cosivina-python (fft / spectral KernelFFT) validation runner (2D)
# Uses cosivina's KernelFFT element (NumPy-only, no numba path).
# Output -> data/cosivina-python-fft.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation-2d/
python "$root\runners\cosivina_python_runner_2d.py" fft
exit $LASTEXITCODE
