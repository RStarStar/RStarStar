# Implemented subset

This is the current executable prototype, implemented in R with internal R6
classes. Other language features in the [guide](language-guide.md) remain proposals. The interface and
language are experimental and may change.

## Run it

The user interface is the R package; see the [package guide](r-package.md).
From an R session in the repository root, install locally and compile an example:

```r
install.packages("R6") # Once, if not already installed
install.packages(".", repos = NULL, type = "source")
library(RStarStar)
path <- system.file("examples", "basics.rsspps", package = "RStarStar")
generated <- transpile(path)
cat(generated)
# Choose explicitly whether to execute:
results <- run_file(path)
results$adjusted
```

transpile(path) accepts one nonempty path to a regular local file with the exact
lowercase .rsspps suffix. Source must be UTF-8 (a BOM is accepted) without NUL
bytes. Empty programs are valid. Inline source, .R/.txt files, uppercase suffixes,
URLs, connections, and path vectors are not supported. Readable source diagnostics
use normalized absolute paths; input-validation errors retain the supplied path.

Compilation reads the source file only: it does not run the program, load datasets,
print program output, or write charts. Each call uses a fresh binding scope and
returns one R-source string. The internal rss_compile(source, filename) interface
is not exported or supported as a public API. Arbitrary R calls from RStarStar
remain future work; run_file(path) provides explicit execution and result transfer.

Generated R includes its runtime helpers and runs independently of the compiler.
Chart code uses the R-bundled graphics/grDevices packages. Compilation is not a
sandbox for later execution, and checks cannot protect generated R that is edited.
Relative dataset and chart paths use the execution working directory, not the
source-file directory. run_file(path, working_dir = directory) can select an
execution directory and restore the caller's directory afterward. Developer
runners in examples/ use packaged .rsspps files with explicit data directories.

The package declares R >= 4.1.0 and is tested locally on R 4.6.0/macOS arm64.
Earlier versions and other platforms are not yet verified. R6 is the compiler’s
sole dependency outside R-bundled packages; generated programs remain independent
of R6. PNG execution requires Cairo; chart rendering checks report explicit skips
without it. See CONTRIBUTING.md in the repository for installed
namespace tests and package build/check commands.

## Grammar

