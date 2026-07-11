# run.ps1 — cosivina-python (nonumba / pure NumPy) validation runner (1D)
# Output -> data/cosivina-python-nonumba.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation/
py -3.11 "$root\runners\cosivina_python_runner.py" nonumba
exit $LASTEXITCODE
