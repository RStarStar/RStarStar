check("nested records construct and expose chained fields", {
  result <- run('record Point { x: Number\ny: Number }\nrecord Place { name: Text\nlocation: Point }\np = Place(location: Point(1, 2), name: "Home")\nx = p.location.x\ny = Place("Work", Point(3, 4)).location.y')
  stopifnot(result$env$x == 1, result$env$y == 4)
})
check("nested schemas reject unknown forward recursive and ambiguous types", {
  fails('record Place { location: Point }\nrecord Point { x: Number }', "earlier record type", 1, 26)
  fails('record Node { next: Node }', "Unknown field type 'Node'")
  fails('record Place { location: Table }', "Unknown field type 'Table'")
  fails('record Number { x: Number }', "cannot replace a built-in field type")
  fails('fn Point(x) { return x }\nrecord Place { location: Point }', "Unknown field type 'Point'")
})
check("nested fields enforce nominal types statically and dynamically", {
  prefix <- 'record Point { x: Number }\nrecord Other { x: Number }\nrecord Place { location: Point }\n'
  fails(paste0(prefix, 'p = Place(Other(1))'), "requires one Record:Point")
  fails(paste0(prefix, 'p = Place(1)'), "requires one Record:Point")
  filter_error(paste0(prefix, 'fn wrap(value) { return Place(value) }\np = wrap(Other(1))'), "requires one plain Record:Point")
})
check("nested updates preserve inner outer and sibling aliases", {
  result <- run('record Point { x: Number }\nrecord Place { location: Point }\ninner = Point(1)\na = Place(inner)\nb = a\nc = a with {location: a.location with {x: 2}}\nx = c.location.x')
  stopifnot(result$env$inner$x == 1, result$env$a$location$x == 1,
            result$env$b$location$x == 1, result$env$x == 2)
})
check("nested functions retain deep field types and update validation", {
  prefix <- 'record Point { x: Number }\nrecord Place { location: Point }\n'
  result <- run(paste0(prefix, 'fn shift(value) { return value with {location: value.location with {x: value.location.x + 1}} }\np = shift(Place(Point(3)))\nx = p.location.x'))
  stopifnot(result$env$x == 4)
  fails(paste0(prefix, 'p = Place(Point(1))\nx = p.location.unknown'), "Unknown record field")
  filter_error(paste0(prefix, 'fn bad(value) { return value with {location: value.location with {x: "bad"}} }\np = bad(Place(Point(1)))'), "requires one plain Number")
})
check("nested equality preserves nominal and three-valued semantics", {
  result <- run('record Point { x: Number }\nrecord Place { label: Text\nlocation: Point }\na = Place("A", Point(1))\nb = Place("A", Point(1))\nequal = a == b\ndifferent = a != (b with {location: Point(2)})\nu = Place("A", Point(0 / 0))\nv = Place("B", Point(0 / 0))\nunknown = u == u\ndefinite = u == v')
  stopifnot(isTRUE(result$env$equal), isTRUE(result$env$different),
            identical(result$env$unknown, NA), identical(result$env$definite, FALSE))
})
check("three-level records remain independent through R result transfer", {
  with_source_file('record Point { x: Number }\nrecord Place { location: Point }\nrecord Trip { destination: Place }\nfn same(a, b) { return a == b }\na = Trip(Place(Point(1)))\nb = a', function(path) {
    result <- RStarStar::run_file(path)
    stopifnot(isTRUE(result$same(result$a, result$b)))
    result$a$destination$location$x <- 9
    stopifnot(result$b$destination$location$x == 1)
    env <- new.env(parent = baseenv())
    eval(parse(text = RStarStar::transpile(path)), env)
    stopifnot(env$a$destination$location$x == 1)
    invalid <- result$Point(1)
    invalid$x <- new.env()
    stopifnot(inherits(tryCatch(result$Place(invalid), error = identity), "rstarstar_error"))
    invalid <- result$Point(1)
    attr(invalid, "foreign") <- new.env()
    stopifnot(inherits(tryCatch(result$Place(invalid), error = identity), "rstarstar_error"))
  })
})
