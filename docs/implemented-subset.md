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
programs embed a self-contained loader; arithmetic-only output stays minimal. Compilation is not a sandbox
for later execution, nor are its binding checks enforced if generated R is edited.

Validated locally on R 4.6.0 on macOS arm64. A minimum R version and broader
compatibility matrix are not yet established. No external dependencies or package
installation are needed. Internal rss_* functions are not a stable public API.

## Grammar

```text
program    = { newline | statement newline }, [ statement ] ;
statement  = [ "mut" ], name, "=", expression
           | "print", expression
           | "read", text, "into", [ "mut" ], name,
             [ "with", "delimiter", text ] ;
expression = product, { ("+" | "-"), product } ;
product    = unary, { ("*" | "/"), unary } ;
unary      = ("+" | "-"), unary | primary ;
primary    = number | text | "true" | "false" | name
           | "(", expression, ")"
           | "[", expression, { ",", expression }, "]" ;
```

Statements are separated by newlines; the last newline is optional. Blank lines
are allowed. Newlines inside parentheses or brackets are ignored, so those
expressions may span lines. A # starts a comment outside text. Semicolons and
trailing commas are not supported. Multiplication and division bind more tightly
than addition and subtraction; binary operators associate left. Unary signs bind
more tightly than binary operators.

Names match [A-Za-z_][A-Za-z0-9_]* and are case-sensitive. The keywords mut, print,
true, false, read, into, with, and delimiter cannot be names. R keywords may be names; generated identifiers
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
All arithmetic operand lengths are known statically in this subset. Loaded table
columns are not accessible in expressions yet; that future feature will need
runtime checks for lengths and types not known at compilation.

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

Not implemented: filter/plot, column access, summaries, indexing, comparisons, conditions, functions,
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
collide with a source binding because dots are not allowed in source identifiers.
The output can be saved and run in a fresh R session without sourcing the compiler.
