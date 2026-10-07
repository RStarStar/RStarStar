# Initial language guide

This guide explores the intended experience. **Bindings, mut, literals, vectors,
arithmetic, printing, CSV loading/export, column access, filtering, scalar/grouped summaries,
PNG bar charts, simple user-defined functions, conditional expressions, records, and scalar-field classes now work.** See the [implemented subset](implemented-subset.md) for exact working
syntax and [design decisions](design-decisions.md) for open proposals.

The R package provides transpile(path) for compilation and run_file(path) for
explicit execution with variables and functions returned to R. Both accept only
local UTF-8 .rsspps files; see the [package guide](r-package.md).
The compiler implementation uses internal R6 classes. This does not change source
syntax or record value semantics; generated R runs without R6.

## Bundled standard library

The package includes experimental std::absolute(values) and std::square_root(values)
for plain numeric scalars and vectors. Missing values propagate; negative square
roots fail at execution. std::text_length(values) counts characters in plain text,
preserving missing values and vector length. std::trim_text(values) removes boundary
spaces, tabs, carriage returns, and newlines from text. Only required implementations are embedded in standalone
generated R. There are no new R exports or dependencies. See the
[standard-library contract](standard-library.md) for examples and limits.

## Read and transform data

```text
read "sales.csv" into sales
filter sales where revenue > 0 into profitable_sales
```

Preserve numeric-looking identifiers by choosing a column type when loading:

```text
read "codes.csv" into codes with columns {code: Text}
lengths = std::text_length(codes.code)
```

Only named columns override inference. Text, Number, and Boolean are supported;
invalid declared values fail at execution. Replace default missing markers explicitly
when a dataset uses a different convention:

```text
read "codes.csv" into codes with columns {code: Text} with missing ["", "N/A"]
```

