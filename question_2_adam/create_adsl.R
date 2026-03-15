# Question 2: ADaM ADSL (Subject-Level Analysis Dataset) Creation using {admiral}
# Derives AGEGR9, AGEGR9N, TRTSDTM, TRTSTMF, ITTFL, LSTAVLDT from SDTM sources
# Input:  pharmaversesdtm::dm, vs, ex, ds, ae
# Output: adsl.csv
library(admiral)
library(dplyr, warn.conflicts = FALSE)
library(pharmaversesdtm)
library(lubridate)
library(stringr)
library(here)

log_dir <- file.path(here::here(), "question_2_adam")
if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)

log_file <- file.path(log_dir, "create_adsl.log")

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

cat("ADSL Creation Log\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Load SDTM sources & convert SAS-style blanks to NA
dm <- pharmaversesdtm::dm
vs <- pharmaversesdtm::vs
ex <- pharmaversesdtm::ex
ds <- pharmaversesdtm::ds
ae <- pharmaversesdtm::ae


dm <- convert_blanks_to_na(dm)
vs <- convert_blanks_to_na(vs)
ex <- convert_blanks_to_na(ex)
ds <- convert_blanks_to_na(ds)
ae <- convert_blanks_to_na(ae)


cat("Datasets loaded:\n")
cat("  DM:", nrow(dm), "rows\n")
cat("  VS:", nrow(vs), "rows\n")
cat("  EX:", nrow(ex), "rows\n")
cat("  DS:", nrow(ds), "rows\n")
cat("  AE:", nrow(ae), "rows\n\n")

# Custom functions ----
# Unless differently specified in the PDF document, I follow admiral vignette
format_racegr1 <- function(x) {
  case_when(
    x == "WHITE" ~ "White",
    x != "WHITE" ~ "Non-white",
    TRUE ~ "Missing"
  )
}

format_region1 <- function(x) {
  case_when(
    x %in% c("CAN", "USA") ~ "NA",
    !is.na(x) ~ "RoW",
    TRUE ~ "Missing"
  )
}

format_lddthgr1 <- function(x) {
  case_when(
    x <= 30 ~ "<= 30",
    x > 30 ~ "> 30",
    TRUE ~ NA_character_
  )
}

# EOSSTT mapping
format_eosstt <- function(x) {
  case_when(
    x %in% c("COMPLETED") ~ "COMPLETED",
    x %in% c("SCREEN FAILURE") ~ NA_character_,
    !is.na(x) ~ "DISCONTINUED",
    TRUE ~ "ONGOING"
  )
}

# Derive variables ----
# Start ADSL from DM (dropping DOMAIN)
adsl <- dm |> 
  select(-DOMAIN)

## AGEGR1 & AGEGR1N ----
agegr1_lookup <- exprs(
  ~condition,            ~AGEGR1, ~AGEGR1N,
  is.na(AGE),    NA_character_, NA_integer_,
  AGE < 18,                "<18",        1,
  between(AGE, 18, 50),  "18-50",        2,
  !is.na(AGE),             ">50",        3
)

adsl <- derive_vars_cat(
  dataset = adsl,
  definition = agegr1_lookup
)

# To my understanding, AGEGR1N should be numeric:
adsl <- adsl |>
  mutate(AGEGR1N = as.integer(AGEGR1N))

# ITTFL (Y if ARM is populated) ---
adsl <- adsl |> 
  mutate(
    ITTFL = if_else(!is.na(ARM), "Y", "N")
  )

# To my understanding, we don't have Period, Subperiod, and Phase Variables 

## Treatment variables (TRT01P, TRT01A) ----
adsl <- adsl |> 
  mutate(TRT01P = ARM, TRT01A = ACTARM) 

## Prepare time columns ----
# Impute missing time with 00:00:00, but don't flag if only seconds were missing.
ex_ext <- ex |> 
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",
    highest_imputation = "h",
    time_imputation = "first",
    flag_imputation = "auto",
    ignore_seconds_flag = TRUE #do not flag only imputed seconds
  ) |> 
  derive_vars_dtm(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    highest_imputation = "h",
    time_imputation = "last",
    flag_imputation = "auto",
    ignore_seconds_flag = TRUE
  )

## TRTSDTM ---
adsl <- adsl |> 
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 |
      (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) &
      !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  )

## TRTEDTM - treatment end date ----
adsl <- adsl |> 
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 |
                    (EXDOSE == 0 &
                       str_detect(EXTRT, "PLACEBO"))) & !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID) 
  ) |> 
  # following admiral vignette:
  ## Derive treatment end/start date TRTSDT/TRTEDT ----
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM)) |> 
  ## Derive treatment duration (TRTDURD) ----
  derive_var_trtdurd()

## Disposition dates, status ----
# following admiral vignette:
ds_ext <- derive_vars_dt(
  ds,
  dtc = DSSTDTC,
  new_vars_prefix = "DSST"
)

