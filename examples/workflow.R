# Run from the repository root: Rscript examples/workflow.R [output.png]
source("R/transpile.R")
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) > 1L) stop("Usage: Rscript examples/workflow.R [output.png]")
if (length(arguments)) {
  output <- arguments[[1L]]
} else {
  dir.create("examples/output", showWarnings = FALSE)
  output <- tempfile("sales-", tmpdir = "examples/output", fileext = ".png")
}
input <- paste(readLines("examples/workflow.txt"), collapse = "\n")
# Use a unique default output so rerunning the demo never overwrites a chart.
stopifnot(endsWith(input, '"revenue.png"'))
input <- paste0(substring(input, 1L, nchar(input) - nchar('"revenue.png"')),
                encodeString(output, quote = '"'))
generated <- transpile(input, filename = "examples/workflow.txt")
eval(parse(text = generated), envir = new.env(parent = baseenv()))
cat("Chart saved to:", normalizePath(output), "\n")
