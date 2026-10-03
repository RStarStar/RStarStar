library(RStarStar)
path <- system.file("examples", "standard-library.rsspps", package = "RStarStar", mustWork = TRUE)
results <- run_file(path)
stopifnot(identical(results$magnitudes, c(9, 0, 16)),
          identical(results$roots, c(3, 0, 4)))
