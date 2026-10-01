# Run from the repository root after installing RStarStar: Rscript examples/filter.R
library(RStarStar)
path <- system.file("examples", "filter.rsspps", package = "RStarStar", mustWork = TRUE)
local({
  previous <- getwd()
  on.exit(setwd(previous))
  # Dataset paths in the packaged examples are relative to their examples folder.
  setwd(dirname(path))
  generated <- transpile(path)
  eval(parse(text = generated), envir = new.env(parent = baseenv()))
})
