# Implemented subset

This is the current executable prototype, implemented in base R. Other language
features in the [guide](language-guide.md) remain proposals. The interface and
language are experimental and may change.

## Run it

From the repository root, with R installed:

```sh
Rscript tests/run.R
Rscript examples/demo.R
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
uses base functions and requires no RStarStar runtime. Compilation is not a sandbox
for later execution, nor are its binding checks enforced if generated R is edited.

Validated locally on R 4.6.0 on macOS arm64. A minimum R version and broader
compatibility matrix are not yet established. No external dependencies or package
installation are needed. Internal rss_* functions are not a stable public API.

## Grammar

```text
program    = { newline | statement newline }, [ statement ] ;
statement  = [ "mut" ], name, "=", expression
           | "print", expression ;
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
true, and false cannot be names. R keywords may be names; generated identifiers
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

Inferred element types are Number, Text, and Boolean. Mutable bindings keep their
element type; their length may change, including between a scalar and a vector.
There are no annotations or explicit conversion operations yet.

## Vector and arithmetic rules

Vectors must be nonempty and homogeneous. Each element expression must have
length one; a length-one vector also qualifies. Multi-value elements and nested
containers are not supported. Scalars are length-one values, consistent with R.

Arithmetic requires numbers. Operand lengths must match or one operand must
have length one. General R recycling is rejected even when lengths divide evenly.
All lengths are known statically in this subset. A future data-loading feature
will need runtime checks for lengths and types that are not known at compilation.

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
are normalized to LF. Added runtime diagnostics are not implemented yet.

For example, x = 1 followed by x = 2 reports an immutable-reassignment error on
line 2. Undefined names, mixed vector types, nonnumeric arithmetic, and mismatched
vector lengths also fail before R generation.

Not implemented: read/filter/plot, indexing, comparisons, conditions, functions,
annotations, explicit conversions, records, classes, interfaces, and arbitrary
R calls. Input is parsed as RStarStar, never evaluated as R during compilation.
