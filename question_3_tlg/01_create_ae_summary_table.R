# Question 3, Task 1: AE Summary Table (FDA Table 10 style) using {gtsummary}
# Input:  pharmaverseadam::adae, pharmaverseadam::adsl
# Output: ae_summary_table.html

library(gtsummary)
library(dplyr)
library(pharmaverseadam)
library(gt)

log_dir <- file.path(here::here(), "question_3_tlg")
if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)

log_file <- file.path(log_dir, "01_create_ae_summary_table.log")

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

cat("AE Summary Table Creation Log\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Load data -----
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

cat("ADAE loaded:", nrow(adae), "rows\n")
cat("ADSL loaded:", nrow(adsl), "rows\n\n")

# Data prep ----
# Keep only TEAEs
adae_teae <- adae |> 
  filter(TRTEMFL == "Y",
         # Filter to safety population only
         SAFFL == "Y")

cat("Treatment-emergent AE records after filtering (TRTEMFL == 'Y'):", nrow(adae_teae), "\n")
cat("Unique subjects with TEAEs:", n_distinct(adae_teae$USUBJID), "\n")
cat("Treatment arms:", paste(unique(adae_teae$ACTARM), collapse = ", "), "\n\n")

# Filter to safety population only
adsl_safe <- adsl |> 
  filter(SAFFL == "Y") 

# Create table ----
ae_table <- adae_teae |> 
  tbl_hierarchical(
    variables = c(AESOC, AETERM),
    by = ACTARM,
    denominator = adsl_safe,
    id = USUBJID,
    include = c(AESOC, AETERM),
    overall_row = TRUE, 
    label = "..ard_hierarchical_overall.." ~ "Treatment Emergent AEs"
  ) |> 
  add_overall() |> 
  sort_hierarchical() |> 
  bold_labels() |> 
  modify_header(label ~ "**Primary System Organ Class\n    Reported Term for the Adverse Event**") |> 
  modify_caption("**Table: Summary of Treatment-Emergent Adverse Events**")

cat("AE summary table created successfully.\n")

# Export ----
output_dir <- file.path(here::here(), "output", "question_3_tlg")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

ae_table |> 
  as_gt() |> 
  gt::gtsave(file.path(output_dir, "ae_summary_table.html"))
cat("Table saved as: question_3_tlg/ae_summary_table.html\n")
cat("Final timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
