# Run from the repository root: Rscript examples/filter.R
source("R/transpile.R")
input <- paste(readLines("examples/filter.txt"), collapse = "\n")
generated <- transpile(input, filename = "examples/filter.txt")
eval(parse(text = generated), envir = new.env(parent = baseenv()))
