library(RStarStar)
local({
  directory <- system.file("examples", package = "RStarStar", mustWork = TRUE)
  previous <- setwd(directory)
  on.exit(setwd(previous))
  results <- run_file(file.path(directory, "functions.rsspps"))
  print(results$add_tax(c(100, 200), 0.1))
  print(results$selected)
})
