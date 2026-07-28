# run_validation_and_benchmark.ps1 — fully sequential, single-session re-run of
# EVERYTHING: cross-platform-validation (1D+2D) + benchmarking (1D+2D), all 8
# variants including Cosivina (MATLAB) and Cosivina-fft (MATLAB, spectral
# KernelFFT), one executable at a time. Nothing in this script runs concurrently
# with anything else in it, to eliminate any cross-process contention between
# variants. It does NOT control what else is running on the machine — close
# other heavy apps (other Claude Code windows, VSCode instances, etc.) before
# launching this.
#
# Estimated total runtime: ≈170h / 7.1 days (protocol is 500 timed steps x 10 runs;
# 1D field sizes {100,500,1000}, 2D grid sizes {100,200,500}). Dominated by the 2D
# benchmark matrix, ~133h for the six non-MATLAB variants alone, of which grid=500 is
# the large majority: a pre-flight spot-check measured grid=500 costing 8.23x grid=200
# (not the 6.25x pure grid^2 scaling would predict — likely cache/bandwidth pressure),
# so the phase table below applies that measured factor rather than naive area scaling.
# See the phase table below for the per-phase breakdown.
#
# Run from PowerShell (not Git Bash — the Cedar exes silent-exit under Git Bash).
#
# -QuickTest: exercises all 32 validation/benchmark invocations at a tiny scope
# (arch=detection, N=5, one size) to smoke-test the whole pipeline in minutes
# instead of days. Benchmarks write to scratch CSVs under .claude/temp/smoke/,
# never to the real data/ CSVs; validation still runs at full scope to its
# normal location (it's only ~5 min total). Skips the destructive Step 0.

param(
  [switch]$QuickTest
)

$ErrorActionPreference = "Continue"
$ROOT     = "C:\dev-files\dynamic-field-theory-software"
$MATLAB   = "C:\Program Files\MATLAB\R2024b\bin\matlab.exe"
$COSIVINA = "C:/dev-files/cosivina"
$log      = "$ROOT\.claude\temp\full-rerun-with-matlab.log"

function Log($msg) {
    $msg | Tee-Object -FilePath $log -Append
}

New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$bannerSuffix = if ($QuickTest) { " [QUICK TEST]" } else { "" }
"===== FULL RERUN (incl. MATLAB) START$bannerSuffix $(Get-Date) =====" | Out-File -FilePath $log -Encoding utf8

# ---------------------------------------------------------------------------
# Phase table + ETA machinery. Baselines are the original measured 2000-step/5-run,
# {100,500}/{100,200}-size logged runs (.claude/temp/full-rerun-with-matlab.log,
# .claude/temp/full-rerun-benchmark.log), rescaled to the current 500-step/10-run,
# {100,500,1000}/{100,200,500}-size protocol:
#   1D benchmark phases  x1.414  (Sigma-field-size ratio 2.667x, x0.53 protocol saving)
#   2D benchmark phases  x4.020  (grid=100/200 shares x0.53 protocol saving, grid=500
#                                 share added at the MEASURED 8.23x-vs-grid=200 cost —
#                                 not naive 6.25x grid^2 scaling — also x0.53)
# Validation phases are unchanged (validation sims are fixed-size, independent of the
# benchmark sweep). The two cosivina 2D benchmark rows were already the least-certain
# estimates before rescaling (never completed in a logged run) and now also carry the
# rescaling uncertainty on top. Used purely for progress/ETA reporting — it does not
# gate or alter execution.
# ---------------------------------------------------------------------------
$phaseTable = [ordered]@{
  "1D validation, 6 non-MATLAB" = 35
  "1D validation, cosivina"     = 8
  "1D validation, cosivina-fft" = 8
  "2D validation, 6 non-MATLAB" = 213
  "2D validation, cosivina"     = 16
  "2D validation, cosivina-fft" = 16
  "1D benchmark, 6 non-MATLAB"  = 3011
  "1D benchmark, cosivina"      = 370
  "1D benchmark, cosivina-fft"  = 370
  "2D benchmark, 6 non-MATLAB"  = 477832
  "2D benchmark, cosivina"      = 100970
  "2D benchmark, cosivina-fft"  = 30146
}
$totalEstimateSeconds      = ($phaseTable.Values | Measure-Object -Sum).Sum
$cumulativeEstimateSeconds = 0.0
$cumulativeActualSeconds   = 0.0

