# Implemented subset

This is the current executable prototype, implemented in base R. Other language
features in the [guide](language-guide.md) remain proposals. The interface and
language are experimental and may change.

## Run it

From the repository root, with R installed:

```sh
Rscript tests/run.R
Rscript examples/demo.R
Rscript examples/read-csv.R
Rscript examples/filter.R
Rscript examples/workflow.R
```

In an R session at the repository root:

```r
source("R/transpile.R")
generated <- transpile("scores = [72, 85, 91, 68]\nprint scores + 5")
cat(generated)
# Choose explicitly whether to execute:
eval(parse(text = generated), envir = new.env(parent = baseenv()))
```

transpile() accepts one source string and an optional filename for diagnostics,
then returns a single R-source string. It does not run the program, print its
output, or write files. Each call starts with a fresh binding scope. Generated R
uses base functions and requires no separately installed RStarStar runtime. CSV
programs embed a self-contained loader and, when needed, checked expression
helpers; summaries also embed runtime checks, and charts use R's bundled
graphics/grDevices packages. Programs without data loading retain direct arithmetic output. Compilation is not a sandbox
for later execution, nor are its binding checks enforced if generated R is edited.

Validated locally on R 4.6.0 on macOS arm64. A minimum R version and broader
compatibility matrix are not yet established. No external dependencies or package
installation are needed. PNG charts require capabilities("cairo") to be true;
the full test suite includes chart rendering and therefore requires Cairo. Internal rss_* functions are not a stable public API.

## Grammar

```text
program    = { newline | statement newline }, [ statement ] ;
statement  = [ "mut" ], name, "=", expression
           | "print", expression
           | "read", text, "into", [ "mut" ], name,
             [ "with", "delimiter", text ]
           | "filter", name, "where", expression, [ "skipping", "missing" ],
             "into", [ "mut" ], name
           | "plot", name, "x", (name | text), "y", (name | text),
             "as", "bar", "to", text ;
expression = conjunction, { "or", conjunction } ;
conjunction = negation, { "and", negation } ;
negation   = "not", negation | comparison ;
comparison = sum, [ ("==" | "!=" | "<" | "<=" | ">" | ">="), sum
                 | "is", [ "not" ], "missing" ] ;
sum        = product, { ("+" | "-"), product } ;
product    = unary, { ("*" | "/"), unary } ;
unary      = ("+" | "-"), unary | primary ;
primary    = number | text | "true" | "false" | name | "@", name
           | name, ".", (name | text)
           | ("average" | "sum" | "count"), "(", expression, ")",
             [ "skipping", "missing" ]
           | "(", expression, ")"
           | "[", expression, { ",", expression }, "]" ;
```

Statements are separated by newlines; the last newline is optional. Blank lines
are allowed. Newlines inside parentheses or brackets are ignored, so those
expressions may span lines. A # starts a comment outside text. Semicolons and
trailing commas are not supported. Multiplication and division bind more tightly
than addition and subtraction; binary operators associate left. Unary signs bind
more tightly than binary operators. Comparisons bind less tightly than arithmetic,
then not, then and, then or. Comparisons cannot be chained; write x > 0 and x < 10.

Names match [A-Za-z_][A-Za-z0-9_]* and are case-sensitive. The keywords mut, print,
true, false, read, into, with, delimiter, filter, where, skipping, missing, is,
and, or, not, and plot cannot be names. R keywords may be names; generated identifiers
are quoted, and generated function calls explicitly use the base namespace.

Numbers start with a digit, have optional fractional digits (such as 1.25), and
an optional exponent (such as 1e-3). Signs are unary operators. Numeric literals
must be finite and use R double precision; no integer-specific type exists yet.
Double-quoted text supports escaped quotes, backslashes, and \n, \t, \r. Literal
newlines inside text and other escapes are rejected. Text may contain Unicode.
Booleans are true and false.

## Binding rules

The first assignment declares a name. Later assignments update it only if its
original declaration used mut. A second mut declaration of the same name is an
error. There is one scope and no shadowing or forward references. The right-hand
side can read the previous value during an update, but a declaration cannot read
its own not-yet-created binding.

```text
mut count = 1
count = count + 2
print count
```

Inferred element types are Number, Text, and Boolean. CSV loading creates a Table
binding; tables can be printed, aliased, and reassigned if mutable, but cannot be
used in arithmetic or as vector elements. Table schemas may change on reload. Mutable bindings keep their
element type; their length may change, including between a scalar and a vector.
There are no annotations or explicit conversion operations yet.

