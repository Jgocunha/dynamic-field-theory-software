# run.ps1 — cosivina-python (nonumba / pure NumPy) validation runner (2D)
# Output -> data/cosivina-python-nonumba.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation-2d/
py -3.11 "$root\runners\cosivina_python_runner_2d.py" nonumba
exit $LASTEXITCODE
