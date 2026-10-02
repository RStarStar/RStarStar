# Architecture

R/api.R exports transpile(path) and run_file(path). The compiler entry point validates
and reads local UTF-8 .rsspps files, then delegates to the internal rss_compile()
in R/transpile.R. The compiler performs tokenization, parsing, semantic analysis,
and R generation. Internal rss_* functions are not exported.

CSV programs embed a self-contained loader and checked expression helpers.
Basic scalar-field records are implemented; classes and the explicit R interoperability bridge are not. The
package uses only R-bundled dependencies; see the [package guide](r-package.md).

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


Record declarations register a nominal type and scalar field schema. Their generated
constructor functions call the embedded runtime validator and create ordinary named
lists with an internal rss_record_type attribute; no class dispatch backend is used.
Known field types participate in inference, and dynamic field lookup checks exact
names. Runtime type tags distinguish mutable bindings of different record types.
The scalar-only, attribute-free constructor boundary excludes nested references;
external R mutation of returned values is outside the source-language guarantee.