## Vector and arithmetic rules

Vectors must be nonempty and homogeneous. Each element expression must have
length one; a length-one vector also qualifies. Multi-value elements and nested
containers are not supported. Scalars are length-one values, consistent with R.

Arithmetic requires numbers. Operand lengths must match or one operand must
have length one. General R recycling is rejected even when lengths divide evenly.
Known types and lengths are checked during compilation. Column types and lengths
are checked at runtime, including when columns are assigned to other bindings.
The same vector, arithmetic, and mutable-type rules apply to loaded values.

```text
print [1, 2] + 10
print [1, 2] + [3, 4]
```

Results are [11, 12] and [4, 6], printed using base R's display format.
Division by zero and arithmetic overflow currently follow R (including Inf and
NaN); there is no missing-value literal or complete missing-data policy yet.

## Errors and limits

Language errors use class rstarstar_error and report filename:line:column.
Tokens and AST nodes retain source spans with exclusive end columns. Locations
count characters, with a tab counting as one character. CRLF and CR line endings
are normalized to LF. CSV runtime errors also use rstarstar_error and report the
read statement location; malformed CSV errors include a data-file line where
available.

For example, x = 1 followed by x = 2 reports an immutable-reassignment error on
line 2. Undefined names, mixed vector types, nonnumeric arithmetic, and mismatched
vector lengths also fail before R generation.

Not implemented: grouped summaries, other chart types, general indexing, conditional statements, user-defined functions,
annotations, explicit conversions, records, classes, interfaces, and arbitrary
R calls. Input is parsed as RStarStar, never evaluated as R during compilation.


## CSV loading

```text
read "sales.csv" into sales
print sales
read "archive.csv" into mut archive with delimiter ";"
read "updated.csv" into archive with delimiter ";"
```

Paths and delimiters currently must be text literals. Paths resolve relative to
R's execution working directory, not the source filename. Only existing local
files are accepted. Transpilation never opens them. The optional delimiter is
one ASCII character other than a quote or newline; comma is the default and tab
is supported. read, into, with, and delimiter are newly reserved keywords.

Files must be UTF-8; a UTF-8 BOM is accepted. The first row is the header, with
nonempty, unique column names preserved exactly. Every subsequent row must have
the same field count. Empty files, duplicate headers, malformed quoting, and
short/long rows produce errors. Blank records are not skipped: they are one empty
field and therefore valid only for a one-column table. Header-only tables work.

Double quotes enclose fields, doubled quotes escape a quote, and quoted fields
can contain delimiters and newlines. After a closing quote, only another quote,
a delimiter, a line ending, or EOF is valid. Whitespace is otherwise preserved;
it is not silently trimmed. Line endings normalize to LF inside quoted text.

Column inference considers all nonmissing values:

- Decimal/scientific numbers become R doubles, including numeric-looking values
  with leading zeros. Nonfinite numeric conversions are rejected.
- A column containing only true/false/TRUE/FALSE becomes logical.
- Other columns remain text; mixed numeric/text columns are not conversion errors.
- Empty fields and exact NA become missing, including inside quotes. All-missing
  and zero-row columns are character vectors with unknown intended type.

No rows are dropped, missing values are not replaced with zero, and mixed columns
are not partly converted. Explicit column schemas, alternate missing markers,
and preserving numeric-looking identifiers as text are not configurable yet.
The CSV loader reads the whole file into memory and is an initial implementation,
not a streaming or large-dataset engine.

Generated output embeds .rss_read_csv only when needed. That helper name cannot
collide with a source binding because dots are column-access punctuation, not
part of source binding names.
The output can be saved and run in a fresh R session without sourcing the compiler.


## Column access, comparisons, and filtering

```text
read "sales.csv" into sales
print sales.revenue
print sales."Order total"
minimum = 100
filter sales where revenue > @minimum skipping missing into selected
filter sales where revenue is missing into needs_review
```

Column lookup is exact, case-sensitive, and checked at execution. Missing columns
produce source-located errors rather than NULL or partial matches. Quote headers
with spaces, punctuation, or reserved keywords after the dot. Column access is
read-only; field assignment and general indexing are not supported.

Inside where, bare names always refer to the input table's columns, even if a
variable has the same name. Use @name for a declared variable; table.column also
works for explicit column references. Outside where, bare names are variables
and @name is an equivalent explicit spelling. There is no fallback from an
unknown column to a variable, preventing accidental name capture. References to
columns of another table are positional and require compatible lengths; filtering
does not align or join rows by keys.

