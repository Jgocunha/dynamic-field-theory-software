# run_validation_and_benchmark.ps1 — fully sequential, single-session re-run of
# EVERYTHING: cross-platform-validation (1D+2D) + benchmarking (1D+2D), all 8
# variants including Cosivina (MATLAB) and Cosivina-fft (MATLAB, spectral
# KernelFFT), one executable at a time. Nothing in this script runs concurrently
# with anything else in it, to eliminate any cross-process contention between
# variants. It does NOT control what else is running on the machine — close
# other heavy apps (other Claude Code windows, VSCode instances, etc.) before
# launching this.
#
# Estimated total runtime: ~38-41h+ (dominated by the 2D benchmark matrix, ~36h
# for the six non-MATLAB variants alone; cosivina-fft benchmark adds more on top).
#
# Run from PowerShell (not Git Bash — the Cedar exes silent-exit under Git Bash).

$ErrorActionPreference = "Continue"
$ROOT     = "C:\dev-files\dynamic-field-theory-software"
$MATLAB   = "C:\Program Files\MATLAB\R2024b\bin\matlab.exe"
$COSIVINA = "C:/dev-files/cosivina"
$log      = "$ROOT\.claude\temp\full-rerun-with-matlab.log"

function Log($msg) {
    $msg | Tee-Object -FilePath $log -Append
}

New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
"===== FULL RERUN (incl. MATLAB) START $(Get-Date) =====" | Out-File -FilePath $log -Encoding utf8

# ---------------------------------------------------------------------------
# Step 0: truncate the 8 append-mode benchmark CSVs so this run starts clean
# (they are appended to, not overwritten). Validation outputs are overwritten
# by filename (sim_NNN_*.csv), so they need no truncation. Any pre-existing
# data is backed up to .claude/backups/ — NOT alongside the CSV — to keep the
# data/ folders free of .bak clutter.
# ---------------------------------------------------------------------------
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = "$ROOT\.claude\backups\benchmark-data"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$benchCsvs = @(
  "$ROOT\benchmarking\data\timings-dnfc.csv",
  "$ROOT\benchmarking\data\timings-cedar.csv",
  "$ROOT\benchmarking\data\timings-cosivina-python.csv",
  "$ROOT\benchmarking\data\timings-cosivina.csv",
  "$ROOT\benchmarking-2d\data\timings-dnfc-2d.csv",
  "$ROOT\benchmarking-2d\data\timings-cedar-2d.csv",
  "$ROOT\benchmarking-2d\data\timings-cosivina-python-2d.csv",
  "$ROOT\benchmarking-2d\data\timings-cosivina-2d.csv"
)
foreach ($f in $benchCsvs) {
  if (Test-Path $f) {
    if ((Get-Item $f).Length -gt 0) {
      Copy-Item $f (Join-Path $backupDir ((Split-Path $f -Leaf) + ".bak-full-rerun-$ts"))
    }
    Clear-Content $f
  }
}
Log "Truncated $($benchCsvs.Count) benchmark CSVs (non-empty ones backed up to $backupDir)"

# ---------------------------------------------------------------------------
# Step 1: 1D cross-platform-validation
# ---------------------------------------------------------------------------
Log "----- 1D validation: dnfc, cedar-opencv, cedar-fftw, cosivina-python x3  ($(Get-Date)) -----"
Push-Location "$ROOT\cross-platform-validation"
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\dnfc\run.ps1"                    *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cedar-opencv\run.ps1"            *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cedar-fftw\run.ps1"              *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-numba\run.ps1"   *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-nonumba\run.ps1" *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-fft\run.ps1"     *>> $log
Pop-Location

Log "----- 1D validation: cosivina (MATLAB)  ($(Get-Date)) -----"
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/cross-platform-validation'); run('runners/cosivina_runner.m')" *>> $log

Log "----- 1D validation: cosivina-fft (MATLAB)  ($(Get-Date)) -----"
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/cross-platform-validation'); run('runners/cosivina_fft_runner.m')" *>> $log

# ---------------------------------------------------------------------------
# Step 2: 2D cross-platform-validation
# ---------------------------------------------------------------------------
Log "----- 2D validation: dnfc, cedar-opencv, cedar-fftw, cosivina-python x3  ($(Get-Date)) -----"
Push-Location "$ROOT\cross-platform-validation-2d"
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\dnfc\run.ps1"                    *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cedar-opencv\run.ps1"            *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cedar-fftw\run.ps1"              *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-numba\run.ps1"   *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-nonumba\run.ps1" *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-fft\run.ps1"     *>> $log
Pop-Location

Log "----- 2D validation: cosivina (MATLAB)  ($(Get-Date)) -----"
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/cross-platform-validation-2d'); run('runners/cosivina_runner_2d.m')" *>> $log

Log "----- 2D validation: cosivina-fft (MATLAB)  ($(Get-Date)) -----"
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/cross-platform-validation-2d'); run('runners/cosivina_fft_runner_2d.m')" *>> $log

# ---------------------------------------------------------------------------
# Step 3: 1D benchmark (run_1d_benchmark.ps1 already runs its 6 non-MATLAB
# variants strictly serially internally)
# ---------------------------------------------------------------------------
Log "----- 1D benchmark: dnfc, cedar x2, cosivina-python x3  ($(Get-Date)) -----"
& "$ROOT\benchmarking\runners\run_1d_benchmark.ps1" *>> $log

Log "----- 1D benchmark: cosivina (MATLAB)  ($(Get-Date)) -----"
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking'); run('runners/cosivina_benchmark.m')" *>> $log

Log "----- 1D benchmark: cosivina-fft (MATLAB)  ($(Get-Date)) -----"
& $MATLAB -batch "VARIANT='fft'; addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking'); run('runners/cosivina_benchmark.m')" *>> $log

# ---------------------------------------------------------------------------
# Step 4: 2D benchmark
# ---------------------------------------------------------------------------
Log "----- 2D benchmark: dnfc, cedar x2, cosivina-python x3  ($(Get-Date)) -----"
& "$ROOT\benchmarking-2d\runners\run_2d_benchmark.ps1" *>> $log

Log "----- 2D benchmark: cosivina (MATLAB)  ($(Get-Date)) -----"
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking-2d'); run('runners/cosivina_benchmark_2d.m')" *>> $log

Log "----- 2D benchmark: cosivina-fft (MATLAB)  ($(Get-Date)) -----"
& $MATLAB -batch "VARIANT='fft'; addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking-2d'); run('runners/cosivina_benchmark_2d.m')" *>> $log

Log "===== FULL RERUN (incl. MATLAB) COMPLETE $(Get-Date) ====="
