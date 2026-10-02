# Roadmap

Milestones describe outcomes, not release dates. The foundation and first
compiler subset are implemented; broader features remain pending. See
[PROGRESS.md](../PROGRESS.md) for verification and limitations.

## 0. Project foundation

- [x] Initial guide, design record, architecture outline, and contribution guidance.
- [x] Repository-wide agent instructions and existing MIT license.
- [ ] Review the proposed rules against beginner workflows and R behavior.

## 1. Define the smallest language subset — initial version complete

Agree on literals, arithmetic, bindings, mut, printing, comments, and source
locations. Write successful examples and expected errors. Decide numeric/vector
behavior needed by those examples, including length mismatches.

Done when this subset has unambiguous syntax and observable behavior recorded in
the design documents. OOP and file loading need not block this milestone.

## 2. First end-to-end transpiler — initial version complete

Implement tokens, parsing, binding checks, and readable R generation for the
agreed subset. Establish the R development layout and document actual checks.

Done when an example transpiles and its generated R produces the expected result,
while immutable reassignment fails with an appropriate source location. Keep
transpilation separate from execution.

The working subset is documented in [implemented-subset.md](implemented-subset.md).
The implementation is distributed as a local-installable R package, with a
file-only public API and installed-namespace behavioral tests.

## 3. A complete data-analysis workflow — initial version complete

- [x] CSV loading, optional delimiter, mutable targets, and source-located errors.
- [x] Column access, comparisons, compound predicates, and explicit missing-value filtering.
- [x] Scalar average/sum/count summaries and a saved PNG bar chart.

The workflow example now reads, filters, computes scalar summaries, and saves a
bar chart. The grouped-summary extension now combines repeated categories with
one or more grouping keys and multiple outputs. Configurable schemas and
additional chart types remain extensions.

Done when a small documented dataset can go from file to summary and chart, with
useful failures for absent files, missing columns, and invalid inputs.

## 3a. Package the working prototype — initial version complete

- [x] Add R package metadata, namespace exports, and API help pages.
- [x] Expose a .rsspps-file-only transpile() API, with path/content diagnostics.
- [x] Keep the raw-string compiler internal and migrate language examples to .rsspps.
- [x] Provide an R-session quickstart and packaged examples.
- [x] Adapt tests to the installed namespace and establish package build/check commands.
- [x] Choose supported R versions and document Cairo requirements for charts.

Done when a user can install the package locally, load it in an R session, and
transpile an example without sourcing repository files. Compilation must still
perform no program execution. R >= 4.1.0 is declared; verification beyond local
R 4.6.0 remains pending. No public CLI is planned. See the
[package plan](r-package.md); release hosting is a separate future decision.

## 4. Approachable objects — foundations in progress

- [x] Basic functions with parameters, a single return expression, and checked calls.
- [ ] Records, classes, constructors, and methods.

Implement records, classes, constructors, methods, and explicit mutation after
settling the object backend and value-semantics boundary. Define functions and
scope needed by methods as part of this work or an earlier milestone.

Done when the guide's record and Counter examples run, access rules hold, and
copying and nested mutation behave as documented.

## 5. Contracts and ecosystem access

- [x] Explicit run_file(path) execution and result/function transfer to R callers.
- [ ] External R calls, interfaces, and reference/mutation contracts.

Specify interfaces and explicit interoperability between .rsspps programs,
existing R functions/packages, and project APIs. R callers now receive
results/functions through run_file(path). Prototype interop
earlier if needed to avoid architectural dead ends.

Done when the Predictor example works and a documented external-package example
states exactly which checks and mutation guarantees apply.

## 6. Contributor-ready preview

Refine the R package installation and API documentation, automate the established
package checks, and document limitations and compatibility expectations. Choose
a release channel separately; public CLI conventions are outside the plan.

Done when a new contributor can follow the setup guide, run the checks, and make
a small change without relying on undocumented maintainer knowledge.
