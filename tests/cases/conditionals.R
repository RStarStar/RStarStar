check("conditionals choose values with conventional expression precedence", {
  result <- run('a = if 2 + 3 > 4 then 10 + 2 else 30\nb = 2 * (if false then 8 else 3)\nc = if true then if false then 1 else 2 else 3')
  stopifnot(result$env$a == 12, result$env$b == 6, result$env$c == 2)
})
check("conditional branches are lazy but both are checked statically", {
  result <- run('a = if true then 1 else average([0 / 0])\nb = if false then average([0 / 0]) else 2')
  stopifnot(result$env$a == 1, result$env$b == 2)
  fails('x = if true then 1 else unknown', "Unknown variable")
  fails('x = if true then 1 else "text" + 2', "Arithmetic requires numbers")
})
check("conditional syntax requires then else and complete branches", {
  fails('x = if true 1 else 2', "Expected 'then'")
  fails('x = if true then 1', "Expected 'else'")
  fails('x = if true then else 2', "Expected a value")
  fails('x = if true then 1 else', "Expected a value")
})
check("known conditional predicates reject numbers text and vectors", {
  fails('x = if 1 then 2 else 3', "must be boolean", 1, 8)
  fails('x = if "yes" then 2 else 3', "must be boolean")
  fails('x = if [true, false] then 2 else 3', "exactly one boolean")
})
check("dynamic conditional predicates reject missing empty and nonboolean inputs", {
  prefix <- 'fn choose(flag) { return if flag then 1 else 2 }\n'
  for (arg in c('1', '"true"', '[true, false]', '(0 / 0) > 0')) {
    filter_error(paste0(prefix, 'x = choose(', arg, ')'), "exactly one nonmissing boolean", 1L)
  }
  with_sales(function(source) {
    filter_error(paste0(prefix, source, 'filter sales where revenue > 1000 skipping missing into empty\nx = choose(empty.active)'), "exactly one nonmissing boolean", 1L)
  })
})
check("conditional functions safely avoid an empty average", {
  with_sales(function(source) {
    result <- run(paste0('fn safe_average(values) {\nreturn (if count(values) == 0\nthen 0\nelse average(values))\n}\n', source,
                        'filter sales where revenue > 1000 skipping missing into empty\na = safe_average(empty.revenue)\nb = safe_average([2, 4])'))
    stopifnot(result$env$a == 0, result$env$b == 3)
  })
})
check("branches may select different types but surrounding operations remain checked", {
  result <- run('x = if true then "ok" else 2\ny = if false then [1, 2] else [3, 4, 5]')
  stopifnot(result$env$x == "ok", identical(result$env$y, c(3, 4, 5)))
  filter_error('x = (if true then "ok" else 2) + 1', "Arithmetic requires numbers")
  filter_error('x = (if false then [1, 2] else [3, 4, 5]) + [1, 2]', "Vector lengths must match")
  filter_error('mut x = if true then 1 else "text"\nx = "text"', "from Number to Text")
})
check("conditional table results and filter scope preserve existing rules", {
  with_sales(function(source) {
    result <- run(paste0(source, 'threshold = 100\nfilter sales where if @threshold > 0 then revenue > @threshold else active skipping missing into selected\nchosen = if false then selected else sales'))
    stopifnot(identical(result$env$selected$region, "North"), identical(result$env$chosen, result$env$sales))
    filter_error(paste0(source, 'filter sales where if active then true else false into selected'), "exactly one nonmissing boolean")
  })
})
check("public execution returns callable conditional functions with source errors", {
  with_source_file('fn choose(flag) { return if flag then 10 else 20 }', function(path) {
    result <- RStarStar::run_file(path)
    stopifnot(result$choose(TRUE) == 10, result$choose(FALSE) == 20)
    error <- tryCatch(result$choose(NA), error = identity)
    stopifnot(inherits(error, "rstarstar_error"), error$line == 1L,
              error$filename == normalizePath(path, winslash = "/"))
  })
})
