local({
  check("constructor errors list only omitted required fields in declaration order", {
    for (kind in c("record", "class")) {
      prefix <- paste0(kind, ' C { first: Number\noptional: Number = 0\nlast: Text }\n')
      fails(paste0(prefix, 'x = C()'), "Missing required fields 'first', 'last' for constructor 'C'.", 4, 5)
      fails(paste0(prefix, 'x = C(1)'), "Missing required field 'last' for constructor 'C'.")
      fails(paste0(prefix, 'x = C(last: "ok")'), "Missing required field 'first'")
      fails(paste0(prefix, 'x = C(optional: 2)'), "Missing required fields 'first', 'last'")
      stopifnot(run(paste0(prefix, 'x = C(last: "ok", first: 1)'))$env$x$optional == 0)
    }
  })
  check("constructor maximum counts describe optional fields accurately", {
    for (kind in c("record", "class")) {
      prefix <- paste0(kind, ' C { x: Number = 0 }\n')
      fails(paste0(prefix, 'c = C(1, 2)'), "Constructor 'C' accepts at most 1 argument; received 2.", 2, 5)
      stopifnot(run(paste0(prefix, 'c = C()'))$env$c$x == 0)
      fails(paste0(kind, ' Pair { x: Number\ny: Number }\np = Pair(1, 2, 3)'),
        "Constructor 'Pair' accepts at most 2 arguments; received 3.")
    }
  })
  check("incomplete constructors identify incorrect labels before missing fields", {
    for (kind in c("record", "class")) {
      prefix <- paste0(kind, ' C { width: Number\nheight: Number\ndepth: Number }\n')
      fails(paste0(prefix, 'c = C(w: 1)'), "Unknown parameter 'w' for constructor 'C'; names must match exactly.", 4, 7)
      fails(paste0(prefix, 'c = C(1, width: 2)'), "Parameter 'width' was supplied more than once.")
      fails(paste0(prefix, 'c = C(width: std::square_root(-1))'), "Missing required fields 'height', 'depth'")
    }
    fails('fn add(x, y) { return x + y }\nx = add(1)', "Function 'add' expects 2 arguments; received 1.")
  })
  check("public constructor diagnostics preserve paths and prevent execution", {
    with_source_file('print "must not run"\nrecord C { x: Number\ny: Text }\nc = C()', function(path) {
      error <- NULL
      output <- capture.output(error <- tryCatch(RStarStar::run_file(path), rstarstar_error = identity))
      stopifnot(length(output) == 0L, inherits(error, "rstarstar_error"),
        identical(error$filename, normalizePath(path)), error$line == 4L, error$column == 5L,
        grepl("Missing required fields 'x', 'y'", conditionMessage(error), fixed = TRUE))
    })
  })
})
