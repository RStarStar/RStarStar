# Design decisions

Initial record: 2026-10-01. A first compiler subset is now implemented; see the
implementation decision below. Broader proposals are not implemented.

“Direction” records the project's goals. “Proposed” means a design worth exploring,
not a stable specification. Record accepted semantic choices here as work proceeds,
including their rationale and consequences.

## Direction

- Implement the toolchain in R and generate readable ordinary R.
- Help people new to R express analysis without needing to write R syntax.
- Offer useful safeguards through a small, consistent everyday interface.
- Make diagnostics refer to the user's source, including runtime checks we add.
- Support R's ecosystem without recreating all of it.
- Welcome AI-assisted contributions under the same review standards.
- Keep functions and data workflows usable independently of OOP.

## Proposed design

| Proposal | Motivation | Still to resolve |
| --- | --- | --- |
| Sentence-like actions and conventional expressions | Readable workflows and concise arithmetic | Grammar, blocks, comments, precedence |
| Immutable bindings by default, explicit mut | Make changes intentional | Declarations, shadowing, nested updates |
| Inferred types with optional annotations | Reduce boilerplate | Type model, coercion, static/runtime boundary |
| Stable types for mutable bindings | Avoid unexpected changes in meaning | Whether to adopt; numeric compatibility |
| Explicit missing-data policies | Avoid hidden statistical choices | Defaults and empty/all-missing input |
| Single non-missing boolean conditions | Make branches unambiguous | Boolean syntax and runtime checks |
| Records with generated operations | Reduce boilerplate for data | Equality, validation, nested values |
| Classes with private fields and public methods | Protect internal state | Construction, visibility syntax, backend |
| Explicit self and mut self | Show method effects | Usability and function-argument mutation |
| Value semantics for language-owned objects | Avoid surprising aliases | Copy strategy and foreign R references |
| Interfaces after basic OOP | Express shared contracts | Dispatch and compatibility rules |

## Questions for language development

1. What is the smallest grammar, including declarations, literals, and comments?
2. How are scalar values and vectors represented? What are indexing and length
   mismatch rules, and which R recycling behaviors should be allowed?
3. How does name lookup distinguish local variables from table columns?
4. Which errors can be checked before execution, and which require runtime data?
5. What does a missing value mean in arithmetic, comparisons, filters, and summaries?
6. How can users call R packages, and what guarantees stop at that boundary?
7. What generated code or helpers are required for mutation and object semantics?

The source extension is .rsspps. Detailed package layout, supported R versions,
dependency policy, and object backend remain unchosen. R package distribution is selected;
a public CLI is not planned (see the package decision below). Do not assume S3, S4, R6, or another system is
the backend merely because the surface language has classes.

## Deferred scope

Inheritance, operator overloading, generics, ownership/borrowing systems, IDE
integration, and a package manager are outside the initial implementation scope.
Revisit them only with motivating user examples.

## Recording future decisions

For each accepted change, add a dated entry with the problem, decision, examples,
alternatives considered, consequences, and verification criteria. Update the
[guide](language-guide.md) in the same change. Explicitly mark superseded choices.


## 2026-10-01 — Initial compiler subset

Status: implemented, experimental. The request to begin implementation authorizes
this small starting subset; these implementation choices remain open to revision.

- First assignment declares a binding; later assignments require mut on the
  original declaration. Repeated mut declarations fail. One scope, no shadowing.
- Infer Number (R double), Text, and Boolean. Mutable element types are stable;
  lengths may change. This adopts stable types for the current subset only.
- Use +, -, *, / with conventional precedence, unary signs, and parentheses.
- Vectors are nonempty, homogeneous, and built from length-one expressions.
  Arithmetic allows equal lengths or scalar broadcasting, rejecting general R
  recycling to avoid accidental mismatches even when lengths divide evenly.
- Use double-quoted text, true/false, # comments, and newline-separated statements.
  Delimiters allow multiline expressions. Print uses base R's display format.
- Preserve arithmetic Inf/NaN outcomes for now; a full missing-data policy remains
  open. No R calls, file operations, indexing, or OOP are part of this subset.
- Expose transpile(source, filename) in a sourceable base-R file. Return R text;
  execution is explicitly separate. No external dependencies or runtime helpers.

This is enough to verify a real source-to-R path before implementing CSV or OOP.
Alternatives deferred: required declaration keywords, a scalar/vector type split,
implicit coercion, and R's general recycling. They would add syntax or surprising
behavior before there are motivating workflows. Exact grammar and limits are in
[implemented-subset.md](implemented-subset.md).