function Format-Duration($seconds) {
    $ts = [TimeSpan]::FromSeconds([Math]::Max(0, $seconds))
    "{0}h {1}m" -f [int]$ts.TotalHours, $ts.Minutes
}

function Start-Phase {
    [Diagnostics.Stopwatch]::StartNew()
}

function Complete-Phase($phaseName, $sw) {
    $sw.Stop()
    $elapsed = $sw.Elapsed.TotalSeconds
    $script:cumulativeActualSeconds   += $elapsed
    $script:cumulativeEstimateSeconds += $phaseTable[$phaseName]

    # Only trust the actual/estimate correction factor once completed phases
    # cover a meaningful share of the total estimate — otherwise the tiny
    # validation phases produce a wild factor. Below that, use raw estimates.
    $progressFrac = $script:cumulativeEstimateSeconds / $totalEstimateSeconds
    if ($progressFrac -gt 0.05) {
        $factor = $script:cumulativeActualSeconds / $script:cumulativeEstimateSeconds
    } else {
        $factor = 1.0
    }
    $remainingRaw       = $totalEstimateSeconds - $script:cumulativeEstimateSeconds
    $remainingCorrected = $remainingRaw * $factor
    $eta                = (Get-Date).AddSeconds($remainingCorrected)

    Log ("  [$phaseName] elapsed=$(Format-Duration $elapsed)  cumulative=$(Format-Duration $script:cumulativeActualSeconds)  remaining~$(Format-Duration $remainingCorrected) -> ETA ~$($eta.ToString('ddd dd MMM HH:mm'))")
}

Log "Total estimate: $(Format-Duration $totalEstimateSeconds) ($totalEstimateSeconds s) -> projected finish ~$((Get-Date).AddSeconds($totalEstimateSeconds).ToString('ddd dd MMM HH:mm')) if the run started now"
Log "NOTE: the last two phases (2D benchmark cosivina / cosivina-fft) are the least-certain estimates -- neither has ever completed in a logged run, and both now also carry the rescaling uncertainty below. The dnfc baseline predates its ~20% 2D speedup, which should pull the total slightly under estimate."
Log "NOTE: grid=500 has never been run end-to-end at any N. Its 8.23x-vs-grid=200 cost factor was measured on ONE variant (dnfc) at N=10 only -- N=100 holds far more resident memory simultaneously and could scale worse; MATLAB/Python variants were not spot-checked at all. Treat the 2D benchmark estimate as wider than +/-30%."

# ---------------------------------------------------------------------------
# Step 0: truncate the 8 append-mode benchmark CSVs so this run starts clean
# (they are appended to, not overwritten). Validation outputs are usually
# overwritten by filename (sim_NNN_*.csv), but output for any sim that fails
# or is skipped survives as stale data, so the 16 validation data dirs are
# cleared too. Any pre-existing data is backed up to .claude/backups/ — NOT
# alongside the CSV — to keep the data/ folders free of .bak clutter.
#
# Skipped entirely under -QuickTest: benchmarks there write to scratch CSVs,
# never the real ones, and validation output is fine to run into whatever
# is already on disk (it's overwritten by filename anyway).
# ---------------------------------------------------------------------------
if (-not $QuickTest) {
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

  $validationDirs = @(
    "$ROOT\cross-platform-validation\data\dnfc",
    "$ROOT\cross-platform-validation\data\cedar-opencv",
    "$ROOT\cross-platform-validation\data\cedar-fftw",
    "$ROOT\cross-platform-validation\data\cosivina",
    "$ROOT\cross-platform-validation\data\cosivina-fft",
    "$ROOT\cross-platform-validation\data\cosivina-python-numba",
    "$ROOT\cross-platform-validation\data\cosivina-python-nonumba",
    "$ROOT\cross-platform-validation\data\cosivina-python-fft",
    "$ROOT\cross-platform-validation-2d\data\dnfc",
    "$ROOT\cross-platform-validation-2d\data\cedar-opencv",
    "$ROOT\cross-platform-validation-2d\data\cedar-fftw",
    "$ROOT\cross-platform-validation-2d\data\cosivina",
    "$ROOT\cross-platform-validation-2d\data\cosivina-fft",
    "$ROOT\cross-platform-validation-2d\data\cosivina-python-numba",
    "$ROOT\cross-platform-validation-2d\data\cosivina-python-nonumba",
    "$ROOT\cross-platform-validation-2d\data\cosivina-python-fft"
  )
  $clearedCount = 0
  foreach ($d in $validationDirs) {
    if (Test-Path $d) {
      $files = Get-ChildItem -Path $d -File -Force
      foreach ($f in $files) { Remove-Item -LiteralPath $f.FullName -Force }
      $clearedCount += $files.Count
    }
  }
  Log "Cleared $clearedCount stale files from $($validationDirs.Count) validation data dirs"
} else {
  Log "QUICK TEST: skipping destructive Step 0 (no truncation, no clearing)"
}

