# Loaded by tests/run.R; fixtures live only in R's temporary directory.
with_csv <- function(contents, code) {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  writeLines(contents, path, useBytes = TRUE)
  code(encodeString(path, quote = '"'))
}
runtime_fails <- function(source, message, line = 1L) {
  generated <- transpile(source, "csv.input")
  error <- tryCatch(eval(parse(text = generated), new.env(parent = baseenv())),
                    rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"),
            grepl(message, conditionMessage(error), fixed = TRUE),
            error$filename == "csv.input", error$line == line, error$column == 1L)
}
check("CSV reads numbers, text, booleans and missing values", {
  with_csv(c("region,revenue,active", "North,120,true", "South,,false", "West,NA,NA"), function(path) {
    table <- run(paste("read", path, "into sales"))$env$sales
    stopifnot(is.data.frame(table), nrow(table) == 3L,
              identical(table$region, c("North", "South", "West")),
              identical(table$revenue, c(120, NA_real_, NA_real_)),
              identical(table$active, c(TRUE, FALSE, NA)))
  })
})
check("CSV delimiter, escaped quotes, embedded newline and punctuation", {
  with_csv(c('label;value', '"a; b";1', '"say ""hello""";2', '"two', 'lines";3', '# literal;4'), function(path) {
    table <- run(paste("read", path, 'into data with delimiter ";"'))$env$data
    stopifnot(identical(table$label, c("a; b", 'say "hello"', "two\nlines", "# literal")))
  })
})
check("CSV header names preserved and header-only tables supported", {
  with_csv("full name,1st value", function(path) {
    table <- run(paste("read", path, "into data"))$env$data
    stopifnot(nrow(table) == 0L, identical(names(table), c("full name", "1st value")))
  })
})
check("CSV mixed columns remain text and all-missing columns are text", {
  with_csv(c("mixed,empty", "10,", "unknown,NA"), function(path) {
    table <- run(paste("read", path, "into data"))$env$data
    stopifnot(identical(table$mixed, c("10", "unknown")), identical(table$empty, c(NA_character_, NA_character_)))
  })
})
check("CSV mutable reload and table aliases", {
  with_csv(c("value", "1"), function(path) {
    result <- run(paste("read", path, "into mut data\ncopy = data\nread", path, "into data\nprint copy"))
    stopifnot(identical(result$env$data, result$env$copy), length(result$output) > 0L)
  })
})
check("CSV compilation never reads files and output is standalone", {
  nonexistent <- encodeString(tempfile(), quote = '"')
  generated <- transpile(paste("read", nonexistent, "into data"))
  stopifnot(is.character(generated), !grepl(".rss_read_csv", transpile("x = 1"), fixed = TRUE))
  runtime_fails(paste("read", nonexistent, "into data"), "existing local file")
})
check("CSV runtime errors retain original source line", {
  runtime_fails('x = 1\n\nread "missing-rstarstar-test-file.csv" into data', "Cannot read CSV", 3L)
})
check("CSV immutable load target", fails('read "a.csv" into data\nread "b.csv" into data', "Cannot reassign"))
check("CSV table type cannot become scalar", fails('read "a.csv" into mut data\ndata = 1', "from Table to Number"))
check("CSV scalar type cannot become table", fails('mut data = 1\nread "a.csv" into data', "from Number to Table"))
check("CSV tables cannot be arithmetic or vector operands", {
  fails('read "a.csv" into data\nprint data + 1', "Arithmetic requires numbers")
  fails('read "a.csv" into data\nprint [data]', "Tables cannot be vector elements")
})
check("CSV syntax errors and invalid delimiter", {
  fails('read path into data', "quoted CSV path")
  fails('read "a.csv" data', "Expected 'into'")
  fails('read "a.csv" into', "Expected a variable name")
  fails('read "a.csv" into data with separator ";"', "Expected 'delimiter'")
  for (sep in c("", "::", "\n", '"', "é")) {
    fails(paste('read "a.csv" into data with delimiter', encodeString(sep, quote = '"')), "Delimiter must")
  }
})
check("CSV malformed row lengths are not filled or truncated", {
  for (row in c("1", "1,2,3", "")) {
    with_csv(c("a,b", row), function(path) runtime_fails(paste("read", path, "into data"), "fields; expected 2"))
  }
})
check("CSV malformed quotes are not repaired", {
  for (row in c('1,"unclosed', '1,un"quoted', '1,"closed"tail')) {
    with_csv(c("a,b", row), function(path) runtime_fails(paste("read", path, "into data"), "quot"))
  }
})
check("CSV empty files and invalid headers", {
  for (contents in list(character(), "a,a", ",b", " ,b")) {
    with_csv(contents, function(path) runtime_fails(paste("read", path, "into data"),
        if (length(contents)) "nonempty and unique" else "empty"))
  }
})
check("CSV numeric overflow rejected without coercing to infinity", {
  with_csv(c("value", "1e999"), function(path) runtime_fails(paste("read", path, "into data"), "finite range"))
})
check("CSV directories rejected", {
  runtime_fails(paste("read", encodeString(tempdir(), quote = '"'), "into data"), "existing local file")
})
check("CSV tab delimiter", {
  with_csv(c("a\tb", "1\t2"), function(path) {
    result <- run(paste("read", path, 'into data with delimiter "\\t"'))
    stopifnot(result$env$data$a == 1, result$env$data$b == 2)
  })
})
check("CSV UTF-8 BOM, CRLF and final line without newline", {
  path <- tempfile(fileext = ".csv")
  tryCatch({
    writeBin(charToRaw("\ufeffname,value\r\nආයුබෝවන්,1"), path)
    table <- run(paste("read", encodeString(path, quote = '"'), "into data"))$env$data
    stopifnot(identical(names(table), c("name", "value")), table$name == "ආයුබෝවන්", table$value == 1)
  }, finally = unlink(path))
})
check("CSV invalid UTF-8 has a source-located error", {
  path <- tempfile(fileext = ".csv")
  tryCatch({
    writeBin(c(charToRaw("name\n"), as.raw(255L)), path)
    runtime_fails(paste("read", encodeString(path, quote = '"'), "into data"), "UTF-8")
  }, finally = unlink(path))
})
