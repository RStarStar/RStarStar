# RStarStar's dependency-free initial compiler. Transpilation never evaluates input.
rss_error <- function(message, token, filename) {
  stop(structure(list(
    message = sprintf("%s:%d:%d: %s", filename, token$line, token$column, message),
    call = NULL, filename = filename, line = token$line, column = token$column,
    end_line = token$end_line, end_column = token$end_column
  ), class = c("rstarstar_error", "error", "condition")))
}

rss_tokenize <- function(source, filename) {
  source <- gsub("\r\n?", "\n", source)
  chars <- strsplit(source, "", fixed = TRUE)[[1L]]
  n <- length(chars)
  i <- 1L
  line <- 1L
  column <- 1L
  depth <- 0L
  tokens <- list()
  current <- function() if (i <= n) chars[[i]] else ""
  advance <- function() {
    if (current() == "\n") {
      line <<- line + 1L
      column <<- 1L
    } else {
      column <<- column + 1L
    }
    i <<- i + 1L
  }
  location <- function() list(line = line, column = column,
                              end_line = line, end_column = column)
  add <- function(kind, value, start) {
    start$kind <- kind
    start$value <- value
    start$end_line <- line
    start$end_column <- column # Exclusive end position.
    tokens[[length(tokens) + 1L]] <<- start
  }
  while (i <= n) {
    ch <- current()
    start <- location()
    if (ch %in% c(" ", "\t")) {
      advance()
    } else if (ch == "#") {
      while (i <= n && current() != "\n") advance()
    } else if (ch == "\n") {
      advance()
      if (depth == 0L) add("newline", "\n", start)
    } else if (grepl("^[A-Za-z_]$", ch)) {
      begin <- i
      while (i <= n && grepl("^[A-Za-z0-9_]$", current())) advance()
      value <- paste0(chars[begin:(i - 1L)], collapse = "")
      kind <- if (value %in% c("mut", "print", "true", "false", "read", "into", "with", "delimiter")) value else "name"
      add(kind, value, start)
    } else if (grepl("^[0-9]$", ch)) {
      rest <- paste0(chars[i:n], collapse = "")
      value <- regmatches(rest, regexpr("^[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?", rest))
      if (!is.finite(as.numeric(value))) rss_error("Number is outside the supported finite range.", start, filename)
      for (unused in seq_len(nchar(value))) advance()
      add("number", value, start)
    } else if (ch == '"') {
      advance()
      value <- ""
      while (i <= n && current() != '"') {
        if (current() == "\n") rss_error("Text must close on the same line; use \\n for a newline.", start, filename)
        if (current() == "\\") {
          escape_start <- location()
          advance()
          escapes <- c('"' = '"', "\\" = "\\", n = "\n", t = "\t", r = "\r")
          if (!(current() %in% names(escapes))) rss_error("Unsupported text escape. Use \\n, \\t, \\r, \\\\, or \\\".", escape_start, filename)
          value <- paste0(value, escapes[[current()]])
        } else {
          value <- paste0(value, current())
        }
        advance()
      }
      if (i > n) rss_error("Unclosed text literal; expected a double quote.", start, filename)
      advance()
      add("text", value, start)
    } else if (ch %in% c("=", "+", "-", "*", "/", "(", ")", "[", "]", ",")) {
      advance()
      if (ch %in% c("(", "[")) depth <- depth + 1L
      if (ch %in% c(")", "]")) depth <- max(0L, depth - 1L)
      add(ch, ch, start)
    } else {
      rss_error(sprintf("Unexpected character '%s'.", ch), start, filename)
    }
  }
  add("eof", "", location())
  tokens
}

