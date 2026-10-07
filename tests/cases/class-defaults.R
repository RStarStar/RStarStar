local({
  counter <- 'class Counter {
mut value: Number = 0
fn current(self) { return self.value }
fn increment(mut self, amount) { self.value = self.value + amount }
}'
  check("default constructors preserve copies and allow exact overrides", {
    result <- run(paste(counter, 'first = Counter()', 'mut second = first',
      'second.increment(3)', 'third = Counter(value: 10)', 'fourth = Counter(-2)',
      'a = first.current()', 'b = second.current()', sep = "\n"))
    stopifnot(result$env$a == 0, result$env$b == 3,
      result$env$third$value == 10, result$env$fourth$value == -2,
      result$env$Counter()$value == 0)
  })
  check("literal defaults cover scalar types signs and escaping", {
    result <- run('class Settings {
low: Number = -2.5
high: Number = +1e2
label: Text = "quoted: \\"yes\\"\\n"
active: Boolean = true
quiet: Boolean = false
}
a = Settings()
b = Settings(active: false, label: "new")')
    stopifnot(result$env$a$low == -2.5, result$env$a$high == 100,
      result$env$a$label == 'quoted: "yes"\n', result$env$a$active,
      !result$env$a$quiet, !result$env$b$active, result$env$b$label == "new")
  })
  mixed <- 'class Mixed { optional: Number = 1\nrequired: Text\nlast: Boolean = false }'
  check("required fields may follow defaults without changing positional matching", {
    result <- run(paste(mixed,
      'a = Mixed(required: "a")', 'b = Mixed(2, "b")',
      'c = Mixed(last: true, required: "c")', sep = "\n"))
    stopifnot(result$env$a$optional == 1, result$env$b$optional == 2,
      result$env$b$required == "b", !result$env$b$last,
      result$env$c$last, result$env$c$optional == 1)
    fails(paste(mixed, 'x = Mixed()', sep = "\n"), "Missing required field 'required'", 4, 5)
    fails(paste(mixed, 'x = Mixed(2)', sep = "\n"), "Missing required field 'required'")
    fails(paste(mixed, 'x = Mixed("a")', sep = "\n"), "Missing required field 'required'")
    fails(paste(mixed, 'x = Mixed(2, optional: 3)', sep = "\n"), "supplied more than once")
    fails(paste(mixed, 'x = Mixed(req: "a")', sep = "\n"), "names must match exactly")
  })
  check("invalid default declarations fail even when unused or overridden", {
    fails('class C {\nx: Number = "bad"\n}', "Default for field 'x' requires one Number", 2, 13)
    fails('class C { x: Text = false }', "requires one Text")
    fails('class C { x: Boolean = 1 }\nx = C(true)', "requires one Boolean")
    for (value in c('other', 'self.x', '[1]', '1 + 2', 'std::square_root(-1)',
                    'if true then 1 else 2', '--1')) {
      fails(paste0('class C { x: Number = ', value, ' }'), "scalar literals")
    }
    # Ordinary function defaults are still outside this slice.
    fails('fn f(x = 1) { return x }', "Expected")
  })
  check("constructor overrides retain static and runtime field checks", {
    fails(paste(counter, 'x = Counter("bad")', sep = "\n"), "requires one Number")
    fails(paste(counter, 'x = Counter([1, 2])', sep = "\n"), "requires one Number")
    fails(paste(counter, 'x = Counter(1, 2)', sep = "\n"), "expects 1 arguments")
    result <- run(paste(counter, 'fn make(value) { return Counter(value) }', sep = "\n"))
    for (value in list("bad", c(1, 2), structure(1, names = "x"))) {
      error <- tryCatch(result$env$make(value), rstarstar_error = identity)
      stopifnot(inherits(error, "rstarstar_error"))
    }
    stopifnot(result$env$make(8)$value == 8)
  })
  check("default constructors evaluate explicit arguments in source order", {
    source <- 'class Pair { left: Number = 0\nright: Number = 0 }\nx = Pair(right: average([1 / 0]), left: std::square_root(-1))'
    error <- tryCatch(run(source), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"),
      grepl("Numeric summaries require finite values", conditionMessage(error), fixed = TRUE))
  })
  check("public file API exposes default constructors to R callers", {
    path <- tempfile(fileext = ".rsspps")
    on.exit(unlink(path), add = TRUE)
    writeLines(paste(counter, 'x = Counter()', sep = "\n"), path)
    code <- RStarStar::transpile(path)
    result <- RStarStar::run_file(path)
    stopifnot(is.character(code), result$x$value == 0,
      result$Counter()$value == 0, result$Counter(value = 9)$value == 9)
    error <- tryCatch(result$Counter(value = "bad"), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"))
  })
  check("default constructors run standalone without compiler dependencies", {
    code <- transpile(paste(counter, 'mut c = Counter()\nc.increment(2)\nanswer = c.current()', sep = "\n"))
    script <- tempfile(fileext = ".R")
    on.exit(unlink(script), add = TRUE)
    writeLines(c(code, 'stopifnot(answer == 2, !"R6" %in% loadedNamespaces(), !"RStarStar" %in% loadedNamespaces())'), script)
    executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
    output <- system2(executable, c("--vanilla", "--default-packages=NULL", shQuote(script)), stdout = TRUE, stderr = TRUE)
    stopifnot(is.null(attr(output, "status")))
  })
})
