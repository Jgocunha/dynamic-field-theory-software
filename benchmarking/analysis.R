# analysis.R — DFT Framework Benchmark Analysis
#
# Reads three separate CSV files (one per framework) and produces:
#   - Table 1: steps/second for Cedar, Cosivina, dnfc × N={10,50,100,500,1000}
#   - Detailed statistics (median / min / max)
#   - Speedup ratios relative to Cosivina
#
# CSV format (no header, comma-separated):
#   framework, mode, N, run, steps_per_second
#
# Run from the benchmarking/ root directory:
#   Rscript analysis.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
})

# ---------------------------------------------------------------------------
# Locate files
# ---------------------------------------------------------------------------
ROOT <- tryCatch(
  dirname(rstudioapi::getSourceEditorContext()$path),
  error = function(e) normalizePath(".")
)
if (is.null(ROOT) || ROOT == "") ROOT <- normalizePath(".")

col_spec <- cols(
  framework        = col_character(),
  mode             = col_character(),
  N                = col_integer(),
  run              = col_integer(),
  steps_per_second = col_double()
)
col_nms <- c("framework", "mode", "N", "run", "steps_per_second")

read_framework <- function(filename) {
  path <- file.path(ROOT, "data", filename)
  if (!file.exists(path)) stop("File not found: ", path)
  read_csv(path, col_names = col_nms, col_types = col_spec)
}

timings <- bind_rows(
  read_framework("timings-cedar.csv"),
  read_framework("timings-cosivina.csv"),
  read_framework("timings-dnfc.csv")
)

cat(sprintf("Loaded %d rows total\n\n", nrow(timings)))

# ---------------------------------------------------------------------------
# Aggregate
# ---------------------------------------------------------------------------
summary_df <- timings %>%
  group_by(framework, mode, N) %>%
  summarise(
    median_sps = median(steps_per_second),
    min_sps    = min(steps_per_second),
    max_sps    = max(steps_per_second),
    sd_sps     = sd(steps_per_second),
    n_runs     = n(),
    .groups    = "drop"
  )

# ---------------------------------------------------------------------------
# Main results table (headless only)
# ---------------------------------------------------------------------------
headless_wide <- summary_df %>%
  filter(mode == "headless") %>%
  mutate(label = sprintf("%.0f", round(median_sps))) %>%
  select(framework, N, label) %>%
  pivot_wider(names_from = N, values_from = label, names_prefix = "N=") %>%
  arrange(framework)

cat("=== Headless steps/second (median of 3 runs) ===\n")
print(as.data.frame(headless_wide))
cat("\n")

# ---------------------------------------------------------------------------
# Detailed statistics table
# ---------------------------------------------------------------------------
detail <- summary_df %>%
  filter(mode == "headless") %>%
  mutate(stats = sprintf("%.0f  [%.0f–%.0f]", median_sps, min_sps, max_sps)) %>%
  select(framework, N, stats) %>%
  pivot_wider(names_from = N, values_from = stats, names_prefix = "N=") %>%
  arrange(framework)

cat("=== Detailed: median [min–max] steps/second ===\n")
print(as.data.frame(detail))
cat("\n")

# ---------------------------------------------------------------------------
# Speedup ratios relative to Cosivina
# ---------------------------------------------------------------------------
pivot_median <- summary_df %>%
  filter(mode == "headless") %>%
  select(framework, N, median_sps) %>%
  pivot_wider(names_from = framework, values_from = median_sps)

speedup <- pivot_median %>%
  mutate(
    dnfc_vs_cosivina  = round(dnfc      / cosivina, 2),
    cedar_vs_cosivina = round(cedar     / cosivina, 2),
    dnfc_vs_cedar     = round(dnfc      / cedar,    2)
  ) %>%
  select(N, dnfc_vs_cosivina, cedar_vs_cosivina, dnfc_vs_cedar)

cat("=== Speedup ratios (headless) ===\n")
print(as.data.frame(speedup))
cat("\n")

# ---------------------------------------------------------------------------
# Scaling efficiency (steps/s relative to N=10 baseline)
# ---------------------------------------------------------------------------
baseline <- summary_df %>%
  filter(mode == "headless", N == 10) %>%
  select(framework, base_sps = median_sps)

scaling <- summary_df %>%
  filter(mode == "headless") %>%
  left_join(baseline, by = "framework") %>%
  mutate(efficiency = round(median_sps / base_sps * (N / 10), 3)) %>%
  select(framework, N, efficiency) %>%
  pivot_wider(names_from = N, values_from = efficiency, names_prefix = "N=") %>%
  arrange(framework)

cat("=== Scaling efficiency (1.0 = perfectly linear) ===\n")
print(as.data.frame(scaling))
cat("\n")

# ---------------------------------------------------------------------------
# Save outputs
# ---------------------------------------------------------------------------
out_summary <- file.path(ROOT, "data", "benchmark_summary.csv")
write_csv(summary_df, out_summary)
cat(sprintf("Summary saved to %s\n", out_summary))
cat("\nAnalysis complete.\n")