rss_parse <- function(tokens, filename) {
  position <- 1L
  peek <- function() tokens[[position]]
  take <- function() {
    token <- peek()
    position <<- position + 1L
    token
  }
  expect <- function(kind, message) {
    if (peek()$kind != kind) rss_error(message, peek(), filename)
    take()
  }
  node <- function(kind, token, ...) {
    # Force child parsing before recording the exclusive end position.
    fields <- list(...)
    # Nodes span their entire construct; token retains the diagnostic start.
    end <- tokens[[max(1L, position - 1L)]]
    c(list(kind = kind, token = token,
           span = list(line = token$line, column = token$column,
                       end_line = end$end_line, end_column = end$end_column)), fields)
  }
  primary <- function() {
    token <- peek()
    if (token$kind %in% c("number", "text", "true", "false", "name")) {
      take()
      return(node(token$kind, token, value = token$value))
    }
    if (token$kind == "(") {
      take()
      value <- expression()
      expect(")", "Expected ')' to close the expression.")
      return(node("group", token, value = value))
    }
    if (token$kind == "[") {
      take()
      if (peek()$kind == "]") rss_error("Empty vectors need a type; they are not supported yet.", peek(), filename)
      values <- list(expression())
      while (peek()$kind == ",") {
        take()
        values[[length(values) + 1L]] <- expression()
      }
      expect("]", "Expected ']' to close the vector.")
      return(node("vector", token, values = values))
    }
    rss_error("Expected a value, variable, vector, or parenthesized expression.", token, filename)
  }
  unary <- function() {
    if (peek()$kind %in% c("+", "-")) {
      token <- take()
      return(node("unary", token, operator = token$kind, value = unary()))
    }
    primary()
  }
  product <- function() {
    value <- unary()
    while (peek()$kind %in% c("*", "/")) {
      operator <- take()
      value <- node("binary", value$token, operator = operator$kind,
                    operator_token = operator, left = value, right = unary())
    }
    value
  }
  expression <- function() {
    value <- product()
    while (peek()$kind %in% c("+", "-")) {
      operator <- take()
      value <- node("binary", value$token, operator = operator$kind,
                    operator_token = operator, left = value, right = product())
    }
    value
  }
  statements <- list()
  while (peek()$kind != "eof") {
    if (peek()$kind == "newline") {
      take()
      next
    }
    token <- peek()
    if (token$kind == "print") {
      take()
      statement <- node("print", token, value = expression())
    } else if (token$kind == "read") {
      take()
      path <- expect("text", "Expected a quoted CSV path after 'read'.")
      expect("into", "Expected 'into' after the CSV path.")
      mutable <- FALSE
      if (peek()$kind == "mut") {
        take()
        mutable <- TRUE
      }
      name <- expect("name", "Expected a variable name after 'into' or 'into mut'.")
      separator <- ","
      if (peek()$kind == "with") {
        take()
        expect("delimiter", "Expected 'delimiter' after 'with'.")
        delimiter <- expect("text", "Expected a quoted delimiter.")
        separator <- delimiter$value
        if (nchar(separator, type = "bytes") != 1L || separator %in% c('"', "\n", "\r")) {
          rss_error("Delimiter must be one ASCII character other than a quote or newline.", delimiter, filename)
        }
      }
      statement <- node("assign", token, name = name$value, name_token = name,
                        mutable = mutable,
                        value = node("read", token, path = path$value, separator = separator))
    } else {
      mutable <- FALSE
      if (token$kind == "mut") {
        take()
        mutable <- TRUE
      }
      name <- expect("name", "Expected a variable name or a 'print' statement.")
      expect("=", "Expected '=' after the variable name.")
      statement <- node("assign", token, name = name$value, name_token = name,
                        mutable = mutable, value = expression())
    }
    if (!(peek()$kind %in% c("newline", "eof"))) {
      rss_error("Expected a new line after the statement.", peek(), filename)
    }
    statements[[length(statements) + 1L]] <- statement
  }
  statements
}

