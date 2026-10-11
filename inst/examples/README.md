# Packaged RStarStar examples

These examples use the implemented syntax in RStarStar 0.0.25. Start with
[basics.rsspps](basics.rsspps), then choose a topic:

| Example | Demonstrates |
| --- | --- |
| [read-csv.rsspps](read-csv.rsspps) | Column types, leading zeros, custom missing markers, and literal empty text |
| [filter.rsspps](filter.rsspps) | Outer variables, missing-value policies, and trimmed lowercase label matching |
| [grouped.rsspps](grouped.rsspps) | Summaries by one or multiple columns and a second aggregation |
| [functions.rsspps](functions.rsspps) | Positional/named arguments and conditional expressions |
| [standard-library.rsspps](standard-library.rsspps) | Absolute values, square roots, text length, trimming, and lowercase text |
| [records.rsspps](records.rsspps) | Typed values, copy updates, equality, expression fields, and nested records |
| [methods.rsspps](methods.rsspps) | Record methods, scalar constructor defaults, and named overrides |
| [classes.rsspps](classes.rsspps) | Private fields, constructor defaults, and explicit mutation with independent copies |
| [record-state.rsspps](record-state.rsspps) | Record-valued class state, snapshots, and whole-field updates |
| [csv-export.rsspps](csv-export.rsspps) | CSV round trip with a semicolon delimiter and a custom missing marker |
| [workflow.rsspps](workflow.rsspps) | CSV analysis, scalar summaries, and a PNG bar chart |

## Run an example from R

After installing the package, compilation returns R code without executing the
program:

```r
library(RStarStar)
path <- system.file("examples", "filter.rsspps", package = "RStarStar", mustWork = TRUE)
code <- transpile(path)
cat(code)
```

Data and output paths use R's working directory. This helper copies the bundled
data into a fresh temporary folder on every call, executes the selected example,
and returns both its bindings and the folder containing any output files:

```r
run_example <- function(name = "filter") {
  examples <- system.file("examples", package = "RStarStar", mustWork = TRUE)
  work <- tempfile("rstarstar-example-")
  dir.create(work)
  stopifnot(file.copy(file.path(examples, "data"), work, recursive = TRUE))
  previous <- setwd(work)
  on.exit(setwd(previous))
  values <- run_file(file.path(examples, paste0(name, ".rsspps")))
  list(values = values, directory = work)
}
result <- run_example("filter")
result$values$matching_regions
# Original labels " North " and "NORTH", with revenues 10 and 20.
```

Use `run_example("csv-export")` to create `sales-export.csv`, or
`run_example("workflow")` to create `revenue.png` (requires Cairo support in R).
The temporary folders remain available for inspection during the R session;
remove them with `unlink(result$directory, recursive = TRUE)` when finished.
Exports and charts refuse to overwrite existing files.

## Behaviors to notice

- Filtering cleaned labels preserves the original CSV strings. Omitting
  `skipping missing` from the label comparison fails on the missing label.
  Lowercase conversion follows the executing R locale.
- `with missing ["N/A"]` treats only `N/A` as missing; `with missing []`
  preserves every marker as text. Declaring such text as `Number` fails at execution.
- `Point()` in the methods example uses zero defaults; `Point(y: 4)` overrides
  one field. `Point(z: 4)` fails compilation because field names must match exactly.
- Record updates and class mutation preserve other copies. Values returned to R
  are ordinary tagged lists; these examples do not promise deep immutability in R.

The failing snippets above explain diagnostics; all `.rsspps` files here are
intended to run successfully with their bundled data and the stated chart support.