Comparisons ==, !=, <, <=, >, >= operate element by element on matching types.
Equality supports numbers, text, and booleans; ordered comparisons support numbers
and text only. Text ordering follows the executing R session's locale. No implicit
text/number or boolean/number conversions occur. Lengths must match or one side
must be scalar. An empty vector with a scalar produces an empty result; an empty
vector with a nonscalar nonempty vector is a length error.

and, or, and not require booleans and use elementwise R logical behavior, including
its three-valued missing-value rules. They do not short-circuit. is missing and
is not missing work on scalar/vector values, including NA and NaN; they always
produce nonmissing booleans. Tables themselves cannot be tested this way.

The filter condition must be a boolean scalar (applied to every row) or have one
value per input row. A condition containing NA is an error by default. Explicit
skipping missing discards rows whose final condition is missing; it does not drop
rows merely because an unrelated column is missing. Alternatively, use a predicate
such as revenue is not missing and revenue > 0, or revenue is missing to retain
missing rows intentionally. Skipping does not suppress type or column errors.

Filtering preserves row order, column names/types, and table shape, even with zero
rows or a single column. Printed row numbers are reset. The original table remains
unchanged unless its mutable binding is the target. into mut declares a new mutable
target; existing targets follow ordinary reassignment rules.

CSV inference still governs empty and all-missing columns: these are Text until a
schema feature exists. A numeric comparison on a header-only or all-missing Text
column fails a type check; is missing works. By contrast, filtering all rows out
of an already numeric column preserves its numeric type.

Generated data programs embed .rss expression helpers to enforce runtime type,
length, missing-value, and mutation checks. No helper installation is necessary.
Failures point to the source column, operator, assignment, or filter statement.


## Scalar summaries

```text
average_revenue = average(sales.revenue) skipping missing
total_revenue = sum(sales.revenue) skipping missing
rows = count(sales)
known_values = count(sales.revenue) skipping missing
print average([1, 2, 3])
```

The built-in names average, sum, and count are recognized only when followed by
parentheses. They remain legal variable names, and calls still mean the built-in
operation even if a binding has the same name. This is not general function-call
support. The entire parenthesized expression is the summary input. An optional
skipping missing immediately afterward applies only to that summary.

average and sum require numeric input. Missing values (NA/NaN) cause an error
unless skipping missing is present. Remaining infinite values are errors, as is
a result outside the finite numeric range. An empty average, including after
skipping all values, is an error. An empty numeric sum is zero. All-missing CSV
columns still infer as Text: numeric summaries reject them even when skipping.

count(vector) includes missing entries by default; skipping missing excludes
them. count(table) returns the number of rows; skipping missing on a table is an
error because no column policy was specified. Every summary returns a numeric
scalar. Empty vectors/tables count as zero. Numeric input types are checked
statically where known and otherwise at runtime; missingness is checked at runtime.

Summaries work inside filter predicates with the same bare-column/@variable rules.
An outer filter's skipping missing is separate from a summary's option. To avoid
two adjacent skipping clauses, compute a summary in a variable first and refer to
it with @name in the filter. Group-by and table-producing summaries are deferred.

## PNG bar charts

```text
filter sales where revenue is not missing into complete_sales
plot complete_sales x region y revenue as bar to "revenue.png"
```

Plotting is a statement with no binding result. The x/y/as/bar/to words are
contextual markers, so ordinary variables named x or y remain legal. Each axis
specifies an exact column name or quoted header, not an expression. One bar is
drawn per row in source order. Labels must be unique after conversion to text;
repeated categories are rejected rather than summed implicitly. Heights must be
finite numeric values. Missing labels/heights and empty tables are errors; filter
them explicitly first. Negative and zero heights are supported.

Output is a 1200-by-800 PNG, using R's Cairo device. The installed R build must
report capabilities("cairo") as true; other formats and renderers are not yet
supported. Paths are literal text, end in .png (case-insensitive), and resolve
from the execution working directory. The parent directory must exist. Existing
files are not overwritten. Drawing uses a temporary file in that directory and
publishes it only after the graphics device closes; temporary files are cleaned
up. The compiler never creates images or opens devices during transpilation.

Titles and axis labels come from the selected column names. Styling, label-layout
controls, grouped bars, and large-category-count layout are not configurable yet.
Device errors are reported with the plot statement's source location. Font
availability depends on the R installation. The demo runner writes a uniquely
named image under examples/output/ by default, or accepts an explicit new PNG
path as its sole argument. Generated example output is ignored by Git.
