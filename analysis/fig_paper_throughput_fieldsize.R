# fig_paper_throughput_fieldsize.R — 1D+2D throughput figure, both field/grid
# sizes, for the SoftwareX paper.
#
# Companion to fig_paper_throughput.R (which fixes field=100/grid=100x100 and
# is left untouched). This version adds the field-size axis that figure omits:
# a 2x3 grid of panels — {1D, 2D} x {small, medium, large field/grid} — each
# showing simulation throughput (steps/sec) vs N (5, 10, 50, 100). dnf-composer
# is drawn bolder and is the top line in every panel at every N, since it is
# the fastest framework at every tested (dimension, size, N) combination in
# the underlying data.
#
# Sizes shown: 1D field in {100, 500, 1000}; 2D grid in {100x100, 200x200,
# 500x500} — the three sizes benchmarked in benchmarking/ and
# benchmarking-2d/. Each point is the mean across the four regimes (detection,
# selection, memory, multi-peak); the ribbon is the min-max range across
# regimes (not a parametric CI — see fig_paper_throughput.R's header for why).
#
# Run from anywhere:
#   Rscript fig_paper_throughput_fieldsize.R
# Reads:
#   ../benchmarking/data/benchmark_summary.csv
#   ../benchmarking-2d/data/benchmark_summary.csv
# Writes:
#   fig_paper_throughput_fieldsize.png (next to this script)

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(scales)
  library(showtext)
})

HERE <- tryCatch(
  dirname(rstudioapi::getSourceEditorContext()$path),
  error = function(e) normalizePath(".")
)
if (is.null(HERE) || HERE == "") HERE <- normalizePath(".")
ROOT <- normalizePath(file.path(HERE, ".."))

# -- Font: EB Garamond, loaded directly from file (font-enumeration APIs
# crash on this machine's font cache; font_add() with explicit paths sidesteps
# that entirely). Falls back to the system default serif font if EB Garamond
# isn't installed on this machine (the ttf files are user-specific, not
# bundled in the repo). --------------------------------------------------

FONT_CANDIDATES <- c(
  "C:/Users/jgocunha/AppData/Local/Microsoft/Windows/Fonts",
  file.path(Sys.getenv("LOCALAPPDATA"), "Microsoft/Windows/Fonts"),
  file.path(Sys.getenv("WINDIR"), "Fonts")
)
FONT_DIR <- Filter(function(d) {
  nzchar(d) &&
    file.exists(file.path(d, "EBGaramond-VariableFont_wght.ttf")) &&
    file.exists(file.path(d, "EBGaramond-SemiBold.ttf"))
}, FONT_CANDIDATES)

if (length(FONT_DIR) > 0) {
  FONT_FAMILY <- "EB Garamond"
  font_add(
    family  = FONT_FAMILY,
    regular = file.path(FONT_DIR[1], "EBGaramond-VariableFont_wght.ttf"),
    bold    = file.path(FONT_DIR[1], "EBGaramond-SemiBold.ttf")
  )
} else {
  FONT_FAMILY <- "serif"
  message("EB Garamond not found in any known font directory; falling back to '", FONT_FAMILY, "'.")
}
showtext_auto()
showtext_opts(dpi = 300)

# -- Data ------------------------------------------------------------------

ARCH_ORDER <- c("detection", "selection", "memory", "multi-peak")

# panel_label values are ordered so facet_wrap (fills left-to-right,
# top-to-bottom) lays out: [1D small, 1D medium, 1D large] / [2D small, 2D
# medium, 2D large].
PANEL_LEVELS <- c("1D, field = 100", "1D, field = 500", "1D, field = 1000",
                   "2D, grid = 100×100", "2D, grid = 200×200", "2D, grid = 500×500")

load_throughput <- function(csv_path, dim_label, field_size_val, panel_label) {
  read_csv(csv_path, show_col_types = FALSE) %>%
    filter(mode == "headless", field_size == field_size_val, arch %in% ARCH_ORDER) %>%
    group_by(fwv, N) %>%
    summarise(
      mean_sps = mean(median_sps),
      lo_sps   = min(median_sps),
      hi_sps   = max(median_sps),
      .groups  = "drop"
    ) %>%
    mutate(dim = dim_label, panel = panel_label)
}

