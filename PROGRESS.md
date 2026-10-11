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


## 2026-10-02 — Lazy conditional expressions

Added if condition then value else fallback in version 0.0.4. Conditions require
one nonmissing boolean, checked statically where possible and at runtime otherwise.
Both branches are analyzed, but only the chosen branch executes. Branches can
return different types/lengths; inference retains matching information and runtime
checks protect surrounding operations and mutable bindings. Generated R uses
native if and an embedded source-located condition validator.

Updated language/reference guides, decisions, architecture, roadmap, README,
installed package help, and the packaged functions example with safe_average().
if, then, and else are newly reserved; the earlier R-keyword binding test now uses
repeat instead of if. This is an intentional syntax compatibility change. Statement
blocks, loops, records, classes, and the external R bridge remain unimplemented.

Verification: reinstalled through the shared runner and passed 165 behavioral
checks with zero skips, including nine new conditional cases. Coverage includes
nesting, precedence, lazy branches, static errors in unused branches, invalid
conditions, safe empty-input handling, dynamic types/lengths, mutable updates,
filter scope, and callable functions returned by the file API. All seven demos
and source build passed. After sandbox dependency-index access failed, the
network-enabled R CMD check --no-manual rerun reported Status: OK (zero errors,
warnings, or notes). Documentation links, fences, and whitespace checks passed.
Validation remains R 4.6.0/macOS arm64; hosted CI and PDF manuals remain unverified.


## 2026-10-02 — Named function arguments

Added name: value arguments for user-defined function calls in version 0.0.5.
Names match exactly and case-sensitively. Positional arguments precede named ones;
every declared parameter must be supplied exactly once. Compilation rejects
unknown/partial names, duplicates, positional/named collisions, wrong arity, and
positional arguments following named ones. Labels and source tokens are retained
in the AST; generated named lists preserve eager source-order evaluation through
the existing call helper.

Updated the function guide/reference, design decisions, architecture, roadmap,
README, package version references, and packaged functions example. Built-in
summaries keep their existing syntax. Defaults, annotations, record constructors,
and the R-call bridge remain unimplemented; returned R closures still use R's
ordinary calling conventions when invoked directly from R.

Verification: the shared runner reinstalled the changed package, passed 174 checks
with zero skips, ran all seven demos, and built/checked the source archive. Nine
new checks cover reordering, mixed calls, nested expressions, matching failures,
source-order errors, table/filter scope, call chains, quoted R-keyword parameter
names, and public/standalone execution. After sandbox dependency-index requests
failed, a network-enabled R CMD check --no-manual rerun finished Status: OK with
zero errors, warnings, or notes. Documentation links, fences, and git diff
whitespace passed. Local validation used R 4.6.0/macOS arm64; hosted CI and PDF
manual generation remain unverified.


## 2026-10-02 — Initial records and generated constructors

Added records with required scalar Number, Text, and Boolean fields in version
0.0.6. The record keyword is reserved. Generated constructors reuse positional
and exact named arguments; field names/types participate in semantic analysis and
dynamic inputs are checked at construction. Fields support exact public reads but
no assignment. Functions can construct, accept, and return records. Mutable bindings
permit replacement only with the same declared record type; aliases retain their
original values.

Records are ordinary named R lists with an internal nominal-type attribute and
base list printing, without a class dispatch backend or new dependencies. The
constructor boundary rejects nested, attributed, and reference values. Missing
scalars of the declared type remain valid. Returned R lists can be modified by R
callers; no external deep-immutability guarantee is claimed. Equality, with updates,
nesting, vector/table fields, Integer annotations, defaults, validation blocks,
and classes remain deferred. Undefined whole-record operations fail explicitly.

Added packaged records.rsspps and a records.R demo, included it in the shared check
runner, and updated guides, decisions, architecture, roadmap, README, package help,
and version references. Preserved the preceding named-argument changes already
in the working tree.

Verification: reinstalled through the shared runner; 187 behavioral checks passed
with zero skips, including 13 record cases covering schemas, constructor arguments,
dynamic checks, function scope, field lookup, aliases, nominal mutation, typed
missing values, unsupported operations, and public/standalone/R boundaries. All
eight demos passed and the source archive built successfully. Initial checking
caught an unqualified setNames call; replacing it with base R name assignment
removed the note without adding a dependency. The final network-enabled R CMD
check --no-manual reported Status: OK (zero errors, warnings, or notes), following
sandbox dependency-index failures. Documentation links, fences, and whitespace
checks passed. Validation remains local R 4.6.0/macOS arm64; hosted CI and PDF
manual generation remain unverified.


## 2026-10-02 — Record copy updates

Added receiver with { field: value, ... } in version 0.0.7. The expression creates
a validated record of the same nominal type, preserving unspecified fields and
declaration order without changing the original or aliases. Known schemas are
checked during analysis; dynamic receivers and replacements receive runtime checks.
Field names must be unique and exact. Receiver/name validation precedes replacement
evaluation, which follows source order and reads the original surrounding scope.
Ordinary mut rules still govern rebinding.

Updates attach to primary expressions, can chain, and support comma-separated
fields with boundary newlines. AST spans cover the receiver and full update while
diagnostics retain update/field locations. Updated the record demo, guide/reference,
decisions, architecture, roadmap, README, and version references. Corrected a stale
reference-page list that still described all records as unimplemented. Nested
updates, record equality, classes, and foreign-reference guarantees remain deferred.

Verification: the shared runner reinstalled the package and passed 195 checks with
zero skips. Eight new cases cover original/alias preservation, simultaneous swaps,
chained and computed receivers, malformed and invalid updates, dynamic errors/call
chains, replacement order/lazy branches, public/standalone execution, and AST spans.
All eight demos and source build passed. Following sandbox dependency-index failures,
the network-enabled R CMD check --no-manual rerun reported Status: OK with zero
errors, warnings, or notes. Documentation links, fences, and git diff whitespace
passed. Validation remains local R 4.6.0/macOS arm64; hosted CI and PDF manuals
remain unverified.


## 2026-10-02 — Record equality

Added == and != for records of the same declared type in version 0.0.8. Equality
compares corresponding scalar fields and returns one Boolean: a definite mismatch
wins over missing comparisons; otherwise any missing comparison yields missing;
all matching comparisons yield true. Inequality negates that result. Different
nominal types, record/scalar comparisons, and ordering remain errors. Numeric
fields retain exact scalar equality, without a tolerance.

