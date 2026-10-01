# RStarStar

An approachable language for R that combines clear syntax with thoughtful
safeguards, helping users write reliable data analysis while retaining R's
expressive power and ecosystem.

RStarStar is a planned transpiler **implemented in R** that translates its own
syntax into readable R code. It is for people who want to use R but find its
syntax difficult to approach. Prior programming experience is not required.

## Project status

**Design stage.** There is no parser, compiler, runtime, or installable package
yet. All RStarStar examples are proposals, not executable programs or a stable
language specification. The project name is RStarStar; a source file extension
and command-line interface have not been chosen.

## What writing it could look like

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

- [Initial language guide](docs/language-guide.md): proposed syntax and behavior.
- [Design decisions](docs/design-decisions.md): direction, proposals, and unresolved questions.
- [Architecture](docs/architecture.md): a proposed implementation structure.
- [Roadmap](docs/roadmap.md): small milestones and completion criteria.
- [Contributing](CONTRIBUTING.md): how to participate, including with AI assistance.
- [Agent instructions](AGENTS.md): repository guidance for coding agents.

Start by discussing an example or clarifying an open design question. There are
currently no installation, build, or test commands. Implementation will begin
with a small end-to-end subset after its behavior is agreed.

## License

RStarStar is licensed under the [MIT License](LICENSE).
