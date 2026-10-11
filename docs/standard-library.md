# Bundled standard library

Status: **implemented, experimental in 0.0.28**. Installing RStarStar includes
these operations. No additional package or import declaration is required.

```text
magnitudes = std::absolute([-3, 0, 2])
roots = std::square_root(values: [0, 4, 9])
lengths = std::text_length(["A", "ABC", ""])
clean = std::trim_text([" A ", "B", "   "])
finite = std::is_finite([5, 1 / 0, 0 / 0])
```

| Operation | Result |
| --- | --- |
| std::absolute(values) | Elementwise magnitudes; [-3, 0, 2] becomes [3, 0, 2] |
| std::square_root(values) | Real square roots; [0, 4, 9] becomes [0, 2, 3] |
| std::is_finite(values) | Boolean predicate; [5, 1 / 0, 0 / 0] becomes [true, false, false] |
| std::text_length(values) | Character counts; ["A", "ABC", ""] becomes [1, 3, 0] |
| std::trim_text(values) | Remove boundary whitespace; [" A ", "B", "   "] becomes ["A", "B", ""] |
| std::lower_text(values) | Lowercase text using the current R locale; ["North", "NORTH"] becomes ["north", "north"] |

The six numeric/text transforms and predicates above accept exactly one argument,
either positional or named exactly values:.
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

For absolute and square_root, numeric NA and NaN propagate elementwise and retain
their distinction. The is_finite predicate instead returns false for both. There is no
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

## Finite numeric values

std::is_finite(values) accepts one plain numeric scalar/vector and returns Boolean
values of the same length. Finite numbers, including zero and negative numbers,
return true. Positive/negative infinity, NA, and NaN return false, never missing.
Empty numeric inputs return an empty Boolean vector. Integer and double inputs are
accepted; text, booleans, complex numbers, tables, records, classes, and attributed
R values are rejected without coercion. Inputs are not modified.

Use it to select rows whose computed ratios can be summarized:

```text
read "ratios.csv" into data with columns {numerator: Number, denominator: Number}
filter data where std::is_finite(numerator / denominator) into usable
mean_ratio = average(usable.numerator / usable.denominator)
```

For rows (10, 2), (1, 0), (0, 0), and (0, 2), the retained ratios are 5 and 0;
the average is 2.5. Missing numeric inputs are excluded by this predicate as well,
so no skipping missing clause is needed. The source table remains unchanged.
An empty retained table still makes average fail; the predicate does not invent a
fallback result. Declaring numeric CSV columns matters when all values are missing
or the file has only a header: otherwise inferred Text fails the numeric check.

```text
flags = std::is_finite(values: [5, 1 / 0, 0 / 0, -1 / 0])
# [true, false, false, false]
bad = std::is_finite("5")  # Compile error: numbers required.
```

The predicate evaluates its input normally, once. It cannot suppress an earlier
error: std::is_finite(std::square_root(-1)) still fails during square-root execution.
A finite number may be negative; use a separate comparison when a domain requires
nonnegative input. Existing is missing tests remain available when missingness
must be distinguished from infinity.

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

## Lowercase text

std::lower_text(values) accepts one plain Text scalar/vector and returns Text of
the same length. It uses R's tolower under the current LC_CTYPE locale and does not
change that locale. Missing text remains missing, empty text stays empty, and an
empty text vector remains empty. Spaces, punctuation, and digits are retained;
combine with trim_text when boundary whitespace should be removed too.

```text
labels = [" North ", "NORTH", "South"]
normalized = std::lower_text(std::trim_text(labels))
# ["north", "north", "south"]
```

This supports explicitly lowercase comparisons on imported labels:

```text
read "regions.csv" into regions
filter regions where std::lower_text(std::trim_text(region)) == "north" skipping missing into selected
```

The original table and selected strings retain their spelling; the predicate does
not rewrite columns. Missing comparisons require the usual explicit filtering
policy. Numeric/Boolean input is rejected without conversion. Exactly one
positional argument or values: argument is accepted, evaluated once. Invalid or
byte-encoded text and attributed R values are rejected with source-located errors.

Non-ASCII mappings may vary by locale and R platform. This is lowercase conversion,
not Unicode normalization, transliteration, or full case folding; it does not
promise identical matching across locales. No extra Unicode dependency is added.
For example, std::lower_text(123) is a compilation error rather than text conversion.

## Text files and background tasks

The library also provides std::file_exists(path), std::read_text(path), and
std::write_text(path, text) for local text files. Reads return one UTF-8 Text value;
writes create new files without overwriting and require a filesystem with hard-link
support. Relative paths use the execution directory. These operations have
filesystem effects only during execution.

std::start_task(worker, value) starts an earlier one-argument function in a separate
R process. std::await_task(task, timeout: 60) collects its plain Number/Text/Boolean
result. Inputs are copied; handles coordinate one task and cache the result/error.
Timeouts do not cancel work. At most eight uncollected tasks are allowed per program;
nested tasks and shared mutable bindings are unsupported. No extra R dependency is
needed. See [Text files and background tasks](files-and-tasks.md) for signatures,
examples, lifecycle, filesystem requirements, and limitations.

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