Static analysis allows compatible record equality and preserves incompatible-type
errors. The embedded runtime handles dynamic values, checks layouts/plain scalar
fields, and retains comparison locations and function call chains. No R class
operator methods or dependencies were added. Updated record examples, reference
and language guides, design decisions, architecture, roadmap, README, and version
references. Nested record equality and broader foreign-object guarantees remain
outside the implemented subset.

Verification: reinstalled through the shared runner; 203 behavioral checks passed
with zero skips, including eight new equality cases. Coverage includes every field
type, construction order, missing-value combinations, nominal incompatibility,
ordering rejection, conditional use, source diagnostics, malformed R inputs, and
public/standalone execution. Corrected a test's expected comparison column from 24
to 26 during verification. All eight demos and source build passed. After sandbox
dependency-index failures, the network-enabled R CMD check --no-manual rerun
reported Status: OK with zero errors, warnings, or notes. Documentation links,
fences, and git diff whitespace checks passed. Validation remains local
R 4.6.0/macOS arm64; hosted CI and PDF manual generation remain unverified.


## 2026-10-02 — Field access on expression results

Added direct .field and ."header" access on constructor/function calls, updates,
parenthesized expressions, and explicit @variables in version 0.0.9. Postfix
operations compose left to right, retain complete source spans, and generate one
receiver expression. Known record schemas inform analysis; dynamic lookups use
the existing exact runtime field helper with source-located errors.

Preserved explicit table.column lookup, filter scope rules, and grouped-summary
input restrictions. Updated guides, decisions, architecture, roadmap, README,
version references, and packaged records demo. Nested records, indexing, methods,
field assignment, and callable field values remain unimplemented.

Verification: the shared runner reinstalled the package and passed 211 checks with
zero skips. Eight new cases cover constructor/function results, updates and
conditionals, returned tables/quoted headers, filter scope, malformed or invalid
access, lazy receivers/call errors, AST spans, and public/standalone execution.
All eight demos and source build passed. After sandbox dependency-index failures,
the network-enabled R CMD check --no-manual rerun reported Status: OK with zero
errors, warnings, or notes. Documentation links, fences, and git diff whitespace
checks passed. Validation remains local R 4.6.0/macOS arm64; hosted CI and PDF
manual generation remain unverified.


## 2026-10-02 — Nested records

Added earlier-declared record types as field annotations in version 0.0.10. Nested
fields retain exact nominal types through constructors, chained access, explicit
inner with updates, and recursive equality. Unknown, forward, self-recursive, and
mutually recursive schemas are rejected. Number/Text/Boolean cannot be record
declaration names because they denote primitive field types; ordinary bindings
with those names remain allowed.

Runtime construction recursively accepts supported scalar/record trees and rejects
reference-bearing or attributed nested inputs. Updates preserve inner, outer, and
sibling aliases; equality retains the existing three-valued rules recursively.
The tagged-list R boundary remains experimental, without full schema provenance
validation for arbitrary forged/modified R objects or external deep immutability.
Recursive schemas, vector/table fields, dotted replacement labels, and classes
remain future work. Updated record examples, installed package help, guides,
architecture, decisions, roadmap, README, and version references.

Verification: the shared runner reinstalled the package and passed 218 checks with
zero skips. Seven new cases cover construction/access, invalid schemas, nominal
field types, nested copy independence, function/update errors, recursive missing
value equality, three-level records, and public/standalone/R boundaries. All eight
demos and source build passed. Following sandbox dependency-index failures, a
network-enabled R CMD check --no-manual rerun reported Status: OK with zero errors,
warnings, or notes. Documentation links, fences, and git diff whitespace checks
passed. Validation remains local R 4.6.0/macOS arm64; hosted CI and PDF manual
generation remain unverified.


## 2026-10-02 — Bundled standard-library direction

Recorded the user's plan to eventually ship a standard library inside the RStarStar
R package. Updated README, package guide, language guide, roadmap, and decision
record. Library contents, access syntax, implementation format, compatibility, and
generated-R integration remain future design work. Existing built-ins and internal
runtime helpers are not declared a stable standard-library API.

Documentation only: no implementation, exports, dependencies, version, or execution
behavior changed. Verified relative Markdown links, balanced code fences, example
consistency, and git diff whitespace. Package tests/build/check were not rerun for
this documentation-only change.


## 2026-10-03 — Standard-library first-slice proposal

Added docs/standard-library.md with a concrete proposal for two numeric operations,
qualified access syntax, exact argument matching, scalar/vector/empty/missing and
nonfinite-value behavior, useful failures, and standalone generated-code integration.
Included alternatives and an implementation/verification checklist. Linked the
proposal from README, package/language guides, roadmap, and decision record.

The proposal is explicitly unaccepted and unimplemented. No language syntax,
exports, dependencies, compiler code, or package version changed; all standard-library
implementation roadmap items remain pending. Verified relative documentation links,
code fences, example status/consistency, and git diff whitespace. No package tests
or build/check were rerun for this documentation-only change.

## 2026-10-03 — Bundled numeric standard library (0.0.11)

Implemented the first slice following the proposal: std::absolute(values) and
std::square_root(values), with exactly one positional or exact named argument.
Added namespace parsing and source spans, static name/arity/type checks, and runtime
validation of attribute-free integer/double inputs. Operations preserve lengths,
empty numeric vectors, NA/NaN, and positive infinity; square_root rejects all
nonmissing negative inputs before computing. Errors retain source locations and
language function call chains. Existing bindings named std and user functions
named absolute remain usable.

A private catalog holds quoted implementations. Generated R embeds only used
operations and shared checks in an isolated base-only environment; compilation
never evaluates their bodies. run_file() hides the helper binding. Added focused
behavioral/API tests, an installed source example, a developer demo, and R help.
Updated the guide, implemented subset, package plan, decisions, and roadmap.
No dependencies or public R exports were added.

Verification: the shared runner reinstalled the package, passed 226 checks with
0 skips, ran all nine demos including Cairo chart output, built
RStarStar_0.0.11.tar.gz, and finished R CMD check --no-manual with Status: OK.
The sandbox blocked dependency-index access; a network-enabled check rerun also
finished with Status: OK. Checked relative Markdown links, balanced code fences,
example consistency, and git diff whitespace.

Limits: the library API remains experimental and contains only these two numeric
operations. No imports, first-class library values, external R-call bridge, or
class/method backend is introduced. Hosted CI, other R versions/platforms, and PDF
manual generation remain unverified.

## 2026-10-03 — Standard-library text length (0.0.12)

Added std::text_length(values) for character-count validation of text, including
CSV code columns. It accepts one plain Text scalar/vector with an optional exact
values: label and returns Number counts of the same length. Empty strings count
as zero; missing values and empty vectors are preserved. UTF-8 counts use Unicode
code points, not bytes, display widths, or grapheme clusters. No normalization or
implicit coercion occurs. Invalid/byte-encoded text and attributed R inputs fail
with source-located diagnostics. The catalog now declares input types for static
checks; numeric operation behavior is preserved.