```text
program    = { newline | statement newline }, [ statement ] ;
statement  = "fn", name, "(", [ name, { ",", name } ], ")", "{",
             { newline }, "return", expression, { newline }, "}"
           | [ "mut" ], name, "=", expression
           | "print", expression
           | "write", name, "to", text, { "with", ("delimiter" | "missing"), text }
           | "read", text, "into", [ "mut" ], name,
             { "with", ( "delimiter", text | "columns", "{", (name | text), ":", name,
               { ",", (name | text), ":", name }, "}"
               | "missing", "[", [ text, { ",", text } ], "]" ) }
           | "filter", name, "where", expression, [ "skipping", "missing" ],
             "into", [ "mut" ], name
           | "summarize", name, "by", (name | text), { ",", (name | text) }, "with",
             grouped_result, { ",", grouped_result }, "into", [ "mut" ], name
           | "plot", name, "x", (name | text), "y", (name | text),
             "as", "bar", "to", text ;
grouped_result = name, "=", ("average" | "sum" | "count"), "(",
                 (name | name, ".", (name | text)), ")", [ "skipping", "missing" ] ;
expression = conjunction, { "or", conjunction } ;
conjunction = negation, { "and", negation } ;
negation   = "not", negation | comparison ;
comparison = sum, [ ("==" | "!=" | "<" | "<=" | ">" | ">="), sum
                 | "is", [ "not" ], "missing" ] ;
sum        = product, { ("+" | "-"), product } ;
product    = unary, { ("*" | "/"), unary } ;
unary      = ("+" | "-"), unary | primary ;
primary    = number | text | "true" | "false" | name | "@", name
           | name, "(", [ expression, { ",", expression } ], ")"
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
and, or, not, plot, summarize, fn, return, write, if, then, else, and record cannot be names. Other R keywords may be names; generated identifiers
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
error. Top-level declarations share one scope without redeclaration or forward
references. Functions have a separate parameter scope as described below. The right-hand
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

Not implemented: other chart types, general indexing, conditional statements, multi-statement functions,
function annotations, explicit conversions, recursive records, interfaces, and arbitrary
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
- By default, empty fields and exact NA become missing, including inside quotes. All-missing
  and zero-row columns are character vectors with unknown intended type.

No rows are dropped, missing values are not replaced with zero, and mixed columns
are not partly converted. Optional column types override inference as described
below. Missing-value markers can also be replaced explicitly.
The CSV loader reads the whole file into memory and is an initial implementation,
not a streaming or large-dataset engine.

### Explicit CSV column types

```text
read "codes.csv" into codes with columns {code: Text, amount: Number, active: Boolean}
read "codes.txt" into codes_again with delimiter ";" with columns {"product code": Text}
```

Each optional with clause appears at most once; delimiter, columns, and missing
may appear in any order. A columns block must contain at least one unique header/type pair,
separated by commas. Newlines inside the block and quoted headers are supported.
Types are exactly Text, Number, or Boolean; columns is contextual, not reserved.
Undeclared columns retain inference. Declared names must exist in the file header,
even for a zero-row file. Header matching is exact and case-sensitive.

Text preserves nonmissing field text, including leading zeros and surrounding
whitespace. Number accepts only the existing decimal/scientific syntax and finite
conversion results. Boolean accepts exactly true/false/TRUE/FALSE. No trimming or
conversion fallback occurs. By default, empty fields and exact NA are missing for
all types, including quoted fields. The missing option can replace these markers. Declared Number and Boolean
columns retain their types when empty or all missing.

```text
# If amount contains "unknown", execution fails with its column and data-row number.
read "sales.csv" into sales with columns {amount: Number}
```

Syntax/type-label errors fail compilation. Header mismatches and invalid values
fail only at execution, at the read statement's source location; data rows are
numbered from 1 excluding the header, including multiline quoted records as one
row. No partial table is returned. Compilation never reads the CSV. These types
control loading only; the analyzer still treats table-column types as unknown.
Mutable table reloads may specify different column types on each read.

### Custom CSV missing markers

```text
read "codes.csv" into codes with columns {code: Text} with missing ["", "N/A"]
read "literal-codes.csv" into literal_codes with missing []
```

The optional with missing clause replaces the default ["", "NA"] list for that
read only. Include every desired marker explicitly. In the first example, literal
NA stays text, while empty fields and N/A become missing. An empty list disables
marker recognition: empty fields and literal NA remain values. This [] is a read
configuration, not support for empty vector expressions elsewhere in the language.

Markers must be unique quoted text literals. Multiline lists and ordinary text
escapes are allowed. Matching is exact and case-sensitive, after CSV unquoting and
line-ending normalization, without trimming; quoted and unquoted fields follow
the same rule. Markers apply to data fields in all columns, never the header, and
are recognized before inference or declared conversion. Each read starts with the
defaults unless its own missing clause overrides them, including mutable reloads.

Preserved empty strings or NA text will fail a declared Number/Boolean conversion.
For example, with columns {amount: Number} with missing [] rejects an empty amount
instead of silently treating it as missing. Choosing numeric-looking markers such
as "0" intentionally makes those exact fields missing. No rows are dropped.

Malformed lists, duplicate markers, and repeated missing options fail compilation;
invalid converted data fails at execution with the existing read diagnostics.
Compilation still reads no CSV data. Per-column markers, expressions in option
lists, and distinguishing quoted markers from unquoted markers are unsupported.

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

CSV inference still governs undeclared empty and all-missing columns: these are
Text unless explicitly declared. A numeric comparison on a header-only or all-missing Text
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
operation even if a binding has the same name. These built-in calls are distinct from user-defined function calls; user functions
cannot use these three names. The entire parenthesized expression is the summary input. An optional
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
it with @name in the filter. Table-producing grouped summaries use a separate
summarize statement described below.

## PNG bar charts

```text
filter sales where revenue is not missing into complete_sales
plot complete_sales x region y revenue as bar to "revenue.png"
```

Plotting is a statement with no binding result. The x/y/as/bar/to words are
contextual markers, so ordinary variables named x or y remain legal. Each axis
specifies an exact column name or quoted header, not an expression. One bar is
drawn per row in source order. Labels must be unique after conversion to text;
repeated categories are rejected rather than summed implicitly. Use summarize
to combine repeated categories before plotting. Heights must be
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


## Grouped summaries

```text
summarize sales by region with total = sum(revenue) skipping missing, rows = count(revenue) into totals
print totals
plot totals x region y total as bar to "totals.png"
```

summarize accepts one or more comma-separated grouping columns and one or more
named aggregate outputs. Grouping columns must be unique.
The grouping column may be quoted; by is contextual, while summarize is reserved.
Outputs must have unique names different from every grouping column. Each result
must be average(column), sum(column), or count(column), with optional skipping
missing on that individual result. Quoted input headers use the qualified form,
for example sum(sales."Order total"). Bare inputs always refer to source columns,
not ordinary variables. Qualified inputs must name the source table. General
expressions, constants, external variables, nesting, and references to newly
computed output columns are not yet supported within grouped results.

Groups appear in first-seen order; grouping values retain their types. Missing
keys form a retained group, with no implicit dropping. Filter missing keys before
grouping if they should be excluded (or before charting, which rejects missing
labels). A single group is produced per distinct combination of keys using R's unique/match
value semantics for each column. Different missing-key combinations stay distinct.
Raw key values are never joined as text, avoiding separator collisions.

Each group's statistic follows the scalar summary rules. count(column) counts
all group rows; skipping missing counts nonmissing column values. Missing numeric
inputs require explicit skipping for sum/average. An all-missing numeric group
sums to zero when skipping; its average is an error. If any group fails, the
statement fails instead of producing a partial result. Type checks apply to the
entire input column, retaining the existing all-missing CSV Text inference rule.

Empty input produces a zero-row table with each grouping column's original type
and numeric summary columns. Input columns and types are still validated even
when empty. There is no invented empty group, so average is not evaluated when
there are zero groups. The source table is unchanged; target bindings follow
ordinary immutability and mut rules. Output can be filtered, summarized again,
or charted. This initial implementation groups in memory and does not claim
large-dataset performance. Output key columns appear in the order specified.


For example, summarize each region/product combination, then roll up again:

```text
summarize sales by region, product with total = sum(revenue) skipping missing into detail
summarize detail by region with total = sum(total) into totals
```

A missing region with product A and a missing region with product B are separate
groups. Filtering or charting grouped results follows the existing rules: a chart
still needs unique labels on its chosen x column. Multi-column grouping does not
implicitly create combined chart labels or grouped bars.


## User-defined functions

```text
fn add_tax(amount, rate) {
  return amount * (1 + rate)
}

