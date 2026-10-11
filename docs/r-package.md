# R package guide

RStarStar 0.0.26 is an experimental, locally installable R package. There is no
public CLI and no published CRAN release. It exports transpile(path) to return generated R text and run_file(path) to
execute a program and return its bindings. Both accept .rsspps files only.

For a step-by-step project walkthrough, start with [Using RStarStar in your R projects](using-from-r.md).

## Install and compile

From an R session with the repository root as its working directory:

```r
install.packages("R6") # Once, if not already installed
install.packages(".", repos = NULL, type = "source")
library(RStarStar)
path <- system.file("examples", "basics.rsspps", package = "RStarStar")
code <- transpile(path)
cat(code)
```

For your own program, save RStarStar source in analysis.rsspps and call
transpile("analysis.rsspps"). Use ?transpile for installed API help. The package
includes twelve .rsspps examples and their small CSV fixtures under
system.file("examples", package = "RStarStar"). Rscript files in the repository's
examples/ directory are developer demo runners, not a public interface.

The package declares R >= 4.1.0 and uses R6 for compiler internals alongside
R-bundled graphics/grDevices/utils. Generated programs do not require R6.
Local verification uses R 4.6.0/macOS arm64. Wider compatibility is
not yet verified. CI targets R release on Linux/macOS/Windows and R 4.1.0 on
Linux; see [automated checks](../CONTRIBUTING.md#automated-package-checks). PNG chart execution needs Cairo support; compilation does not.
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

Call run_file(path) when you want to execute a program:

```r
results <- run_file(path)
results$adjusted
```

The entire file compiles before execution starts. Each run uses a fresh environment
with base R as its parent and returns a named list of final variables and functions.
Names follow R's default sorted order; runtime helpers are excluded. Empty and
print-only programs return an empty list. Returned functions retain their checks
and can be called by existing R code, using ordinary R argument semantics.

Printing goes to normal R output. CSV reads/exports and chart writes happen during execution;
relative paths use the caller's working directory by default.
CSV exports and charts refuse to overwrite existing files. Charts still require Cairo. Runtime errors
preserve source locations and return no partial result. Earlier output/file effects
are not rolled back. For example, a print followed by a missing CSV still prints
before raising an error; an invalid declaration later in the file prevents all execution.

Use run_file(path, working_dir = directory) to choose an execution directory without
manually calling setwd(). For example, run an installed CSV example from any folder:

```r
directory <- system.file("examples", package = "RStarStar", mustWork = TRUE)
results <- run_file(file.path(directory, "filter.rsspps"), working_dir = directory)
results$matching_regions
```

working_dir defaults to NULL, preserving the caller's directory. An explicit value
must be one nonempty path to an existing local directory; it is not created.
Both path and a relative working_dir resolve from the caller's directory. The entire
source compiles before directory selection, so source errors take precedence over
invalid directory arguments. For valid source, an invalid or inaccessible directory
raises rstarstar_error before any program output or file effects. For example,
run_file(path, working_dir = "absent-folder") fails if that folder does not exist.

Execution temporarily changes R's process working directory and restores it on
return or error. This controls relative paths only; it does not restrict filesystem
access or roll back earlier writes. Generated R is unchanged and uses whichever
directory is active when separately executed. Returned functions remain ordinary
R closures; working_dir applies only during this run_file call.

Records return as ordinary named R lists with an internal type attribute, and their
constructors return as R functions. Field checks apply when constructors run; R
callers can subsequently modify returned lists. Nested constructor inputs and with
update receivers/replacements are checked recursively against the declared record
schemas. Wrong leaf types, missing/extra/reordered fields, and unsupported attributes
fail rather than defining a new layout. Updates cannot repair invalid receivers.
Matching hand-built tagged lists may still be accepted; this does not prove their
origin. This is not enforced immutability
outside the source language. See [records](implemented-subset.md#records).

Caller variables are not injected. Results are ordinary R values and functions are
ordinary closures; this is not a sandbox or a deep-immutability guarantee. Generated
code still embeds its runtime helpers and can be saved and evaluated separately
without an installed compiler. See ?run_file for installed help and
examples/run-file.R for an R caller using a returned function and table.

## Bundled standard library

The package includes experimental std::absolute(values) and std::square_root(values)
for plain numeric scalars and vectors. Missing values propagate; negative square
roots fail at execution. std::text_length(values) counts characters in plain text,
preserving missing values and vector length. std::lower_text(values) produces lowercase text using the current R locale.
It preserves missing values and is not Unicode normalization or full case folding.
std::trim_text(values) removes boundary
spaces, tabs, carriage returns, and newlines from text. Only required implementations are embedded in standalone
generated R. There are no new R exports or dependencies. See the
[standard-library contract](standard-library.md) for examples and limits.

## CSV column types

Inside a .rsspps file, read supports optional with columns {code: Text} to preserve
identifiers such as 0012. Number and Boolean declarations validate every nonmissing
value and retain type for empty/all-missing columns. Other columns remain inferred.
The optional with missing ["", "N/A"] clause replaces default missing markers;
with missing [] preserves every field before conversion. These options change
source syntax, not the public file API. See
[CSV column types](implemented-subset.md#explicit-csv-column-types).

## CSV export delimiters

Source statements such as write sales to "sales-export.csv" with delimiter ";"
can choose comma, semicolon, tab, or pipe. A .csv suffix is required; output refuses
to overwrite existing files. The packaged csv-export.rsspps example reads back its
semicolon output using the matching delimiter and an explicit N/A missing marker.
Write accepts one quoted marker (with missing "N/A"); read accepts a list
(with missing ["N/A"]). Choose a marker absent from real data. Export markers cannot
contain the selected delimiter, quotes, or line breaks. The development runner
examples/csv-export.R executes it in a temporary directory and removes its output.

## Mutable classes

The classes.rsspps example demonstrates private scalar fields, mut self methods,
and standalone mutation on mutable bindings. Copies keep their original values;
failed methods do not replace the receiver. Class fields may declare type-checked literal defaults; Counter() in the example
uses value: Number = 0. Explicit arguments override defaults, and fields without
defaults remain required. Returned constructor functions expose these defaults to R
callers. The record-state.rsspps example adds record-valued class fields and
whole-field copy updates. Nested record layouts are checked recursively at
construction, method dispatch, and replacement, including values supplied by R
callers. Record fields require explicit arguments; nested class fields and computed
defaults remain unsupported.

Class results are ordinary tagged lists. Source privacy does not prevent inspection
or modification from R, and there is no native dollar-method API. Generated class
code remains independent of R6. See the [class contract](mutable-classes.md).

## Constructor diagnostics

Source calls to record and class constructors identify omitted required fields,
including every missing field in declaration order. Too many arguments report the
maximum accepted count, including optional fields. For example, a constructor with
one defaulted field accepts zero or one arguments; passing two reports that it
accepts at most one. Names remain exact. Non-overfull calls diagnose unknown or
duplicate labels before missing fields. These errors occur during compilation,
before any program output or file effects. Direct calls to returned constructors
from R continue to use R's argument matching and missing-argument messages.

## Record constructor defaults

Record scalar fields support the same literal defaults as class scalar fields.
For example, record Point { x: Number = 0 } permits Point() and Point(x: 3).
Defaults are type-checked without execution. Required fields, including nested
record-valued fields, still need explicit arguments. Returned constructor functions
expose these defaults to R callers. The record-state.rsspps example now constructs
its origin with Point(). Computed expressions and constructor calls in defaults
remain unsupported.

## Record methods

Records support read-only receiver methods returning values, including copied records.
The methods.rsspps example is installed with the package. R callers can invoke methods
through returned language wrapper functions; records do not expose native R dollar
methods. See [record methods](record-methods.md) for scope and validation limits.

## Package development

DESCRIPTION, NAMESPACE, and man/ provide package metadata, exports, and API help.
The full MIT license is preserved in LICENSE.md; LICENSE contains R's standard
MIT stub. Maintainer metadata uses the existing repository commit identity.
inst/examples/ is the canonical home of packaged source examples and data.
Repository docs, progress logs, demo runners, and generated output are excluded
from the source-package payload using .Rbuildignore.

Reinstall after changing R/ and run Rscript tests/run.R against that installation.
Tests include internal compiler cases and public file-API cases. R CMD build .
and R CMD check --no-manual RStarStar_0.0.26.tar.gz validate the package, installed
help, examples, and tests. Use the current version in the archive name. Chart
rendering tests report skips when Cairo is unavailable. --no-manual omits PDF
manual generation only. See [Contributing](../CONTRIBUTING.md) for commands.

## Interoperability still to implement

The package already lets existing R code compile .rsspps files, and generated R
runs with ordinary R tooling. Broader interoperability remains a goal:

- An explicit bridge for .rsspps programs to call existing R functions, packages,
  and project APIs. Import/call syntax and supported conversions are undecided;
  arbitrary R calls are currently rejected by the language.
- Tested contracts for references, mutation, ownership, and cross-language errors.
  No deep-immutability guarantee across arbitrary R objects is implied.

.R files continue to be handled by R; they are not RStarStar compiler inputs.
Compiler internals remain private rather than automatically exposed as project
APIs. Compilation must not load or execute an interoperability dependency.