Extended the packaged standard-library example and demo, installed R help,
behavioral tests, guides, decision record, and roadmap. Covered Unicode combining
characters and emoji, static/dynamic type errors, exact arguments, filter scope,
missing CSV values, empty vectors, R-boundary validation, call chains, once-only
evaluation, and standalone generated R. No dependencies or public exports added.

Verification: the shared runner reinstalled the package, passed 232 checks with
0 skips, ran all nine demos (including Cairo output), built the 0.0.12 source
archive, and completed R CMD check --no-manual with Status: OK. After sandbox
access failures for dependency indexes, the network-enabled final check also
reported Status: OK. Verified 56 local Markdown links across 12 files, balanced
code fences, example consistency, and git diff whitespace.

Limits: CSV schema inference is unchanged; numeric-only codes need future explicit
schema support to remain Text, and empty CSV cells are missing. The library remains
experimental. Hosted CI, other R versions/platforms, and PDF manual generation
remain unverified; no external R-call bridge or class backend was added.

## 2026-10-03 — Standard-library text trimming (0.0.13)

Added std::trim_text(values) for cleaning text before comparisons and length checks.
It removes boundary spaces, tabs, carriage returns, and newlines from plain Text
scalars/vectors. Internal spacing and other Unicode whitespace are preserved.
Missing values and empty vectors remain unchanged; strings containing only the
specified whitespace become empty strings. Inputs are not mutated. Exact arguments,
encoding validation, R-boundary attribute rejection, and source-located errors
follow the existing library contract.

Added catalog output-type metadata so analysis correctly retains Text results for
binding, arithmetic, comparison, and record checks. Extended behavioral tests,
packaged examples, demo assertions, installed help, guides, decisions, and roadmap.
Preserved the existing text-length work in the working tree. No dependencies,
public exports, or implicit conversions were introduced.

Verification: reinstalled through the shared runner; 237 checks passed with 0 skips.
All nine demos passed, including Cairo rendering. Built RStarStar_0.0.13.tar.gz;
R CMD check --no-manual reported Status: OK. A network-enabled rerun after sandbox
dependency-index access failures also reported Status: OK. Checked 57 local links
across 12 Markdown files, balanced code fences, examples, and git diff whitespace.

Limits: nonbreaking spaces and other Unicode whitespace are intentionally retained.
Filtering with trimmed text does not rewrite the original table values. CSV type
inference and missing-cell behavior remain unchanged. The library is experimental;
hosted CI, other R versions/platforms, and PDF manual generation remain unverified.

## 2026-10-03 — Optional CSV column types (0.0.14)

Added read ... with columns {code: Text, amount: Number} to preserve identifiers
and validate selected columns. Supports exact bare/quoted headers, multiline
comma-separated declarations, and combination with delimiter in either order.
Each option appears at most once. Other columns retain inference. Declared Text
preserves leading zeros; declared Number/Boolean retain types even on empty or
all-missing inputs. Existing missing markers and strict conversion formats apply.
Unknown headers and invalid values fail during execution with source location,
column, and data-row diagnostics; compilation still never opens the dataset.

Generated R embeds the schema independently of R argument matching, including
headers named recursive or use.names. Added regression coverage for these names,
partial schemas, mutable reloads, malformed declarations, invalid data, typed empty
columns, file APIs, and standalone execution. Extended the packaged CSV demo with
an identifier fixture and updated guides, installed help, decisions, and roadmap.
Preserved the earlier standard-library work in the working tree.

Verification: the final shared runner reinstalled the package, passed 245 checks
with 0 skips, ran all nine demos including Cairo rendering, built the 0.0.14 archive,
and completed R CMD check --no-manual with Status: OK. A network-enabled rerun
after sandbox dependency-index failures also reported Status: OK. Checked 59 local links across
12 Markdown files, balanced code fences, example consistency, and git diff whitespace.

Limits: declared types affect loading, not static table-column inference or later
mutable reloads. Missing markers remain fixed, including quoted empty/NA fields;
no date types, required columns, schema objects, dependencies, or exports added.
Hosted CI, other R versions/platforms, and PDF manual generation remain unverified.

## 2026-10-06 — Configurable CSV missing markers (0.0.15)

Added with missing ["", "N/A"] to read. The list explicitly replaces the default
empty-string/NA markers for one read; [] disables marker recognition. Matching is
exact and case-sensitive after CSV unquoting and line-ending normalization, before
inference or declared conversion. Quoted fields follow the same rules. Each option
may appear once, in any order with delimiter and columns. Markers are unique text
literals; general empty vector expressions remain unsupported.

Added behavioral checks for custom/default replacement, preserved literal NA and
empty strings, typed conversion failures, inference, quoted and multiline fields,
mutable reloads, invalid options, public file APIs, and standalone output. Extended
the packaged CSV example and demo with a missing-code fixture. Updated guides,
installed help, decisions, and roadmap. Existing unrelated .DS_Store files were
left untouched. No dependencies or public exports added.

Verification: the shared runner reinstalled the package, passed 251 checks with
0 skips, ran all nine demos including Cairo rendering, built RStarStar_0.0.15.tar.gz,
and completed R CMD check --no-manual with Status: OK. A network-enabled rerun
after sandbox dependency-index failures also reported Status: OK. Checked 61 local Markdown
links across 12 files, balanced fences, example consistency, and git diff whitespace.

Limits: one missing policy applies to all data columns in a read. Marker expressions,
per-column policies, and quoted/unquoted distinctions are unsupported. Export still
writes missing fields as empty, so custom reading alone is not exact serialization.
Hosted CI, other R versions/platforms, and PDF manual generation remain unverified.

## 2026-10-06 — CSV export delimiters (0.0.16)

Added write ... with delimiter ";" with comma (default), semicolon, tab, and pipe
support. Delimiters must be quoted literals; unsupported separators and repeated
options fail compilation. Preserved UTF-8 text quoting, empty missing fields,
header-only output, temporary-file cleanup, and overwrite protection. Limited
export separators because R's writer leaves numbers and booleans unquoted, making
letters/digits and numeric punctuation unsafe delimiters.

Added checks for semicolon/tab/pipe round trips, embedded separators, quotes,
multiline and Unicode text, malformed delimiters, header-only tables, overwrite
protection, compile-without-write, and standalone generated execution. Added a
packaged csv-export.rsspps example and temporary-directory demo to the shared
runner. Updated guides, installed help, decisions, roadmap, and package version.

