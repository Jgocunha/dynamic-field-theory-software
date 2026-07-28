# run_2d_benchmark.ps1 — serial 2D benchmark driver (portable).
#
# Runs the full 2D matrix SERIALLY:
#   7 variants (dnfc, cedar-opencv, cedar-fftw, cpy-numba, cpy-nonumba, cpy-fft)
#   x 4 regimes (detection, selection, memory, multi-peak)
#   x 3 grids (100, 200, 500)
#   x N {5,10,50,100} x 10 runs (500 timed steps)   [cosivina MATLAB run separately]
#
# The Cedar exes ONLY run reliably when launched from PowerShell with the Cedar
# DLLs on PATH — do NOT launch them from Git Bash (they silent-exit).
#
# BEFORE RUNNING: edit the PATH VARIABLES below to match this machine, then run the
# pre-flight checks in .claude/reports/fast-pc-benchmark-handoff.md.
#
# Single-instance guard via lockdir. Appends per-cell, so a crash/reboot only loses
# the in-progress cell; re-running resumes cleanly ONLY IF you first remove any
# partial cell (see handoff doc "Resuming after interruption").
#
# Scope params (Archs/NList/GridSizes/TimedSteps/NRuns/DataDir) default to the full sweep
# above; pass narrower values (e.g. for a quick smoke test) without touching the hardcoded
# defaults.

param(
  [string[]]$Archs     = @("detection","selection","memory","multi-peak"),
  [string]  $NList     = "5,10,50,100",
  [int[]]   $GridSizes = @(100,200,500),
  [int]     $TimedSteps = 500,
  [int]     $NRuns      = 10,
  [string]  $DataDir   = "C:\dev-files\dynamic-field-theory-software\benchmarking-2d\data"
)

$ErrorActionPreference = "Continue"

# ============================ EDIT THESE FOR THIS MACHINE ============================
$ROOT   = "C:\dev-files\dynamic-field-theory-software"                                   # this repo
$CEDAR  = "C:\dev-files\cedar\bin"                                                       # cedar exes + DLLs
$DNFC   = "C:\dev-files\dynamic-neural-field-composer\dynamic-neural-field-composer\build\release\examples\Release"  # dnfc exes (VS generator)

# Cedar runtime DLL dirs (Qt, OpenCV, QGLViewer, GLEW, Boost, cedar\bin, + fftw3.dll dir).
# A missing DLL => the exe silent-exits or errors 0xC0000135. Adjust each to this machine.
$CEDAR_DLL_PATHS = @(
  "C:\dev-files\Qt\5.15.0\msvc2019_64\bin",
  "C:\dev-files\opencv\opencv-build\bin\Release",
  "C:\dev-files\libQGLViewer\build\Release",
  "C:\dev-files\glew-2.3.1-win32\glew-2.3.1\bin\Release\x64",
  "C:\dev-files\boost_1_82_0\lib64-msvc-14.3",
  $CEDAR,
  "C:\dev-files\vcpkg\installed\x64-windows\bin"    # fftw3.dll lives here (needed for the fftw variant)
)

$PY = "python"   # python launcher for cosivina-python (numba + nonumba)
# ====================================================================================

$LOCK = Join-Path $PSScriptRoot "run_2d.lockd"
if (Test-Path $LOCK) { Write-Output "LOCKDIR EXISTS ($LOCK) — another run is active. Aborting."; exit 9 }
New-Item -ItemType Directory -Path $LOCK | Out-Null
Write-Output "ACQUIRED LOCK pid $PID  ($(Get-Date))"
try {
  $env:PATH = ($CEDAR_DLL_PATHS -join ";") + ";" + $env:PATH

  # dnfc has no thread pool by construction (see TRADE_OFF_CAVEATS.md §7), so this is
  # defensive rather than load-bearing; set for parity with the other three variants'
  # explicit single-thread pins.
  $env:OMP_NUM_THREADS = "1"
  $env:MKL_NUM_THREADS = "1"

  $CPY2D = "$ROOT\benchmarking-2d\runners\cosivina_python_benchmark_2d.py"
  $D2    = $DataDir
  $ARCHS = $Archs
  $NCSV  = $NList

  Write-Output "===== 2D SERIAL ($TimedSteps steps / $NRuns runs, grids $($GridSizes -join ',')) ====="
  foreach ($g in $GridSizes) {
    foreach ($a in $ARCHS) {
      Write-Output "----- grid=$g arch=$a  ($(Get-Date)) -----"
      & "$DNFC\benchmark_headless_2d.exe" "$D2\timings-dnfc-2d.csv"  $a $NCSV $g $TimedSteps $NRuns
      & "$CEDAR\benchmark_2d.exe"         "$D2\timings-cedar-2d.csv" $a opencv $NCSV $g $TimedSteps $NRuns
      & "$CEDAR\benchmark_2d.exe"         "$D2\timings-cedar-2d.csv" $a fftw   $NCSV $g $TimedSteps $NRuns
      & python "$CPY2D" $a numba   $NCSV $g "$D2\timings-cosivina-python-2d.csv" $TimedSteps $NRuns
      & python "$CPY2D" $a nonumba $NCSV $g "$D2\timings-cosivina-python-2d.csv" $TimedSteps $NRuns
      & python "$CPY2D" $a fft     $NCSV $g "$D2\timings-cosivina-python-2d.csv" $TimedSteps $NRuns
    }
  }
  Write-Output "===== ALLDONE2D  ($(Get-Date)) ====="
}
finally {
  Remove-Item $LOCK -Recurse -Force -ErrorAction SilentlyContinue
}