# Screen fail date
adsl <- adsl |> 
  derive_vars_merged(
    dataset_add = ds_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(SCRFDT = DSSTDT),
    filter_add = DSCAT == "DISPOSITION EVENT" & DSDECOD == "SCREEN FAILURE"
  ) |> 
  derive_vars_merged(
    dataset_add = ds_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(EOSDT = DSSTDT),
    filter_add = DSCAT == "DISPOSITION EVENT" & DSDECOD != "SCREEN FAILURE"
  ) |> 
  # EOS status
  derive_vars_merged(
    dataset_add = ds_ext,
    by_vars = exprs(STUDYID, USUBJID),
    filter_add = DSCAT == "DISPOSITION EVENT",
    new_vars = exprs(EOSSTT = format_eosstt(DSDECOD)),
    missing_values = exprs(EOSSTT = "ONGOING")
  ) |> 
  # Last retrieval date
  derive_vars_merged(
    dataset_add = ds_ext,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(FRVDT = DSSTDT),
    filter_add = DSCAT == "OTHER EVENT" & DSDECOD == "FINAL RETRIEVAL VISIT"
  ) |> 
  # Derive Randomization Date
  derive_vars_merged(
    dataset_add = ds_ext,
    filter_add = DSDECOD == "RANDOMIZED",
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(RANDDT = DSSTDT)
  ) |> 
  # Death date - impute partial date to first day/month
  derive_vars_dt(
    new_vars_prefix = "DTH",
    dtc = DTHDTC,
    highest_imputation = "M",
    date_imputation = "first"
  ) |> 
  # Relative Day of Death
  derive_vars_duration(
    new_var = DTHADY,
    start_date = TRTSDT,
    end_date = DTHDT
  ) |> 
  # Elapsed Days from Last Dose to Death
  derive_vars_duration(
    new_var = LDDTHELD,
    start_date = TRTEDT,
    end_date = DTHDT,
    add_one = FALSE
  ) |> 
  # Cause of Death and Traceability Variables
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      event(
        dataset_name = "ae",
        condition = AEOUT == "FATAL",
        set_values_to = exprs(DTHCAUS = AEDECOD, DTHDOM = DOMAIN),
      ),
      event(
        dataset_name = "ds",
        condition = DSDECOD == "DEATH" & grepl("DEATH DUE TO", DSTERM),
        set_values_to = exprs(DTHCAUS = DSTERM, DTHDOM = DOMAIN),
      )
    ),
    source_datasets = list(ae = ae, ds = ds),
    tmp_event_nr_var = event_nr,
    order = exprs(event_nr),
    mode = "first",
    new_vars = exprs(DTHCAUS = DTHCAUS, DTHDOM = DTHDOM)
  ) |> 
  # Death Cause Category
  mutate(DTHCGR1 = case_when(
    is.na(DTHDOM) ~ NA_character_,
    DTHDOM == "AE" ~ "ADVERSE EVENT",
    str_detect(DTHCAUS, "(PROGRESSIVE DISEASE|DISEASE RELAPSE)") ~ "PROGRESSIVE DISEASE",
    TRUE ~ "OTHER"
  ))


## LSTAVLDT (last known alive date) ----
# following the rules described in the PDF document
adsl <- adsl |> 
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      # VS - last date with valid result
      event(
        dataset_name = "vs",
        condition = (!is.na(VSSTRESN) | !is.na(VSSTRESC)) & !is.na(VSDTC),
        set_values_to = exprs(
          LSTAVLDT = convert_dtc_to_dt(VSDTC)
        )
      ),
      # AE onset
      event(
        dataset_name = "ae",
        condition = !is.na(AESTDTC),
        set_values_to = exprs(
          LSTAVLDT = convert_dtc_to_dt(AESTDTC)
        )
      ),
      # DS
      event(
        dataset_name = "ds",
        condition = !is.na(DSSTDTC),
        set_values_to = exprs(
          LSTAVLDT = convert_dtc_to_dt(DSSTDTC)
        )
      ),
      # Treatment end (already in ADSL)
      event(
        dataset_name = "adsl",
        condition = !is.na(TRTEDT),
        set_values_to = exprs(
          LSTAVLDT = TRTEDT
        )
      )
    ),
    source_datasets = list(vs = vs, ae = ae, ds = ds, adsl = adsl),
    order = exprs(LSTAVLDT),
    mode = "last",
    check_type = "none",
    new_vars = exprs(LSTAVLDT)
  )


# following admiral vignette:
ads <- adsl |> 
  derive_var_merged_exist_flag(
    dataset_add = ex,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = SAFFL,
    false_value = "N",
    missing_value = "N",
    condition = (EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO")))
  ) |> 
  mutate(
    RACEGR1 = format_racegr1(RACE),
    REGION1 = format_region1(COUNTRY),
    LDDTHGR1 = format_lddthgr1(LDDTHELD),
    DTH30FL = if_else(LDDTHGR1 == "<= 30", "Y", NA_character_),
    DTHA30FL = if_else(LDDTHGR1 == "> 30", "Y", NA_character_),
    DTHB30FL = if_else(DTHDT <= TRTSDT + 30, "Y", NA_character_),
    DOMAIN = NULL
  )

# Review final dataset
cat("Final ADSL Dataset\n")
cat("Dimensions:", nrow(adsl), "rows x", ncol(adsl), "columns\n")
cat("All variables:", paste(names(adsl), collapse = ", "), "\n\n")


# Save ----
output_dir <- file.path(here::here(), "output", "question_2_adam")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

output_file <- file.path(output_dir, "adsl.csv")
write.csv(adsl, file = output_file, row.names = FALSE)

cat("Dataset saved as:", output_file, "\n")
cat("Final timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