rss_analyze <- function(statements, filename) {
  bindings <- new.env(parent = emptyenv())
  info <- function(type, size) list(type = type, size = size)
  infer <- function(value) {
    kind <- value$kind
    if (kind == "read") return(info("Table", 1L))
    if (kind == "number") return(info("Number", 1L))
    if (kind == "text") return(info("Text", 1L))
    if (kind %in% c("true", "false")) return(info("Boolean", 1L))
    if (kind == "name") {
      if (!exists(value$value, bindings, inherits = FALSE)) {
        rss_error(sprintf("Unknown variable '%s'. Define it before using it.", value$value), value$token, filename)
      }
      return(get(value$value, bindings, inherits = FALSE)$info)
    }
    if (kind == "group") return(infer(value$value))
    if (kind == "vector") {
      elements <- lapply(value$values, infer)
      if (any(vapply(elements, function(x) x$size != 1L, logical(1)))) {
        rss_error("Vector elements must each contain one value; nested vectors are not supported.", value$token, filename)
      }
      types <- vapply(elements, function(x) x$type, character(1))
      if (any(types == "Table")) rss_error("Tables cannot be vector elements.", value$token, filename)
      if (length(unique(types)) != 1L) rss_error("Vector elements must have the same type.", value$token, filename)
      return(info(types[[1L]], length(elements)))
    }
    if (kind == "unary") {
      operand <- infer(value$value)
      if (operand$type != "Number") rss_error("Arithmetic requires numbers; convert text explicitly when conversion is supported.", value$token, filename)
      return(operand)
    }
    left <- infer(value$left)
    right <- infer(value$right)
    if (left$type != "Number" || right$type != "Number") {
      rss_error("Arithmetic requires numbers; text and booleans are not converted automatically.", value$operator_token, filename)
    }
    if (left$size != right$size && left$size != 1L && right$size != 1L) {
      rss_error("Vector lengths must match, or one operand must contain a single value.", value$operator_token, filename)
    }
    info("Number", max(left$size, right$size))
  }
  for (statement in statements) {
    if (statement$kind == "print") {
      infer(statement$value)
      next
    }
    name <- statement$name
    existing <- exists(name, bindings, inherits = FALSE)
    if (existing) {
      previous <- get(name, bindings, inherits = FALSE)
      if (statement$mutable) rss_error(sprintf("Variable '%s' is already declared. Omit 'mut' to update a mutable binding.", name), statement$name_token, filename)
      if (!previous$mutable) rss_error(sprintf("Cannot reassign '%s'. Declare it with 'mut' if you intend to change it, or choose a new name.", name), statement$name_token, filename)
    }
    result <- infer(statement$value)
    if (existing && previous$info$type != result$type) {
      rss_error(sprintf("Cannot change '%s' from %s to %s.", name, previous$info$type, result$type), statement$name_token, filename)
    }
    assign(name, list(info = result, mutable = if (existing) previous$mutable else statement$mutable), bindings)
  }
  invisible(statements)
}

rss_generate <- function(statements, filename) {
  name <- function(value) paste0("`", value, "`")
  emit <- function(value) {
    switch(value$kind,
      read = paste0(".rss_read_csv(", encodeString(value$path, quote = '"'), ", ",
                    encodeString(value$separator, quote = '"'), ", ",
                    encodeString(filename, quote = '"'), ", ", value$token$line, "L, ",
                    value$token$column, "L)"),
      number = value$value,
      text = encodeString(value$value, quote = '"'),
      true = "TRUE",
      false = "FALSE",
      name = name(value$value),
      group = paste0("(", emit(value$value), ")"),
      vector = paste0("base::c(", paste(vapply(value$values, emit, character(1)), collapse = ", "), ")"),
      unary = paste0("(", value$operator, emit(value$value), ")"),
      binary = paste0("(", emit(value$left), " ", value$operator, " ", emit(value$right), ")")
    )
  }
  lines <- vapply(statements, function(statement) {
    if (statement$kind == "print") return(paste0("base::print(", emit(statement$value), ")"))
    paste0(name(statement$name), " <- ", emit(statement$value))
  }, character(1))
  if (any(vapply(statements, function(x) x$kind == "assign" && x$value$kind == "read", logical(1)))) {
    # Embed a self-contained helper; the output needs no compiler installation.
    helper <- paste(deparse(rss_read_csv, width.cutoff = 100L), collapse = "\n")
    lines <- c(paste0(".rss_read_csv <- ", helper), "", lines)
  }
  paste(lines, collapse = "\n")
}

