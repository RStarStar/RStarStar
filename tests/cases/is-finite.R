check("finite predicate returns Boolean values for arithmetic results", {
  result <- run('ratios = [10, 1, 0, -1] / [2, 0, 0, 0]\nflags = std::is_finite(values: ratios)\nselected = if std::is_finite(1 / 0) then 1 else 2\nrecord Check { valid: Boolean }\nchecked = Check(std::is_finite(5))\nmut valid = false\nvalid = std::is_finite(0)\nstd = 99\nfn is_finite(x) { return "user" }\nown = is_finite(1)')$env
  stopifnot(identical(result$flags, c(TRUE, FALSE, FALSE, FALSE)),
            identical(result$ratios, c(5, Inf, NaN, -Inf)),
            result$selected == 2, result$checked$valid, result$valid, result$own == "user")
})

check("finite predicate enforces numeric inputs exact signature and Boolean inference", {
  for (source in c('x = std::is_finite("3")', 'x = std::is_finite(true)',
                   'record Point { x: Number }\nx = std::is_finite(Point(1))',
                   'class Counter { value: Number }\nx = std::is_finite(Counter(1))')) {
    fails(source, "require plain numbers")
  }
  fails('x = std::is_finite()', "exactly one argument")
  fails('x = std::is_finite(1, 2)', "exactly one argument")
  fails('x = std::is_finite(value: 1)', "exact parameter name", 1, 20)
  fails('x = std::is_finite(1) skipping missing', "Expected a new line")
  fails('x = std::is_finite(1) + 1', "Arithmetic requires numbers")
  fails('mut x = 1\nx = std::is_finite(1)', "Cannot change")
  fails('x = std::is_finite([1, 2]) and [true, false, true]', "Vector lengths")
})

check("finite predicate filters computed CSV ratios without dropping valid zeros", {
  with_csv(c('numerator,denominator', '10,2', '1,0', '0,0', '-1,0', 'NA,2', '0,2'), function(path) {
    prefix <- paste('read', path, 'into data with columns {numerator: Number, denominator: Number}\n')
    result <- run(paste0(prefix,
      'filter data where std::is_finite(numerator / denominator) into usable\n',
      'mean = average(usable.numerator / usable.denominator)\n',
      'filter data where not std::is_finite(numerator / denominator) into review\n',
      'filter data where false into empty\nflags = std::is_finite(empty.numerator)\n',
      'limit = 2\nfilter data where std::is_finite(numerator / @limit) into known'))$env
    stopifnot(identical(result$usable$numerator, c(10, 0)), result$mean == 2.5,
              nrow(result$review) == 4L, nrow(result$data) == 6L,
              identical(result$data$numerator, c(10, 1, 0, -1, NA_real_, 0)),
              identical(result$flags, logical()), nrow(result$known) == 5L)
    filter_error(paste0(prefix, 'x = std::is_finite(data)'), "require plain numbers")
  })
  for (contents in list(c('x', 'NA'), 'x')) {
    with_csv(contents, function(path) {
      prefix <- paste('read', path, 'into data')
      filter_error(paste0(prefix, '\nx = std::is_finite(data.x)'), "requires plain numbers")
      result <- run(paste0(prefix, ' with columns {x: Number}\nx = std::is_finite(data.x)'))$env
      stopifnot(identical(result$x, if (length(contents) == 1L) logical() else FALSE))
    })
  }
})

check("finite predicate validates R inputs preserves values and evaluates once", {
  with_source_file('fn finite(x) { return std::is_finite(x) }', function(path) {
    finite <- RStarStar::run_file(path)$finite
    values <- c(-1, 0, 1, NA_real_, NaN, Inf, -Inf)
    original <- values
    stopifnot(identical(finite(values), c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE)),
              identical(values, original), identical(finite(c(1L, NA_integer_)), c(TRUE, FALSE)),
              identical(finite(numeric()), logical()), identical(finite(integer()), logical()))
    for (bad in list(NULL, TRUE, "1", 1+1i, raw(1), factor("1"), matrix(1),
                     c(named = 1), structure(1, class = "foreign"), list(1), new.env())) {
      error <- tryCatch(finite(bad), error = identity)
      stopifnot(inherits(error, "rstarstar_error"), error$line == 1L, error$column == 23L,
                identical(error$filename, normalizePath(path, winslash = "/")))
    }
    forced <- 0L
    stopifnot(identical(finite({ forced <- forced + 1L; values }), is.finite(values)), forced == 1L)
  })
})

check("finite predicate retains call chains and compilation execution separation", {
  source <- 'fn finite(x) { return std::is_finite(x) }\nprint 42\ny = finite("bad")'
  with_source_file(source, function(path) {
    output <- capture.output(code <- RStarStar::transpile(path))
    stopifnot(length(output) == 0L, is.character(code))
    output <- capture.output(error <- tryCatch(RStarStar::run_file(path), error = identity))
    stopifnot(identical(output, "[1] 42"), inherits(error, "rstarstar_error"),
              error$line == 1L, error$column == 23L,
              grepl(paste0("called at ", normalizePath(path, winslash = "/"), ":3:5"),
                    conditionMessage(error), fixed = TRUE))
  })
  stopifnot(run('fn finite(x) { return std::is_finite(x) }\nx = if true then false else finite("bad")')$env$x == FALSE)
  filter_error('x = std::is_finite(std::square_root(-1))', "nonnegative values")
})

check("finite predicate embeds only required helpers and runs without the compiler", {
  with_source_file('x = std::is_finite([1, 1 / 0, 0 / 0])', function(path) {
    code <- RStarStar::transpile(path)
    stopifnot(!grepl('absolute =', code, fixed = TRUE),
              !grepl('square_root =', code, fixed = TRUE),
              !grepl('lower_text =', code, fixed = TRUE),
              identical(RStarStar::run_file(path), list(x = c(TRUE, FALSE, FALSE))))
    script <- tempfile(fileext = ".R")
    on.exit(unlink(script), add = TRUE)
    writeLines(c(code, 'stopifnot(identical(x, c(TRUE, FALSE, FALSE)), !"RStarStar" %in% loadedNamespaces(), !"R6" %in% loadedNamespaces())'), script)
    executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
    output <- system2(executable, c("--vanilla", "--default-packages=NULL", shQuote(script)), stdout = TRUE, stderr = TRUE)
    stopifnot(is.null(attr(output, "status")))
  })
})
