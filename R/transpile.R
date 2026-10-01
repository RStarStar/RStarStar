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
      kind <- if (value %in% c("mut", "print", "true", "false", "read", "into", "with", "delimiter", "filter", "where", "skipping", "missing", "is", "and", "or", "not")) value else "name"
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
    } else if (ch %in% c("=", "!", "<", ">") && i < n && chars[[i + 1L]] == "=") {
      advance()
      advance()
      add(paste0(ch, "="), paste0(ch, "="), start)
    } else if (ch %in% c(".", "@", "<", ">", "=", "+", "-", "*", "/", "(", ")", "[", "]", ",")) {
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
      if (token$kind == "name" && peek()$kind == ".") {
        take()
        column <- peek()
        if (!(column$kind %in% c("name", "text"))) rss_error("Expected a column name or quoted column after '.'.", column, filename)
        take()
        return(node("column", token, table = token$value, column = column$value))
      }
      return(node(token$kind, token, value = token$value))
    }
    if (token$kind == "@") {
      take()
      variable <- expect("name", "Expected a variable name after '@'.")
      return(node("local", token, value = variable$value))
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
  sum_expression <- function() {
    value <- product()
    while (peek()$kind %in% c("+", "-")) {
      operator <- take()
      value <- node("binary", value$token, operator = operator$kind,
                    operator_token = operator, left = value, right = product())
    }
    value
  }
  comparison <- function() {
    value <- sum_expression()
    if (peek()$kind == "is") {
      operator <- take()
      negate <- FALSE
      if (peek()$kind == "not") { take(); negate <- TRUE }
      expect("missing", "Expected 'missing' or 'not missing' after 'is'.")
      return(node("missing", value$token, value = value, negate = negate))
    }
    comparisons <- c("==", "!=", "<", "<=", ">", ">=")
    if (peek()$kind %in% comparisons) {
      operator <- take()
      value <- node("binary", value$token, operator = operator$kind,
                    operator_token = operator, left = value, right = sum_expression())
      if (peek()$kind %in% comparisons) rss_error("Comparisons cannot be chained; join separate comparisons with 'and'.", peek(), filename)
    }
    value
  }
  negation <- function() {
    if (peek()$kind == "not") {
      token <- take()
      return(node("unary", token, operator = "not", value = negation()))
    }
    comparison()
  }
  conjunction <- function() {
    value <- negation()
    while (peek()$kind == "and") {
      operator <- take()
      value <- node("binary", value$token, operator = "and",
                    operator_token = operator, left = value, right = negation())
    }
    value
  }
  expression <- function() {
    value <- conjunction()
    while (peek()$kind == "or") {
      operator <- take()
      value <- node("binary", value$token, operator = "or",
                    operator_token = operator, left = value, right = conjunction())
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
    } else if (token$kind == "filter") {
      take()
      table <- expect("name", "Expected a table variable after 'filter'.")
      expect("where", "Expected 'where' after the table name.")
      predicate <- expression()
      skip <- FALSE
      if (peek()$kind == "skipping") {
        take()
        expect("missing", "Expected 'missing' after 'skipping'.")
        skip <- TRUE
      }
      expect("into", "Expected 'into' after the filter condition.")
      mutable <- FALSE
      if (peek()$kind == "mut") { take(); mutable <- TRUE }
      target <- expect("name", "Expected a variable name after 'into' or 'into mut'.")
      statement <- node("assign", token, name = target$value, name_token = target,
                        mutable = mutable, value = node("filter", token, table = table$value,
                        table_token = table, predicate = predicate, skip = skip))
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
  lookup <- function(name, token) {
    if (!exists(name, bindings, inherits = FALSE)) {
      rss_error(sprintf("Unknown variable '%s'. Define it before using it.", name), token, filename)
    }
    get(name, bindings, inherits = FALSE)$info
  }
  require_table <- function(name, token) {
    if (!lookup(name, token)$type %in% c("Table", "Unknown")) rss_error("Column access and filtering require a table.", token, filename)
  }
  infer <- function(value, in_filter = FALSE) {
    kind <- value$kind
    recurse <- function(x) infer(x, in_filter)
    if (kind == "read") return(info("Table", 1L))
    if (kind == "filter") {
      require_table(value$table, value$table_token)
      predicate <- infer(value$predicate, TRUE)
      if (!predicate$type %in% c("Boolean", "Unknown")) rss_error("Filter condition must be boolean.", value$predicate$token, filename)
      return(info("Table", 1L))
    }
    if (kind == "column") {
      require_table(value$table, value$token)
      return(info("Unknown", NA_integer_))
    }
    if (kind == "local") return(lookup(value$value, value$token))
    if (kind == "number") return(info("Number", 1L))
    if (kind == "text") return(info("Text", 1L))
    if (kind %in% c("true", "false")) return(info("Boolean", 1L))
    if (kind == "name") {
      if (in_filter) return(info("Unknown", NA_integer_))
      return(lookup(value$value, value$token))
    }
    if (kind == "group") return(recurse(value$value))
    if (kind == "missing") {
      operand <- recurse(value$value)
      if (operand$type == "Table") rss_error("Test a column or vector for missing values, not a table.", value$token, filename)
      return(info("Boolean", operand$size))
    }
    if (kind == "vector") {
      elements <- lapply(value$values, recurse)
      if (any(vapply(elements, function(x) !is.na(x$size) && x$size != 1L, logical(1)))) {
        rss_error("Vector elements must each contain one value; nested vectors are not supported.", value$token, filename)
      }
      types <- vapply(elements, function(x) x$type, character(1))
      if (any(types == "Table")) rss_error("Tables cannot be vector elements.", value$token, filename)
      known <- unique(types[types != "Unknown"])
      if (length(known) > 1L) rss_error("Vector elements must have the same type.", value$token, filename)
      return(info(if (length(known)) known[[1L]] else "Unknown", length(elements)))
    }
    if (kind == "unary") {
      operand <- recurse(value$value)
      required <- if (value$operator == "not") "Boolean" else "Number"
      if (!operand$type %in% c(required, "Unknown")) rss_error(if (required == "Number") "Arithmetic requires numbers." else "Logical operations require booleans.", value$token, filename)
      return(info(required, operand$size))
    }
    left <- recurse(value$left)
    right <- recurse(value$right)
    op <- value$operator
    types <- c(left$type, right$type)
    known <- types[types != "Unknown"]
    if (op %in% c("+", "-", "*", "/")) {
      if (any(known != "Number")) rss_error("Arithmetic requires numbers; text and booleans are not converted automatically.", value$operator_token, filename)
      result_type <- "Number"
    } else if (op %in% c("and", "or")) {
      if (any(known != "Boolean")) rss_error("Logical operations require booleans.", value$operator_token, filename)
      result_type <- "Boolean"
    } else {
      if ("Table" %in% known || length(unique(known)) > 1L) rss_error("Comparisons require matching value types.", value$operator_token, filename)
      if (op %in% c("<", "<=", ">", ">=") && "Boolean" %in% known) rss_error("Ordered comparisons require numbers or text.", value$operator_token, filename)
      result_type <- "Boolean"
    }
    sizes <- c(left$size, right$size)
    if (!anyNA(sizes) && left$size != right$size && left$size != 1L && right$size != 1L) {
      rss_error("Vector lengths must match, or one operand must contain a single value.", value$operator_token, filename)
    }
    size <- if (anyNA(sizes)) NA_integer_ else if (0L %in% sizes) 0L else max(sizes)
    info(result_type, size)
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
    if (existing && previous$info$type != "Unknown" && result$type != "Unknown" && previous$info$type != result$type) {
      rss_error(sprintf("Cannot change '%s' from %s to %s.", name, previous$info$type, result$type), statement$name_token, filename)
    }
    assign(name, list(info = result, mutable = if (existing) previous$mutable else statement$mutable), bindings)
  }
  invisible(statements)
}

rss_generate <- function(statements, filename) {
  name <- function(value) paste0("`", value, "`")
  quote_text <- function(value) encodeString(value, quote = '"')
  has_data <- any(vapply(statements, function(x) x$kind == "assign" && x$value$kind == "read", logical(1)))
  needs_runtime <- FALSE
  call_runtime <- function(method, args, token) {
    needs_runtime <<- TRUE
    paste0(".rss$", method, "(", paste(c(args, quote_text(filename), paste0(token$line, "L"),
           paste0(token$column, "L")), collapse = ", "), ")")
  }
  emit <- function(value, table = NULL) {
    recurse <- function(x) emit(x, table)
    switch(value$kind,
      read = paste0(".rss_read_csv(", quote_text(value$path), ", ", quote_text(value$separator),
                    ", ", quote_text(filename), ", ", value$token$line, "L, ", value$token$column, "L)"),
      filter = {
        predicate <- emit(value$predicate, name(value$table))
        call_runtime("filter", c(name(value$table), predicate, if (value$skip) "TRUE" else "FALSE"), value$token)
      },
      column = call_runtime("column", c(name(value$table), quote_text(value$column)), value$token),
      local = name(value$value),
      number = value$value,
      text = quote_text(value$value),
      true = "TRUE",
      false = "FALSE",
      name = if (is.null(table)) name(value$value) else call_runtime("column", c(table, quote_text(value$value)), value$token),
      group = paste0("(", recurse(value$value), ")"),
      missing = if (has_data) call_runtime("missing", c(recurse(value$value), if (value$negate) "TRUE" else "FALSE"), value$token) else
        paste0(if (value$negate) "!" else "", "base::is.na(", recurse(value$value), ")"),
      vector = if (!has_data) paste0("base::c(", paste(vapply(value$values, recurse, character(1)), collapse = ", "), ")") else call_runtime("vector", paste0("base::list(", paste(vapply(value$values, recurse, character(1)), collapse = ", "), ")"), value$token),
      unary = if (!has_data) paste0("(", if (value$operator == "not") "!" else value$operator, recurse(value$value), ")") else call_runtime("unary", c(quote_text(value$operator), recurse(value$value)), value$token),
      binary = if (!has_data) paste0("(", recurse(value$left), " ", switch(value$operator, "and" = "&", "or" = "|", value$operator), " ", recurse(value$right), ")") else call_runtime("binary", c(quote_text(value$operator), recurse(value$left), recurse(value$right)), value$operator_token)
    )
  }
  declared <- character()
  lines <- vapply(statements, function(statement) {
    if (statement$kind == "print") return(paste0("base::print(", emit(statement$value), ")"))
    rhs <- emit(statement$value)
    if (has_data && statement$name %in% declared) rhs <- call_runtime("update", c(name(statement$name), rhs), statement$name_token)
    declared <<- c(declared, statement$name)
    paste0(name(statement$name), " <- ", rhs)
  }, character(1))
  helpers <- character()
  if (needs_runtime) helpers <- c(helpers, paste0(".rss <- (", paste(deparse(rss_runtime, width.cutoff = 100L), collapse = "\n"), ")()"))
  if (has_data) {
    helpers <- c(helpers, paste0(".rss_read_csv <- ", paste(deparse(rss_read_csv, width.cutoff = 100L), collapse = "\n")))
  }
  paste(c(helpers, if (length(helpers)) "", lines), collapse = "\n")
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

# Embedded expression checks also cover values whose CSV type/length is unknown
# until execution. All closures live in a private environment in generated R.
rss_runtime <- function() {
  fail <- function(message, filename, line, column) {
    stop(structure(list(message = sprintf("%s:%d:%d: %s", filename, line, column, message),
                        call = NULL, filename = filename, line = line, column = column,
                        end_line = line, end_column = column + 1L),
                   class = c("rstarstar_error", "error", "condition")))
  }
  type <- function(value) {
    if (is.data.frame(value)) return("Table")
    if (is.numeric(value)) return("Number")
    if (is.character(value)) return("Text")
    if (is.logical(value)) return("Boolean")
    "Unsupported"
  }
  binary <- function(op, left, right, filename, line, column) {
    error <- function(message) fail(message, filename, line, column)
    types <- c(type(left), type(right))
    if (op %in% c("+", "-", "*", "/")) {
      if (any(types != "Number")) error("Arithmetic requires numbers; text and booleans are not converted automatically.")
    } else if (op %in% c("and", "or")) {
      if (any(types != "Boolean")) error("Logical operations require booleans.")
    } else {
      if (types[[1L]] != types[[2L]] || any(types %in% c("Table", "Unsupported"))) error("Comparisons require matching value types.")
      if (op %in% c("<", "<=", ">", ">=") && types[[1L]] == "Boolean") error("Ordered comparisons require numbers or text.")
    }
    a <- length(left)
    b <- length(right)
    if (a != b && a != 1L && b != 1L) error("Vector lengths must match, or one operand must contain a single value.")
    switch(op, "+" = left + right, "-" = left - right, "*" = left * right, "/" = left / right,
           "==" = left == right, "!=" = left != right, "<" = left < right, "<=" = left <= right,
           ">" = left > right, ">=" = left >= right, "and" = left & right, "or" = left | right)
  }
  list(
    binary = binary,
    unary = function(op, value, filename, line, column) {
      expected <- if (op == "not") "Boolean" else "Number"
      if (type(value) != expected) fail(if (op == "not") "Logical operations require booleans." else "Arithmetic requires numbers.", filename, line, column)
      switch(op, "not" = !value, "+" = +value, "-" = -value)
    },
    vector = function(values, filename, line, column) {
      if (any(lengths(values) != 1L)) fail("Vector elements must each contain one value.", filename, line, column)
      types <- vapply(values, type, character(1))
      if (any(types %in% c("Table", "Unsupported")) || length(unique(types)) != 1L) fail("Vector elements must have the same non-table type.", filename, line, column)
      do.call(base::c, values)
    },
    column = function(table, name, filename, line, column) {
      if (!is.data.frame(table)) fail("Column access requires a table.", filename, line, column)
      if (!(name %in% names(table))) fail(sprintf("Unknown column '%s'. Check the table's column names.", name), filename, line, column)
      table[[name, exact = TRUE]]
    },
    missing = function(value, negate, filename, line, column) {
      if (type(value) %in% c("Table", "Unsupported")) fail("Test a column or vector for missing values, not a table.", filename, line, column)
      result <- is.na(value)
      if (negate) !result else result
    },
    filter = function(table, predicate, skip, filename, line, column) {
      if (!is.data.frame(table)) fail("Filtering requires a table.", filename, line, column)
      if (!is.logical(predicate)) fail("Filter condition must be boolean.", filename, line, column)
      if (length(predicate) != 1L && length(predicate) != nrow(table)) fail("Filter condition must have one value or one value per row.", filename, line, column)
      if (anyNA(predicate) && !skip) fail("Filter condition contains missing values. Use 'skipping missing' to drop those rows, or test 'is missing'.", filename, line, column)
      predicate[is.na(predicate)] <- FALSE
      if (length(predicate) == 1L) predicate <- rep(predicate, nrow(table))
      result <- table[predicate, , drop = FALSE]
      rownames(result) <- NULL
      result
    },
    update = function(previous, value, filename, line, column) {
      if (type(previous) != type(value)) fail(sprintf("Cannot change binding from %s to %s.", type(previous), type(value)), filename, line, column)
      value
    }
  )
}
