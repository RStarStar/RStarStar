check("field access reads constructor and function results directly", {
  result <- run('record Point { x: Number }\nfn make(value) { return Point(value) }\na = Point(3).x\nb = make(4).x + 2')
  stopifnot(result$env$a == 3, result$env$b == 6)
})
check("field access follows record updates and parenthesized conditionals", {
  result <- run('record Point { x: Number }\np = Point(1)\na = (p with {x: 2}).x\nb = p with {x: 3}.x\nc = (if true then p else Point(9)).x')
  stopifnot(result$env$a == 2, result$env$b == 3, result$env$c == 1, result$env$p$x == 1)
})
check("returned tables support quoted headers and scalar summaries", {
  with_sales(function(prefix) {
    result <- run(paste0('fn same(value) { return value }\n', prefix,
                        'revenue = same(sales).revenue\nmean = average(same(sales).revenue) skipping missing\norders = (sales)."Order total"'))
    stopifnot(identical(result$env$revenue, c(120, 85, NA_real_)), result$env$mean == 102.5,
              identical(result$env$orders, c(10, 20, 30)))
  })
})
check("postfix fields keep filter argument and explicit variable scope", {
  with_sales(function(prefix) {
    result <- run(paste0('record Limit { value: Number }\nfn limit(value) { return Limit(value) }\n', prefix,
                        'minimum = 100\nfilter sales where revenue > limit(@minimum).value skipping missing into selected'))
    stopifnot(identical(result$env$selected$region, "North"))
  })
})
check("field expressions reject missing fields malformed syntax and scalar receivers", {
  fails('record Point { x: Number }\nx = Point(1).other', "Unknown record field", 2, 13)
  fails('record Point { x: Number }\nx = Point(1).x.other', "requires a table or record")
  fails('x = (1).field', "requires a table or record")
  fails('record Point { x: Number }\nx = Point(1).', "Expected a field name")
  fails('record Point { x: Number }\nx = Point(1).2', "Expected a field name")
  filter_error('fn same(value) { return value }\nx = same(1).field', "requires a table or record", 2L, 12L)
  with_sales(function(prefix) filter_error(paste0('fn same(value) { return value }\n', prefix, 'x = same(sales).unknown'), "Unknown column"))
})
check("member receivers preserve lazy evaluation and function error locations", {
  result <- run('record Point { x: Number }\nx = (if true then Point(1) else Point(average([0 / 0]))).x')
  stopifnot(result$env$x == 1)
  error <- tryCatch(run('record Point { x: Number }\nfn bad() { return Point(average([0 / 0])) }\nx = bad().x'), rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"), error$line == 2L,
            grepl("called at test.input:3:", conditionMessage(error), fixed = TRUE))
})
check("member AST spans retain the full receiver and field suffix", {
  ast <- rss_parse(rss_tokenize('x = (\nPoint(1)\n)."x"', "members.input"), "members.input")
  member <- ast[[1L]]$value
  stopifnot(member$kind == "member", member$span$line == 1L, member$span$column == 5L,
            member$span$end_line == 3L, member$span$end_column == 6L,
            member$token$line == 3L, member$token$column == 2L)
})
check("public file execution and standalone code support field expressions", {
  with_source_file('record Point { x: Number }\nfn shifted(value) { return (value with {x: value.x + 1}).x }\nx = shifted(Point(3))', function(path) {
    result <- RStarStar::run_file(path)
    stopifnot(result$x == 4, result$shifted(result$Point(8)) == 9)
    env <- new.env(parent = baseenv())
    eval(parse(text = RStarStar::transpile(path)), env)
    stopifnot(env$x == 4)
  })
})
