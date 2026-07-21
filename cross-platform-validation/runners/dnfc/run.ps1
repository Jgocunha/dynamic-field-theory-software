# run.ps1 — dnfc validation runner (1D)
# Runs the dnfc validation exe over simulations/dnfc -> data/dnfc.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation/
$exe  = "C:\dev-files\dynamic-neural-field-composer\dynamic-neural-field-composer\build\release\examples\Release\cross_platform_validation_runner.exe"

& $exe "$root\simulations\dnfc" "$root\data\dnfc"
exit $LASTEXITCODE
