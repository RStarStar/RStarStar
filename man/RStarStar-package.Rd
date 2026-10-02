\name{RStarStar-package}
\alias{RStarStar-package}
\alias{RStarStar}
\docType{package}
\title{RStarStar: an Experimental Language Toolchain Implemented in R}
\description{
An R package that compiles local \code{.rsspps} source files to ordinary R.
The initial language includes immutable bindings, explicit mutation, vectors,
CSV loading, filtering, grouped summaries, PNG charts, and simple functions.
}
\details{
Use \code{transpile(path)} to compile a file without running it. Packaged source
examples are available with \code{system.file("examples", package = "RStarStar")}.
There is no public command-line interface. Records, classes, general R calls,
remain future work. Use \code{run_file(path)} to execute a file and return its
variables and functions to R.
}
\seealso{\code{\link{transpile}}, \code{\link{run_file}}}
