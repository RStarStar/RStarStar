\name{file_tasks}
\alias{file_tasks}
\title{Text File Operations and Background Tasks in RStarStar Source}
\description{
Experimental standard-library operations inside \code{.rsspps} files. These are
language operations, not additional exported R functions. Compilation never runs them.
}
\details{
\code{std::file_exists(path)} accepts one nonempty plain Text path and tests for a
regular local file, following symlinks. Directories return false; existence does
not guarantee readability. URLs and connections are rejected.

\code{std::read_text(path)} reads a regular UTF-8 file into one Text value,
preserving BOMs, line endings, and final newlines. Empty files yield empty text.
Invalid UTF-8 and NUL bytes fail. The whole file is read into memory.

\code{std::write_text(path, text)} accepts one path and one nonmissing plain Text
value, writes UTF-8 without adding a newline, and returns the path with tilde
expansion. It requires an existing parent directory and refuses existing targets.
A staged file is published with a hard link, so competing writers cannot overwrite
the destination. Filesystems without hard-link support fail without a copy fallback.
This does not guarantee crash recovery or durable storage.

\code{std::start_task(worker, value)} starts an earlier one-argument source function
in a fresh Rscript process and returns an opaque Task handle. Inputs/results must
be plain Number, Text, or Boolean scalars/vectors without attributes. Required
generated functions/helpers and input are copied before returning; workers use
the directory captured at start. Other R session settings are not copied. Worker
console output is discarded. Filesystem effects remain visible across processes.

\code{std::await_task(task)} waits up to 60 seconds; supply \code{timeout: 10}, for
example, to change the wait. Timeout must be one finite nonnegative Number; zero
checks immediately. Timeout does not cancel the worker. A retained handle can be
awaited again from R through a source wrapper returned by the same program. Cached
results/errors are reused on repeated awaits, including aliases. Worker language
errors preserve source locations and gain task start/await context. Abrupt worker
failure can appear as a timeout.

Handles belong to one program runtime and originating R process. They cannot be
used in arithmetic, comparisons, vectors, or field access, or as task input/result.
At most eight uncollected tasks are allowed per runtime; collection frees transport
files and a slot. Garbage collection of abandoned handles requests cleanup when
their workers finish, without cancelling them. Await all relevant tasks before
ending the session. Nested tasks, worker pools, cancellation, shared-memory
mutation, and cleanup guarantees after forced termination are unsupported.

Arguments match exact names, with positional arguments before named arguments;
evaluation follows written order. The worker-name position is the sole exception
to the restriction on function values. Rscript comes from the current R installation;
generated code needs neither RStarStar nor R6. Relative data paths use the execution
directory. Errors do not roll back earlier writes or other worker effects, and an
uncaught run_file error returns no partial bindings. These APIs are not a sandbox.
}
\examples{
local({
  directory <- tempfile("rstarstar-tasks-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  path <- system.file("examples", "files-and-tasks.rsspps", package = "RStarStar")
  result <- run_file(path, working_dir = directory)
  print(result$first)
  print(result$second)
})
}
\seealso{\code{\link{standard_library}}, \code{\link{run_file}}, \code{\link{transpile}}}