print add_tax([10, 20], 0.1)
```

Functions are top-level declarations with unique names and parameter names. A body
contains exactly one return expression. Braces may share a line with the expression
or enclose it on separate lines; comments and blank lines around return are allowed.
Multiline return expressions must use parentheses/brackets, as elsewhere.

Calls use positional or named arguments with exactly the declared count, including
zero arguments. Named arguments use parameter: value; see the rules below. Arguments are evaluated once, left to right, before entering the body,
even when unused. Parameters are immutable local bindings; they can shadow outer
variable names without changing them. Functions accept scalar/vector/table values,
and may return those values. Types and lengths that are unknown from source are
checked at runtime by the same helpers used for loaded data.

Bodies can reference parameters, built-in summaries, and previously declared
functions. They cannot capture outer variables: pass needed data explicitly.
There are no forward references or recursion. Function names are immutable and
share the top-level declaration namespace. Functions cannot be copied into
variables, passed as values, or returned as values. A parameter shadowing an earlier
function cannot be called as a function. Built-in summary names cannot be used
for function definitions, though ordinary bindings may still use them.

```text
fn mean_revenue(data) {
  return average(data.revenue) skipping missing
}
read "sales.csv" into sales
print mean_revenue(sales)
```

Functions may be called inside filters. Call arguments follow the filter's existing
column/@variable rules; the function body itself uses parameter scope. Grouped
aggregate inputs remain restricted to columns and do not accept function calls yet.

Definitions are checked during compilation but bodies are never executed until
called in the generated R program. Body runtime errors retain their source location
and append call locations as they propagate. Argument errors retain their original
expression location. Runtime helpers are isolated from user functions so names
such as mean or c cannot replace implementation dependencies.

This first version excludes annotations, default arguments, nested functions,
closures, recursion, and assignments or other statements inside bodies. Record
methods use the same one-return body form; see the record-method section.
A function definition need not be followed by a call. A bare call as a top-level
statement is not yet supported: assign or print its result instead.


## Explicit execution API

run_file(path, working_dir = NULL) uses the same file contract as transpile(path), compiles the whole
file, then executes it in a fresh environment. It returns a named list of final
variables and callable functions, excluding runtime helpers. Printing and file
operations occur during execution; relative paths use the caller's working
directory by default. An optional working_dir selects an existing local directory
for execution and restores the caller's directory on return or error. Both source
and directory arguments resolve from the caller's directory; compilation precedes
directory selection. Invalid directories fail before program execution. The option
does not create directories or restrict access to other filesystem paths.
Errors propagate without partial results or rollback of earlier effects. See the
[package guide](r-package.md#explicit-execution-from-r) for result and scope rules.


## CSV export

```text
read "sales.csv" into sales
summarize sales by region with total = sum(revenue) skipping missing into totals
write totals to "totals.csv"
```

write is a reserved keyword. The input must be a declared table variable; the
output must be a quoted literal ending in .csv (case-insensitive). Export writes
UTF-8 data (comma-separated by default) with headers, LF line endings, no row names, and doubled
quotes inside quoted text. Numbers use R's standard write.table formatting with a
decimal point, booleans use TRUE/FALSE, and missing entries become empty fields by default.
Header-only output is supported. An optional with delimiter selects comma, semicolon,
tab ("\t"), or pipe ("|"). Other separators are rejected during compilation because
they could split unquoted numeric or boolean output. Append/overwrite modes remain
unsupported. A .csv output suffix is required for every supported delimiter.

```text
write sales to "sales-export.csv" with delimiter ";"
read "sales-export.csv" into restored with delimiter ";"
```

The delimiter must be quoted text, not a variable, and may be specified only once.
Quoted text fields safely retain embedded delimiters, quotes, and newlines. Import
does not detect separators automatically; choose the matching delimiter on read.

Use with missing "N/A" to choose the single text marker written for missing values.
Unlike read's marker list, write accepts one quoted literal. The default is "".
The missing and delimiter options may appear in either order, once each. Because
missing markers are written unquoted, the marker cannot contain the selected
delimiter, a double quote, carriage return, or newline. Validation uses the final
delimiter regardless of option order and fails before execution.

```text
write sales to "sales-export.csv" with delimiter ";" with missing "N/A"
read "sales-export.csv" into restored with delimiter ";" with missing ["N/A"]
```

Using only N/A on read preserves empty text and literal NA. However, genuine text
or other field values equal to N/A will also be read as missing, even if quoted;
choose a marker absent from real data. No collision detection is performed. These
options do not guarantee exact serialization, and numeric/type limits still apply.
For example, with missing "a;b" with delimiter ";" fails compilation.

Compilation checks syntax and known types but does not inspect or create the
output. Execution checks runtime table types and writes via a temporary file in
the destination directory. The directory must exist and an existing destination
is refused, including when it is also the input file. Errors point to the write
statement. Temporary files are cleaned up; publishing is not an atomic transaction
or a promise of crash recovery. Relative paths use the execution working directory.
For example, running the program twice reports an existing-output error on the
second run; choose a new filename explicitly.

CSV is a data-exchange format, not exact typed serialization. Re-reading without
explicit column types or missing markers applies the existing inference rules: empty text and the literal text NA become missing,
numeric-looking text can become numbers, and empty/all-missing columns become
Text. Standard numeric formatting can lose precision. Use the R values returned
by run_file() when preserving R types and precision matters.


## Conditional expressions

```text
fn safe_average(values) {
  return if count(values) == 0 then 0 else average(values)
}
answer = if true then 10 else 20
```

if condition then value else fallback is an expression, usable in assignments,
returns, arguments, vectors, and filter predicates. All three keywords are reserved;
programs that used them as identifiers must rename those bindings. Both branches
are required. Use parentheses to place a conditional inside a larger arithmetic
expression: 2 * (if flag then 10 else 20). Conditions and branch values accept
full expressions, and nested conditionals associate each else with its nearest
unfinished if. Wrap multiline conditionals in parentheses as with other multiline
expressions. There are no conditional statement blocks or loops yet.

Conditions must be exactly one nonmissing boolean. Known nonbooleans and known
vector conditions fail at compile time; runtime checks reject missing booleans,
empty vectors, and other dynamic invalid conditions. For example, if [true, false]
then 1 else 2 is an error. No truthiness conversion or per-element selection occurs.
In filters, ordinary bare-column and @variable lookup rules still apply; a table
column with multiple rows is therefore not a valid if condition.

The condition is evaluated once and only the chosen branch executes. Thus an
unchosen average of empty data cannot raise an execution error. Both branches are
parsed and analyzed, however: if true then 1 else unknown still reports the unknown
name. Branch expressions can return scalars, vectors, or tables, and may have
different types or lengths. Matching known branch types/lengths are retained by
inference; differing ones remain unknown until execution. Surrounding arithmetic,
vector construction, table operations, and mutable updates retain their runtime
checks. For example, adding 1 to a selected Text value or changing a mutable
Number binding to a selected Text value fails rather than coercing it.

Generated code uses R's lazy if expression plus a source-located condition check,
not vectorized ifelse(). Compilation never evaluates either branch. Function
condition errors retain their source location and language call-chain context.


## Named function arguments

```text
fn add_tax(amount, rate) {
  return amount * (1 + rate)
}
a = add_tax(rate: 0.1, amount: 100)
b = add_tax(100, rate: 0.1)
```

User-defined functions accept parameter: expression in calls. Names are exact and
case-sensitive, with no partial matching. Named arguments may appear in any order;
all positional arguments must precede them. Each positional argument supplies its
corresponding parameter in declaration order, and every parameter must be supplied
exactly once. There are no defaults or omitted parameters.

For example, add_tax(100, amount: 0.1) fails because amount was supplied twice;
add_tax(rate: 0.1, 100) fails because a positional argument follows a named one.
add_tax(amt: 100, rate: 0.1) fails rather than guessing that amt means amount.
The equals sign is still assignment syntax, not a named-argument separator.

Arguments evaluate once, from left to right in source order, before the function
body, including arguments the body does not use. Reordering names does not reorder
evaluation. Argument labels do not introduce variables or affect expression scope:
inside filters, use @variable for caller bindings as before. Body failures retain
source locations and language call-chain context.

This syntax applies to user-defined functions and record constructors. Built-in average, sum, and
count retain their single-input syntax and optional skipping missing modifier.
Function parameter declarations remain plain names; function annotations, default
values, recursive record fields, and the external R-call bridge are still future work. Functions
returned to R callers remain ordinary R closures with ordinary R call syntax.


## Records

```text
record AnalysisResult {
  label: Text
  mean: Number
}
result = AnalysisResult(mean: 145.8, label: "Sales")
print result.mean
```

record is reserved. A top-level declaration defines at least one uniquely named
field, one per line inside braces (a single field may share a line with the braces).
Fields require explicit Number, Text, Boolean, or earlier record-type annotations
and hold exactly one value of that type. Primitive fields are plain scalars; nested
fields hold record values. Integer, vectors, tables, and function-valued fields are not
supported as field declarations. Methods may follow all fields. A scalar missing value is allowed
when it has the required type; no nonmissing or finite-number constraint is added.

Scalar record fields may declare literal defaults: x: Number = 0,
label: Text = "Untitled", or active: Boolean = true. A number may have one sign,
and parentheses may surround a literal or signed number. Default types are checked
even for unused declarations. Variables, calls, vectors, and computed expressions
are rejected; x: Number = "zero" and x: Number = (1 + 2) fail at compilation.

The generated constructor requires every field without a default exactly once.
Exact named arguments may skip optional fields, including before a required field;
positional arguments keep declaration order. Explicit overrides use the same type
checks and evaluate once in written order. Nested record-valued fields remain
required: no constructor-call defaults or implicit construction are supported.
Copy updates preserve all unspecified current values rather than restoring defaults.
Returned R constructors expose the defaults under ordinary R calling rules.
Source constructor errors list omitted required fields in declaration order and
report the maximum argument count for overfull calls. Unknown or duplicate labels
in otherwise non-overfull calls are diagnosed before missing fields. For example,
Point(z: 3) identifies z instead of reporting only an argument-count mismatch.

```text
record Point {
  x: Number = 0
  y: Number = 0
}
origin = Point()
raised = Point(y: 3)
# Point(z: 3) fails: unknown parameter.
```

Constructors use ordinary source positional/named call rules. Constructors share the function/binding namespace,
cannot replace built-in summaries, and must be declared before use. Known wrong
types and lengths fail during analysis; unknown inputs are checked when constructed.
Constructor runtime errors point to the declaration and include the language call
location. For example, AnalysisResult(label: "Sales", mean: [1, 2]) fails because
mean requires one Number value. Both labels and values are checked without executing
source during compilation.

Read a field through variable.field or variable."field". Unknown fields fail rather
than partially matching. Functions can construct, accept, and return records, and
can use previously declared constructors without capturing ambient variables.
Field types inform inference when the record type is known. Direct field assignment
is unsupported. Reconstruct the value or use with to change it:

```text
mut current = result
current = AnalysisResult(label: "Revised", mean: 150)
print result.mean  # Still 145.8
```

A mutable record binding retains its declared record type, even if a different
record has the same field layout. Replacing current does not modify result.
Records support == and !=, but have no ordering, arithmetic, vector-element, or whole-record
missingness/summary behavior; operate on their fields instead. The with update expression creates a new validated value as described below.

Generated records are named R lists in declaration order, with an internal
rss_record_type attribute used by runtime checks. No S3/S4/R6 class backend is
selected; print uses base R list display. run_file() returns both records and
constructor functions. R callers use ordinary R calls and may modify those lists;
this representation is experimental and offers no deep-immutability or validation
guarantee after external modification. Direct R constructor calls require plain attribute-free primitive scalars or nested
record values with supported structure. Date, factor, matrix, environment, raw list,
complex, and attributed primitive fields remain unsupported. See the packaged records.rsspps and
examples/records.R demonstration.


## Record updates

```text
updated = result with { mean: 150, label: "Corrected" }
mut current = result
current = current with { mean: current.mean + 1 }
```

A with { field: expression, ... } expression copies a record and replaces selected
fields. At least one field is required. Field names must be unique and match exactly;
values must retain the field's declared type. Unspecified fields, declaration order,
and the nominal record type are preserved. The source record and any aliases stay
unchanged, including on failure. Rebinding an immutable variable still fails.

Separate fields with commas. Newlines are allowed after the opening brace, around
commas, and before the closing brace; multiline replacement expressions themselves
need parentheses as usual. Trailing commas are not supported. Updates bind to the
preceding primary expression, including a constructor call, function call, or a
parenthesized expression. They can chain: p with { x: 2 } with { x: 3 }. To update
an entire conditional result, use (if flag then a else b) with { x: 3 }.
A field can be read directly from the update result, for example
(p with { x: 3 }).x. See field access on expression results below.

All expressions are analyzed during compilation. At runtime the receiver is
evaluated first and must be a record; update names are then checked. Replacement
expressions evaluate once in written order before field validation and construction.
They use ordinary surrounding scope, with no implicit field variables and no view
of earlier replacements. Thus p with { x: p.y, y: p.x } swaps the original values.
An invalid dynamic field name fails before replacement expressions run. Replacement
expression errors keep their own locations; dynamic update validation errors point
to with and retain function call chains. Unchosen conditional branches remain lazy.

For example, p with { unknown: 1 } fails for an unknown field, while p with
{ x: "text" } fails if x is Number. An update inside a function can accept a record
parameter and returns a new record. Nested updates use explicit inner with expressions; no dotted update labels,
general table update, or foreign-object immutability policy is introduced. The existing experimental R
representation and external-mutation limits still apply.


## Record equality

```text
record Point {
  x: Number
  y: Number
}
a = Point(1, 2)
b = Point(y: 2, x: 1)
print a == b  # true
print a != (b with { x: 3 })  # true
```

== and != compare records of the same declared type and return one Boolean result.
Construction argument order and separate instances do not affect equality. Each
corresponding primitive field uses the existing equality operation, including exact
numeric comparison without a tolerance and ordinary text/boolean comparison.
Comparisons do not modify either record.

Missing values are not treated as matching values. If any field comparison is
false, record equality is false, even when another field comparison is missing.
If no field differs definitely but any comparison is missing, equality is missing.
Otherwise equality is true. != is the boolean negation, so a missing equality also
produces missing inequality. For example, Point(0 / 0, 1) == Point(0 / 0, 1) is
missing, while Point(0 / 0, 1) == Point(0 / 0, 2) is false. Test (a == b) is missing
explicitly when needed; an if condition still rejects a missing comparison result.

Different declared record types are incompatible even with identical field layouts;
comparison with a scalar or table is also an error. Ordering (<, <=, >, >=) remains
undefined and is rejected. Known incompatible operands fail during analysis;
dynamic operands fail at the comparison location with existing function call chains.
Runtime comparison also rejects mismatched field layouts or unsupported primitive
fields in externally modified R values, and recursively compares nested records. This is defensive validation, not a complete
foreign-object schema or immutability guarantee.

These operators are implemented by generated runtime calls. Direct use of R's ==
on returned raw lists is not this language feature; R callers can use a returned
function such as fn same(a, b) { return a == b }. Nested record equality follows the same reduction rules recursively.


## Field access on expression results

```text
record Point {
  x: Number
}
fn make_point(value) {
  return Point(value)
}
a = make_point(10).x
b = (Point(10) with { x: 20 }).x
```

.field or ."quoted field" may follow a constructor call, function call, parenthesized
expression, explicit @variable, or record update. It reads an exact record field
or table column from the resulting value. For example, average(copy(sales).revenue)
skipping missing works when copy returns the table. Quoted headers retain spaces
and punctuation. The receiver is evaluated once; accessing it never causes an
unchosen conditional branch to execute.

Field access and with updates are applied from left to right before arithmetic.
Use parentheses to select a whole conditional receiver: (if flag then a else b).x.
Suffixes may chain syntactically, but each intermediate value must be a table or
record. A scalar field cannot be a receiver, so Point(1).x.other is an error when x is
Number. Nested record fields and method calls can be chained. Vector indexing and
calls through field values remain unsupported. Known invalid receivers/fields fail at compile time; dynamic
failures retain source locations (the dot for expression-result access).

Existing table.column spelling retains its explicit table-variable lookup. Other
receiver expressions use ordinary expression scope: bare names inside filter
expressions are columns, and @name accesses a surrounding binding. For example,
copy(@sales).revenue refers to the outer sales table in a filter; copy(sales) would
look for a column named sales. Parenthesizing a bare name does not escape filter
scope. Grouped summaries retain their existing restriction to bare columns or
input_table.column; general expression-result access is not a grouped aggregate
input. Direct field assignment is still unsupported.


## Nested records

```text
record Point {
  x: Number
  y: Number
}
record Place {
  label: Text
  location: Point
}
home = Place("Home", Point(1, 2))
moved = home with { location: home.location with { x: 3 } }
print home.location.x   # 1
print moved.location.x  # 3
```

A field annotation may name an earlier record declaration. Constructors require
one value of that exact nominal type, and nested field access preserves schema
information where known. A structurally similar different record is not accepted.
Scalar/vector/table values cannot replace record fields. An entire nested field
cannot be missing; missingness belongs to correctly typed primitive fields inside it.

Declare dependencies first. Unknown annotations, forward references, self-recursive
and mutually recursive schemas fail at the annotation location. Number, Text, and
Boolean cannot be used as record declaration names, avoiding ambiguous field types;
ordinary bindings with those names remain allowed. These primitive type names are
not new lexer keywords. Integer is still not an implemented primitive type.

To change an inner value, use an inner with expression and replace the outer field.
Dotted replacement labels such as with { location.x: 3 } are unsupported. The inner
and outer originals and aliases retain their values, including when passed through
functions or on failed validation. Equality descends through matching nested record
types; at every level a definite mismatch wins over missing comparisons. Ordering
remains undefined. Direct field assignment remains unsupported.

The R representation remains nested named lists with internal nominal tags. Nested
constructor inputs are recursively checked against declared schemas: nominal type,
field names and declaration order, scalar leaf types, and supported attributes.
Copy updates validate the entire receiver before replacements and validate nested
replacements against the declared schema. An R-modified Point whose numeric x was
changed to text is rejected when passed to a containing constructor or used in a
with update, even if the update would replace x. Updates do not repair invalid
receivers. This is layout validation, not a provenance contract: a manually created
plain tagged list matching the schema can still be accepted.
Do not infer safe arbitrary-R interoperability or deep immutability outside the
language. Recursive schemas and vector/table fields remain
future work; no additional object backend or dependency is introduced.

## Bundled standard library

```text
magnitudes = std::absolute([-3, 0, 2])
roots = std::square_root(values: [0, 4, 9])
```

The numeric operations accept one plain numeric scalar/vector, preserving length and
missing values. square_root rejects negative nonmissing inputs at execution.
Only std:: is supported, with exact names and optional values: arguments. No
imports or new R exports are needed; emitted implementations run standalone.
See the [standard-library contract](standard-library.md) for the complete rules.

std::text_length(values) accepts plain Text scalars/vectors and returns a Number
for each character count. Empty text yields zero, missing text stays missing, and
empty text vectors yield empty numeric vectors. UTF-8 counts use Unicode code
points, not grapheme clusters or bytes. There is no normalization or automatic
conversion; invalid/byte-encoded text and attributed R inputs are rejected.

```text
lengths = std::text_length(values: ["A", "ABC", ""])
# Result: [1, 3, 0]
```

std::trim_text(values) returns Text of the same length after removing boundary
spaces, tabs, carriage returns, and newlines. Internal spacing and other Unicode
whitespace remain unchanged. Missing values stay missing; whitespace-only strings
become empty strings. Plain Text inputs, exact arguments, and encoding checks follow
the standard-library contract. Returned Text types participate in normal binding,
record, and expression checks.

```text
clean = std::trim_text([" A B ", "   "])
# Result: ["A B", ""]
```

std::lower_text(values) returns plain Text of the same length using R's tolower
and current LC_CTYPE locale. It preserves missing values, empty vectors, spaces,
and punctuation. It composes with trim_text for comparisons, for example
std::lower_text(std::trim_text(region)) == "north" inside a filter. Such predicates
do not modify stored table values. Exact arguments and text/encoding checks follow
the standard-library contract. Non-ASCII mappings can vary across locales/platforms;
no Unicode normalization, full case folding, or locale change occurs.

## Record methods

```text
record Point {
  x: Number
  fn shifted(self, dx) { return self with {x: self.x + dx} }
}
a = Point(3)
b = a.shifted(dx: 2)
# a.x is 3; b.x is 5.
```

Methods follow fields, require self first, and contain one return expression.
Fields and methods must have unique names within the record. Calls implicitly
supply self and follow exact positional/named argument rules. No mutable receivers,
field assignment, first-class methods, forward references, or recursion. Method
lookup is fixed at each call site's declaration position; dynamic receivers dispatch
only among those visible methods. Known receivers get static checks, unknown ones
get runtime checks. Receiver and arguments evaluate once in source order, before
runtime dispatch. Earlier methods/functions and constructors are usable; the current
constructor is available only after the record declaration completes.

Methods retain copy semantics and existing scalar-field constraints. Runtime checks
validate receiver layouts, including nested fields. Body errors include method and
ordinary function call locations. Records remain named lists with nominal tags;
helpers are excluded from run_file results and generated code stays standalone.
See the [full contract](record-methods.md) for scope, R boundaries, and failures.


## Mutable classes

```text
class Counter {
  mut value: Number
  fn current(self) { return self.value }
  fn increment(mut self, amount) { self.value = self.value + amount }
}
first = Counter(0)
mut second = first
second.increment(amount: 1)
print first.current()   # 0
print second.current()  # 1
```

class is reserved. Classes require at least one private Number, Text, Boolean, or
earlier record-type field before methods. Primitive fields hold plain scalars. Fields may have scalar literal defaults, for example
mut value: Number = 0 or label: Text = "Counter". Numbers may have one sign;
parentheses around literals are allowed. Defaults are type-checked during compilation;
variables, calls, vectors, and computed expressions are rejected. Fields without
defaults remain required. Exact positional/named arguments can override defaults;
positional arguments keep declaration order, so use names to skip optional fields.
Required fields may follow optional fields. Explicit arguments retain written
execution order, and each construction uses the defaults only for omitted fields.
Returned R constructors expose the same defaults under R's calling rules. Read-only methods have one return expression; mut self
methods have one or more self.field assignments to fields declared mut. Only direct
self.field or self."field" inside the owning class accesses private fields.

Mutating calls are standalone statements on named mutable bindings. Receiver and
arguments evaluate once in source order. Field assignments operate sequentially on
a candidate, checking types before each replacement. Only successful completion
replaces the caller binding; aliases retain their values, including on failure.
Record fields hold one value of their declared nominal type, including earlier
acyclic nested records. Assign a whole record using a constructor, a with copy, or
a read-only record method result. Direct nested assignment (self.position.x = 3)
is unsupported, and the outer field requires mut for replacement. Returned record
snapshots are independent values. Construction, receiver dispatch, and replacement
recursively validate declared record layouts and scalar leaf types, including inputs
from R callers. Record fields require explicit constructor arguments; no record
field defaults, nested classes, vectors, tables, or foreign references are supported.
See the packaged record-state.rsspps example.

Known effects/types are checked statically; unknown receivers use checked dispatch
within the call site's fixed visible method set. Methods have no outer data captures,
recursion, forward calls, or mutable parameters. Class equality, with updates,
computed defaults, custom constructors, and arbitrary statement bodies are unsupported.
Earlier program output/files are not rolled back on error.

Generated values are tagged lists, independent of R6. Privacy is a source rule:
R callers and base printing can inspect those lists. See the [class contract](mutable-classes.md)
for failures, evaluation order, and R boundaries, and the packaged classes.rsspps
example for executable usage.
