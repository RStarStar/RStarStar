\name{standard_library}
\alias{standard_library}
\title{Bundled Operations in RStarStar Source}
\description{
The experimental standard library in \code{.rsspps} source provides
\code{std::absolute(values)}, \code{std::square_root(values)},
\code{std::text_length(values)}, and \code{std::trim_text(values)}.
These are language operations, not exported R functions.
}
\details{
All accept exactly one positional argument or an argument named \code{values:}.
Numeric operations require integer or double vectors without attributes. Length, including
zero length, and numeric missing values are preserved. Negative nonmissing
square-root inputs fail at execution with a source location. Other namespaces,
implicit coercion, and first-class library functions are unsupported.
The text-length operation accepts character vectors without attributes and returns
numeric character counts. Empty strings have length zero; missing and empty vectors
are preserved. UTF-8 counts are Unicode code points, not grapheme clusters or bytes.
No normalization occurs. Invalid or byte-encoded text from R raises a source-located
error. Text factors, matrices, and numeric inputs are rejected.
The trim-text operation accepts plain character vectors and returns text after
removing boundary spaces, tabs, carriage returns, and newlines. Internal spacing,
other Unicode whitespace, missing values, and vector length are preserved.
Whitespace-only strings become empty strings. Encoding checks follow text length.
Required implementations are embedded in generated R, which remains standalone.
}
\examples{
path <- system.file("examples", "standard-library.rsspps", package = "RStarStar")
results <- run_file(path)
results$roots
results$code_lengths
results$clean_codes
}
\seealso{\code{\link{transpile}}, \code{\link{run_file}}}
