\name{run_file}
\alias{run_file}
\title{Execute a RStarStar Source File and Return Its Bindings}
\usage{run_file(path)}
\arguments{
  \item{path}{One local UTF-8 \code{.rsspps} file path, as required by
  \code{\link{transpile}}.}
}
\description{
Compiles the entire file, then explicitly executes the generated R in a fresh
 environment with the base R environment as its parent.
}
\value{
A named list of final top-level variables and functions, excluding compiler
runtime helpers. Names follow R's default sorted order. Empty programs and
print-only programs return an empty list. Returned functions retain their runtime
checks and can be called from R.
}
\details{
Compilation errors prevent execution. Runtime errors propagate without returning
partial results; earlier console and file effects are not rolled back. Language
errors retain their original source locations.

Printing goes to normal R output. CSV exports refuse to overwrite existing files. Data and chart paths resolve from the caller's
working directory; this function does not change it. Charts retain their existing
Cairo requirement and refusal to overwrite files.

Each call uses fresh program bindings. Caller variables are not injected. Results
are ordinary R values, and returned functions are ordinary R closures with R's
argument matching and evaluation rules when invoked from R. This is not a sandbox
or a deep-immutability guarantee. Calling arbitrary external R APIs from the
source language remains unsupported.
}
\seealso{\code{\link{transpile}}}
\examples{
path <- system.file("examples", "basics.rsspps", package = "RStarStar")
results <- run_file(path)
results$adjusted
}
