# Run from the repository root after installing RStarStar: Rscript examples/filter.R
library(RStarStar)
path <- system.file("examples", "filter.rsspps", package = "RStarStar", mustWork = TRUE)
local({
  previous <- getwd()
  on.exit(setwd(previous))
  # Dataset paths in the packaged examples are relative to their examples folder.
  setwd(dirname(path))
  generated <- transpile(path)
  environment <- new.env(parent = baseenv())
  eval(parse(text = generated), envir = environment)
  stopifnot(identical(environment$matching_regions$region, c(" North ", "NORTH")),
            identical(environment$matching_regions$revenue, c(10, 20)),
            identical(environment$regions$region, c(" North ", "NORTH", "South", NA_character_)),
            identical(environment$missing_regions$revenue, 40))
})
