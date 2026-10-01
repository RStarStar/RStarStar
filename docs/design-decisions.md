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

The file extension, package layout, supported R versions, dependency policy, CLI,
and object backend are unchosen. Do not assume S3, S4, R6, or another system is
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
