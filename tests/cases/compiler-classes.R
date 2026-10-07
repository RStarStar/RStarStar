# Internal R6 stages must remain independent across calls, instances, and failures.
local({
  namespace <- asNamespace("RStarStar")
  make <- function(name) get(name, namespace)$new()
  ast <- function(source, filename = "class.input") rss_parse(rss_tokenize(source, filename), filename)
  error_from <- function(code) {
    error <- tryCatch(force(code), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"))
    error
  }

  check("tokenizer instances reset text positions and recover from errors", {
    first <- make("RSSTokenizer")
    second <- make("RSSTokenizer")
    first$tokenize("x = [\n1, 2\n]", "first")
    error <- error_from(first$tokenize('x = "unclosed', "broken"))
    stopifnot(error$filename == "broken", error$column == 5L)
    expected <- second$tokenize("y = 3\nprint y", "second")
    stopifnot(identical(first$tokenize("y = 3\nprint y", "second"), expected),
              identical(first$tokenize("", "empty")[[1L]]$line, 1L))
  })

  check("parser instances reset token cursors after partial parses", {
    parser <- make("RSSParser")
    broken <- rss_tokenize("x = [1,", "broken")
    error <- error_from(parser$parse(broken, "broken"))
    stopifnot(error$filename == "broken")
    tokens <- rss_tokenize("y = (2 + 3)\nprint y", "good")
    expected <- make("RSSParser")$parse(tokens, "good")
    stopifnot(identical(parser$parse(tokens, "good"), expected),
              identical(parser$parse(tokens, "again"), expected),
              identical(parser$parse(rss_tokenize("", "empty"), "empty"), list()))
  })

  check("analyzer clears declarations and failed function scopes between calls", {
    analyzer <- make("RSSAnalyzer")
    program <- ast("record Point { x: Number\nfn value(self) { return self.x }\n}\np = Point(1)\nx = p.value()")
    analyzer$analyze(program, "first")
    make("RSSAnalyzer")$analyze(program, "second")
    analyzer$analyze(program, "repeat")
    for (source in c("print p", "p = Point(1)", "record Box { p: Point }",
                     "fn value(x) { return x.value() }")) {
      error <- error_from(analyzer$analyze(ast(source), "isolated"))
      stopifnot(error$filename == "isolated")
    }
    error_from(analyzer$analyze(ast("fn broken(x) { return absent }"), "broken"))
    analyzer$analyze(ast("x = 2"), "recovered")
    error <- error_from(analyzer$analyze(ast("print x"), "fresh"))
    stopifnot(grepl("Unknown variable 'x'", conditionMessage(error), fixed = TRUE))
  })

  check("generator resets helpers declarations and method IDs between calls", {
    generator <- make("RSSGenerator")
    source <- paste('read "not-read.csv" into data',
      'record Point { x: Number\nfn value(self) { return self.x }\n}',
      'mut p = Point(std::absolute(-2))', 'p = p with { x: 3 }',
      'answer = p.value()', sep = "\n")
    program <- ast(source)
    expected <- transpile(source, "class.input")
    stopifnot(identical(generator$generate(program, "class.input"), expected),
              identical(generator$generate(ast("x = 1"), "plain"), "`x` <- 1"),
              identical(generator$generate(list(), "empty"), ""),
              identical(generator$generate(program, "class.input"), expected))
    other <- make("RSSGenerator")
    stopifnot(identical(other$generate(program, "class.input"), expected))
  })

  check("compiler instances preserve diagnostics and execution separation", {
    compiler <- make("RSSCompiler")
    output <- capture.output(code <- compiler$compile('print "later"\nx = 2', "first"))
    stopifnot(length(output) == 0L)
    for (source in c('x = "unclosed', "x = [1,", "x = 1\nx = 2")) {
      error_from(compiler$compile(source, "broken"))
      stopifnot(identical(compiler$compile("x = 3", "good"), "`x` <- 3"))
    }
    error <- error_from(compiler$compile("print x", "fresh"))
    stopifnot(error$filename == "fresh", error$line == 1L, error$column == 7L,
              identical(make("RSSCompiler")$compile("x = 3"), "`x` <- 3"))
    env <- new.env(parent = baseenv())
    stopifnot(identical(capture.output(eval(parse(text = code), env)), '[1] "later"'), env$x == 2)
  })

  check("generated records and standard calls execute without loading R6", {
    script <- tempfile(fileext = ".R")
    on.exit(unlink(script), add = TRUE)
    code <- transpile(paste(
      'record Point { x: Number\nfn value(self) { return self.x }\n}',
      'original = Point(-2)', 'updated = original with { x: std::absolute(original.value()) }',
      'answer = updated.value()', sep = "\n"))
    writeLines(c('stopifnot(!"R6" %in% loadedNamespaces(), !"RStarStar" %in% loadedNamespaces())',
      code, 'stopifnot(answer == 2, original$x == -2, updated$x == 2)',
      'stopifnot(!"R6" %in% loadedNamespaces(), !"RStarStar" %in% loadedNamespaces())'), script)
    executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
    output <- system2(executable, c("--vanilla", "--default-packages=NULL", shQuote(script)), stdout = TRUE, stderr = TRUE)
    stopifnot(is.null(attr(output, "status")))
  })
})
