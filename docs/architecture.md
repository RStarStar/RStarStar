# Architecture

R/transpile.R implements tokenization, parsing, semantic analysis, and R generation
for the initial subset using base R only. It exposes transpile(source, filename).
CSV programs embed a self-contained runtime loader and checked expression helpers
from the same file. The pipeline
below also describes how later features should fit; objects and interoperability
are not implemented. Package layout is undecided.

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
programs without CSV reads omit it and use direct R expressions. Data programs
use a private .rss helper environment for column lookup, checked arithmetic and
comparisons, vector construction, filtering, scalar summaries, chart rendering,
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
