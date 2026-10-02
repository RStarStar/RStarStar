library(RStarStar)
path <- system.file("examples", "records.rsspps", package = "RStarStar", mustWork = TRUE)
results <- run_file(path)
stopifnot(results$result$mean == 20, results$current$mean == 25)
