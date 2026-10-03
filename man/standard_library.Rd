\name{standard_library}
\alias{standard_library}
\title{Bundled Numeric Operations in RStarStar Source}
\description{
The experimental standard library in \code{.rsspps} source provides
\code{std::absolute(values)} and \code{std::square_root(values)}.
These are language operations, not exported R functions.
}
\details{
Both accept exactly one positional argument or an argument named \code{values:}.
Inputs must be integer or double vectors without attributes. Length, including
zero length, and numeric missing values are preserved. Negative nonmissing
square-root inputs fail at execution with a source location. Other namespaces,
implicit coercion, and first-class library functions are unsupported.
Required implementations are embedded in generated R, which remains standalone.
}
\examples{
path <- system.file("examples", "standard-library.rsspps", package = "RStarStar")
results <- run_file(path)
results$roots
}
\seealso{\code{\link{transpile}}, \code{\link{run_file}}}
