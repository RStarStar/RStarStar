# The public file APIs are exercised in isolated folders; never write installed data.
check("text file operations round-trip UTF-8 exact line endings and empty text", {
  with_execution_directory(function(directory) {
    with_source_file(paste(
      'fn save(path, text) { return std::write_text(path, text) }',
      'fn load(path) { return std::read_text(path) }',
      'fn present(path) { return std::file_exists(path) }', sep = '\n'), function(path) {
      api <- RStarStar::run_file(path)
      for (text in c('', 'Hello', '\ufeffé\r\nline\n', 'ආයුබෝවන්')) {
        target <- tempfile('text with spaces ', tmpdir = directory)
        stopifnot(!api$present(target), identical(api$save(target, text), target),
                  api$present(target), identical(api$load(target), text),
                  identical(readBin(target, 'raw', n = file.info(target)$size), charToRaw(enc2utf8(text))))
      }
      stopifnot(!api$present(directory))
      latin <- rawToChar(as.raw(233)); Encoding(latin) <- 'latin1'
      target <- file.path(directory, 'latin.txt')
      api$save(target, latin)
      stopifnot(identical(api$load(target), '\u00e9'))
    })
  })
})

check("file operations validate exact labels arity scalar sizes and result types", {
  fails('x = std::read_text()', 'Missing required parameters')
  fails('x = std::file_exists(1)', "requires Text")
  fails('x = std::read_text(["a", "b"])', 'requires one value')
  fails('x = std::write_text("a", true)', 'requires Text')
  fails('x = std::write_text(path: "a", path: "b")', 'more than once')
  fails('x = std::read_text(file: "a")', 'Unknown parameter')
  fails('x = std::write_text("a", "b", "c")', 'Too many arguments')
  fails('x = std::file_exists("a") + 1', 'Arithmetic requires numbers')
  fails('mut x = 1\nx = std::read_text("a")', 'Cannot change')
})

check("text I/O rejects unsafe inputs and existing destinations without changes", {
  with_execution_directory(function(directory) {
    with_source_file('fn load(path) { return std::read_text(path) }\nfn save(path, text) { return std::write_text(path, text) }\nfn present(path) { return std::file_exists(path) }', function(path) {
      api <- RStarStar::run_file(path)
      destination <- file.path(directory, 'existing.txt')
      writeLines('original', destination)
      invalid <- rawToChar(as.raw(c(0xc3, 0x28))); Encoding(invalid) <- 'UTF-8'
      bytes <- rawToChar(as.raw(c(0xc3, 0xa9))); Encoding(bytes) <- 'bytes'
      for (bad in list(NULL, NA_character_, '', 1, TRUE, c('a', 'b'), c(named = 'a'), matrix('a'), invalid, bytes, 'https://example.invalid/data')) {
        for (operation in list(api$load, api$present, function(x) api$save(x, 'new'))) {
          error <- tryCatch(operation(bad), error = identity)
          stopifnot(inherits(error, 'rstarstar_error'))
        }
      }
      for (bad in list(NA_character_, character(), c('a', 'b'), 1, TRUE, c(named = 'a'), matrix('a'), invalid, bytes)) {
        error <- tryCatch(api$save(file.path(directory, 'not-created.txt'), bad), error = identity)
        stopifnot(inherits(error, 'rstarstar_error'), !file.exists(file.path(directory, 'not-created.txt')))
      }
      for (target in c(destination, directory, file.path(directory, 'absent', 'file.txt'))) {
        stopifnot(inherits(tryCatch(api$save(target, 'new'), error = identity), 'rstarstar_error'))
      }
      stopifnot(identical(readLines(destination), 'original'),
                !length(list.files(directory, pattern = '^\\.rstarstar-text-', all.files = TRUE)))
      for (contents in list(as.raw(c(65, 0, 66)), as.raw(255))) {
        target <- file.path(directory, 'invalid.txt')
        writeBin(contents, target)
        error <- tryCatch(api$load(target), error = identity)
        stopifnot(inherits(error, 'rstarstar_error'), error$line == 1L,
                  identical(error$filename, normalizePath(path, winslash = '/')))
      }
      stopifnot(inherits(tryCatch(api$load(directory), error = identity), 'rstarstar_error'))
    })
  })
})

check("file effects happen only on execution with eager source-order arguments", {
  with_execution_directory(function(directory) {
    with_source_file(paste(
      'saved = std::write_text(text: std::write_text("destination.txt", "outer.txt"), path: std::read_text("destination.txt"))',
      'exists = std::file_exists(saved)', 'content = std::read_text(saved)', sep = '\n'), function(path) {
      previous <- getwd()
      setwd(directory)
      on.exit(setwd(previous), add = TRUE)
      output <- capture.output(code <- RStarStar::transpile(path))
      stopifnot(!length(output), !file.exists('destination.txt'), !file.exists('outer.txt'))
      result <- RStarStar::run_file(path)
      stopifnot(result$exists, result$content == 'destination.txt')
    })
    with_source_file('saved = std::write_text("should-not-exist.txt", "x")\nx = absent', function(path) {
      error <- tryCatch(RStarStar::run_file(path, working_dir = directory), error = identity)
      stopifnot(inherits(error, 'rstarstar_error'), !file.exists(file.path(directory, 'should-not-exist.txt')))
    })
  })
})

check("file errors retain source locations and language call chains", {
  error <- tryCatch(run('fn load(path) { return std::read_text(path) }\nx = load("definitely-absent-rstarstar-file")'), error = identity)
  stopifnot(inherits(error, 'rstarstar_error'), error$line == 1L, error$column == 24L,
            grepl('called at test.input:2:5', conditionMessage(error), fixed = TRUE))
  stopifnot(run('x = if true then "ok" else std::read_text("absent")')$env$x == 'ok')
})
