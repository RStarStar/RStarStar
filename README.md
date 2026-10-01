# RStarStar

An approachable language for R that combines clear syntax with thoughtful
safeguards, helping users write reliable data analysis while retaining R's
expressive power and ecosystem.

RStarStar is an experimental transpiler **implemented in R** that translates its own
syntax into readable R code. It is for people who want to use R but find its
syntax difficult to approach. Prior programming experience is not required.

## Project status

**Compiler prototype.** Bindings, `mut`, literals, vectors, arithmetic, printing,
CSV loading, column access, filtering, scalar/grouped summaries, and PNG bar charts
transpile to readable R. Grouping supports multiple columns, such as region and
product. Functions and OOP remain future work.
The language is experimental, not a stable specification or installable package.
A source file extension and command-line interface have not been chosen.

## Try the implemented subset

With R installed, run these commands from the repository root:

```sh
Rscript tests/run.R
Rscript examples/demo.R
Rscript examples/read-csv.R
Rscript examples/filter.R
Rscript examples/workflow.R
Rscript examples/grouped.R
```

The toolchain uses base R with no external dependencies. See the
[implemented subset](docs/implemented-subset.md) for the API, grammar, and limits.

## What you can write now

Filtering uses explicit missing-value handling; grouped summaries combine repeated
regions. This example expects at least one retained row and nonmissing region
labels; chart output requires Cairo support in R:

```text
read "sales.csv" into sales
filter sales where revenue > 0 skipping missing into profitable_sales
print average(profitable_sales.revenue)
print sum(profitable_sales.revenue)
summarize profitable_sales by region with total = sum(revenue) into totals
plot totals x region y total as bar to "revenue.png"

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
