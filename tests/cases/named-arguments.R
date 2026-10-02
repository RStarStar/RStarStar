check("named calls use exact parameter names in any named order", {
  result <- run('fn subtract(left, right) { return left - right }\na = subtract(right: 2, left: 10)\nb = subtract(10, right: 2)\nc = subtract(left: 10, right: 2)')
  stopifnot(result$env$a == 8, result$env$b == 8, result$env$c == 8)
})
check("named arguments support multiline nested and conditional expressions", {
  result <- run('fn add(left, right) { return left + right }\nanswer = add(\nright: add(right: 2, left: 3),\nleft: if true then [1, 2] else [3, 4]\n)')
  stopifnot(identical(result$env$answer, c(6, 7)))
})
check("named calls reject partial unknown duplicate and conflicting names", {
  prefix <- 'fn add(left, right) { return left + right }\n'
  fails(paste0(prefix, 'x = add(l: 1, right: 2)'), "names must match exactly", 2, 9)
  fails(paste0(prefix, 'x = add(other: 1, right: 2)'), "Unknown parameter 'other'")
  fails(paste0(prefix, 'x = add(left: 1, left: 2)'), "supplied more than once", 2, 18)
  fails(paste0(prefix, 'x = add(1, left: 2)'), "supplied more than once")
})
check("named calls retain exact arity and positional-before-named ordering", {
  prefix <- 'fn add(left, right) { return left + right }\n'
  fails(paste0(prefix, 'x = add(left: 1)'), "expects 2 arguments")
  fails(paste0(prefix, 'x = add(left: 1, right: 2, extra: 3)'), "expects 2 arguments")
  fails(paste0(prefix, 'x = add(right: 1, 2)'), "Positional arguments must come before named")
  fails(paste0(prefix, 'x = add(left: , right: 2)'), "Expected a value")
  fails(paste0(prefix, 'x = add(left = 1, right = 2)'), "Expected ')' after function arguments")
})
check("named argument failures follow source order rather than parameter order", {
  error <- tryCatch(run('fn ignore(first, second) { return 1 }\nx = ignore(second: average([0 / 0]), first: average([0 / 0]))'), rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"), error$line == 2L, error$column == 20L)
})
check("named arguments retain function scope filter scope and table values", {
  with_sales(function(prefix) {
    result <- run(paste0('fn above(value, threshold) { return value > threshold }\nfn mean_revenue(data) { return average(data.revenue) skipping missing }\n', prefix,
                        'minimum = 100\nfilter sales where above(threshold: @minimum, value: revenue) skipping missing into selected\nmean = mean_revenue(data: sales)'))
    stopifnot(identical(result$env$selected$region, "North"), result$env$mean == 102.5)
  })
  fails('outside = 1\nfn f(value) { return value }\nfn g() { return f(value: outside) }', "Unknown variable 'outside'")
})
check("named calls preserve body diagnostics and call chains", {
  error <- tryCatch(run('fn increment(value) { return value + 1 }\nx = increment(value: "text")'), rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"), error$line == 1L,
            grepl("called at test.input:2:", conditionMessage(error), fixed = TRUE))
})
check("named calls quote R-reserved parameter names and coexist with zero arguments", {
  result <- run('fn add(repeat, TRUE) { return repeat + TRUE }\nfn zero() { return 0 }\nx = add(TRUE: 2, repeat: 5) + zero()')
  stopifnot(result$env$x == 7)
})
check("named calls execute through public file API and standalone generated R", {
  with_source_file('fn divide(numerator, denominator) { return numerator / denominator }\nvalue = divide(denominator: 2, numerator: 10)', function(path) {
    result <- RStarStar::run_file(path)
    standalone <- new.env(parent = baseenv())
    eval(parse(text = RStarStar::transpile(path)), standalone)
    stopifnot(result$value == 5, standalone$value == 5)
  })
})
