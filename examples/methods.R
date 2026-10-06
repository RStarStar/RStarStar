library(RStarStar)
path <- system.file("examples", "methods.rsspps", package = "RStarStar", mustWork = TRUE)
result <- run_file(path)
stopifnot(result$distance == 5, result$start$x == 3,
          result[["next"]]$x == 4, result[["next"]]$y == 6)
