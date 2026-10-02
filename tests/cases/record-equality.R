check("record equality compares all scalar fields independently of construction order", {
  result <- run('record Sample { label: Text\nvalue: Number\nactive: Boolean }\na = Sample("A", 1, true)\nb = Sample(active: true, value: 1, label: "A")\nc = a with {value: 2}\nequal = a == b\ndifferent = a != c\nunequal = a == c\nsame = a != b')
  stopifnot(isTRUE(result$env$equal), isTRUE(result$env$different),
            identical(result$env$unequal, FALSE), identical(result$env$same, FALSE))
})
check("record equality notices text boolean and numeric differences", {
  result <- run('record Sample { label: Text\nvalue: Number\nactive: Boolean }\na = Sample("A", 1, true)\nx = a == (a with {label: "B"})\ny = a == (a with {active: false})\nz = a == (a with {value: 2})')
  stopifnot(identical(result$env$x, FALSE), identical(result$env$y, FALSE), identical(result$env$z, FALSE))
})
check("missing record fields yield unknown unless another field definitely differs", {
  result <- run('record Point { x: Number\ny: Number }\na = Point(0 / 0, 1)\nb = Point(0 / 0, 1)\nc = Point(0 / 0, 2)\nx = a == b\ny = a != b\nz = a == c\nw = a != c\nu = (a == b) is missing')
  stopifnot(identical(result$env$x, NA), identical(result$env$y, NA),
            identical(result$env$z, FALSE), identical(result$env$w, TRUE), isTRUE(result$env$u))
})
check("different nominal types and record-to-scalar equality are errors", {
  prefix <- 'record A { x: Number }\nrecord B { x: Number }\na = A(1)\nb = B(1)\n'
  fails(paste0(prefix, 'x = a == b'), "matching value types")
  fails(paste0(prefix, 'x = a != 1'), "matching value types")
  for (right in c('b', '1')) {
    filter_error(paste0(prefix, 'fn same(left, right) { return left == right }\nx = same(a, ', right, ')'), "same declared record type")
  }
})
check("record ordering remains rejected both statically and dynamically", {
  prefix <- 'record Point { x: Number }\na = Point(1)\n'
  for (op in c('<', '<=', '>', '>=')) {
    fails(paste0(prefix, 'x = a ', op, ' a'), "ordering is not defined")
    filter_error(paste0(prefix, 'fn compare(left, right) { return left ', op, ' right }\nx = compare(a, a)'), "ordering is not defined")
  }
})
check("record equality works in conditionals and retains missing-condition failures", {
  result <- run('record Point { x: Number }\na = Point(1)\nb = Point(1)\nanswer = if a == b then "same" else "different"')
  stopifnot(result$env$answer == "same")
  filter_error('record Point { x: Number }\na = Point(0 / 0)\nx = if a == a then 1 else 2', "exactly one nonmissing boolean")
})
check("record equality runtime errors preserve comparison location and call chain", {
  error <- tryCatch(run('record A { x: Number }\nrecord B { x: Number }\nfn same(a, b) { return a == b }\nx = same(A(1), B(1))'), rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"), error$line == 3L, error$column == 26L,
            grepl("called at test.input:4:", conditionMessage(error), fixed = TRUE))
})
check("public equality functions handle typed missing fields and reject malformed R values", {
  with_source_file('record Sample { label: Text\nvalue: Number\nactive: Boolean }\nfn same(a, b) { return a == b }', function(path) {
    result <- RStarStar::run_file(path)
    a <- result$Sample(NA_character_, NA_real_, NA)
    b <- result$Sample(NA_character_, NA_real_, NA)
    stopifnot(identical(result$same(a, b), NA))
    good <- result$Sample("A", 1, TRUE)
    stopifnot(isTRUE(result$same(good, good)))
    malformed <- good
    malformed$value <- c(1, 2)
    stopifnot(inherits(tryCatch(result$same(good, malformed), error = identity), "rstarstar_error"))
    malformed <- good
    names(malformed)[1L] <- "other"
    stopifnot(inherits(tryCatch(result$same(good, malformed), error = identity), "rstarstar_error"))
    env <- new.env(parent = baseenv())
    eval(parse(text = RStarStar::transpile(path)), env)
    stopifnot(isTRUE(env$same(env$Sample("A", 1, TRUE), env$Sample("A", 1, TRUE))))
  })
})
