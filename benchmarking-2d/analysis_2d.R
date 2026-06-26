# analysis_2d.R — DFT Framework 2D Benchmark Analysis (50x50 fields)
#
# 2D counterpart of ../benchmarking/analysis.R. Reads the four per-framework
# timing CSVs and produces, per architecture: median steps/second × N, 95% CI,
# speedup vs Cosivina, and the detection scaling efficiency.
#
# CSV format (no header, comma-separated):
#   framework, arch, mode, N, run, steps_per_second
#
# Run from the benchmarking-2d/ root directory:
#   Rscript analysis_2d.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
})

ROOT <- tryCatch(
  dirname(rstudioapi::getSourceEditorContext()$path),
  error = function(e) normalizePath(".")
)
if (is.null(ROOT) || ROOT == "") ROOT <- normalizePath(".")

col_spec <- cols(
  framework        = col_character(),
  arch             = col_character(),
  mode             = col_character(),
  N                = col_integer(),
  run              = col_integer(),
  steps_per_second = col_double()
)
col_nms <- c("framework", "arch", "mode", "N", "run", "steps_per_second")

read_framework <- function(filename) {
  path <- file.path(ROOT, "data", filename)
  if (!file.exists(path)) { message("File not found (skipping): ", path); return(NULL) }
  read_csv(path, col_names = col_nms, col_types = col_spec)
}

timings <- bind_rows(
  read_framework("timings-cedar-2d.csv"),
  read_framework("timings-cosivina-2d.csv"),
  read_framework("timings-dnfc-2d.csv"),
  read_framework("timings-cosivina-python-2d.csv")
)

cat(sprintf("Loaded %d rows total\n\n", nrow(timings)))

ARCH_ORDER <- c("detection", "selection", "memory", "insufficient", "multi-peak")

summary_df <- timings %>%
  group_by(framework, arch, mode, N) %>%
  summarise(
    median_sps = median(steps_per_second),
    mean_sps   = mean(steps_per_second),
    min_sps    = min(steps_per_second),
    max_sps    = max(steps_per_second),
    sd_sps     = sd(steps_per_second),
    n_runs     = n(),
    sem_sps    = sd(steps_per_second) / sqrt(n()),
    ci95_lo    = ifelse(n() > 1,
                        mean(steps_per_second) - qt(0.975, n() - 1) * sd(steps_per_second) / sqrt(n()),
                        NA_real_),
    ci95_hi    = ifelse(n() > 1,
                        mean(steps_per_second) + qt(0.975, n() - 1) * sd(steps_per_second) / sqrt(n()),
                        NA_real_),
    .groups    = "drop"
  )

archs_present <- intersect(ARCH_ORDER, unique(summary_df$arch))

for (a in archs_present) {
  cat(sprintf("============================================================\n"))
  cat(sprintf("ARCHITECTURE: %s\n", a))
  cat(sprintf("============================================================\n"))

  sub <- summary_df %>% filter(mode == "headless", arch == a)

  wide <- sub %>%
    mutate(label = sprintf("%.0f", round(median_sps))) %>%
    select(framework, N, label) %>%
    pivot_wider(names_from = N, values_from = label, names_prefix = "N=") %>%
    arrange(framework)
  cat("--- median steps/second (>=10 runs), 50x50 ---\n")
  print(as.data.frame(wide))

  detail <- sub %>%
    mutate(stats = sprintf("%.0f [%.0f-%.0f]", median_sps, min_sps, max_sps)) %>%
    select(framework, N, stats) %>%
    pivot_wider(names_from = N, values_from = stats, names_prefix = "N=") %>%
    arrange(framework)
  cat("--- median [min-max] ---\n")
  print(as.data.frame(detail))

  pivot_median <- sub %>%
    select(framework, N, median_sps) %>%
    pivot_wider(names_from = framework, values_from = median_sps)

  if ("cosivina" %in% names(pivot_median)) {
    sp <- pivot_median %>%
      mutate(
        dnfc_vs_cosivina  = if ("dnfc"  %in% names(.)) round(dnfc  / cosivina, 2) else NA_real_,
        cedar_vs_cosivina = if ("cedar" %in% names(.)) round(cedar / cosivina, 2) else NA_real_,
        dnfc_vs_cedar     = if (all(c("dnfc","cedar") %in% names(.))) round(dnfc / cedar, 2) else NA_real_,
        `cpy_vs_cosivina` = if ("cosivina-python" %in% names(.)) round(`cosivina-python` / cosivina, 2) else NA_real_
      ) %>%
      select(N, any_of(c("dnfc_vs_cosivina", "cedar_vs_cosivina", "dnfc_vs_cedar", "cpy_vs_cosivina")))
    cat("--- speedup vs Cosivina ---\n")
    print(as.data.frame(sp))
  }
  cat("\n")
}

if ("detection" %in% archs_present) {
  det <- summary_df %>% filter(mode == "headless", arch == "detection")
  baseline <- det %>% filter(N == 10) %>% select(framework, base_sps = median_sps)
  scaling <- det %>%
    left_join(baseline, by = "framework") %>%
    mutate(efficiency = round(median_sps / base_sps * (N / 10), 3)) %>%
    select(framework, N, efficiency) %>%
    pivot_wider(names_from = N, values_from = efficiency, names_prefix = "N=") %>%
    arrange(framework)
  cat("=== Scaling efficiency, detection sweep (1.0 = perfectly linear) ===\n")
  print(as.data.frame(scaling))
  cat("\n")
}

out_summary <- file.path(ROOT, "data", "benchmark_summary.csv")
write_csv(summary_df, out_summary)
cat(sprintf("Summary saved to %s\n", out_summary))
cat("\nAnalysis complete.\n")
