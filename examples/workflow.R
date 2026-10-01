# Run from the repository root after installation: Rscript examples/workflow.R [output.png]
library(RStarStar)
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) > 1L) stop("Usage: Rscript examples/workflow.R [output.png]")
if (length(arguments)) {
  output <- arguments[[1L]]
} else {
  dir.create("examples/output", showWarnings = FALSE)
  output <- tempfile("sales-", tmpdir = "examples/output", fileext = ".png")
}
output <- file.path(normalizePath(dirname(output), mustWork = TRUE), basename(output))
path <- system.file("examples", "workflow.rsspps", package = "RStarStar", mustWork = TRUE)
local({
  previous <- getwd()
  on.exit(setwd(previous))
  input <- paste(readLines(path), collapse = "\n")
  stopifnot(endsWith(input, '"revenue.png"'))
  input <- paste0(substring(input, 1L, nchar(input) - nchar('"revenue.png"')),
                  encodeString(output, quote = '"'))
  source_file <- tempfile(fileext = ".rsspps")
  on.exit(unlink(source_file), add = TRUE)
  writeLines(input, source_file)
  setwd(dirname(path))
  generated <- transpile(source_file)
  eval(parse(text = generated), envir = new.env(parent = baseenv()))
})
cat("Chart saved to:", normalizePath(output), "\n")
