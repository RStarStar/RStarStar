# Run from the repository root after installing RStarStar: Rscript examples/read-csv.R
library(RStarStar)
path <- system.file("examples", "read-csv.rsspps", package = "RStarStar", mustWork = TRUE)
local({
  previous <- getwd()
  on.exit(setwd(previous))
  # Dataset paths in the packaged examples are relative to their examples folder.
  setwd(dirname(path))
  generated <- transpile(path)
  environment <- new.env(parent = baseenv())
  eval(parse(text = generated), envir = environment)
  stopifnot(identical(environment$codes$code, c("0012", "0007")),
            identical(environment$codes$amount, c(3, 4)),
            identical(environment$literal_codes$code, c("NA", NA_character_, "")))
})
