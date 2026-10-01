check("functions accept parameters and preserve vector operations", {
  result <- run('fn add_tax(amount, rate) { return amount * (1 + rate) }\nanswer = add_tax([10, 20], 0.1)')
  stopifnot(identical(result$env$answer, c(11, 22)))
})
check("function body newlines and zero-argument functions", {
  result <- run('fn answer() {\n# a comment\nreturn 42\n}\nvalue = answer()')
  stopifnot(result$env$value == 42)
})
check("functions compose in declaration order", {
  result <- run('fn double(x) { return x * 2 }\nfn quadruple(x) { return double(double(x)) }\nvalue = quadruple(3)')
  stopifnot(result$env$value == 12)
})
check("functions accept tables and can compute summaries", {
  with_sales(function(prefix) {
    result <- run(paste0('fn revenue_mean(data) { return average(data.revenue) skipping missing }\n', prefix, 'value = revenue_mean(sales)'))
    stopifnot(result$env$value == 102.5)
  })
})
check("function predicates retain filter column and local rules", {
  with_sales(function(prefix) {
    result <- run(paste0('fn above(value, threshold) { return value > threshold }\n', prefix,
                        'minimum = 100\nfilter sales where above(revenue, @minimum) skipping missing into selected'))
    stopifnot(identical(result$env$selected$region, "North"))
  })
})
check("calls enforce arity, declaration order and callable names", {
  fails('fn add(a, b) { return a + b }\nprint add(1)', "expects 2 arguments")
  fails('fn add(a, b) { return a + b }\nprint add(1, 2, 3)', "expects 2 arguments")
  fails('print later(1)\nfn later(x) { return x }', "Unknown variable")
  fails('x = 1\nprint x()', "not a declared function")
  fails('print system("touch unwanted")', "Unknown variable")
})
check("functions cannot capture outer variables or recurse", {
  fails('rate = 0.1\nfn tax(x) { return x * rate }', "Unknown variable 'rate'")
  fails('fn loop(x) { return loop(x) }', "Unknown variable 'loop'")
  fails('fn first(x) { return second(x) }\nfn second(x) { return x }', "Unknown variable 'second'")
})
check("function names are immutable and parameter names unique", {
  fails('fn f(x, x) { return x }', "Parameter names must be unique")
  fails('fn f(x) { return x }\nf = 1', "Cannot reassign")
  fails('fn f(x) { return x }\nfn f(y) { return y }', "already declared")
  fails('x = 1\nfn x() { return 1 }', "already declared")
  fails('fn sum(x) { return x }', "cannot replace a built-in")
})
check("functions are not first-class values", {
  fails('fn f(x) { return x }\ncopy = f', "Functions must be called")
  fails('fn f(x) { return x }\nprint @f', "Functions must be called")
})
check("function bodies reject statements and unsupported parameter syntax", {
  fails('fn f(x) { x = 2 }', "one 'return' expression")
  fails('fn f(x) { return x\nprint x }', "multi-statement functions")
  fails('fn f(x = 1) { return x }', "Expected ')' after function parameters")
  fails('fn f(x) { return x }\nprint f(x = 1)', "Expected ')' after function arguments")
})
check("runtime function errors preserve body location and call chain", {
  error <- tryCatch(run('fn add_one(x) { return x + 1 }\nfn wrap(x) { return add_one(x) }\nprint wrap("oops")'), rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"), error$line == 1L, error$column == 26L,
            grepl("called at test.input:2:", conditionMessage(error), fixed = TRUE),
            grepl("called at test.input:3:", conditionMessage(error), fixed = TRUE))
})
check("unknown function values obey arithmetic vector and mutation checks", {
  filter_error('fn add(a, b) { return a + b }\nprint add([1, 2], [1, 2, 3])', "Vector lengths must match")
  filter_error('fn box(x) { return [x] }\nprint box([1, 2])', "each contain one value")
  filter_error('fn same(x) { return x }\nmut value = same(1)\nvalue = same("text")', "from Number to Text")
})
check("unused function arguments are still evaluated", {
  filter_error('fn ignore(x) { return 1 }\nprint ignore(average([0 / 0]))', "contains missing")
})
check("function parameters shadow names without leaking into callers", {
  result <- run('x = 10\nfn plus(x) { return x + 1 }\ny = plus(2)\nprint x')
  stopifnot(result$env$x == 10, result$env$y == 3)
  fails('fn f(local_value) { return local_value }\nprint local_value', "Unknown variable")
})
check("user functions cannot shadow runtime dependencies", {
  with_sales(function(prefix) {
    result <- run(paste0('fn mean(x) { return 999 }\nfn c(x) { return 888 }\n', prefix,
                        'value = average(sales.revenue) skipping missing\nvector = [1, 2]\ncustom = mean(1)'))
    stopifnot(result$env$value == 102.5, identical(result$env$vector, c(1, 2)), result$env$custom == 999)
  })
})
check("function declarations are checked without executing their bodies", {
  output <- capture.output(generated <- transpile('fn bad() { return average([0 / 0]) }'))
  stopifnot(length(output) == 0L, is.character(generated))
  result <- run('fn bad() { return average([0 / 0]) }\nx = 1')
  stopifnot(result$env$x == 1)
})
