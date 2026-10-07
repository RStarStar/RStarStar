library(RStarStar)
path <- system.file("examples", "classes.rsspps", package = "RStarStar", mustWork = TRUE)
result <- run_file(path)
stopifnot(result$original == 0, result$updated == 5)
