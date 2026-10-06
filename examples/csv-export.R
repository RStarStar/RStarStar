library(RStarStar)
local({
  path <- system.file("examples", "csv-export.rsspps", package = "RStarStar", mustWork = TRUE)
  directory <- tempfile("rstarstar-export-demo-")
  dir.create(directory)
  previous <- getwd()
  on.exit({ setwd(previous); unlink(directory, recursive = TRUE) })
  dir.create(file.path(directory, "data"))
  stopifnot(file.copy(file.path(dirname(path), "data", "sales.csv"), file.path(directory, "data", "sales.csv")))
  setwd(directory)
  results <- run_file(path)
  stopifnot(identical(results$sales, results$restored), file.exists("sales-export.csv"),
            any(grepl("N/A", readLines("sales-export.csv"), fixed = TRUE)))
})
