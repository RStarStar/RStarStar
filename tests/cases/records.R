check("records construct named and positional scalar fields", {
  result <- run('record Result {\nlabel: Text\nmean: Number\nvalid: Boolean\n}\na = Result(valid: true, mean: 12, label: "Sales")\nb = Result("Other", 5, false)\nlabel = a.label\nvalue = a.mean + b.mean')
  stopifnot(result$env$label == "Sales", result$env$value == 17,
            identical(names(result$env$a), c("label", "mean", "valid")),
            identical(attr(result$env$a, "rss_record_type"), "Result"))
})
check("record schemas reject malformed duplicate and unsupported fields", {
  fails('record Empty {}', "at least one field")
  fails('record Point { x: Number\nx: Number }', "must be unique")
  fails('record Point { x Number }', "Expected ':'")
  fails('record Point { x: Integer }', "Number, Text, or Boolean only")
  fails('record Point { x: Number y: Number }', "new line between record fields")
  fails('record Point { x: Number', "Expected '}' to close the record")
})
check("record names share the declaration namespace and cannot replace summaries", {
  fails('record sum { value: Number }', "cannot replace a built-in")
  fails('record Point { x: Number }\nrecord Point { y: Number }', "already declared")
  fails('Point = 1\nrecord Point { x: Number }', "already declared")
  fails('record Point { x: Number }\nfn Point(x) { return x }', "already declared")
  fails('record Point { x: Number }\nPoint = 1', "Cannot reassign")
  fails('p = Point(1)\nrecord Point { x: Number }', "Unknown variable")
})
check("record constructors enforce required names types and scalar lengths", {
  prefix <- 'record Point { x: Number\nlabel: Text }\n'
  fails(paste0(prefix, 'p = Point(x: 1)'), "expects 2 arguments")
  fails(paste0(prefix, 'p = Point(other: 1, label: "a")'), "Unknown parameter")
  fails(paste0(prefix, 'p = Point(x: 1, x: 2)'), "supplied more than once")
  fails(paste0(prefix, 'p = Point("text", "a")'), "requires one Number")
  fails(paste0(prefix, 'p = Point([1, 2], "a")'), "requires one Number")
  fails(paste0(prefix, 'p = Point(1, true)'), "requires one Text")
})
check("record fields validate dynamic values and retain constructor call locations", {
  prefix <- 'record Point { x: Number }\nfn identity(x) { return x }\n'
  for (value in c('"text"', '[1, 2]')) {
    error <- tryCatch(run(paste0(prefix, 'p = Point(identity(', value, '))')), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"), error$line == 1L,
              grepl("requires one plain Number", conditionMessage(error), fixed = TRUE),
              grepl("called at test.input:3:", conditionMessage(error), fixed = TRUE))
  }
})
check("functions construct pass and return records without ambient capture", {
  result <- run('record Point { x: Number }\nfn make(x) { return Point(x: x) }\nfn twice(point) { return point.x * 2 }\np = make(4)\nanswer = twice(p)')
  stopifnot(result$env$answer == 8)
  fails('record Point { x: Number }\np = Point(1)\nfn f() { return p.x }', "Unknown variable 'p'")
})
check("field lookup rejects unknown fields statically and dynamically", {
  prefix <- 'record Point { x: Number }\np = Point(1)\n'
  fails(paste0(prefix, 'x = p.other'), "Unknown record field 'other'")
  filter_error(paste0(prefix, 'fn bad(value) { return value.other }\nx = bad(p)'), "Unknown record field 'other'", 3L)
  result <- run(paste0(prefix, 'x = p."x"'))
  stopifnot(result$env$x == 1)
})
check("record bindings allow same-type replacement without changing aliases", {
  result <- run('record Point { x: Number }\nmut first = Point(1)\nsecond = first\nfirst = Point(2)\na = first.x\nb = second.x')
  stopifnot(result$env$a == 2, result$env$b == 1)
  fails('record Point { x: Number }\np = Point(1)\np = Point(2)', "Cannot reassign")
  fails('record Point { x: Number }\np = Point(1)\np.x = 2', "Expected '='")
})
check("mutable records retain nominal types even through dynamic functions", {
  prefix <- 'record A { x: Number }\nrecord B { x: Number }\n'
  fails(paste0(prefix, 'mut value = A(1)\nvalue = B(2)'), "from Record:A to Record:B")
  filter_error(paste0(prefix, 'fn same(value) { return value }\nmut value = same(A(1))\nvalue = same(B(2))'), "from Record:A to Record:B")
})
check("records do not silently acquire vector comparison or summary semantics", {
  prefix <- 'record Point { x: Number }\np = Point(1)\n'
  fails(paste0(prefix, 'x = [p]'), "Records cannot be vector elements")
  fails(paste0(prefix, 'x = p == p'), "Record comparisons are not supported")
  fails(paste0(prefix, 'x = p is missing'), "Test a record field")
  fails(paste0(prefix, 'x = count(p)'), "not a record")
  fails(paste0(prefix, 'x = p + 1'), "Arithmetic requires numbers")
  for (expression in c('value == value', '[value]', 'value is missing', 'count(value)')) {
    filter_error(paste0(prefix, 'fn bad(value) { return ', expression, ' }\nx = bad(p)'),
                 switch(expression, 'value == value' = "Record comparisons", '[value]' = "Records cannot", 'value is missing' = "Test a record field", 'count(value)' = "vector or table"))
  }
})
check("record fields support typed missing values and conditional record selection", {
  result <- run('record Point { x: Number }\na = Point(0 / 0)\nb = Point(2)\np = if false then a else b\nis_absent = a.x is missing\nvalue = p.x')
  stopifnot(result$env$is_absent, result$env$value == 2)
})
check("public execution exposes record constructors and independent R values", {
  with_source_file('record Point { x: Number }\np = Point(1)\nq = p', function(path) {
    generated <- RStarStar::transpile(path)
    env <- new.env(parent = baseenv())
    eval(parse(text = generated), env)
    result <- RStarStar::run_file(path)
    result$p$x <- 99
    stopifnot(env$p$x == 1, result$q$x == 1, result$Point(x = 3)$x == 3,
              RStarStar::run_file(path)$p$x == 1)
    for (bad in list(new.env(), list(1), as.Date("2026-01-01"), matrix(1), 1 + 1i, structure(1, reference = new.env()))) {
      stopifnot(inherits(tryCatch(result$Point(bad), error = identity), "rstarstar_error"))
    }
  })
})

check("record fields reject nested records and table values", {
  prefix <- 'record Point { x: Number }\n'
  fails(paste0(prefix, 'p = Point(Point(1))'), "requires one Number")
  with_sales(function(source) fails(paste0(prefix, source, 'p = Point(sales)'), "requires one Number"))
  filter_error(paste0(prefix, 'fn build(value) { return Point(value) }\np = build(Point(1))'), "requires one plain Number")
})
