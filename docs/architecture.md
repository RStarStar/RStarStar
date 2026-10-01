# Proposed architecture

This is an implementation outline, not a description of existing code. The
toolchain will be written in R; package layout and dependencies are undecided.

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

Generated output should be inspectable and reproducible. If helper functions are
required, document how output obtains them; standalone output versus a runtime
dependency remains an open decision.

## Objects and interoperability

Specify observable object behavior before choosing an R backend. Check copying,
private access, constructors, nested values, and mutation through arguments.
Do not assume an R object system automatically satisfies our proposed semantics.

Calling R packages is essential to the longer-term design, but external objects
can have reference behavior or effects the compiler cannot infer. Define the
interop boundary explicitly before claiming mutation guarantees across it.

## Verification once code exists

- Parser cases should cover valid syntax and useful malformed-input errors.
- Semantic cases should cover scope, forbidden reassignment, and mutating calls.
- Integration cases should compare generated R behavior with expected results.
- Diagnostics should identify the relevant source location.
- Object cases should verify aliasing behavior, including nested state.
- Data cases should cover missing columns, malformed values, and missing data.

Choose and document real tooling with the first implementation. There is no build
or test command to run at this stage.
