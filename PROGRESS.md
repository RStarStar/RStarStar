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
