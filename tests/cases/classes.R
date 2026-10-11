local({
  counter <- 'class Counter {
mut value: Number
fn current(self) { return self.value }
fn increment(mut self, amount) { self.value = self.value + amount }
}'
  pair <- 'class Pair {
mut left: Number
mut right: Number
fn change(mut self, replacement) {
self.left = self.left + 1
self.right = replacement
}
fn total(self) { return self.left + self.right }
}'
  check("class mutation replaces one binding and preserves aliases", {
    result <- run(paste(counter, 'first = Counter(value: 0)', 'mut second = first',
      'second.increment(amount: 2)', 'second.increment(second.current())',
      'a = first.current()', 'b = second.current()', sep = "\n"))
    stopifnot(result$env$a == 0, result$env$b == 4, result$env$first$value == 0)
    path <- system.file("examples", "classes.rsspps", package = "RStarStar", mustWork = TRUE)
    invisible(capture.output(result <- RStarStar::run_file(path)))
    stopifnot(result$original == 0, result$updated == 5,
      setequal(names(result), c("Counter", "first", "second", "original", "updated")))
  })
  check("classes preserve immutable fields and permit zero-argument mutation", {
    result <- run('class Named { label: Text\nmut value: Number\nfn increment(mut self) { self.value = self.value + 1 }\nfn name(self) { return self."label" } }\nmut n = Named("counter", 1)\nn.increment()\nx = n.name()')
    stopifnot(result$env$n$value == 2, result$env$x == "counter")
  })
  check("class assignments see earlier candidate fields and readonly methods", {
    source <- 'fn twice(x) { return x * 2 }
class Pair {
mut left: Number
mut right: Number
fn current(self) { return self.left }
fn advance(mut self, enabled) {
self.left = if enabled then twice(self.left) else self.left
self.right = self.current() + 1
}
}
mut pair = Pair(2, 0)
pair.advance(true)'
    result <- run(source)
    stopifnot(result$env$pair$left == 4, result$env$pair$right == 5)
  })
  check("failed mutation preserves the committed receiver and assignment location", {
    env <- new.env(parent = baseenv())
    code <- transpile(paste(pair, 'mut pair = Pair(1, 2)', 'alias = pair',
      'pair.change("bad")', sep = "\n"), "atomic.input")
    error <- tryCatch(eval(parse(text = code), env), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"), error$line == 6L, error$column == 6L,
      grepl("called at atomic.input:12:", conditionMessage(error), fixed = TRUE),
      identical(env$pair, env$alias), env$pair$left == 1, env$pair$right == 2)
    code <- transpile(paste(pair, 'mut pair = Pair(1, 2)', 'pair.change([3, 4])', sep = "\n"))
    error <- tryCatch(eval(parse(text = code), env), rstarstar_error = identity)
    stopifnot(inherits(error, "rstarstar_error"), env$pair$left == 1, env$pair$right == 2)
  })
  check("classes require mutable binding field and receiver permissions", {
    fails(paste(counter, 'fixed = Counter(0)', 'fixed.increment(1)', sep = "\n"), "mutable receiver binding")
    fails('class C { value: Number\nfn set(mut self) { self.value = 1 } }', "is immutable")
    fails('class C { mut value: Number\nfn set(self) { self.value = 1 } }', "one 'return'")
    fails(paste(counter, 'mut c = Counter(0)', 'x = c.increment(1)', sep = "\n"), "cannot be used in expressions")
    fails(paste(counter, 'mut c = Counter(0)', 'c.current()', sep = "\n"), "require a mutating method")
    fails(paste(counter, 'fn f(c) { return c.increment(1) }', sep = "\n"), "cannot be used in expressions")
    fails(paste(counter, 'fn f(mut c) { return c }', sep = "\n"), "parameter name")
    fails(paste(counter, 'mut c = Counter(0)', 'c.current().increment(1)', sep = "\n"), "simple named")
    fails(paste(counter, 'Counter(0).increment(1)', sep = "\n"), "Expected '='")
    fails(paste(counter, 'mut c = Counter(0)', 'c.value = 1', sep = "\n"), "external field assignment")
  })
  check("classes enforce private fields through known and unknown receivers", {
    for (expr in c('c.value', 'Counter(0).value', '(c).value', '@c.value', 'c."value"')) {
      fails(paste(counter, 'c = Counter(0)', paste('x =', expr), sep = "\n"), "fields are private")
    }
    filter_error('class C { value: Number\nfn inspect(self, other) { return other.value } }\nc = C(0)\nx = c.inspect(c)',
      "fields are private")
    filter_error(paste(counter, 'fn field(x) { return x.value }', 'x = field(Counter(0))', sep = "\n"), "fields are private")
    fails('class C { value: Number\nfn inspect(self) { return (self).value } }', "fields are private")
    fails('class C { value: Number\nfn inspect(self) { return self.absent } }', "Unknown class field")
  })

  check("class constructors enforce scalar primitive fields and exact arguments", {
    fails('class C {}', "at least one field")
    fails('class C { x: Number\nx: Text }', "must be unique")
    fails('class C { x: Number\nfn x(self) { return 1 } }', "must be unique")
    fails('class C { x: Number\nfn f(self) { return 1 }\ny: Text }', "fields must be declared before")
    for (field in c("C", "Integer", "Table")) {
      fails(paste0('class C { x: ', field, ' }'), "Class fields require")
    }
    fails('class Inner { x: Number }\nclass C { x: Inner }', "Class fields require")
    fails('class C { x: Number }\nrecord R { x: C }', "Unknown field type")
    fails('class C { x: Number = 1 + 2 }', "scalar literals")
    fails(paste(counter, 'c = Counter()', sep="\n"), "Missing required field 'value'")
    fails(paste(counter, 'c = Counter(v: 0)', sep="\n"), "Unknown parameter")
    fails(paste(counter, 'c = Counter("bad")', sep="\n"), "requires one Number")
    fails(paste(counter, 'c = Counter([1, 2])', sep="\n"), "requires one Number")
    result <- run('class C { text: Text\nflag: Boolean\nnumber: Number }\nc = C(number: 0 / 0, flag: true, text: "hi")')
    stopifnot(result$env$c$text == "hi", isTRUE(result$env$c$flag), is.nan(result$env$c$number))
  })
  check("class bodies reject unsupported statements captures and forward calls", {
    for (body in c("", "return 1", "print 1", "local = 1", "self = 1", "self.x = 1\nreturn 2")) {
      error <- tryCatch(transpile(paste0('class C { mut x: Number\nfn f(mut self) { ', body, ' } }')), rstarstar_error=identity)
      stopifnot(inherits(error, "rstarstar_error"))
    }
    fails('class C { x: Number\nfn f(mut other) { self.x = 1 } }', "first parameter")
    fails('class C { x: Number\nfn f(self, mut x) { return x } }', "parameter name")
    fails('class C { mut x: Number\nfn f(mut self) { self.x = "bad" } }', "requires one Number")
    fails('class C { mut x: Number\nfn f(mut self) { self.absent = 1 } }', "Unknown class field")
    fails('outer = 1\nclass C { mut x: Number\nfn f(mut self) { self.x = outer } }', "Unknown variable")
    fails('class C { mut x: Number\nfn f(mut self) { self.x = self.f() } }', "No visible method")
    fails('class C { mut x: Number\nfn f(mut self) { self.x = self.g() }\nfn g(self) { return 1 } }', "No visible method")
    fails('class C { x: Number\nfn f(self) { return C(1) } }', "Unknown variable")
    fails(paste(counter, 'class Other { mut x: Number\nfn f(mut self, c) { self.x = c.increment(1) } }', sep="\n"),
      "cannot be used in expressions")
  })
  check("class mutation matches exact signatures and stable nominal types", {
    fails(paste(counter, 'mut c = Counter(0)\nc.increment()', sep="\n"), "expects 1 arguments")
    fails(paste(counter, 'mut c = Counter(0)\nc.increment(amt: 1)', sep="\n"), "Unknown method parameter")
    fails(paste(counter, 'mut c = Counter(0)\nc.increment(self: 1)', sep="\n"), "supplies self")
    fails(paste(counter, 'class Other { value: Number }\nmut c = Counter(0)\nc = Other(1)', sep="\n"), "Cannot change")
    filter_error(paste(counter, 'class Other { value: Number }\nfn identity(x) { return x }\nmut c = identity(Counter(0))\nc = identity(Other(1))', sep="\n"), "Cannot change binding")
  })
  check("dynamic dispatch enforces class method effects and visibility", {
    prefix <- paste(counter, 'record Readonly { x: Number\nfn increment(self, amount) { return self.x + amount } }',
      'fn identity(x) { return x }', 'fn expression(x) { return x.increment(1) }', sep="\n")
    result <- run(paste(prefix, 'mut c = identity(Counter(0))\nc.increment(2)\nx = c.current()\ny = expression(Readonly(3))', sep="\n"))
    stopifnot(result$env$x == 2, result$env$y == 4)
    filter_error(paste(prefix, 'x = expression(Counter(0))', sep="\n"), "cannot be used in expressions")
    filter_error(paste(prefix, 'mut c = identity(Readonly(0))\nc.increment(1)', sep="\n"), "require a mutating method")
    filter_error(paste(prefix, 'mut c = identity(Counter(0))\nc.increment(amt: 1)', sep="\n"), "Unknown method parameter")
    filter_error(paste(prefix, 'mut c = identity(1)\nc.increment(1)', sep="\n"), "receiver")
    prefix <- paste(counter, 'fn earlier(x) { return x.current() }',
      'class Late { value: Number\nfn current(self) { return self.value } }', sep="\n")
    filter_error(paste(prefix, 'x = earlier(Late(1))', sep="\n"), "No visible method")
    stopifnot(run(paste(prefix, 'x = earlier(Counter(3))', sep="\n"))$env$x == 3)
  })
  check("generic operations cannot reveal class fields or imply equality", {
    for (expression in c("c == c", "c != c", "c < c")) {
      fails(paste(counter, 'c = Counter(0)', paste("x =", expression), sep="\n"), "Class comparison")
    }
    fails(paste(counter, 'c = Counter(0)\nx = c with {value: 2}', sep="\n"), "requires a record")
    fails(paste(counter, 'c = Counter(0)\nx = [c]', sep="\n"), "Classes cannot")
    fails(paste(counter, 'c = Counter(0)\nx = c is missing', sep="\n"), "through methods")
    fails(paste(counter, 'c = Counter(0)\nx = count(c)', sep="\n"), "through methods")
    for (expr in c("a == a", "a with {value: 2}", "[a]", "a is missing", "count(a)")) {
      error <- tryCatch(run(paste(counter, paste0('fn test(a) { return ', expr, ' }'),
        'x = test(Counter(0))', sep="\n")), rstarstar_error=identity)
      stopifnot(inherits(error, "rstarstar_error"))
    }
  })
  check("class runtime rejects foreign layouts and attributed or reference fields", {
    result <- run(paste(counter, 'fn current(x) { return x.current() }', sep="\n"))$env
    for (bad in list(new.env(), list(value=1), structure(list(value=1), rss_class_type="Unknown"),
        structure(list(value=1, extra=2), rss_class_type="Counter"),
        structure(list(wrong=1), rss_class_type="Counter"),
        structure(list(value="bad"), rss_class_type="Counter"),
        structure(list(value=new.env()), rss_class_type="Counter"),
        structure(list(value=1), rss_class_type="Counter", extra=TRUE))) {
      stopifnot(inherits(tryCatch(result$current(bad), error=identity), "rstarstar_error"))
    }
    for (bad in list(new.env(), list(1), structure(1, names="a"), as.Date("2026-10-07"), c(1, 2))) {
      stopifnot(inherits(tryCatch(result$Counter(bad), error=identity), "rstarstar_error"))
    }
    stopifnot(result$current(result$Counter(3)) == 3)
  })
  check("mutation arguments evaluate once in written order against the old receiver", {
    source <- 'class C {
mut x: Number
mut y: Number
fn change(mut self, a, b) {
self.x = a
self.y = b
}
}
fn identity(x) { return x }
mut c = identity(C(1, 2))
first = 0
second = 0
c.change(b: second, a: first)'
    code <- parse(text=transpile(source))
    env <- new.env(parent=baseenv())
    for (i in seq_len(length(code) - 1L)) eval(code[[i]], env)
    seen <- character()
    receiver <- env$c
    rm(list=c("c", "first", "second"), envir=env)
    makeActiveBinding("c", function(value) {
      if (missing(value)) { seen <<- c(seen, "receiver"); receiver } else {
        seen <<- c(seen, "commit"); receiver <<- value
      }
    }, env)
    makeActiveBinding("first", function() { seen <<- c(seen, "first"); receiver$y + 10 }, env)
    makeActiveBinding("second", function() { seen <<- c(seen, "second"); receiver$x + 20 }, env)
    eval(code[[length(code)]], env)
    stopifnot(identical(seen, c("receiver", "second", "first", "commit")),
      receiver$x == 12, receiver$y == 21)
    seen <- character()
    receiver <- 1
    rm(list=c("first", "second"), envir=env)
    makeActiveBinding("first", function() { seen <<- c(seen, "first"); 10 }, env)
    makeActiveBinding("second", function() { seen <<- c(seen, "second"); 20 }, env)
    error <- tryCatch(eval(code[[length(code)]], env), error=identity)
    stopifnot(inherits(error, "rstarstar_error"),
      identical(seen, c("receiver", "second", "first")))
  })
  check("class syntax retains spans and stages reset after class errors", {
    source <- paste(counter, 'mut c = Counter(0)', 'c.increment(1)', sep="\n")
    ast <- rss_parse(rss_tokenize(source, "spans"), "spans")
    stopifnot(ast[[1]]$span$end_line == 5L,
      ast[[1]]$methods$increment$body[[1]]$span$line == 4L,
      ast[[3]]$span$line == 7L, ast[[3]]$span$end_column == 15L)
    analyzer <- get("RSSAnalyzer", asNamespace("RStarStar"))$new()
    broken <- rss_parse(rss_tokenize('class C { x: Number\nfn inspect(self) { return self.absent } }', "broken"), "broken")
    stopifnot(inherits(tryCatch(analyzer$analyze(broken, "broken"), error=identity), "rstarstar_error"))
    analyzer$analyze(ast, "spans")
    generator <- get("RSSGenerator", asNamespace("RStarStar"))$new()
    code <- generator$generate(ast, "spans")
    stopifnot(identical(code, transpile(source, "spans")))
    plain <- rss_parse(rss_tokenize("x = 1", "plain"), "plain")
    stopifnot(identical(generator$generate(plain, "plain"), "`x` <- 1"),
      identical(generator$generate(ast, "spans"), code))
  })
  check("class transpilation is lazy and generated execution remains R6 independent", {
    source <- paste(counter, 'class Unused { mut x: Number\nfn fail(mut self) { self.x = std::square_root(-1) } }',
      'first = Counter(0)\nmut second = first\nsecond.increment(2)\nanswer = second.current()', sep="\n")
    stopifnot(length(capture.output(code <- transpile(source))) == 0L)
    script <- tempfile(fileext=".R")
    on.exit(unlink(script), add=TRUE)
    writeLines(c('stopifnot(!"R6" %in% loadedNamespaces(), !"RStarStar" %in% loadedNamespaces())',
      code, 'stopifnot(answer == 2, first$value == 0)',
      'stopifnot(!"R6" %in% loadedNamespaces(), !"RStarStar" %in% loadedNamespaces())'), script)
    executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
    output <- system2(executable, c("--vanilla", "--default-packages=NULL", shQuote(script)), stdout=TRUE, stderr=TRUE)
    stopifnot(is.null(attr(output, "status")))
  })
})
