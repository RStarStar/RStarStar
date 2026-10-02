\name{transpile}
\alias{transpile}
\title{Compile a RStarStar Source File into R Code}
\usage{
transpile(path)
}
\arguments{
  \item{path}{One nonempty character string naming an existing regular local
  file with the lowercase extension \code{.rsspps}. The file must contain UTF-8
  text. A UTF-8 byte order mark is accepted.}
}
\description{
Validates and compiles a RStarStar source file into readable R source text.
Compilation does not execute the program, load its datasets, or write charts.
}
\value{
A single character string containing generated R source, or an empty string for
an empty program. Language and input errors inherit from \code{rstarstar_error}
and include source locations. For readable source files, diagnostics use the
normalized absolute path.
}
\details{
Only file paths are accepted by the public API. Inline source strings, R source
files, URLs, connections, and batches of paths are not supported. Internal
compiler helpers are not exported.

Generated code embeds its required runtime helpers and can be saved or evaluated
explicitly in an R session. Compilation is separate from execution and is not a
sandbox for later execution. Relative data and chart paths resolve from the
working directory when generated code executes, not from the source-file folder.
PNG chart execution requires an R installation with Cairo support; other
compilation and language features do not require it.

The language and package API are experimental. An R-call bridge is not yet implemented.
Use \code{\link{run_file}} for explicit execution and result transfer.
}
\examples{
path <- system.file("examples", "basics.rsspps", package = "RStarStar")
code <- transpile(path)
cat(code)
# Execution is an explicit separate operation:
results <- new.env(parent = baseenv())
eval(parse(text = code), envir = results)
results$adjusted
}
