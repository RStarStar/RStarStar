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

The source extension is .rsspps. Package layout, supported R versions, and
dependency policy are recorded in the decisions below. R package distribution is
selected; a public CLI is not planned. Source-language classes use tagged scalar-field values as recorded below.
Internal compiler R6 objects are separate from that representation.

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


## 2026-10-02 — Named function arguments

Status: implemented, experimental in 0.0.5. User-defined calls accept name: value,
matching the proposed record-constructor spelling without implementing records.
Names match exactly and case-sensitively. Positional arguments precede named ones
and bind in declaration order; named arguments can be reordered. Every parameter
must be supplied once. Unknown names, duplicates, positional/named collisions,
missing/excess arguments, and positional-after-named calls are compile errors.

Arguments retain eager, once-only evaluation in source order, not parameter order.
The compiler preserves labels/locations and emits a named list for the existing
call helper. This leaves function bodies and filter expression scope unchanged.
Returned R closures continue to use ordinary R calling conventions outside the
source language. Built-in summary calls are unchanged.

This supersedes the positional-only call restriction. Alternatives deferred:
R-style partial matching (makes typos ambiguous), interspersed positional arguments
(makes binding harder to explain), and default parameters (needs separate scope
and evaluation rules). Parameter annotations, records, and the R bridge remain
unimplemented. Verification covers matching failures, source evaluation order,
R-keyword parameter names, nested calls, diagnostics, and file/standalone execution.


## 2026-10-02 — Initial records with typed scalar fields

Status: implemented, experimental in 0.0.6. Adopt record Name { field: Type }
with newline-separated fields and required scalar Number/Text/Boolean annotations.
Constructors use existing positional/named calls. Fields are readable and cannot
be assigned; mut permits whole-value replacement only with the same nominal record
type. Constructors and schemas must be declared before use. Missing scalar fields
are allowed when correctly typed; numeric finiteness rules are unchanged.

Use named R lists with an internal type attribute and base list printing, without
choosing a class/dispatch backend. Constructor checks reject attributed or reference
values from R. This limited boundary supports independent copies and replacement
without claiming arbitrary-object deep immutability. Returned lists remain mutable
from R, and direct R calls keep R argument semantics. Runtime constructor errors
retain the declaration location plus language call sites.

This implements only the construction/field-access portion of the record proposal.
Integer annotations, nested/vector/table fields, equality, with updates, defaults,
validation blocks, and classes remain deferred. Explicit field schemas avoid
per-instance type guessing; scalar-only fields keep the initial copying contract
small enough to verify. Tests cover schema/call errors, static and dynamic checks,
function use, lookup, aliases, nominal reassignment, typed missing values, rejection
of undefined record operations, and R/file/standalone boundaries.


## 2026-10-02 — Copy updates for records

Status: implemented, experimental in 0.0.7. Adopt the proposed with expression as
receiver with { field: value, ... }, creating a new record of the same nominal type.
Require at least one unique, exact field name and preserve scalar field types.
Commas separate fields, with optional boundary newlines and no trailing comma.
Updates attach to primary expressions and may chain; parentheses select a whole
conditional receiver. General chained field access remains deferred.

The receiver and field names are validated before replacement evaluation. Values
then evaluate once in source order, using surrounding scope, before construction
of the validated copy. Updates are simultaneous with respect to the original
record: swapping fields reads their original values. Failures leave the original
and aliases unchanged; rebinding still follows ordinary mut rules. Both known
schemas and dynamic function inputs receive checks and source-located errors.

This supersedes the previous deferral of with updates. Alternatives deferred:
in-place field mutation (requires mutable object semantics), implicit field scope
(ambiguous with caller variables), and sequential field updates (order-sensitive).
Nested fields, equality, classes, and the external R mutation boundary are unchanged.


## 2026-10-02 — Scalar-field record equality

Status: implemented, experimental in 0.0.8. Same-declared-type records support ==
and != by comparing corresponding scalar fields. Numeric comparison is exact,
following the existing scalar == behavior. Any definite field mismatch makes
equality false; otherwise any missing comparison makes the result missing; all
true comparisons make it true. != negates the result. Different nominal types,
record/scalar comparisons, and all ordering comparisons are errors.

