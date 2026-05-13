# fig_benchmark.R — Generate PNG figures for the benchmark README
#
# Produces (saved to benchmarking/):
#   fig_benchmark_throughput.png  — steps/sec vs N, log-log, one line per framework
#   fig_benchmark_speedup.png     — speedup relative to Cosivina, grouped bars
#
# Run from the benchmarking/ directory:
#   Rscript fig_benchmark.R

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

# ── Data ──────────────────────────────────────────────────────────────────────

col_nms  <- c("framework", "mode", "N", "run", "steps_per_second")
col_spec <- cols(
  framework        = col_character(),
  mode             = col_character(),
  N                = col_integer(),
  run              = col_integer(),
  steps_per_second = col_double()
)

read_fw <- function(f) {
  read_csv(file.path(ROOT, "data", f), col_names = col_nms, col_types = col_spec)
}

timings <- bind_rows(
  read_fw("timings-cedar.csv"),
  read_fw("timings-cosivina.csv"),
  read_fw("timings-dnfc.csv"),
  read_fw("timings-cosivina-python.csv")
)

summary_df <- timings %>%
  filter(mode == "headless") %>%
  group_by(framework, N) %>%
  summarise(
    median_sps = median(steps_per_second),
    min_sps    = min(steps_per_second),
    max_sps    = max(steps_per_second),
    .groups    = "drop"
  )

# ── Cosmetics ─────────────────────────────────────────────────────────────────

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

# ── Figure 1: throughput (log-log line chart) ─────────────────────────────────
#
# This is the standard plot for scalability benchmarks: it shows both the
# absolute throughput and how each framework degrades as N grows.

p_throughput <- ggplot(
  summary_df,
  aes(x = N, y = median_sps, colour = framework,
      shape = framework, linetype = framework, group = framework)
) +
  geom_ribbon(
    aes(ymin = min_sps, ymax = max_sps, fill = framework),
    alpha = 0.12, colour = NA
  ) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 3.5) +
  scale_x_log10(
    breaks = c(10, 50, 100, 500, 1000),
    labels = c("10", "50", "100", "500", "1 000")
  ) +
  scale_y_log10(labels = label_comma()) +
  scale_colour_manual(values = fw_colors, labels = fw_labels) +
  scale_fill_manual(values = fw_colors, labels = fw_labels, guide = "none") +
  scale_shape_manual(values = fw_shapes, labels = fw_labels) +
  scale_linetype_manual(values = fw_lty, labels = fw_labels) +
  labs(
    title    = "Simulation throughput",
    subtitle = "Steps per second · headless · median of 3 runs · ribbon = min–max",
    x        = "Number of independent neural fields (N)",
    y        = "Steps per second (log scale)",
    colour   = NULL, shape = NULL, linetype = NULL
  ) +
  theme_bw(base_size = 13) +
  theme(
    legend.position      = "bottom",
    legend.key.width     = unit(2, "cm"),
    legend.text          = element_text(size = 10),
    panel.grid.minor     = element_blank(),
    plot.title           = element_text(face = "bold"),
    plot.subtitle        = element_text(size = 10, colour = "grey40")
  ) +
  guides(colour   = guide_legend(nrow = 2),
         shape    = guide_legend(nrow = 2),
         linetype = guide_legend(nrow = 2))

ggsave(
  file.path(ROOT, "fig_benchmark_throughput.png"),
  p_throughput,
  width = 8, height = 5.5, dpi = 150
)
cat("Saved: fig_benchmark_throughput.png\n")

# ── Figure 2: speedup relative to Cosivina (grouped bar chart) ────────────────
#
# Speedup plots are the standard way to communicate relative performance.
# Each group of bars is one N value; bar height = how many times faster than
# Cosivina. The dashed line at y=1 marks the Cosivina baseline.

cosivina_ref <- summary_df %>%
  filter(framework == "cosivina") %>%
  select(N, ref_sps = median_sps)

speedup_df <- summary_df %>%
  filter(framework != "cosivina") %>%
  left_join(cosivina_ref, by = "N") %>%
  mutate(
    speedup   = median_sps / ref_sps,
    framework = factor(framework, levels = c("dnfc", "cedar", "cosivina-python"))
  )

speedup_colors <- fw_colors[c("dnfc", "cedar", "cosivina-python")]
speedup_labels <- fw_labels[c("dnfc", "cedar", "cosivina-python")]

p_speedup <- ggplot(
  speedup_df,
  aes(x = factor(N), y = speedup, fill = framework)
) +
  geom_col(position = position_dodge(width = 0.72), width = 0.65) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey30", linewidth = 0.6) +
  geom_text(
    aes(label = sprintf("%.2f×", speedup)),
    position = position_dodge(width = 0.72),
    vjust    = -0.4, size = 3, colour = "grey20"
  ) +
  scale_fill_manual(values = speedup_colors, labels = speedup_labels) +
  scale_y_continuous(
    breaks = c(0.5, 1, 1.5, 2, 2.5, 3, 3.5),
    labels = function(x) paste0(x, "×"),
    expand = expansion(mult = c(0, 0.12))
  ) +
  labs(
    title    = "Speedup relative to Cosivina (MATLAB)",
    subtitle = "Dashed line = Cosivina baseline (1×). Values > 1× are faster.",
    x        = "Number of independent neural fields (N)",
    y        = "Speedup (×)",
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
  width = 8, height = 5, dpi = 150
)
cat("Saved: fig_benchmark_speedup.png\n")

cat("\nDone. Add to README with:\n")
cat("  ![Throughput](benchmarking/fig_benchmark_throughput.png)\n")
cat("  ![Speedup](benchmarking/fig_benchmark_speedup.png)\n")
