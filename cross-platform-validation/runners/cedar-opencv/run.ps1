# run.ps1 — cedar-opencv validation runner (1D)
# Runs the Cedar validation exe over simulations/cedar-opencv -> data/cedar-opencv.
# The OpenCV convolution engine is baked into each JSON by generate_simulations.py.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation/
$exe  = "C:\dev-files\cedar\bin\cross_platform_validation.exe"

# Cedar runtime DLLs (Qt, OpenCV, QGLViewer, GLEW, Boost, Cedar).
$dlls = @(
  "C:\Qt\5.15.1\msvc2019_64\bin",
  "C:\dev-files\opencv\opencv-build\bin\Release",
  "C:\dev-files\libQGLViewer\build\Release",
  "C:\dev-files\glew-2.3.1\bin\Release\x64",
  "C:\dev-files\boost_1_82_0\lib64-msvc-14.3",
  "C:\dev-files\cedar\bin"
)
$env:PATH = ($dlls -join ";") + ";" + $env:PATH

& $exe "$root\simulations\cedar-opencv" "$root\data\cedar-opencv"
exit $LASTEXITCODE
