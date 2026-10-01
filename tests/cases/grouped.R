with_groups <- function(code) {
  with_csv(c("region,revenue", "South,10", "North,20", "South,30", "North,NA"), function(path) {
    code(paste("read", path, "into sales\n"))
  })
}
check("grouped multiple statistics preserve first-seen order", {
  with_groups(function(prefix) {
    result <- run(paste0(prefix, "summarize sales by region with total = sum(revenue) skipping missing, mean = average(revenue) skipping missing, rows = count(revenue), known = count(revenue) skipping missing into totals"))
    stopifnot(identical(result$env$totals$region, c("South", "North")),
              identical(result$env$totals$total, c(40, 20)),
              identical(result$env$totals$mean, c(20, 20)),
              identical(result$env$totals$rows, c(2, 2)),
              identical(result$env$totals$known, c(2, 1)), nrow(result$env$sales) == 4L)
  })
})
check("grouped missing values require per-statistic policy", {
  with_groups(function(prefix) {
    filter_error(paste0(prefix, "summarize sales by region with total = sum(revenue) into totals"), "contains missing", 2L)
    filter_error(paste0(prefix, "summarize sales by region with total = sum(revenue) skipping missing, mean = average(revenue) into totals"), "contains missing", 2L)
  })
})
check("missing grouping keys are retained", {
  with_csv(c("region,revenue", "NA,1", "North,2", ",3"), function(path) {
    result <- run(paste("read", path, "into sales\nsummarize sales by region with total = sum(revenue) into totals"))
    stopifnot(identical(result$env$totals$region, c(NA_character_, "North")), identical(result$env$totals$total, c(4, 2)))
  })
})
check("quoted headers and numeric keys retain types", {
  with_csv(c('Group code,Order total', '2,10', '1,20', '2,5'), function(path) {
    result <- run(paste("read", path, 'into sales\nsummarize sales by "Group code" with total = sum(sales."Order total") into totals'))
    stopifnot(identical(result$env$totals[["Group code"]], c(2, 1)), identical(result$env$totals$total, c(15, 20)))
  })
})
check("empty grouped result retains schema", {
  with_groups(function(prefix) {
    result <- run(paste0(prefix, "filter sales where false into empty\nsummarize empty by region with total = sum(revenue), mean = average(revenue) into totals"))
    stopifnot(nrow(result$env$totals) == 0L, identical(names(result$env$totals), c("region", "total", "mean")),
              is.character(result$env$totals$region), is.numeric(result$env$totals$total))
    filter_error(paste0(prefix, "filter sales where false into empty\nsummarize empty by region with total = sum(typo) into totals"), "Unknown summary column")
  })
})
check("all-missing numeric group uses scalar summary rules", {
  with_csv(c("region,revenue", "A,1", "B,NA"), function(path) {
    prefix <- paste("read", path, "into sales\n")
    result <- run(paste0(prefix, "summarize sales by region with total = sum(revenue) skipping missing into totals"))
    stopifnot(identical(result$env$totals$total, c(1, 0)))
    filter_error(paste0(prefix, "summarize sales by region with mean = average(revenue) skipping missing into totals"), "Cannot average")
  })
})
check("grouped columns never resolve to ordinary bindings", {
  with_groups(function(prefix) {
    result <- run(paste0(prefix, "revenue = 999\nsummarize sales by region with total = sum(revenue) skipping missing into totals"))
    stopifnot(identical(result$env$totals$total, c(40, 20)))
    filter_error(paste0(prefix, "revenue = 999\nsummarize sales by typo with total = sum(revenue) into totals"), "Unknown grouping column")
  })
})
check("grouped grammar rejects unsupported expressions and duplicate outputs", {
  prefix <- 'read "a.csv" into sales\n'
  fails(paste0(prefix, 'summarize sales by region with region = sum(revenue) into totals'), "must be unique")
  fails(paste0(prefix, 'summarize sales by region with total = sum(revenue), total = count(revenue) into totals'), "must be unique")
  fails(paste0(prefix, 'summarize sales by region with total = sum(revenue + 1) into totals'), "Each grouped result")
  fails(paste0(prefix, 'summarize sales by region with total = sum(other.revenue) into totals'), "input table")
  fails(paste0(prefix, 'summarize sales region with total = sum(revenue) into totals'), "Expected 'by'")
  fails(paste0(prefix, 'summarize sales by region with total = sum(revenue)'), "Expected 'into'")
})
check("grouped targets follow mutation rules and preserve aliases", {
  with_groups(function(prefix) {
    result <- run(paste0(prefix, "summarize sales by region with total = sum(revenue) skipping missing into mut totals\noriginal = totals\nsummarize totals by region with value = sum(total) into totals"))
    stopifnot(identical(result$env$original$total, c(40, 20)), identical(result$env$totals$value, c(40, 20)))
    fails(paste0(prefix, "summarize sales by region with total = sum(revenue) into sales"), "Cannot reassign")
    fails("x = 1\nsummarize x by region with total = sum(revenue) into totals", "require a table")
  })
})
check("grouped numeric operations reject text but count accepts it", {
  with_groups(function(prefix) {
    filter_error(paste0(prefix, "summarize sales by region with total = sum(region) into totals"), "require numbers")
    result <- run(paste0(prefix, "summarize sales by region with rows = count(region) into totals"))
    stopifnot(identical(result$env$totals$rows, c(2, 2)))
  })
})
check_chart("grouped output can be filtered and charted", {
  with_groups(function(prefix) with_chart(function(path, quoted) {
    result <- run(paste0(prefix, "summarize sales by region with total = sum(revenue) skipping missing into totals\n",
                        "filter totals where total >= 20 into selected\n", plot_statement(quoted, "selected", "region", "total")))
    stopifnot(file.info(path)$size > 1000, nrow(result$env$selected) == 2L)
  }))
})
check("multiple keys preserve tuples, types, column order and first appearance", {
  with_csv(c("region,product,active,value", "South,2,true,10", "North,1,false,20",
             "South,2,true,5", "South,1,false,7"), function(path) {
    result <- run(paste("read", path, "into data\nsummarize data by region, product, active with total = sum(value), rows = count(value) into totals"))$env$totals
    stopifnot(identical(names(result), c("region", "product", "active", "total", "rows")),
              identical(result$region, c("South", "North", "South")),
              identical(result$product, c(2, 1, 1)), identical(result$active, c(TRUE, FALSE, FALSE)),
              identical(result$total, c(15, 20, 7)), identical(result$rows, c(2, 1, 1)))
  })
})
check("multi-key grouping cannot collide on text separators", {
  with_csv(c('a,b,value', 'a:b,c,1', 'a,b:c,2', 'a:b,c,3'), function(path) {
    result <- run(paste("read", path, "into data\nsummarize data by a, b with total = sum(value) into totals"))$env$totals
    stopifnot(nrow(result) == 2L, identical(result$total, c(4, 2)))
  })
})
check("missing combinations stay distinct and repeated missing tuples combine", {
  with_csv(c('a,b,value', 'NA,x,1', 'x,NA,2', 'NA,NA,3', 'NA,x,4'), function(path) {
    result <- run(paste("read", path, "into data\nsummarize data by a, b with total = sum(value) into totals"))$env$totals
    stopifnot(identical(result$a, c(NA_character_, "x", NA_character_)),
              identical(result$b, c("x", NA_character_, NA_character_)), identical(result$total, c(5, 2, 3)))
  })
})
check("empty multi-key output keeps typed keys and validates later columns", {
  with_csv(c('a,b,value', 'x,1,5'), function(path) {
    prefix <- paste("read", path, "into data\nfilter data where false into empty\n")
    result <- run(paste0(prefix, "summarize empty by a, b with total = sum(value) into totals"))$env$totals
    stopifnot(nrow(result) == 0L, is.character(result$a), is.numeric(result$b), is.numeric(result$total))
    filter_error(paste0(prefix, "summarize empty by a, typo with total = sum(value) into totals"), "Unknown grouping column 'typo'")
  })
})
check("multiple quoted grouping headers work", {
  with_csv(c('First key,Second key,value', 'x,a,1', 'x,a,2'), function(path) {
    result <- run(paste("read", path, 'into data\nsummarize data by "First key", "Second key" with total = sum(value) into totals'))$env$totals
    stopifnot(identical(names(result), c("First key", "Second key", "total")), result$total == 3)
  })
})
check("duplicate grouping keys and output collisions fail at compile time", {
  prefix <- 'read "a.csv" into data\n'
  fails(paste0(prefix, 'summarize data by a, a with total = sum(value) into totals'), "Grouping columns must be unique")
  fails(paste0(prefix, 'summarize data by a, "a" with total = sum(value) into totals'), "Grouping columns must be unique")
  fails(paste0(prefix, 'summarize data by a, b with b = sum(value) into totals'), "must be unique")
  fails(paste0(prefix, 'summarize data by a, with total = sum(value) into totals'), "Expected a grouping column")
})
check("multi-key results can roll up again without changing the source", {
  with_csv(c('region,product,value', 'A,x,1', 'A,y,2', 'A,x,3'), function(path) {
    result <- run(paste("read", path, 'into data\nsummarize data by region, product with total = sum(value) into detail\nsummarize detail by region with total = sum(total) into overall'))
    stopifnot(nrow(result$env$data) == 3L, nrow(result$env$detail) == 2L, result$env$overall$total == 6)
  })
})
