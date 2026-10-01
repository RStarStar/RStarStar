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
and automatic cross-language result transfer remain future work.
}
\seealso{\code{\link{transpile}}}
