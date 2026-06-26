# run.ps1 — dnfc validation runner (2D)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation-2d/
$exe  = "C:\dev-files\dynamic-neural-field-composer\dynamic-neural-field-composer\build\release\examples\cross_platform_validation_runner_2d.exe"

& $exe "$root\simulations\dnfc" "$root\data\dnfc"
exit $LASTEXITCODE
