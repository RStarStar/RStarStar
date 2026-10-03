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
check("text length counts characters and preserves source values", {
  result <- run('text = ["", "hello", "é", "é", "😀"]\nlengths = std::text_length(values: text)\nplus = lengths + 1\nfn text_length(x) { return 99 }\nown = text_length("abc")\nstd = 1\nnchar = 2\nas = std::text_length("abc")')
  stopifnot(identical(result$env$lengths, c(0, 5, 1, 2, 1)),
            identical(result$env$plus, c(1, 6, 2, 3, 2)), result$env$own == 99,
            result$env$as == 3, identical(result$env$text, c("", "hello", "é", "é", "😀")))
})
check("text length rejects known wrong types and invalid signatures", {
  fails('x = std::text_length(123)', "require plain text", 1, 5)
  fails('x = std::text_length(true)', "require plain text")
  fails('record Label { value: Text }\nx = std::text_length(Label("hi"))', "require plain text")
  fails('x = std::text_length()', "exactly one argument")
  fails('x = std::text_length("a", "b")', "exactly one argument")
  fails('x = std::text_length(value: "a")', "exact parameter name")
  fails('x = std::text_length("abc") + [1, 2, 3]\ny = x + [1, 2]', "Vector lengths")
  fails('x = std::text_length(["a", "bb"]) + "text"', "Arithmetic requires numbers")
})
check("text length works in CSV filtering with missing and empty columns", {
  with_csv(c('code', 'A', 'ABC', 'NA'), function(path) {
    prefix <- paste('read', path, 'into data\n')
    result <- run(paste0(prefix, 'limit = 2\nfilter data where std::text_length(code) <= @limit skipping missing into short\nlengths = std::text_length(data.code)\nfilter data where false into empty\nempty_lengths = std::text_length(empty.code)'))
    stopifnot(identical(result$env$short$code, "A"),
              identical(result$env$lengths, c(1, 3, NA_real_)),
              identical(result$env$empty_lengths, numeric()))
    filter_error(paste0(prefix, 'filter data where std::text_length(code) > 0 into kept'), "contains missing values")
    filter_error(paste0(prefix, 'x = std::text_length(data)'), "require plain text")
  })
  with_csv(c('code', 'NA'), function(path) {
    stopifnot(identical(run(paste('read', path, 'into data\nx = std::text_length(data.code)'))$env$x, NA_real_))
  })
})
check("text length validates dynamic inputs and retains function call chains", {
  source <- 'fn size(x) { return std::text_length(x) }\ny = size(123)'
  stopifnot(is.character(transpile(source)))
  filter_error(source, "requires plain text", 1, 21)
  error <- tryCatch(run(source), rstarstar_error = identity)
  stopifnot(grepl("called at test.input:2:5", conditionMessage(error), fixed = TRUE))
  stopifnot(run('fn size(x) { return if true then 0 else std::text_length(x) }\ny = size(123)')$env$y == 0)
})
check("text length handles the R boundary including encoding errors", {
  with_source_file('fn size(x) { return std::text_length(x) }', function(path) {
    size <- RStarStar::run_file(path)$size
    stopifnot(identical(size(c("", NA_character_, "abc")), c(0, NA_real_, 3)),
              identical(size(character()), numeric()))
    for (bad in list(1, TRUE, factor("abc"), matrix("abc"), c(name = "abc"), list("abc"), new.env())) {
      stopifnot(inherits(tryCatch(size(bad), error = identity), "rstarstar_error"))
    }
    invalid <- rawToChar(as.raw(c(0xc3, 0x28)))
    Encoding(invalid) <- "UTF-8"
    bytes <- rawToChar(as.raw(c(0xc3, 0xa9)))
    Encoding(bytes) <- "bytes"
    for (bad in c(invalid, bytes)) {
      error <- tryCatch(size(bad), error = identity)
      stopifnot(inherits(error, "rstarstar_error"),
                grepl("valid character text", conditionMessage(error), fixed = TRUE),
                identical(error$filename, normalizePath(path, winslash = "/")))
    }
    forced <- 0L
    stopifnot(size({ forced <- forced + 1L; "abc" }) == 3, forced == 1L)
  })
})
check("text length generates standalone code and private results", {
  with_source_file('x = std::text_length(["a", "abc"])', function(path) {
    code <- RStarStar::transpile(path)
    stopifnot(!grepl('square_root', code, fixed = TRUE), !grepl('absolute =', code, fixed = TRUE))
    env <- new.env(parent = baseenv())
    eval(parse(text = code), env)
    stopifnot(identical(env$x, c(1, 3)), identical(RStarStar::run_file(path), list(x = c(1, 3))))
  })
})
check("trim text removes only boundary ASCII whitespace", {
  result <- run('values = ["  A B  ", "\\tABC\\r\\n", "   ", "", "é", " A "]\nclean = std::trim_text(values: values)\nlengths = std::text_length(clean)\nmut label = "before"\nlabel = std::trim_text(" after ")\nfn trim_text(x) { return "user" }\nown = trim_text(" A ")')
  stopifnot(identical(result$env$clean, c("A B", "ABC", "", "", "é", "\u00a0A\u00a0")),
            identical(result$env$lengths, c(3, 3, 0, 0, 1, 3)), result$env$label == "after",
            result$env$own == "user", result$env$values[[1L]] == "  A B  ")
})
check("trim text infers Text output and enforces signatures", {
  fails('x = std::trim_text(1)', "require plain text")
  fails('x = std::trim_text(true)', "require plain text")
  fails('x = std::trim_text()', "exactly one argument")
  fails('x = std::trim_text("a", "b")', "exactly one argument")
  fails('x = std::trim_text(value: "a")', "exact parameter name")
  fails('x = std::trim_text(" 1 ") + 1', "Arithmetic requires numbers")
  fails('mut x = 1\nx = std::trim_text("1")', "Cannot change")
  result <- run('record Code { value: Text }\nx = Code(std::trim_text(" A "))\ny = std::trim_text([" a ", " b "]) == ["a", "b"]')
  stopifnot(result$env$x$value == "A", identical(result$env$y, c(TRUE, TRUE)))
})
check("trim text cleans CSV filter values and preserves missing rows", {
  with_csv(c('code', ' A ', 'B', 'NA', '   '), function(path) {
    prefix <- paste('read', path, 'into data\n')
    result <- run(paste0(prefix, 'wanted = "A"\nfilter data where std::trim_text(code) == @wanted skipping missing into selected\nclean = std::trim_text(data.code)\nfilter data where false into empty\nnone = std::trim_text(empty.code)'))
    stopifnot(identical(result$env$selected$code, " A "),
              identical(result$env$clean, c("A", "B", NA_character_, "")),
              identical(result$env$none, character()), result$env$data$code[[1L]] == " A ")
    filter_error(paste0(prefix, 'filter data where std::trim_text(code) == "A" into selected'), "contains missing values")
  })
})
check("trim text checks R inputs and retains source locations", {
  with_source_file('fn clean(x) { return std::trim_text(x) }', function(path) {
    clean <- RStarStar::run_file(path)$clean
    stopifnot(identical(clean(c(" A ", NA_character_, "\t\n")), c("A", NA_character_, "")),
              identical(clean(character()), character()))
    invalid <- rawToChar(as.raw(c(0xc3, 0x28)))
    Encoding(invalid) <- "UTF-8"
    bytes <- rawToChar(as.raw(c(0xc3, 0xa9)))
    Encoding(bytes) <- "bytes"
    for (bad in list(1, TRUE, factor(" A "), matrix(" A "), c(name = " A "), list(" A "), new.env(), invalid, bytes)) {
      error <- tryCatch(clean(bad), error = identity)
      stopifnot(inherits(error, "rstarstar_error"), error$line == 1L, error$column == 22L)
    }
    forced <- 0L
    stopifnot(clean({ forced <- forced + 1L; " A " }) == "A", forced == 1L)
  })
  source <- 'fn clean(x) { return std::trim_text(x) }\ny = clean(1)'
  stopifnot(is.character(transpile(source)))
  error <- tryCatch(run(source), rstarstar_error = identity)
  stopifnot(grepl("called at test.input:2:5", conditionMessage(error), fixed = TRUE))
})
check("trim text embeds standalone implementations and returns only user bindings", {
  with_source_file('x = std::trim_text(" A ")', function(path) {
    code <- RStarStar::transpile(path)
    stopifnot(!grepl('text_length =', code, fixed = TRUE), !grepl('absolute =', code, fixed = TRUE))
    env <- new.env(parent = baseenv())
    eval(parse(text = code), env)
    stopifnot(identical(env$x, "A"), identical(RStarStar::run_file(path), list(x = "A")))
  })
})
