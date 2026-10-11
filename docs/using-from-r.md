# Using RStarStar in your R projects

RStarStar is an experimental R package that translates `.rsspps` source files into
readable R. You use it from an R console, RStudio, or an ordinary `.R` script.
You can keep your existing R analysis and use RStarStar for selected parts of it.
There is no public command-line tool or CRAN release yet.

## 1. Get and install the package

You need R 4.1.0 or later. Local verification has used R 4.6.0 on macOS; the
configured cross-platform CI targets are not yet verified. RStudio is optional.

Get a local copy from the [repository](https://github.com/RStarStar/RStarStar).
Use GitHub's **Code → Download ZIP** and extract it, or run this in a terminal
with Git installed:

```sh
git clone https://github.com/RStarStar/RStarStar.git
```

In R, change the working directory to that downloaded repository folder. Replace
this example path with yours; the folder should contain `DESCRIPTION` and `R/`.

```r
setwd("/path/to/RStarStar")
if (!requireNamespace("R6", quietly = TRUE)) {
  install.packages("R6", repos = "https://cloud.r-project.org")
}
install.packages(".", repos = NULL, type = "source")
library(RStarStar)
packageVersion("RStarStar")
```

Choose a writable personal library if R prompts you. Install once, then use
`library(RStarStar)` in each new session. You can now work in your own project
folder; you do not need to keep the package repository as your working directory.
After updating the repository, reinstall it and restart R before trying new features.
`install.packages("RStarStar")` from CRAN is not currently the installation method.

## 2. Try a bundled example

Paste this into R:

```r
path <- system.file(
  "examples", "basics.rsspps",
  package = "RStarStar", mustWork = TRUE
)
cat(readLines(path), sep = "\n")

# Inspect generated R without running the source program.
code <- RStarStar::transpile(path)
cat(code)

# Explicitly execute and collect final variables/functions.
results <- RStarStar::run_file(path)
results$adjusted
# [1] 77 90 96 73
mean(results$adjusted)
# [1] 84
```

`transpile(path)` returns R source text. `run_file(path)` compiles the entire file,
then executes it and returns a named list. Source `print` statements also print in
your R console. Each run starts with fresh program bindings.

## 3. Put RStarStar beside your own R code

Create a project folder, open an R session there, and save these two files:

```text
my-analysis/
  analysis.rsspps
  main.R
```

Save the following as **analysis.rsspps**, using UTF-8 text and the exact lowercase
extension. It is RStarStar syntax, not ordinary R syntax:

```text
scores = [72, 85, 91, 68]
adjusted = scores + 5
average_score = average(adjusted)

fn add_tax(amount, rate) {
  return amount * (1 + rate)
}

fn clean_label(values) {
  return std::lower_text(std::trim_text(values))
}
```

Save the following as **main.R** and run it from your project directory:

```r
library(RStarStar)
results <- run_file("analysis.rsspps")

# Use ordinary R functions with returned values.
print(results$adjusted)
print(results$average_score)  # 84
summary(results$adjusted)

# Call RStarStar functions using data from your R session.
prices <- c(100, 200, 300)
with_tax <- results$add_tax(amount = prices, rate = 0.1)
print(with_tax)              # 110 220 330

labels <- c(" North ", "NORTH", NA_character_)
clean <- results$clean_label(labels)
print(clean)                 # "north" "north" NA

report <- data.frame(price = prices, with_tax = with_tax)
print(report)
```

From R, `source("main.R")` runs that script. You can also run
`Rscript main.R` from a terminal in the project folder; this uses R's normal script
runner, not a separate RStarStar CLI.

Returned functions keep their language checks, so `results$add_tax("100", 0.1)`
fails rather than silently converting text to a number. Direct calls from R use
R's argument syntax (`rate = 0.1`); inside `.rsspps` files, named calls use
`rate: 0.1`. Pass plain vectors when required: factors, named vectors, matrices,
and arbitrary R objects are not interchangeable with plain Text/Number values.
Lowercasing non-ASCII text follows the executing R locale.

Variables in your R session are **not automatically visible** inside a `.rsspps`
file. Pass them to returned functions as above. Calling arbitrary R functions or
packages from inside `.rsspps` source is not implemented. Use those packages in
your `.R` script with the returned values and tables.

## 4. Read a CSV and continue analysing in R

In the same project directory, create a small dataset using R:

```r
sales <- data.frame(
  region = c("North", "South", "West", "East"),
  revenue = c(120, 80, NA_real_, 0)
)
write.csv(sales, "sales.csv", row.names = FALSE, na = "NA")
```

Save this as **sales-analysis.rsspps**:

```text
read "sales.csv" into sales
filter sales where revenue > 0 skipping missing into positive_sales
total_revenue = sum(positive_sales.revenue)
mean_revenue = average(positive_sales.revenue)
```

Then use the results in R:

```r
sales_results <- RStarStar::run_file("sales-analysis.rsspps")
sales_results$total_revenue  # 200
sales_results$mean_revenue   # 100

# The returned table is an R data.frame.
positive <- sales_results$positive_sales
summary(positive)
positive$share <- positive$revenue / sum(positive$revenue)
print(positive)
```

You can pass `positive` to the R plotting, reporting, or modelling packages you
already use. No extra R package is needed for the examples above.

Relative dataset and output paths resolve from R's **current working directory**
by default, not from the source file's directory. Check `getwd()` when a CSV cannot
be found. To choose another existing data/output folder, use
`run_file("sales-analysis.rsspps", working_dir = "data-folder")`.
The source path still resolves from your current directory. RStarStar temporarily
uses the selected folder for execution and restores your directory afterward,
including on errors. Using an absolute source path alone does not select a data folder.

CSV exports and charts created by RStarStar refuse to overwrite existing outputs;
choose a fresh filename for repeated runs. RStarStar PNG charts need
`capabilities("cairo")` to be `TRUE`. The R `write.csv` call above follows R's own
file-writing behavior instead.

## 5. Save the generated R

You can inspect and save a program without executing it:

```r
code <- RStarStar::transpile("analysis.rsspps")
writeLines(code, "analysis-generated.R", useBytes = TRUE)
```

Later, execute that generated file explicitly in an R session:

```r
generated <- new.env(parent = baseenv())
sys.source("analysis-generated.R", envir = generated)
generated$adjusted
# [1] 77 90 96 73
```

Generated code includes the runtime helpers it needs and does not require
RStarStar or R6 to run. R itself is still required; data/chart programs retain
their file and graphics requirements. Editing generated R can bypass language
checks, so keep the `.rsspps` file as your source of truth.

## 6. Understand common errors

| Problem | What to check |
| --- | --- |
| `there is no package called 'RStarStar'` | Install the local repository into a library visible to this R session. |
| Source file not found | Check `getwd()`, `file.exists(path)`, and the exact filename. |
| Wrong source extension | Use lowercase `.rsspps`, not `.R`, `.txt`, or inline source text. Renaming R code does not translate it. |
| Immutable reassignment | Declare a changing source binding with `mut`, for example `mut total = 0`. |
| Filter contains missing values | Choose an explicit policy such as `skipping missing` or `is missing`. |
| Unexpected constructor or type error | Use exact argument names and the declared scalar/record types. |
| A new operation is unknown | Reinstall the latest local source and restart R. |

Language diagnostics include the original source filename, line, and column.
You can handle them from R:

```r
tryCatch(
  RStarStar::run_file("analysis.rsspps"),
  rstarstar_error = function(error) message(conditionMessage(error))
)
```

A compilation error prevents all program execution. A runtime error returns no
partial results; earlier prints or files are not rolled back. Execution is not a
sandbox for untrusted programs. Returned R objects can be modified in R; language
binding rules do not make arbitrary R objects deeply immutable.

## Next steps

- [Implemented subset](implemented-subset.md): executable syntax and limits.
- [Standard library](standard-library.md): numeric and text operations.
- [Package API contract](r-package.md): file handling and interoperability details.
- [Contributing](../CONTRIBUTING.md): bugs, patches, ideas, and AI-assisted contributions.
- Installed help: `?RStarStar::transpile` and `?RStarStar::run_file`.

The project is experimental and its API may change. Try it on small analyses and
share a reproducible example when something is confusing or incorrect.
