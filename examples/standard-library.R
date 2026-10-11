library(RStarStar)
path <- system.file("examples", "standard-library.rsspps", package = "RStarStar", mustWork = TRUE)
results <- run_file(path)
stopifnot(identical(results$magnitudes, c(9, 0, 16)),
          identical(results$roots, c(3, 0, 4)),
          identical(results$finite_ratios, c(TRUE, FALSE, FALSE, FALSE)),
          identical(results$ratios, c(5, Inf, NaN, -Inf)),
          identical(results$code_lengths, c(1, 3, 0)),
          identical(results$clean_codes, c("A", "ABC", "")),
          identical(results$clean_lengths, c(1, 3, 0)))
stopifnot(identical(results$normalized_labels, c("north", "north", "south")),
          identical(results$labels, c(" North ", "NORTH", "South")))
