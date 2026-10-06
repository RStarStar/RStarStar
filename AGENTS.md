# Agent instructions

These instructions apply throughout this repository. Read README.md,
CONTRIBUTING.md, and the relevant documents in docs/ before making changes.

## Project intent

- Build a language that transpiles to readable R, with the toolchain written in R.
- Deliver it as an R package used from R sessions. Follow docs/r-package.md; a
  public CLI is not planned unless the user explicitly revisits that decision.
- The public source API accepts local UTF-8 .rsspps files only. Keep raw-string
  compilation internal; preserve interoperability with existing R
  code, packages, tooling, and documented project APIs as described in the plan.
- Serve beginners to R with concise syntax and understandable diagnostics.
- Preserve useful R concepts and access to its ecosystem.
- Keep ordinary analysis usable without classes, interfaces, or type annotations.
- Prefer a small coherent design over adding features because other languages have them.

## Current stage

An installable R package and behavioral tests exist. transpile(path) and run_file(path) are
exported. Packaged source examples live in inst/examples/; tests run against the
installed namespace, with internal compiler cases kept under tests/cases/. Read docs/implemented-subset.md
for executable syntax and limits. Do not describe proposals as implemented
features or invent successful checks. Broader syntax in the guide is provisional. Consult docs/design-decisions.md for status;
do not silently promote an unresolved choice into a language guarantee.

## Making changes

- Keep changes focused on the requested task; preserve unrelated user changes.
- Record every significant implementation change in PROGRESS.md with its scope,
  verification results, and remaining limitations. Keep the history accurate.
- Update the guide, decision record, and roadmap when an accepted design changes.
- Explain behavioral tradeoffs with small examples, including failure cases.
- Do not introduce dependencies, an object-system backend, a source extension,
  or a public CLI merely to make the scaffold look complete.
- Do not execute user source during parsing or semantic analysis. Execution
  must be an explicit step separate from transpilation.
- Preserve source locations so future diagnostics can refer to RStarStar code.
- Never promise deep immutability or safe interoperability with arbitrary R
  objects without an implemented, verified policy.
- Keep the MIT license and avoid committing credentials, local environments,
  generated build output, or private datasets.

## Verification and reporting

For documentation, check relative links, example consistency, and git diff
whitespace. Reinstall the changed package before running Rscript tests/run.R from
the repository root. Validate package changes with R CMD build . and
R CMD check --no-manual RStarStar_0.0.17.tar.gz (use the current version).
Rscript examples/demo.R demonstrates explicit compilation and execution. Add
focused semantic and integration checks for new behavior. Tests should verify
behavior, diagnostics, and generated R results rather than only mirror
implementation details. Dependencies are limited to R-bundled packages. Chart
rendering tests explicitly skip when Cairo is unavailable; report skipped coverage.

Report what changed, what was checked, and any remaining uncertainty. AI-assisted
contributions follow the same correctness and review standards as other work.
