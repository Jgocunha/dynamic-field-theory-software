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
  library(showtext)
})

ROOT <- tryCatch(
  dirname(rstudioapi::getSourceEditorContext()$path),
  error = function(e) normalizePath(".")
)
if (is.null(ROOT) || ROOT == "") ROOT <- normalizePath(".")

# -- Font: EB Garamond, matching the style used in .claude/paper's figures.
# Loaded directly from file (font-enumeration APIs crash on this machine's
# font cache; font_add() with explicit paths sidesteps that entirely). ------

FONT_DIR <- "C:/Users/jgocunha/AppData/Local/Microsoft/Windows/Fonts"
font_add(
  family  = "EB Garamond",
  regular = file.path(FONT_DIR, "EBGaramond-VariableFont_wght.ttf"),
  bold    = file.path(FONT_DIR, "EBGaramond-SemiBold.ttf")
)
showtext_auto()
showtext_opts(dpi = 150)

# -- Data ----------------------------------------------------------------------

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
  # "opencv"/"numba" are each framework's primary variant, matching the bare
  # "cedar"/"cosivina-python" keys in fw_labels/fw_colors/fw_shapes/fw_lty below.
  ifelse(variant %in% c("default", "opencv", "numba"), framework, paste0(framework, " (", variant, ")"))
}

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
) %>% mutate(fwv = make_fwv(framework, variant))

summary_df <- timings %>%
  filter(mode == "headless") %>%
  group_by(fwv, arch, field_size, N) %>%
  summarise(
    median_sps = median(steps_per_second),
    mean_sps   = mean(steps_per_second),
    min_sps    = min(steps_per_second),
    max_sps    = max(steps_per_second),
    ci95_lo    = ifelse(n() > 1, mean(steps_per_second) - qt(0.975, n()-1)*sd(steps_per_second)/sqrt(n()), median_sps),
    ci95_hi    = ifelse(n() > 1, mean(steps_per_second) + qt(0.975, n()-1)*sd(steps_per_second)/sqrt(n()), median_sps),
    .groups    = "drop"
  ) %>%
  mutate(arch = factor(arch, levels = intersect(ARCH_ORDER, unique(arch))),
         size_label = factor(sprintf("grid=%dx%d", field_size, field_size),
                             levels = sprintf("grid=%dx%d", sort(unique(field_size)), sort(unique(field_size)))))

# -- Cosmetics -----------------------------------------------------------------

# Eight framework-variant series (matches ../benchmarking/fig_benchmark.R).
fw_order  <- c("dnfc", "cedar", "cedar (fftw)", "cosivina", "cosivina (fft)",
               "cosivina-python", "cosivina-python (nonumba)", "cosivina-python (fft)")

fw_labels <- c(
  "dnfc"                       = "dnfc (C++, float64)",
  "cedar"                      = "Cedar (C++, float32, OpenCV)",
  "cedar (fftw)"               = "Cedar (C++, float32, FFTW)",
  "cosivina"                   = "Cosivina (MATLAB, float64)",
  "cosivina (fft)"             = "Cosivina (MATLAB, FFT)",
  "cosivina-python"            = "cosivina-python (numba)",
  "cosivina-python (nonumba)"  = "cosivina-python (pure NumPy)",
  "cosivina-python (fft)"      = "cosivina-python (FFT, NumPy)"
)

fw_colors <- c(
  "dnfc"                       = "#0072B2",
  "cedar"                      = "#D55E00",
  "cedar (fftw)"               = "#E69F00",
  "cosivina"                   = "#009E73",
  "cosivina (fft)"             = "#44AA99",
  "cosivina-python"            = "#CC79A7",
  "cosivina-python (nonumba)"  = "#7B3294",
  "cosivina-python (fft)"      = "#882255"
)

fw_shapes <- c(
  "dnfc"                       = 16,
  "cedar"                      = 17,
  "cedar (fftw)"               = 2,
  "cosivina"                   = 15,
  "cosivina (fft)"             = 0,
  "cosivina-python"            = 18,
  "cosivina-python (nonumba)"  = 5,
  "cosivina-python (fft)"      = 8
)

fw_lty <- c(
  "dnfc"                       = "solid",
  "cedar"                      = "solid",
  "cedar (fftw)"               = "dashed",
  "cosivina"                   = "dashed",
  "cosivina (fft)"             = "dotdash",
  "cosivina-python"            = "dotted",
  "cosivina-python (nonumba)"  = "dotdash",
  "cosivina-python (fft)"      = "longdash"
)

summary_df <- summary_df %>%
  mutate(fwv = factor(fwv, levels = intersect(fw_order, unique(fwv))))

# -- Figure 1: throughput vs N, faceted by architecture (2D) -------------------

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
    title    = "Simulation throughput by architecture (2D)",
    subtitle = "Steps per second · headless · point = median · ribbon = 95% CI of the mean",
    x        = "Number of independent neural fields (N)",
    y        = "Steps per second (log scale)",
    caption  = "Each row (architecture) has an independent y-axis (facet scales = \"free_y\")",
    colour   = NULL, shape = NULL, linetype = NULL
  ) +
  theme_minimal(base_family = "EB Garamond", base_size = 12) +
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
  width = 9, height = 7, dpi = 150, bg = "white"
)
cat("Saved: fig_benchmark_throughput.png\n")

# -- Figure 2: per-architecture speedup vs Cosivina, at a representative N ------

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
      aes(label = sprintf("%.1fx", speedup)),
      position = position_dodge(width = 0.78),
      vjust    = -0.4, size = 2.7, colour = "grey20", family = "EB Garamond"
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
      caption  = "Each field-size panel has an independent y-axis (facet scales = \"free_y\")",
      fill     = NULL
    ) +
    theme_minimal(base_family = "EB Garamond", base_size = 13) +
    theme(
      legend.position      = "bottom",
      legend.text          = element_text(size = 10),
      panel.grid.minor     = element_blank(),
      panel.grid.major.x   = element_blank(),
      plot.title           = element_text(face = "bold"),
      plot.subtitle        = element_text(size = 10, colour = "grey40")
    ) +
    guides(fill = guide_legend(nrow = 2))

  ggsave(
    file.path(ROOT, "fig_benchmark_speedup.png"),
    p_speedup,
    width = 9, height = 5, dpi = 150, bg = "white"
  )
  cat("Saved: fig_benchmark_speedup.png\n")
} else {
  message("No Cosivina rows at N=", ref_N, " — skipping speedup figure.")
}

cat("\nDone.\n")
