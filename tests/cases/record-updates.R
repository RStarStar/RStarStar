check("record updates preserve originals aliases field order and nominal type", {
  result <- run('record Point { x: Number\ny: Number }\np = Point(1, 2)\ncopy = p\nq = p with { y: 5 }')
  stopifnot(result$env$p$y == 2, result$env$copy$y == 2, result$env$q$y == 5,
            result$env$q$x == 1, identical(names(result$env$q), c("x", "y")),
            identical(attr(result$env$q, "rss_record_type"), "Point"))
})
check("record updates use original scope for all simultaneous replacements", {
  result <- run('record Point { x: Number\ny: Number }\np = Point(1, 2)\nq = p with {\nx: p.y,\ny: p.x\n}\nmut current = p\ncurrent = current with {x: 4, y: current.x}')
  stopifnot(result$env$q$x == 2, result$env$q$y == 1,
            result$env$current$x == 4, result$env$current$y == 1)
})
check("updates accept constructor function and parenthesized receivers and chain", {
  result <- run('record Point { x: Number }\nfn make(x) { return Point(x) }\na = Point(1) with {x: 2} with {x: 3}\nb = make(4) with {x: 5}\nc = (if true then a else b) with {x: 6}')
  stopifnot(result$env$a$x == 3, result$env$b$x == 5, result$env$c$x == 6)
})
check("record updates reject malformed duplicates unknown fields and invalid replacements", {
  prefix <- 'record Point { x: Number }\np = Point(1)\n'
  fails(paste0(prefix, 'q = p with {}'), "at least one field")
  fails(paste0(prefix, 'q = p with {x: 2, x: 3}'), "must be unique")
  fails(paste0(prefix, 'q = p with {other: 2}'), "Unknown record field 'other'", 3, 13)
  fails(paste0(prefix, 'q = p with {x: "text"}'), "requires one Number")
  fails(paste0(prefix, 'q = p with {x: [1, 2]}'), "requires one Number")
  fails(paste0(prefix, 'q = p with {x = 2}'), "Expected ':'")
  fails(paste0(prefix, 'q = p with {x: 2'), "Expected '}'")
  fails('q = 1 with {x: 2}', "requires a record")
  fails(paste0(prefix, 'p = p with {x: 2}'), "Cannot reassign")
})
check("dynamic record update failures retain update source and language call chains", {
  prefix <- 'record Point { x: Number }\nfn replace(value, x) { return value with {x: x} }\n'
  for (call in c('replace(Point(1), "text")', 'replace(Point(1), [1, 2])', 'replace(1, 2)')) {
    error <- tryCatch(run(paste0(prefix, 'q = ', call)), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"), error$line == 2L,
              grepl("called at test.input:3:", conditionMessage(error), fixed = TRUE))
  }
  filter_error(paste0('record Point { x: Number }\nfn bad(value) { return value with {other: 2} }\nq = bad(Point(1))'), "Unknown record field 'other'")
})
check("replacement expression errors follow source order and unchosen updates stay lazy", {
  prefix <- 'record Point { x: Number\ny: Number }\np = Point(1, 2)\n'
  error <- tryCatch(run(paste0(prefix, 'q = p with {y: average([0 / 0]), x: average([0 / 0])}')), rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"), error$line == 4L, error$column == 16L)
  result <- run(paste0(prefix, 'q = if true then p else p with {x: average([0 / 0])}'))
  stopifnot(result$env$q$x == 1)
})
check("public record update functions return new records and leave inputs on failure", {
  with_source_file('record Point { x: Number }\nfn replace(value, x) { return value with {x: x} }\np = Point(1)\nq = replace(p, 2)', function(path) {
    result <- RStarStar::run_file(path)
    changed <- result$replace(result$p, 3)
    error <- tryCatch(result$replace(result$p, "bad"), error = identity)
    stopifnot(result$p$x == 1, result$q$x == 2, changed$x == 3, inherits(error, "rstarstar_error"))
    standalone <- new.env(parent = baseenv())
    eval(parse(text = RStarStar::transpile(path)), standalone)
    stopifnot(standalone$p$x == 1, standalone$q$x == 2)
  })
})

check("record update AST preserves receiver and multiline update span", {
  ast <- rss_parse(rss_tokenize("q = p with {\nx: 2\n}", "update.input"), "update.input")
  value <- ast[[1L]]$value
  stopifnot(value$span$line == 1L, value$span$column == 5L,
            value$span$end_line == 3L, value$span$end_column == 2L,
            value$token$column == 7L, value$field_tokens[[1L]]$line == 2L)
})
