# R package guide

RStarStar 0.0.1 is an experimental, locally installable R package. There is no
public CLI and no published CRAN release. Its only exported function is
transpile(path), which accepts .rsspps files and returns generated R text.

## Install and compile

From an R session with the repository root as its working directory:

```r
install.packages(".", repos = NULL, type = "source")
library(RStarStar)
path <- system.file("examples", "basics.rsspps", package = "RStarStar")
code <- transpile(path)
cat(code)
```

For your own program, save RStarStar source in analysis.rsspps and call
transpile("analysis.rsspps"). Use ?transpile for installed API help. The package
includes six .rsspps examples and their small CSV fixtures under
system.file("examples", package = "RStarStar"). Rscript files in the repository's
examples/ directory are developer demo runners, not a public interface.

The package declares R >= 4.1.0, uses only R-bundled graphics/grDevices/utils
packages, and is verified locally on R 4.6.0/macOS arm64. Wider compatibility is
not yet tested. PNG chart execution needs Cairo support; compilation does not.
Choose a writable R library for installation. Release hosting is still undecided.

## Public API and file contract

- transpile(path) accepts one nonempty character path to an existing regular local
  file ending in lowercase .rsspps. Inline text, .R/.txt files, uppercase suffixes,
  URLs, R connections, and multiple paths are not accepted.
- Source must be UTF-8 text without NUL bytes. A UTF-8 BOM, CRLF line endings,
  and a missing final newline are accepted. An empty program returns empty R text.
- The parser validates the source contents; renaming arbitrary R code does not
  bypass language validation. Diagnostics for readable files use normalized
  absolute paths and the original source line/column.
- Compilation reads the source, but does not execute it, read program datasets,
  write charts, or modify the source. Loading the package does not execute programs.
- The string compiler rss_compile(source, filename), parser, and runtime builders
  are internal implementation details. They are not exported or stable APIs.

This restriction applies to source files only. CSV datasets, PNG outputs, and
ordinary R values keep their own formats. Relative data/chart paths resolve from
the execution working directory, not the .rsspps file's directory.

## Explicit execution from R

Generated code embeds its runtime helpers and can run without an installed
compiler. Execution remains an explicit R operation:

```r
results <- new.env(parent = baseenv())
eval(parse(text = code), envir = results)
results$adjusted
```

This allows an R caller to inspect values and call generated functions through
the evaluation environment. That is ordinary R evaluation, not a new execution
API or a sandbox. A beginner-oriented execution helper, its result contract, and
its file-effect policy remain future design work.

## Package development

DESCRIPTION, NAMESPACE, and man/ provide package metadata, exports, and API help.
The full MIT license is preserved in LICENSE.md; LICENSE contains R's standard
MIT stub. Maintainer metadata uses the existing repository commit identity.
inst/examples/ is the canonical home of packaged source examples and data.
Repository docs, progress logs, demo runners, and generated output are excluded
from the source-package payload using .Rbuildignore.

Reinstall after changing R/ and run Rscript tests/run.R against that installation.
Tests include internal compiler cases and public file-API cases. R CMD build .
and R CMD check --no-manual RStarStar_0.0.1.tar.gz validate the package, installed
help, examples, and tests. Use the current version in the archive name. Chart
rendering tests report skips when Cairo is unavailable. --no-manual omits PDF
manual generation only. See [Contributing](../CONTRIBUTING.md) for commands.

## Interoperability still to implement

The package already lets existing R code compile .rsspps files, and generated R
runs with ordinary R tooling. Broader interoperability remains a goal:

- An explicit bridge for .rsspps programs to call existing R functions, packages,
  and project APIs. Import/call syntax and supported conversions are undecided;
  arbitrary R calls are currently rejected by the language.
- A documented execution/result-transfer API for R callers, including the
  environment used and how functions/results are returned.
- Tested contracts for references, mutation, ownership, and cross-language errors.
  No deep-immutability guarantee across arbitrary R objects is implied.

.R files continue to be handled by R; they are not RStarStar compiler inputs.
Compiler internals remain private rather than automatically exposed as project
APIs. Compilation must not load or execute an interoperability dependency.