# Return R source as a single string. The caller decides whether to save or run it.
transpile <- function(source, filename = "<input>") {
  if (!is.character(source) || length(source) != 1L || is.na(source)) {
    stop("source must be one non-missing character string.", call. = FALSE)
  }
  if (!is.character(filename) || length(filename) != 1L || is.na(filename)) {
    stop("filename must be one non-missing character string.", call. = FALSE)
  }
  tokens <- rss_tokenize(source, filename)
  statements <- rss_parse(tokens, filename)
  rss_analyze(statements, filename)
  rss_generate(statements, filename)
}

# Self-contained runtime helper, embedded only in programs containing read.
# Keep all dependencies inside this function or explicitly namespace-qualified.
rss_read_csv <- function(path, separator, filename, line, column) {
  fail <- function(message) {
    stop(structure(list(
      message = sprintf("%s:%d:%d: Cannot read CSV '%s': %s", filename, line, column, path, message),
      call = NULL, filename = filename, line = line, column = column,
      end_line = line, end_column = column + 4L
    ), class = c("rstarstar_error", "error", "condition")))
  }
  if (!file.exists(path) || dir.exists(path)) fail("expected an existing local file.")
  lines <- tryCatch(withCallingHandlers(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    warning = function(w) stop(conditionMessage(w), call. = FALSE)
  ), error = function(e) fail(conditionMessage(e)))
  if (!length(lines)) fail("the file is empty; expected a header row.")
  if (anyNA(iconv(lines, from = "UTF-8", to = "UTF-8"))) fail("expected valid UTF-8 text.")
  lines[[1L]] <- sub("^\ufeff", "", lines[[1L]])
  # readLines removes line endings. Restore them to retain empty records.
  chars <- strsplit(paste0(paste(lines, collapse = "\n"), "\n"), "", fixed = TRUE)[[1L]]
  records <- list()
  record <- character()
  field <- character()
  state <- "start"
  csv_line <- 1L
  record_line <- 1L
  width <- NULL
  finish_field <- function() {
    record <<- c(record, paste0(field, collapse = ""))
    field <<- character()
    state <<- "start"
  }
  finish_record <- function() {
    finish_field()
    if (is.null(width)) width <<- length(record)
    if (length(record) != width) {
      fail(sprintf("CSV row starting on line %d has %d fields; expected %d.", record_line, length(record), width))
    }
    records[[length(records) + 1L]] <<- record
    record <<- character()
    record_line <<- csv_line + 1L
  }
  for (ch in chars) {
    if (state == "quoted") {
      if (ch == '"') state <- "closed" else field <- c(field, ch)
    } else if (state == "closed" && ch == '"') {
      field <- c(field, '"')
      state <- "quoted"
    } else if (ch == separator) {
      finish_field()
    } else if (ch == "\n") {
      finish_record()
    } else if (state == "start" && ch == '"') {
      state <- "quoted"
    } else {
      if (state == "closed" || ch == '"') fail(sprintf("invalid quoting on CSV line %d.", csv_line))
      field <- c(field, ch)
      state <- "plain"
    }
    if (ch == "\n") csv_line <- csv_line + 1L
  }
  if (state == "quoted") fail(sprintf("unclosed quoted field starting in the row on CSV line %d.", record_line))
  header <- records[[1L]]
  if (any(!nzchar(trimws(header))) || anyDuplicated(header)) fail("column names must be nonempty and unique.")
  rows <- records[-1L]
  convert <- function(index) {
    values <- vapply(rows, function(row) row[[index]], character(1))
    missing <- values %in% c("", "NA")
    values[missing] <- NA_character_
    present <- values[!missing]
    if (!length(present)) return(values)
    numeric_pattern <- "^[+-]?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([eE][+-]?[0-9]+)?$"
    if (all(grepl(numeric_pattern, present))) {
      result <- as.numeric(values)
      if (any(!is.finite(result[!missing]))) fail(sprintf("column '%s' contains a number outside the finite range.", header[[index]]))
      return(result)
    }
    if (all(present %in% c("true", "false", "TRUE", "FALSE"))) {
      return(ifelse(is.na(values), NA, tolower(values) == "true"))
    }
    values
  }
  columns <- lapply(seq_along(header), convert)
  names(columns) <- header
  # Construct explicitly to preserve column names and header-only tables.
  structure(columns, class = "data.frame", row.names = seq_along(rows))
}
