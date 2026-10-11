check("lower text composes with trimming and preserves inputs", {
  result <- run('labels = [" North ", "NORTH", "South", "", " A B! "]\nnormalized = std::lower_text(values: std::trim_text(labels))\nspaces = std::lower_text(" A B! ")\nfn lower_text(x) { return "user" }\nown = lower_text("A")\nrecord Label { value: Text }\nlabel = Label(std::lower_text("ABC"))')$env
  stopifnot(identical(result$normalized, c("north", "north", "south", "", "a b!")),
    result$labels[[1L]] == " North ", result$spaces == " a b! ",
    result$own == "user", result$label$value == "abc")
})
check("lower text enforces Text results exact names and arity", {
  for (source in c('x = std::lower_text(1)', 'x = std::lower_text(true)')) fails(source, "require plain text")
  fails('x = std::lower_text()', "exactly one argument")
  fails('x = std::lower_text("A", "B")', "exactly one argument")
  fails('x = std::lower_text(value: "A")', "exact parameter name")
  fails('x = std::lower_text("1") + 1', "Arithmetic requires numbers")
  fails('mut x = 1\nx = std::lower_text("1")', "Cannot change")
})
check("lower text filters CSV labels without rewriting the table", {
  with_csv(c('region', ' North ', 'NORTH', 'South', 'NA', '   '), function(path) {
    prefix <- paste('read', path, 'into data\n')
    result <- run(paste0(prefix, 'wanted = "north"\nfilter data where std::lower_text(std::trim_text(region)) == @wanted skipping missing into selected\nclean = std::lower_text(data.region)\nfilter data where false into empty\nnone = std::lower_text(empty.region)'))$env
    stopifnot(identical(result$selected$region, c(" North ", "NORTH")),
      identical(result$clean, c(" north ", "north", "south", NA_character_, "   ")),
      identical(result$none, character()))
    filter_error(paste0(prefix, 'filter data where std::lower_text(region) == "north" into selected'), "contains missing values")
  })
})
check("lower text validates R inputs and follows the caller locale", {
  with_source_file('fn clean(x) { return std::lower_text(x) }', function(path) {
    clean <- RStarStar::run_file(path)$clean
    locale <- Sys.getlocale("LC_CTYPE")
    values <- c("ABC", "", NA_character_, "\u00c9", "\u03a3", "\u0130")
    stopifnot(identical(clean(values), tolower(values)),
      identical(Sys.getlocale("LC_CTYPE"), locale), identical(clean(character()), character()))
    invalid <- rawToChar(as.raw(c(0xc3, 0x28))); Encoding(invalid) <- "UTF-8"
    bytes <- rawToChar(as.raw(c(0xc3, 0xa9))); Encoding(bytes) <- "bytes"
    for (bad in list(1, TRUE, factor("A"), matrix("A"), c(name = "A"), list("A"), new.env(), invalid, bytes)) {
      error <- tryCatch(clean(bad), error = identity)
      stopifnot(inherits(error, "rstarstar_error"), error$line == 1L, error$column == 22L,
        identical(error$filename, normalizePath(path, winslash = "/")))
    }
    forced <- 0L
    stopifnot(clean({ forced <- forced + 1L; "A" }) == "a", forced == 1L)
  })
  error <- tryCatch(run('fn clean(x) { return std::lower_text(x) }\ny = clean(1)'), rstarstar_error = identity)
  stopifnot(grepl("called at test.input:2:5", conditionMessage(error), fixed = TRUE))
})
check("lower text compiles without execution and embeds only used operations", {
  with_source_file('fn clean(x) { return std::lower_text(x) }\nx = if false then clean(1) else "OK"\ny = clean("ABC")', function(path) {
    code <- RStarStar::transpile(path)
    stopifnot(!grepl('trim_text =', code, fixed = TRUE), !grepl('absolute =', code, fixed = TRUE))
    result <- RStarStar::run_file(path)
    stopifnot(setequal(names(result), c("clean", "x", "y")), result$x == "OK", result$y == "abc")
    script <- tempfile(fileext = ".R")
    on.exit(unlink(script), add = TRUE)
    writeLines(c(code, 'stopifnot(y == "abc", !"RStarStar" %in% loadedNamespaces(), !"R6" %in% loadedNamespaces())'), script)
    executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
    output <- system2(executable, c("--vanilla", "--default-packages=NULL", shQuote(script)), stdout=TRUE, stderr=TRUE)
    stopifnot(is.null(attr(output, "status")))
  })
})
