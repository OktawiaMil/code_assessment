# Question 1: SDTM DS Domain Creation using {sdtm.oak}
# Input: pharmaverseraw::ds_raw
# Output: ds_domain.csv

# Load libraries ----
library(sdtm.oak)
library(dplyr)
library(pharmaverseraw)
library(pharmaversesdtm)

# Logging
log_dir <- file.path(here::here(), "question_1_sdtm")
if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)

log_file <- file.path(log_dir, "01_create_ds_domain.log")

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

cat("DS Domain Creation Log\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Load raw data and DM (for USUBJID join later) ----
ds_raw <- pharmaverseraw::ds_raw
dm <- pharmaversesdtm::dm

cat("Raw DS data loaded:", nrow(ds_raw), "rows,", ncol(ds_raw), "columns\n")
cat("Column names:", paste(names(ds_raw), collapse = ", "), "\n")
cat("\nFirst few rows:\n")
print(head(ds_raw))

# Controlled terminology for Disposition Event (C66727)
# Maps collected values -> CDISC standard terms
# Downloaded from: 
# https://github.com/pharmaverse/examples/blob/main/metadata/sdtm_ct.csv
study_ct <- read.csv(file.path(
  here::here(),
  "input",
  "question_1_sdtm",
  "sdtm_ct.csv"
))

# oak_id_vars needed by all sdtm.oak mapping functions
ds_raw <- ds_raw |> 
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )

cat("\nOak ID vars generated. Columns now:\n")
print(names(ds_raw))

# Variable mapping---
ds_raw <- ds_raw |>
  mutate(
    # Following CRF:
    # if OTHERSP null then map IT.DSTERM to DSTERM
    # if OTHERSP not null - map OTHERSP to DSTERM
    DSTERM_raw = if_else(is.na(OTHERSP), IT.DSTERM, OTHERSP),
    # If OTHERSP not null - map it to DSDECOD
    # If OTHERSP null - map IT.DSDECOD to DSDECOD
    DSDECOD_raw = if_else(is.na(OTHERSP), IT.DSDECOD, OTHERSP),
    DSCAT_raw = case_when(
      IT.DSDECOD == "Randomized" ~ "PROTOCOL MILESTONE",
      !is.na(OTHERSP) ~"OTHER EVENT",
      .default = "DISPOSITION EVENT"
      ),
    DSDTC_raw = create_iso8601(DSDTCOL, DSTMCOL, .format = c("m-d-y", "H:M")) |> as.character()
  )

## DSTERM (topic variable) ----
ds <- assign_no_ct(
  raw_dat = ds_raw,
  raw_var = "DSTERM_raw",
  tgt_var = "DSTERM",
  id_vars = oak_id_vars()
)

## DSDECOD (coded term via C66727 CT) ----
ds <- ds |>
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "DSDECOD_raw",
    tgt_var = "DSDECOD",
    ct_spec = study_ct,
    ct_clst = "C66727"
  )

## DSCAT ----
ds <- ds |>
  assign_ct(
    raw_dat = ds_raw,  
    raw_var = "DSCAT_raw", 
    tgt_var = "DSCAT",
    ct_spec = study_ct,
    ct_clst = "C74558"
  )

## VISIT from INSTANCE ----
ds <- ds |>
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct,
    ct_clst = "VISIT"
  )


## DSDTC ----
ds <- ds |>
  assign_no_ct(
    raw_dat = ds_raw,
    raw_var = "DSDTC_raw",
    tgt_var = "DSDTC",
    id_vars = oak_id_vars()
  )

## DSSTDTC - disposition event start date ----
ds <- ds |>
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = "m-d-y"
  )

## VISITNUM - numeric version of VISIT ----
visit_num_lookup <- study_ct |> 
  filter(codelist_code == "VISITNUM") |> 
  select(term_value, collected_value) |> 
  left_join(
    study_ct |> 
      filter(codelist_code == "VISIT") |>
      select(term_value, collected_value) |> 
      rename(VISIT = term_value)
  ) |> 
  select(VISITNUM = term_value, VISIT)

ds <- ds |> 
  left_join(visit_num_lookup, by = "VISIT") |> 
  mutate(VISITNUM = as.numeric(VISITNUM))

## USUBJID ---- 
# following example from AE & made sure it's compatible with the outcome in pharmaversesdtm::dm
ds <- ds |>
  left_join(
    ds_raw |> select(oak_id, raw_source, patient_number, STUDY, PATNUM),
    by = c("oak_id", "raw_source", "patient_number")
  ) |>
  mutate(
    STUDYID = STUDY,
    DOMAIN  = "DS",
    USUBJID = paste0("01-", PATNUM)
  )

## DSSTDY - study day relative to RFSTDTC ----
ds <- derive_study_day(
  sdtm_in = ds,
  dm_domain = dm,
  tgdt = "DSSTDTC",
  refdt = "RFSTDTC",
  study_day_var = "DSSTDY"
)
 
## DSSEQ ----
# sequence number within subject, ordered by date/term
ds <- ds |>
  derive_seq(
    tgt_var = "DSSEQ",
    rec_vars = c("USUBJID", "DSSTDTC")
  )

# Final variable selection and ordering ----
ds_final <- ds |>
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ,
    DSTERM, DSDECOD, DSCAT,
    VISITNUM, VISIT,
    DSDTC, DSSTDTC, DSSTDY
  ) |>
  arrange(STUDYID, USUBJID, DSSEQ)

cat("Final DS Domain\n")
cat("Dimensions:", nrow(ds_final), "rows x", ncol(ds_final), "columns\n")
cat("Variables:", paste(names(ds_final), collapse = ", "), "\n\n")

# Save outputs ----
output_dir <- file.path(here::here(), "output", "question_1_sdtm")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

write.csv(ds_final, file = file.path(output_dir, "ds_domain.csv"),
          row.names = FALSE)

cat("DS Domain Creation Complete\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
