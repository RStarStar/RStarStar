# Loaded after csv.R for its temporary fixture helper.
with_sales <- function(code) {
  with_csv(c('region,revenue,active,Order total', 'North,120,true,10',
             'South,85,false,20', 'West,,true,30'), function(path) {
    code(paste("read", path, "into sales\n"))
  })
}
filter_error <- function(source, message, line = NULL, column = NULL) {
  error <- tryCatch(run(source), rstarstar_error = identity)
  stopifnot(inherits(error, "rstarstar_error"), grepl(message, conditionMessage(error), fixed = TRUE),
            error$filename == "test.input")
  if (!is.null(line)) stopifnot(error$line == line)
  if (!is.null(column)) stopifnot(error$column == column)
}
check("column extraction preserves values and missing entries", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, 'values = sales.revenue\nprint sales."Order total"'))
    stopifnot(identical(result$env$values, c(120, 85, NA_real_)), length(result$output) == 1L)
  })
})
check("filter skips missing only when explicitly requested", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, "filter sales where revenue > 90 skipping missing into selected"))
    stopifnot(identical(result$env$selected$region, "North"), nrow(result$env$sales) == 3L,
              identical(names(result$env$selected), names(result$env$sales)))
    filter_error(paste0(prefix, "filter sales where revenue > 90 into selected"), "contains missing", 2L, 1L)
  })
})
check("missing tests retain missing rows or explicitly exclude them", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, "filter sales where revenue is missing into absent_rows\n",
                        "filter sales where revenue is not missing and revenue > 90 into selected"))
    stopifnot(identical(result$env$absent_rows$region, "West"), identical(result$env$selected$region, "North"))
  })
})
check("bare column names and explicit local variables never shadow each other", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, "revenue = 1000\nminimum = 90\n",
                        "filter sales where revenue > @minimum skipping missing into selected"))
    stopifnot(identical(result$env$selected$region, "North"))
    filter_error(paste0(prefix, 'minimum = 90\nfilter sales where revenue > minimum into selected'), "Unknown column 'minimum'", 3L)
    fails(paste0(prefix, "filter sales where revenue > @undefined into selected"), "Unknown variable")
  })
})
check("qualified columns and quoted headers in filters", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, 'filter sales where sales."Order total" >= 20 into selected'))
    stopifnot(identical(result$env$selected$region, c("South", "West")))
  })
})
check("text equality, boolean columns and compound predicates", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, 'filter sales where not active or region == "West" into selected'))
    stopifnot(identical(result$env$selected$region, c("South", "West")))
  })
})
check("all comparison operators and expression precedence", {
  result <- run('a = 2 + 3 * 4 >= 14\nb = 2 != 3\nc = 2 <= 2\nd = 2 < 3\ne = 3 > 2\nf = 2 == 2\ng = not 1 > 2 and false or true')
  stopifnot(all(vapply(c("a", "b", "c", "d", "e", "f", "g"), function(n) result$env[[n]], logical(1))))
  fails("x = 1 < 2 < 3", "cannot be chained")
  fails('x = 1 == "1"', "matching value types")
  fails('x = true < false', "Ordered comparisons")
  fails('x = 1 and true', "require booleans")
})
check("dynamic arithmetic respects types and lengths", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, 'adjusted = sales.revenue + 5'))
    stopifnot(identical(result$env$adjusted, c(125, 90, NA_real_)))
    filter_error(paste0(prefix, 'print sales.region + 1'), "Arithmetic requires numbers", 2L, 20L)
    filter_error(paste0(prefix, 'print sales.revenue + [1, 2]'), "Vector lengths must match", 2L)
    filter_error(paste0(prefix, 'print sales.region == 1'), "matching value types", 2L)
    filter_error(paste0(prefix, 'print not sales.revenue'), "require booleans", 2L)
  })
})
check("runtime vectors do not coerce or flatten columns", {
  with_sales(function(prefix) {
    filter_error(paste0(prefix, "print [sales.revenue]"), "each contain one value")
  })
  with_csv(c("x", "hello"), function(path) {
    filter_error(paste("read", path, 'into data\nprint [data.x, 1]'), "same non-table type")
  })
})
check("mutable column bindings keep their runtime type", {
  with_sales(function(prefix) {
    filter_error(paste0(prefix, 'mut x = sales.revenue\nx = "hello"'), "from Number to Text", 3L)
    filter_error(paste0(prefix, 'mut x = 1\nx = sales.region'), "from Number to Text", 3L)
    result <- run(paste0(prefix, 'mut x = sales.revenue\nx = [1, 2]'))
    stopifnot(identical(result$env$x, c(1, 2)))
  })
})
check("filter requires boolean and correct predicate length", {
  with_sales(function(prefix) {
    fails(paste0(prefix, 'filter sales where 1 into selected'), "must be boolean")
    filter_error(paste0(prefix, 'filter sales where revenue into selected'), "must be boolean")
    filter_error(paste0(prefix, 'filter sales where [true, false] into selected'), "one value per row")
  })
})
check("scalar filters retain all or no rows without losing columns", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, "filter sales where true into all_rows\nfilter sales where false into no_rows"))
    stopifnot(identical(result$env$all_rows, result$env$sales), nrow(result$env$no_rows) == 0L,
              identical(names(result$env$no_rows), names(result$env$sales)))
  })
})
check("filtering a typed empty result works", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, "filter sales where false into empty\nfilter empty where revenue > 0 into still_empty"))
    stopifnot(nrow(result$env$still_empty) == 0L, is.numeric(result$env$still_empty$revenue))
  })
})
check("header-only and all-missing columns retain the CSV inference policy", {
  with_csv("value", function(path) {
    result <- run(paste("read", path, "into data\nfilter data where value is missing into selected"))
    stopifnot(nrow(result$env$selected) == 0L)
    filter_error(paste("read", path, "into data\nfilter data where value > 0 into selected"), "matching value types")
  })
  with_csv(c("value", "NA"), function(path) {
    result <- run(paste("read", path, "into data\nfilter data where value is missing into selected"))
    stopifnot(nrow(result$env$selected) == 1L)
  })
})
check("single-column tables remain tables after filtering", {
  with_csv(c("value", "1", "2"), function(path) {
    result <- run(paste("read", path, "into data\nfilter data where value > 1 into selected"))
    stopifnot(is.data.frame(result$env$selected), identical(result$env$selected$value, 2))
  })
})
check("filter chaining, mutable targets and input preservation", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, "filter sales where active into mut selected\n",
                        'filter selected where region != "West" into selected'))
    stopifnot(nrow(result$env$sales) == 3L, identical(result$env$selected$region, "North"))
    fails(paste0(prefix, 'filter sales where true into sales'), "Cannot reassign")
    fails(paste0(prefix, 'x = 1\nfilter sales where true into x'), "Cannot reassign")
  })
})
check("unknown columns never use partial matching", {
  with_sales(function(prefix) {
    filter_error(paste0(prefix, "print sales.rev"), "Unknown column 'rev'", 2L, 7L)
    filter_error(paste0(prefix, "filter sales where rev > 0 into selected"), "Unknown column 'rev'", 2L, 20L)
  })
})
check("non-table access and malformed filter syntax", {
  fails("x = 1\nprint x.value", "require a table")
  fails("x = 1\nfilter x where true into y", "require a table")
  fails('read "a.csv" into data\nfilter data true into selected', "Expected 'where'")
  fails('read "a.csv" into data\nfilter data where true', "Expected 'into'")
  fails('read "a.csv" into data\nprint data.', "Expected a column")
})
check("missing tests work on NaN and logical comparisons", {
  result <- run('x = [0 / 0, 1]\na = x is missing\nb = x is not missing\nc = not (x == 1)')
  stopifnot(identical(result$env$a, c(TRUE, FALSE)), identical(result$env$b, c(FALSE, TRUE)),
            identical(result$env$c, c(NA, FALSE)))
})
check("runtime helper names cannot collide with user variables", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, 'c = 3\nlength = 4\ntype = 5\nvalues = [c, length, type]\nprint values'))
    stopifnot(identical(result$env$values, c(3, 4, 5)))
  })
})
check("in-place filtering leaves earlier aliases intact", {
  with_csv(c("value", "1", "2"), function(path) {
    result <- run(paste("read", path, "into mut data\noriginal = data\nfilter data where value > 1 into data"))
    stopifnot(nrow(result$env$original) == 2L, nrow(result$env$data) == 1L)
  })
})
check("filter AST spans cover the complete statement", {
  source <- "filter data where (\nvalue > 0\n) skipping missing into selected"
  ast <- rss_parse(rss_tokenize(source, "span"), "span")
  stopifnot(ast[[1L]]$span$line == 1L, ast[[1L]]$span$end_line == 3L,
            ast[[1L]]$span$end_column == nchar(strsplit(source, "\n")[[1L]][[3L]]) + 1L)
})
