# Bundled standard library

Status: **implemented, experimental in 0.0.11**. Installing RStarStar includes
these operations. No additional package or import declaration is required.

```text
magnitudes = std::absolute([-3, 0, 2])
roots = std::square_root(values: [0, 4, 9])
```

| Operation | Result |
| --- | --- |
| std::absolute(values) | Elementwise magnitudes; [-3, 0, 2] becomes [3, 0, 2] |
| std::square_root(values) | Real square roots; [0, 4, 9] becomes [0, 2, 3] |

Both accept exactly one argument, either positional or named exactly values:.
Arguments evaluate once. Ordinary expression/filter scope applies, including
@name for outer bindings in filters. A binding named std and a user function named
absolute remain valid; std is special only before ::. Only the bundled namespace
is supported: stats::median(...) is not an external R-call bridge. Operations
cannot be used as first-class values. Unknown names never fall back to R globals.

## Values and errors

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

## Packaging and generated R

A private catalog stores signatures and quoted R implementations. The compiler
embeds only the operations used by the program plus their common checks in an
isolated helper environment. Generated R still runs without RStarStar installed.
run_file() excludes library helper bindings from its results. Public R exports
remain transpile(path) and run_file(path), accepting only local UTF-8 .rsspps files.

Already generated code retains its implementation when the compiler is upgraded;
recompilation uses the installed package version. The API is experimental with no
separate library version selector. Existing average/sum/count and file statements
retain their behavior. Text, dates, randomness, more statistics, and I/O additions
need separate workflow-driven designs. Classes and external R calls remain separate.

Qualified calls were chosen over unqualified names (more collisions), std.absolute
(member-access ambiguity), and imports (unnecessary module rules for two operations).
Standalone embedding makes generated files larger but preserves their execution
contract. See the [decision record](design-decisions.md) and
[implemented subset](implemented-subset.md).
