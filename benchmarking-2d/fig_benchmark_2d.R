# fig_benchmark_2d.R — Generate PNG figures for the 2D benchmark README
#
# 2D counterpart of ../benchmarking/fig_benchmark.R. Produces (saved to
# benchmarking-2d/):
#   fig_benchmark_throughput.png  — steps/sec vs N, log-log, one line per framework
#   fig_benchmark_speedup.png     — speedup relative to Cosivina, grouped bars
#
# Run from the benchmarking-2d/ directory:
#   Rscript fig_benchmark_2d.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(scales)
})

ROOT <- tryCatch(
  dirname(rstudioapi::getSourceEditorContext()$path),
  error = function(e) normalizePath(".")
)
if (is.null(ROOT) || ROOT == "") ROOT <- normalizePath(".")

# -- Data ----------------------------------------------------------------------

col_nms  <- c("framework", "arch", "mode", "N", "run", "steps_per_second")
col_spec <- cols(
  framework        = col_character(),
  arch             = col_character(),
  mode             = col_character(),
  N                = col_integer(),
  run              = col_integer(),
  steps_per_second = col_double()
)

ARCH_ORDER <- c("detection", "selection", "memory", "insufficient", "multi-peak")

read_fw <- function(f) {
  path <- file.path(ROOT, "data", f)
  if (!file.exists(path)) { message("File not found (skipping): ", path); return(NULL) }
  read_csv(path, col_names = col_nms, col_types = col_spec)
}

timings <- bind_rows(
  read_fw("timings-cedar-2d.csv"),
  read_fw("timings-cosivina-2d.csv"),
  read_fw("timings-dnfc-2d.csv"),
  read_fw("timings-cosivina-python-2d.csv")
)

summary_df <- timings %>%
  filter(mode == "headless") %>%
  group_by(framework, arch, N) %>%
  summarise(
    median_sps = median(steps_per_second),
    mean_sps   = mean(steps_per_second),
    min_sps    = min(steps_per_second),
    max_sps    = max(steps_per_second),
    ci95_lo    = ifelse(n() > 1, mean(steps_per_second) - qt(0.975, n()-1)*sd(steps_per_second)/sqrt(n()), median_sps),
    ci95_hi    = ifelse(n() > 1, mean(steps_per_second) + qt(0.975, n()-1)*sd(steps_per_second)/sqrt(n()), median_sps),
    .groups    = "drop"
  ) %>%
  mutate(arch = factor(arch, levels = intersect(ARCH_ORDER, unique(arch))))

# -- Cosmetics -----------------------------------------------------------------

fw_order  <- c("dnfc", "cedar", "cosivina", "cosivina-python")

fw_labels <- c(
  "dnfc"            = "dnfc (C++, float64)",
  "cedar"           = "Cedar (C++, float32)",
  "cosivina"        = "Cosivina (MATLAB, float64)",
  "cosivina-python" = "cosivina-python (Python, float64)"
)

# Colorblind-friendly palette (Wong 2011)
fw_colors <- c(
  "dnfc"            = "#0072B2",   # blue
  "cedar"           = "#D55E00",   # vermillion
  "cosivina"        = "#009E73",   # green
  "cosivina-python" = "#CC79A7"    # pink
)

fw_shapes <- c(
  "dnfc"            = 16,  # circle
  "cedar"           = 17,  # triangle
  "cosivina"        = 15,  # square
  "cosivina-python" = 18   # diamond
)

fw_lty <- c(
  "dnfc"            = "solid",
  "cedar"           = "solid",
  "cosivina"        = "dashed",
  "cosivina-python" = "dotted"
)

summary_df <- summary_df %>%
  mutate(framework = factor(framework, levels = fw_order))

# -- Figure 1: throughput vs N, faceted by architecture (2D) -------------------

