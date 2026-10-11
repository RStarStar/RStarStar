library(RStarStar)
path <- system.file("examples", "methods.rsspps", package = "RStarStar", mustWork = TRUE)
result <- run_file(path)
stopifnot(result$distance == 5, result$start$x == 3,
          result[["next"]]$x == 4, result[["next"]]$y == 6,
          result$origin$x == 0, result$origin$y == 0,
          result$on_axis$x == 0, result$axis_distance == 4,
          result$shifted_x == 3)
