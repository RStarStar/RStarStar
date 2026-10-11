# Standalone background workers. Each start serializes a worker closure and plain
# input before launching a fresh Rscript process; no forked/shared R state is used.
# The private directory transports results, never arbitrary user-supplied RDS files.
rss_task_runtime <- function(fail) {
  owner <- Sys.getpid()
  authority <- new.env(parent = emptyenv())
  pending <- character()
  plain <- function(value) {
    is.null(attributes(value)) && typeof(value) %in% c("double", "integer", "logical", "character")
  }
  # R serializes globalenv() by reference, so a standalone script's closures need
  # an explicit program scope. Copy referenced functions/helpers and rehome their
  # environments, preserving cycles in runtime registries. Source workers cannot
  # capture ambient data; their sole input is passed separately by value.
  snapshot <- function(worker) {
    source <- environment(worker)
    program <- new.env(parent = baseenv())
    originals <- list(source)
    copies <- list(program)
    capture <- function(fun) {
      for (name in unique(all.names(body(fun)))) {
        if (!exists(name, source, inherits = FALSE) || exists(name, program, inherits = FALSE)) next
        value <- get(name, source, inherits = FALSE)
        if (!is.function(value) && !name %in% c(".rss", ".rss_std", ".rss_read_csv")) next
        assign(name, NULL, program)
        assign(name, copy(value), program)
      }
    }
    copy <- function(value) {
      if (is.function(value)) {
        if (is.primitive(value)) return(value)
        if (identical(environment(value), source)) capture(value)
        environment(value) <- copy(environment(value))
        return(value)
      }
      if (is.environment(value)) {
        for (i in seq_along(originals)) if (identical(value, originals[[i]])) return(copies[[i]])
        if (identical(value, baseenv()) || identical(value, emptyenv()) || isNamespace(value)) return(value)
        target <- new.env(parent = emptyenv())
        originals[[length(originals) + 1L]] <<- value
        copies[[length(copies) + 1L]] <<- target
        parent.env(target) <- copy(parent.env(value))
        for (name in ls(value, all.names = TRUE)) assign(name, copy(get(name, value, inherits = FALSE)), target)
        return(target)
      }
      if (is.list(value)) {
        for (i in seq_along(value)) value[i] <- list(copy(value[[i]]))
      }
      value
    }
    copy(worker)
  }
  # This function is written into the worker script, so it must be self-contained.
  worker_main <- function(directory) {
    on.exit({
      file.create(file.path(directory, "done"), showWarnings = FALSE)
      if (file.exists(file.path(directory, "released"))) unlink(directory, recursive = TRUE)
    }, add = TRUE)
    result <- tryCatch({
      job <- readRDS(file.path(directory, "job.rds"))
      setwd(job$working_dir)
      value <- do.call(job$worker, list(job$value))
      if (!is.null(attributes(value)) || !typeof(value) %in% c("double", "integer", "logical", "character")) {
        stop("Tasks must return plain Number, Text, or Boolean values.", call. = FALSE)
      }
      list(ok = TRUE, value = value)
    }, error = function(e) list(ok = FALSE, error = e))
    # Publish only a complete serialization, then signal completion in on.exit.
    temporary <- file.path(directory, "result.tmp")
    saveRDS(result, temporary)
    if (!file.rename(temporary, file.path(directory, "result.rds"))) stop("Could not publish task result.", call. = FALSE)
    invisible(NULL)
  }
  # Collection frees transport files. Abandonment asks a still-running worker to
  # clean up when it finishes; it does not terminate the worker or undo its effects.
  release <- function(task) {
    directory <- task$directory
    if (is.character(directory) && length(directory) == 1L && dir.exists(directory)) {
      file.create(file.path(directory, "released"), showWarnings = FALSE)
      if (file.exists(file.path(directory, "done"))) unlink(directory, recursive = TRUE)
    }
    invisible(NULL)
  }
  list(
    # worker is a source-declared one-argument function. A serialized copy of its
    # generated environment supports earlier functions and standalone helpers.
    start_task = function(worker, value, filename, line, column) {
      error <- function(message) fail(message, filename, line, column)
      if (Sys.getpid() != owner) error("Starting nested tasks inside a worker is unsupported.")
      if (!is.function(worker) || typeof(worker) != "closure" || length(formals(worker)) != 1L) error("Task worker must be a one-argument function.")
      if (!plain(value)) error("Task input must be plain Number, Text, or Boolean values.")
      force(value)
      pending <<- pending[dir.exists(pending)]
      if (length(pending) >= 8L) error("At most eight uncollected tasks are allowed; await a task before starting another.")
      executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
      if (!file.exists(executable)) error("Background tasks require Rscript from the current R installation.")
      directory <- tempfile("rstarstar-task-")
      if (!dir.create(directory, mode = "0700")) error("Could not create a private task directory.")
      launched <- FALSE
      on.exit(if (!launched) unlink(directory, recursive = TRUE), add = TRUE)
      tryCatch(withCallingHandlers({
        # Serialization happens in the caller, fixing the input before returning.
        saveRDS(list(worker = snapshot(worker), value = value, working_dir = getwd()), file.path(directory, "job.rds"))
        script <- file.path(directory, "worker.R")
        writeLines(c(paste0("worker_main <- ", paste(deparse(worker_main, width.cutoff = 100L), collapse = "\n")),
          "worker_main(commandArgs(trailingOnly = TRUE)[[1L]])"), script)
        status <- local({
          # R CMD check sets R_TESTS to a relative startup file. It is not part of
          # the worker job and may be absent in its directory, even with --vanilla.
          tests <- Sys.getenv("R_TESTS", unset = NA_character_)
          on.exit(if (is.na(tests)) Sys.unsetenv("R_TESTS") else Sys.setenv(R_TESTS = tests))
          Sys.unsetenv("R_TESTS")
          system2(executable, c("--vanilla", "--default-packages=NULL", shQuote(script), shQuote(directory)),
                  stdout = FALSE, stderr = FALSE, wait = FALSE)
        })
        if (status != 0L) error("Could not launch the background R worker.")
      }, warning = function(w) stop(conditionMessage(w), call. = FALSE)), error = function(e) {
        if (inherits(e, "rstarstar_error")) stop(e)
        error(paste("Could not start task:", conditionMessage(e)))
      })
      launched <- TRUE
      task <- new.env(parent = emptyenv())
      task$directory <- directory
      task$collected <- FALSE
      task$result <- NULL
      task$started <- sprintf("%s:%d:%d", filename, line, column)
      class(task) <- "rss_task"
      attr(task, "rss_task_owner") <- authority
      # R callers may inspect a handle, but must not redirect finalizer cleanup.
      lockBinding("directory", task)
      lockBinding("started", task)
      lockEnvironment(task, bindings = FALSE)
      reg.finalizer(task, release, onexit = TRUE)
      pending <<- c(pending, directory)
      task
    },
    # Wait for completion, caching values/errors so aliases and repeated awaits
    # observe one job. A timeout leaves the handle usable for a later await.
    await_task = function(task, timeout = 60, filename, line, column) {
      error <- function(message) fail(message, filename, line, column)
      if (Sys.getpid() != owner || !is.environment(task) || !inherits(task, "rss_task") ||
          !identical(attr(task, "rss_task_owner", exact = TRUE), authority)) {
        error("await_task requires a task created by this program in the current R process.")
      }
      if (!typeof(timeout) %in% c("double", "integer") || !is.null(attributes(timeout)) || length(timeout) != 1L ||
          !is.finite(timeout) || timeout < 0) error("Task timeout must be one finite nonnegative Number of seconds.")
      if (!task$collected) {
        started <- proc.time()[["elapsed"]]
        while (!file.exists(file.path(task$directory, "done"))) {
          if (!dir.exists(task$directory)) error("Task transport directory is no longer available.")
          if (proc.time()[["elapsed"]] - started >= timeout) error("Task await timed out; the worker may still be running. Await this handle again to collect it.")
          Sys.sleep(min(0.02, max(0, timeout - (proc.time()[["elapsed"]] - started))))
        }
        task$result <- tryCatch(readRDS(file.path(task$directory, "result.rds")),
          error = function(e) list(ok = FALSE, error = simpleError(paste("Could not read task result:", conditionMessage(e)))))
        task$collected <- TRUE
        release(task)
      }
      if (!isTRUE(task$result$ok)) {
        e <- task$result$error
        context <- paste0("\n  task started at ", task$started,
                          "\n  awaited at ", filename, ":", line, ":", column)
        if (inherits(e, "rstarstar_error")) {
          e$message <- paste0(e$message, context)
          stop(e)
        }
        error(paste0("Background task failed: ", conditionMessage(e), context))
      }
      task$result$value
    }
  )
}