Verification: tests/run.R checks successful generated-code execution, rejection
cases, source locations, literal escaping, and absence of execution during
transpilation. Future unknown types/lengths will require runtime checks; static
analysis here is sufficient only because every value comes from known literals
and supported expressions.


## 2026-10-01 — CSV loading and the runtime boundary

Status: implemented, experimental. read accepts a quoted local path, into, an
optional mut, a target name, and an optional with delimiter text literal. Loading
uses existing declaration and reassignment rules. Table is a distinct inferred
type; table arithmetic and vector elements are rejected. Column access is deferred.

Generated CSV programs embed a self-contained loader so execution needs no compiler
installation. Compilation never reads data. A strict field parser is used to avoid
silently filling short rows, treating extra fields as row names, or repairing bad
quotes. UTF-8 files require unique nonempty headers; quoted multiline fields and
escaped quotes are supported. See the implemented subset for the exact CSV dialect.

Inference uses whole columns: numbers, booleans, otherwise text. Empty/NA fields
remain missing, including quoted fields; all-missing columns remain text. Mixed
numeric/text data stays text rather than being partially converted. Configurable
schemas and missing markers are deferred, so numeric-looking identifiers may lose
leading zeros. Runtime failures retain the read statement's source location.

Alternatives deferred: external runtime installation, permissive CSV repair,
path expressions, remote URLs, and schema syntax. The implementation prioritizes
an inspectable local-file workflow and predictable failure behavior. It currently
reads the entire file and does not claim large-dataset performance.

Verification covers CSV content, mutable reload, missing data, malformed rows and
quotes, encodings, header-only files, delimiter validation, and standalone generated
execution in an environment containing only base R. Filtering and statistical
missing-value rules remain separate, unresolved work.


## 2026-10-01 — Columns and filtering

Status: implemented, experimental. Column access uses table.column or a quoted
header after the dot. Bare names inside where always mean input columns; @name
explicitly references a declared variable. This avoids silent column/local name
collisions and schema-dependent fallback. Outside filters, @name and name both
refer to variables. Exact column lookup happens at runtime without partial matches.

Added typed, vectorized comparisons, and/or/not, and is [not] missing. Ordered
comparisons accept numbers or text; equality also accepts booleans. Comparisons
cannot be chained. Logical operations are elementwise and not short-circuiting.
They retain R's three-valued logic; the final predicate determines missingness.

A filter requires a boolean scalar or one boolean per input row. Missing results
fail by default; skipping missing explicitly removes those rows. is missing can
select them instead. No automatic missing-row removal is performed. Table shape,
column types, and input row order are preserved, with display row numbers reset.
Targets follow existing immutable/mutable binding rules.

Data-derived values carry unknown static types/lengths. Embedded runtime helpers
apply the same operand, vector-construction, and reassignment checks to these
values. Numeric/text mixing and unequal nonscalar lengths remain errors. Programs
without reads retain direct R expressions. Compiler-only validation cannot enforce
these guarantees on unknown data, so runtime checks are part of generated output.

Alternatives deferred: implicit column/local precedence, silent NA filtering,
partial column matches, row alignment/joins, and a general indexing syntax.
All-missing/header-only columns retain the existing CSV Text inference; schemas
remain future work. Summaries and charting are still unimplemented.

Verification includes runtime types/lengths, missing-value policies, exact lookup,
compound predicates, alias preservation, mutable targets, empty/single-column
outputs, source locations, and complete statement spans.


## 2026-10-01 — Scalar summaries and saved bar charts

Status: implemented, experimental. average(input), sum(input), and count(input)
are contextual built-in expressions with an optional skipping missing suffix.
Parentheses replace the earlier prefix-average sketch to make input boundaries
unambiguous. The names remain legal bindings; general function calls are deferred.

Numeric summaries reject missing values by default, allow explicit skipping,
and reject nonfinite remaining inputs/results. Empty numeric sum is zero; empty
average is an error. count counts entries (including missing by default), or table
rows. Skipping missing is supported for vectors only. Existing CSV type inference
continues to apply; schemas and grouped table summaries remain future work.

plot table x column y column as bar to "path.png" saves one bar per row, using
bundled R graphics with the Cairo PNG device. Contextual axis words preserve x/y
variable names. Chart columns must be present, labels unique, heights numeric and
finite, and both columns nonmissing. No implicit aggregation or row dropping.
The PNG is published from a temporary file after rendering; existing output is
not overwritten and the parent directory must already exist.

Alternatives deferred: prefix aggregate expressions without parentheses, implicit
missing removal, group-by, automatic aggregation of repeated labels, GUI devices,
additional image formats, and configurable styling. This delivers a complete
small workflow while keeping those choices separate.

