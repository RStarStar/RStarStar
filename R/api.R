# Public file-only entry point. The compiler never evaluates source programs.
# path: one nonempty local UTF-8 file path with the exact lowercase .rsspps suffix.
# Returns: one character string containing standalone R source, not its results.
# Raises rstarstar_error for invalid input, unreadable source, or language errors.
# Dataset reads and program output happen only if the generated R is executed.
# Public help is maintained separately in man/transpile.Rd.
transpile <- function(path) {
  location <- list(line = 1L, column = 1L, end_line = 1L, end_column = 1L)
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    rss_error("path must be one nonempty local .rsspps file path.", location, "<input>")
  }
  if (!grepl("\\.rsspps$", path)) {
    rss_error("Expected a source file with the lowercase .rsspps extension.", location, path)
  }
  if (!file.exists(path) || !utils::file_test("-f", path)) {
    rss_error("Expected an existing regular local .rsspps file.", location, path)
  }
  # Use an absolute diagnostic filename before any later execution-directory change.
  filename <- normalizePath(path, winslash = "/", mustWork = TRUE)
  bytes <- tryCatch(withCallingHandlers(
    readBin(filename, what = "raw", n = file.info(filename)$size),
    warning = function(w) stop(conditionMessage(w), call. = FALSE)
  ), error = function(e) rss_error(paste("Cannot read source:", conditionMessage(e)), location, filename))
  # Check raw bytes first: conversion to an R string cannot preserve embedded NULs.
  if (any(bytes == as.raw(0L))) rss_error("Source must be UTF-8 text without NUL bytes.", location, filename)
  source <- rawToChar(bytes)
  if (is.na(iconv(source, from = "UTF-8", to = "UTF-8"))) {
    rss_error("Source must be valid UTF-8 text.", location, filename)
  }
  Encoding(source) <- "UTF-8"
  source <- sub("^\ufeff", "", source)
  rss_compile(source, filename = filename)
}

# Execution is opt-in and starts only after the entire file compiles.
# path: the same local source-file contract as transpile().
# working_dir: NULL preserves the caller's directory; otherwise use an existing
# directory for relative data/output paths and restore the original on exit.
# Returns: a named list of final bindings; returned functions retain their scope.
# Compile errors precede directory validation. Runtime failures return no partial
# results, but earlier printing and file writes are not rolled back. This is not
# a sandbox, and working_dir does not apply to later calls of returned functions.
# Public help is maintained separately in man/run_file.Rd.
run_file <- function(path, working_dir = NULL) {
  code <- transpile(path)
  if (!is.null(working_dir)) {
    location <- list(line = 1L, column = 1L, end_line = 1L, end_column = 1L)
    if (!is.character(working_dir) || length(working_dir) != 1L ||
        is.na(working_dir) || !nzchar(working_dir)) {
      rss_error("working_dir must be NULL or one nonempty local directory path.", location, "<input>")
    }
    if (!dir.exists(working_dir)) {
      rss_error("working_dir must name an existing local directory.", location, "<input>")
    }
    previous <- tryCatch(setwd(working_dir), error = function(e) {
      rss_error(paste("Cannot enter working_dir:", conditionMessage(e)), location, "<input>")
    })
    on.exit(setwd(previous), add = TRUE)
  }
  # Base parent prevents implicit access to caller bindings. Each run is separate.
  environment <- new.env(parent = baseenv())
  eval(parse(text = code), envir = environment)
  # Keep generated support objects private while preserving user closures intact.
  bindings <- setdiff(ls(environment, all.names = TRUE), c(".rss", ".rss_read_csv", ".rss_std"))
  if (!length(bindings)) return(list())
  mget(bindings, envir = environment, inherits = FALSE)
}
