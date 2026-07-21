# run.ps1 — cosivina-python (numba) validation runner (2D)
# Output -> data/cosivina-python-numba.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation-2d/
python "$root\runners\cosivina_python_runner_2d.py" numba
exit $LASTEXITCODE
