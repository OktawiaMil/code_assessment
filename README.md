# Code Assessment

This repository contains solutions for four tasks:

- Question 1: create the SDTM `DS` domain
- Question 2: create the ADaM `ADSL` dataset
- Question 3: generate AE summary outputs
- Question 4: run a simple GenAI-style clinical data assistant on `ADAE`

## Repository Structure

- [call_file.R](call_file.R): runs Questions 1-3 in sequence
- [question_1_sdtm](question_1_sdtm): SDTM task
- [question_2_adam](question_2_adam): ADaM task
- [question_3_tlg](question_3_tlg): TLG task
- [question_4_gen_ai](question_4_gen_ai): Python clinical data assistant
- [input](input): local input files used by the tasks
- [output](output): generated outputs

## R Setup

This project uses `renv` for reproducible R package management.

1. Open R with the project root as the working directory.
2. The checked-in [.Rprofile](.Rprofile) activates `renv` automatically.
3. Restore packages with:

```r
renv::restore()
```

The current lockfile in [renv.lock](renv.lock) was generated with R `4.5.1`.

## Run Questions 1-3

Questions 1-3 are implemented in R and can be run from the project root with:

```r
source("call_file.R")
```

[call_file.R](call_file.R) sources all `.R` scripts from:

- [question_1_sdtm](question_1_sdtm)
- [question_2_adam](question_2_adam)
- [question_3_tlg](question_3_tlg)

### Generated Outputs

Running Questions 1-3 produces files under [output](output), including:

- [output/question_1_sdtm/ds_domain.csv](output/question_1_sdtm/ds_domain.csv)
- [output/question_2_adam/adsl.csv](output/question_2_adam/adsl.csv)
- [output/question_3_tlg/ae_summary_table.html](output/question_3_tlg/ae_summary_table.html)
- [output/question_3_tlg/ae_severity_by_treatment.png](output/question_3_tlg/ae_severity_by_treatment.png)
- [output/question_3_tlg/top10_ae_plot.png](output/question_3_tlg/top10_ae_plot.png)

### Log Files

Each R task also writes a log file in its task folder:

- [question_1_sdtm/01_create_ds_domain.log](question_1_sdtm/01_create_ds_domain.log)
- [question_2_adam/create_adsl.log](question_2_adam/create_adsl.log)
- [question_3_tlg/01_create_ae_summary_table.log](question_3_tlg/01_create_ae_summary_table.log)
- [question_3_tlg/02_create_avisualizations.log](question_3_tlg/02_create_avisualizations.log)

## Run Question 4

Question 4 is separate from `call_file.R` and is implemented in Python in [question_4_gen_ai](question_4_gen_ai).

### Files Required

An external user should have these files in the `question_4_gen_ai` folder:

- `clinical_data_agent.py`
- `test_agent.py`
- `adae.csv`

`adae.csv` must be in the same folder as `test_agent.py`.

### Python Setup

Create a virtual environment and install `pandas`.

On Windows PowerShell:

```powershell
cd .\question_4_gen_ai
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install pandas
```

### Run the Script

From the `question_4_gen_ai` folder:

```powershell
python .\test_agent.py
```

The script loads `adae.csv`, runs example natural-language queries, and prints the matching subject IDs.

## Formatting

R code can be formatted with [Air](https://posit-dev.github.io/air/). The shared configuration is in [air.toml](air.toml).

Example:

```powershell
air format .
```
