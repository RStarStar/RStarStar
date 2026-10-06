\name{record_methods}
\alias{record_methods}
\title{Value Methods on RStarStar Records}
\description{
Record declarations can contain fn methods after their fields. Methods require
self as their first parameter and one return expression. Receiver calls supply
self implicitly and require exact positional or named arguments.
}
\details{
Methods return values; updates use existing with expressions to return a copied
record. Mutation, recursion, forward references, and bound method values are
unsupported. Each call sees only methods available at its declaration position.
Unknown receivers are checked at execution against the visible nominal types and
record layouts. Receiver and arguments evaluate once in source order. Body errors
retain method and ordinary function call locations.
Records remain ordinary R lists with internal tags. R callers may invoke methods
through returned language wrapper functions, not native R dollar-method calls.
This is not deep immutability or provenance checking for arbitrary R objects.
Generated code remains standalone, with private method metadata.
}
\examples{
path <- system.file("examples", "methods.rsspps", package = "RStarStar")
result <- run_file(path)
result$distance
}
\seealso{\code{\link{run_file}}, \code{\link{transpile}}}
