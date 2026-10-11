# Standalone UTF-8 text I/O. This factory is embedded only when file operations
# are used; fail supplies source-located diagnostics without a package dependency.
rss_file_runtime <- function(fail) {
  # Accept one plain local path, never URLs, connections, or missing values.
  path_value <- function(path, filename, line, column) {
    if (!is.character(path) || !is.null(attributes(path)) || length(path) != 1L ||
        is.na(path) || !nzchar(path) || Encoding(path) == "bytes") {
      fail("File path must be one nonempty plain Text value with valid encoding.", filename, line, column)
    }
    path <- enc2utf8(path)
    if (is.na(iconv(path, from = "UTF-8", to = "UTF-8"))) fail("File path must have valid text encoding.", filename, line, column)
    if (grepl("^[A-Za-z][A-Za-z0-9+.-]*://", path)) fail("File operations require local paths, not URLs.", filename, line, column)
    path.expand(path)
  }
  # Convert OS warnings/errors into language diagnostics without losing their detail.
  io <- function(action, filename, line, column) {
    tryCatch(withCallingHandlers(action(), warning = function(w) stop(conditionMessage(w), call. = FALSE)),
      error = function(e) {
        if (inherits(e, "rstarstar_error")) stop(e)
        fail(paste("File operation failed:", conditionMessage(e)), filename, line, column)
      })
  }
  list(
    # Existence means a regular file, following symlinks; it does not imply readability.
    file_exists = function(path, filename, line, column) {
      path <- path_value(path, filename, line, column)
      isTRUE(utils::file_test("-f", path))
    },
    # Read exact UTF-8 text, preserving BOMs, CR/LF characters, and final newlines.
    read_text = function(path, filename, line, column) {
      path <- path_value(path, filename, line, column)
      if (!isTRUE(utils::file_test("-f", path))) fail("read_text requires an existing regular local file.", filename, line, column)
      io(function() {
        bytes <- readBin(path, "raw", n = file.info(path)$size)
        if (any(bytes == as.raw(0L))) fail("read_text requires UTF-8 text without NUL bytes.", filename, line, column)
        text <- rawToChar(bytes)
        if (is.na(iconv(text, from = "UTF-8", to = "UTF-8"))) fail("read_text requires valid UTF-8 text.", filename, line, column)
        Encoding(text) <- "UTF-8"
        text
      }, filename, line, column)
    },
    # Stage complete bytes in the destination directory, then publish via a hard
    # link. Linking refuses existing paths even when multiple workers race to write.
    # Filesystems without hard-link support fail; no overwrite-prone fallback is used.
    write_text = function(path, text, filename, line, column) {
      path <- path_value(path, filename, line, column)
      if (!is.character(text) || !is.null(attributes(text)) || length(text) != 1L ||
          is.na(text) || Encoding(text) == "bytes") fail("write_text requires one nonmissing plain Text value.", filename, line, column)
      text <- enc2utf8(text)
      if (is.na(iconv(text, from = "UTF-8", to = "UTF-8"))) fail("write_text requires valid UTF-8 text.", filename, line, column)
      if (file.exists(path)) fail("Text output already exists; choose a new path.", filename, line, column)
      if (!dir.exists(dirname(path))) fail("Text output directory does not exist.", filename, line, column)
      temporary <- tempfile(".rstarstar-text-", tmpdir = dirname(path))
      on.exit(unlink(temporary), add = TRUE)
      io(function() {
        writeBin(charToRaw(text), temporary)
        if (!file.link(temporary, path)) fail("Could not publish text without overwriting; the filesystem must support hard links.", filename, line, column)
        path
      }, filename, line, column)
    }
  )
}
