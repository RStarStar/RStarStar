# Mutable classes

Status: **implemented, experimental; literal defaults added in 0.0.20 and record fields in 0.0.21**. This adopts the first-slice
proposal recorded in the [design decisions](design-decisions.md). The compiler
uses R6 internally; generated class values are ordinary tagged lists and generated
programs do not require R6.

## A small stateful object

```text
class Counter {
  mut value: Number = 0

  fn current(self) {
    return self.value
  }

  fn increment(mut self, amount) {
    self.value = self.value + amount
  }
}

mut counter = Counter()
counter.increment(amount: 1)
print counter.current()
# 1
```

class is now reserved. Classes declare at least one field before any methods.
Fields have explicit Number, Text, Boolean, or earlier record types. Primitive
fields hold one plain scalar; record fields hold one value of the declared nominal type.
Fields are private in source; methods are public. A field needs mut to permit
assignment. Generated constructors accept positional/named arguments. Fields without defaults
must be supplied exactly once. A field can declare a scalar literal default using
=, such as value: Number = 0, label: Text = "Counter", or active: Boolean = true.
Numbers may have a single + or - sign; parentheses around literals are allowed.
Default types are checked at compilation even if the class is unused or every call
overrides the field. Variables, field references, calls, vectors, and computed
expressions are rejected. No default expression executes during compilation.

Defaults need not be trailing fields. Positional arguments still correspond to
field declaration order; use exact names to skip an optional field:

```text
class Meter {
  mut value: Number = 0
  label: Text
}
a = Meter(label: "Visits")       # value is 0
b = Meter(10, "Downloads")       # explicit override
# Meter() fails: required field label is missing.
# Meter("Visits") fails: the positional argument supplies value, not label.
# value: Number = "zero" fails even if a caller supplies a numeric value.
```

Explicit arguments evaluate once in written order. Omitted fields use their
literal defaults on each construction. Overrides retain scalar type checks;
no default is substituted for an explicit invalid or missing value. Returned R
constructors also have defaults, under ordinary R argument matching rules.
Records support the same scalar literal defaults. Ordinary functions still require all arguments. Validation blocks,
nested class fields, vectors, tables, and foreign reference fields remain
unsupported.

## Three explicit permissions

- mut counter permits replacing the caller's binding with an updated value.
- mut value permits changing that field inside the class.
- mut self marks a method that produces an updated receiver.

All three are required for a field-changing call. Read-only fn current(self)
methods contain one return expression. Mutating methods contain one or more
self.field = expression assignments, separated by newlines, with no return.
Locals, condition statements, loops, I/O, nested mutating calls, and general
multi-statement functions are unsupported. Conditional expressions are allowed
on assignment right-hand sides.

Field/method names must be unique, self must be the first parameter, and arguments
must match exactly. Bodies may use parameters and earlier functions, constructors,
and read-only methods, but cannot capture outer data. A method is visible only
after its body; the constructor becomes visible after the class declaration.
There is no recursion, forward reference, or bound method value.

Only direct self.field (also self."field") inside the owning class reads private
fields. Access through other receivers, including (self).field, is rejected.
Ordinary functions can receive and return class values and invoke read-only
methods, but cannot access their fields.

## Mutation replaces one binding

```text
# After the Counter declaration above:
first = Counter(value: 0)
mut second = first
second.increment(1)
print first.current()   # 0
print second.current()  # 1
```

A mutating call computes a new receiver and assigns it back to second. Existing
aliases keep their values. Supported fields are plain scalars or record trees without
reference values, so no explicit clone is needed. Reassignment retains the same nominal class type.

Mutating calls are standalone statements on simple named mut bindings. Read-only
calls remain expressions. Mutation in an expression, on a constructor result,
through a field receiver, or through a function parameter is unsupported. There
are no mutable parameters or implicit updates to aliases.

```text
# Each line below is a separate failure example after suitable declarations.
fixed.increment(1)             # fixed was declared without mut.
x = counter.increment(1)       # A mutating call has no expression result.
Counter(0).increment(1)         # Requires a named mutable binding.
print counter.value            # Private field.
counter.value = 5              # External field assignment.
counter.current()              # Read-only calls need an expression context.
```

