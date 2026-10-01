# Initial language guide

This guide explores the intended experience. **Bindings, mut, literals, vectors,
arithmetic, printing, and CSV loading now work; filtering, functions, and OOP remain
proposals.** See the [implemented subset](implemented-subset.md) for exact working
syntax and [design decisions](design-decisions.md) for open proposals.

## Read and transform data

```text
read "sales.csv" into sales
filter sales where revenue > 0 into profitable_sales
```

Sentence-like commands express actions; ordinary expressions express calculations.
The filter example assumes a numeric revenue column with no missing values.
Filtering is still a proposal; column-name resolution and missing-value filtering
rules need a decision. CSV loading works and reports file errors with the original
statement location and path.

CSV loading supports an optional delimiter:

```text
read "sales.csv" into sales with delimiter ";"
```

The loader reads local UTF-8 CSV files with headers. It infers numeric, boolean,
or text columns, preserves missing values, and rejects malformed rows. See the
[implemented subset](implemented-subset.md#csv-loading) for exact inference and
missing-value rules. Schemas and other file formats remain future work.

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
conditions remain proposals. See the implemented subset for arithmetic limits.

## Missing data

Missing-value behavior must be visible and documented. One possible spelling is:

```text
average sales.revenue skipping missing
```

The default when no policy is supplied is unresolved. All-missing and empty
inputs also need explicit behavior. Do not assume missing means zero or false.

## Records: describe data

```text
record AnalysisResult {
  label: Text
  mean: Number
  sample_size: Integer
}

result = AnalysisResult(
  label: "October sales",
  mean: 145.8,
  sample_size: 120
)

print result.mean

updated = result with {
  label: "Corrected October sales"
}
```

Proposed records provide generated constructors, readable printing, and value
equality. Fields are public to read and immutable by default. The with expression
creates a new value and validates its field names and types. Equality involving
missing values or nested objects still needs a specification.

## Classes: protect state and provide behavior

```text
class Counter {
  mut value: Integer = 0

  fn increment(mut self) {
    self.value = self.value + 1
  }

  fn current(self) {
    return self.value
  }
}

mut counter = Counter()
counter.increment()
print counter.current()
```

Proposed class fields are private; methods are public unless marked private.
Generated constructors accept initial field values and defaults. Construction
does not imply permission to access private fields afterward. Validation and
custom construction are open design topics.

The three mutation markers describe different permissions: mut counter allows
updates to the binding; mut value permits field changes; mut self permits a
method to update the receiver. Calling a mutating method requires a mutable
receiver. This explicit spelling is a starting point for usability review.

Value semantics are proposed for language-owned objects:

```text
mut first = Counter()
mut second = first
second.increment()
```

The intended result is first.current() == 0 and second.current() == 1. The
implementation strategy and boundaries around R reference objects are unresolved.
Nested objects and mutation through function arguments need additional examples.

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