Verification: reinstalled through the shared runner; 255 checks passed with 0 skips.
All ten demos passed, including Cairo output and the new CSV export demo. Built
RStarStar_0.0.16.tar.gz; R CMD check --no-manual returned Status: OK. A network-enabled
rerun after sandbox dependency-index failures also returned Status: OK. Checked
61 local Markdown links across 12 files, code fences, examples, and diff whitespace.

Limits: .csv output suffix remains required even for tab/pipe output. Read requires
the matching delimiter explicitly. Custom export missing markers and append/overwrite
modes remain unsupported; CSV is not exact typed serialization. Hosted CI, other R
versions/platforms, and PDF manual generation remain unverified.

## 2026-10-06 — CSV export missing marker (0.0.17)

Added write ... with missing "N/A" to replace default empty missing fields with one
explicit marker. Write accepts a text literal, while read continues to accept a
marker list. Missing and delimiter options may appear once each, in either order.
Because R writes missing markers unquoted, compilation rejects the final delimiter,
quotes, and line breaks inside a marker. Existing defaults and file protections
remain intact.

Added checks for missing/empty/literal-NA distinctions with matching read options,
option ordering, explicit default markers, malformed/structurally invalid markers,
marker collision behavior, compile-without-write, standalone execution, and overwrite
protection. Updated the packaged export demo, installed help, guides, decisions,
and roadmap. Preserved the prior export-delimiter work in the working tree.
No dependencies or public exports added.

Verification: the shared runner reinstalled the package; 260 checks passed with
0 skips. All ten demos passed, including Cairo rendering and the revised export
demo. Built RStarStar_0.0.17.tar.gz and completed R CMD check --no-manual with
Status: OK. A network-enabled rerun after sandbox dependency-index failures also
returned Status: OK. Checked 61 local Markdown links across 12 files, balanced code fences,
example consistency, and git diff whitespace.

Limits: real values equal to a chosen read marker also become missing, even when
quoted; no marker collision detection or exact serialization guarantee is provided.
Numeric formatting and type inference retain their existing limits. Hosted CI,
other R versions/platforms, and PDF manual generation remain unverified.

## 2026-10-06 — Record-method design proposal

Returned to the approachable-objects roadmap with docs/record-methods.md. Proposed
methods declared after record fields, explicit self, one return expression, exact
arguments, and value-returning updates. Specified field/method collisions, receiver
and argument evaluation, declaration-order visibility, unknown-receiver dispatch,
source locations, generated helper isolation, and R interoperability limits.
Included successful/failing examples, alternatives, review points, and a future
implementation checklist. Linked it from README, guide, decisions, and roadmap.

This is a proposal, not accepted syntax or implemented method support. No compiler,
package API, version, dependency, or backend changes. Mutable classes and interfaces
remain unresolved. Verified 67 local links across 13 Markdown files, balanced fences,
example consistency with the proposed rules, and git diff whitespace. Package tests,
demos, build, and check were not rerun for this documentation-only change.

## 2026-10-06 — Value record methods (0.0.18)

Implemented the reviewed first-slice direction: fn methods after record fields,
explicit self, a single return expression, receiver calls, and exact positional/named
arguments. Methods return values and use with for copied updates. Receiver calls
compose with constructors, nested fields, and expression results. Fields/methods
share a unique member namespace. Methods see earlier functions, constructors, and
methods, but not outer data, themselves, later methods, or their current constructor.

Added static method signatures and fixed visible method IDs at each generated call
site. Unknown receivers dispatch at execution by nominal type among those candidates;
later declarations cannot expand an earlier function's lookup set. Receiver and
arguments evaluate once in source order. Runtime checks validate exact supported
receiver layouts, including nested fields, and shared argument matching avoids R's
partial matching. Method body errors retain source locations and enclosing call
chains. Private runtime registries hold ordinary R functions and schemas; record
values/equality and public result bindings remain unchanged.

Added 12 focused checks covering declarations/spans, copies/aliases, exact and dynamic
calls, visibility, evaluation order, invalid R layouts, filter scope, lazy bodies,
helper-name collisions, diagnostics, and standalone execution. Preserved existing
field-access diagnostics during the parser refactor. A filter test initially tried
to put a whole CSV column in a scalar field; corrected it to a vector predicate
method, retaining the existing field contract. Added packaged/developer examples,
installed help, architecture notes, and updated the contract, guides, and roadmap.

Verification: the final shared runner reinstalled the package, passed 272 checks
with 0 skips, ran all eleven demos including Cairo rendering and the method demo,
built RStarStar_0.0.18.tar.gz, and completed R CMD check --no-manual with Status: OK.
A network-enabled rerun after sandbox dependency-index failures also reported
Status: OK. Checked 70 local links across 13 Markdown files, balanced fences,
example consistency, and git diff whitespace.

Limits: no mut self, direct field writes, recursion, forward references, bound method
values, interfaces, or mutable class backend. Fields remain scalar or nested records.
R callers use returned language wrappers to invoke methods; no native dollar-method
interface or arbitrary-object provenance/deep-immutability guarantee. Hosted CI,
other R versions/platforms, and PDF manual generation remain unverified.

## 2026-10-07 — R6 compiler implementation

Refactored compiler internals into RSSCompiler plus RSSTokenizer, RSSParser,
RSSAnalyzer, and RSSGenerator, with separate R/ files for each stage. Cursors,
source context, semantic scopes, method visibility, and emission bookkeeping now
live in private R6 fields; grammar, inference, and expression-generation helpers
are private methods. Stage calls reset their state, and every compilation creates
fresh stages. Scope environments are allocated per analysis, and cloning is disabled.
Internal rss_* adapters preserve focused stage tests. Public exports remain
transpile(path) and run_file(path), with the same file-only source contract.

Moved unchanged standalone runtime functions to R/runtime.R. Generated record
values remain tagged lists, with existing copying, equality, and method behavior.
Generated R does not load or require R6. Added R6 as the compiler's sole dependency
outside R-bundled packages, including its namespace import, installation guidance,
and CI dependency setup. The shared check runner retains dependency libraries while
putting the freshly installed package first. Updated architecture, guide, dependency
policy, decision record, and roadmap; this is no source-language class backend choice.

Added six behavioral checks for repeated calls, separate instances, recovery after
lexer/parser/analyzer errors, cleared scopes and generator registries, execution
separation, and generated record/standard-library code running in a fresh R process
without loading R6 or RStarStar. Compared the previous and refactored compiler on
1,343 distinct test string literals and packaged example sources: 150 successful
outputs were byte-identical and 1,193 failures had identical diagnostic classes,
messages, filenames, and spans. The original 272 checks also passed unchanged.

