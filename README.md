# code_assessment
# TODO: double -check if it works after your own implamantation !!!!
## R environment

This project uses `renv` for reproducible package management.

- Open R with the project root as the working directory. The checked-in `.Rprofile` will auto-activate `renv`.
- Recreate the project library with `renv::restore()`.
- After changing R dependencies, update the lockfile with `renv::snapshot()`.

The current lockfile was generated with R `4.5.1`.

## Formatting

This project uses [Air](https://posit-dev.github.io/air/) for R formatting. The shared formatter configuration lives in `air.toml`.

- Format files from the project root with `air format .`.
- If Air is not installed on your machine yet, install the Air CLI separately before using the formatter.
