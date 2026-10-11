\name{run_file}
\alias{run_file}
\title{Execute a RStarStar Source File and Return Its Bindings}
\usage{run_file(path, working_dir = NULL)}
\arguments{
  \item{path}{One local UTF-8 \code{.rsspps} file path, as required by
  \code{\link{transpile}}.}
  \item{working_dir}{Optional nonempty path to an existing local directory for
  program execution. Relative paths are resolved from the caller's working
  directory. \code{NULL} (the default) uses the caller's working directory.}
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
Classes support private scalar or record fields, scalar literal constructor defaults, and explicit
mutating methods. Fields without defaults remain required. Returned constructors
expose defaults to R callers under ordinary R calling rules. Records also support
scalar literal defaults; nested record-valued fields still require explicit values. Mutation
replaces only a named mutable receiver after the entire method succeeds; aliases
retain their values. Record fields require explicit arguments and recursive layout
validation during construction, dispatch, and replacement. Class values are tagged R lists, and generated code does not
require R6. R callers can inspect or modify returned lists; source privacy is not
a security boundary. See the packaged \code{classes.rsspps} example.

Nested record constructor inputs and record copy-update receivers and replacements
are checked against declared schemas recursively. R-modified values with wrong
leaf types or missing/extra fields are rejected. Copy updates do not repair invalid
receivers. Matching manually tagged values may still be accepted; layout checks
are not a provenance guarantee.

Compilation errors prevent execution. Runtime errors propagate without returning
partial results; earlier console and file effects are not rolled back. Language
errors retain their original source locations.

Printing goes to normal R output. CSV exports refuse to overwrite existing files.
Relative data, export, and chart paths resolve from \code{working_dir} when supplied,
or from the caller's working directory by default. The source \code{path} is always
resolved and compiled before changing directories. Compilation errors take precedence
over invalid \code{working_dir} arguments. Invalid or inaccessible directories fail
before program execution with an \code{rstarstar_error}.

An explicit \code{working_dir} temporarily changes R's process working directory;
the caller's directory is restored on return or error. No directory is created.
This is a path-resolution convenience, not filesystem isolation: absolute paths
and parent-directory paths remain usable. Charts retain their existing Cairo
requirement and refusal to overwrite files.

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

directory <- system.file("examples", package = "RStarStar")
sales <- run_file(file.path(directory, "filter.rsspps"), working_dir = directory)
sales$matching_regions
}
