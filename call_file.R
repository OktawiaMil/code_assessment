project_dir <- here::here()

run_task_scripts <- function(task_dir) {
  if (!dir.exists(task_dir)) {
    stop("Task directory does not exist: ", task_dir, call. = FALSE)
  }

  script_paths <- list.files(
    path = task_dir,
    pattern = "\\.[Rr]$",
    full.names = TRUE,
    recursive = TRUE
  )

  if (length(script_paths) == 0L) {
    stop("No R scripts found in: ", task_dir, call. = FALSE)
  }

  message("Running ", basename(task_dir), "...")

  for (script_path in script_paths) {
    message("  sourcing ", basename(script_path))
    source(script_path, local = globalenv())
  }

  invisible(script_paths)
}

task_dirs <- file.path(
  project_dir,
  c(
    "question_1_sdtm",
    "question_2_adam",
    "question_3_tlg"
  )
)

invisible(lapply(task_dirs, run_task_scripts))
