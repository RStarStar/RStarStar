# Run from the repository root: Rscript examples/grouped.R
source("R/transpile.R")
input <- paste(readLines("examples/grouped.txt"), collapse = "\n")
generated <- transpile(input, filename = "examples/grouped.txt")
eval(parse(text = generated), envir = new.env(parent = baseenv()))
