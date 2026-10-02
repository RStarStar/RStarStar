# Progress

Record each significant implementation change here, including its scope,
verification, and remaining limitations. Keep earlier entries as a history;
correct inaccurate claims explicitly. Dates use the project's local calendar.

## 2026-10-01 — First end-to-end compiler

Implemented in R/transpile.R, using only base R:

- A tokenizer for names, finite numeric literals, escaped text, booleans,
  punctuation, comments, and newlines, with source locations.
- A recursive-descent parser with an AST and source spans for bindings, mut,
  printing, vectors, grouping, unary signs, and arithmetic precedence.
- Semantic analysis for declaration order, immutable reassignment, duplicate
  declarations, stable mutable element types, numeric arithmetic, homogeneous
  vectors, and equal-length/scalar vector operations.
- Readable R generation through transpile(source, filename), returning a string.
  Compilation does not evaluate source or require runtime helpers.
- Structured rstarstar_error conditions with filename, line, and column.
- A runnable example and a dependency-free behavioral test runner.

Verification: Rscript tests/run.R passed all 37 checks on R 4.6.0,
aarch64-apple-darwin24.6.0. Checks include generated-code execution, rejection
cases, source spans, escaping, no execution during compilation, and independent
compilation environments.

Rscript examples/demo.R also passed: adjusted scores were 77, 90, 96, 73 and
the mutable threshold became 75. Documentation verification covered nine
Markdown files and 22 relative links; link, code-fence, and whitespace checks
passed. AGENTS.md now requires this log for significant implementation changes.

Design choices for this subset are recorded in docs/design-decisions.md and
its grammar and limits in docs/implemented-subset.md. No package install or CLI
is introduced. The example uses .txt; this is not a language extension decision.

Remaining: CSV operations, comparisons and conditions, missing-data policy,
functions, indexing, OOP, interfaces, R-package interoperability, and a broader
supported-R-version matrix. Arithmetic currently retains R's Inf/NaN behavior;
this is not a complete missing-value design. No performance guarantees yet.


## 2026-10-01 — CSV loading

Implemented read "sales.csv" into sales, mutable read targets, and optional
with delimiter syntax. Added a Table type with existing mutation protections,
plus an embedded standalone CSV loader. Compilation does not access files.

The loader supports UTF-8 (including BOM), quoted delimiters and multiline fields,
whole-column numeric/boolean/text inference, and preserved missing values. It
rejects malformed row widths, quoting, invalid headers/encoding, missing files,
and numeric overflow with errors pointing to the original read statement.

Added tests/csv.R and an example dataset/program under examples/. Updated the
language guide, exact subset, design record, architecture, and milestone 3 status.
Filtering, column access, summaries, charts, and OOP remain unimplemented. CSV
schemas and configurable missing markers are not available; files load into memory.

Verification: Rscript tests/run.R passed all 57 checks (37 existing and 20 CSV
checks) on the local R 4.6.0 environment. Both Rscript examples/demo.R and
Rscript examples/read-csv.R passed. The CSV demo retained all three rows and
preserved West's missing revenue as NA.


## 2026-10-01 — Column access and filtering

Added exact table.column and table."quoted header" access, filter/where/into,
mutable filter targets, and explicit skipping missing. Bare predicate names mean
columns; @name means a declared variable. Added comparisons, and/or/not, and
is [not] missing with documented precedence and elementwise behavior.

Extended semantic analysis for unknown CSV types/lengths and embedded runtime
checks for data expressions, vector construction, filters, and stable mutable
types. No file reads or source execution occur during compilation. Ordinary
programs without reads retain direct R expressions. Filtering preserves table
shape/types and input aliases; it resets displayed row numbers.

Added tests/filter.R and examples/filter.R with a readable source example.
Updated the guide, grammar, design record, architecture, and roadmap. Existing
error tests now use non-keyword names/symbols because missing and @ gained syntax.
Summaries, charts, schemas, indexing, functions, and OOP remain future work.