Verification includes scalar results, missing/empty/type errors, count policies,
PNG signatures/dimensions, standalone generated execution, no compilation-time
file output, and chart validation/output protection. The full suite now requires
Cairo; broader renderer portability remains future work.


## 2026-10-01 — Grouped table summaries

Status: implemented, experimental. summarize table by key with name = sum(column),
... into target supports one key and named average/sum/count outputs. The separate
statement avoids introducing persistent grouped-table state. Each aggregate may
specify skipping missing. Outputs are unique and cannot replace the key name.

Keys retain type and first-seen order, including a missing-key group. Empty inputs
produce typed zero-row output; columns/types are still validated. Aggregate rules
reuse scalar summaries per group, so missing input does not disappear silently.
Bare inputs mean columns; qualified inputs must name the source table. Immutable
and mutable target rules remain unchanged. The whole assignment fails on an error.

Deferred alternatives: multiple grouping keys, arbitrary expressions in aggregate
inputs, output-to-output references, implicit missing-key removal, and sorting
groups automatically. These limits keep the first grouped workflow explicit.
The chart's duplicate-label diagnostic now suggests summarize instead of claiming
that grouped summaries are unavailable.

Verification covers repeated and missing keys, multiple aggregates, per-result
missing policy, quoted headers, type preservation, empty input, invalid columns,
output-name conflicts, mutable targets, and grouped output flowing into a chart.


## 2026-10-01 — Multiple grouping columns

Status: implemented, experimental. A comma-separated list after by replaces the
single-key restriction. Duplicate key names and aggregate names colliding with
any key are compile-time errors. Every key is validated even for empty input.
Keys appear in the specified order with their original types; complete key
combinations appear in first-seen order, including missing-value combinations.

Each column is matched independently to integer IDs using unique/match. Combining
those IDs avoids raw-text separator collisions and preserves typed equality.
The existing per-group scalar summary and mutation rules are unchanged. Empty
input returns all key columns and numeric output columns with zero rows.

Implicit sorting, dropping missing keys, combined chart labels, and grouped bars
remain excluded. Existing single-key programs continue to work. Tests cover
multiple key types, missing combinations, separator-like text, quoted headers,
empty input, collisions, malformed syntax, and rolling results up again.


## 2026-10-01 — Initial user-defined functions

Status: implemented, experimental. fn name(parameters) { return expression }
provides a deliberately small foundation for later methods. Calls use exact-count
positional arguments evaluated eagerly once in order. Bodies see parameters,
built-in summaries, and earlier functions; data must be passed explicitly.
Function names are immutable, share the top-level namespace, and cannot replace
built-in summary names. Functions are not first-class values in this version.

Semantic analysis checks each body in its own scope without execution. Parameter
types/lengths are unknown until runtime, where existing value checks apply. Body
errors retain source locations and include the call chain. Generated functions
cannot alter helpers through name collisions: embedded runtime and CSV helper
closures now use base-R parent environments. Generated code remains standalone.

Deferred alternatives: capture/closure semantics, recursion, annotations, named or
default arguments, multiple statements, nested functions, and mutable parameters.
Choosing explicit arguments and one return expression establishes useful reuse
without prematurely fixing those language rules. Existing typed OOP examples
remain proposals; records and methods are not implemented.

Verification covers calls, composition, scope isolation, arity, eager unused
arguments, tables, filter predicates, dynamic type/length checks, call locations,
namespace collisions, and compilation without body execution.


## 2026-10-01 — Distribute as an R package

Status: accepted direction, packaging not yet implemented. At the user's request,
RStarStar will be an R package people load and use from an R session, rather than
a public CLI program. This supersedes earlier language treating CLI conventions
as an unresolved release task. Existing Rscript demos remain development helpers.

Keep transpile(source, filename) as the initial public API: it returns readable R
without executing input. Package loading, examples, and a future explicit execution
helper must preserve that boundary. Keep rss_* implementation helpers internal.
The package does not change the RStarStar language or require users to write the
translated R themselves; a small R-session entry point invokes the toolchain.

Package metadata, namespace, help pages, installed-package tests, and build/check
validation are planned next. No installation or publication has happened in this
change. CRAN versus another release channel, the final package name, supported R
versions, and the execution-helper API remain open. See [r-package.md](r-package.md).


## 2026-10-01 — .rsspps-only public source API and R interoperability

Status: accepted direction, file API and interoperability bridge not implemented.
At the user's request, the public package API will consume .rsspps source files
only. This supersedes the preceding plan to expose transpile(source, filename)
as the public API. Retain that string compiler internally; the intended public
entry point is file-based, illustrated as transpile("analysis.rsspps"). Existing
.txt fixtures and source-string examples remain prototype artifacts until migrated.

