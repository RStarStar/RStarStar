# Agent instructions

These instructions apply throughout this repository. Read README.md,
CONTRIBUTING.md, and the relevant documents in docs/ before making changes.

## Project intent

- Build a language that transpiles to readable R, with the toolchain written in R.
- Serve beginners to R with concise syntax and understandable diagnostics.
- Preserve useful R concepts and access to its ecosystem.
- Keep ordinary analysis usable without classes, interfaces, or type annotations.
- Prefer a small coherent design over adding features because other languages have them.

## Current stage

This is a documentation-only design scaffold. No compiler or test runner exists.
Do not describe proposals as implemented features or invent successful checks.
Syntax in the guide is provisional. Consult docs/design-decisions.md for status;
do not silently promote an unresolved choice into a language guarantee.

## Making changes

- Keep changes focused on the requested task; preserve unrelated user changes.
- Update the guide, decision record, and roadmap when an accepted design changes.
- Explain behavioral tradeoffs with small examples, including failure cases.
- Do not introduce dependencies, an object-system backend, a source extension,
  or a public CLI merely to make the scaffold look complete.
- Do not execute user source during parsing or semantic analysis. Future execution
  must be an explicit step separate from transpilation.
- Preserve source locations so future diagnostics can refer to RStarStar code.
- Never promise deep immutability or safe interoperability with arbitrary R
  objects without an implemented, verified policy.
- Keep the MIT license and avoid committing credentials, local environments,
  generated build output, or private datasets.

## Verification and reporting

For documentation, check relative links, example consistency, and git diff
whitespace. No R build or test command is available yet. Once implementation
exists, document real commands and use focused semantic and integration checks.
Tests should verify behavior, diagnostics, and generated R results rather than
only mirror implementation details.

Report what changed, what was checked, and any remaining uncertainty. AI-assisted
contributions follow the same correctness and review standards as other work.
