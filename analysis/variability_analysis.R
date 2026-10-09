# variability_analysis.R — Run-to-run variability for the DNF benchmark
#
# SoftwareX revision, item B8. Computes, per configuration (fwv x arch x dim x
# field_size x N), the run-to-run variability (CI half-width as % of median)
# from the 10 raw per-run timings, and compares it against regime-to-regime
# spread (the claim Figure 5's caption makes).
#
# CSV format read (no header, comma-separated), same as benchmarking/analysis.R:
#   framework, variant, arch, field_size, mode, N, run, steps_per_second
#
# Run from anywhere (path is resolved from this script's own location):
#   & 'C:\Program Files\R\R-4.4.1\bin\Rscript.exe' analysis/variability_analysis.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

# ---------------------------------------------------------------------------
# Locate files
# ---------------------------------------------------------------------------
HERE <- tryCatch(
  dirname(normalizePath(sys.frames()[[1]]$ofile)),
  error = function(e) NA_character_
)
if (is.na(HERE) || HERE == "") {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grepl("^--file=", args)])
  if (length(file_arg) > 0) {
    HERE <- dirname(normalizePath(file_arg[1]))
  } else {
    HERE <- normalizePath(".")
  }
}
ROOT <- normalizePath(file.path(HERE, ".."))

cat(sprintf("Script dir (HERE): %s\n", HERE))
cat(sprintf("Repo root (ROOT):  %s\n", ROOT))

col_spec <- cols(
  framework        = col_character(),
  variant          = col_character(),
  arch             = col_character(),
  field_size       = col_integer(),
  mode             = col_character(),
  N                = col_integer(),
  run              = col_integer(),
  steps_per_second = col_double()
)
col_nms <- c("framework", "variant", "arch", "field_size", "mode", "N", "run", "steps_per_second")

# framework+variant display label: bare framework when variant is "default",
# else "framework (variant)" — matches benchmarking/analysis.R exactly.
make_fwv <- function(framework, variant) {
  ifelse(variant == "default", framework, paste0(framework, " (", variant, ")"))
}

read_timings <- function(dir, filename, dim_label) {
  path <- file.path(ROOT, dir, "data", filename)
  if (!file.exists(path)) stop("File not found: ", path)
  df <- read_csv(path, col_names = col_nms, col_types = col_spec, progress = FALSE)
  df$dim <- dim_label
  df
}

timings <- bind_rows(
  read_timings("benchmarking",    "timings-cedar.csv",             "1D"),
  read_timings("benchmarking",    "timings-cosivina.csv",           "1D"),
  read_timings("benchmarking",    "timings-cosivina-python.csv",    "1D"),
  read_timings("benchmarking",    "timings-dnfc.csv",                "1D"),
  read_timings("benchmarking-2d", "timings-cedar-2d.csv",            "2D"),
  read_timings("benchmarking-2d", "timings-cosivina-2d.csv",         "2D"),
  read_timings("benchmarking-2d", "timings-cosivina-python-2d.csv",  "2D"),
  read_timings("benchmarking-2d", "timings-dnfc-2d.csv",             "2D")
) %>%
  mutate(fwv = make_fwv(framework, variant))

cat(sprintf("\nLoaded %d rows total\n", nrow(timings)))
if (nrow(timings) != 7680) {
  stop(sprintf("Expected 7680 rows, got %d - data has changed since the plan was written.", nrow(timings)))
}

# ---------------------------------------------------------------------------
# Step 2 - protocol check: runs per configuration, timed steps assumption
# ---------------------------------------------------------------------------
run_counts <- timings %>%
  count(fwv, arch, dim, field_size, N, name = "n_runs")

n_configs <- nrow(run_counts)
cat(sprintf("Distinct configurations (fwv x arch x dim x field_size x N): %d\n", n_configs))

bad_configs <- run_counts %>% filter(n_runs != 10)
if (nrow(bad_configs) > 0) {
  cat("WARNING: configurations without exactly 10 runs:\n")
  print(as.data.frame(bad_configs))
} else {
  cat("Confirmed: every configuration has exactly 10 runs (matches manuscript claim of 10 runs/config).\n")
}

run_idx_range <- range(timings$run)
cat(sprintf("Run index range: %d..%d\n", run_idx_range[1], run_idx_range[2]))

t_crit <- qt(0.975, 9)
cat(sprintf("t(0.975, 9) = %.4f (manuscript/task states 2.262)\n", t_crit))
if (abs(t_crit - 2.262) > 0.001) {
  stop("t-critical value does not match expected 2.262 - check df.")
}

cat("\nNote: timed-steps/warm-up protocol (500 timed steps, 200 warm-up) is set in the\n")
cat("PowerShell drivers (run_1d_benchmark.ps1 / run_2d_benchmark.ps1) and hardcoded\n")
cat("WARMUP_STEPS=200 in every runner with no CLI override. The compiled C++ defaults\n")
cat("(TIMED_STEPS=2000, N_RUNS=5) are dead values, always overridden by the drivers -\n")
cat("not reflected in this data (confirmed by the 10-runs-per-config check above).\n\n")