throughput_df <- bind_rows(
  load_throughput(file.path(ROOT, "benchmarking", "data", "benchmark_summary.csv"), "1D", 100, PANEL_LEVELS[1]),
  load_throughput(file.path(ROOT, "benchmarking", "data", "benchmark_summary.csv"), "1D", 500, PANEL_LEVELS[2]),
  load_throughput(file.path(ROOT, "benchmarking", "data", "benchmark_summary.csv"), "1D", 1000, PANEL_LEVELS[3]),
  load_throughput(file.path(ROOT, "benchmarking-2d", "data", "benchmark_summary.csv"), "2D", 100, PANEL_LEVELS[4]),
  load_throughput(file.path(ROOT, "benchmarking-2d", "data", "benchmark_summary.csv"), "2D", 200, PANEL_LEVELS[5]),
  load_throughput(file.path(ROOT, "benchmarking-2d", "data", "benchmark_summary.csv"), "2D", 500, PANEL_LEVELS[6])
)

# -- Cosmetics: Okabe-Ito-derived, colour-blind-safe palette, matching the
# palette already used across this repo's benchmark figures. -------------

fw_order <- c("dnfc", "cedar (opencv)", "cedar (fftw)", "cosivina", "cosivina (fft)",
              "cosivina-python (numba)", "cosivina-python (nonumba)", "cosivina-python (fft)")

fw_labels <- c(
  "dnfc"                       = "dnf-composer",
  "cedar (opencv)"             = "Cedar (OpenCV)",
  "cedar (fftw)"               = "Cedar (FFTW)",
  "cosivina"                   = "Cosivina",
  "cosivina (fft)"             = "Cosivina (MATLAB, FFT)",
  "cosivina-python (numba)"    = "cosivina-python (numba)",
  "cosivina-python (nonumba)"  = "cosivina-python (NumPy)",
  "cosivina-python (fft)"      = "cosivina-python (FFT)"
)

fw_colors <- c(
  "dnfc"                       = "#0072B2",
  "cedar (opencv)"             = "#D55E00",
  "cedar (fftw)"               = "#E69F00",
  "cosivina"                   = "#009E73",
  "cosivina (fft)"             = "#44AA99",
  "cosivina-python (numba)"    = "#CC79A7",
  "cosivina-python (nonumba)"  = "#7B3294",
  "cosivina-python (fft)"      = "#882255"
)

fw_linewidth <- setNames(c(1.3, rep(0.7, 7)), fw_order)  # dnfc drawn bolder — it's the paper's subject

throughput_df <- throughput_df %>%
  mutate(
    fwv   = factor(fwv, levels = fw_order),
    panel = factor(panel, levels = PANEL_LEVELS)
  )

# -- Figure ------------------------------------------------------------------

p <- ggplot(throughput_df, aes(x = N, y = mean_sps, colour = fwv, group = fwv)) +
  geom_ribbon(aes(ymin = lo_sps, ymax = hi_sps, fill = fwv), alpha = 0.12, colour = NA) +
  geom_line(aes(linewidth = fwv)) +
  geom_point(size = 1.5) +
  facet_wrap(~ panel, nrow = 2, scales = "free_y") +
  scale_colour_manual(values = fw_colors, labels = fw_labels, name = NULL) +
  scale_fill_manual(values = fw_colors, guide = "none") +
  scale_linewidth_manual(values = fw_linewidth, guide = "none") +
  scale_x_log10(breaks = c(5, 10, 50, 100)) +
  scale_y_log10(labels = label_comma(accuracy = 1)) +
  labs(x = "Number of independent neural fields (N)", y = "Simulation steps per second") +
  theme_minimal(base_family = FONT_FAMILY, base_size = 12) +
  theme(
    axis.text           = element_text(size = 8.5),
    axis.title          = element_text(size = 11),
    panel.grid.minor    = element_blank(),
    strip.text          = element_text(size = 10.5, face = "bold"),
    panel.spacing       = unit(1.3, "lines"),
    legend.position     = "bottom",
    legend.text         = element_text(size = 9),
    legend.key.width    = unit(1.1, "cm"),
    plot.margin         = margin(10, 14, 6, 6)
  ) +
  guides(colour = guide_legend(nrow = 2, override.aes = list(linewidth = 1.3)))

ggsave(
  file.path(HERE, "fig_paper_throughput_fieldsize.png"),
  p, width = 11.5, height = 7.8, dpi = 300, bg = "white"
)
cat("Saved: fig_paper_throughput_fieldsize.png\n")

# showtext_auto() renders glyphs as vector outlines on any device (not just
# raster ones), so the default pdf() device (inferred from the extension)
# already gives correct, portable EB Garamond text without needing Cairo.
ggsave(
  file.path(HERE, "fig_paper_throughput_fieldsize.pdf"),
  p, width = 11.5, height = 7.8
)
cat("Saved: fig_paper_throughput_fieldsize.pdf\n")
