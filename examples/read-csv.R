# Run from the repository root: Rscript examples/read-csv.R
source("R/transpile.R")
input <- paste(readLines("examples/read-csv.txt"), collapse = "\n")
generated <- transpile(input, filename = "examples/read-csv.txt")
# The generated source includes its loader and can also be saved as an R script.
eval(parse(text = generated), envir = new.env(parent = baseenv()))
