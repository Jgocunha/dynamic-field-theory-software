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

col_nms  <- c("framework", "variant", "arch", "field_size", "mode", "N", "run", "steps_per_second")
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

ARCH_ORDER <- c("detection", "selection", "memory", "multi-peak")

make_fwv <- function(framework, variant) {
  ifelse(variant == "default", framework, paste0(framework, " (", variant, ")"))
}

read_fw <- function(f) {
  path <- file.path(ROOT, "data", f)
  if (!file.exists(path)) { message("File not found (skipping): ", path); return(NULL) }
  read_csv(path, col_names = col_nms, col_types = col_spec)
}

timings <- bind_rows(
  read_fw("timings-cedar.csv"),
  read_fw("timings-cosivina.csv"),
  read_fw("timings-dnfc.csv"),
  read_fw("timings-cosivina-python.csv")
) %>% mutate(fwv = make_fwv(framework, variant))

summary_df <- timings %>%
  filter(mode == "headless") %>%
  group_by(fwv, arch, field_size, N) %>%
  summarise(
    median_sps = median(steps_per_second),
    mean_sps   = mean(steps_per_second),
    min_sps    = min(steps_per_second),
    max_sps    = max(steps_per_second),
    # 95% CI on the mean (t-interval over the per-cell runs).
    ci95_lo    = ifelse(n() > 1, mean(steps_per_second) - qt(0.975, n()-1)*sd(steps_per_second)/sqrt(n()), median_sps),
    ci95_hi    = ifelse(n() > 1, mean(steps_per_second) + qt(0.975, n()-1)*sd(steps_per_second)/sqrt(n()), median_sps),
    .groups    = "drop"
  ) %>%
  mutate(arch = factor(arch, levels = intersect(ARCH_ORDER, unique(arch))),
         size_label = factor(sprintf("field=%d", field_size),
                             levels = sprintf("field=%d", sort(unique(field_size)))))

# ── Cosmetics ─────────────────────────────────────────────────────────────────

# Six framework-variant series. Colour-blind-friendly palette (Wong 2011 + 2 hues):
# the two Cedar variants share a warm family, the two cosivina-python variants a
# pink/purple family, so opencv/fftw and numba/nonumba read as related pairs.
fw_order  <- c("dnfc", "cedar", "cedar (fftw)", "cosivina",
               "cosivina-python", "cosivina-python (nonumba)")

fw_labels <- c(
  "dnfc"                       = "dnfc (C++, float64)",
  "cedar"                      = "Cedar (C++, float32, OpenCV)",
  "cedar (fftw)"               = "Cedar (C++, float32, FFTW)",
  "cosivina"                   = "Cosivina (MATLAB, float64)",
  "cosivina-python"            = "cosivina-python (numba)",
  "cosivina-python (nonumba)"  = "cosivina-python (pure NumPy)"
)

fw_colors <- c(
  "dnfc"                       = "#0072B2",   # blue
  "cedar"                      = "#D55E00",   # vermillion
  "cedar (fftw)"               = "#E69F00",   # orange (Cedar family)
  "cosivina"                   = "#009E73",   # green
  "cosivina-python"            = "#CC79A7",   # pink
  "cosivina-python (nonumba)"  = "#7B3294"    # purple (cpy family)
)

fw_shapes <- c(
  "dnfc"                       = 16,  # circle
  "cedar"                      = 17,  # triangle
  "cedar (fftw)"               = 2,   # open triangle
  "cosivina"                   = 15,  # square
  "cosivina-python"            = 18,  # diamond
  "cosivina-python (nonumba)"  = 5    # open diamond
)

fw_lty <- c(
  "dnfc"                       = "solid",
  "cedar"                      = "solid",
  "cedar (fftw)"               = "dashed",
  "cosivina"                   = "dashed",
  "cosivina-python"            = "dotted",
  "cosivina-python (nonumba)"  = "dotdash"
)

summary_df <- summary_df %>%
  mutate(fwv = factor(fwv, levels = intersect(fw_order, unique(fwv))))

# ── Figure 1: throughput vs N, faceted by architecture ────────────────────────
#
# One panel per architecture. Within a panel, each line is a framework variant:
# absolute throughput and how it degrades as N grows. Lets the reader see how the
# ranking shifts across architectures (e.g. the Mexican-hat "memory" regime, where
# Cedar/FFTW pulls away from Cedar/OpenCV).