Verification: Rscript tests/run.R passed all 79 checks (57 previous and 22 new)
on the local R 4.6.0 environment. The basic, CSV, and filter demos all passed.
The filter demo selected North with revenue 120 and separately retained West's
missing-revenue row for review. Checked nine Markdown files and 23 relative
links, balanced code fences, code/example whitespace, and git diff --check.


## 2026-10-01 — Scalar summaries and PNG charts

Implemented average(...), sum(...), count(...), explicit skipping missing, and
plot table x column y column as bar to "output.png". Summaries document empty,
missing, nonfinite, and table-count behavior. Chart validation rejects missing
values, duplicate labels, nonnumeric heights, empty input, and existing output.
Generated programs embed required helpers and use R's bundled graphics packages;
transpilation still performs no input reads, image writes, or execution.

Added tests/summary-chart.R and a CSV-to-filter-to-summary-to-chart example in
examples/workflow.R and examples/workflow.txt. Marked roadmap milestone 3's initial
version complete. Grouping, schemas, chart configuration, functions, and OOP
remain future work. PNG rendering requires Cairo support in the installed R.

Verification: all 94 behavioral checks passed on local R 4.6.0, including PNG
signature/dimension checks and output protection. The workflow produced average
102.5, sum 205, and row count 2. Its 1200-by-800 PNG was visually inspected: North
and South bars, values, title, and axes rendered correctly. The sandbox emitted
Fontconfig cache-directory warnings during rendering; images were generated and
verified despite those warnings.

The three earlier demos also passed. Documentation verification covered nine
Markdown files and 23 local links; code-fence, whitespace, and git diff checks
passed.


## 2026-10-01 — Grouped summaries

Implemented summarize table by key with named average/sum/count results into a
target table. Supports one grouping key, multiple outputs, per-output missing
policies, quoted input headers, and ordinary mutable/immutable target rules.
Grouping preserves key types and first-seen order, including missing-key groups.
Empty output retains its schema; invalid columns/types still fail. The runtime
reuses scalar summary checks instead of silently dropping incomplete values.

Added tests/grouped.R and examples/grouped.R with a repeated-category dataset.
Updated guides, grammar, architecture, roadmap, and the duplicate-chart-label
error. Multi-key grouping, arbitrary grouped expressions, schemas, functions,
and OOP remain future work.

Verification: Rscript tests/run.R passed all 105 checks (94 existing and 11 new),
including grouped-output filtering and PNG chart generation. The existing sandbox
Fontconfig cache warnings remain nonfatal. Rscript examples/grouped.R passed:
South totals 40 and North totals 20, each with two source rows; filtering the
result retains South. Checked nine Markdown files, 23 local links, code fences,
and git diff --check successfully.


## 2026-10-01 — Multiple grouping columns

Extended summarize to accept comma-separated grouping columns. Groups use typed
per-column matches and collision-free integer combinations rather than joining
raw text keys. Preserves first-seen combinations, key order/types, missing-key
combinations, and zero-row schemas. Duplicate keys and output/key name collisions
fail before execution; unknown keys fail at runtime even for empty input.

Added seven behavioral checks and extended the grouped example with region/product
combinations and a second aggregation back to region totals. Updated the guide,
grammar, architecture, design decisions, roadmap, and README. Grouped expressions,
combined chart labels, schemas, functions, and OOP remain unimplemented.

Verification: Rscript tests/run.R completed successfully with all 112 checks
passing (105 existing and seven new), including single-key regressions and chart
checks. The grouped demo produced four region/product combinations and rolled
them back up to South = 40 and North = 20. All nine Markdown files, 23 relative
links, code fences, and git diff whitespace checks passed.


## 2026-10-01 — Initial user-defined functions

Implemented fn declarations with parameters, one return expression, and positional
calls to previously declared functions. Added independent parameter scopes,
immutable function names, eager argument evaluation, and body errors with call
locations. Functions operate on vectors/tables and work in filter predicates.
Runtime type/length/mutation checks apply even in programs without CSV reads.
Isolated generated runtime and CSV helper environments from user function names.

