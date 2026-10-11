# Internal runtime access permits deterministic worker barriers without adding a
# sleep/loop language feature solely for tests. Public source integration follows.
task_test_api <- function() {
  result <- run('fn work(x) { return x }\nfn start(x) { return std::start_task(work, x) }\nfn wait(task) { return std::await_task(task) }')
  runtime <- result$env$.rss_std
  list(start = function(worker, value) runtime$start_task(worker, value, 'task.test', 1L, 1L),
       await = function(task, timeout = 10) runtime$await_task(task, timeout, 'task.test', 2L, 1L))
}

check("tasks snapshot inputs preserve aliases and return primitive results", {
  with_source_file(paste('fn square(x) { return x * x }',
    'mut values = [2, 3]', 'task = std::start_task(value: values, worker: square)',
    'alias = task', 'values = [9, 9]', 'first = std::await_task(task)',
    'second = std::await_task(timeout: 10, task: alias)', sep = '\n'), function(path) {
    result <- RStarStar::run_file(path)
    stopifnot(identical(result$first, c(4, 9)), identical(result$second, c(4, 9)),
              identical(result$values, c(9, 9)), identical(result$alias, result$task),
              !dir.exists(result$task$directory))
    stopifnot(inherits(tryCatch({result$task$directory <- tempdir()}, error = identity), 'error'))
  })
  api <- task_test_api()
  for (value in list(numeric(), c(NA_real_, NaN, Inf), c(TRUE, NA), c('é', NA_character_))) {
    task <- api$start(function(x) x, value)
    stopifnot(identical(api$await(task), value))
  }
})

check("background workers overlap in separate R processes", {
  with_execution_directory(function(directory) {
    api <- task_test_api()
    worker <- function(paths) {
      file.create(paths[[1L]])
      deadline <- proc.time()[['elapsed']] + 10
      while (!file.exists(paths[[2L]])) {
        if (proc.time()[['elapsed']] >= deadline) stop('Workers did not overlap')
        Sys.sleep(0.01)
      }
      as.double(Sys.getpid())
    }
    paths <- file.path(directory, c('first-ready', 'second-ready'))
    first <- api$start(worker, paths)
    second <- api$start(worker, rev(paths))
    pids <- c(api$await(first), api$await(second))
    stopifnot(length(unique(pids)) == 2L, all(pids != Sys.getpid()))
  })
})

check("workers exclude R test startup hooks without changing the caller environment", {
  local({
    previous <- Sys.getenv('R_TESTS', unset = NA_character_)
    on.exit(if (is.na(previous)) Sys.unsetenv('R_TESTS') else Sys.setenv(R_TESTS = previous))
    Sys.setenv(R_TESTS = 'nonexistent-rstarstar-test-startup.R')
    api <- task_test_api()
    task <- api$start(function(x) Sys.getenv('R_TESTS'), 1)
    stopifnot(api$await(task) == '', Sys.getenv('R_TESTS') == 'nonexistent-rstarstar-test-startup.R')
  })
})

check("tasks integrate with text I/O and retain their starting working directory", {
  with_execution_directory(function(directory) {
    writeLines('one', file.path(directory, 'one.txt'))
    writeLines('two', file.path(directory, 'two.txt'))
    with_source_file(paste('fn load(path) { return std::read_text(path) }',
      'fn collect(task) { return std::await_task(task) }',
      'first = std::start_task(load, std::write_text("once.txt", "one\\n"))',
      'second = std::start_task(load, "two.txt")', sep = '\n'), function(path) {
      previous <- getwd()
      result <- RStarStar::run_file(path, working_dir = directory)
      stopifnot(identical(getwd(), previous), result$collect(result$first) == 'one\n',
                result$collect(result$second) == 'two\n')
    })
  })
})