# ---------------------------------------------------------------------------
# Quick-test scope: arch=detection only, N=5, one size, scratch output dirs.
# ---------------------------------------------------------------------------
if ($QuickTest) {
  $smokeDir = "$ROOT\.claude\temp\smoke"
  $smoke1D  = "$smokeDir\1d"
  $smoke2D  = "$smokeDir\2d"
  New-Item -ItemType Directory -Force -Path $smoke1D | Out-Null
  New-Item -ItemType Directory -Force -Path $smoke2D | Out-Null
  $smoke1DM = $smoke1D -replace '\\','/'   # forward slashes for MATLAB string literals
  $smoke2DM = $smoke2D -replace '\\','/'
  Log "QUICK TEST: scope = arch detection, N=5, 1D field=100 / 2D grid=100; scratch output under $smokeDir"
}

# ---------------------------------------------------------------------------
# Step 1: 1D cross-platform-validation
# ---------------------------------------------------------------------------
Log "----- 1D validation: dnfc, cedar-opencv, cedar-fftw, cosivina-python x3  ($(Get-Date)) -----"
$sw = Start-Phase
Push-Location "$ROOT\cross-platform-validation"
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\dnfc\run.ps1"                    *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cedar-opencv\run.ps1"            *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cedar-fftw\run.ps1"              *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-numba\run.ps1"   *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-nonumba\run.ps1" *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-fft\run.ps1"     *>> $log
Pop-Location
Complete-Phase "1D validation, 6 non-MATLAB" $sw

Log "----- 1D validation: cosivina (MATLAB)  ($(Get-Date)) -----"
$sw = Start-Phase
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/cross-platform-validation'); run('runners/cosivina_runner.m')" *>> $log
Complete-Phase "1D validation, cosivina" $sw

Log "----- 1D validation: cosivina-fft (MATLAB)  ($(Get-Date)) -----"
$sw = Start-Phase
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/cross-platform-validation'); run('runners/cosivina_fft_runner.m')" *>> $log
Complete-Phase "1D validation, cosivina-fft" $sw

# ---------------------------------------------------------------------------
# Step 2: 2D cross-platform-validation
# ---------------------------------------------------------------------------
Log "----- 2D validation: dnfc, cedar-opencv, cedar-fftw, cosivina-python x3  ($(Get-Date)) -----"
$sw = Start-Phase
Push-Location "$ROOT\cross-platform-validation-2d"
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\dnfc\run.ps1"                    *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cedar-opencv\run.ps1"            *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cedar-fftw\run.ps1"              *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-numba\run.ps1"   *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-nonumba\run.ps1" *>> $log
& powershell -NoProfile -ExecutionPolicy Bypass -File "runners\cosivina-python-fft\run.ps1"     *>> $log
Pop-Location
Complete-Phase "2D validation, 6 non-MATLAB" $sw

Log "----- 2D validation: cosivina (MATLAB)  ($(Get-Date)) -----"
$sw = Start-Phase
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/cross-platform-validation-2d'); run('runners/cosivina_runner_2d.m')" *>> $log
Complete-Phase "2D validation, cosivina" $sw

Log "----- 2D validation: cosivina-fft (MATLAB)  ($(Get-Date)) -----"
$sw = Start-Phase
& $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/cross-platform-validation-2d'); run('runners/cosivina_fft_runner_2d.m')" *>> $log
Complete-Phase "2D validation, cosivina-fft" $sw

