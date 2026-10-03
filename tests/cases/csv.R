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
check("CSV schemas preserve identifiers and infer unspecified columns", {
  with_csv(c('code,amount,active', '0012,3,true', '0007,4,false'), function(path) {
    result <- run(paste('read', path, 'into data with columns {code: Text}'))$env$data
    stopifnot(identical(result$code, c("0012", "0007")), identical(result$amount, c(3, 4)),
              identical(result$active, c(TRUE, FALSE)))
  })
})
check("CSV schemas preserve missing and zero-row storage types", {
  for (rows in list(c('n,b,t', 'NA,NA,NA'), 'n,b,t')) {
    with_csv(rows, function(path) {
      result <- run(paste('read', path, 'into data with columns {n: Number, b: Boolean, t: Text}'))$env$data
      stopifnot(typeof(result$n) == "double", typeof(result$b) == "logical", typeof(result$t) == "character",
                nrow(result) == length(rows) - 1L, all(is.na(result$n)), all(is.na(result$b)))
    })
  }
})
check("CSV schemas combine with delimiters quoted headers and mutable reloads", {
  with_csv(c('product code;value', '001;2'), function(path) {
    result <- run(paste('columns = 3\nread', path, 'into mut data with columns {\n"product code": Text,\nvalue: Number\n} with delimiter ";"\nread', path, 'into data with delimiter ";" with columns {"product code": Text}'))
    stopifnot(result$env$data[["product code"]] == "001", result$env$data$value == 2, result$env$columns == 3)
  })
})
check("CSV schemas reject malformed declarations before reading data", {
  prefix <- 'read "does-not-exist.csv" into data with columns '
  fails(paste0(prefix, '{}'), "Expected a column name")
  fails(paste0(prefix, '{x: Integer}'), "Text, Number, or Boolean")
  fails(paste0(prefix, '{x: Text, x: Number}'), "nonempty and unique")
  fails(paste0(prefix, '{"": Text}'), "nonempty and unique")
  fails(paste0(prefix, '{x: Text,}'), "Expected a column name")
  fails(paste0(prefix, '{x: Text} with columns {y: Text}'), "only once")
  fails('read "x" into data with delimiter ";" with delimiter ","', "only once")
  stopifnot(is.character(transpile(paste0(prefix, '{x: Text}'))))
})
check("CSV schemas reject absent headers even for empty tables", {
  with_csv('actual', function(path) {
    runtime_fails(paste('read', path, 'into data with columns {missing_name: Text}'), "absent from the CSV header")
  })
})
check("CSV explicit conversions reject invalid values without fallback", {
  for (case in list(c("Number", "oops"), c("Number", " 3 "), c("Number", "Inf"), c("Boolean", "1"), c("Boolean", "True"))) {
    with_csv(c('value', 'NA', case[[2L]]), function(path) {
      runtime_fails(paste('read', path, 'into data with columns {value:', case[[1L]], '}'),
                    paste0('requires ', case[[1L]], '; invalid value at data row 2'))
    })
  }
  with_csv(c('value', '1e999'), function(path) {
    runtime_fails(paste('read', path, 'into data with columns {value: Number}'), "outside the finite range")
    stopifnot(run(paste('read', path, 'into data with columns {value: Text}'))$env$data$value == "1e999")
  })
})
check("CSV schema file API output executes independently with text helpers", {
  with_csv(c('code', '0012', '0007'), function(path) {
    source <- paste('read', path, 'into data with columns {code: Text}\nlengths = std::text_length(data.code)')
    with_source <- tempfile(fileext = '.rsspps')
    on.exit(unlink(with_source))
    writeLines(source, with_source)
    result <- RStarStar::run_file(with_source)
    env <- new.env(parent = baseenv())
    eval(parse(text = RStarStar::transpile(with_source)), env)
    stopifnot(identical(result$lengths, c(4, 4)), identical(env$data$code, c("0012", "0007")))
  })
})

check("CSV schema headers cannot collide with generated R argument names", {
  with_csv(c('recursive,use.names', '001,002'), function(path) {
    result <- run(paste('read', path, 'into data with columns {recursive: Text, "use.names": Text}'))$env$data
    stopifnot(identical(result$recursive, "001"), identical(result[["use.names"]], "002"))
  })
})
