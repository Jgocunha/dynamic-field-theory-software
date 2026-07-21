# run_1d_benchmark.ps1 — serial 1D benchmark driver (portable).
#
# Runs the full 1D matrix SERIALLY:
#   7 variants (dnfc, cedar-opencv, cedar-fftw, cpy-numba, cpy-nonumba, cpy-fft)
#   x 4 regimes (detection, selection, memory, multi-peak)
#   x 2 field sizes (100, 500)
#   x N {5,10,50,100} x 5 runs (2000 timed steps)   [cosivina MATLAB run separately]
#
# See the sibling 2D driver (benchmarking-2d/runners/run_2d_benchmark.ps1) and the handoff
# doc (.claude/reports/fast-pc-benchmark-handoff.md). Same conventions: Cedar exes MUST run
# from PowerShell (silent-exit under Git Bash); single-instance lockdir; appends per-cell.
#
# BEFORE RUNNING: edit the PATH VARIABLES below, run the pre-flight checks in the handoff doc.

$ErrorActionPreference = "Continue"

# ============================ EDIT THESE FOR THIS MACHINE ============================
$ROOT   = "C:\dev-files\dynamic-field-theory-software"                                   # this repo
$CEDAR  = "C:\dev-files\cedar\bin"                                                       # cedar exes + DLLs
$DNFC   = "C:\dev-files\dynamic-neural-field-composer\dynamic-neural-field-composer\build\release\examples\Release"  # dnfc exes (VS generator)

$CEDAR_DLL_PATHS = @(
  "C:\dev-files\Qt\5.15.0\msvc2019_64\bin",
  "C:\dev-files\opencv\opencv-build\bin\Release",
  "C:\dev-files\libQGLViewer\build\Release",
  "C:\dev-files\glew-2.3.1-win32\glew-2.3.1\bin\Release\x64",
  "C:\dev-files\boost_1_82_0\lib64-msvc-14.3",
  $CEDAR,
  "C:\dev-files\vcpkg\installed\x64-windows\bin"    # fftw3.dll (needed for the fftw variant)
)
# ====================================================================================

$LOCK = Join-Path $PSScriptRoot "run_1d.lockd"
if (Test-Path $LOCK) { Write-Output "LOCKDIR EXISTS ($LOCK) — another run is active. Aborting."; exit 9 }
New-Item -ItemType Directory -Path $LOCK | Out-Null
Write-Output "ACQUIRED LOCK pid $PID  ($(Get-Date))"
try {
  $env:PATH = ($CEDAR_DLL_PATHS -join ";") + ";" + $env:PATH

  $CPY1D = "$ROOT\benchmarking\runners\cosivina_python_benchmark.py"
  $D1    = "$ROOT\benchmarking\data"
  $ARCHS = @("detection","selection","memory","multi-peak")
  $NCSV  = "5,10,50,100"

  Write-Output "===== 1D SERIAL (2000 steps / 5 runs, field sizes 100,500) ====="
  foreach ($fs in 100,500) {
    foreach ($a in $ARCHS) {
      Write-Output "----- fs=$fs arch=$a  ($(Get-Date)) -----"
      & "$DNFC\benchmark_headless.exe" "$D1\timings-dnfc.csv"   $a $NCSV $fs
      & "$CEDAR\benchmark.exe"         "$D1\timings-cedar.csv"  $a opencv $NCSV $fs
      & "$CEDAR\benchmark.exe"         "$D1\timings-cedar.csv"  $a fftw   $NCSV $fs
      & python "$CPY1D" $a numba   $NCSV $fs
      & python "$CPY1D" $a nonumba $NCSV $fs
      & python "$CPY1D" $a fft     $NCSV $fs
    }
  }
  Write-Output "===== ALLDONE1D  ($(Get-Date)) ====="
}
finally {
  Remove-Item $LOCK -Recurse -Force -ErrorAction SilentlyContinue
}
