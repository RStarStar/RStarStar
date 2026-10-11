# Text files and background tasks

Status: implemented, experimental in 0.0.28. These are `std::` operations inside
`.rsspps` source, not additional exported R functions. Compilation validates source
without reading data files, writing text, or starting workers.

## Text file operations

| Operation | Arguments and result |
| --- | --- |
| `std::file_exists(path)` | One Text path; returns whether it names a regular file |
| `std::read_text(path)` | One Text path; returns the entire UTF-8 file as one Text value |
| `std::write_text(path, text)` | One Text path and one Text value; creates a new file and returns the path (with `~` expanded) |

Arguments may be positional or use the exact names shown. Positional arguments
must precede named ones. Arguments evaluate once in written order, even when named
arguments are supplied in a different order.

```text
saved = std::write_text(path: "message.txt", text: "Hello\n")
exists = std::file_exists(saved)
message = std::read_text(saved)
print message
```

Run this in a directory without `message.txt`. Paths must be nonempty, nonmissing,
plain Text scalars with valid encoding. URLs and connections are unsupported.
Relative paths use the current execution directory, including a `working_dir`
selected by `run_file`. File extensions are unrestricted for these data operations;
public compiler inputs still require `.rsspps`.

`file_exists` returns false for missing files and directories, follows links to
regular files, and does not promise readability or that the path will remain
unchanged. `read_text` requires a regular file, reads it fully into memory, rejects
NUL bytes and invalid UTF-8, and preserves line endings, a leading UTF-8 BOM, and
any final newline. An empty file returns `""`.

`write_text` encodes one nonmissing plain Text scalar as UTF-8 without adding a
newline. Marked Latin-1 text from R is converted to UTF-8; invalid or byte-encoded
text is rejected. The destination directory must exist. Existing destinations,
including directories, are refused. It stages a complete file in the destination
directory and publishes it with a hard link: concurrent writers cannot replace
an existing destination. The filesystem must support hard links; failures do not
fall back to copying over the destination. Temporary files are cleaned up on normal
return/error, but no crash-recovery or durable-storage guarantee is made.

This uses R's documented [file-link API](https://stat.ethz.ch/R-manual/R-devel/library/base/html/files.html).
Native Unix/macOS filesystems and Windows NTFS support hard links; other filesystems
may reject this operation. Platform/filesystem behavior still needs hosted coverage.

Examples of independent failures:

```text
bad = std::read_text("missing.txt")       # Execution error if the file is absent.
bad = std::write_text("out.txt", true)   # Compile error: text is required.
bad = std::read_text(["a.txt", "b.txt"]) # Compile error: one path is required.
```

## Start and await a task

```text
fn clean_file(path) {
  return std::lower_text(std::trim_text(std::read_text(path)))
}

first_task = std::start_task(clean_file, "first.txt")
second_task = std::start_task(worker: clean_file, value: "second.txt")
first = std::await_task(first_task, timeout: 60)
second = std::await_task(second_task)
print first
print second
```

Create `first.txt` and `second.txt` before running this example. Both workers start
before either result is awaited. The installed `files-and-tasks.rsspps` example
creates its own two text files; run it in a fresh working directory.

`start_task(worker, value)` requires the name of an earlier ordinary one-argument
source function. Constructors, methods, arbitrary expressions, and forward
references cannot supply the worker. This is a limited function-argument position;
functions are not general first-class values elsewhere. Input and result must be
plain Number, Text, or Boolean scalars/vectors without attributes. Empty vectors
and typed missing values are supported at the R boundary. Tables, records, classes,
functions, and task handles cannot be task inputs or results.

The caller evaluates the input once and serializes it with the worker's required
generated functions/helpers before returning an opaque Task handle. A fresh
`Rscript --vanilla` process executes the worker. The worker uses the execution
working directory captured at start, including after the caller's directory is
restored. R bindings are copied rather than shared. Other R session settings are
not copied: do not assume inherited R options, locale changes made only inside R,
or random-number state. Workers retain ordinary filesystem access, so file effects
can be visible to other tasks. Worker console output is discarded; return values
and errors are the supported communication mechanism.

The implementation uses R's documented [asynchronous system2 interface](https://stat.ethz.ch/R-manual/R-devel/library/base/html/system2.html),
private temporary result files, and the current installation's `Rscript`. It uses
no forked R process, external worker package, or internal parallel-package protocol.
Generated code and workers remain independent of RStarStar and R6. Starting a task
has process/serialization overhead; use it for independent work worth that cost.

`await_task(task, timeout = 60)` waits up to the given number of seconds and returns
the worker result. In source, use `timeout: 60` for a named argument. Timeout must
be one finite, nonnegative Number; zero checks for completion without waiting.
A timeout raises a source-located error **without cancelling the worker**. An R
caller that retains the handle and a returned source wrapper can retry the await.
There is no source-language exception handling yet, so an uncaught timeout ends
that `run_file` call without returning partial bindings. Worker failures preserve
their source location and add start/await context. Abrupt worker death or failed
startup may be reported as an await timeout rather than a worker condition.

Task handles belong to the program/runtime that created them and the originating
R process. They may be aliased or passed to ordinary source functions for awaiting,
but cannot be compared, used in arithmetic/vectors, or inspected through source
field access. Repeated awaits (including through aliases) return the cached result
or raise the cached worker error without rerunning the job. R callers can retain
handles returned by `run_file`, but must use a wrapper from that same program to
await them. Handles are not supported as portable serialized values or across
separate `run_file` calls.

At most eight uncollected tasks are allowed per program runtime. Awaiting completion
releases that task's transport directory and frees a slot. Dropping all references
to an uncollected handle lets R's finalizer request cleanup when its worker finishes;
collection timing is controlled by R's garbage collector. Abandonment does not
cancel work. Nested start/await operations inside a worker are unsupported. There
is no worker pool, cancellation, shared-memory mutation, detached-service lifetime,
or guarantee of cleanup after a process crash/forced termination. Await every task
whose result or failure matters before ending the R session.

## Effects and diagnostics

Invalid signatures and known types fail during compilation, before any file or
worker effects. Unknown inputs and filesystem/process failures are checked during
execution. Errors carry the original `.rsspps` location; ordinary function call
chains are retained. Earlier writes and other task effects are not rolled back
when a later operation fails. Independent task completion order is unspecified;
await in the order in which results should be consumed.

These APIs provide convenience and defined failure behavior, not a filesystem
sandbox or deep immutability for arbitrary R objects. See the
[standard-library contract](standard-library.md) and [R package guide](r-package.md).
