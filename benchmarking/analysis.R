# analysis.R — DFT Framework Benchmark Analysis
#
# Reads four per-framework CSV files and produces, per architecture:
#   - steps/second for each framework VARIANT × N
#   - 95% CI on the mean (t-interval over the 5 runs/cell)
#   - speedup ratios relative to Cosivina (MATLAB)
#
# Variants compared: cosivina (MATLAB), cosivina-python (numba | nonumba),
# cedar (opencv | fftw), dnfc. The framework+variant pair is the display key `fwv`.
#
# CSV format (no header, comma-separated):
#   framework, variant, arch, field_size, mode, N, run, steps_per_second
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
# else "framework (variant)" — e.g. "cedar (fftw)", "cosivina-python (nonumba)".
make_fwv <- function(framework, variant) {
  ifelse(variant == "default", framework, paste0(framework, " (", variant, ")"))
}

read_framework <- function(filename) {
  path <- file.path(ROOT, "data", filename)
  if (!file.exists(path)) { message("File not found (skipping): ", path); return(NULL) }
  read_csv(path, col_names = col_nms, col_types = col_spec)
}

timings <- bind_rows(
  read_framework("timings-cedar.csv"),
  read_framework("timings-cosivina.csv"),
  read_framework("timings-dnfc.csv"),
  read_framework("timings-cosivina-python.csv")
)

cat(sprintf("Loaded %d rows total\n\n", nrow(timings)))

ARCH_ORDER <- c("detection", "selection", "memory", "multi-peak")

timings <- timings %>% mutate(fwv = make_fwv(framework, variant))

# ---------------------------------------------------------------------------
# Aggregate (per framework-variant x arch x field_size x N)
# ---------------------------------------------------------------------------
summary_df <- timings %>%
  group_by(framework, variant, fwv, arch, field_size, mode, N) %>%
  summarise(
    median_sps = median(steps_per_second),
    mean_sps   = mean(steps_per_second),
    min_sps    = min(steps_per_second),
    max_sps    = max(steps_per_second),
    sd_sps     = sd(steps_per_second),
    n_runs     = n(),
    sem_sps    = sd(steps_per_second) / sqrt(n()),
    # 95% CI on the mean (t-interval; valid for the 5 runs collected per cell).
    ci95_lo    = ifelse(n() > 1,
                        mean(steps_per_second) - qt(0.975, n() - 1) * sd(steps_per_second) / sqrt(n()),
                        NA_real_),
    ci95_hi    = ifelse(n() > 1,
                        mean(steps_per_second) + qt(0.975, n() - 1) * sd(steps_per_second) / sqrt(n()),
                        NA_real_),
    .groups    = "drop"
  )

archs_present <- intersect(ARCH_ORDER, unique(summary_df$arch))
sizes_present <- sort(unique(summary_df$field_size))

# ---------------------------------------------------------------------------
# Per-architecture x field-size tables
# ---------------------------------------------------------------------------
for (a in archs_present) {
  for (fs in sizes_present) {
    sub <- summary_df %>% filter(mode == "headless", arch == a, field_size == fs)
    if (nrow(sub) == 0) next

    cat(sprintf("============================================================\n"))
    cat(sprintf("ARCHITECTURE: %s   field_size: %d\n", a, fs))
    cat(sprintf("============================================================\n"))

    wide <- sub %>%
      mutate(label = sprintf("%.0f", round(median_sps))) %>%
      select(fwv, N, label) %>%
      pivot_wider(names_from = N, values_from = label, names_prefix = "N=") %>%
      arrange(fwv)
    cat("--- median steps/second (5 runs) ---\n")
    print(as.data.frame(wide))

    detail <- sub %>%
      mutate(stats = sprintf("%.0f [%.0f-%.0f]", median_sps, min_sps, max_sps)) %>%
      select(fwv, N, stats) %>%
      pivot_wider(names_from = N, values_from = stats, names_prefix = "N=") %>%
      arrange(fwv)
    cat("--- median [min-max] ---\n")
    print(as.data.frame(detail))

    # Speedup of every variant relative to Cosivina (MATLAB) at each N.
    ref <- sub %>% filter(framework == "cosivina") %>% select(N, ref_sps = median_sps)
    if (nrow(ref) > 0) {
      sp <- sub %>%
        inner_join(ref, by = "N") %>%
        mutate(speedup = round(median_sps / ref_sps, 2)) %>%
        select(fwv, N, speedup) %>%
        pivot_wider(names_from = N, values_from = speedup, names_prefix = "N=") %>%
        arrange(fwv)
      cat("--- speedup vs Cosivina (MATLAB) ---\n")
      print(as.data.frame(sp))
    }
    cat("\n")
  }
}

# ---------------------------------------------------------------------------
# Save outputs
# ---------------------------------------------------------------------------
out_summary <- file.path(ROOT, "data", "benchmark_summary.csv")
write_csv(summary_df, out_summary)
cat(sprintf("Summary saved to %s\n", out_summary))
cat("\nAnalysis complete.\n")