Verification: the final shared runner reinstalled the package, passed 278 checks
with 0 skips, ran all eleven demos including Cairo rendering, built
RStarStar_0.0.18.tar.gz, and completed R CMD check --no-manual with Status: OK.
The first check exposed a missing explicit R6 namespace import; fixed it before
the successful final run. That first run also lacked dependency-index network
access; the final run had network access and no warnings or notes. Checked 70 local
links across 13 Markdown files, balanced fences, unchanged packaged example output,
and git diff whitespace.

Limits: R6 must be installed to use the compiler. Classes are internal implementation
details, with no new public API or language features. No performance improvement is
claimed. Hosted CI, other R versions/platforms, and PDF manual generation remain
unverified. Local verification used R 4.6.0 and R6 2.6.1 on macOS arm64.

## 2026-10-07 — Mutable-class design proposal

Added docs/mutable-classes.md with a concrete next OOP slice: private scalar fields,
explicit constructors, read-only methods, mut self assignment bodies, and standalone
calls on simple mutable bindings. Recommended value semantics and candidate-based
receiver replacement so aliases remain independent and failed methods do not commit
partial state. Defined evaluation order, field/binding permissions, effect restrictions,
source-located failures, dynamic dispatch boundaries, and R interoperability limits.

Separated the representation recommendation from the compiler's existing R6 usage;
no source-language backend is selected. Included alternatives, successful/failing
examples, and a future verification checklist. Linked the proposal from README,
guide, roadmap, and decision record; clarified that the older Counter sketch includes
defaults outside this proposed first slice.

Documentation only: no language implementation, package version, exports, dependencies,
or runtime behavior changed. Verified 77 local links across 14 Markdown files,
balanced code fences, example consistency with the proposed rules, and git diff
whitespace. Tests, demos, build, and package check were not rerun. The proposal still
needs adoption before implementation; classes remain unsupported in 0.0.18.

## 2026-10-07 — Scalar-field mutable classes (0.0.19)

Implemented the proposed first class slice: private scalar Number/Text/Boolean
fields, generated all-field constructors, read-only methods, and mut self methods
containing sequential self.field assignments. Mutating calls require a simple
named mut binding and a field declared mut. Added source spans and diagnostics for
permissions, private access, exact signatures, effects, and unsupported bodies.
class is now a reserved word.

Class values use a separate nominal list tag and private schema/permission/method
metadata. Receiver and arguments evaluate once in source order. Assignments update
a validated local candidate; only a completely successful method replaces the caller
binding. Aliases keep their values, and failed later assignments never commit partial
receiver state. Known receivers are checked statically; unknown receivers enforce
effects, layouts, and declaration-order method visibility at runtime. Generic field
access, record updates, comparisons, vector construction, and whole-object summaries
or missingness cannot bypass the class boundary. Generated programs remain R6-free.

Added fifteen behavioral checks alongside the previous 278, covering aliasing,
repeated/zero-argument calls, immutable fields, candidate visibility, atomic failures,
private access through dynamic receivers, static/runtime effects, exact signatures,
scope, nominal types, malformed R layouts, evaluation order (including dispatch
failure), spans, stage reuse, and fresh-process execution without R6/RStarStar.
Added packaged classes.rsspps and its developer demo; extended the shared check runner.
Updated package help, guide, implemented subset, architecture, class contract,
decision record, roadmap, README, and versioned build instructions.

Verification: the shared runner installed the current package, passed 293 checks
with 0 skips, ran all twelve demos including Cairo rendering, and built
RStarStar_0.0.19.tar.gz. The initial package check reported Status: OK but could not
access dependency indexes in the sandbox. Reran R CMD check --no-manual with network
access: Status: OK, with no warnings or notes; its installed-package suite also
passed all 293 checks. Verified 81 local links across 14 Markdown files, balanced
fences, example consistency, and git diff whitespace. Local environment: R 4.6.0
on macOS arm64.

Limits: fields are plain scalars only. No defaults, nested mutable state, general
statement bodies, mutable parameters, class equality, interfaces, inheritance, or
external R-call bridge. Privacy is source-level access control, not secrecy in R;
base printing and R callers can inspect returned lists. Failed calls protect the
receiver binding, not earlier program prints/files, and run_file returns no partial
results. Hosted CI, other R versions/platforms, and PDF manual generation remain
unverified.

## 2026-10-07 — Literal class-field defaults (0.0.20)

Continued the object milestone with scalar literal constructor defaults. Class
fields can declare defaults such as mut value: Number = 0, label: Text = "Counter",
and active: Boolean = true. Defaults accept singly signed numeric literals and
parenthesized literals; calls, variables, computed expressions, and vectors are
rejected. The analyzer checks default types even for unused declarations. Fields
without defaults remain required; exact named arguments can skip optional fields,
while positional arguments retain declaration order. Required and optional fields
may be interleaved. Explicit overrides retain normal type and scalar checks.

Generated constructors use R parameter defaults and preserve explicit argument
execution order. Each constructed value retains existing alias and mutation rules.
No user code executes during parsing or analysis. No public API, runtime dependency,
or CLI was added. The packaged class example now uses Counter(); returned R
constructors also expose defaults under ordinary R calling rules. Updated the guide,
class contract, implemented subset, architecture, decision record, roadmap, package
help, and current build instructions.

Added eight behavioral checks for scalar defaults, signs/escaping, overrides,
required/optional matching, duplicate/unknown/missing arguments, invalid declarations,
runtime input checks, source locations, aliasing, explicit argument evaluation order,
public file APIs, R callers, and independent generated execution without R6/RStarStar.

Verification: reinstalled through the shared check runner, passed all 301 checks
with 0 skips, ran all twelve demos including Cairo charts, built
RStarStar_0.0.20.tar.gz, and completed R CMD check --no-manual with Status: OK and
no warnings or notes. An earlier sandboxed validation could not reach dependency
indexes; the final validation had network access. Checked 81 relative Markdown links
and balanced fences across 12 Markdown files, example consistency, and git diff
whitespace. Local environment: R 4.6.0 on macOS arm64.

Limits: defaults are class scalar literals only. Computed defaults, record/function
defaults, nested mutable state, and custom constructors remain deferred. Existing
source-privacy and R interoperability limits remain unchanged. Hosted CI, other R
versions/platforms, and PDF manual generation were not verified.

## 2026-10-07 — Record-valued class state (0.0.21)

