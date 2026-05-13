# fig_validation.R — Generate PNG figures for the cross-platform validation README
#
# Reads from pre-computed CSVs (produced by analysis.R) — no need to reload
# the 1 000+ raw simulation CSVs.
#
# Produces (saved to cross-platform-validation/):
#   fig_validation_equivalence.png — max|Δu| per pair vs. threshold (lollipop)
#   fig_validation_boxplots.png    — deviation boxplots by sim type × pair
#   fig_validation_heatmap.png     — log10 deviation heatmap (sim ID × pair)
#
# Run from cross-platform-validation/:
#   Rscript fig_validation.R

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

val_summary  <- read_csv(file.path(ROOT, "validation_summary.csv"),
                         show_col_types = FALSE)
analysis_sum <- read_csv(file.path(ROOT, "analysis_summary.csv"),
                         show_col_types = FALSE)

# ── Shared cosmetics ──────────────────────────────────────────────────────────

PAIR_LABELS <- c(
  cedar_abs_vs_dnfc_abs                 = "Cedar AbsSig\nvs dnfc AbsSig",
  cedar_hv_vs_dnfc_hv                   = "Cedar Heaviside\nvs dnfc Heaviside",
  cosivina_s100_vs_dnfc_s100            = "Cosivina Sigmoid\nvs dnfc Sigmoid",
  cosivina_python_s100_vs_dnfc_s100     = "cosivina-python Sigmoid\nvs dnfc Sigmoid",
  cosivina_python_s100_vs_cosivina_s100 = "cosivina-python Sigmoid\nvs Cosivina Sigmoid",
  cedar_abs_vs_cosivina_s100            = "Cedar AbsSig\nvs Cosivina Sigmoid"
)

# Same order for all figures: same-family first, cross-family last
PAIR_ORDER <- names(PAIR_LABELS)

SAME_FAMILY <- c(
  "cedar_abs_vs_dnfc_abs",
  "cedar_hv_vs_dnfc_hv",
  "cosivina_s100_vs_dnfc_s100",
  "cosivina_python_s100_vs_dnfc_s100",
  "cosivina_python_s100_vs_cosivina_s100"
)

TYPE_ORDER  <- c("detection", "selection", "memory", "insufficient", "multi_peak")
TYPE_LABELS <- c(
  detection    = "Detection",
  selection    = "Selection",
  memory       = "Memory",
  insufficient = "Insufficient",
  multi_peak   = "Multi-peak"
)

PHASE_COLORS  <- c(with_stimulus    = "#0072B2",   # blue
                   without_stimulus = "#D55E00")   # vermillion
PHASE_LABELS  <- c(with_stimulus    = "Phase 1 (stimulus ON)",
                   without_stimulus = "Phase 2 (stimulus OFF)")

# ── Figure 1: equivalence summary (lollipop chart) ───────────────────────────
#
# Each pair → observed max|Δu| vs. the applicable threshold.
# Immediately shows which pairs pass and by how much margin.

thresholds <- tibble(
  pair      = PAIR_ORDER,
  threshold = c(2e-4, 2e-4, 1e-4, 1e-4, 1e-4, NA_real_),
  family    = c("Same family", "Same family", "Same family",
                "Same family", "Same family", "Cross-family")
)

equiv_df <- val_summary %>%
  left_join(thresholds, by = "pair") %>%
  mutate(
    pair_label = factor(PAIR_LABELS[pair], levels = rev(PAIR_LABELS)),
    pass       = !is.na(algebraic_equiv) & algebraic_equiv,
    status     = case_when(
      is.na(algebraic_equiv) ~ "Cross-family\n(not tested)",
      pass                   ~ "PASS",
      TRUE                   ~ "FAIL"
    ),
    status = factor(status, levels = c("PASS", "FAIL", "Cross-family\n(not tested)"))
  )

STATUS_COLORS <- c(
  "PASS"                       = "#009E73",   # green
  "FAIL"                       = "#CC0000",   # red
  "Cross-family\n(not tested)" = "#999999"    # grey
)

p_equiv <- ggplot(equiv_df,
  aes(x = max_max_abs_diff, y = pair_label, colour = status)) +
  # segment from a very small value to observed max (lollipop stem)
  geom_segment(aes(x = 1e-16, xend = max_max_abs_diff,
                   y = pair_label, yend = pair_label),
               linewidth = 0.6) +
  # observed max
  geom_point(size = 4.5) +
  # threshold reference tick
  geom_point(aes(x = threshold), shape = 124, size = 8,
             colour = "grey20", na.rm = TRUE) +
  # threshold label (only once per unique threshold value)
  annotate("text", x = 2e-4, y = 5.55, label = "Float32\nthreshold\n(2×10⁻⁴)",
           size = 3, hjust = 0.5, colour = "grey30", lineheight = 0.9) +
  annotate("text", x = 1e-4, y = 3.55, label = "Float64\nthreshold\n(1×10⁻⁴)",
           size = 3, hjust = 0.5, colour = "grey30", lineheight = 0.9) +
  scale_x_log10(
    limits = c(1e-16, 5),
    breaks = c(1e-14, 1e-10, 1e-6, 1e-4, 1e-2, 1),
    labels = label_scientific()
  ) +
  scale_colour_manual(values = STATUS_COLORS) +
  labs(
    title    = "Algebraic equivalence: observed max |Δu| vs. threshold",
    subtitle = "Vertical tick (|) = applicable precision threshold. Dot = observed maximum deviation across all 200 comparisons.",
    x        = expression(max*"|"*Delta*u*"|"[max]*"  (log scale)"),
    y        = NULL,
    colour   = NULL
  ) +
  theme_bw(base_size = 13) +
  theme(
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold"),
    plot.subtitle    = element_text(size = 9, colour = "grey40")
  )

