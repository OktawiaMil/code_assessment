# Question 3, Task 2: AE Visualizations
# Plot 1: Severity distribution by treatment (stacked bar)
# Plot 2: Top 10 AEs with 95% Clopper-Pearson CIs (forest plot)

library(ggplot2)
library(dplyr)
library(pharmaverseadam)
library(purrr)

log_dir <- file.path(here::here(), "question_3_tlg")
if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)

log_file <- file.path(log_dir, "02_create_avisualizations.log")

log_con <- file(log_file, open = "wt")

sink(log_con, split = TRUE)
sink(log_con, type = "message")

on.exit({
  # Close message sink first if active
  if (sink.number(type = "message") > 0) {
    sink(type = "message")
  }
  # Then close output sinks if active
  while (sink.number() > 0) {
    sink()
  }
  close(log_con)
}, add = TRUE)


cat("AE Visualizations Log\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Load and prep data ----
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

adae_teae <- adae |> 
  filter(TRTEMFL == "Y",
         # Filter to safety population only
         SAFFL == "Y")

# Filter to safety population only
adsl <- adsl |> 
  filter(SAFFL == "Y") 

cat("ADAE TEAEs:", nrow(adae_teae), "records\n")
cat("Total subjects in ADSL:", nrow(adsl), "\n\n")

output_dir <- file.path(here::here(), "output", "question_3_tlg")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Plot 1: Severity by treatment arm (stacked bar) ---
cat("AE severity distribution:\n")
print(table(adae_teae$AESEV, adae_teae$ACTARM))
cat("\n")

p1 <- ggplot(adae_teae, aes(x = ACTARM, fill = AESEV)) +
  geom_bar(position = "stack", width = 0.7) +
  scale_fill_manual(
    values = c("MILD" = "#F8766D", "MODERATE" = "#00BA38", "SEVERE" = "#619CFF"),
    name = "Severity/Intensity"
  ) +
  labs(
    title = "AE severity distribution by treatment",
    x = "Treatment Arm",
    y = "Count of AEs"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.text.x = element_text(size = 10),
    legend.position = "right"
  )

ggsave(
  file.path(output_dir, "ae_severity_by_treatment.png"),
  plot = p1, width = 12, height = 8
)
cat("Plot 1 saved: output/question_3_tlg/ae_severity_by_treatment.png\n\n")

# Plot 2: Top 10 AEs with 95% Clopper-Pearson CIs -----
n_total <- n_distinct(adsl$USUBJID)
cat("Total subjects for incidence calculation:", n_total, "\n")

# Check what are the top 10 AEs
ae_counts <- adae_teae |> 
  distinct(USUBJID, AETERM) |> 
  count(AETERM, name = "n_subjects") |> 
  arrange(desc(n_subjects)) |> 
  slice_head(n = 10)

cat("Top 10 AEs by frequency:\n")
print(ae_counts)
cat("\n")

# Incidence expressed in % + exact Clopper-Pearson CIs
ae_ci <- ae_counts |> 
  mutate(
    pct = n_subjects / n_total * 100,
    ci = map2(n_subjects, n_total, ~ binom.test(.x, .y, conf.level = 0.95)$conf.int),
    lower = map_dbl(ci, 1) * 100,
    upper = map_dbl(ci, 2) * 100
  ) |> 
  select(-ci)

p2 <- ggplot(ae_ci, aes(x = pct, y = reorder(AETERM, pct))) +
  geom_point(size = 3, color = "black") +
  geom_errorbar(
    aes(xmin = lower, xmax = upper),
    linewidth = 0.6, width = 0.25
  ) +
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = paste0("n = ", n_total, " subjects; 95% Clopper-Pearson CIs"),
    x = "Percentage of Patients (%)",
    y = NULL
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5, size = 10)
  )

ggsave(
  file.path(output_dir, "top10_ae_plot.png"),
  plot = p2, width = 12, height = 8
)
cat("Plot 2 saved: output/question_3_tlg/top10_ae_forest_plot.png\n")

cat("\nAE Visualizations Creation Complete\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

