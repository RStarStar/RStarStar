with_source_file <- function(contents, code, extension = ".rsspps") {
  path <- tempfile(fileext = extension)
  on.exit(unlink(path))
  if (is.raw(contents)) writeBin(contents, path) else writeLines(contents, path, useBytes = TRUE)
  code(path)
}
input_error <- function(path, message) {
  error <- tryCatch(RStarStar::transpile(path), rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"), grepl(message, conditionMessage(error), fixed = TRUE))
  error
}
check("installed package exports only the file API", {
  stopifnot(identical(getNamespaceExports("RStarStar"), "transpile"),
            identical(names(formals(RStarStar::transpile)), "path"))
})
check("public file API compiles and generated output runs independently", {
  with_source_file(c("fn twice(x) { return x * 2 }", "value = twice([2, 3])"), function(path) {
    code <- RStarStar::transpile(path)
    env <- new.env(parent = baseenv())
    eval(parse(text = code), env)
    stopifnot(identical(env$value, c(4, 6)))
  })
})
check("public API rejects non-rsspps extensions and raw source", {
  for (suffix in c(".R", ".txt", ".RSSPPS", ".rsspps.R")) {
    with_source_file("x = 1", function(path) input_error(path, "lowercase .rsspps"), extension = suffix)
  }
  input_error("x = 1", "lowercase .rsspps")
})
check("public API validates scalar paths and rejects connections", {
  for (value in list(NULL, NA_character_, "", 1, c("a.rsspps", "b.rsspps"))) input_error(value, "one nonempty")
  connection <- textConnection("x = 1")
  tryCatch(input_error(connection, "one nonempty"), finally = close(connection))
})
check("public API rejects missing paths and directories", {
  path <- tempfile(fileext = ".rsspps")
  input_error(path, "existing regular local")
  dir.create(path)
  tryCatch(input_error(path, "existing regular local"), finally = unlink(path, recursive = TRUE))
})
check("public source accepts UTF-8 BOM, CRLF and no terminal newline", {
  with_source_file(charToRaw('\ufefftext = "ආයුබෝවන්"\r\nx = 2'), function(path) {
    env <- new.env(parent = baseenv())
    eval(parse(text = RStarStar::transpile(path)), env)
    stopifnot(env$text == "ආයුබෝවන්", env$x == 2)
  })
})
check("public API rejects invalid UTF-8 and NUL bytes", {
  with_source_file(as.raw(255), function(path) input_error(path, "valid UTF-8"))
  with_source_file(c(charToRaw("x = 1"), as.raw(0)), function(path) input_error(path, "NUL bytes"))
})
check("public source diagnostics use normalized paths and source lines", {
  with_source_file(c("x = 1", "x = 2"), function(path) {
    error <- input_error(path, "Cannot reassign")
    stopifnot(error$filename == normalizePath(path, winslash = "/"), error$line == 2L, error$column == 1L)
  })
})
check("public API supports empty files and filenames with spaces", {
  with_source_file(raw(), function(path) stopifnot(identical(RStarStar::transpile(path), "")))
  directory <- tempfile("source folder ")
  dir.create(directory)
  tryCatch({
    path <- file.path(directory, "my program.rsspps")
    writeLines("x = 1", path)
    stopifnot(grepl("<- 1", RStarStar::transpile(path), fixed = TRUE))
  }, finally = unlink(directory, recursive = TRUE))
})
check("public compilation does not execute programs or read datasets", {
  with_source_file('read "nonexistent-data.csv" into data\nprint data', function(path) {
    before <- readBin(path, "raw", n = file.info(path)$size)
    output <- capture.output(code <- RStarStar::transpile(path))
    stopifnot(length(output) == 0L, is.character(code),
              identical(before, readBin(path, "raw", n = file.info(path)$size)))
  })
})
check("renaming R code to rsspps does not execute it", {
  with_source_file("x <- 1", function(path) input_error(path, "Expected '='"))
})
check("package includes runnable source examples", {
  path <- system.file("examples", "basics.rsspps", package = "RStarStar", mustWork = TRUE)
  code <- RStarStar::transpile(path)
  env <- new.env(parent = baseenv())
  invisible(capture.output(eval(parse(text = code), env)))
  stopifnot(identical(env$adjusted, c(77, 90, 96, 73)))
  stopifnot(all(file.exists(file.path(dirname(path), paste0(c("basics", "read-csv", "filter", "workflow", "grouped", "functions"), ".rsspps")))))
})