Added tests/functions.R, examples/functions.R, and examples/functions.txt. Updated
the grammar, guide, architecture, design record, README, and roadmap. Captures,
recursion, first-class functions, annotations, named/default arguments, multiple
body statements, and OOP remain unsupported.

Verification: all 128 checks passed (112 previous and 16 new). Tests include
function composition, table inputs, eager unused arguments, call chains, static
scope/arity errors, runtime type/length errors, and helper-name isolation.
The functions demo returned 11/22, mean revenue 102.5, and North's selected row;
the original demo also passed. All nine Markdown files, 23 relative links,
code fences, and git diff whitespace checks passed.


## 2026-10-01 — R package distribution direction

Recorded the user's decision to distribute RStarStar as an R package used from
an R session, rather than a public CLI. Added docs/r-package.md and updated the
README, contributor/agent guidance, architecture, implementation guide, design
record, and roadmap. Package work is now the next planned milestone; existing
Rscript examples remain developer tools.

Documentation-only change: no package metadata, installation, publication, or
compiler behavior changed. The current sourceable API still works as before.
Verification is limited to documentation links, fences, and whitespace checks;
the compiler test suite was not rerun for this documentation-only change.
All 10 Markdown files and 31 relative links passed validation, along with
code-fence and git diff whitespace checks.


## 2026-10-01 — .rsspps source API and interoperability direction

Recorded .rsspps as the required source format for the planned public package API.
The file-based API supersedes the previous public raw-string API plan; the existing
string compiler will become internal. Documented interoperability goals for R
callers, RStarStar programs, existing R packages/tooling, and project APIs, while
keeping compiler internals private and compilation separate from execution.

Updated package plan, README, agent/contributor guidance, implemented-subset status,
architecture, roadmap, and design decisions. This is documentation only: no file
validation, fixture renaming, package installation, or R-call bridge was implemented.
The current prototype behavior remains unchanged.

Verification: all 10 Markdown files, 32 relative links, code fences, and git diff
whitespace checks passed. No compiler tests were needed for this documentation change.


## 2026-10-01 — Installable package and .rsspps public API

Added package metadata, NAMESPACE, installed help, and a sole public transpile(path)
export. The string compiler is now internal rss_compile(). The public API reads
one local UTF-8 .rsspps file, rejects other inputs and invalid text, preserves
source locations, and does not run the program or access its datasets.

Moved canonical language examples/data to inst/examples/ and changed source files
to .rsspps. Developer runners now use the installed package. Tests run against its
namespace under both Rscript and R CMD check; added 12 public API/package cases.
Chart rendering tests explicitly skip without Cairo. The full MIT license remains
in LICENSE.md, with a standard package license stub in LICENSE. Maintainer metadata
uses the repository's existing Git author identity. R >= 4.1.0 is declared, with
only local R 4.6.0 verified so far. No CRAN publication or interoperability bridge.

Initial package validation: clean source build, installation, and R CMD check
--no-manual succeeded with Status: OK after fixing license metadata and explicitly
qualifying utils::file_test. Network-restricted dependency checks were rerun with
approved access.

Final verification: built the source archive, installed it in a fresh temporary
library, and passed 140 checks with zero skips. R CMD check --no-manual reported
Status: OK (zero errors, warnings, or notes), including installed help examples
and tests. All six developer demos ran against the fresh installation; the full
workflow saved its chart successfully. Installation did not modify the user's
default R library. PDF manual generation and other R/platform versions were not
tested. A final source-example comment correction does not change program behavior.
Rebuilt the archive after that comment correction. All 11 Markdown files,
33 local links, code fences, and git diff whitespace checks passed.


## 2026-10-02 — Explicit file execution and R result transfer

Added exported run_file(path) in version 0.0.2. It reuses the .rsspps-only UTF-8
source contract, compiles the whole file before execution, and returns final
variables/functions as a named list from a fresh base-parent environment. Compiler
helpers are excluded; empty/print-only programs return empty lists. Returned
functions retain runtime checks and can be called by R code. Added installed API
help, an R caller demo, and updated the package guide, language guide, decisions,
architecture, roadmap, and contributor/agent instructions.