This supersedes the earlier equality deferral for scalar-field records only.
Treating two missing fields as equal was rejected because it would silently change
the existing missing-data interpretation. Returning false for different record
types was rejected in favor of existing incompatible-type diagnostics. No custom
R comparison methods are added; generated helpers provide language behavior and
source locations. Raw returned lists still follow ordinary R behavior outside the
language, with defensive runtime checks for malformed inputs to returned functions.

Verification covers all field types, construction order, missing comparisons with
and without a definite mismatch, nominal incompatibility, forbidden ordering,
conditional use, call-chain diagnostics, and public/standalone execution. Nested
records, tolerance-based numeric comparison, and foreign-object equality remain
outside this implementation.


## 2026-10-02 — Field access on expression results

Status: implemented, experimental in 0.0.9. Allow exact .field/."header" access on
constructor calls, function calls, parenthesized expressions, explicit @variables,
and record-update results. Postfix access/updates associate left to right before
arithmetic; parenthesize an entire conditional receiver. Each receiver is emitted
once and must be a table or record. Known schema/type errors are static; dynamic
errors retain the dot location and existing call-chain behavior.

Preserve original table.column lookup and grouped-summary restrictions. General
receiver expressions use their existing scope, including column lookup for bare
names inside filters and explicit @bindings for outer values. Nested records,
indexing, methods, field assignment, and callable field values remain deferred.
This supersedes the temporary-variable requirement for reading an update result.

The AST retains legacy explicit column nodes and introduces expression member nodes
to avoid changing aggregate grammar or filter name resolution. Tests cover records,
returned tables, quoted headers, updates, conditionals, scope, failures, complete
source spans, and both public and standalone execution.


## 2026-10-02 — Nested records with acyclic schemas

Status: implemented, experimental in 0.0.10. Field annotations may name earlier
record declarations. Nested values retain exact nominal types; chained reads,
explicit inner with updates, and recursive equality extend existing behavior.
Declare dependencies first: unknown, forward, self-recursive, and mutually recursive
schemas fail. Number/Text/Boolean are no longer permitted as record declaration
names because their annotations denote primitives; ordinary bindings are unaffected.

Nested updates create new inner and outer values without changing aliases. Equality
uses the same three-valued reduction at each level, including definite mismatch
overriding missing comparisons. Missing values are permitted only in typed primitive
fields, not in place of a whole nested record. Constructors recursively reject
unsupported/reference-bearing field structures and extra record attributes from R.
The tagged-list representation remains experimental and does not prove full schema
provenance or immutability for externally forged/modified objects.

This supersedes the scalar-only record-field restriction and deferral of nested
updates/equality. Recursive types, vector/table fields, dotted update labels, methods,
and classes remain deferred. Requiring earlier types avoids cycle handling before
there is a motivating recursive-data workflow. Verification covers declaration
order, type mismatches, multi-level field inference, copy independence, failed
updates, nested missing equality, and public/standalone/R boundaries.


## 2026-10-02 — Standard library bundled with the R package

Status: accepted direction, not implemented. At the user's request, RStarStar will
eventually include a standard library distributed within the same R package as the
toolchain. Users installing RStarStar will receive the library without a separate
standard-library package installation.

The initial operations, naming/import syntax, implementation format, compatibility
policy, and relationship to public R exports remain open. Existing compiler helpers
and built-ins are not automatically promoted to a stable library API. Define the
library's use by generated R before revisiting current standalone-output behavior.
Preserve the .rsspps-only public source API, compilation/execution separation, and
R-bundled dependency policy. No library code, imports, exports, dependencies, or
runtime behavior change in this documentation update.


## 2026-10-03 — First standard-library slice proposed

Status: proposed, not implemented or accepted syntax. Added a reviewable
[standard-library proposal](standard-library.md) covering absolute/square_root,
qualified std:: calls, exact arguments, elementwise missing-value behavior, domain
errors, private R implementations, and embedding used helpers in standalone output.
The proposal includes alternatives and a verification checklist. Namespace syntax,
operation names, value rules, and implementation strategy still require review.

This elaborates the accepted package-bundling direction without promoting it into
an implemented library. Current built-ins, exports, dependencies, source validation,
and generated-program behavior remain unchanged. Classes and external R calls stay
separate milestones.