check("task signatures and handle operations fail clearly during analysis", {
  prefix <- 'fn work(x) { return x * 2 }\n'
  fails(paste0(prefix, 'task = std::start_task(work)'), 'Missing required parameters')
  fails(paste0(prefix, 'task = std::start_task(work(1), 2)'), 'must name an earlier')
  fails('fn work(x, y) { return x + y }\ntask = std::start_task(work, 1)', 'one-argument function')
  fails('record Point { x: Number }\ntask = std::start_task(Point, 1)', 'not a constructor')
  fails('task = std::start_task(later, 1)\nfn later(x) { return x }', 'Unknown variable')
  fails(paste0(prefix, 'task = std::start_task(work, 2)\nx = task + 1'), 'Await a task')
  fails(paste0(prefix, 'task = std::start_task(work, 2)\nx = [task]'), 'Task handles')
  fails(paste0(prefix, 'task = std::start_task(work, 2)\nx = task is missing'), 'Await a task')
  fails(paste0(prefix, 'task = std::start_task(work, 2)\nx = count(task)'), 'Await a task')
  fails('x = std::await_task(1)', 'requires Task')
  fails('fn wait(task) { return std::await_task(task, timeout: [1, 2]) }', 'requires one value')
  fails(paste0(prefix, 'print work'), 'Functions must be called')
})

check("task timeouts permit retry and validate R caller inputs", {
  with_execution_directory(function(directory) {
    api <- task_test_api()
    worker <- function(path) {
      deadline <- proc.time()[['elapsed']] + 10
      while (!file.exists(path)) {
        if (proc.time()[['elapsed']] >= deadline) stop('release marker missing')
        Sys.sleep(0.01)
      }
      42
    }
    release <- file.path(directory, 'release')
    task <- api$start(worker, release)
    error <- tryCatch(api$await(task, 0), error = identity)
    stopifnot(inherits(error, 'rstarstar_error'), grepl('timed out', conditionMessage(error)), !task$collected)
    for (bad in list(-1, NA_real_, Inf, 1+1i, TRUE, '1', numeric(), c(1, 2), c(named = 1))) {
      stopifnot(inherits(tryCatch(api$await(task, bad), error = identity), 'rstarstar_error'))
    }
    file.create(release)
    stopifnot(api$await(task) == 42, api$await(task, 0) == 42, !dir.exists(task$directory))
    for (bad in list(list(1), new.env(), c(named = 1), matrix(1), NULL, 1+1i)) {
      stopifnot(inherits(tryCatch(api$start(function(x) x, bad), error = identity), 'rstarstar_error'))
    }
    stopifnot(inherits(tryCatch(task_test_api()$await(task), error = identity), 'rstarstar_error'))
  })
})

check("worker errors are cached with source and task call context", {
  with_source_file('fn root(x) { return std::square_root(x) }\nfn wait(task) { return std::await_task(task) }\ntask = std::start_task(root, -1)', function(path) {
    result <- RStarStar::run_file(path)
    errors <- lapply(1:2, function(i) tryCatch(result$wait(result$task), error = identity))
    stopifnot(all(vapply(errors, inherits, logical(1), 'rstarstar_error')),
              errors[[1L]]$line == 1L, errors[[1L]]$column == 21L,
              identical(conditionMessage(errors[[1L]]), conditionMessage(errors[[2L]])),
              grepl('task started at', conditionMessage(errors[[1L]])),
              grepl('awaited at', conditionMessage(errors[[1L]])), !dir.exists(result$task$directory))
  })
  api <- task_test_api()
  task <- api$start(function(x) list(x), 1)
  error <- tryCatch(api$await(task), error = identity)
  stopifnot(inherits(error, 'rstarstar_error'), grepl('plain Number', conditionMessage(error)))
})

check("tasks cannot nest and compilation never starts workers or writes files", {
  with_execution_directory(function(directory) {
    with_source_file('fn save(path) { return std::write_text(path, "written") }\ntask = std::start_task(save, "output.txt")\nx = missing_name', function(path) {
      output <- capture.output(error <- tryCatch(RStarStar::run_file(path, working_dir = directory), error = identity))
      stopifnot(!length(output), inherits(error, 'rstarstar_error'), !file.exists(file.path(directory, 'output.txt')))
    })
    with_source_file('fn identity(x) { return x }\nfn nested(x) { return std::await_task(std::start_task(identity, x)) }\ntask = std::start_task(nested, 1)\nx = std::await_task(task)', function(path) {
      code <- RStarStar::transpile(path)
      stopifnot(is.character(code))
      error <- tryCatch(RStarStar::run_file(path), error = identity)
      stopifnot(inherits(error, 'rstarstar_error'), grepl('nested tasks', conditionMessage(error)))
    })
  })
})

