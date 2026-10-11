library(RStarStar)
local({
  directory <- system.file("examples", package = "RStarStar", mustWork = TRUE)
  previous <- getwd()
  results <- run_file(file.path(directory, "functions.rsspps"), working_dir = directory)
  stopifnot(identical(getwd(), previous))
  print(results$add_tax(c(100, 200), 0.1))
  print(results$selected)
})