p_throughput <- ggplot(
  summary_df,
  aes(x = N, y = median_sps, colour = framework,
      shape = framework, linetype = framework, group = framework)
) +
  geom_ribbon(
    aes(ymin = ci95_lo, ymax = ci95_hi, fill = framework),
    alpha = 0.15, colour = NA
  ) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2.6) +
  facet_wrap(~ arch, ncol = 3) +
  scale_x_log10(
    breaks = c(10, 50, 100, 500, 1000),
    labels = c("10", "50", "100", "500", "1k")
  ) +
  scale_y_log10(labels = label_comma()) +
  scale_colour_manual(values = fw_colors, labels = fw_labels) +
  scale_fill_manual(values = fw_colors, labels = fw_labels, guide = "none") +
  scale_shape_manual(values = fw_shapes, labels = fw_labels) +
  scale_linetype_manual(values = fw_lty, labels = fw_labels) +
  labs(
    title    = "Simulation throughput by architecture (2D, 50x50 fields)",
    subtitle = "Steps per second · headless · point = median · ribbon = 95% CI of the mean",
    x        = "Number of independent neural fields (N)",
    y        = "Steps per second (log scale)",
    colour   = NULL, shape = NULL, linetype = NULL
  ) +
  theme_bw(base_size = 12) +
  theme(
    legend.position      = "bottom",
    legend.key.width     = unit(1.6, "cm"),
    legend.text          = element_text(size = 9),
    panel.grid.minor     = element_blank(),
    plot.title           = element_text(face = "bold"),
    plot.subtitle        = element_text(size = 9, colour = "grey40"),
    strip.text           = element_text(face = "bold")
  ) +
  guides(colour   = guide_legend(nrow = 2),
         shape    = guide_legend(nrow = 2),
         linetype = guide_legend(nrow = 2))

ggsave(
  file.path(ROOT, "fig_benchmark_throughput.png"),
  p_throughput,
  width = 9, height = 6.5, dpi = 150
)
cat("Saved: fig_benchmark_throughput.png\n")

# -- Figure 2: per-architecture speedup vs Cosivina, at a representative N ------

ref_N <- 100
cosivina_ref <- summary_df %>%
  filter(framework == "cosivina", N == ref_N) %>%
  select(arch, ref_sps = median_sps)

speedup_df <- summary_df %>%
  filter(framework != "cosivina", N == ref_N) %>%
  inner_join(cosivina_ref, by = "arch") %>%
  mutate(
    speedup    = median_sps / ref_sps,
    speedup_lo = ci95_lo / ref_sps,
    speedup_hi = ci95_hi / ref_sps,
    framework  = factor(framework, levels = c("dnfc", "cedar", "cosivina-python"))
  )

speedup_colors <- fw_colors[c("dnfc", "cedar", "cosivina-python")]
speedup_labels <- fw_labels[c("dnfc", "cedar", "cosivina-python")]

if (nrow(speedup_df) > 0) {
  p_speedup <- ggplot(
    speedup_df,
    aes(x = arch, y = speedup, fill = framework)
  ) +
    geom_col(position = position_dodge(width = 0.78), width = 0.7) +
    geom_errorbar(
      aes(ymin = speedup_lo, ymax = speedup_hi),
      position = position_dodge(width = 0.78), width = 0.25,
      linewidth = 0.4, colour = "grey25"
    ) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "grey30", linewidth = 0.6) +
    geom_text(
      aes(label = sprintf("%.1fx", speedup)),
      position = position_dodge(width = 0.78),
      vjust    = -0.4, size = 2.7, colour = "grey20"
    ) +
    scale_fill_manual(values = speedup_colors, labels = speedup_labels) +
    scale_y_continuous(
      labels = function(x) paste0(x, "x"),
      expand = expansion(mult = c(0, 0.12))
    ) +
    labs(
      title    = sprintf("Speedup relative to Cosivina (MATLAB), 2D, N=%d", ref_N),
      subtitle = "Dashed line = Cosivina baseline (1x). Values > 1x are faster.",
      x        = "Architecture",
      y        = "Speedup (x)",
      fill     = NULL
    ) +
    theme_bw(base_size = 13) +
    theme(
      legend.position      = "bottom",
      legend.text          = element_text(size = 10),
      panel.grid.minor     = element_blank(),
      panel.grid.major.x   = element_blank(),
      plot.title           = element_text(face = "bold"),
      plot.subtitle        = element_text(size = 10, colour = "grey40")
    ) +
    guides(fill = guide_legend(nrow = 1))

  ggsave(
    file.path(ROOT, "fig_benchmark_speedup.png"),
    p_speedup,
    width = 9, height = 5, dpi = 150
  )
  cat("Saved: fig_benchmark_speedup.png\n")
} else {
  message("No Cosivina rows at N=", ref_N, " — skipping speedup figure.")
}

cat("\nDone.\n")
