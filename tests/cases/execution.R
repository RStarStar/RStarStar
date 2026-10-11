check("execution returns final bindings and callable composed functions", {
  with_source_file(c("fn twice(x) { return x * 2 }",
                     "fn four(x) { return twice(twice(x)) }",
                     "mut value = 1", "value = 3", "answer = four(value)"), function(path) {
    result <- RStarStar::run_file(path)
    stopifnot(setequal(names(result), c("twice", "four", "value", "answer")),
              result$value == 3, result$answer == 12,
              identical(result$four(c(2, 3)), c(8, 12)))
  })
})
check("each execution has fresh bindings and leaves caller values unchanged", {
  with_source_file("mut value = 1\nvalue = value + 1", function(path) {
    value <- 99
    first <- RStarStar::run_file(path)
    first$value <- 100
    stopifnot(value == 99, RStarStar::run_file(path)$value == 2)
  })
})
check("empty and print-only execution return empty lists and preserve output", {
  with_source_file(raw(), function(path) stopifnot(identical(RStarStar::run_file(path), list())))
  with_source_file("print 42", function(path) {
    output <- capture.output(result <- RStarStar::run_file(path))
    stopifnot(identical(result, list()), identical(output, "[1] 42"))
  })
})
check("execution retains the source-file-only validation contract", {
  for (input in list(NULL, "x = 1", "example.R", c("a.rsspps", "b.rsspps"))) {
    stopifnot(inherits(tryCatch(RStarStar::run_file(input), error = identity), "rstarstar_error"))
  }
  with_source_file(as.raw(255), function(path) {
    stopifnot(inherits(tryCatch(RStarStar::run_file(path), error = identity), "rstarstar_error"))
  })
})
check("whole-file compilation precedes all execution effects", {
  with_source_file("print 42\nx = unknown", function(path) {
    output <- capture.output(error <- tryCatch(RStarStar::run_file(path), error = identity))
    stopifnot(length(output) == 0, inherits(error, "rstarstar_error"), error$line == 2L)
  })
})
check("execution errors preserve source locations and earlier console effects", {
  with_source_file('print 42\nread "absent-run-file-data.csv" into data', function(path) {
    before <- getwd()
    output <- capture.output(error <- tryCatch(RStarStar::run_file(path), error = identity))
    stopifnot(identical(output, "[1] 42"), inherits(error, "rstarstar_error"),
              error$filename == normalizePath(path, winslash = "/"), error$line == 2L,
              identical(getwd(), before))
  })
})
check("execution reads relative data from caller working directory and hides helpers", {
  directory <- tempfile()
  dir.create(directory)
  before <- getwd()
  tryCatch({
    writeLines(c("value", "2", "4"), file.path(directory, "data.csv"))
    with_source_file('read "data.csv" into data\nmean = average(data.value)', function(path) {
      setwd(directory)
      result <- RStarStar::run_file(path)
      stopifnot(setequal(names(result), c("data", "mean")),
                identical(result$data$value, c(2, 4)), result$mean == 3,
                identical(getwd(), normalizePath(directory)))
    })
  }, finally = {setwd(before); unlink(directory, recursive = TRUE)})
})
check("returned functions retain runtime diagnostics when called from R", {
  with_source_file("fn twice(x) { return x * 2 }", function(path) {
    result <- RStarStar::run_file(path)
    error <- tryCatch(result$twice("text"), error = identity)
    stopifnot(inherits(error, "rstarstar_error"), error$line == 1L,
              error$filename == normalizePath(path, winslash = "/"))
  })
})
check_chart("explicit execution writes a chart and refuses overwriting it", {
  with_sales(function(prefix) with_chart(function(path, quoted) {
    with_source_file(paste(prefix, "filter sales where revenue is not missing into selected\nplot selected x region y revenue as bar to", quoted), function(source) {
      RStarStar::transpile(source)
      stopifnot(!file.exists(path))
      result <- RStarStar::run_file(source)
      stopifnot(file.exists(path), file.info(path)$size > 0, is.data.frame(result$sales))
      stopifnot(inherits(tryCatch(RStarStar::run_file(source), error = identity), "rstarstar_error"))
    })
  }))
})

with_execution_directory <- function(code) {
  directory <- tempfile("execution directory ")
  dir.create(directory)
  previous <- getwd()
  on.exit({setwd(previous); unlink(directory, recursive = TRUE)})
  code(directory)
}

