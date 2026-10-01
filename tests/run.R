# Run from the repository root: Rscript tests/run.R
source("R/transpile.R")
checks <- 0L
check <- function(label, code) {
  force(code)
  checks <<- checks + 1L
  cat("PASS", label, "\n")
}
run <- function(source) {
  generated <- transpile(source, "test.input")
  env <- new.env(parent = baseenv())
  output <- capture.output(eval(parse(text = generated), envir = env))
  list(env = env, output = output, generated = generated)
}
fails <- function(source, message, line = NULL, column = NULL) {
  error <- tryCatch(transpile(source, "test.input"), rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"),
            grepl(message, conditionMessage(error), fixed = TRUE),
            identical(error$filename, "test.input"))
  if (!is.null(line)) stopifnot(error$line == line)
  if (!is.null(column)) stopifnot(error$column == column)
}

check("vector analysis and explicit execution", {
  result <- run("scores = [72, 85, 91, 68]\nadjusted = scores + 5\nprint adjusted")
  stopifnot(identical(result$env$adjusted, c(77, 90, 96, 73)),
            length(result$output) == 1L, grepl("77", result$output, fixed = TRUE))
})
check("mutable update reads the previous value", {
  result <- run("mut count = 1\ncount = count + 2\ncount = count * 3")
  stopifnot(identical(result$env$count, 9))
})
check("precedence, unary signs, grouping, and left associativity", {
  result <- run("a = 2 + 3 * 4\nb = (2 + 3) * 4\nc = 20 / 2 / 2\nd = 10 - 3 - 2\ne = -2 * +3\nf = -(2 + 3)")
  stopifnot(result$env$a == 14, result$env$b == 20, result$env$c == 5,
            result$env$d == 5, result$env$e == -6, result$env$f == -5)
})
check("numeric notation", {
  stopifnot(run("x = 1.25e+2 + 2E-1")$env$x == 125.2)
})
check("same-length vectors and scalar broadcasting", {
  result <- run("a = [1, 2] + [3, 4]\nb = 10 - [1, 2]")
  stopifnot(identical(result$env$a, c(4, 6)), identical(result$env$b, c(9, 8)))
})
check("mutable size changes retain element type", {
  stopifnot(identical(run("mut x = 1\nx = [2, 3]")$env$x, c(2, 3)))
})
check("booleans and text", {
  result <- run('flags = [true, false]\ntext = "hello # world"')
  stopifnot(identical(result$env$flags, c(TRUE, FALSE)), result$env$text == "hello # world")
})
check("text escapes round-trip without execution", {
  source <- 'text = "quote: \\"; slash: \\\\; newline: \\n; tab: \\t; return: \\r"'
  stopifnot(identical(run(source)$env$text, 'quote: "; slash: \\; newline: \n; tab: \t; return: \r'))
})
check("unicode text", stopifnot(run('x = "ආයුබෝවන්"')$env$x == "ආයුබෝවන්"))
check("comments, blank lines, multiline delimiters and CRLF", {
  result <- run("# start\r\n\r\nx = [\r\n1, # entry\r\n2\r\n]\r\ny = (x +\r\n3) # end")
  stopifnot(identical(result$env$y, c(4, 5)))
})
check("empty and comment-only programs", {
  stopifnot(identical(transpile(""), ""), identical(transpile("# comment\n"), ""))
})
check("R keywords and builtin names are safe bindings", {
  result <- run("if = 2\nc = 3\nTRUE = 4\n_thing = [if, c, TRUE]\nprint _thing")
  stopifnot(identical(result$env$`_thing`, c(2, 3, 4)))
})
check("compiler does not evaluate input or leak bindings", {
  output <- capture.output(generated <- transpile('print "do not execute"\nunique_binding = 1'))
  stopifnot(length(output) == 0L, is.character(generated))
  fails("print unique_binding", "Unknown variable")
  fails('system("touch unwanted")', "Expected '='")
})
check("strings cannot inject R code", {
  result <- run('text = "\\\"); stop(\\\"injected\\\"); #"')
  stopifnot(identical(result$env$text, '"); stop("injected"); #'))
})
check("immutable reassignment location", fails("x = 1\nx = 2", "Cannot reassign 'x'", 2, 1))
check("duplicate mutable declaration", fails("mut x = 1\nmut x = 2", "already declared", 2, 5))
check("immutable cannot become mutable", fails("x = 1\nmut x = 2", "already declared"))
check("unknown names", fails("print absent", "Unknown variable 'absent'", 1, 7))
check("self-reference before declaration", fails("x = x + 1", "Unknown variable 'x'", 1, 5))
check("stable mutable types", fails('mut x = 1\nx = "two"', "from Number to Text"))
check("mixed vector types", fails('x = [1, "two"]', "same type"))
check("no implicit text arithmetic", fails('x = "1" + 2', "Arithmetic requires numbers", 1, 9))
check("no implicit boolean arithmetic", fails("x = -true", "Arithmetic requires numbers"))
check("reject silent vector recycling", fails("x = [1, 2] + [1, 2, 3, 4]", "Vector lengths must match"))
check("reject empty vectors", fails("x = []", "Empty vectors"))
check("reject multi-value vector elements", fails("x = [[1, 2], 3]", "each contain one value"))
check("missing closing vector", fails("x = [1, 2", "Expected ']'"))
check("missing closing group", fails("x = (1 + 2", "Expected ')'"))
check("trailing comma", fails("x = [1,]", "Expected a value"))
check("missing right operand", fails("x = 1 +\ny = 2", "Expected a value", 1, 8))
check("unclosed text", fails('x = "hello', "Unclosed text", 1, 5))
check("invalid escape", fails('x = "\\q"', "Unsupported text escape", 1, 6))
check("unexpected character", fails("x = 1 $ 2", "Unexpected character", 1, 7))
check("statement separation", fails("x = 1 y = 2", "Expected a new line", 1, 7))
check("literal range", fails("x = 1e999", "finite range"))
check("public API argument validation", {
  for (bad in list(NA_character_, c("x", "y"), 1, NULL)) {
    stopifnot(inherits(tryCatch(transpile(bad), error = identity), "error"))
    stopifnot(inherits(tryCatch(transpile("", bad), error = identity), "error"))
  }
})
check("AST retains complete multiline source spans", {
  ast <- rss_parse(rss_tokenize("x = [\n1, 2\n]", "spans"), "spans")
  stopifnot(ast[[1]]$span$line == 1L, ast[[1]]$span$column == 1L,
            ast[[1]]$span$end_line == 3L, ast[[1]]$span$end_column == 2L,
            ast[[1]]$value$span$column == 5L)
})
source("tests/csv.R")
source("tests/filter.R")
cat(sprintf("\n%d checks passed.\n", checks))
