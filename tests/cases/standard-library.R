check("standard numeric calls preserve values and namespace independence", {
  result <- run('std = 7\nabs = 8\nsqrt = 9\nfn absolute(x) { return x + 1 }\na = std::absolute([-3, 0, 2])\nb = std::square_root(values: [0, 4, 9])\nc = absolute(3)\nd = std::square_root(std::absolute(-16))')
  stopifnot(identical(result$env$a, c(3, 0, 2)), identical(result$env$b, c(0, 2, 3)), result$env$c == 4, result$env$d == 4)
})
check("standard calls reject unknown namespaces names and signatures", {
  fails('x = stats::median(3)', "Only the bundled", 1, 5)
  fails('x = std::unknown(3)', "Unknown bundled operation", 1, 5)
  fails('x = std::absolute()', "exactly one argument")
  fails('x = std::absolute(1, 2)', "exactly one argument")
  fails('x = std::absolute(value: 1)', "exact parameter name", 1, 19)
  fails('x = std::absolute', "must be called")
  fails('x = std::absolute(1) skipping missing', "Expected a new line")
})
check("standard calls reject known nonnumeric inputs", {
  fails('x = std::absolute("3")', "require plain numbers")
  fails('x = std::square_root(true)', "require plain numbers")
  fails('record Point { x: Number }\nx = std::absolute(Point(3))', "require plain numbers")
})
check("standard domain checks happen at execution with call chains", {
  source <- 'fn root(x) { return std::square_root(x) }\ny = root([4, -1])'
  stopifnot(is.character(transpile(source)))
  filter_error(source, "nonmissing value is negative", 1, 21)
  error <- tryCatch(run(source), rstarstar_error = identity)
  stopifnot(grepl("called at test.input:2:5", conditionMessage(error), fixed = TRUE))
  filter_error('x = std::square_root(-1 / 0)', "nonnegative values")
  stopifnot(run('x = if true then 1 else std::square_root(-1)')$env$x == 1)
})
check("standard numeric operations retain missing infinite and empty inputs", {
  with_source_file('fn magnitude(x) { return std::absolute(x) }\nfn root(x) { return std::square_root(x) }', function(path) {
    result <- RStarStar::run_file(path)
    stopifnot(identical(result$magnitude(c(NA_real_, NaN, -Inf, Inf)), c(NA_real_, NaN, Inf, Inf)),
              identical(result$root(c(NA_real_, NaN, Inf)), c(NA_real_, NaN, Inf)),
              identical(result$root(numeric()), numeric()), identical(result$magnitude(-2L), 2L))
    for (bad in list(TRUE, "3", matrix(3), structure(3, class = "foreign"), c(named = 3), list(3), new.env(), 1+1i)) {
      for (operation in result) stopifnot(inherits(tryCatch(operation(bad), error = identity), "rstarstar_error"))
    }
    forced <- 0L
    result$magnitude({ forced <- forced + 1L; -2 })
    stopifnot(forced == 1L)
  })
})
check("standard operations use filter scope and retain typed empty columns", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, '\nlimit = 100\nfilter sales where std::absolute(revenue) > @limit skipping missing into selected\nfilter sales where false into empty\nx = std::absolute(empty.revenue)'))
    stopifnot(nrow(result$env$selected) == 1L, identical(result$env$x, numeric()))
    filter_error(paste0(prefix, '\nx = std::absolute(sales)'), "require plain numbers")
  })
  with_csv('x\nNA\n', function(path) {
    filter_error(paste0('read ', path, ' into data\nx = std::absolute(data.x)'), "requires plain numbers")
  })
})
check("standard library emits only required standalone implementations", {
  generated <- transpile('x = std::absolute(-3)')
  stopifnot(!grepl('square_root', generated, fixed = TRUE), !grepl('RStarStar::', generated, fixed = TRUE),
            !grepl('.rss_std', transpile('x = 1'), fixed = TRUE))
  env <- new.env(parent = baseenv())
  eval(parse(text = generated), env)
  stopifnot(env$x == 3)
  with_source_file('x = std::absolute(-3)', function(path) {
    stopifnot(identical(RStarStar::run_file(path), list(x = 3)))
  })
})
check("standard call AST retains multiline span", {
  ast <- rss_parse(rss_tokenize('x = std::absolute(\n-3\n)', 'span'), 'span')[[1]]$value
  stopifnot(ast$kind == 'standard_call', ast$span$column == 5L, ast$span$end_line == 3L, ast$span$end_column == 2L)
})
