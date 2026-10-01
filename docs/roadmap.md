# Roadmap

Milestones describe outcomes, not release dates. Except for the initial scaffold,
all work below is pending. Revise scope as examples reveal design problems.

## 0. Project foundation

- [x] Initial guide, design record, architecture outline, and contribution guidance.
- [x] Repository-wide agent instructions and existing MIT license.
- [ ] Review the proposed rules against beginner workflows and R behavior.

## 1. Define the smallest language subset

Agree on literals, arithmetic, bindings, mut, printing, comments, and source
locations. Write successful examples and expected errors. Decide numeric/vector
behavior needed by those examples, including length mismatches.

Done when this subset has unambiguous syntax and observable behavior recorded in
the design documents. OOP and file loading need not block this milestone.

## 2. First end-to-end transpiler

Implement tokens, parsing, binding checks, and readable R generation for the
agreed subset. Establish the R development layout and document actual checks.

Done when an example transpiles and its generated R produces the expected result,
while immutable reassignment fails with an appropriate source location. Keep
transpilation separate from execution.

## 3. A complete data-analysis workflow

Define and implement CSV loading, filtering, a summary, and a simple chart.
Resolve column lookup, file parsing, and missing-data policies for that workflow.

Done when a small documented dataset can go from file to summary and chart, with
useful failures for absent files, missing columns, and invalid inputs.

## 4. Approachable objects

Implement records, classes, constructors, methods, and explicit mutation after
settling the object backend and value-semantics boundary. Define functions and
scope needed by methods as part of this work or an earlier milestone.

Done when the guide's record and Counter examples run, access rules hold, and
copying and nested mutation behave as documented.

## 5. Contracts and ecosystem access

Specify interfaces and explicit R-package interoperability. Prototype interop
earlier if needed to avoid architectural dead ends.

Done when the Predictor example works and a documented external-package example
states exactly which checks and mutation guarantees apply.

## 6. Contributor-ready preview

Choose supported R versions, installation and CLI conventions, automate the
established checks, and document limitations and compatibility expectations.

Done when a new contributor can follow the setup guide, run the checks, and make
a small change without relying on undocumented maintainer knowledge.