Continued the object milestone with private class fields typed as earlier records,
including acyclic nested record trees. A Tracker can hold a Point and replace it
through a constructor, with copy update, or read-only record method. The outer
field must be mutable for replacement; direct nested assignments and nested
mutable class fields remain unsupported. Record fields require explicit arguments;
scalar literal defaults from 0.0.20 remain unchanged.

Class construction and replacement now recursively validate declared record layouts,
not just tags or generic record shape. Receiver dispatch retains the same recursive
checks. Tests reject malformed nested fields and attributes from R callers. Record
and class aliases and returned snapshots retain their values; failed later mutation
assignments do not commit any candidate changes. Source privacy, nominal typing,
execution separation, and standalone generated R remain intact, with no new public
API or dependency.

Added the packaged record-state.rsspps example and developer demo, and included it
in the shared check runner. Added eight behavioral checks covering nested aliasing,
record methods, static and dynamic type failures, forward/recursive/class-valued
schema rejection, privacy and immutability, nested assignment rejection, failure
atomicity, source locations/call chains, malformed R layouts, public APIs, and
execution without R6/RStarStar. Updated current documentation, decision record,
roadmap, package help, and versioned build instructions. Preserved the preceding
uncommitted constructor-default work.

Verification: the final shared runner reinstalled 0.0.21, passed all 309 checks
with 0 skips, ran all thirteen demos including Cairo rendering, built
RStarStar_0.0.21.tar.gz, and completed R CMD check --no-manual with Status: OK and
no warnings or notes. Final package checking used network access for dependency
indexes. Verified 81 relative links and balanced fences across 12 Markdown files,
the twelve packaged examples, example consistency, and git diff whitespace.
Local verification used R 4.6.0 on macOS arm64.

Limits: record trees only, without class-valued fields, direct nested mutation,
record defaults, or computed defaults. R callers may still inspect/modify returned
lists; recursive validation does not establish provenance or promise arbitrary-R
reference safety. Hosted CI, other R versions/platforms, and PDF manual generation
remain unverified.

## 2026-10-07 — Scalar literal defaults for records (0.0.22)

Extended the existing class constructor-default rules to record scalar fields.
Point fields can declare x: Number = 0 and y: Number = 0 so Point() constructs
an origin and Point(y: 3) overrides one value. Fields without defaults remain
required, including nested record-valued fields. Exact argument matching, written
argument execution order, type checks, equality, methods, and copy updates retain
their existing rules. Defaults never restore fields during a with update.

A new test exposed that parenthesized literals, documented for class defaults,
were rejected by the parser. Fixed the shared literal check to ignore grouping
while retaining source spans. Parenthesized literals and singly signed numbers
now work for records and classes; computed expressions and repeated signs remain
rejected. No default source executes during compilation. No API or dependency was
added. The packaged tracker example now constructs its origin with Point().

Added seven behavioral checks covering scalar types, overrides, mixed required and
optional arguments, declaration errors and locations, nested records, copies,
equality, methods, runtime failures from R inputs, public file APIs, explicit
argument execution order, parenthesized literals, and independent generated
execution. Updated current documentation, decision record, roadmap, help, and
versioned build instructions. Preserved earlier uncommitted implementation work.

Verification: the first new suite caught the parenthesis mismatch above. After
fixing it, the final shared runner reinstalled 0.0.22, passed all 316 checks with
0 skips, ran all thirteen demos including Cairo rendering, built
RStarStar_0.0.22.tar.gz, and completed R CMD check --no-manual with Status: OK and
no warnings or notes. The final run used network access for dependency indexes,
which were unavailable in the earlier sandboxed run. Verified 81 relative links
and balanced fences across 12 Markdown files, example consistency, and git diff
whitespace. Local environment: R 4.6.0 on macOS arm64.

Limits: defaults remain scalar literals only. Computed expressions, defaults for
nested record-valued fields, and ordinary function/method parameter defaults are
unsupported. Hosted CI, other R versions/platforms, and PDF manuals remain unverified.

## 2026-10-11 — Recursive record validation at R boundaries (0.0.23)

Reproduced two gaps in the current implementation: a nested record constructor
accepted an R-modified Point whose Number field had become Text, and a copy update
accepted extra fields added by R. Nested construction checked generic record shape
rather than declared schemas; updates derived expected types from supplied values.

Record constructors now reuse the scalar/record validator used by classes, which
recursively validates registered schemas. Copy updates first validate the complete
receiver, then validate replacements using its declared schema. Invalid receivers
cannot be repaired implicitly by an update. Missing/extra/reordered fields, wrong
leaf types, unknown tags, and unsupported attributes are rejected at these boundaries.
Valid integer Number inputs, typed missing/nonfinite values, defaults, and alias
semantics remain unchanged. No syntax, export, or dependency was added.

Added five regression checks covering corrupted nested R inputs, invalid receivers,
replacement failures and unchanged originals, valid scalar/structural inputs,
source locations and call chains, public file APIs, and standalone R6-free output.
Updated documentation, decision record, roadmap, help, and build instructions.
The first test run identified incorrect expected line numbers in new assertions;
corrected those assertions before the final verification.

Verification: the final shared runner reinstalled 0.0.23, passed all 321 checks
with 0 skips, ran all thirteen demos including Cairo rendering, built
RStarStar_0.0.23.tar.gz, and completed R CMD check --no-manual with Status: OK and
no warnings or notes. Dependency-index checks had network access. Verified 81
relative links and balanced fences across 12 Markdown files, example consistency,
and git diff whitespace. Local environment: R 4.6.0 on macOS arm64.

Limits: matching manually tagged plain values can still be accepted; layout
validation is not provenance or deep immutability. Generic external field access
and equality were outside this fix. Hosted CI, other R versions/platforms, and
PDF manuals remain unverified.

## 2026-10-11 — Clear constructor argument errors (0.0.24)

Improved source record/class constructor diagnostics without changing accepted
programs or generated code. Errors identify constructors, list all omitted required
fields in declaration order, and report accurate maximum argument counts including
optional fields. A defaulted one-field constructor now reports "accepts at most 1
argument" when overfull, rather than incorrectly implying that one is required.

Non-overfull calls check labels before missing fields, so incomplete calls with
unknown or duplicate names identify those mistakes directly. Missing/overfull
errors preserve call locations; unknown labels preserve argument locations.
Ordinary function/method errors and direct R calls retain their current behavior.

Added four focused checks covering records/classes, required/defaulted fields,
singular/plural diagnostics, exact labels, locations, public file APIs, and no
execution before compilation errors. Updated existing constructor-error assertions,
documentation, decision record, roadmap, and versioned build instructions. An
initial test assertion named the wrong missing field in an existing Point fixture;
corrected it to the declared label field. Preserved the prior uncommitted runtime
validation work.