check("task resource limit bounds uncollected workers and collection frees slots", {
  api <- task_test_api()
  tasks <- lapply(1:8, function(i) api$start(function(x) x, i))
  error <- tryCatch(api$start(function(x) x, 9), error = identity)
  stopifnot(inherits(error, 'rstarstar_error'), grepl('eight uncollected', conditionMessage(error)))
  stopifnot(identical(vapply(tasks, api$await, integer(1)), 1:8))
  next_task <- api$start(function(x) x, 9)
  stopifnot(api$await(next_task) == 9)
})

check("abandoned handles request cleanup after worker completion", {
  with_execution_directory(function(directory) {
    api <- task_test_api()
    worker <- function(path) {
      deadline <- proc.time()[['elapsed']] + 10
      while (!file.exists(path)) {
        if (proc.time()[['elapsed']] >= deadline) stop('release marker missing')
        Sys.sleep(0.01)
      }
      1
    }
    marker <- file.path(directory, 'finish')
    task <- api$start(worker, marker)
    transport <- task$directory
    rm(task)
    invisible(gc())
    stopifnot(file.exists(file.path(transport, 'released')))
    file.create(marker)
    deadline <- proc.time()[['elapsed']] + 10
    while (dir.exists(transport) && proc.time()[['elapsed']] < deadline) Sys.sleep(0.01)
    stopifnot(!dir.exists(transport))
  })
})

check("worker snapshots preserve earlier functions and object method helpers", {
  result <- run(paste('record Point { x: Number\nfn next(self) { return self.x + 1 }\n}',
    'fn offset(x) { return Point(x).next() }', 'fn calculate(x) { return offset(x) * 2 }',
    'task = std::start_task(calculate, 3)', 'answer = std::await_task(task)', sep = '\n'))$env
  stopifnot(result$answer == 8)
})

check("concurrent text writes have a single winner without overwriting", {
  with_execution_directory(function(directory) {
    with_source_file(paste('fn save(text) { return std::write_text("winner.txt", text) }',
      'fn wait(task) { return std::await_task(task) }',
      'first = std::start_task(save, "first")', 'second = std::start_task(save, "second")', sep = '\n'), function(path) {
      result <- RStarStar::run_file(path, working_dir = directory)
      answers <- lapply(list(result$first, result$second), function(task) tryCatch(result$wait(task), error = identity))
      success <- !vapply(answers, inherits, logical(1), 'error')
      stopifnot(sum(success) == 1L, inherits(answers[[which(!success)]], 'rstarstar_error'))
      contents <- readChar(file.path(directory, 'winner.txt'), 20)
      stopifnot(identical(contents, c('first', 'second')[[which(success)]]),
                !length(list.files(directory, pattern = '^\\.rstarstar-text-', all.files = TRUE)))
    })
  })
})

check("file and task generated R executes without RStarStar or R6", {
  with_execution_directory(function(directory) {
    code <- transpile(paste('fn save(path) { return std::write_text(path, "hello") }',
      'fn load(path) { return std::read_text(path) }', 'created = std::start_task(save, "data.txt")',
      'path = std::await_task(created)', 'loaded = std::start_task(load, path)',
      'text = std::await_task(loaded)', 'exists = std::file_exists(path)', sep = '\n'))
    script <- file.path(directory, 'standalone.R')
    writeLines(c(paste0('setwd(', encodeString(directory, quote = '"'), ')'), code,
      'stopifnot(text == "hello", exists, !"RStarStar" %in% loadedNamespaces(), !"R6" %in% loadedNamespaces())'), script)
    executable <- file.path(R.home('bin'), if (.Platform$OS.type == 'windows') 'Rscript.exe' else 'Rscript')
    output <- system2(executable, c('--vanilla', '--default-packages=NULL', shQuote(script)), stdout = TRUE, stderr = TRUE)
    stopifnot(is.null(attr(output, 'status')))
  })
})