p_throughput <- ggplot(
  summary_df,
  aes(x = N, y = median_sps, colour = fwv,
      shape = fwv, linetype = fwv, group = fwv)
) +
  geom_ribbon(
    aes(ymin = ci95_lo, ymax = ci95_hi, fill = fwv),
    alpha = 0.15, colour = NA
  ) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2.6) +
  facet_grid(arch ~ size_label, scales = "free_y") +
  scale_x_log10(
    breaks = c(5, 10, 50, 100, 500, 1000),
    labels = c("5", "10", "50", "100", "500", "1k")
  ) +
  scale_y_log10(labels = label_comma()) +
  scale_colour_manual(values = fw_colors, labels = fw_labels) +
  scale_fill_manual(values = fw_colors, labels = fw_labels, guide = "none") +
  scale_shape_manual(values = fw_shapes, labels = fw_labels) +
  scale_linetype_manual(values = fw_lty, labels = fw_labels) +
  labs(
    title    = "Simulation throughput by architecture",
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
  guides(colour   = guide_legend(nrow = 3),
         shape    = guide_legend(nrow = 3),
         linetype = guide_legend(nrow = 3))

ggsave(
  file.path(ROOT, "fig_benchmark_throughput.png"),
  p_throughput,
  width = 9, height = 7, dpi = 150
)
cat("Saved: fig_benchmark_throughput.png\n")

# ── Figure 2: per-architecture speedup vs Cosivina, at a representative N ──────
#
# Bar height = how many times faster than Cosivina at the largest N shared by all
# architectures (the realism matrix runs 10/50/100). Grouped by architecture so
# the reader sees how the speedup depends on the workload.

ref_N <- 100
cosivina_ref <- summary_df %>%
  filter(fwv == "cosivina", N == ref_N) %>%
  select(arch, field_size, ref_sps = median_sps)

speedup_order <- setdiff(fw_order, "cosivina")
speedup_df <- summary_df %>%
  filter(fwv != "cosivina", N == ref_N) %>%
  inner_join(cosivina_ref, by = c("arch", "field_size")) %>%
  mutate(
    speedup    = median_sps / ref_sps,
    speedup_lo = ci95_lo / ref_sps,
    speedup_hi = ci95_hi / ref_sps,
    fwv        = factor(fwv, levels = intersect(speedup_order, unique(fwv)))
  )

speedup_colors <- fw_colors[intersect(speedup_order, names(fw_colors))]
speedup_labels <- fw_labels[intersect(speedup_order, names(fw_labels))]

if (nrow(speedup_df) > 0) {
  p_speedup <- ggplot(
    speedup_df,
    aes(x = arch, y = speedup, fill = fwv)
  ) +
    geom_col(position = position_dodge(width = 0.78), width = 0.7) +
    geom_errorbar(
      aes(ymin = speedup_lo, ymax = speedup_hi),
      position = position_dodge(width = 0.78), width = 0.25,
      linewidth = 0.4, colour = "grey25"
    ) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "grey30", linewidth = 0.6) +
    facet_wrap(~ size_label, ncol = 2, scales = "free_y") +
    geom_text(
      aes(label = sprintf("%.1f×", speedup)),
      position = position_dodge(width = 0.78),
      vjust    = -0.4, size = 2.7, colour = "grey20"
    ) +
    scale_fill_manual(values = speedup_colors, labels = speedup_labels) +
    scale_y_continuous(
      labels = function(x) paste0(x, "×"),
      expand = expansion(mult = c(0, 0.12))
    ) +
    labs(
      title    = sprintf("Speedup relative to Cosivina (MATLAB), N=%d", ref_N),
      subtitle = "Dashed line = Cosivina baseline (1×). Values > 1× are faster.",
      x        = "Architecture",
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
    width = 9, height = 5, dpi = 150
  )
  cat("Saved: fig_benchmark_speedup.png\n")
} else {
  message("No Cosivina rows at N=", ref_N, " — skipping speedup figure.")
}

cat("\nDone. Add to README with:\n")
cat("  ![Throughput](benchmarking/fig_benchmark_throughput.png)\n")
cat("  ![Speedup](benchmarking/fig_benchmark_speedup.png)\n")