Verification: final shared validation reinstalled 0.0.24, passed all 325 checks
with 0 skips, ran all thirteen demos including Cairo rendering, built
RStarStar_0.0.24.tar.gz, and completed R CMD check --no-manual with Status: OK and
no warnings or notes. The final run had dependency-index network access after the
sandboxed run could not reach indexes. Checked 81 relative links and balanced
fences across 12 Markdown files, example consistency, and git diff whitespace.
Local environment: R 4.6.0 on macOS arm64.

Limits: diagnostic changes apply to source constructor calls only. Overfull calls
report argument count before label problems. No partial name matching or spelling
guesses were added. Hosted CI, other R versions/platforms, and PDF manuals remain
unverified.

## 2026-10-11 — Lowercase text comparisons (0.0.25)

Added std::lower_text(values) to the bundled catalog for explicit lowercase
comparisons on CSV labels. It accepts plain Text, preserves length and missing/
empty values, and composes with trim_text without rewriting source data. Uses
base R tolower under the caller's LC_CTYPE locale without changing it. Non-ASCII
mappings can vary across locales/platforms; no normalization or full case folding
is promised. Attributed, numeric/Boolean, invalid, and byte-encoded inputs are
rejected with source-located errors. Only used operations are embedded in generated
R, with no new export or dependency and no execution during compilation.

Added five behavioral checks for composition, original-value preservation, types,
exact arguments, CSV filtering, missing/empty values, R-input validation/encoding,
locale parity, single argument evaluation, call chains, lazy execution, public
APIs, and independent R6-free output. Extended the packaged standard-library example
and demo with lowercase labels. Updated the library contract, guide, implemented
subset, package guide, decision record, roadmap, README, and build instructions.
Preserved prior uncommitted work.

Verification: final shared validation reinstalled 0.0.25, passed all 330 checks
with 0 skips, ran all thirteen demos including Cairo rendering, built
RStarStar_0.0.25.tar.gz, and completed R CMD check --no-manual with Status: OK and
no warnings or notes. Final dependency-index checking had network access. Checked
81 relative links and balanced fences across 12 Markdown files, example consistency,
and git diff whitespace. Local environment: R 4.6.0 on macOS arm64.

Limits: lowercase conversion follows the executing R locale and platform. No
locale-independent Unicode matching, transliteration, or in-place table rewrite
was introduced. Hosted CI, other R versions/platforms, and PDF manuals remain
unverified.

## 2026-10-11 — Public user and contributor onboarding

Added docs/using-from-r.md with repository download/source installation, a bundled
example, a two-file personal R project, calling returned functions with R values,
CSV analysis and returned data frames, standalone generated R, common diagnostics,
working-directory behavior, updates, and current interoperability limits. Linked
the walkthrough prominently from README and the package API guide.

Expanded the existing CONTRIBUTING.md with issue/feature-request guidance, a
fork/branch/pull-request workflow, and an explicit welcome for AI-assisted reports,
fixes, patches, tests, documentation, and feature requests. Human understanding,
verification, and responsibility remain required. Added docs/linkedin-post.md with
a ready-to-adapt announcement and short repository description, accurately marking
the package as experimental and source-installed rather than a CRAN release.
The announcement uses the configured Git remote URL and is intended for use once
the repository is public; visibility was not verified or changed.

Verification: installed the current 0.0.25 source into a fresh temporary R library,
extracted and ran every runnable walkthrough block in an isolated project folder,
and checked documented values, CSV shares, the invalid-input example, and generated
code in a fresh R process without RStarStar/R6 loaded. All passed. Checked 91
relative links and balanced code fences across 14 Markdown files, example/API
consistency, and git diff whitespace. Download/clone instructions and public link
availability were not exercised. No compiler or package behavior changed in this
update; the full behavioral suite and package build/check were not rerun. Preserved
all prior uncommitted changes. No publication, message posting, or GitHub visibility
change was performed.

## 2026-10-11 — Refresh packaged examples for 0.0.25

Updated inst/examples to demonstrate recent implemented features together. The
filter example uses a small mixed-case/whitespace CSV fixture, explicit lowercase
and trimming operations, an outer target binding, and separate missing-label
review while preserving original strings. The CSV example now contrasts custom
missing markers with an empty marker list. The methods example combines scalar
record defaults, named overrides, and field access on a returned record, retaining
the original value. Refreshed the basics introduction.

Added an installed examples README indexing all twelve sources, explaining key
failure cases, and providing an R helper that copies fixtures to a fresh temporary
working directory so export/chart examples can run without writing into the
installed package. Extended the three affected development runners with expected
result checks. No compiler behavior, language design, dependencies, or API changed.

Verification: reinstalled 0.0.25 into temporary libraries; all 330 behavioral checks
passed with 0 skips. All thirteen development demos passed, including Cairo chart
rendering. R CMD build . and R CMD check --no-manual RStarStar_0.0.25.tar.gz passed
with Status: OK, no warnings or notes. Executed both R blocks in the new README
and used its helper to run all twelve installed sources through run_file(),
checking CSV/chart output creation. Checked the README's relative links and git
diff whitespace. Local environment: R 4.6.0 on macOS arm64. Other platforms,
hosted CI, and PDF manuals were not checked; lowercase conversion still follows
the executing R locale.

## 2026-10-11 — Optional execution directory for run_file (0.0.26)

Added run_file(path, working_dir = NULL) so R callers can select an existing
folder for relative data and output paths without a manual setwd/on.exit wrapper.
The default preserves existing behavior. Source paths resolve and compile before
changing directories; a relative working_dir also resolves from the caller's
directory. Invalid directory arguments produce rstarstar_error before program
execution. Explicit directory changes restore the caller's directory on return
or error, including empty programs and failed overwrite attempts.

Added six behavioral checks covering separate source/data locations (including a
same-named source decoy), relative paths and spaces, CSV output location, invalid
inputs, source diagnostics and compilation precedence, default/NULL compatibility,
returned functions, earlier effects on failure, and Cairo chart output/restoration.
Updated the development run-file example and packaged examples helper to use the
argument. Updated API help, guides, decision record, roadmap, README, and package
version/build instructions. No source syntax, generated R, exports, or dependencies
changed.

Verification: reinstalled 0.0.26 into temporary libraries; all 336 checks passed
with 0 skips, and all thirteen development demos passed. R CMD build . and
R CMD check --no-manual RStarStar_0.0.26.tar.gz completed with Status: OK, no warnings
or notes. Both R blocks in the packaged README and all twelve installed source
examples passed through its updated run_file helper, including CSV/chart output
checks. Checked 103 relative links and balanced fences across 14 Markdown files,
example consistency, and git diff whitespace. Local environment: R 4.6.0 on macOS
arm64 with Cairo. Hosted CI, other platforms/R versions, and PDF manuals remain
unverified.

