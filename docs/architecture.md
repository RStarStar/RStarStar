# Architecture

R/api.R exports transpile(path) and run_file(path). The compiler entry point validates
and reads local UTF-8 .rsspps files, then delegates to the internal rss_compile()
in R/transpile.R. The compiler performs tokenization, parsing, semantic analysis,
and R generation. Internal rss_* functions are not exported.

CSV programs embed a self-contained loader and checked expression helpers.
Records with scalar/nested fields and classes with private scalar fields are implemented.
The explicit R interoperability bridge remains future work. The
compiler uses R6 alongside R-bundled dependencies; see the [package guide](r-package.md).

## Internal compiler classes

RSSCompiler in R/transpile.R coordinates RSSTokenizer (R/tokenize.R), RSSParser
(R/parse.R), RSSAnalyzer (R/analyze.R), and RSSGenerator (R/generate.R). Each stage
owns its private cursor, scope, or emission state and exposes one stage method.
Grammar helpers, inference, and expression emission are private R6 methods.
Every compilation creates fresh stages; each stage also resets state when reused,
including after a failed call. Reference-valued scopes are allocated per analysis,
never as shared class defaults. Cloning is disabled for these internal workers.

The internal rss_* stage functions remain small adapters for focused tests. No
classes are exported. R/runtime.R keeps the ordinary helper functions embedded
in generated programs, and R/standard-library.R supplies standalone operations.
R6 is needed to compile, but generated R and record values retain their existing
representation and need no R6 installation. Source-language classes likewise
use tagged values and standalone helpers. See the [R6 introduction](https://r6.r-lib.org/articles/Introduction.html)
for private members and reference semantics.

## Compilation pipeline

1. **Source and tokens:** recognize keywords, names, literals, and punctuation;
   preserve file names and source spans.
2. **Parser:** build an abstract syntax tree with source spans. Report malformed
   input using the user's vocabulary.
3. **Semantic analysis:** resolve names and check the supported binding, mutation,
   and type rules. Clearly distinguish known facts from runtime information.
4. **Lowering and R generation:** translate validated constructs into readable R,
   adding calls to runtime helpers only when necessary.
5. **Explicit execution:** let users save or run generated R as a separate action.
   Transpilation itself must not run input programs or load their data files.

Avoid implementing the language through a chain of text substitutions. Structured
syntax is needed for scope, useful errors, and reliable nested expressions.

## Runtime boundary

Some checks require execution: a CSV may be absent, a column may have an unexpected
type, or a condition may evaluate to a missing value. Generated checks should retain
enough source information to explain the original operation. Arbitrary R errors
may need to retain their underlying details when a trustworthy translation is not possible.

Generated output remains standalone: CSV programs embed a loader helper, while
programs without CSV reads omit the loader. Programs without CSV reads or
function definitions use direct R arithmetic expressions. Data programs
use a private .rss helper environment for column lookup, checked arithmetic and
comparisons, vector construction, filtering, scalar/grouped summaries, chart rendering,
and stable-type reassignment. Summary expressions embed checks even without CSV
input. Chart helpers call the bundled graphics/grDevices namespaces, require
Cairo, close their device, and publish a temporary image without overwriting
existing output.
Semantic analysis marks unknown column types/lengths for runtime checking; it
never inspects files. The loader validates structure and reports
source-located errors at execution time. Future helpers should preserve this
explicit boundary unless a later design decision changes the distribution model.

## Objects and interoperability

Specify observable object behavior before choosing an R backend. Check copying,
private access, constructors, nested values, and mutation through arguments.
Do not assume an R object system automatically satisfies our proposed semantics.

Calling R packages is essential to the longer-term design, but external objects
can have reference behavior or effects the compiler cannot infer. Define the
interop boundary explicitly before claiming mutation guarantees across it.

## Verification

- Parser cases should cover valid syntax and useful malformed-input errors.
- Semantic cases should cover scope, forbidden reassignment, and mutating calls.
- Integration cases should compare generated R behavior with expected results.
- Diagnostics should identify the relevant source location.
- Object cases should verify aliasing behavior, including nested state.
- Data cases should cover missing columns, malformed values, and missing data.

Run Rscript tests/run.R from the repository root. Rscript examples/demo.R shows
compilation and explicit execution. Object and data cases above become required
when those features are implemented. Record significant changes in PROGRESS.md.


Grouped summaries compile into descriptors for named aggregate columns. The
runtime validates columns, maps each typed grouping column to integer IDs with
unique/match, combines those collision-free IDs, and partitions row indices in
first-seen order. It reuses scalar summary checks for each group. No source expressions
are evaluated dynamically; only the supported aggregate descriptors are executed.


Function declarations create semantic parameter scopes containing only parameters
and previously declared function signatures. Bodies are checked without execution;
unknown parameter types/lengths require runtime checks. Emission uses ordinary R
functions and a checked call helper that evaluates arguments eagerly and appends
call locations to language errors. Function values and ambient variable capture
are rejected before generation. Embedded helper closures are created in base-R
parent environments, preventing user function names from shadowing dependencies.


run_file(path) delegates validation and whole-file compilation to transpile(path),
then evaluates generated R in a fresh environment parented by baseenv(). It returns
final bindings through mget(), excluding reserved compiler helpers. Returned function
closures retain that environment. Execution is explicit, with no caller injection,
working-directory changes, effect rollback, or external-call bridge.


CSV write statements validate a table binding during analysis and emit an embedded
runtime call. The writer uses utils::write.table on a temporary UTF-8 file, then
file.copy(overwrite = FALSE) to publish it. It checks column types, reports I/O
errors at the source statement, and cleans up the temporary file. Compilation
never inspects the destination; publication is not guaranteed atomic.


Conditional expressions retain both branches in the AST for semantic analysis.
Inference preserves matching branch types/sizes and otherwise records unknowns.
The generator emits native R if with an embedded scalar, nonmissing-boolean
validator; it never evaluates branches during compilation. Programs containing
conditionals use checked operations so dynamically selected types and lengths
cannot bypass vector, arithmetic, or reassignment rules.


Call AST nodes preserve argument labels, source tokens, and source order. Semantic
analysis matches exact labels to declared parameters and rejects duplicate bindings,
unknown names, and incorrect arity. Emission builds a list in source order, with
quoted exact argument names where supplied, and passes it to the existing eager
call helper. R's partial argument matching is never used to accept source calls.


Record declarations register a nominal type and field schema. Their generated
constructor functions call the embedded runtime validator and create ordinary named
lists with an internal rss_record_type attribute; no class dispatch backend is used.
Known field types participate in inference, and dynamic field lookup checks exact
names. Runtime type tags distinguish mutable bindings of different record types.
The plain-scalar/record-tree constructor boundary excludes foreign references;
external R mutation of returned values is outside the source-language guarantee.


Record updates are postfix AST nodes carrying receiver, field labels, replacement
expressions, and source spans. Analysis validates known schemas and defers unknown
receivers to runtime. The runtime checks receiver/name validity, evaluates replacement
values in source order, and validates a copied candidate through the existing record
constructor helper. No field of the original list is assigned. Internal type/order
metadata and unchanged fields are preserved; this is not a foreign-reference
copying policy.


Record equality is handled by the embedded binary-operation helper. Analysis permits
==/!= for compatible nominal types; dynamic checks enforce same-type records and
matching supported field layouts. Corresponding field comparisons reduce to false
on a definite mismatch, missing if otherwise uncertain, and true if all match.
Inequality negates that scalar result. Ordering remains rejected; no R class/operator
dispatch methods are registered.


General expression-result field access uses a member AST node containing the
receiver expression and exact field name. Postfix parsing composes it with record
updates while preserving the complete source span and dot location. Known record
schemas supply field types; unknown/table receivers use the existing runtime field
helper. Generation emits the receiver once. Original name.column nodes remain for
explicit table lookup and the restricted grouped-summary grammar.


Nested record annotations resolve against previously registered schemas; primitive
names are reserved for field typing. Inference carries canonical Record:Name field
types through construction and chained lookup. Generation passes canonical tags to
the embedded constructor. Runtime validation recursively accepts only supported
plain scalar/record trees; with updates reuse construction checks and equality
recursively reduces nested comparisons. Schema declaration order excludes recursive
types. This is not a provenance validator for arbitrary manually altered R values.

## Record methods

Method declarations reuse function-body parsing inside record nodes. Receiver calls
are postfix method_call nodes. Analysis registers each method after checking its
body, with self's nominal type and a frozen declaration-order view. Generation embeds
visible method IDs at each call; later declarations do not widen those candidates.
Private runtime registries store schemas and ordinary method closures, validate exact
receiver layouts/arguments, and route body errors through existing call-chain logic.
The shared exact argument matcher is embedded in standalone runtime code. Method
closures retain the program environment for earlier function calls; no methods are
added to record values and no R dispatch backend is registered.


## Mutable classes

Class nodes carry scalar/record schemas and mutable field names. Method nodes carry an
explicit effect; mutating bodies contain field_assign nodes with source spans.
Analysis scopes private field access to direct self receivers in the owning class.
Standalone mutation nodes require a mutable binding and a mutating method.
Method dispatch checks effects as well as nominal types and exact arguments.

Classes use rss_class_type tagged lists, separate from records. The runtime validates
plain scalar and recursively declared record layouts, plus field permissions. Each generated field assignment replaces
the method-local candidate; the caller binding receives the result only after the
complete checked method succeeds. Generic column access, equality, and record updates
reject classes. No reference backend or R6 runtime dependency is introduced.

Record and class scalar field literal defaults are validated by the analyzer and emitted as R
constructor parameter defaults. Constructor signatures track optional fields;
source calls still require exact names and positional declaration order. Defaults
do not capture user bindings or evaluate source during compilation.
