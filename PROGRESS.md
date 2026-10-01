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
