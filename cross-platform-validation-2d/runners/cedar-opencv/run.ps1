# run.ps1 — cedar-opencv validation runner (2D)
# Runs the Cedar 2D validation exe over simulations/cedar-opencv -> data/cedar-opencv.

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."        # cross-platform-validation-2d/
$exe  = "C:\dev-files\cedar\bin\cross_platform_validation_2d.exe"

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