.rsspps programs are intended to interoperate with existing R code, packages,
tooling, and codebase APIs. R invokes the public package API; an explicit future
bridge lets RStarStar use R/project functions and exchange ordinary results. This
does not make .R files valid compiler inputs or expose compiler internals publicly.
Dataset and output formats are unaffected by the source-file restriction.

Interop syntax, result transfer, execution environments, and reference/mutation
semantics still require design and testing. Compilation must remain separate from
execution; neither source loading nor package loading runs user code. See the
[package plan](r-package.md) for the boundary and implementation work.


## 2026-10-01 — Initial installable package and file API

Status: implemented locally, not published. RStarStar 0.0.1 exports only
transpile(path), accepting one regular local UTF-8 file with an exact lowercase
.rsspps suffix. Source may have a BOM or no terminal newline; invalid encoding,
NUL bytes, wrong extensions, directories, and invalid argument shapes fail.
Readable source diagnostics use normalized absolute paths. The former string
entry point is now the internal rss_compile(source, filename).

The package includes metadata, namespace, help pages, and canonical examples under
inst/examples/. Developer runners and tests use the installed namespace. Generated
R remains standalone, and execution stays explicit. Maintainer metadata comes
from the repository's existing Git author identity; the full MIT text is retained
in LICENSE.md alongside the package-format license stub in LICENSE.

R >= 4.1.0 is declared as the initial baseline, but verification so far covers
R 4.6.0/macOS arm64 only. Dependencies are bundled with R. Chart execution requires
Cairo and chart tests explicitly skip on builds without it. PDF-manual generation,
broader CI, release publication, an execution helper, and the R-call bridge remain
outside this milestone. This supersedes prior documentation-only package status.


## 2026-10-02 — Explicit execution and results for R callers

Status: implemented in 0.0.2. run_file(path) accepts the same local UTF-8 .rsspps
files as transpile(path). It compiles the entire file first, then evaluates generated
R in a fresh environment parented by baseenv(). It returns a named list of final
variables and functions, with default R name sorting and no compiler helpers.
Empty/print-only programs return empty lists. Returned functions retain their checks
and use ordinary R calling conventions when called from R.

No caller bindings are injected and the working directory is unchanged. CSV/chart
paths resolve from that working directory. Console/file effects happen explicitly;
runtime failure returns no partial results and does not roll back earlier effects.
Compile failure prevents all execution. This offers simple R result transfer without
choosing an external-call syntax or promising deep immutability or sandboxing.
The external R bridge and object model remain future work.


## 2026-10-02 — CSV result export

Status: implemented in 0.0.3. Add write table to "output.csv" to save analysis
results. write becomes reserved. Input is a table variable and destination is a
quoted .csv path (case-insensitive suffix). This intentionally starts with one
format and no append, overwrite, or custom-delimiter options.

Execution writes UTF-8 comma-separated data with quoted headers/text, doubled
embedded quotes, LF endings, no row names, TRUE/FALSE booleans, and empty missing
fields. Header-only tables work. Numeric formatting follows utils::write.table;
CSV does not preserve every type or numeric bit. Re-reading follows existing
inference, including empty/NA text becoming missing. Use returned R values for
exact in-session results instead.

Compilation does no output I/O. Execution requires an existing directory and
refuses existing destinations. A temporary file is cleaned up after publication
or failure; publication is not promised atomic. Runtime failures preserve source
locations. This extends ordinary analysis without changing the unresolved object
model or external-call bridge.


## 2026-10-02 — Conditional expressions for reusable calculations

Status: implemented, experimental in 0.0.4. Adopt the proposed single nonmissing
boolean condition rule through if condition then value else fallback. This allows
functions to avoid invalid calculations (such as averaging empty inputs) while
retaining their single-return-expression bodies. if, then, and else become reserved.
This supersedes earlier allowance of if as an ordinary R-keyword binding.

Both branches are analyzed, but only the chosen branch executes after one condition
evaluation. Branches may differ in type or length; conflicting inference becomes
Unknown and surrounding operations retain runtime type/shape checks. This avoids
forcing evaluation of unused branches to compare values or types. Conditions are
never implicitly coerced or vectorized. Generated R uses native lazy if plus the
embedded condition validator. Diagnostics point to the condition and retain
function call chains.

Alternatives deferred: statement blocks (need scope/assignment rules), vectorized
selection (needs its own missingness and length contract), and required matching
branch types (needs richer inference for unknown parameters). This does not settle
records, mutable objects, or external R reference semantics. Verification covers
syntax, nesting, lazy evaluation, static errors in unused branches, conditions,
dynamic branch types, filter scope, mutable checks, and the public file API.
