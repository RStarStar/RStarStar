point_methods <- 'record Point {\nx: Number\ny: Number\nfn magnitude(self) { return std::square_root(self.x * self.x + self.y * self.y) }\nfn shifted(self, dx, dy) { return self with {x: self.x + dx, y: self.y + dy} }\nfn double_shift(self) { return self.shifted(1, 2).shifted(1, 2) }\n}'
check("methods calculate and return copies with chained receivers", {
  result <- run(paste0(point_methods, '\np = Point(3, 4)\nalias = p\nn = p.shifted(dy: 2, dx: 1)\ndistance = p.magnitude()\nx = Point(1, 2).double_shift().x\nmut current = p\ncurrent = current.shifted(1, 1)\nsame = p == alias'))
  stopifnot(result$env$distance == 5, result$env$n$x == 4, result$env$n$y == 6,
            result$env$p$x == 3, result$env$alias$x == 3, result$env$x == 3,
            result$env$current$x == 4, isTRUE(result$env$same))
})
check("method declarations reject invalid self collisions and mutation", {
  fails('record P { x: Number\nfn a() { return 1 } }', 'first parameter')
  fails('record P { x: Number\nfn a(mut self) { return 1 } }', 'parameter name')
  fails('record P { x: Number\nfn x(self) { return 1 } }', 'must be unique')
  fails('record P { x: Number\nfn a(self) { return 1 }\nfn a(self) { return 2 } }', 'must be unique')
  fails('record P { x: Number\nfn a(self) { return 1 }\ny: Number }', 'fields must be declared before methods')
  fails('record P { x: Number\nfn a(self) { self.x = 1 } }', "one 'return'")
  fails('record P { x: Number\nfn a(self) { return self = 1 } }', "Expected '}'")
})
check("method scope excludes outer data implicit fields and forward recursion", {
  fails('outer = 2\nrecord P { x: Number\nfn a(self) { return outer } }', "Unknown variable 'outer'")
  fails('record P { x: Number\nfn a(self) { return x } }', "Unknown variable 'x'")
  fails('record P { x: Number\nfn a(self) { return self.a() } }', 'No visible method')
  fails('record P { x: Number\nfn a(self) { return self.b() }\nfn b(self) { return 1 } }', 'No visible method')
  fails('record P { x: Number\nfn a(self) { return P(1) } }', "Unknown variable 'P'")
})
check("known method calls require exact signatures and field spelling", {
  fails(paste0(point_methods, '\nx = Point(1, 2).shifted(1)'), 'expects 2 arguments')
  fails(paste0(point_methods, '\nx = Point(1, 2).shifted(d: 1, dy: 2)'), 'Unknown method parameter')
  fails(paste0(point_methods, '\nx = Point(1, 2).shifted(1, dx: 2)'), 'supplied more than once')
  fails(paste0(point_methods, '\nx = Point(1, 2).magnitude(self: Point(1, 2))'), 'supplies self')
  fails(paste0(point_methods, '\nx = Point(1, 2).magnitude'), 'Unknown record field')
  fails(paste0(point_methods, '\nx = Point(1, 2)."magnitude"()'), 'identifiers')
  fails(paste0(point_methods, '\nx = 3.magnitude()'), 'record receiver')
})
check("unknown receivers dispatch by type using definition-time visibility", {
  prefix <- 'record A { x: Number\nfn value(self) { return self.x } }\nfn earlier(p) { return p.value() }\nrecord B { x: Text\nfn value(self, suffix) { return self.x } }\nfn later(p, v) { return p.value(suffix: v) }\n'
  result <- run(paste0(prefix, 'x = earlier(A(3))\ny = later(B("hi"), 1)'))
  stopifnot(result$env$x == 3, result$env$y == 'hi')
  filter_error(paste0(prefix, 'x = earlier(B("hi"))'), 'No visible method')
  filter_error(paste0(prefix, 'x = earlier(3)'), 'record receiver')
  filter_error(paste0(prefix, 'x = later(A(3), 1)'), 'expects 0 arguments')
})
check("methods retain named argument order and evaluate receiver once", {
  source <- paste0(point_methods, '\nfn invoke(p, dx, dy) { return p.shifted(dy: dy, dx: dx) }')
  with_source_file(source, function(path) {
    results <- RStarStar::run_file(path)
    seen <- character()
    mark <- function(name, value) { seen <<- c(seen, name); value }
    value <- results$invoke(mark('receiver', results$Point(1, 2)), mark('dx', 3), mark('dy', 4))
    stopifnot(identical(seen, c('receiver', 'dy', 'dx')), value$x == 4, value$y == 6)
    seen <- character()
    error <- tryCatch(results$invoke(mark('receiver', 3), mark('dx', 3), mark('dy', 4)), error = identity)
    stopifnot(inherits(error, 'rstarstar_error'), identical(seen, c('receiver', 'dy', 'dx')))
  })
})
check("method runtime validates forged record layouts including nested fields", {
  source <- paste0(point_methods, '\nrecord Place { point: Point\nfn value(self) { return self.point.magnitude() } }\nfn value(p) { return p.value() }\nfn magnitude(p) { return p.magnitude() }')
  with_source_file(source, function(path) {
    result <- RStarStar::run_file(path)
    p <- result$Point(3, 4)
    for (bad in list(structure(list(x=3,y='bad'), rss_record_type='Point'),
                     structure(list(x=3,y=4,z=5), rss_record_type='Point'),
                     structure(list(y=4,x=3), rss_record_type='Point'))) {
      stopifnot(inherits(tryCatch(result$magnitude(bad), error=identity), 'rstarstar_error'))
    }
    place <- result$Place(p)
    place$point$x <- new.env()
    stopifnot(inherits(tryCatch(result$value(place), error=identity), 'rstarstar_error'))
    stopifnot(result$value(result$Place(p)) == 5)
  })
})
check("methods compose in filter scope and nested expression receivers", {
  with_sales(function(prefix) {
    result <- run(paste0(point_methods, '\np = Point(1, 2)\nrecord Threshold { value: Number\nfn accepts(self, values) { return values > self.value } }\nlimit = Threshold(100)\n', prefix,
      'filter sales where @limit.accepts(revenue) skipping missing into selected\nrecord Place { point: Point }\nplace = Place(p)\nx = (place with {point: Point(3, 4)}).point.magnitude()'))
    stopifnot(nrow(result$env$selected) == 1L, result$env$x == 5)
  })
})
check("method errors retain body and enclosing call locations", {
  source <- 'record P { x: Number\nfn bad(self, y) { return self.x + y }\n}\nfn call(p) { return p.bad("text") }\nx = call(P(1))'
  stopifnot(is.character(transpile(source)))
  error <- tryCatch(run(source), rstarstar_error=identity)
  stopifnot(inherits(error, 'rstarstar_error'), error$line == 2L,
            grepl('called at test.input:4:', conditionMessage(error), fixed=TRUE),
            grepl('called at test.input:5:', conditionMessage(error), fixed=TRUE))
})
check("methods stay private and generated programs run standalone", {
  with_source_file(paste0(point_methods, '\np = Point(3, 4)\nx = p.magnitude()'), function(path) {
    code <- RStarStar::transpile(path)
    result <- RStarStar::run_file(path)
    stopifnot(setequal(names(result), c('Point','p','x')), identical(names(result$p), c('x','y')))
    env <- new.env(parent=baseenv())
    eval(parse(text=code),env)
    stopifnot(env$x == 5)
  })
  ast <- rss_parse(rss_tokenize('record P { x: Number\nfn a(self) { return self.x }\n}\nx = P(1).a(\n)', 'span'), 'span')
  stopifnot(ast[[1]]$methods$a$span$line == 2L, ast[[1]]$methods$a$span$end_line == 2L,
            ast[[2]]$value$span$column == 5L, ast[[2]]$value$span$end_line == 5L)
})
check("method dispatch rejects dynamic partial and duplicate labels", {
  prefix <- paste0(point_methods, '\nfn partial(p) { return p.shifted(d: 1, dy: 2) }\nfn duplicate(p) { return p.shifted(1, dx: 2) }\n')
  filter_error(paste0(prefix, 'x = partial(Point(1, 2))'), 'Unknown method parameter')
  filter_error(paste0(prefix, 'x = duplicate(Point(1, 2))'), 'supplied more than once')
})
check("method declarations are lazy and helper names remain isolated", {
  source <- 'fn amount(x) { return x + 1 }\nrecord P { x: Number\nfn amount(self) { return amount(self.x) }\nfn unused(self) { return std::square_root(-1) }\n}\nself = 8\nmethods = 9\nschemas = 10\nmatch_method = 11\nx = P(2).amount()'
  result <- run(source)
  stopifnot(result$env$x == 3, result$env$self == 8)
})
