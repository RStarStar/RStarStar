check("summaries work on literals and inside larger expressions", {
  result <- run('a = average([1, 2, 3])\nb = sum([1, 2, 3]) + 4\nc = count([true, false])\nd = average([2, 4] + 2)')
  stopifnot(result$env$a == 2, result$env$b == 10, result$env$c == 2, result$env$d == 5)
})
check("summary names remain valid variable names", {
  result <- run('count = 7\nsum = 8\naverage = 9\nresult = sum([count, sum, average])')
  stopifnot(result$env$result == 24)
})
check("CSV summaries and row counts", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, 'a = average(sales.revenue) skipping missing\nb = sum(sales.revenue) skipping missing\nc = count(sales)\nd = count(sales.revenue)\ne = count(sales.revenue) skipping missing'))
    stopifnot(result$env$a == 102.5, result$env$b == 205, result$env$c == 3,
              result$env$d == 3, result$env$e == 2)
    filter_error(paste0(prefix, 'print average(sales.revenue)'), "contains missing", 2L, 7L)
  })
})
check("empty and all-missing numeric summaries are deliberate", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, 'filter sales where false into empty\na = sum(empty.revenue)\nb = count(empty)'))
    stopifnot(result$env$a == 0, result$env$b == 0)
    filter_error(paste0(prefix, 'filter sales where false into empty\nprint average(empty.revenue)'), "Cannot average", 3L)
  })
  result <- run('x = sum([0 / 0]) skipping missing\ny = count([0 / 0]) skipping missing')
  stopifnot(result$env$x == 0, result$env$y == 0)
  filter_error('print average([0 / 0]) skipping missing', "Cannot average")
})
check("summary types, nonfinite inputs and overflowing results", {
  fails('print average([true, false])', "require numbers")
  fails('print sum("hello")', "require numbers")
  filter_error('print sum([1 / 0])', "finite values")
  filter_error('print sum([1e308, 1e308])', "finite numeric range")
  with_sales(function(prefix) {
    filter_error(paste0(prefix, 'print average(sales.region)'), "require numbers")
    fails(paste0(prefix, 'print count(sales) skipping missing'), "counts rows")
  })
})
check("summary predicates preserve filter name resolution", {
  with_sales(function(prefix) {
    result <- run(paste0(prefix, 'filter sales where revenue > average(revenue) skipping missing skipping missing into selected'))
    stopifnot(identical(result$env$selected$region, "North"))
  })
})
with_chart <- function(code) {
  path <- tempfile(fileext = ".png")
  on.exit(unlink(path))
  code(path, encodeString(path, quote = '"'))
}
plot_statement <- function(path, table = "selected", x = "region", y = "revenue") {
  paste("plot", table, "x", x, "y", y, "as bar to", path)
}
check("CSV-filter-summary-chart produces a valid standalone PNG", {
  with_sales(function(prefix) with_chart(function(path, quoted) {
    before <- grDevices::dev.list()
    result <- run(paste0(prefix, 'filter sales where revenue is not missing into selected\nmean_revenue = average(selected.revenue)\n', plot_statement(quoted)))
    stopifnot(result$env$mean_revenue == 102.5, file.exists(path), file.info(path)$size > 1000,
              identical(before, grDevices::dev.list()))
    connection <- file(path, "rb")
    on.exit(close(connection))
    stopifnot(identical(readBin(connection, "raw", 8L), as.raw(c(137, 80, 78, 71, 13, 10, 26, 10))))
    seek(connection, 16L)
    stopifnot(identical(readBin(connection, "integer", 2L, size = 4L, endian = "big"), c(1200L, 800L)))
  }))
})
check("plot compilation has no filesystem effects", {
  with_chart(function(path, quoted) {
    transpile(paste('read "nonexistent.csv" into selected\n', plot_statement(quoted)))
    stopifnot(!file.exists(path))
  })
})
check("chart rejects missing values without creating output", {
  with_sales(function(prefix) with_chart(function(path, quoted) {
    filter_error(paste0(prefix, plot_statement(quoted, table = "sales")), "contain missing", 2L, 1L)
    stopifnot(!file.exists(path))
  }))
})
check("chart rejects duplicate categories without implicit grouping", {
  with_csv(c("region,revenue", "North,1", "North,2"), function(csv) with_chart(function(path, quoted) {
    filter_error(paste("read", csv, "into selected\n", plot_statement(quoted)), "must be unique")
    stopifnot(!file.exists(path))
  }))
})
check("chart validates empty data, types and exact column names", {
  with_sales(function(prefix) with_chart(function(path, quoted) {
    filter_error(paste0(prefix, 'filter sales where false into selected\n', plot_statement(quoted)), "empty table")
    filter_error(paste0(prefix, plot_statement(quoted, "sales", y = "region")), "must be numeric")
    filter_error(paste0(prefix, plot_statement(quoted, "sales", y = "rev")), "Unknown chart column")
    stopifnot(!file.exists(path))
  }))
})
check("chart output does not overwrite existing files", {
  with_sales(function(prefix) with_chart(function(path, quoted) {
    writeLines("preserve this", path)
    filter_error(paste0(prefix, 'filter sales where revenue is not missing into selected\n', plot_statement(quoted)), "already exists")
    stopifnot(identical(readLines(path), "preserve this"))
  }))
})
check("chart reports nonexistent output directories", {
  with_sales(function(prefix) {
    quoted <- encodeString(file.path(tempfile(), "chart.png"), quote = '"')
    filter_error(paste0(prefix, 'filter sales where revenue is not missing into selected\n', plot_statement(quoted)), "directory does not exist")
  })
})
check("chart syntax and non-table checks", {
  fails('x = 1\nplot x x region y revenue as bar to "out.png"', "require a table")
  fails('read "a.csv" into data\nplot data x region y revenue as line to "out.png"', "Expected 'bar'")
  fails('read "a.csv" into data\nplot data x region y revenue as bar to "out.pdf"', ".png")
})
check("chart supports quoted headers and negative and zero values", {
  with_csv(c('Group name,Net total', 'A,-5', 'B,0'), function(csv) with_chart(function(path, quoted) {
    run(paste("read", csv, "into selected\n", plot_statement(quoted, x = '"Group name"', y = '"Net total"')))
    stopifnot(file.info(path)$size > 1000)
  }))
})