## 2026-10-03 — First standard-library slice implemented

Status: accepted and implemented, experimental in 0.0.11; supersedes the proposal
above. std::absolute(values) and std::square_root(values) accept one exact positional
or named argument. Inputs are attribute-free integer/double scalars or vectors.
Length, numeric NA, and NaN are preserved; square_root rejects any nonmissing
negative value at execution. Qualified names avoid user-binding collisions, and
only std is supported. Operations are not first-class values or arbitrary R calls.

The private catalog holds quoted implementations, never evaluated during compilation.
Only used operations and common validation are embedded in an isolated base-only
scope. Generated R remains standalone, with no additional public exports or
dependencies. Errors retain source locations and language function call chains.
See the [library contract](standard-library.md) for alternatives and failure cases.

## 2026-10-03 — Text-length standard-library operation

Status: implemented, experimental in 0.0.12. To support validation of text columns
(such as imported product codes), add std::text_length(values), using the existing
one-argument namespace syntax. It accepts only attribute-free Text scalars/vectors
and returns Number character counts of the same length. Empty text gives zero,
missing text gives a missing Number, and empty vectors remain empty. Known wrong
types fail analysis; dynamic types and invalid/byte-encoded R text fail execution
with source locations and language function call chains.

Choose character counts over byte counts for beginner-facing text checks. UTF-8
counts follow Unicode code points, not grapheme clusters or display width; combined
accents can therefore count differently from precomposed characters. Do not normalize
inputs or silently coerce numbers. This bounded behavior uses base R without new
dependencies. More elaborate Unicode handling needs its own design.

