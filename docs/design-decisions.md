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