check("explicit working directory resolves data and outputs but not the source path", {
  with_execution_directory(function(directory) {
    dir.create(file.path(directory, "data folder"))
    writeLines(c("value", "2", "4"), file.path(directory, "data folder", "data.csv"))
    writeLines(c('read "data.csv" into data', 'write data to "result.csv"',
                 'fn twice(x) { return x * 2 }', 'mean = average(data.value)'),
               file.path(directory, "analysis.rsspps"))
    # A different source in working_dir must never replace the caller's source.
    writeLines("mean = 99", file.path(directory, "data folder", "analysis.rsspps"))
    setwd(directory)
    previous <- getwd()
    result <- RStarStar::run_file("analysis.rsspps", working_dir = "data folder")
    stopifnot(identical(getwd(), previous), result$mean == 3,
              identical(result$twice(c(2, 3)), c(4, 6)),
              identical(result$data$value, c(2, 4)),
              file.exists(file.path("data folder", "result.csv")),
              !file.exists("result.csv"),
              identical(utils::read.csv(file.path("data folder", "result.csv"))$value, c(2L, 4L)))
  })
})

check("invalid working directories fail before program effects", {
  with_source_file('print 42', function(path) {
    previous <- getwd()
    for (directory in list("", NA_character_, character(), 1, FALSE,
                           c("a", "b"), list(tempdir()), path, tempfile())) {
      output <- capture.output(error <- tryCatch(
        RStarStar::run_file(path, working_dir = directory), error = identity))
      stopifnot(length(output) == 0L, identical(getwd(), previous),
                inherits(error, "rstarstar_error"), error$filename == "<input>",
                grepl("working_dir", conditionMessage(error), fixed = TRUE))
    }
  })
})

check("working directory is restored after runtime errors without rolling back exports", {
  with_execution_directory(function(directory) {
    writeLines(c("value", "2"), file.path(directory, "data.csv"))
    with_source_file(c('read "data.csv" into data', 'write data to "result.csv"',
                       'read "absent.csv" into absent'), function(path) {
      previous <- getwd()
      error <- tryCatch(RStarStar::run_file(path, working_dir = directory), error = identity)
      stopifnot(identical(getwd(), previous), inherits(error, "rstarstar_error"),
                error$filename == normalizePath(path, winslash = "/"), error$line == 3L,
                file.exists(file.path(directory, "result.csv")))
      # A second run fails on overwrite and still restores the caller's directory.
      error <- tryCatch(RStarStar::run_file(path, working_dir = directory), error = identity)
      stopifnot(identical(getwd(), previous), inherits(error, "rstarstar_error"),
                error$line == 2L)
    })
  })
})

check("compilation errors precede working directory selection and preserve locations", {
  with_execution_directory(function(directory) {
    with_source_file('print 42\nx = unknown', function(path) {
      previous <- getwd()
      output <- capture.output(error <- tryCatch(
        RStarStar::run_file(path, working_dir = directory), error = identity))
      stopifnot(length(output) == 0L, identical(getwd(), previous),
                error$filename == normalizePath(path, winslash = "/"), error$line == 2L)
      error <- tryCatch(RStarStar::run_file(path, working_dir = 1), error = identity)
      stopifnot(inherits(error, "rstarstar_error"), error$line == 2L,
                grepl("Unknown variable", conditionMessage(error), fixed = TRUE))
    })
  })
})

check("empty and print-only programs restore working directory and NULL retains defaults", {
  with_execution_directory(function(directory) {
    previous <- getwd()
    with_source_file(raw(), function(path) {
      stopifnot(identical(RStarStar::run_file(path, working_dir = directory), list()),
                identical(getwd(), previous))
    })
    with_source_file("print 42", function(path) {
      output <- capture.output(result <- RStarStar::run_file(path, working_dir = directory))
      stopifnot(identical(result, list()), identical(output, "[1] 42"),
                identical(getwd(), previous))
    })
    writeLines(c("value", "7"), file.path(directory, "data.csv"))
    with_source_file('read "data.csv" into data', function(path) {
      setwd(directory)
      previous <- getwd()
      stopifnot(identical(RStarStar::run_file(path, working_dir = NULL)$data$value, 7),
                identical(getwd(), previous))
    })
  })
})

check_chart("explicit working directory controls chart output and restores after overwrite errors", {
  with_execution_directory(function(directory) {
    writeLines(c("region,revenue", "North,10"), file.path(directory, "sales.csv"))
    with_source_file(c('read "sales.csv" into sales',
                       'plot sales x region y revenue as bar to "revenue.png"'), function(path) {
      previous <- getwd()
      RStarStar::run_file(path, working_dir = directory)
      stopifnot(identical(getwd(), previous),
                file.info(file.path(directory, "revenue.png"))$size > 0)
      error <- tryCatch(RStarStar::run_file(path, working_dir = directory), error = identity)
      stopifnot(inherits(error, "rstarstar_error"), identical(getwd(), previous))
    })
  })
})
