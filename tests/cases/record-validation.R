local({
  source <- 'record Point { x: Number\ny: Number = 0 }
record Other { x: Number\ny: Number = 0 }
record Place { point: Point\nlabel: Text = "Home" }
record Trip { destination: Place }
fn wrap(p) { return Place(p) }
fn replace(p, value) { return p with { point: value } }
fn rename(p) { return p with { label: "Away" } }
fn move(p) { return p with { x: 2 } }'
  check("record constructors reject malformed nested R values recursively", {
    env <- run(source)$env
    good <- env$Point(1)
    invalid <- list()
    p <- good; p$x <- "bad"; invalid[[1]] <- p
    p <- good; p$extra <- 3; invalid[[2]] <- p
    p <- good; p$y <- NULL; invalid[[3]] <- p
    p <- good; names(p) <- c("y", "x"); invalid[[4]] <- p
    p <- good; p$x <- c(1, 2); invalid[[5]] <- p
    p <- good; attr(p, "foreign") <- new.env(); invalid[[6]] <- p
    invalid[[7]] <- env$Other(1)
    for (p in invalid) {
      error <- tryCatch(env$Place(p), rstarstar_error = identity)
      stopifnot(inherits(error, "rstarstar_error"),
        grepl("requires one plain Record:Point", conditionMessage(error), fixed = TRUE))
      place <- env$Place(good); place$point <- p
      stopifnot(inherits(tryCatch(env$Trip(place), rstarstar_error = identity), "rstarstar_error"))
    }
  })
  check("copy updates reject malformed receivers before repairing them", {
    env <- run(source)$env
    good <- env$Point(1)
    for (kind in c("type", "extra", "missing", "unknown")) {
      p <- good
      if (kind == "type") p$x <- "bad"
      if (kind == "extra") p$extra <- 1
      if (kind == "missing") p$y <- NULL
      if (kind == "unknown") attr(p, "rss_record_type") <- "Unknown"
      before <- p
      error <- tryCatch(env$move(p), rstarstar_error = identity)
      stopifnot(inherits(error, "rstarstar_error"), identical(p, before),
        grepl("Record update receiver does not match", conditionMessage(error), fixed = TRUE))
    }
    p <- env$Place(good); p$point$x <- "bad"
    stopifnot(inherits(tryCatch(env$rename(p), rstarstar_error = identity), "rstarstar_error"))
  })
  check("copy updates check replacement schemas and preserve original values", {
    env <- run(source)$env
    good <- env$Place(env$Point(1))
    replacement <- env$Point(3); replacement$x <- "bad"
    error <- tryCatch(env$replace(good, replacement), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"), good$point$x == 1,
      error$line == 9L, grepl("requires one plain Record:Point", conditionMessage(error), fixed = TRUE))
    updated <- env$replace(good, env$Point(3))
    stopifnot(updated$point$x == 3, good$point$x == 1, updated$label == "Home")
  })
  check("record validation preserves supported scalar and structural R inputs", {
    env <- run(source)$env
    for (value in list(1L, NA_real_, NaN, Inf)) {
      point <- env$Point(value)
      place <- env$Place(point)
      stopifnot(identical(place$point$x, value), env$rename(place)$label == "Away")
    }
    # Layout validation is not provenance: a matching plain tagged value is accepted.
    point <- structure(list(x = 4, y = 5), rss_record_type = "Point")
    stopifnot(env$Place(point)$point$x == 4)
  })
  check("public constructors report declaration and language call locations", {
    with_source_file(source, function(path) {
      result <- RStarStar::run_file(path)
      point <- result$Point(1); point$x <- "bad"
      error <- tryCatch(result$wrap(point), rstarstar_error = identity)
      stopifnot(inherits(error, "rstarstar_error"), error$line == 5L,
        identical(error$filename, normalizePath(path)),
        grepl("called at", conditionMessage(error), fixed = TRUE))
      script <- tempfile(fileext = ".R")
      on.exit(unlink(script), add = TRUE)
      writeLines(c(RStarStar::transpile(path),
        'p <- Point(1); p$x <- "bad"',
        'stopifnot(inherits(tryCatch(Place(p), error=identity), "rstarstar_error"))',
        'stopifnot(!"R6" %in% loadedNamespaces(), !"RStarStar" %in% loadedNamespaces())'), script)
      executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
      output <- system2(executable, c("--vanilla", "--default-packages=NULL", shQuote(script)), stdout=TRUE, stderr=TRUE)
      stopifnot(is.null(attr(output, "status")))
    })
  })
})