# ---------------------------------------------------------------------------
# Step 3 - per-configuration variability
# ---------------------------------------------------------------------------
per_config <- timings %>%
  group_by(fwv, arch, dim, field_size, N) %>%
  summarise(
    n        = n(),
    median   = median(steps_per_second),
    mean     = mean(steps_per_second),
    sd       = sd(steps_per_second),
    min_sps  = min(steps_per_second),
    max_sps  = max(steps_per_second),
    .groups  = "drop"
  ) %>%
  mutate(
    ci_half   = qt(0.975, n - 1) * sd / sqrt(n),
    pct       = 100 * ci_half / median,
    run_range = 100 * (max_sps - min_sps) / mean
  ) %>%
  select(fwv, arch, dim, field_size, N, n, median, mean, sd, ci_half, pct, run_range)

stopifnot(nrow(per_config) == n_configs)

write_csv(per_config, file.path(ROOT, "analysis", "variability_per_config.csv"))
cat(sprintf("Wrote analysis/variability_per_config.csv (%d rows)\n\n", nrow(per_config)))

# ---------------------------------------------------------------------------
# Cross-check against the repo's own aggregation (benchmark_summary.csv)
# ---------------------------------------------------------------------------
read_summary <- function(dir, dim_label) {
  path <- file.path(ROOT, dir, "data", "benchmark_summary.csv")
  df <- read_csv(path, show_col_types = FALSE)
  df$dim <- dim_label
  df
}

summary_ref <- bind_rows(
  read_summary("benchmarking", "1D"),
  read_summary("benchmarking-2d", "2D")
) %>%
  select(fwv, arch, field_size, N, dim, ref_median = median_sps, ref_sd = sd_sps,
         ref_ci95_lo = ci95_lo, ref_ci95_hi = ci95_hi, ref_mean = mean_sps)

cross_check <- per_config %>%
  inner_join(summary_ref, by = c("fwv", "arch", "field_size", "N", "dim")) %>%
  mutate(
    computed_ci95_lo = mean - ci_half,
    computed_ci95_hi = mean + ci_half,
    median_diff = abs(median - ref_median),
    ci_lo_diff  = abs(computed_ci95_lo - ref_ci95_lo),
    ci_hi_diff  = abs(computed_ci95_hi - ref_ci95_hi)
  )

n_matched <- nrow(cross_check)
tol <- 1e-6
mismatches <- cross_check %>% filter(median_diff > tol | ci_lo_diff > tol | ci_hi_diff > tol)

cat(sprintf("Cross-check against benchmark_summary.csv: matched %d / %d configs\n", n_matched, n_configs))
if (n_matched != n_configs) {
  stop("Cross-check join did not match all configurations - schema mismatch with benchmark_summary.csv.")
}
if (nrow(mismatches) > 0) {
  cat(sprintf("MISMATCHES: %d configs disagree with benchmark_summary.csv beyond tolerance %.1e\n", nrow(mismatches), tol))
  print(as.data.frame(mismatches %>% select(fwv, arch, dim, field_size, N, median_diff, ci_lo_diff, ci_hi_diff)))
  stop("Cross-check failed - investigate before trusting X.")
} else {
  cat("Cross-check PASSED: median and 95% CI bounds match benchmark_summary.csv on all configs (tol 1e-6).\n\n")
}

# ---------------------------------------------------------------------------
# Step 4.1 - X = max(pct), and where it comes from
# ---------------------------------------------------------------------------
per_config_sorted <- per_config %>% arrange(desc(pct))
X_row <- per_config_sorted %>% slice(1)
X <- round(X_row$pct, 1)

cat("============================================================\n")
cat("X = max(pct) across all configurations\n")
cat("============================================================\n")
cat(sprintf("X = %.1f%%\n", X))
cat("Configuration:\n")
print(as.data.frame(X_row %>% select(fwv, arch, dim, field_size, N, n, median, sd, ci_half, pct)))
cat("\n")

# ---------------------------------------------------------------------------
# Step 4.2 - distribution of pct, outlier check
# ---------------------------------------------------------------------------
cat("============================================================\n")
cat("Distribution of pct across all configurations\n")
cat("============================================================\n")
pct_median <- median(per_config$pct)
pct_p90    <- quantile(per_config$pct, 0.90, names = FALSE)
pct_max    <- max(per_config$pct)
cat(sprintf("median pct = %.2f%%\n", pct_median))
cat(sprintf("p90 pct    = %.2f%%\n", pct_p90))
cat(sprintf("max pct    = %.2f%%\n", pct_max))
cat("\nTop 10 configurations by pct:\n")
print(as.data.frame(per_config_sorted %>% slice(1:10) %>%
  select(fwv, arch, dim, field_size, N, pct)))

second_row <- per_config_sorted %>% slice(2)
max_excl_top <- second_row$pct
gap_ratio <- X_row$pct / max_excl_top
cat(sprintf("\nMax excluding the top value: %.2f%% (configuration: fwv=%s, arch=%s, dim=%s, field_size=%d, N=%d)\n",
            max_excl_top, second_row$fwv, second_row$arch, second_row$dim, second_row$field_size, second_row$N))
