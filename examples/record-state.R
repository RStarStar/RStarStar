library(RStarStar)
path <- system.file("examples", "record-state.rsspps", package = "RStarStar", mustWork = TRUE)
result <- run_file(path)
stopifnot(result$origin$x == 0, result$before$x == 0,
          result$after$x == 3, result$after$y == 4, result$move_count == 1)
