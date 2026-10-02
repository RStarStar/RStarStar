# Public file-only entry point. The compiler never evaluates source programs.
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
  filename <- normalizePath(path, winslash = "/", mustWork = TRUE)
  bytes <- tryCatch(withCallingHandlers(
    readBin(filename, what = "raw", n = file.info(filename)$size),
    warning = function(w) stop(conditionMessage(w), call. = FALSE)
  ), error = function(e) rss_error(paste("Cannot read source:", conditionMessage(e)), location, filename))
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
run_file <- function(path) {
  code <- transpile(path)
  environment <- new.env(parent = baseenv())
  eval(parse(text = code), envir = environment)
  bindings <- setdiff(ls(environment, all.names = TRUE), c(".rss", ".rss_read_csv"))
  if (!length(bindings)) return(list())
  mget(bindings, envir = environment, inherits = FALSE)
}