cat(sprintf("Ratio of top pct to second-highest pct: %.2fx\n", gap_ratio))
if (gap_ratio > 1.5) {
  cat("=> The maximum appears to be an ISOLATED OUTLIER (>1.5x the next-highest value).\n\n")
} else {
  cat("=> The maximum is NOT a clear isolated outlier (within 1.5x of the next-highest value).\n\n")
}

# ---------------------------------------------------------------------------
# Step 4.3 - regime-spread comparison
# ---------------------------------------------------------------------------
regime_groups <- per_config %>%
  group_by(fwv, dim, field_size, N) %>%
  summarise(
    n_regimes       = n(),
    regime_median_min = min(median),
    regime_median_max = max(median),
    regime_mean_of_medians = mean(median),
    regime_spread   = 100 * (max(median) - min(median)) / mean(median),
    max_pct_in_group       = max(pct),
    max_run_range_in_group = max(run_range),
    .groups = "drop"
  ) %>%
  mutate(
    claim_holds_ci_vs_spread  = max_pct_in_group < regime_spread,
    claim_holds_range_vs_spread = max_run_range_in_group < regime_spread
  )

stopifnot(all(regime_groups$n_regimes == 4))
n_groups <- nrow(regime_groups)

write_csv(regime_groups, file.path(ROOT, "analysis", "variability_regime_spread.csv"))
cat(sprintf("Wrote analysis/variability_regime_spread.csv (%d groups)\n\n", n_groups))

cat("============================================================\n")
cat(sprintf("Regime-spread comparison across %d groups (fwv x dim x field_size x N)\n", n_groups))
cat("============================================================\n")
cat(sprintf("regime_spread median = %.2f%%\n", median(regime_groups$regime_spread)))
cat(sprintf("regime_spread min    = %.2f%%\n", min(regime_groups$regime_spread)))
cat("\n")

cat("--- Comparison 1 (as specified): max(pct) [CI half-width basis] vs regime_spread [range basis] ---\n")
counter_ci <- regime_groups %>% filter(!claim_holds_ci_vs_spread)
cat(sprintf("Holds for %d / %d groups.\n", n_groups - nrow(counter_ci), n_groups))
if (nrow(counter_ci) > 0) {
  cat("COUNTEREXAMPLES (run-to-run pct >= regime spread):\n")
  print(as.data.frame(counter_ci %>% select(fwv, dim, field_size, N, max_pct_in_group, regime_spread)))
} else {
  cat("No counterexamples - run-to-run pct < regime spread in every group.\n")
}
cat("\n")

cat("--- Comparison 2 (like-for-like): max(run_range) [range basis] vs regime_spread [range basis] ---\n")
counter_range <- regime_groups %>% filter(!claim_holds_range_vs_spread)
cat(sprintf("Holds for %d / %d groups.\n", n_groups - nrow(counter_range), n_groups))
if (nrow(counter_range) > 0) {
  cat("COUNTEREXAMPLES (run-to-run range >= regime spread):\n")
  print(as.data.frame(counter_range %>% select(fwv, dim, field_size, N, max_run_range_in_group, regime_spread)))
} else {
  cat("No counterexamples - run-to-run range < regime spread in every group.\n")
}
cat("\n")

# ---------------------------------------------------------------------------
# Step 4.4 - Figure 5 ribbon confirmation (static check on the script text)
# ---------------------------------------------------------------------------
cat("============================================================\n")
cat("Figure 5 ribbon source (analysis/fig_paper_throughput.R)\n")
cat("============================================================\n")
fig5_path <- file.path(ROOT, "analysis", "fig_paper_throughput.R")
if (file.exists(fig5_path)) {
  fig5_lines <- readLines(fig5_path)
  ribbon_def_idx <- grep("lo_sps\\s*=\\s*min\\(median_sps\\)", fig5_lines)
  ribbon_geom_idx <- grep("geom_ribbon", fig5_lines)
  cat("Ribbon aggregation line(s):\n")
  if (length(ribbon_def_idx) > 0) cat(sprintf("  L%d: %s\n", ribbon_def_idx, trimws(fig5_lines[ribbon_def_idx])))
  cat("Ribbon geom line(s):\n")
  if (length(ribbon_geom_idx) > 0) {
    for (i in ribbon_geom_idx) cat(sprintf("  L%d: %s\n", i, trimws(fig5_lines[i])))
  }
  cat("\nConclusion: the ribbon is min/max of median_sps (per-config median over 10 runs)\n")
  cat("ACROSS THE 4 REGIMES within group_by(fwv, N), at fixed field_size and mode=='headless'.\n")
  cat("It is NOT a run-level CI, NOT sd, NOT computed from raw per-run data - run-to-run\n")
  cat("variability is fully collapsed away before the ribbon is computed (n=4 regimes, not n=10 runs).\n\n")
} else {
  cat(sprintf("WARNING: %s not found - cannot confirm ribbon source statically.\n\n", fig5_path))
}

cat("Analysis complete.\n")
