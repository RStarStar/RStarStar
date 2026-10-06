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
check("CSV export supports semicolon and tab delimiters with escaped text", {
  with_csv(c('label,value', '"a;b",1', '"a\tb",2', '"say ""hi""",3', '"line', 'break",4', 'é,NA'), function(input) {
    for (delimiter in c(';', '\t', '|')) {
      with_csv_output(function(path, quoted) {
        option <- paste('with delimiter', encodeString(delimiter, quote = '"'))
        result <- run(paste('read', input, 'into data\nwrite data to', quoted, option,
                            '\nread', quoted, 'into restored', option))
        stopifnot(identical(result$env$data, result$env$restored),
                  grepl(paste0('"label"', delimiter, '"value"'), readLines(path)[[1L]], fixed = TRUE))
      })
    }
  })
})
check("CSV export validates delimiter syntax before execution", {
  prefix <- 'write data to "result.csv" with delimiter '
  for (literal in c('""', '"||"', '"é"', '"\\n"', '"\\r"', '"\\\""')) {
    fails(paste0(prefix, literal), 'Export delimiter must be')
  }
  for (literal in c('"1"', '"e"', '"T"')) fails(paste0(prefix, literal), 'Export delimiter must be')
  fails(paste0(prefix, 'separator'), 'quoted delimiter')
  fails('write data to "result.csv" with missing []', "quoted missing-value marker")
  fails(paste0(prefix, '";" with delimiter ","'), 'only once')
})
check("custom delimiter output keeps overwrite protection and header-only tables", {
  with_sales(function(prefix) with_csv_output(function(path, quoted) {
    run(paste0(prefix, 'filter sales where false into empty\nwrite empty to ', quoted, ' with delimiter ";"'))
    stopifnot(length(readLines(path)) == 1L, grepl(';', readLines(path), fixed = TRUE))
    before <- readBin(path, 'raw', file.info(path)$size)
    filter_error(paste0(prefix, 'write sales to ', quoted, ' with delimiter ";"'), 'already exists')
    stopifnot(identical(readBin(path, 'raw', file.info(path)$size), before))
  }))
})
check("custom delimiter public API compiles without writing and runs standalone", {
  with_sales(function(prefix) with_csv_output(function(path, quoted) {
    with_source_file(paste0(prefix, 'write sales to ', quoted, ' with delimiter ";"'), function(source) {
      code <- RStarStar::transpile(source)
      stopifnot(!file.exists(path))
      eval(parse(text = code), new.env(parent = baseenv()))
      stopifnot(file.exists(path), grepl(';', readLines(path)[[1L]], fixed = TRUE))
    })
  }))
})
check("export missing markers distinguish missing from empty and NA text", {
  with_csv(c('label,value,active', '"",1,true', 'NA,?,?', '?,2,false'), function(input) {
    with_csv_output(function(path, quoted) {
      result <- run(paste('read', input, 'into data with missing ["?"]\nwrite data to', quoted,
                          'with missing "N/A" with delimiter ";"\nread', quoted,
                          'into restored with delimiter ";" with missing ["N/A"]'))
      stopifnot(identical(result$env$data, result$env$restored),
                identical(result$env$restored$label, c("", "NA", NA_character_)))
    })
  })
})
check("export missing option supports both orders and explicit default", {
  with_sales(function(prefix) {
    for (option in c('with delimiter "|" with missing "?"', 'with missing "?" with delimiter "|"', 'with missing ""')) {
      with_csv_output(function(path, quoted) {
        run(paste0(prefix, 'write sales to ', quoted, ' ', option))
        separator <- if (grepl('|', option, fixed = TRUE)) '|' else ','
        marker <- if (separator == '|') '?' else ''
        restored <- utils::read.table(path, header = TRUE, sep = separator, na.strings = marker, check.names = FALSE)
        stopifnot(is.na(restored$revenue[[3L]]))
      })
    }
  })
})
check("export marker syntax rejects structural CSV characters and repeated options", {
  prefix <- 'write data to "result.csv" with missing '
  for (literal in c('["NA"]', 'marker', '1')) fails(paste0(prefix, literal), 'quoted missing-value marker')
  for (literal in c('\"a,b\"', '\"a\\n b\"', '\"a\\r b\"', '\"a\\\"b\"')) {
    fails(paste0(prefix, literal), 'cannot contain')
  }
  fails(paste0(prefix, '"a;b" with delimiter ";"'), 'cannot contain')
  fails('write data to "result.csv" with delimiter ";" with missing "a;b"', 'cannot contain')
  fails(paste0(prefix, '"?" with missing "NA"'), 'only once')
})
check("export marker round trip ambiguity remains explicit", {
  with_csv(c('label', 'N/A', '?'), function(input) {
    with_csv_output(function(path, quoted) {
      result <- run(paste('read', input, 'into data with missing ["?"]\nwrite data to', quoted,
                          'with missing "N/A"\nread', quoted, 'into restored with missing ["N/A"]'))
      stopifnot(result$env$data$label[[1L]] == "N/A", all(is.na(result$env$restored$label)))
    })
  })
})
check("custom export markers compile without effects and retain overwrite protection", {
  with_sales(function(prefix) with_csv_output(function(path, quoted) {
    with_source_file(paste0(prefix, 'write sales to ', quoted, ' with missing "missing"'), function(source) {
      code <- RStarStar::transpile(source)
      stopifnot(!file.exists(path))
      eval(parse(text = code), new.env(parent = baseenv()))
      before <- readBin(path, 'raw', file.info(path)$size)
      error <- tryCatch(RStarStar::run_file(source), rstarstar_error = identity)
      stopifnot(inherits(error, 'rstarstar_error'), grepl('already exists', conditionMessage(error), fixed = TRUE),
                identical(before, readBin(path, 'raw', file.info(path)$size)))
    })
  }))
})
