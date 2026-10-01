# RStarStar

An approachable language for R that combines clear syntax with thoughtful
safeguards, helping users write reliable data analysis while retaining R's
expressive power and ecosystem.

RStarStar is an experimental transpiler **implemented in R** that translates its own
syntax into readable R code. It is for people who want to use R but find its
syntax difficult to approach. Prior programming experience is not required.

## Project status

**Compiler prototype.** Bindings, `mut`, literals, vectors, arithmetic, printing,
and CSV loading transpile to readable R. Filtering, summaries, charts, and OOP
remain future work.
The language is experimental, not a stable specification or installable package.
A source file extension and command-line interface have not been chosen.

## Try the implemented subset

With R installed, run these commands from the repository root:

```sh
Rscript tests/run.R
Rscript examples/demo.R
Rscript examples/read-csv.R
```

The toolchain uses base R with no external dependencies. See the
[implemented subset](docs/implemented-subset.md) for the API, grammar, and limits.

## What the broader language could look like

CSV loading, bindings, and arithmetic work. The filter statement is still a proposal.

```text
read "sales.csv" into sales
filter sales where revenue > 0 into profitable_sales

scores = [72, 85, 91, 68]
adjusted = scores + 5

mut passing_score = 70
passing_score = 75
```

Our direction is to offer immutable bindings by default, explicit mutation,
inferred types, helpful errors, and approachable records and classes. We want
simple everyday syntax with more control available when needed. Functions and
tables should remain useful without learning OOP.

## Start here

- [Progress log](PROGRESS.md): significant changes and verification results.
- [Initial language guide](docs/language-guide.md): proposed syntax and behavior.
- [Design decisions](docs/design-decisions.md): direction, proposals, and unresolved questions.
- [Architecture](docs/architecture.md): a proposed implementation structure.
- [Roadmap](docs/roadmap.md): small milestones and completion criteria.
- [Contributing](CONTRIBUTING.md): how to participate, including with AI assistance.
- [Agent instructions](AGENTS.md): repository guidance for coding agents.

Start with the implemented subset, an example, or an open design question. Keep
significant implementation changes and their verification in PROGRESS.md.

## License

RStarStar is licensed under the [MIT License](LICENSE).