ggsave(file.path(ROOT, "fig_validation_equivalence.png"), p_equiv,
       width = 9, height = 5.5, dpi = 150)
cat("Saved: fig_validation_equivalence.png\n")

# ── Figure 2: deviation boxplots by simulation type × pair ───────────────────
#
# Reproduces the existing fig_boxplots.pdf as a PNG.
# Faceted by comparison pair (2 columns), x = sim type, fill = phase.

box_df <- analysis_sum %>%
  filter(!is.na(max_abs_diff), pair %in% PAIR_ORDER) %>%
  mutate(
    pair_label = factor(PAIR_LABELS[pair], levels = PAIR_LABELS[PAIR_ORDER]),
    type       = factor(TYPE_LABELS[type], levels = TYPE_LABELS[TYPE_ORDER]),
    phase      = factor(phase, levels = names(PHASE_LABELS))
  )

p_box <- ggplot(box_df,
  aes(x = type, y = max_abs_diff + 1e-16, fill = phase)) +
  geom_boxplot(outlier.size = 0.7, alpha = 0.85, linewidth = 0.4) +
  facet_wrap(~pair_label, ncol = 2, scales = "free_y") +
  scale_y_log10(labels = label_scientific()) +
  scale_fill_manual(values = PHASE_COLORS, labels = PHASE_LABELS) +
  labs(
    title    = "Pointwise deviation between frameworks",
    subtitle = "100 simulations × 5 architectures · y-axis is log-scaled and independent per panel",
    x        = "Simulation type",
    y        = expression(max*"|"*Delta*u*"|"),
    fill     = NULL
  ) +
  theme_bw(base_size = 11) +
  theme(
    axis.text.x      = element_text(angle = 30, hjust = 1, size = 9),
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    strip.text       = element_text(size = 9, lineheight = 1.1),
    plot.title       = element_text(face = "bold"),
    plot.subtitle    = element_text(size = 9, colour = "grey40")
  )

ggsave(file.path(ROOT, "fig_validation_boxplots.png"), p_box,
       width = 10, height = 8, dpi = 150)
cat("Saved: fig_validation_boxplots.png\n")

# ── Figure 3: deviation heatmap (sim ID × pair) ───────────────────────────────
#
# Reproduces the existing fig_deviation_heatmap.pdf as a PNG.
# Shows at a glance where deviations are large vs. negligible.
# Both phases shown side-by-side.

heat_df <- analysis_sum %>%
  filter(!is.na(max_abs_diff), pair %in% PAIR_ORDER) %>%
  mutate(
    log10_dev  = log10(pmax(max_abs_diff, 1e-16)),
    sim_num    = as.integer(sim_id),
    pair_label = factor(PAIR_LABELS[pair], levels = PAIR_LABELS[PAIR_ORDER]),
    phase_label = factor(
      ifelse(phase == "with_stimulus", "Phase 1: stimulus ON", "Phase 2: stimulus OFF"),
      levels = c("Phase 1: stimulus ON", "Phase 2: stimulus OFF")
    )
  )

# Colour scale limits: clip at float32 threshold on the high end
CLIM <- c(log10(1e-16), log10(2e-4))

p_heat <- ggplot(heat_df,
  aes(x = pair_label, y = sim_num, fill = log10_dev)) +
  geom_tile() +
  facet_wrap(~phase_label, ncol = 2) +
  scale_fill_viridis_c(
    name   = expression(log[10]*"|"*Delta*u*"|"[max]),
    option = "plasma",
    direction = -1,
    limits = CLIM,
    oob    = scales::squish,
    breaks = c(-16, -12, -8, -4, log10(1e-4)),
    labels = c("≤10⁻¹⁶", "10⁻¹²", "10⁻⁸", "10⁻⁴", "2×10⁻⁴")
  ) +
  scale_y_reverse(
    breaks = c(1, 20, 40, 60, 80, 100),
    labels = c("001", "020", "040", "060", "080", "100")
  ) +
  labs(
    title    = "Deviation heatmap: log₁₀ max |Δu| per simulation",
    subtitle = "Darker = smaller deviation (better agreement). Cross-family pair shows systematic difference.",
    x        = "Comparison pair",
    y        = "Simulation ID"
  ) +
  theme_bw(base_size = 11) +
  theme(
    axis.text.x      = element_text(angle = 30, hjust = 1, size = 8, lineheight = 0.9),
    legend.position  = "right",
    panel.grid       = element_blank(),
    strip.text       = element_text(face = "bold"),
    plot.title       = element_text(face = "bold"),
    plot.subtitle    = element_text(size = 9, colour = "grey40")
  )

ggsave(file.path(ROOT, "fig_validation_heatmap.png"), p_heat,
       width = 11, height = 6.5, dpi = 150)
cat("Saved: fig_validation_heatmap.png\n")

cat("\nDone. Add to README with:\n")
cat("  ![Equivalence](cross-platform-validation/fig_validation_equivalence.png)\n")
cat("  ![Boxplots](cross-platform-validation/fig_validation_boxplots.png)\n")
cat("  ![Heatmap](cross-platform-validation/fig_validation_heatmap.png)\n")
