# TODO: remove when done with coding
install.packages(c("admiral", "sdtm.oak", "gt", "ggplot2", "pharmaverseraw"))
install.packages("readr")
renv::snapshot()


# Load libraries
library(pharmaverseraw)
library(sdtm.oak)
library(dplyr)
library(readr)

# Load data
ds_raw <- pharmaverseraw::ds_raw
ds_raw |> skimr::skim()

# Load controlled terminology table
study_ct <- read_csv(file.path(
  here::here(),
  "input",
  "question_1",
  "sdtm_ct.csv"
))
study_ct |> skimr::skim()

# Create oak_id_vars
data_raw <- ds_raw |>
  generate_oak_id_vars(
    pat_var = "PATNUM",
    raw_src = "ds_raw"
  )


# Outcome should have: STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT, VISITNUM, VISIT, DSDTC,
# DSSTDTC, DSSTDY
ds_data <- assign_no_ct(
  raw_dat = data_raw,
  raw_var = "IT.DSTERM",
  tgt_var = "DSTERM",
  id_vars = oak_id_vars()
)


ds_data <- ds_data |>
  assign_ct(
    raw_dat = data_raw,
    raw_var = "IT.DSTERM",
    tgt_var = "DSDECOD",
    ct_spec = study_ct,
    ct_clst = "C66727" # Based on the result: study_ct |> filter(collected_value == "Adverse Event")
  ) |>
  assign_no_ct(
    raw_dat = data_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    id_vars = oak_id_vars()
  ) |>
  assign_no_ct(
    raw_dat = data_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    id_vars = oak_id_vars()
  ) |>
  mutate(
    STUDYID = data_raw$STUDY,
    DOMAIN = "DS",
    USUBJID = paste0("01-", data_raw$PATNUM),
    DSCAT = "DISPOSITION EVENT",
    DSDTC = case_when(
      !is.na(DSDTCOL) & !is.na(DSTMCOL) ~ paste0(DSDTCOL, "T", DSTMCOL),
      !is.na(DSDTCOL) ~ DSDTCOL,
      TRUE ~ NA_character_
    )
  )


#########

data_raw |> count(FORML)
study_ct |> select(collected_value, term_value)
study_ct |>
  select(codelist_code, term_value, collected_value) |>
  distinct()


data_raw |> count(FORM) # what does this show?
data_raw |> count(FORML) # what does this show?
data_raw |> count(INSTANCE) # what does this show?
data_raw |> count(IT.DSTERM)