Known receiver types, signatures, and effects are checked before generation.
Unknown receivers dispatch at execution within the call site's fixed visible set
of methods. The selected method must have the required effect: read-only in an
expression, mutating in a standalone statement. Later declarations cannot change
earlier call sites.

## Evaluation and failure

The receiver evaluates once, then explicit arguments evaluate once in written
order, against the old committed receiver. Runtime dispatch validates the receiver,
effect, and exact signature. Assignments run sequentially on a local candidate;
each validates its declared field type and complete record layout, and later assignments see earlier updates.
The caller's binding is replaced only after every assignment succeeds.

```text
class Pair {
  mut left: Number
  mut right: Number
  fn change(mut self, replacement) {
    self.left = self.left + 1
    self.right = replacement
  }
}
mut pair = Pair(1, 2)
pair.change("bad")
# Execution error: right requires Number. The committed pair remains Pair(1, 2).
```

The error retains the failing assignment's location and method call chain.
This guarantee covers receiver replacement only. Earlier prints/files are not
rolled back, and run_file() returns no partial result on failure. Tests inspect
the separately evaluated generated environment to verify unchanged bindings.
Transpilation never executes method bodies or reads user datasets.

Number fields allow missing/nonfinite numeric scalars under existing rules.
Classes do not support equality, ordering, with updates, vector membership,
whole-object missingness tests, or summaries. Use read-only methods to expose
values for those operations. Generic field access also rejects unknown class
receivers at runtime.

## Representation and R boundary

Class values are named lists with an internal rss_class_type tag. Private runtime
registries hold schemas, field permissions, method functions, and method effects.
Generated mutating methods return a validated candidate to the caller's assignment.
No R dispatch methods or native dollar-method API are registered.

Private means source-language access control, not secrecy or a security boundary
in R. Base printing displays the underlying list. R callers can inspect or alter
returned representations; runtime calls validate supported layouts, not provenance
or deep immutability of arbitrary R objects. Returned language functions can expose
read-only method calls to R callers. No new package export, source extension,
external R-call bridge, or runtime dependency is introduced.

Tagged values preserve the documented alias semantics. Environment-backed
reference objects would change those semantics; automatic reference cloning would
require an additional ownership/copy policy. Nested mutable class state, computed defaults,
custom constructors, private methods, interfaces, and inheritance remain future work.

The packaged classes.rsspps example and tests/cases/classes.R cover success,
permissions, privacy, failure atomicity, evaluation order, dispatch, invalid R
layouts, spans, stage reuse, and fresh-process execution without R6 or RStarStar.
See [implemented syntax](implemented-subset.md) and [record methods](record-methods.md).


## Record-valued state

A class may hold an earlier record type, including an acyclic tree of records.
This lets a tracker keep a position as one value instead of repeating its fields:

```text
record Point {
  x: Number
  y: Number
}
class Tracker {
  mut position: Point
  fn snapshot(self) { return self.position }
  fn move(mut self, dx) {
    self.position = self.position with { x: self.position.x + dx }
  }
}
origin = Point(0, 0)
first = Tracker(origin)
mut second = first
second.move(3)
print first.snapshot().x    # 0
print second.snapshot().x   # 3
print origin.x              # 0
```

Replace the whole private record field with a constructor, a with copy update, or
a record method's result. self.position.x = 3 is unsupported. The outer field
must be declared mut even when only one nested record field changes. Immutable
record-valued class fields may be read and returned, but cannot be replaced.
Returning a snapshot exposes a record value; changing a copy does not change its
owner. The enclosing class field remains private.

Record-valued fields have no defaults in this slice and must be explicitly supplied.
The record type must precede the class declaration; forward, recursive, and
class-valued fields remain unsupported. A different record with identical fields
is still the wrong nominal type. Constructors, method receivers, and replacement
assignments recursively check declared record layouts, including scalar leaf types,
field names, and unsupported attributes. For example, a Point with a Text x field
modified by an R caller is rejected when used to construct a Tracker.

Sequential assignments still use a local candidate. If a later replacement is
invalid, none of that call's candidate changes replace the caller's binding.
Earlier program output remains outside this guarantee. Returned lists can still
be inspected and modified in R; these checks do not promise provenance or deep
immutability for arbitrary R objects. See the packaged record-state.rsspps example.
