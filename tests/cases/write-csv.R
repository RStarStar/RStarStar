with_csv_output <- function(code) {
  directory <- tempfile("csv-output-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  path <- file.path(directory, "result.csv")
  code(path, encodeString(path, quote = '"'))
}
check("CSV export round trips supported values and missing entries", {
  with_sales(function(prefix) with_csv_output(function(path, quoted) {
    result <- run(paste0(prefix, "write sales to ", quoted, "\nread ", quoted, " into restored"))
    stopifnot(identical(result$env$sales, result$env$restored))
    bytes <- readBin(path, "raw", file.info(path)$size)
    stopifnot(!any(bytes == as.raw(13)), !is.na(iconv(rawToChar(bytes), "UTF-8", "UTF-8")))
  }))
})
check("CSV export escapes quotes commas multiline and Unicode text", {
  with_csv(c('label,value', '"a,b",1', '"say ""hello""",2', '"line', 'break",3', '"ආයුබෝවන්",4'), function(input) {
    with_csv_output(function(path, quoted) {
      result <- run(paste("read", input, "into data\nwrite data to", quoted, "\nread", quoted, "into restored"))
      stopifnot(identical(result$env$data, result$env$restored))
    })
  })
})
check("CSV export writes grouped results and header-only tables", {
  with_sales(function(prefix) with_csv_output(function(path, quoted) {
    result <- run(paste0(prefix, "summarize sales by active with total = sum(revenue) skipping missing into totals\nwrite totals to ", quoted))
    restored <- utils::read.csv(path)
    stopifnot(identical(names(restored), c("active", "total")), identical(as.double(restored$total), result$env$totals$total))
  }))
  with_sales(function(prefix) with_csv_output(function(path, quoted) {
    run(paste0(prefix, "filter sales where revenue > 1000 skipping missing into empty\nwrite empty to ", quoted))
    stopifnot(length(readLines(path)) == 1L, nrow(utils::read.csv(path)) == 0L)
  }))
})
check("CSV export rejects invalid source syntax and non-tables", {
  fails('write unknown to "result.csv"', "Unknown", 1, 7)
  fails('x = 1\nwrite x to "result.csv"', "table", 2, 7)
  fails('write x "result.csv"', "Expected 'to'")
  fails('write x to result', "quoted CSV")
  fails('write x to "result.txt"', ".csv output")
})
check("CSV export refuses overwrite and reports missing directories", {
  with_sales(function(prefix) with_csv_output(function(path, quoted) {
    writeLines("existing content", path)
    filter_error(paste0(prefix, "write sales to ", quoted), "already exists", 2L, 1L)
    stopifnot(identical(readLines(path), "existing content"))
    missing <- encodeString(file.path(dirname(path), "absent", "result.csv"), quote = '"')
    filter_error(paste0(prefix, "write sales to ", missing), "directory does not exist", 2L, 1L)
    stopifnot(identical(list.files(dirname(path), all.files = TRUE, no.. = TRUE), "result.csv"))
  }))
})
check("public file API exports only during explicit execution", {
  with_sales(function(prefix) with_csv_output(function(path, quoted) {
    with_source_file(paste0(prefix, "write sales to ", quoted), function(source) {
      RStarStar::transpile(source)
      stopifnot(!file.exists(path))
      result <- RStarStar::run_file(source)
      stopifnot(file.exists(path), identical(names(result), "sales"))
    })
  }))
})
check("CSV export checks table types unknown until execution", {
  with_csv_output(function(path, quoted) {
    filter_error(paste0("fn identity(x) { return x }\nvalue = identity(1)\nwrite value to ", quoted),
                 "CSV export requires a table", 3L, 1L)
    stopifnot(!file.exists(path))
  })
})
