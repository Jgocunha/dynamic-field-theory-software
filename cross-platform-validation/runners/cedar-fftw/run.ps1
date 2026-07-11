# run.ps1 — cedar-fftw validation runner (1D)
# Runs the Cedar validation exe over simulations/cedar-fftw -> data/cedar-fftw.
# The FFTW convolution engine is baked into each JSON; requires Cedar built with
# CEDAR_USE_FFTW=ON and fftw3.dll on PATH.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation/
$exe  = "C:\dev-files\cedar\bin\cross_platform_validation.exe"

$dlls = @(
  "C:\Qt\5.15.1\msvc2019_64\bin",
  "C:\dev-files\opencv\opencv-build\bin\Release",
  "C:\dev-files\libQGLViewer\build\Release",
  "C:\dev-files\glew-2.3.1\bin\Release\x64",
  "C:\dev-files\boost_1_82_0\lib64-msvc-14.3",
  "C:\dev-files\cedar\bin",
  "C:\dev-files\vcpkg\installed\x64-windows\bin"   # fftw3.dll
)
$env:PATH = ($dlls -join ";") + ";" + $env:PATH

& $exe "$root\simulations\cedar-fftw" "$root\data\cedar-fftw"
exit $LASTEXITCODE