Limits: this temporarily changes the R process working directory; it is not a
filesystem sandbox. Absolute and parent-directory paths remain usable, directories
are not created, and prior console/file effects are not rolled back. The option
applies to this execution only, not later calls to returned R functions.

## 2026-10-11 — API and compiler implementation comments

Added source comments across all eight R modules explaining the public API's
arguments, return values, errors, and side effects; compiler stage contracts;
parser precedence and AST spans; analysis scopes and unknown type/size handling;
R emission and helper selection; runtime validation, dispatch, copying, CSV/chart
output, and standard-library behavior. Comments distinguish static analysis from
execution and schema checks from provenance or deep-immutability guarantees.
Added an architecture reading map and corrected its outdated working-directory
and class-field descriptions to match the implemented API. Public help remains
hand-maintained, with no documentation-generation dependency.

Verification: captured parsed R expressions and generated R for all twelve
packaged sources before this comment pass. Final comparison with source references
excluded confirmed identical parsed expressions in all eight modules and identical
generated R strings. Reinstalled 0.0.26; all 336 behavioral checks passed with
0 skips, and all thirteen development demos passed, including Cairo rendering.
R CMD build . and R CMD check --no-manual RStarStar_0.0.26.tar.gz completed with
Status: OK and no warnings or notes. Checked 111 relative links and balanced fences
across 14 Markdown files, example consistency, and git diff whitespace. Two final
comment wording corrections were checked by the final parsed/generated comparison;
they did not require repeating behavioral checks.

No executable code, API signatures, language semantics, or dependencies changed
in this pass. Preserved the earlier uncommitted working_dir API improvements.
Verification was local on R 4.6.0/macOS arm64; hosted CI, other platforms, and PDF
manuals remain unverified.

## 2026-10-11 — Finite numeric standard-library predicate (0.0.27)

Added std::is_finite(values) for explicitly filtering computed numeric results
before summaries. It accepts one plain numeric scalar/vector, positional or named
values, and returns a same-length Boolean vector. Finite numbers (including zero
and negatives) map to true; NA, NaN, and either infinity map to false. Empty numeric
inputs yield an empty Boolean vector. Attributed, text, Boolean, complex, and
structured R inputs are rejected without coercion. The existing catalog supplies
Boolean inference and standalone embedding without parser changes or new dependencies.

Added six focused checks covering arithmetic results, scalar/record/conditional use,
exact signatures, known/dynamic type errors, result inference, CSV filtering with
missing and zero-row inputs, source-data preservation, R caller validation, source
locations/call chains, one evaluation, lazy branches, input-error propagation, and
standalone execution without RStarStar/R6 loaded. Extended the packaged library
example and development runner. Updated the contract, guides, decision record,
roadmap, README, package version, and build instructions. Installed library help
now documents both is_finite and the previously omitted lower_text operation.

Verification: reinstalled 0.0.27 into a temporary library; all 342 behavioral checks
passed with 0 skips. All thirteen development demos passed, including Cairo chart
rendering. R CMD build . and R CMD check --no-manual RStarStar_0.0.27.tar.gz completed
with Status: OK and no warnings or notes. Checked 111 relative links and balanced
fences across 14 Markdown files, example consistency, and git diff whitespace.
Local environment: R 4.6.0 on macOS arm64. Hosted CI, other platforms/R versions,
and PDF manuals remain unverified.

Limits: this predicate deliberately maps missing values to false; existing numeric
transforms keep their missing-value behavior. It does not catch errors computing
its input or make an empty average valid. No automatic dropping, replacement,
coercion, public R exports, or general missing-value policy changes were introduced.

## 2026-10-11 — UTF-8 files and background tasks (0.0.28)

Implemented the user's selected file and concurrency scope: std::file_exists,
std::read_text, std::write_text, std::start_task, and std::await_task. Text reads
preserve complete UTF-8 contents and reject invalid encoding/NUL bytes. Writes
publish staged bytes through a hard link, refusing existing destinations even
when workers compete. Paths and text receive scalar/type checks and source-located
diagnostics. Extended catalog signatures preserve exact argument names and eager
evaluation in written order without executing source during compilation.

Tasks snapshot an earlier one-argument source function and plain primitive input
before launching a fresh Rscript process. Required generated functions and helper
environments are copied explicitly, including standalone global-scope functions.
Workers retain their starting directory; returned handles cache results/errors,
preserve worker error locations with start/await context, permit timeout retries,
and enforce eight uncollected tasks per runtime. Collection removes transport
files; abandoned handles request cleanup on worker completion. Handle directory
bindings are locked against accidental R-side modification. No public R exports,
external dependencies, source suffix, or CLI changes were introduced.

Added eighteen behavioral checks for file validation/round trips, argument/effect
ordering, no overwrite and competing writers, worker overlap in distinct processes,
input snapshots, working directories, exact signatures, timeout retries, cached
errors, nested-task rejection, capacity reuse, abandoned-handle cleanup, referenced
functions/record helpers, and standalone execution. Verification caught and fixed
global-environment serialization and inherited R_TESTS startup failures; the final
run also corrected newline escaping in a new test fixture. Added a packaged source
example, development runner, API comments, installed help, and the full file/task
contract. Updated the guide, design decisions, roadmap, architecture, README,
package metadata, and example inventory.

Verification: reinstalled 0.0.28 into a temporary library before tests; all 360
behavioral checks passed with 0 skips. All fourteen development demos passed,
including Cairo rendering. R CMD build . and R CMD check --no-manual
RStarStar_0.0.28.tar.gz completed with Status: OK (no package warnings or notes).
Repository-index access warnings appeared during dependency lookup, but dependency
checks passed using installed packages. Separately executed the example guide's R
blocks and all thirteen packaged sources through run_file. Checked 124 relative
links, balanced fences, and unique section headings across fifteen Markdown files,
plus git diff whitespace. Local platform: R 4.6.0 on macOS arm64.

Limits: writes require filesystem hard-link support; reads load entire files into
memory. Workers require Rscript, copy plain primitive inputs/results, and discard
console output. Await timeouts do not cancel work. Nested tasks, cancellation,
worker pools, shared-memory mutation, and crash cleanup guarantees remain absent.
Files are shared external resources and execution is not sandboxed. Other platforms,
hosted CI, and PDF manuals remain unverified.