# ---------------------------------------------------------------------------
# Step 3: 1D benchmark (run_1d_benchmark.ps1 already runs its 6 non-MATLAB
# variants strictly serially internally)
# ---------------------------------------------------------------------------
Log "----- 1D benchmark: dnfc, cedar x2, cosivina-python x3  ($(Get-Date)) -----"
$sw = Start-Phase
if ($QuickTest) {
  & "$ROOT\benchmarking\runners\run_1d_benchmark.ps1" -Archs @("detection") -NList "5" -FieldSizes @(100) -DataDir $smoke1D *>> $log
} else {
  & "$ROOT\benchmarking\runners\run_1d_benchmark.ps1" *>> $log
}
Complete-Phase "1D benchmark, 6 non-MATLAB" $sw

Log "----- 1D benchmark: cosivina (MATLAB)  ($(Get-Date)) -----"
$sw = Start-Phase
if ($QuickTest) {
  & $MATLAB -batch "ARCH_LIST={'detection'}; ARCH_N=[5]; FIELD_SIZES=[100]; OUTPUT_FILE='$smoke1DM/timings-cosivina.csv'; addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking'); run('runners/cosivina_benchmark.m')" *>> $log
} else {
  & $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking'); run('runners/cosivina_benchmark.m')" *>> $log
}
Complete-Phase "1D benchmark, cosivina" $sw

Log "----- 1D benchmark: cosivina-fft (MATLAB)  ($(Get-Date)) -----"
$sw = Start-Phase
if ($QuickTest) {
  & $MATLAB -batch "VARIANT='fft'; ARCH_LIST={'detection'}; ARCH_N=[5]; FIELD_SIZES=[100]; OUTPUT_FILE='$smoke1DM/timings-cosivina.csv'; addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking'); run('runners/cosivina_benchmark.m')" *>> $log
} else {
  & $MATLAB -batch "VARIANT='fft'; addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking'); run('runners/cosivina_benchmark.m')" *>> $log
}
Complete-Phase "1D benchmark, cosivina-fft" $sw

# ---------------------------------------------------------------------------
# Step 4: 2D benchmark
# ---------------------------------------------------------------------------
Log "----- 2D benchmark: dnfc, cedar x2, cosivina-python x3  ($(Get-Date)) -----"
$sw = Start-Phase
if ($QuickTest) {
  & "$ROOT\benchmarking-2d\runners\run_2d_benchmark.ps1" -Archs @("detection") -NList "5" -GridSizes @(100) -DataDir $smoke2D *>> $log
} else {
  & "$ROOT\benchmarking-2d\runners\run_2d_benchmark.ps1" *>> $log
}
Complete-Phase "2D benchmark, 6 non-MATLAB" $sw

Log "----- 2D benchmark: cosivina (MATLAB)  ($(Get-Date)) -----"
$sw = Start-Phase
if ($QuickTest) {
  & $MATLAB -batch "ARCH_LIST={'detection'}; ARCH_N=[5]; GRID_SIZES=[100]; OUTPUT_FILE='$smoke2DM/timings-cosivina-2d.csv'; addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking-2d'); run('runners/cosivina_benchmark_2d.m')" *>> $log
} else {
  & $MATLAB -batch "addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking-2d'); run('runners/cosivina_benchmark_2d.m')" *>> $log
}
Complete-Phase "2D benchmark, cosivina" $sw

Log "----- 2D benchmark: cosivina-fft (MATLAB)  ($(Get-Date)) -----"
$sw = Start-Phase
if ($QuickTest) {
  & $MATLAB -batch "VARIANT='fft'; ARCH_LIST={'detection'}; ARCH_N=[5]; GRID_SIZES=[100]; OUTPUT_FILE='$smoke2DM/timings-cosivina-2d.csv'; addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking-2d'); run('runners/cosivina_benchmark_2d.m')" *>> $log
} else {
  & $MATLAB -batch "VARIANT='fft'; addpath(genpath('$COSIVINA')); cd('$ROOT/benchmarking-2d'); run('runners/cosivina_benchmark_2d.m')" *>> $log
}
Complete-Phase "2D benchmark, cosivina-fft" $sw

Log "===== FULL RERUN (incl. MATLAB) COMPLETE$bannerSuffix $(Get-Date) ====="
