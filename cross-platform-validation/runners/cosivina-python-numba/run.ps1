# run.ps1 — cosivina-python (numba) validation runner (1D)
# Runs the cosivina-python runner with the numba JIT backend.
# Output -> data/cosivina-python-numba.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation/
python "$root\runners\cosivina_python_runner.py" numba
exit $LASTEXITCODE
