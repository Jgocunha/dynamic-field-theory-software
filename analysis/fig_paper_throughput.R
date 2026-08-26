# fig_paper_throughput.R — unified 1D+2D throughput figure for the SoftwareX paper.
#
# Simulation throughput (steps/sec) vs N, for all four tested N (5, 10, 50, 100),
# faceted 1D | 2D (independent y-axes — 1D and 2D throughput differ by orders of
# magnitude, so a shared axis would flatten the 2D panel). dnf-composer is the
# top line in both panels at every N, since it is the fastest framework
# everywhere in the underlying data — no rescaling needed to show it winning.
#
# Representative field size per dimension (field=1000 / grid=500x500 — the
# largest of the three sizes benchmarked in each dimension, where the lateral
# convolution dominates the step and the cross-framework race is closest);
# each point is the mean across the four regimes (detection, selection,
# memory, multi-peak), with a min-max ribbon over that regime-to-regime spread
# (not a parametric CI: regime throughput is highly right-skewed — e.g. the
# cheap "detection" regime runs several times faster than "memory" for some
# frameworks — so a t-interval on n=4 skewed samples can swing the lower
# bound negative).
#
# Run from anywhere:
#   Rscript fig_paper_throughput.R
# Reads:
#   ../benchmarking/data/benchmark_summary.csv
#   ../benchmarking-2d/data/benchmark_summary.csv
# Writes:
#   fig_paper_throughput.png (next to this script)

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
# that entirely). --------------------------------------------------------

FONT_DIR <- "C:/Users/jgocunha/AppData/Local/Microsoft/Windows/Fonts"
font_add(
  family  = "EB Garamond",
  regular = file.path(FONT_DIR, "EBGaramond-VariableFont_wght.ttf"),
  bold    = file.path(FONT_DIR, "EBGaramond-SemiBold.ttf")
)
showtext_auto()
showtext_opts(dpi = 300)

# -- Data ------------------------------------------------------------------

FIELD_REF_1D <- 1000  # largest of the three 1D sizes benchmarked
FIELD_REF_2D <- 500   # largest of the three 2D sizes benchmarked (grid = 500x500)
ARCH_ORDER   <- c("detection", "selection", "memory", "multi-peak")

load_throughput <- function(csv_path, dim_label, field_size_val) {
  read_csv(csv_path, show_col_types = FALSE) %>%
    filter(mode == "headless", field_size == field_size_val, arch %in% ARCH_ORDER) %>%
    group_by(fwv, N) %>%
    summarise(
      mean_sps = mean(median_sps),
      lo_sps   = min(median_sps),
      hi_sps   = max(median_sps),
      .groups  = "drop"
    ) %>%
    mutate(dim = dim_label)
}

throughput_df <- bind_rows(
  load_throughput(file.path(ROOT, "benchmarking", "data", "benchmark_summary.csv"), "1D (field = 1000)", FIELD_REF_1D),
  load_throughput(file.path(ROOT, "benchmarking-2d", "data", "benchmark_summary.csv"), "2D (grid = 500×500)", FIELD_REF_2D)
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
    fwv = factor(fwv, levels = fw_order),
    dim = factor(dim, levels = c("1D (field = 1000)", "2D (grid = 500×500)"))
  )

# -- Figure ------------------------------------------------------------------

p <- ggplot(throughput_df, aes(x = N, y = mean_sps, colour = fwv, group = fwv)) +
  geom_ribbon(aes(ymin = lo_sps, ymax = hi_sps, fill = fwv), alpha = 0.12, colour = NA) +
  geom_line(aes(linewidth = fwv)) +
  geom_point(size = 1.7) +
  facet_wrap(~ dim, scales = "free_y") +
  scale_colour_manual(values = fw_colors, labels = fw_labels, name = NULL) +
  scale_fill_manual(values = fw_colors, guide = "none") +
  scale_linewidth_manual(values = fw_linewidth, guide = "none") +
  scale_x_log10(breaks = c(5, 10, 50, 100)) +
  scale_y_log10(labels = label_comma(accuracy = 1)) +
  labs(x = "Number of independent neural fields (N)", y = "Simulation steps per second") +
  theme_minimal(base_family = "EB Garamond", base_size = 12) +
  theme(
    axis.text           = element_text(size = 9),
    axis.title          = element_text(size = 11),
    panel.grid.minor    = element_blank(),
    strip.text          = element_text(size = 11, face = "bold"),
    panel.spacing       = unit(1.4, "lines"),
    legend.position     = "bottom",
    legend.text         = element_text(size = 9),
    legend.key.width    = unit(1.1, "cm"),
    plot.margin         = margin(10, 14, 6, 6)
  ) +
  guides(colour = guide_legend(nrow = 2, override.aes = list(linewidth = 1.3)))

ggsave(
  file.path(HERE, "fig_paper_throughput.png"),
  p, width = 7.6, height = 4.6, dpi = 300, bg = "white"
)
cat("Saved: fig_paper_throughput.png\n")

# showtext_auto() renders glyphs as vector outlines on any device (not just
# raster ones), so the default pdf() device (inferred from the extension)
# already gives correct, portable EB Garamond text without needing Cairo.
ggsave(
  file.path(HERE, "fig_paper_throughput.pdf"),
  p, width = 7.6, height = 4.6
)
cat("Saved: fig_paper_throughput.pdf\n")
