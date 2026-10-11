\name{standard_library}
\alias{standard_library}
\title{Bundled Operations in RStarStar Source}
\description{
The experimental standard library in \code{.rsspps} source provides
\code{std::absolute(values)}, \code{std::square_root(values)},
\code{std::is_finite(values)}, \code{std::text_length(values)},
\code{std::trim_text(values)}, and \code{std::lower_text(values)}.
These are language operations, not exported R functions.
}
\details{
The six operations listed above accept exactly one positional argument or an argument named \code{values:}.
Numeric operations require integer or double vectors without attributes. Length, including
zero length, is preserved. Absolute values and square roots preserve numeric missing values. Negative nonmissing
square-root inputs fail at execution with a source location. Other namespaces,
implicit coercion, and first-class library functions are unsupported.
The finite-number predicate returns a logical vector: finite numbers map to true;
NA, NaN, and positive/negative infinity map to false. Its result is never missing.
Empty numeric inputs yield an empty logical vector. The predicate does not suppress
errors evaluating its input or guarantee that a value meets other domain constraints.
The text-length operation accepts character vectors without attributes and returns
numeric character counts. Empty strings have length zero; missing and empty vectors
are preserved. UTF-8 counts are Unicode code points, not grapheme clusters or bytes.
No normalization occurs. Invalid or byte-encoded text from R raises a source-located
error. Text factors, matrices, and numeric inputs are rejected.
The trim-text operation accepts plain character vectors and returns text after
removing boundary spaces, tabs, carriage returns, and newlines. Internal spacing,
other Unicode whitespace, missing values, and vector length are preserved.
Whitespace-only strings become empty strings. Encoding checks follow text length.
The lowercase operation accepts plain character vectors and uses R's current
LC_CTYPE locale without changing it. It preserves missing values, length, and
whitespace. It is not full Unicode case folding or normalization; non-ASCII mappings
can vary by locale/platform. Invalid or byte-encoded text is rejected.
Required implementations are embedded in generated R, which remains standalone.
The library additionally supports local UTF-8 text files with \code{std::file_exists},
\code{std::read_text}, and \code{std::write_text}, and background workers with
\code{std::start_task} and \code{std::await_task}. These use their own exact named
signatures. See \code{\link{file_tasks}} for effects, process requirements, and limits.
}
\examples{
path <- system.file("examples", "standard-library.rsspps", package = "RStarStar")
results <- run_file(path)
results$roots
results$code_lengths
results$clean_codes
results$normalized_labels
results$finite_ratios
}
\seealso{\code{\link{transpile}}, \code{\link{run_file}}, \code{\link{file_tasks}}}
