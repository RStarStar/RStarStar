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
      kind <- if (value %in% c("mut", "print", "true", "false", "read", "into", "with", "delimiter", "filter", "where", "skipping", "missing", "is", "and", "or", "not", "plot", "summarize", "fn", "return", "write", "if", "then", "else", "record")) value else "name"
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
    } else if (ch %in% c("{", "}", ":", ".", "@", "<", ">", "=", "+", "-", "*", "/", "(", ")", "[", "]", ",")) {
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
  atom <- function() {
    token <- peek()
    if (token$kind == "if") {
      take()
      condition <- expression()
      expect("then", "Expected 'then' after the condition.")
      yes <- expression()
      expect("else", "Expected 'else' and a fallback value.")
      no <- expression()
      return(node("conditional", token, condition = condition, yes = yes, no = no))
    }
    if (token$kind == "name" && token$value %in% c("average", "sum", "count") && tokens[[position + 1L]]$kind == "(") {
      take()
      take()
      value <- expression()
      expect(")", "Expected ')' after the summary input.")
      skip <- FALSE
      if (peek()$kind == "skipping") {
        take()
        expect("missing", "Expected 'missing' after 'skipping'.")
        skip <- TRUE
      }
      return(node("summary", token, operation = token$value, value = value, skip = skip))
    }
    if (token$kind %in% c("number", "text", "true", "false", "name")) {
      take()
      if (token$kind == "name" && peek()$kind == "(") {
        take()
        arguments <- list()
        labels <- character()
        argument_tokens <- list()
        named <- FALSE
        if (peek()$kind != ")") {
          repeat {
            start <- peek()
            label <- ""
            if (peek()$kind == "name" && tokens[[position + 1L]]$kind == ":") {
              label <- take()$value
              take()
              named <- TRUE
            } else if (named) {
              rss_error("Positional arguments must come before named arguments.", start, filename)
            }
            arguments[[length(arguments) + 1L]] <- expression()
            labels <- c(labels, label)
            argument_tokens[[length(argument_tokens) + 1L]] <- start
            if (peek()$kind != ",") break
            take()
          }
        }
        expect(")", "Expected ')' after function arguments.")
        return(node("call", token, name = token$value, arguments = arguments,
                    labels = labels, argument_tokens = argument_tokens))
      }
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
  primary <- function() {
    value <- atom()
    while (peek()$kind == "with") {
      token <- take()
      expect("{", "Expected '{' after 'with' for a record update.")
      while (peek()$kind == "newline") take()
      fields <- character()
      values <- list()
      field_tokens <- list()
      if (peek()$kind == "}") rss_error("A record update must name at least one field.", peek(), filename)
      repeat {
        field <- expect("name", "Expected a field name in the record update.")
        if (field$value %in% fields) rss_error("Record update field names must be unique.", field, filename)
        expect(":", "Expected ':' before the replacement value.")
        fields <- c(fields, field$value)
        field_tokens[[length(field_tokens) + 1L]] <- field
        values[[length(values) + 1L]] <- expression()
        while (peek()$kind == "newline") take()
        if (peek()$kind != ",") break
        take()
        while (peek()$kind == "newline") take()
      }
      expect("}", "Expected '}' after the record update; separate fields with commas.")
      updated <- node("record_update", token, value = value, fields = fields,
                      values = values, field_tokens = field_tokens)
      updated$span$line <- value$span$line
      updated$span$column <- value$span$column
      value <- updated
    }
    value
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
    if (token$kind == "record") {
      take()
      name <- expect("name", "Expected a record name after 'record'.")
      if (name$value %in% c("average", "sum", "count")) rss_error("A record cannot replace a built-in summary.", name, filename)
      expect("{", "Expected '{' before record fields.")
      fields <- character()
      types <- character()
      while (peek()$kind == "newline") take()
      while (peek()$kind != "}") {
        if (peek()$kind == "eof") rss_error("Expected '}' to close the record.", peek(), filename)
        field <- expect("name", "Expected a field name or '}' in the record.")
        if (field$value %in% fields) rss_error("Record field names must be unique.", field, filename)
        expect(":", "Expected ':' and a type after the field name.")
        type <- expect("name", "Expected Number, Text, or Boolean after ':'.")
        if (!type$value %in% c("Number", "Text", "Boolean")) rss_error("Record fields currently support Number, Text, or Boolean only.", type, filename)
        fields <- c(fields, field$value)
        types <- c(types, type$value)
        if (peek()$kind == "eof") rss_error("Expected '}' to close the record.", peek(), filename)
        if (!peek()$kind %in% c("newline", "}")) rss_error("Expected a new line between record fields.", peek(), filename)
        while (peek()$kind == "newline") take()
      }
      take()
      if (!length(fields)) rss_error("A record must declare at least one field.", name, filename)
      statement <- node("record", token, name = name$value, name_token = name, fields = fields, types = types)
    } else if (token$kind == "fn") {
      take()
      name <- expect("name", "Expected a function name after 'fn'.")
      if (name$value %in% c("average", "sum", "count")) rss_error("A function cannot replace a built-in summary.", name, filename)
      expect("(", "Expected '(' after the function name.")
      parameters <- character()
      if (peek()$kind != ")") {
        repeat {
          parameter <- expect("name", "Expected a parameter name.")
          if (parameter$value %in% parameters) rss_error("Parameter names must be unique.", parameter, filename)
          parameters <- c(parameters, parameter$value)
          if (peek()$kind != ",") break
          take()
        }
      }
      expect(")", "Expected ')' after function parameters.")
      expect("{", "Expected '{' before the function body.")
      while (peek()$kind == "newline") take()
      expect("return", "Functions currently require one 'return' expression.")
      body <- expression()
      while (peek()$kind == "newline") take()
      expect("}", "Expected '}' after the return expression; multi-statement functions are not supported yet.")
      statement <- node("function", token, name = name$value, name_token = name,
                        parameters = parameters, body = body)
    } else if (token$kind == "print") {
      take()
      statement <- node("print", token, value = expression())
    } else if (token$kind == "summarize") {
      take()
      table <- expect("name", "Expected a table variable after 'summarize'.")
      if (peek()$kind != "name" || peek()$value != "by") rss_error("Expected 'by' before the grouping column.", peek(), filename)
      take()
      keys <- character()
      repeat {
        key <- peek()
        if (!key$kind %in% c("name", "text")) rss_error("Expected a grouping column name or quoted header.", key, filename)
        take()
        if (key$value %in% keys) rss_error("Grouping columns must be unique.", key, filename)
        keys <- c(keys, key$value)
        if (peek()$kind != ",") break
        take()
      }
      expect("with", "Expected 'with' before the named summaries.")
      summaries <- list()
      repeat {
        label <- expect("name", "Expected a name for the summary output column.")
        expect("=", "Expected '=' after the summary output name.")
        value <- expression()
        if (value$kind != "summary" || !value$value$kind %in% c("name", "column")) {
          rss_error("Each grouped result must be average(column), sum(column), or count(column).", value$token, filename)
        }
        if (value$value$kind == "column" && value$value$table != table$value) rss_error("Grouped summaries must use columns from the input table.", value$value$token, filename)
        summaries[[length(summaries) + 1L]] <- list(name = label$value, value = value)
        if (peek()$kind != ",") break
        take()
      }
      labels <- c(keys, vapply(summaries, function(x) x$name, character(1)))
      if (anyDuplicated(labels)) rss_error("Summary output names must be unique and different from all grouping columns.", token, filename)
      expect("into", "Expected 'into' after the grouped summaries.")
      mutable <- FALSE
      if (peek()$kind == "mut") { take(); mutable <- TRUE }
      target <- expect("name", "Expected a target variable after 'into' or 'into mut'.")
      statement <- node("assign", token, name = target$value, name_token = target,
                        mutable = mutable, value = node("summarize", token,
                        table = table$value, table_token = table, keys = keys, summaries = summaries))
    } else if (token$kind == "write") {
      take()
      table <- expect("name", "Expected a table variable after 'write'.")
      if (peek()$kind != "name" || peek()$value != "to") rss_error("Expected 'to' before the CSV output path.", peek(), filename)
      take()
      path <- expect("text", "Expected a quoted CSV output path.")
      if (!grepl("\\.csv$", path$value, ignore.case = TRUE)) rss_error("Table export requires a .csv output path.", path, filename)
      statement <- node("write", token, table = table$value, table_token = table, path = path$value)
    } else if (token$kind == "plot") {
      take()
      table <- expect("name", "Expected a table variable after 'plot'.")
      word <- function(value) {
        if (peek()$kind != "name" || peek()$value != value) rss_error(sprintf("Expected '%s' in the plot statement.", value), peek(), filename)
        take()
      }
      column_name <- function() {
        if (!peek()$kind %in% c("name", "text")) rss_error("Expected a column name or quoted header.", peek(), filename)
        take()$value
      }
      word("x")
      x <- column_name()
      word("y")
      y <- column_name()
      word("as")
      word("bar")
      word("to")
      path <- expect("text", "Expected a quoted PNG output path.")
      if (!grepl("\\.png$", path$value, ignore.case = TRUE)) rss_error("Bar charts currently require a .png output path.", path, filename)
      statement <- node("plot", token, table = table$value, table_token = table,
                        x = x, y = y, path = path$value)
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
  records <- new.env(parent = emptyenv())
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
    if (kind == "record_update") {
      receiver <- recurse(value$value)
      if (receiver$type != "Unknown" && !startsWith(receiver$type, "Record:")) rss_error("A with update requires a record.", value$token, filename)
      schema <- if (receiver$type == "Unknown") NULL else get(receiver$type, records, inherits = FALSE)
      for (i in seq_along(value$fields)) {
        field <- value$fields[[i]]
        if (!is.null(schema) && !field %in% names(schema)) rss_error(sprintf("Unknown record field '%s'.", field), value$field_tokens[[i]], filename)
        replacement <- recurse(value$values[[i]])
        if (!is.null(schema) && (!replacement$type %in% c(schema[[field]], "Unknown") ||
            (!is.na(replacement$size) && replacement$size != 1L))) {
          rss_error(sprintf("Field '%s' requires one %s value.", field, schema[[field]]), value$field_tokens[[i]], filename)
        }
      }
      return(info(receiver$type, 1L))
    }
    if (kind == "conditional") {
      condition <- recurse(value$condition)
      if (!condition$type %in% c("Boolean", "Unknown")) rss_error("An if condition must be boolean.", value$condition$token, filename)
      if (!is.na(condition$size) && condition$size != 1L) rss_error("An if condition must contain exactly one boolean.", value$condition$token, filename)
      yes <- recurse(value$yes)
      no <- recurse(value$no)
      return(info(if (yes$type == no$type) yes$type else "Unknown",
                  if (!is.na(yes$size) && !is.na(no$size) && yes$size == no$size) yes$size else NA_integer_))
    }
    if (kind == "call") {
      target <- lookup(value$name, value$token)
      if (target$type != "Function") rss_error(sprintf("'%s' is not a declared function.", value$name), value$token, filename)
      if (length(value$arguments) != length(target$parameters)) rss_error(sprintf("Function '%s' expects %d arguments; received %d.", value$name, length(target$parameters), length(value$arguments)), value$token, filename)
      matched <- integer()
      for (i in seq_along(value$arguments)) {
        label <- value$labels[[i]]
        parameter <- if (nzchar(label)) match(label, target$parameters) else i
        if (is.na(parameter)) rss_error(sprintf("Unknown parameter '%s' for function '%s'; names must match exactly.", label, value$name), value$argument_tokens[[i]], filename)
        if (parameter %in% matched) rss_error(sprintf("Parameter '%s' was supplied more than once.", target$parameters[[parameter]]), value$argument_tokens[[i]], filename)
        matched <- c(matched, parameter)
      }
      arguments <- lapply(value$arguments, recurse)
      if (!is.null(target$field_types)) {
        for (i in seq_along(arguments)) {
          expected <- target$field_types[[matched[[i]]]]
          actual <- arguments[[i]]
          if (!actual$type %in% c(expected, "Unknown") || (!is.na(actual$size) && actual$size != 1L)) {
            rss_error(sprintf("Field '%s' requires one %s value.", target$parameters[[matched[[i]]]], expected), value$argument_tokens[[i]], filename)
          }
        }
      }
      return(target$result)
    }
    if (kind == "read") return(info("Table", 1L))
    if (kind == "summarize") {
      require_table(value$table, value$table_token)
      return(info("Table", 1L))
    }
    if (kind == "summary") {
      operand <- recurse(value$value)
      if (value$operation != "count" && !operand$type %in% c("Number", "Unknown")) rss_error("Numeric summaries require numbers.", value$token, filename)
      if (startsWith(operand$type, "Record:")) rss_error("Summaries require a vector or table, not a record.", value$token, filename)
      if (value$operation == "count" && operand$type == "Table" && value$skip) rss_error("count(table) counts rows; choose a column to skip missing values.", value$token, filename)
      return(info("Number", 1L))
    }
    if (kind == "filter") {
      require_table(value$table, value$table_token)
      predicate <- infer(value$predicate, TRUE)
      if (!predicate$type %in% c("Boolean", "Unknown")) rss_error("Filter condition must be boolean.", value$predicate$token, filename)
      return(info("Table", 1L))
    }
    if (kind == "column") {
      receiver <- lookup(value$table, value$token)
      if (startsWith(receiver$type, "Record:")) {
        schema <- get(receiver$type, records, inherits = FALSE)
        if (!value$column %in% names(schema)) rss_error(sprintf("Unknown record field '%s'.", value$column), value$token, filename)
        return(info(schema[[value$column]], 1L))
      }
      require_table(value$table, value$token)
      return(info("Unknown", NA_integer_))
    }
    if (kind == "local") {
      result <- lookup(value$value, value$token)
      if (result$type == "Function") rss_error("Functions must be called; function values are not supported yet.", value$token, filename)
      return(result)
    }
    if (kind == "number") return(info("Number", 1L))
    if (kind == "text") return(info("Text", 1L))
    if (kind %in% c("true", "false")) return(info("Boolean", 1L))
    if (kind == "name") {
      if (in_filter) return(info("Unknown", NA_integer_))
      result <- lookup(value$value, value$token)
      if (result$type == "Function") rss_error("Functions must be called; function values are not supported yet.", value$token, filename)
      return(result)
    }
    if (kind == "group") return(recurse(value$value))
    if (kind == "missing") {
      operand <- recurse(value$value)
      if (startsWith(operand$type, "Record:")) rss_error("Test a record field for missing values, not a record.", value$token, filename)
      if (operand$type == "Table") rss_error("Test a column or vector for missing values, not a table.", value$token, filename)
      return(info("Boolean", operand$size))
    }
    if (kind == "vector") {
      elements <- lapply(value$values, recurse)
      if (any(vapply(elements, function(x) !is.na(x$size) && x$size != 1L, logical(1)))) {
        rss_error("Vector elements must each contain one value; nested vectors are not supported.", value$token, filename)
      }
      types <- vapply(elements, function(x) x$type, character(1))
      if (any(startsWith(types, "Record:"))) rss_error("Records cannot be vector elements yet.", value$token, filename)
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
      if (any(startsWith(known, "Record:")) && !op %in% c("==", "!=")) rss_error("Records support == and != only; ordering is not defined.", value$operator_token, filename)
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
    if (statement$kind == "record") {
      if (exists(statement$name, bindings, inherits = FALSE)) rss_error("Record name is already declared.", statement$name_token, filename)
      record_type <- paste0("Record:", statement$name)
      schema <- statement$types
      names(schema) <- statement$fields
      assign(record_type, schema, records)
      signature <- info("Function", 1L)
      signature$parameters <- statement$fields
      signature$field_types <- statement$types
      signature$result <- info(record_type, 1L)
      assign(statement$name, list(info = signature, mutable = FALSE), bindings)
      next
    }
    if (statement$kind == "function") {
      if (exists(statement$name, bindings, inherits = FALSE)) rss_error("Function name is already declared.", statement$name_token, filename)
      outer <- bindings
      bindings <- new.env(parent = emptyenv())
      # Bodies can see only parameters and earlier functions, never ambient data.
      for (key in ls(outer, all.names = TRUE)) {
        entry <- get(key, outer, inherits = FALSE)
        if (entry$info$type == "Function") assign(key, entry, bindings)
      }
      for (parameter in statement$parameters) assign(parameter, list(info = info("Unknown", NA_integer_), mutable = FALSE), bindings)
      result <- infer(statement$body)
      bindings <- outer
      signature <- info("Function", 1L)
      signature$parameters <- statement$parameters
      signature$result <- result
      assign(statement$name, list(info = signature, mutable = FALSE), bindings)
      next
    }
    if (statement$kind %in% c("plot", "write")) {
      require_table(statement$table, statement$table_token)
      next
    }
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
  contains_conditional <- function(value) {
    if (!is.list(value)) return(FALSE)
    if (identical(value$kind, "conditional")) return(TRUE)
    any(vapply(value, contains_conditional, logical(1)))
  }
  checked <- has_data || contains_conditional(statements) ||
    any(vapply(statements, function(x) x$kind %in% c("function", "record"), logical(1)))
  needs_runtime <- FALSE
  call_runtime <- function(method, args, token) {
    needs_runtime <<- TRUE
    paste0(".rss$", method, "(", paste(c(args, quote_text(filename), paste0(token$line, "L"),
           paste0(token$column, "L")), collapse = ", "), ")")
  }
  emit <- function(value, table = NULL) {
    recurse <- function(x) emit(x, table)
    switch(value$kind,
      record_update = call_runtime("record_update", c(recurse(value$value),
        paste0("base::c(", paste(vapply(value$fields, quote_text, character(1)), collapse = ", "), ")"),
        paste0("base::list(", paste(vapply(value$values, recurse, character(1)), collapse = ", "), ")")), value$token),
      conditional = paste0("(if (", call_runtime("condition", recurse(value$condition), value$condition$token),
                           ") ", recurse(value$yes), " else ", recurse(value$no), ")"),
      call = {
        arguments <- vapply(seq_along(value$arguments), function(i) {
          prefix <- if (nzchar(value$labels[[i]])) paste0(name(value$labels[[i]]), " = ") else ""
          paste0(prefix, recurse(value$arguments[[i]]))
        }, character(1))
        call_runtime("call", c(name(value$name), paste0("base::list(", paste(arguments, collapse = ", "), ")")), value$token)
      },
      summarize = {
        specs <- vapply(value$summaries, function(spec) {
          input <- spec$value$value
          column <- if (input$kind == "name") input$value else input$column
          paste0("base::list(name = ", quote_text(spec$name), ", operation = ", quote_text(spec$value$operation),
                 ", column = ", quote_text(column), ", skip = ", if (spec$value$skip) "TRUE" else "FALSE",
                 ", line = ", spec$value$token$line, "L, position = ", spec$value$token$column, "L)")
        }, character(1))
        call_runtime("summarize", c(name(value$table), paste0("base::c(", paste(vapply(value$keys, quote_text, character(1)), collapse = ", "), ")"),
                     paste0("base::list(", paste(specs, collapse = ", "), ")")), value$token)
      },
      summary = call_runtime("summary", c(quote_text(value$operation), recurse(value$value), if (value$skip) "TRUE" else "FALSE"), value$token),
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
      missing = if (checked) call_runtime("missing", c(recurse(value$value), if (value$negate) "TRUE" else "FALSE"), value$token) else
        paste0(if (value$negate) "!" else "", "base::is.na(", recurse(value$value), ")"),
      vector = if (!checked) paste0("base::c(", paste(vapply(value$values, recurse, character(1)), collapse = ", "), ")") else call_runtime("vector", paste0("base::list(", paste(vapply(value$values, recurse, character(1)), collapse = ", "), ")"), value$token),
      unary = if (!checked) paste0("(", if (value$operator == "not") "!" else value$operator, recurse(value$value), ")") else call_runtime("unary", c(quote_text(value$operator), recurse(value$value)), value$token),
      binary = if (!checked) paste0("(", recurse(value$left), " ", switch(value$operator, "and" = "&", "or" = "|", value$operator), " ", recurse(value$right), ")") else call_runtime("binary", c(quote_text(value$operator), recurse(value$left), recurse(value$right)), value$operator_token)
    )
  }
  declared <- character()
  lines <- vapply(statements, function(statement) {
    if (statement$kind == "record") {
      declared <<- c(declared, statement$name)
      vector <- function(values) paste0("base::c(", paste(vapply(values, quote_text, character(1)), collapse = ", "), ")")
      values <- paste0("base::list(", paste(vapply(statement$fields, name, character(1)), collapse = ", "), ")")
      body <- call_runtime("record", c(quote_text(statement$name), vector(statement$fields), vector(statement$types), values), statement$token)
      return(paste0(name(statement$name), " <- function(", paste(vapply(statement$fields, name, character(1)), collapse = ", "), ") {\n  return(", body, ")\n}"))
    }
    if (statement$kind == "function") {
      declared <<- c(declared, statement$name)
      return(paste0(name(statement$name), " <- function(", paste(vapply(statement$parameters, name, character(1)), collapse = ", "), ") {\n  return(", emit(statement$body), ")\n}"))
    }
    if (statement$kind == "write") return(call_runtime("write", c(name(statement$table), quote_text(statement$path)), statement$token))
    if (statement$kind == "plot") return(call_runtime("plot", c(name(statement$table), quote_text(statement$x), quote_text(statement$y), quote_text(statement$path)), statement$token))
    if (statement$kind == "print") return(paste0("base::print(", emit(statement$value), ")"))
    rhs <- emit(statement$value)
    if (checked && statement$name %in% declared) rhs <- call_runtime("update", c(name(statement$name), rhs), statement$name_token)
    declared <<- c(declared, statement$name)
    paste0(name(statement$name), " <- ", rhs)
  }, character(1))
  helpers <- character()
  if (needs_runtime) helpers <- c(helpers, paste0(".rss <- base::eval(base::quote((", paste(deparse(rss_runtime, width.cutoff = 100L), collapse = "\n"), ")()), base::new.env(parent = base::baseenv()))"))
  if (has_data) {
    helpers <- c(helpers, paste0(".rss_read_csv <- base::eval(base::quote(", paste(deparse(rss_read_csv, width.cutoff = 100L), collapse = "\n"), "), base::baseenv())"))
  }
  paste(c(helpers, if (length(helpers)) "", lines), collapse = "\n")
}

# Return R source as a single string. The caller decides whether to save or run it.
rss_compile <- function(source, filename = "<input>") {
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
    record <- attr(value, "rss_record_type", exact = TRUE)
    if (is.list(value) && is.character(record) && length(record) == 1L && !is.na(record)) return(paste0("Record:", record))
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
      if (any(startsWith(types, "Record:"))) {
        if (!op %in% c("==", "!=")) error("Records support == and != only; ordering is not defined.")
        if (types[[1L]] != types[[2L]]) error("Record equality requires the same declared record type.")
        if (!identical(names(left), names(right)) || !length(left)) error("Record equality requires matching field layouts.")
        matches <- vapply(seq_along(left), function(i) {
          a <- left[[i]]
          b <- right[[i]]
          if (length(a) != 1L || length(b) != 1L || !is.null(attributes(a)) || !is.null(attributes(b)) ||
              !typeof(a) %in% c("double", "integer", "logical", "character") ||
              !typeof(b) %in% c("double", "integer", "logical", "character") || type(a) != type(b)) {
            error("Record equality requires matching plain scalar field types.")
          }
          a == b
        }, logical(1))
        equal <- if (any(!matches, na.rm = TRUE)) FALSE else if (anyNA(matches)) NA else TRUE
        return(if (op == "==") equal else !equal)
      }
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
  runtime <- list(
    record = function(record_name, fields, types, values, filename, line, column) {
      for (i in seq_along(fields)) {
        value <- values[[i]]
        if (type(value) != types[[i]] || length(value) != 1L ||
            !is.null(attributes(value)) || !typeof(value) %in% c("double", "integer", "logical", "character")) {
          fail(sprintf("Field '%s' requires one plain %s value.", fields[[i]], types[[i]]), filename, line, column)
        }
      }
      names(values) <- fields
      structure(values, rss_record_type = record_name)
    },
    condition = function(value, filename, line, column) {
      if (!is.logical(value) || !is.null(dim(value)) || length(value) != 1L || is.na(value)) {
        fail("An if condition must be exactly one nonmissing boolean.", filename, line, column)
      }
      value
    },
    call = function(target, arguments, filename, line, column) {
      # Force each argument once before entering the function, including unused ones.
      arguments <- lapply(arguments, identity)
      tryCatch(do.call(target, arguments), rstarstar_error = function(e) {
        e$message <- paste0(e$message, "\n  called at ", filename, ":", line, ":", column)
        stop(e)
      })
    },
    summary = function(operation, value, skip, filename, line, column) {
      error <- function(message) fail(message, filename, line, column)
      if (operation == "count") {
        if (is.data.frame(value)) {
          if (skip) error("count(table) counts rows; choose a column to skip missing values.")
          return(as.double(nrow(value)))
        }
        if (!type(value) %in% c("Number", "Text", "Boolean")) error("count requires a vector or table.")
        return(as.double(if (skip) sum(!is.na(value)) else length(value)))
      }
      if (!is.numeric(value)) error("Numeric summaries require numbers.")
      if (anyNA(value) && !skip) error("Summary input contains missing values. Add 'skipping missing' explicitly.")
      if (skip) value <- value[!is.na(value)]
      if (any(!is.finite(value))) error("Numeric summaries require finite values.")
      if (operation == "average" && !length(value)) error("Cannot average an empty input or an input with no nonmissing values.")
      result <- if (operation == "average") mean(value) else sum(value)
      if (!is.finite(result)) error("Summary result is outside the finite numeric range.")
      as.double(result)
    },
    write = function(table, path, filename, line, column) {
      error <- function(message) fail(message, filename, line, column)
      if (!is.data.frame(table)) error("CSV export requires a table.")
      if (!ncol(table) || anyNA(names(table)) || any(!nzchar(trimws(names(table)))) || anyDuplicated(names(table))) {
        error("CSV column names must be nonempty and unique.")
      }
      for (value in table) {
        if (!is.null(dim(value)) || is.object(value) ||
            !typeof(value) %in% c("double", "integer", "logical", "character")) {
          error("CSV export supports only plain number, boolean, and text columns.")
        }
        if (is.numeric(value) && any(!is.finite(value) & !is.na(value))) error("CSV numbers must be finite or missing.")
      }
      if (file.exists(path)) error("CSV output already exists; choose a new path.")
      if (!dir.exists(dirname(path))) error("CSV output directory does not exist.")
      temporary <- tempfile(pattern = ".rstarstar-csv-", tmpdir = dirname(path), fileext = ".csv")
      on.exit(unlink(temporary), add = TRUE)
      tryCatch(withCallingHandlers({
        utils::write.table(table, file = temporary, sep = ",", dec = ".", quote = TRUE,
                           row.names = FALSE, col.names = TRUE, na = "", eol = "\n",
                           qmethod = "double", fileEncoding = "UTF-8")
        if (!file.copy(temporary, path, overwrite = FALSE)) error("Could not save CSV; check the output path and permissions.")
      }, warning = function(w) stop(conditionMessage(w), call. = FALSE)), error = function(e) {
        if (inherits(e, "rstarstar_error")) stop(e)
        error(paste("Could not write CSV:", conditionMessage(e)))
      })
      invisible(path)
    },
    plot = function(table, x, y, path, filename, line, column) {
      error <- function(message) fail(message, filename, line, column)
      if (!is.data.frame(table)) error("Plotting requires a table.")
      if (!all(c(x, y) %in% names(table))) error("Unknown chart column; check the x and y column names.")
      labels <- table[[x, exact = TRUE]]
      heights <- table[[y, exact = TRUE]]
      if (!nrow(table)) error("Cannot plot an empty table.")
      if (!is.numeric(heights)) error("Bar heights must be numeric.")
      if (anyNA(labels) || anyNA(heights)) error("Chart columns contain missing values. Filter those rows explicitly before plotting.")
      if (any(!is.finite(heights))) error("Bar heights must be finite.")
      if (anyDuplicated(as.character(labels))) error("Bar labels must be unique; use 'summarize ... by ...' to combine repeated categories.")
      if (file.exists(path)) error("Chart output already exists; choose a new path.")
      if (!dir.exists(dirname(path))) error("Chart output directory does not exist.")
      if (!capabilities("cairo")) error("PNG chart output requires an R build with Cairo support.")
      temporary <- tempfile(pattern = ".rstarstar-chart-", tmpdir = dirname(path), fileext = ".png")
      device <- NULL
      on.exit({
        if (!is.null(device) && device %in% grDevices::dev.list()) grDevices::dev.off(device)
        unlink(temporary)
      }, add = TRUE)
      tryCatch({
        grDevices::png(temporary, width = 1200, height = 800, res = 120, type = "cairo")
        device <- grDevices::dev.cur()
        graphics::par(mar = c(6, 5, 4, 2) + 0.1)
        graphics::barplot(heights, names.arg = as.character(labels), col = "#3678A8",
                          border = NA, main = paste(y, "by", x), xlab = x, ylab = y,
                          las = 1, cex.names = 0.85)
        grDevices::dev.off(device)
        device <- NULL
        if (!file.copy(temporary, path, overwrite = FALSE)) error("Could not save chart; check the output path and permissions.")
      }, error = function(e) {
        if (inherits(e, "rstarstar_error")) stop(e)
        error(paste("Could not draw chart:", conditionMessage(e)))
      })
      invisible(path)
    },
    binary = binary,
    unary = function(op, value, filename, line, column) {
      expected <- if (op == "not") "Boolean" else "Number"
      if (type(value) != expected) fail(if (op == "not") "Logical operations require booleans." else "Arithmetic requires numbers.", filename, line, column)
      switch(op, "not" = !value, "+" = +value, "-" = -value)
    },
    vector = function(values, filename, line, column) {
      if (any(lengths(values) != 1L)) fail("Vector elements must each contain one value.", filename, line, column)
      types <- vapply(values, type, character(1))
      if (any(startsWith(types, "Record:"))) fail("Records cannot be vector elements yet.", filename, line, column)
      if (any(types %in% c("Table", "Unsupported")) || length(unique(types)) != 1L) fail("Vector elements must have the same non-table type.", filename, line, column)
      do.call(base::c, values)
    },
    column = function(table, name, filename, line, column) {
      if (startsWith(type(table), "Record:")) {
        if (!name %in% names(table)) fail(sprintf("Unknown record field '%s'.", name), filename, line, column)
        return(table[[name, exact = TRUE]])
      }
      if (!is.data.frame(table)) fail("Column access requires a table.", filename, line, column)
      if (!(name %in% names(table))) fail(sprintf("Unknown column '%s'. Check the table's column names.", name), filename, line, column)
      table[[name, exact = TRUE]]
    },
    missing = function(value, negate, filename, line, column) {
      if (startsWith(type(value), "Record:")) fail("Test a record field for missing values, not a record.", filename, line, column)
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
  runtime$record_update <- function(value, fields, replacements, filename, line, column) {
    if (!startsWith(type(value), "Record:")) fail("A with update requires a record.", filename, line, column)
    absent <- fields[!fields %in% names(value)]
    if (length(absent)) fail(sprintf("Unknown record field '%s'.", absent[[1L]]), filename, line, column)
    # Force replacements in source order, before constructing the new value.
    replacements <- lapply(replacements, identity)
    types <- vapply(value, type, character(1))
    result <- value
    for (i in seq_along(fields)) result[fields[[i]]] <- replacements[i]
    runtime$record(attr(value, "rss_record_type", exact = TRUE), names(value), types,
                   result, filename, line, column)
  }
  runtime$summarize <- function(table, keys, specs, filename, line, column) {
    error <- function(message) fail(message, filename, line, column)
    if (!is.data.frame(table)) error("Grouped summaries require a table.")
    absent <- keys[!keys %in% names(table)]
    if (length(absent)) error(sprintf("Unknown grouping column '%s'.", absent[[1L]]))
    # Validate even for zero rows; otherwise a typo could silently pass on empty input.
    for (spec in specs) {
      if (!spec$column %in% names(table)) fail(sprintf("Unknown summary column '%s'.", spec$column), filename, spec$line, spec$position)
      if (spec$operation != "count" && !is.numeric(table[[spec$column]])) fail("Numeric summaries require numbers.", filename, spec$line, spec$position)
    }
    # Match each typed column independently, including missing values. Joining
    # integer IDs is collision-free; joining raw text values would not be.
    codes <- lapply(keys, function(key) match(table[[key]], unique(table[[key]])))
    tuples <- if (nrow(table)) do.call(paste, c(codes, sep = ":")) else character()
    first <- which(!duplicated(tuples))
    ids <- match(tuples, tuples[first])
    groups <- lapply(seq_along(first), function(id) which(ids == id))
    columns <- lapply(keys, function(key) table[[key]][first])
    names(columns) <- keys
    for (spec in specs) {
      values <- vapply(groups, function(rows) {
        runtime$summary(spec$operation, table[[spec$column]][rows], spec$skip,
                        filename, spec$line, spec$position)
      }, numeric(1))
      columns[[spec$name]] <- values
    }
    structure(columns, class = "data.frame", row.names = seq_along(first))
  }
  runtime
}
