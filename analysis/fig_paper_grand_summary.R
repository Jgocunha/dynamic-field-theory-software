# fig_paper_grand_summary.R — grand-summary throughput bar chart per
# dimension, for the SoftwareX paper.
#
# Companion to fig_paper_throughput.R / fig_paper_throughput_fieldsize.R
# (both left untouched). Those show throughput as a function of N (and, in
# the fieldsize version, of field/grid size too); this one compresses all of
# that into a single mean + error bar per framework per dimension, so the
# headline "who's fastest overall" comparison reads at a glance.
#
# Each bar = mean simulation throughput (steps/sec) across EVERY tested
# configuration in that dimension: all three field/grid sizes x all four N
# (5, 10, 50, 100) x all four regimes (detection, selection, memory,
# multi-peak) — up to 48 samples per framework per dimension. The error bar
# is the min-max range across that same pool, so it reflects the full spread
# the benchmark actually covers (size effects, N-scaling, and regime
# variation all folded together) rather than isolating any one factor.
#
# dnf-composer is the tallest bar in both panels, since it is the fastest
# framework in every single tested (dimension, size, N, regime) combination
# in the underlying data.
#
# Run from anywhere:
#   Rscript fig_paper_grand_summary.R
# Reads:
#   ../benchmarking/data/benchmark_summary.csv
#   ../benchmarking-2d/data/benchmark_summary.csv
# Writes:
#   fig_paper_grand_summary.png (next to this script)

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

load_summary <- function(csv_path, dim_label) {
  read_csv(csv_path, show_col_types = FALSE) %>%
    filter(mode == "headless", arch %in% ARCH_ORDER) %>%
    group_by(fwv) %>%
    summarise(
      mean_sps = mean(median_sps),
      lo_sps   = min(median_sps),
      hi_sps   = max(median_sps),
      n_obs    = n(),
      .groups  = "drop"
    ) %>%
    mutate(dim = dim_label)
}

summary_df <- bind_rows(
  load_summary(file.path(ROOT, "benchmarking", "data", "benchmark_summary.csv"), "1D"),
  load_summary(file.path(ROOT, "benchmarking-2d", "data", "benchmark_summary.csv"), "2D")
)

# -- Cosmetics: Okabe-Ito-derived, colour-blind-safe palette, matching the
# palette already used across this repo's benchmark figures. -------------

fw_order <- c("dnfc", "cedar (opencv)", "cedar (fftw)", "cosivina", "cosivina (fft)",
              "cosivina-python (numba)", "cosivina-python (nonumba)", "cosivina-python (fft)")

fw_labels <- c(
  "dnfc"                       = "dnf-composer",
  "cedar (opencv)"             = "Cedar\n(OpenCV)",
  "cedar (fftw)"               = "Cedar\n(FFTW)",
  "cosivina"                   = "Cosivina",
  "cosivina (fft)"             = "Cosivina\n(MATLAB, FFT)",
  "cosivina-python (numba)"    = "cosivina-python\n(numba)",
  "cosivina-python (nonumba)"  = "cosivina-python\n(NumPy)",
  "cosivina-python (fft)"      = "cosivina-python\n(FFT)"
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

summary_df <- summary_df %>%
  mutate(
    fwv = factor(fwv, levels = fw_order),
    dim = factor(dim, levels = c("1D", "2D"))
  )

# -- Figure ------------------------------------------------------------------

p <- ggplot(summary_df, aes(x = fwv, y = mean_sps, fill = fwv)) +
  geom_col(width = 0.68, colour = NA) +
  geom_errorbar(aes(ymin = lo_sps, ymax = hi_sps), width = 0.22, linewidth = 0.4, colour = "grey30") +
  geom_text(
    aes(y = hi_sps, label = label_comma(accuracy = 1)(round(mean_sps))),
    vjust = -0.6, size = 2.9, family = FONT_FAMILY, colour = "grey15"
  ) +
  facet_wrap(~ dim, scales = "free_y") +
  scale_fill_manual(values = fw_colors, guide = "none") +
  scale_x_discrete(labels = fw_labels) +
  scale_y_log10(labels = label_comma(accuracy = 1), expand = expansion(mult = c(0.02, 0.16))) +
  labs(x = NULL, y = "Simulation steps per second") +
  theme_minimal(base_family = FONT_FAMILY, base_size = 12) +
  theme(
    axis.text.x         = element_text(angle = 30, hjust = 1, size = 8.5),
    axis.text.y         = element_text(size = 9),
    axis.title.y        = element_text(size = 11, margin = margin(r = 8)),
    panel.grid.minor    = element_blank(),
    panel.grid.major.x  = element_blank(),
    strip.text          = element_text(size = 11, face = "bold"),
    panel.spacing       = unit(1.6, "lines"),
    plot.margin         = margin(10, 14, 6, 6)
  )

ggsave(
  file.path(HERE, "fig_paper_grand_summary.png"),
  p, width = 8.2, height = 4.6, dpi = 300, bg = "white"
)
cat("Saved: fig_paper_grand_summary.png\n")

# showtext_auto() renders glyphs as vector outlines on any device (not just
# raster ones), so the default pdf() device (inferred from the extension)
# already gives correct, portable EB Garamond text without needing Cairo.
ggsave(
  file.path(HERE, "fig_paper_grand_summary.pdf"),
  p, width = 8.2, height = 4.6
)
cat("Saved: fig_paper_grand_summary.pdf\n")

cat("n_obs per bar (should be up to 48 = 3 sizes x 4 N x 4 regimes):\n")
print(summary_df %>% select(dim, fwv, n_obs))
