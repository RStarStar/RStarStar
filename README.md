# RStarStar

An approachable language for R that combines clear syntax with thoughtful
safeguards, helping users write reliable data analysis while retaining R's
expressive power and ecosystem.

RStarStar is an experimental transpiler **implemented in R** that translates its own
syntax into readable R code. It is for people who want to use R but find its
syntax difficult to approach. Prior programming experience is not required.

## Project status

**Compiler prototype.** Bindings, `mut`, literals, vectors, arithmetic, printing,
CSV loading/export, column access, filtering, scalar/grouped summaries, and PNG bar charts
transpile to readable R. Grouping supports multiple columns, such as region and
product. User-defined functions and conditional expressions are supported; records, classes, and
interfaces remain future work.
The language and package API are experimental. RStarStar is now an installable
**R package**, with no public CLI. Its exported functions, transpile(path) and run_file(path),
accept local UTF-8 **.rsspps files only** for compilation or explicit execution.
The R-call bridge remains future work. See the [package guide](docs/r-package.md).

## Install locally and try it

From an R session with this repository as the working directory:

```r
install.packages(".", repos = NULL, type = "source")
library(RStarStar)
path <- system.file("examples", "basics.rsspps", package = "RStarStar")
code <- transpile(path)
cat(code)
```

To compile your own source, use transpile("analysis.rsspps"). Execution is a
separate, explicit R operation:

```r
results <- run_file(path)
results$adjusted
```

This is a local source installation, not a CRAN release. The package uses only
packages bundled with R. It declares R >= 4.1.0 and has been verified locally on
R 4.6.0. Automated checks are configured for R release on Linux/macOS/Windows
and R 4.1.0 on Linux; hosted results are still pending. PNG execution needs
Cairo support. See the [implemented subset](docs/implemented-subset.md) for syntax
and [Contributing](CONTRIBUTING.md) for package checks and developer demos.

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
write totals to "totals.csv"
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

- [R package guide](docs/r-package.md): installation, file API, and interoperability plans.
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

RStarStar is licensed under the [MIT License](LICENSE.md).