Here NA is ordinary text. Use with missing [] to recognize no markers; preserved
empty strings still fail declared Number/Boolean conversion. See the
[missing-marker contract](implemented-subset.md#custom-csv-missing-markers).


Sentence-like commands express actions; ordinary expressions express calculations.
The filter example assumes a numeric revenue column with no missing values.
Bare names in a filter refer to columns. Use @minimum to refer to a variable,
or sales.revenue for explicit column access. If the condition contains missing
values, filtering reports an error unless skipping missing appears before into.
Use revenue is missing to select those rows deliberately. CSV and filter errors
refer to the original source location. See the implemented subset for exact rules.

CSV loading supports an optional delimiter:

```text
read "sales.csv" into sales with delimiter ";"
```

The loader reads local UTF-8 CSV files with headers. It infers numeric, boolean,
or text columns, preserves missing values, and rejects malformed rows. See the
[implemented subset](implemented-subset.md#csv-loading) for exact inference and
missing-value rules. Schemas and other file formats remain future work.

Save a table after analysis with an explicit write statement:

```text
write profitable_sales to "profitable-sales.csv"
```

This executes only when the program runs. The destination directory must exist;
existing files are refused. CSV export uses UTF-8, comma separators, and empty
fields for missing values. Re-reading infers types again, so it is not exact typed
serialization. See [CSV export](implemented-subset.md#csv-export) for details.

## Bindings and mutation

```text
scores = [72, 85, 91, 68]
adjusted = scores + 5

mut passing_score = 70
passing_score = 75
```

The implemented arithmetic retains R's element-by-element behavior. For this small
example, equivalent R is shown below (the generator additionally quotes names
and qualifies base functions):

```r
scores <- c(72, 85, 91, 68)
adjusted <- scores + 5
passing_score <- 70
passing_score <- 75
```

Immutability is a rule enforced by the toolchain; ordinary R assignment does not
enforce it. Assigning to scores again produces a source-located error such as:

```text
Cannot reassign 'scores'.
Declare it with 'mut' if you intend to change it,
or choose a new name for this result.
```

An indexed update would also require a mutable binding. This is not a promise
that arbitrary external R objects are deeply immutable. The current subset has one scope: the first assignment declares a binding and
later assignments require it to be mutable. Indexing is not implemented.

Mutable loading is supported:

```text
read "sales.csv" into mut sales
```

## Types and conditions

Infer types in ordinary code; allow annotations where they help express a contract.
Text-to-number conversion should be explicit. Proposed conditions require one
non-missing boolean. Checks involving file contents may happen at runtime, while
checks supported by known source information can happen before execution.

The current subset infers Number (R double), Text, and Boolean, and keeps mutable
element types stable while allowing length changes. Annotations, Integer, and
conditional statements remain proposals. Comparisons and boolean expressions work. See the implemented subset for arithmetic limits.

## Missing data

Numeric summaries reject missing values unless skipping is explicit:

```text
print average(sales.revenue) skipping missing
```

average() and sum() require numeric inputs. After optional missing-value removal,
an empty average is an error and an empty numeric sum is zero. count() counts
vector entries including missing values, or table rows; count(column) skipping
missing counts nonmissing entries. These built-ins use parentheses to make their
input boundaries explicit. Grouped summaries produce a table:

```text
summarize sales by region with total = sum(revenue) skipping missing, rows = count(revenue) into totals
```

Groups stay in first-seen order, including a group for missing keys. Each output
has its own missing-value policy. Multiple grouping columns are comma-separated, such as by region, product;
see the implemented subset for empty-input and naming rules.

## Save a chart

```text
filter sales where revenue is not missing into complete_sales
plot complete_sales x region y revenue as bar to "revenue.png"
```

The first chart feature saves a PNG with one bar per row. It requires unique
category labels and finite numeric heights, rejects missing plotted values, and
never overwrites an existing file. Cairo support in the installed R build is
required. See the implemented subset for output and empty-table behavior.

## Reuse a calculation

```text
fn add_tax(amount, rate) {
  return amount * (1 + rate)
}
print add_tax([10, 20], 0.1)
print add_tax(rate: 0.1, amount: 100)
```

Calls may name parameters with name: value, using exact names. Positional arguments
come first; named arguments can then appear in any order. Each parameter is required
exactly once. See [named arguments](implemented-subset.md#named-function-arguments).

The initial function form has parameters and a single return expression. Pass
needed data explicitly; functions do not capture outer variables. Functions may
call previously declared functions. Annotations, general multi-statement bodies, and recursion remain proposals.
Mutating class methods support restricted field-assignment bodies. The typed functions in the OOP examples below
are therefore not executable yet.

## Choose a result

```text
fn safe_average(values) {
  return if count(values) == 0 then 0 else average(values)
}
```

The condition must be exactly one nonmissing boolean. Only the chosen branch
runs, so empty inputs above never reach average(). Both branches are still checked
for syntax and names during compilation. This chooses one whole value; it does
not make a separate choice for every vector element. Use filter for row selection.
if, then, and else are reserved words. See
[conditional expressions](implemented-subset.md#conditional-expressions) for the
full rules and failure examples. Statement blocks and loops remain future work.

## Records: describe data

```text
record AnalysisResult {
  label: Text
  mean: Number
  sample_size: Number
}

result = AnalysisResult(
  label: "October sales",
  mean: 145.8,
  sample_size: 120
)
print result.mean
print AnalysisResult(label: "Preview", mean: 10, sample_size: 1).mean
```

This initial record form is implemented. Fields require one plain Number, Text, Boolean, or earlier-declared record value
each. Constructors use the same positional/named argument rules
as functions. Fields are public to read and cannot be assigned. A mut binding may
be replaced with another value of the same declared record type; copies retain
their original fields. An Integer field type is not implemented.

Records use ordinary named R lists with an internal type attribute and base R
printing. Method dispatch uses private runtime metadata. Read-only
[record methods](record-methods.md) now support nested fn declarations and receiver
calls, returning new values for updates. R callers can modify
returned lists, so immutability is a source-language rule. Vector or table fields,
validation blocks, and defaults remain future work. See [records](implemented-subset.md#records)
for exact limits and failures.

Use with to create an updated record without repeating every field:

```text
updated = result with { label: "Corrected sales", mean: 150 }
print result.mean   # Still 145.8
print updated.mean  # 150
```

Replacement expressions read the original scope; fields are not assigned in place.
Unknown/duplicate fields and wrong field types are errors. See
[record updates](implemented-subset.md#record-updates) for evaluation and syntax rules.

Compare same-type records with == or !=:

```text
unchanged = result with { mean: result.mean }
print result == unchanged  # true
print result != updated    # true when at least one field differs
```

Equality compares primitive fields and descends through nested records. A definite mismatch makes equality false;
otherwise any missing field comparison makes it missing. Different record types
are incompatible, and ordering is not defined. See
[record equality](implemented-subset.md#record-equality) for the full contract.

You can also read a field directly from a function or updated result:

```text
print (result with { mean: 150 }).mean
```

The same syntax reads columns from functions returning tables. Access is exact;
see [field expressions](implemented-subset.md#field-access-on-expression-results)
for scope and precedence rules.

Records may contain earlier-declared record types:

```text
record Point { x: Number }
record Place { location: Point }
place = Place(Point(10))
moved = place with { location: place.location with { x: 20 } }
print place.location.x  # 10
print moved.location.x  # 20
```

Nested updates preserve the original values, and equality compares nested fields
recursively using the same missing-value rules. Forward references and recursive
schemas are not supported. See [nested records](implemented-subset.md#nested-records).

## Classes: protect state and provide behavior

The experimental [class subset](mutable-classes.md) supports private scalar
Number, Text, and Boolean fields, explicit constructors, and mutating methods.

```text
class Counter {
  mut value: Number

  fn current(self) {
    return self.value
  }

  fn increment(mut self) {
    self.value = self.value + 1
  }
}

mut counter = Counter(value: 0)
counter.increment()
print counter.current()
```

Three permissions make the change explicit: mut counter permits binding updates,
mut value permits field changes, and mut self marks a mutating method. Calls that
change a receiver must be standalone statements on a named mutable binding.
Read-only methods contain one return expression; mutating bodies contain only
self.field assignments. All fields precede methods; all constructor arguments
are required. Defaults, nested fields, and custom construction remain future work.

Class values have value semantics:

```text
first = Counter(0)
mut second = first
second.increment()
print first.current()   # 0
print second.current()  # 1
```

Each assignment validates the candidate, and the receiver binding is replaced only
after the complete method succeeds. A failed later assignment leaves that binding
unchanged. print second.value fails because class fields are private in source.
Class equality and with updates are unsupported. Tagged R lists implement this
subset without R6 at execution; R callers can inspect/modify those lists, so this
does not promise secrecy or safe mutation of arbitrary R reference objects.

## Interfaces: share a contract

Interfaces are a later milestone, not a requirement for the first compiler.

```text
interface Predictor {
  fn predict(self, x: Number) -> Number
}

class ConstantModel implements Predictor {
  value: Number

  fn predict(self, x: Number) -> Number {
    return self.value
  }
}

class LinearModel implements Predictor {
  slope: Number
  intercept: Number = 0

  fn predict(self, x: Number) -> Number {
    return self.slope * x + self.intercept
  }
}

fn estimate(model: Predictor, x: Number) -> Number {
  return model.predict(x)
}

model = LinearModel(slope: 2, intercept: 1)
print estimate(model, 10)
```

The intended output is 21. Implementations must satisfy the declared contract.
Dispatch, compatibility rules, and mutation in interfaces remain to be designed.
Composition is preferred initially; inheritance is deferred.

## Export with an alternate delimiter

CSV export supports comma (default), semicolon, tab, and pipe separators:

```text
write sales to "sales-export.csv" with delimiter ";"
```

This requires an existing table sales and a new output path. Use the same delimiter
when reading the file back. Missing fields export as empty by default. Select a
marker explicitly when empty text must remain distinct:

```text
write sales to "sales-export.csv" with delimiter ";" with missing "N/A"
read "sales-export.csv" into restored with delimiter ";" with missing ["N/A"]
```

Choose a marker absent from real data: a literal N/A field would also be read as
missing. Export markers cannot contain the delimiter, quotes, or line breaks.
CSV remains a data-exchange format rather than exact typed serialization.