Execution preserves the caller's working directory; relative data/output paths
resolve there. Console/file effects are explicit and are not rolled back after a
runtime failure. Compilation remains execution-free. No caller-binding injection,
external R-call bridge, object system, or deep-immutability guarantee was added.

Verification: reinstalled into a temporary library; 149 behavioral checks passed
with zero skips, including nine new execution cases and Cairo chart coverage.
The basic demo and new returned-function/table demo passed. Source build succeeded;
R CMD check --no-manual reported Status: OK, with zero errors, warnings, or notes.
Reran dependency checking with approved network access after sandbox index access
failed. Tests caught and resolved empty-result list attributes and two test-fixture
issues before final validation. Validation used R 4.6.0/macOS arm64; other platforms
and PDF manual generation remain unverified. Documentation links, code fences,
and git diff whitespace checks passed.


## 2026-10-02 — Contributor package-check automation

Added a GitHub Actions workflow for pushes, pull requests, and manual dispatch.
The configured matrix targets R release on Linux/macOS/Windows and exactly R 4.1.0
on Ubuntu 22.04. Jobs use read-only repository permissions, cancel superseded runs,
and retain available package-check logs for 14 days. No publication is performed.

Added a shared base-R developer runner at .github/scripts/check.R. It installs
into a temporary library before tests, runs the behavioral suite and all developer
demos, builds the version read from DESCRIPTION, and requires R CMD check
--no-manual to report Status: OK. Cairo-dependent demo execution explicitly skips
without Cairo; behavioral tests retain their existing skip reporting. Temporary
libraries/chart output are cleaned up. Excluded .github from the source package
and updated contribution instructions, README, package guide, and roadmap.
No public API, language rules, or package dependencies changed.

Verification: the shared runner passed locally on R 4.6.0/macOS arm64 with 149
checks, zero skips, all seven demos, and a successful build/check. After sandbox
network restrictions blocked dependency indexes, an approved network-enabled
R CMD check rerun finished Status: OK (zero errors, warnings, or notes). A temporary
copy with an intentionally failing test verified a nonzero runner exit before
building. Workflow YAML parsed with four matrix entries; documentation links,
code fences, whitespace, and exclusion of .github from the archive were checked.
Hosted jobs have not run; Linux, Windows, and R 4.1.0 compatibility remain
unverified. actionlint was unavailable, so validation covered YAML parsing and
local runner execution rather than full GitHub expression linting. PDF manuals
remain outside these checks.


## 2026-10-02 — CSV export of analysis results

Added write table to "output.csv" in version 0.0.3, reserving the write keyword.
Parsing checks the table/path syntax, analysis checks known table types, and
standalone generated R embeds runtime export checks. Execution uses UTF-8 CSV
with quoted text/headers, doubled quotes, LF endings, no row names, and empty
missing fields. Header-only tables are supported. Existing destinations and
missing parent directories are rejected with source-located errors. A temporary
file is cleaned up after writing; compilation performs no destination I/O.

Updated the language/package guides, README workflow, architecture, decision
record, roadmap, and installed help. Export deliberately has no append, overwrite,
or delimiter options. CSV inference can change types on re-read, and standard
numeric formatting is not exact serialization. Publication is not guaranteed
atomic; no rollback or crash-recovery guarantee was added.

Verification: the shared check runner reinstalled the package in a temporary
library, passed 156 behavioral checks with zero skips, ran all seven demos, and
built/checked version 0.0.3. Seven new checks cover values/missing data, Unicode
and escaping, grouped/header-only output, source failures, overwrite and path
errors, execution-only effects, and dynamic type failures. A test expectation
was adjusted for base R read.csv inferring integer output, without changing the
compiler's numeric behavior. The network-enabled check rerun after sandbox index
failures finished Status: OK (zero errors, warnings, or notes). Documentation
links, fences, and git diff whitespace checks passed. Validation remains local
R 4.6.0/macOS arm64; the hosted matrix and PDF manual remain unverified.
