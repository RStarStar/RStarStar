local({
  declarations <- 'record Point {
x: Number
y: Number
fn shifted(self, dx) { return self with { x: self.x + dx } }
}
record Position { point: Point\nlabel: Text }
class Tracker {
mut position: Position
mut moves: Number = 0
fn snapshot(self) { return self.position }
fn move(mut self, dx) {
self.position = self.position with { point: self.position.point.shifted(dx) }
self.moves = self.moves + 1
}
fn replace(mut self, next) {
self.moves = self.moves + 1
self.position = next
}
}'
  setup <- paste(declarations, 'point = Point(1, 2)', 'position = Position(point, "Home")',
    'first = Tracker(position)', 'mut second = first', sep = "\n")
  check("record-valued class state preserves inner outer and returned aliases", {
    result <- run(paste(setup, 'snapshot = second.snapshot()', 'second.move(3)',
      'second.move(2)', 'after = second.snapshot()', sep = "\n"))
    env <- result$env
    stopifnot(env$point$x == 1, env$position$point$x == 1,
      env$first$position$point$x == 1, env$snapshot$point$x == 1,
      env$after$point$x == 6, env$second$moves == 2,
      env$after$point$y == 2, env$after$label == "Home")
  })
  check("class record fields enforce nominal types during compilation", {
    fails(paste(declarations, 't = Tracker(Point(1, 2))', sep = "\n"), "requires one Record:Position")
    fails(paste(declarations, 't = Tracker(1)', sep = "\n"), "requires one Record:Position")
    fails('record Point { x: Number }\nclass C { mut p: Point\nfn bad(mut self) { self.p = 1 } }', "requires one Record:Point")
    fails('record Point { x: Number }\nclass C { p: Point = 0 }', "Default for field 'p' requires one Record:Point")
    fails('record Point { x: Number }\nclass C { p: Point = Point(0) }', "scalar literals")
    fails('class C { p: Point }\nrecord Point { x: Number }', "earlier record type", 1, 14)
    fails('class C { p: C }', "earlier record type")
    fails('class Inner { x: Number }\nclass C { p: Inner }', "earlier record type")
  })
  check("record state remains private and requires whole field replacement", {
    fails(paste(setup, 'x = second.position.point.x', sep = "\n"), "fields are private")
    filter_error(paste(declarations, 'fn peek(t) { return t.position }',
      'x = peek(Tracker(Position(Point(1, 2), "Home")))', sep = "\n"), "fields are private")
    fails('record Point { x: Number }\nclass C { p: Point\nfn move(mut self) { self.p = self.p with { x: 2 } } }', "is immutable")
    fails('record Point { x: Number }\nclass C { mut p: Point\nfn move(mut self) { self.p.x = 2 } }', "Expected '='")
    fails(paste(setup, 'first.move(1)', sep = "\n"), "mutable receiver binding")
    result <- run(paste(setup, 'copy = second.snapshot() with { label: "Away" }', sep = "\n"))
    stopifnot(result$env$copy$label == "Away", result$env$second$position$label == "Home")
  })
  check("later record replacement failure leaves all class fields unchanged", {
    source <- paste(setup, 'second.replace(Point(9, 9))', sep = "\n")
    env <- new.env(parent = baseenv())
    error <- tryCatch(eval(parse(text = transpile(source, "state.input")), env), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"), error$filename == "state.input",
      error$line == 18L, error$column == 6L,
      grepl("requires one plain Record:Position", conditionMessage(error), fixed = TRUE),
      grepl("called at state.input:", conditionMessage(error), fixed = TRUE),
      identical(env$first, env$second), env$second$moves == 0)
  })
  check("nested copy update failure also preserves the committed receiver", {
    source <- paste(setup, 'second.move("bad")', sep = "\n")
    env <- new.env(parent = baseenv())
    error <- tryCatch(eval(parse(text = transpile(source)), env), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"), identical(env$first, env$second),
      env$second$position$point$x == 1, env$second$moves == 0)
  })
  check("class constructors recursively validate R-supplied record schemas", {
    result <- run(paste(declarations,
      'fn snapshot(t) { return t.snapshot() }', sep = "\n"))$env
    good <- result$Position(result$Point(1, 2), "Home")
    bad <- list()
    value <- good; value$point$x <- "bad"; bad[[1]] <- value
    value <- good; value$point$extra <- 1; bad[[2]] <- value
    value <- good; value$point$y <- NULL; bad[[3]] <- value
    value <- good; value$point$x <- new.env(); bad[[4]] <- value
    value <- good; value$point$x <- structure(1, names = "x"); bad[[5]] <- value
    value <- good; attr(value$point, "foreign") <- new.env(); bad[[6]] <- value
    value <- good; attr(value$point, "rss_record_type") <- "Other"; bad[[7]] <- value
    value <- good; value$point <- list(x = 1, y = 2); bad[[8]] <- value
    for (value in bad) {
      error <- tryCatch(result$Tracker(value), rstarstar_error = identity)
      stopifnot(inherits(error, "rstarstar_error"))
      receiver <- result$Tracker(good); receiver$position <- value
      error <- tryCatch(result$snapshot(receiver), rstarstar_error = identity)
      stopifnot(inherits(error, "rstarstar_error"))
    }
    stopifnot(result$Tracker(good)$position$point$x == 1)
  })
  check("dynamic replacement validates nested layouts before committing", {
    env <- run(setup)$env
    malformed <- env$position; malformed$point$x <- "bad"
    env$malformed <- malformed
    # Supply an externally modified R value to an otherwise valid generated call.
    code <- transpile(paste(setup, 'second.replace(position)', sep = "\n"))
    statements <- parse(text = code)
    last <- statements[[length(statements)]]
    env$position <- malformed
    error <- tryCatch(eval(last, env), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"), identical(env$first, env$second))
  })
  check("record state example works through installed public APIs", {
    path <- system.file("examples", "record-state.rsspps", package = "RStarStar", mustWork = TRUE)
    invisible(capture.output(result <- RStarStar::run_file(path)))
    stopifnot(result$before$x == 0, result$origin$x == 0,
      result$after$x == 3, result$after$y == 4, result$move_count == 1)
    result$after$x <- 99
    stopifnot(result$second$position$x == 3, result$first$position$x == 0)
    script <- tempfile(fileext = ".R")
    on.exit(unlink(script), add = TRUE)
    writeLines(c(RStarStar::transpile(path),
      'stopifnot(after$x == 3, before$x == 0, !"R6" %in% loadedNamespaces(), !"RStarStar" %in% loadedNamespaces())'), script)
    executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
    output <- system2(executable, c("--vanilla", "--default-packages=NULL", shQuote(script)), stdout = TRUE, stderr = TRUE)
    stopifnot(is.null(attr(output, "status")))
  })
})