The catalog now declares each operation's input type; the compiler uses this
metadata for static checks. Standalone embedding, source-file-only APIs, exact
arguments, and explicit execution remain unchanged. CSV inference also remains
unchanged: numeric-only codes fail the text check, empty cells become missing,
and all-missing Text columns are supported. See the
[library contract](standard-library.md#text-length) for examples and tradeoffs.

## 2026-10-03 — Text trimming and library result types

Status: implemented, experimental in 0.0.13. Add std::trim_text(values) to clean
surrounding whitespace before checking imported codes or text lengths. It accepts
plain Text scalars/vectors and preserves length, missing values, and empty vectors.
Only boundary spaces, tabs, carriage returns, and newlines are removed. Internal
spacing and other Unicode whitespace are retained. Whitespace-only text becomes
empty text; it does not become missing. No coercion, normalization, or mutation.

Use an explicit small whitespace set instead of locale-sensitive or broad Unicode
classification. This keeps cleaning predictable using base R. R-boundary encoding
validation rejects invalid/byte-encoded inputs before regex processing. Types,
exact arguments, source locations, standalone output, and execution separation
follow existing library rules. Filtering on cleaned text preserves original rows;
CSV inference is unchanged. See the [contract](standard-library.md#trimming-text).

The private catalog now declares output types as well as input types. Analysis
retains the operation's result type and input length, so arithmetic rejects trimmed
Text and Text fields/bindings accept it. This removes the earlier assumption that
every library operation returns Number, without introducing a public API.

## 2026-10-03 — Optional CSV column types

Status: implemented, experimental in 0.0.14. Numeric-looking identifiers should
remain usable with text operations without losing leading zeros. Add an optional
with columns {code: Text, amount: Number} clause to read. It can accompany the
existing with delimiter clause in either order, with each option appearing once.
Use exact unique headers (names or quoted text) and Text/Number/Boolean type labels;
columns remains a contextual word. Unspecified columns retain current inference.

Choose per-column overrides rather than mandatory full schemas to keep simple
reads simple. Validate declared headers even on empty files. Text keeps nonmissing
field contents; Number and Boolean require their existing strict input formats
without trimming, lossy conversion, or fallback. Empty and exact NA fields remain
missing, even quoted. Explicit types preserve empty/all-missing numeric and logical
vectors. Invalid values report the read location, column, and one-based data-row
number. Header and value validation happen only during explicit execution.

This is a loader contract, not static table typing or a persistent constraint on
mutable reloads. Alternate missing markers, required/nonmissing columns, date types,
and schema objects remain future designs. Standalone generated R embeds the schema
and loader with no new dependencies or exports. See the
[implemented rules](implemented-subset.md#explicit-csv-column-types).

## 2026-10-06 — Explicit CSV missing markers

Status: implemented, experimental in 0.0.15. Add with missing ["", "N/A"] to read
so datasets can choose their missing convention and preserve literal NA codes.
The list replaces, rather than extends, the default ["", "NA"]. An explicit []
disables marker recognition. The option can appear once, in any order with delimiter
and columns, and resets for each read. It accepts unique quoted text literals only.
This does not introduce general empty vector literals or new reserved words.

Match exact parsed field text, including quoted fields, after CSV unquoting and
line-ending normalization; do not trim or fold case. Apply markers to data fields
before inference/conversion, not to headers. All columns share the policy. Text
preserves unmarked empty/NA fields, while declared Number/Boolean columns reject
unmarked values outside their strict formats. Missing values retain declared types.

Replacing the entire list makes disabling defaults possible without another option.
Avoid per-column policies and quoted/unquoted distinctions in this first addition.
Compilation validates syntax only and never opens data; generated R embeds the
marker list and remains standalone. Export still writes missing values as empty
fields, so custom read markers alone do not guarantee round-trip preservation.
See the [implemented contract](implemented-subset.md#custom-csv-missing-markers).

## 2026-10-06 — Configurable CSV export delimiters

Status: implemented, experimental in 0.0.16. Add an optional with delimiter clause
to write so semicolon and tab workflows can export without leaving the language.
Default comma output is unchanged. Supported export delimiters are comma, semicolon,
tab, and pipe, expressed as one text literal. Require the existing .csv suffix and
retain overwrite protection, temporary-file handling, source locations, and explicit
execution. Use a matching read delimiter; no automatic detection is introduced.

Restrict output separators instead of accepting every read separator: R's writer
leaves numeric and boolean fields unquoted, so letters/digits and punctuation used
in numbers could create ambiguous output. Text quoting still handles embedded
supported separators and doubled quotes. Header-only output remains supported.
Missing values still write as empty fields. No custom export missing marker,
append mode, new extension, dependencies, or public API is introduced. The packaged
csv-export example demonstrates export and re-import; its developer runner uses
a temporary directory. CSV remains unsuitable for guaranteed exact serialization.

## 2026-10-06 — CSV export missing marker

Status: implemented, experimental in 0.0.17. Add write ... with missing "N/A" so
missing entries can remain distinct from empty text on a matching read. Write
accepts one text literal, unlike read's marker list; default empty output remains
unchanged. Delimiter and missing options may appear once each, in either order.

R writes missing markers unquoted. Reject markers containing the final delimiter,
double quotes, carriage returns, or newlines during compilation, regardless of
option order. Preserve existing runtime type checks, overwrite protection, temporary
files, .csv suffix, and standalone output. No compilation-time data access.

Do not imply lossless serialization: real fields equal to a selected read marker
also become missing, including quoted text. Marker collisions are not detected;
users must choose a marker absent from real data. Numeric formatting, type inference,
and explicit read schemas retain their existing limits. Broader quoted-marker
semantics would change CSV parsing and need a separate design. No dependencies,
public exports, or append/overwrite mode are added.

## 2026-10-06 — Record-method first slice proposed

Status: proposed, not accepted or implemented. The
[record-method proposal](record-methods.md) describes nested fn declarations with
explicit self, value-returning updates, exact arguments, definition-time lookup
visibility, and source-located calls. It recommends ordinary private R functions
and existing record values rather than selecting a class backend. Unknown-receiver
dispatch, name collisions, scope, R boundaries, alternatives, and future verification
are specified for review. Mutable classes and interfaces remain separate designs.
No syntax, exports, dependencies, generated behavior, or package version changes.

## 2026-10-06 — Value record methods implemented

Status: accepted and implemented, experimental in 0.0.18. Adopts the record-method
proposal above: nested fn declarations after fields, explicit self, one return
expression, exact arguments, and copy-returning updates. Declaration-order visibility
is encoded as fixed candidate method IDs at each call site. Known receivers resolve
statically; unknown receivers dispatch by nominal record type within that fixed set.
Method signatures may differ between types. Receiver and arguments evaluate once
in source order before runtime dispatch, and body errors retain enclosing call chains.

Private runtime registries hold ordinary method functions and schemas; record values
retain existing list fields/tags and equality. Methods may call earlier methods,
functions, and constructors; their own constructor becomes visible only after the
record declaration. No recursion, forward references, mut self, bound method values,
new backend, dependencies, or exports. Layout validation is not provenance or deep
immutability for arbitrary R objects. See [record methods](record-methods.md).


## 2026-10-07 — Internal compiler refactored to R6

Status: accepted and implemented at the user's request. Compiler organization now
uses RSSCompiler and separate tokenizer, parser, analyzer, and generator classes.
Mutable cursors, symbol tables, method visibility, and helper tracking belong to
private stage state; grammar and inference helpers are private methods. Classes
remain internal, with existing rss_* adapters retained for focused tests.

This supersedes the R-bundled-only dependency policy for compiler implementation:
R6 is the one additional import. Runtime helpers remain ordinary functions, and
record values remain tagged lists. Generated programs require no R6. Public APIs,
source syntax, diagnostics, and execution boundaries remain unchanged. This does
not select a backend for proposed source-language classes.

Each stage resets state at the start of its operation and each compilation uses
fresh stages. For example, compiling x = 1 followed by a separate print x still
fails with an unknown-variable diagnostic; a failed function analysis cannot leave
its parameter scope in the next compilation. Reference-valued scope environments
are allocated per call, and cloning internal workers is disabled.

Keeping closure-based stages would avoid an external dependency, but would not
provide the requested class organization. Converting emitted runtime objects to
R6 would change record copying and introduce a runtime dependency, outside the
requested scope. Verification covers repeat calls, separate instances, failures,
unchanged generated output/diagnostics, and independent execution in a fresh R
process, in addition to the installed package suite and build/check workflow.

## 2026-10-07 — Mutable-class first slice proposed

Status: proposed, not accepted or implemented. Added the
[mutable-class proposal](mutable-classes.md) for scalar private fields, explicit
constructors, mut self assignment bodies, and standalone calls on mutable bindings.
It recommends value semantics: compute and validate a candidate, then replace only
the named receiver binding after success. Aliases remain unchanged; failed calls
must not commit partial receiver state. Earlier program effects are not rolled back.

The proposal distinguishes compiler-internal R6 from the source-language backend.
Tagged list values and private metadata are recommended for review; no backend is
selected or implemented. Generated programs must remain independent of R6. Includes
failure examples, R-boundary limits, alternatives, and a future verification checklist.
Field defaults, nesting, mutable parameters, interfaces, and inheritance remain
outside the proposed first slice. Current syntax, package version, and APIs are unchanged.


## 2026-10-07 — Scalar-field mutable classes implemented

Status: accepted and implemented, experimental in 0.0.19. Supersedes the proposal
status above following the request to continue implementation. Adopt private
Number/Text/Boolean fields, explicit all-field constructors, read-only return
methods, and mut self assignment methods. class becomes reserved. There are three
permissions: mutable binding, mutable field, and mutable receiver method.

Mutating calls are standalone statements on simple named mutable bindings. Evaluate
receiver and arguments once in source order, then validate dispatch, effects, and
signature. Sequential field assignments validate a candidate; only complete success
replaces the caller binding. For example, alias = counter remains unchanged after
counter.increment(1); a later invalid field assignment leaves counter unchanged too.
This does not roll back earlier program output/files.

Tagged list values and private metadata implement value semantics without a new
runtime dependency. Environment-backed references would change alias behavior;
automatic cloning would require an additional policy. Known and dynamic receivers
enforce privacy and effects, and declaration-order dispatch stays fixed. Classes
cannot use record equality/with updates or generic field access. Direct self.field
(and self."field") in the owning class is the supported private-read spelling.

No nested object fields, defaults, general statement bodies, mutable parameters,
interfaces, inheritance, external R-call bridge, or native R dollar-method API.
R can inspect/alter returned lists; layout validation is not provenance or deep
immutability. See the [class contract](mutable-classes.md) and PROGRESS.md for checks.
