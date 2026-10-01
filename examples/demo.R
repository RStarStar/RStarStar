# Run from the repository root: Rscript examples/demo.R
source("R/transpile.R")
input <- paste(readLines("examples/basics.txt", warn = FALSE), collapse = "\n")
generated <- transpile(input, filename = "examples/basics.txt")
cat("Generated R:\n", generated, "\n\nOutput:\n", sep = "")
# Execution is a separate, explicit step, used here to demonstrate the result.
eval(parse(text = generated), envir = new.env(parent = baseenv()))
