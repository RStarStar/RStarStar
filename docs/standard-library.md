# Bundled standard library

Status: **implemented, experimental in 0.0.15**. Installing RStarStar includes
these operations. No additional package or import declaration is required.

```text
magnitudes = std::absolute([-3, 0, 2])
roots = std::square_root(values: [0, 4, 9])
lengths = std::text_length(["A", "ABC", ""])
clean = std::trim_text([" A ", "B", "   "])
```

| Operation | Result |
| --- | --- |
| std::absolute(values) | Elementwise magnitudes; [-3, 0, 2] becomes [3, 0, 2] |
| std::square_root(values) | Real square roots; [0, 4, 9] becomes [0, 2, 3] |
| std::text_length(values) | Character counts; ["A", "ABC", ""] becomes [1, 3, 0] |
| std::trim_text(values) | Remove boundary whitespace; [" A ", "B", "   "] becomes ["A", "B", ""] |

All accept exactly one argument, either positional or named exactly values:.
Arguments evaluate once. Ordinary expression/filter scope applies, including
@name for outer bindings in filters. A binding named std and a user function named
absolute remain valid; std is special only before ::. Only the bundled namespace
is supported: stats::median(...) is not an external R-call bridge. Operations
cannot be used as first-class values. Unknown names never fall back to R globals.

## Numeric values and errors

Inputs must be plain numeric scalars or vectors (integer or double), without
attributes. Length is preserved, including empty numeric vectors. No mutation or
coercion occurs. Text, booleans, records, tables, matrices, classes, named R vectors,
and reference objects are rejected.

Numeric NA and NaN propagate elementwise and retain their distinction. There is no
skipping missing modifier. Empty numeric columns remain numeric, but an all-missing
CSV column inferred as Text fails the numeric check.

absolute maps either infinity to positive infinity. square_root preserves positive
infinity and rejects any nonmissing negative input, including negative infinity.
The whole input is checked before computing; no partial result is returned. Earlier
program effects still follow run_file()'s existing no-rollback rule.

```text
x = std::absolute("3")        # Compile error: numbers required.
y = std::square_root([4, -1])  # Execution error: negative input.
z = std::absolute(value: 3)   # Compile error: parameter is values.
w = std::unknown(3)           # Compile error: unknown operation.
```

These are independent failure examples. Known names, arity, labels, and types are
checked during compilation. Unknown types and domain constraints are checked only
at execution. Transpilation does not execute library operations or load user data.
Runtime errors retain the library call's source location and enclosing language
function call chain. Untaken conditional branches do not run domain checks.

## Text length

std::text_length accepts plain Text scalars or vectors without attributes and returns
Number values of the same length. It counts characters, including spaces and
newlines, not bytes or display width. Empty text has length zero; missing text
returns a missing Number, and an empty text vector returns an empty numeric vector.
There is no implicit conversion from numbers or booleans. Text factors, matrices,
named vectors, and other attributed values passed from R are rejected.

For UTF-8 text, counts are Unicode code points, not user-perceived symbols
(grapheme clusters): "é" has length 1, but "e" followed by a combining accent has
length 2. No normalization occurs. Invalid or byte-encoded text passed from R
raises a source-located execution error. This deliberately small contract uses
base R and introduces no Unicode library dependency.

For example, validate imported codes of at most three characters:

```text
read "codes.csv" into codes
filter codes where std::text_length(code) <= 3 skipping missing into short_codes
```

The code column must be inferred as Text. Missing entries are dropped here because
of skipping missing on the filter; text_length itself preserves them. CSV loading
treats empty cells as missing by default; with missing [] can preserve empty text
for a length-zero check. Numeric-only CSV codes are
inferred as Number by default; use with columns {code: Text} on read to retain
text and leading zeros. An all-missing CSV column is inferred as Text and is accepted.

```text
bad = std::text_length(123)  # Compile error: plain text required.
```

## Trimming text

std::trim_text(values) accepts plain Text scalars or vectors and returns Text of
the same length. It removes only spaces, tabs, carriage returns, and newlines at
each end. Internal spacing remains unchanged. Empty text stays empty; text made
entirely of those whitespace characters becomes empty text, not a missing value.
Missing text stays missing, and empty text vectors remain empty. Inputs are not
mutated. Exactly one positional argument or an exact values: argument is required.

```text
clean = std::trim_text(values: [" A B ", "   ", "C"])
# Result: ["A B", "", "C"]
lengths = std::text_length(clean)
# Result: [3, 0, 1]
bad = std::trim_text(123)  # Compile error: plain text required.
```

Nonbreaking spaces and other Unicode whitespace are deliberately preserved. There
is no case folding, normalization, or numeric conversion. The bounded whitespace
set avoids locale-dependent cleaning rules; broader cleaning needs a separate
contract. As with text_length, attributed R values and invalid/byte-encoded text
are rejected with source-located errors.

For an existing Text column named code, a filter can compare cleaned values:

```text
read "codes.csv" into codes
filter codes where std::trim_text(code) == "A" skipping missing into matching
```

The predicate does not rewrite the table: matching retains the original code
strings. A spaces-only Text cell becomes empty when trimmed. Empty CSV fields
are missing under default loading, but remain text when excluded from the read
statement's missing markers.

## Packaging and generated R

A private catalog stores signatures and quoted R implementations. The compiler
embeds only the operations used by the program plus their common checks in an
isolated helper environment. Generated R still runs without RStarStar installed.
run_file() excludes library helper bindings from its results. Public R exports
remain transpile(path) and run_file(path), accepting only local UTF-8 .rsspps files.

Already generated code retains its implementation when the compiler is upgraded;
recompilation uses the installed package version. The API is experimental with no
separate library version selector. Existing average/sum/count and file statements
retain their behavior. Further text operations, dates, randomness, statistics, and I/O additions
need separate workflow-driven designs. Classes and external R calls remain separate.

Qualified calls were chosen over unqualified names (more collisions), std.absolute
(member-access ambiguity), and imports (unnecessary module rules for a small library).
Standalone embedding makes generated files larger but preserves their execution
contract. See the [decision record](design-decisions.md) and
[implemented subset](implemented-subset.md).
