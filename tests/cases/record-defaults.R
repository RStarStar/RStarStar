local({
  point <- 'record Point {
x: Number = 0
y: Number = -1
fn shifted(self, dx) { return self with { x: self.x + dx } }
}'
  check("record defaults work with overrides methods copies and equality", {
    result <- run(paste(point, 'origin = Point()', 'same = Point(0, -1)',
      'custom = Point(y: 4)', 'shifted = origin.shifted(3)',
      'copy = custom with { x: 9 }', 'equal = origin == same', sep = "\n"))$env
    stopifnot(result$origin$x == 0, result$origin$y == -1,
      result$custom$x == 0, result$custom$y == 4,
      result$shifted$x == 3, result$copy$x == 9, result$copy$y == 4,
      result$equal)
  })
  check("record required fields coexist with all scalar default types", {
    prefix <- 'record Settings { label: Text = "Untitled"\nrequired: Number\nactive: Boolean = true\nquiet: Boolean = false\nlimit: Number = (+2) }'
    result <- run(paste(prefix, 'a = Settings(required: 7)',
      'b = Settings("Named", 8, active: false)', sep = "\n"))$env
    stopifnot(result$a$label == "Untitled", result$a$required == 7,
      result$a$active, !result$a$quiet, result$a$limit == 2,
      result$b$label == "Named", !result$b$active)
    fails(paste(prefix, 'a = Settings()', sep = "\n"), "Missing required field 'required'")
    fails(paste(prefix, 'a = Settings(req: 7)', sep = "\n"), "names must match exactly")
    fails(paste(prefix, 'a = Settings("A", label: "B")', sep = "\n"), "supplied more than once")
    fails(paste(point, 'a = Point(1, 2, 3)', sep = "\n"), "expects 2 arguments")
  })
  check("record default errors identify declarations and reject execution", {
    fails('record Bad {\nx: Number = "bad"\n}', "Default for field 'x' requires one Number", 2, 13)
    fails('record Bad { x: Text = 1 }', "requires one Text")
    fails('record Bad { x: Boolean = "true" }', "requires one Boolean")
    for (value in c('outer', 'self.x', '[1]', '1 + 2', '(1 + 2)', '--1', 'std::square_root(-1)',
                    'if true then 1 else 2')) {
      fails(paste0('record Bad { x: Number = ', value, ' }'), "scalar literals")
    }
    fails(paste(point, 'p = Point("bad")', sep = "\n"), "requires one Number")
    fails(paste(point, 'p = Point([1, 2])', sep = "\n"), "requires one Number")
    # Even an unused default is checked rather than being hidden by an override.
    fails('record Bad { x: Number = "bad" }\na = Bad(1)', "Default for field")
  })
  check("nested records still require values and preserve initialized copies", {
    prefix <- paste(point, 'record Place { label: Text = "Home"\nposition: Point }', sep = "\n")
    result <- run(paste(prefix, 'a = Place(position: Point())',
      'b = a with { position: a.position.shifted(2) }', sep = "\n"))$env
    stopifnot(result$a$position$x == 0, result$b$position$x == 2,
      result$b$position$y == -1, result$a$label == "Home")
    fails(paste(prefix, 'a = Place()', sep = "\n"), "Missing required field 'position'")
    fails(paste(point, 'record Bad { position: Point = Point() }', sep = "\n"), "scalar literals")
    fails(paste(point, 'record Bad { position: Point = 0 }', sep = "\n"), "requires one Record:Point")
  })
  check("record defaults cross the public R API with checked overrides", {
    path <- tempfile(fileext = ".rsspps")
    on.exit(unlink(path), add = TRUE)
    writeLines(paste(point, 'fn make(value) { return Point(x: value) }\na = Point()', sep = "\n"), path)
    result <- RStarStar::run_file(path)
    stopifnot(result$Point()$x == 0, result$Point(y = 3)$y == 3,
      result$make(8)$x == 8, result$make(8)$y == -1)
    for (value in list("bad", c(1, 2), structure(1, names = "x"))) {
      error <- tryCatch(result$make(value), rstarstar_error = identity)
      stopifnot(inherits(error, "rstarstar_error"))
    }
    script <- tempfile(fileext = ".R")
    on.exit(unlink(script), add = TRUE)
    writeLines(c(RStarStar::transpile(path),
      'stopifnot(a$x == 0, a$y == -1, !"R6" %in% loadedNamespaces(), !"RStarStar" %in% loadedNamespaces())'), script)
    executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
    output <- system2(executable, c("--vanilla", "--default-packages=NULL", shQuote(script)), stdout = TRUE, stderr = TRUE)
    stopifnot(is.null(attr(output, "status")))
  })
  check("parenthesized defaults share record and class literal rules", {
    for (kind in c("record", "class")) {
      result <- run(paste0(kind, ' C { n: Number = (-((2)))\nt: Text = ("hi")\nb: Boolean = ((false)) }\nx = C()'))$env
      stopifnot(result$x$n == -2, result$x$t == "hi", !result$x$b)
      fails(paste0(kind, ' C { n: Number = ((1 + 2)) }'), "scalar literals")
      fails(paste0(kind, ' C { n: Number = (-(-2)) }'), "scalar literals")
    }
  })
  check("record defaults preserve explicit argument evaluation order", {
    error <- tryCatch(run(paste(point,
      'p = Point(y: average([1 / 0]), x: std::square_root(-1))', sep = "\n")), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"),
      grepl("Numeric summaries require finite values", conditionMessage(error), fixed = TRUE))
  })
})
