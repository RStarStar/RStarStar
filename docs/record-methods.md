# Record methods

Status: **implemented, experimental in 0.0.18**. Record methods extend existing
value records. Mutable classes and interfaces remain future work. This contract
adopts the first-slice proposal recorded in the decision log.

## Syntax and purpose

Calculations and copy updates belonging to a record can use separate
functions or methods. Methods keep that behavior near its fields and make calls easier
to discover without requiring mutable classes or interfaces.

```text
record Point {
  x: Number
  y: Number

  fn magnitude(self) {
    return std::square_root(self.x * self.x + self.y * self.y)
  }

  fn shifted(self, dx, dy) {
    return self with {x: self.x + dx, y: self.y + dy}
  }
}

start = Point(3, 4)
distance = start.magnitude()
next = start.shifted(dx: 1, dy: 2)
# Results: distance = 5; next = Point(4, 6); start stays Point(3, 4).
```

Place methods after all fields in the record declaration. Reuse fn,
one return expression, existing positional/named argument rules, and ordinary
expressions. The first declared parameter must be self; callers supply only the
remaining parameters. self is a contextual receiver name inside a method, not a
new globally reserved word. Parameter annotations, defaults, overloaded signatures, multi-statement bodies,
and implicit field lookup are not supported.

## Names, scope, and calls

- Fields and methods share a record member namespace; reject duplicate method names
  and a method whose name matches a field. Different record types may have the same
  method name. Unrelated top-level functions keep their own names.
- self.x reads a field. x alone resolves as an ordinary parameter/local name, not
  implicitly as a receiver field. Bodies may use parameters, self, the standard
  library, and previously declared functions/constructors under existing scope rules.
  Do not capture outer data bindings.
- Methods have declaration-order visibility. A method can call an earlier method,
  including on self, but not itself or a later method. The current record constructor
  becomes callable after its declaration; use self with {...} inside its methods.
- A method-call site sees only methods available when its enclosing function/method
  is declared, or at that top-level source position. Freeze that lookup set so a later
  declaration cannot silently change an earlier function's behavior. No recursion,
  forward references, or dynamic method registration in this slice.
- receiver.name(...) is a method call. receiver.name without parentheses remains
  field access; it does not return a bound method. Calls on constructor results,
  nested fields, and parenthesized updates should work. Quoted field access remains
  supported, but method names are identifiers, not quoted strings.
- Require the existing exact arity and exact named labels, positional arguments
  before named ones, and duplicate-argument rejection. self cannot be supplied as
  a named argument at the call site.

Evaluate the receiver once, then explicit arguments once in source order. Force
those expressions before runtime dispatch and signature validation; a failure during
evaluation stops subsequent evaluation. Compilation may reject statically invalid
calls without running anything. In a filter, receiver and argument expressions use
existing column scope and @outer escapes; method bodies use ordinary function scope.

## Values and failure behavior

Methods return values. shifted above makes a new record; it does not update start.
To retain a returned update, explicitly reassign a mutable binding:

```text
mut current = Point(3, 4)
current = current.shifted(1, 2)
```

Reject mut self, direct field assignment, and receiver rebinding in method bodies.
This builds on existing record copy semantics and avoids promising deep immutability
for arbitrary R objects. Methods do not change field layout, equality, or constructor
arguments. No method closures should be stored in record values.

Known receiver types allow compile-time method/name/argument checking. For unknown
receiver types, such as an ordinary function parameter, defer dispatch to execution.
Use the receiver's declared record type and the call site's visible method set;
never fall back to an R method, caller global, or table column. Unknown or non-record
receivers fail with a source-located error. Infer a known call's result from its
method body; for ambiguous receiver types keep type/shape unknown unless all viable
methods agree. Do not infer that all methods with the same name share a signature.

```text
# Independent failure examples.
a = start.shifted(dx: 1, dy: 2, self: start)  # Caller cannot supply self.
b = start.unknown()                         # No such method.
c = start.magnitude                        # No field named magnitude.
d = 3.magnitude()                          # Receiver is not a record.
e = start.shifted("one", 2)                # Numeric addition fails in the body.
```

Diagnostics retain the method declaration/body location, the call location,
and enclosing language function call chain. AST nodes retain full source spans for method members and calls. Parsing, analysis, and transpilation do not execute source, load data, or evaluate
method bodies.

## Generated R and interoperability

Records remain named lists with nominal tags. Method implementations are ordinary
R functions stored in the private runtime
registry. Each generated call carries a fixed set of visible method IDs. Method
closures retain the program environment for checked calls to earlier functions. No
S3/S4/R6 backend, dependencies, or new public R exports are introduced. Generated
R remains standalone, and run_file() excludes helper bindings from results.

R callers receive records as ordinary values and can use returned
language wrapper functions to invoke methods. Do not claim native R dollar-method
calls such as value$magnitude(), foreign class dispatch, schema provenance for forged
records, or deep immutability outside the language. Runtime receivers are
validated against the supported record layout before a method body runs.

## Alternatives and limits

Ordinary functions remain supported. A separate impl block is deferred because it
would add scope and registration rules. Mutable classes require separate aliasing,
visibility, and backend decisions; the guide's Counter and interface examples are
still not executable. No methods are stored in record fields, and there is no native
R value$method() interface. A returned language wrapper function can invoke methods.

Record fields remain scalar or nested records. A method may return a vector, but
cannot place that vector in a scalar field through with. R callers can modify
returned objects. Receiver layout validation rejects mismatched field names/types
and unsupported attributes/references, but is not a provenance or deep-immutability
guarantee for arbitrary R objects.

Verification covers declarations and spans, exact/static/dynamic calls, visibility,
copy updates and aliases, nested receivers, filter scope, eager source-order
arguments, invalid R receivers, errors and call chains, standalone execution, and
private result bindings. See [PROGRESS.md](../PROGRESS.md) for actual package-check
results and platform limits, and [implemented syntax](implemented-subset.md).
