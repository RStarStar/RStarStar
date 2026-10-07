# Internal parse stage. Each call resets its private state, including after errors.
RSSParser <- R6::R6Class(
  "RSSParser",
  cloneable = FALSE,
  public = list(
    parse = function(tokens, filename) {
      private$tokens <- tokens
      private$filename <- filename
      private$position <- 1L
      statements <- list()
      while (private$peek()$kind != "eof") {
        if (private$peek()$kind == "newline") {
          private$take()
          next
        }
        token <- private$peek()
        if (token$kind %in% c("record", "class")) {
          is_class <- token$kind == "class"
          private$take()
          name <- private$expect("name", if (is_class) "Expected a class name after 'class'." else "Expected a record name after 'record'.")
          if (name$value %in% c("average", "sum", "count")) rss_error(if (is_class) "A class cannot replace a built-in summary." else "A record cannot replace a built-in summary.", name, private$filename)
          private$expect("{", if (is_class) "Expected '{' before class fields." else "Expected '{' before record fields.")
          fields <- character()
          mutable_fields <- character()
          defaults <- list()
          types <- character()
          type_tokens <- list()
          methods <- list()
          while (private$peek()$kind == "newline") private$take()
          while (private$peek()$kind != "}") {
            if (private$peek()$kind == "eof") rss_error(if (is_class) "Expected '}' to close the class." else "Expected '}' to close the record.", private$peek(), private$filename)
            if (private$peek()$kind == "fn") {
              method <- private$parse_function(TRUE, is_class)
              if (method$name %in% c(fields, names(methods))) rss_error(if (is_class) "Class field and method names must be unique." else "Record field and method names must be unique.", method$name_token, private$filename)
              methods[[method$name]] <- method
              if (!private$peek()$kind %in% c("newline", "}")) rss_error(if (is_class) "Expected a new line between class members." else "Expected a new line between record members.", private$peek(), private$filename)
              while (private$peek()$kind == "newline") private$take()
              next
            }
            if (length(methods)) rss_error(if (is_class) "Class fields must be declared before methods." else "Record fields must be declared before methods.", private$peek(), private$filename)
            field_mutable <- is_class && private$peek()$kind == "mut"
            if (field_mutable) private$take()
            field <- private$expect("name", if (is_class) "Expected a field name or '}' in the class." else "Expected a field name or '}' in the record.")
            if (field$value %in% fields) rss_error(if (is_class) "Class field names must be unique." else "Record field names must be unique.", field, private$filename)
            private$expect(":", "Expected ':' and a type after the field name.")
            type <- private$expect("name", "Expected a scalar type or earlier record type after ':'.")
            if (private$peek()$kind == "=") {
              private$take()
              default <- private$expression()
              # Parentheses preserve spans but do not turn literals into computations.
              ungroup <- function(value) {
                while (value$kind == "group") value <- value$value
                value
              }
              atom <- ungroup(default)
              literal <- atom$kind %in% c("number", "text", "true", "false") ||
                (atom$kind == "unary" && atom$operator %in% c("+", "-") && ungroup(atom$value)$kind == "number")
              if (!literal) rss_error("Field defaults must be scalar literals (numbers may have a sign).", default$token, private$filename)
              defaults[[field$value]] <- default
            }
            type_tokens[[length(type_tokens) + 1L]] <- type
            fields <- c(fields, field$value)
            if (field_mutable) mutable_fields <- c(mutable_fields, field$value)
            types <- c(types, type$value)
            if (private$peek()$kind == "eof") rss_error(if (is_class) "Expected '}' to close the class." else "Expected '}' to close the record.", private$peek(), private$filename)
            if (!private$peek()$kind %in% c("newline", "}")) rss_error(if (is_class) "Expected a new line between class fields." else "Expected a new line between record fields.", private$peek(), private$filename)
            while (private$peek()$kind == "newline") private$take()
          }
          private$take()
          if (!length(fields)) rss_error(if (is_class) "A class must declare at least one field." else "A record must declare at least one field.", name, private$filename)
          statement <- private$node(token$kind, token, name = name$value, name_token = name, fields = fields, types = types, type_tokens = type_tokens, methods = methods, mutable_fields = mutable_fields, defaults = defaults)
        } else if (token$kind == "fn") {
          statement <- private$parse_function()
        } else if (token$kind == "print") {
          private$take()
          statement <- private$node("print", token, value = private$expression())
        } else if (token$kind == "summarize") {
          private$take()
          table <- private$expect("name", "Expected a table variable after 'summarize'.")
          if (private$peek()$kind != "name" || private$peek()$value != "by") rss_error("Expected 'by' before the grouping column.", private$peek(), private$filename)
          private$take()
          keys <- character()
          repeat {
            key <- private$peek()
            if (!key$kind %in% c("name", "text")) rss_error("Expected a grouping column name or quoted header.", key, private$filename)
            private$take()
            if (key$value %in% keys) rss_error("Grouping columns must be unique.", key, private$filename)
            keys <- c(keys, key$value)
            if (private$peek()$kind != ",") break
            private$take()
          }
          private$expect("with", "Expected 'with' before the named summaries.")
          summaries <- list()
          repeat {
            label <- private$expect("name", "Expected a name for the summary output column.")
            private$expect("=", "Expected '=' after the summary output name.")
            value <- private$expression()
            if (value$kind != "summary" || !value$value$kind %in% c("name", "column")) {
              rss_error("Each grouped result must be average(column), sum(column), or count(column).", value$token, private$filename)
            }
            if (value$value$kind == "column" && value$value$table != table$value) rss_error("Grouped summaries must use columns from the input table.", value$value$token, private$filename)
            summaries[[length(summaries) + 1L]] <- list(name = label$value, value = value)
            if (private$peek()$kind != ",") break
            private$take()
          }
          labels <- c(keys, vapply(summaries, function(x) x$name, character(1)))
          if (anyDuplicated(labels)) rss_error("Summary output names must be unique and different from all grouping columns.", token, private$filename)
          private$expect("into", "Expected 'into' after the grouped summaries.")
          mutable <- FALSE
          if (private$peek()$kind == "mut") { private$take(); mutable <- TRUE }
          target <- private$expect("name", "Expected a target variable after 'into' or 'into mut'.")
          statement <- private$node("assign", token, name = target$value, name_token = target,
                            mutable = mutable, value = private$node("summarize", token,
                            table = table$value, table_token = table, keys = keys, summaries = summaries))
        } else if (token$kind == "write") {
          private$take()
          table <- private$expect("name", "Expected a table variable after 'write'.")
          if (private$peek()$kind != "name" || private$peek()$value != "to") rss_error("Expected 'to' before the CSV output path.", private$peek(), private$filename)
          private$take()
          path <- private$expect("text", "Expected a quoted CSV output path.")
          if (!grepl("\\.csv$", path$value, ignore.case = TRUE)) rss_error("Table export requires a .csv output path.", path, private$filename)
          separator <- ","
          missing_value <- ""
          missing_token <- token
          options <- character()
          while (private$peek()$kind == "with") {
            private$take()
            option <- private$peek()
            if (!option$kind %in% c("delimiter", "missing")) rss_error("Expected 'delimiter' or 'missing' after 'with' in a write statement.", option, private$filename)
            private$take()
            if (option$kind %in% options) rss_error("Each write option may appear only once.", option, private$filename)
            options <- c(options, option$kind)
            if (option$kind == "delimiter") {
              delimiter <- private$expect("text", "Expected a quoted delimiter.")
              separator <- delimiter$value
              if (!separator %in% c(",", ";", "\t", "|")) {
                rss_error("Export delimiter must be a comma, semicolon, tab, or pipe.", delimiter, private$filename)
              }
            } else {
              missing_token <- private$expect("text", "Expected one quoted missing-value marker for export.")
              missing_value <- missing_token$value
            }
          }
          if (any(vapply(c(separator, '"', "\n", "\r"), function(ch) grepl(ch, missing_value, fixed = TRUE), logical(1)))) {
            rss_error("Export missing marker cannot contain the delimiter, a quote, or a line break.", missing_token, private$filename)
          }
          statement <- private$node("write", token, table = table$value, table_token = table, path = path$value,
                            separator = separator, missing_value = missing_value)
        } else if (token$kind == "plot") {
          private$take()
          table <- private$expect("name", "Expected a table variable after 'plot'.")
          word <- function(value) {
            if (private$peek()$kind != "name" || private$peek()$value != value) rss_error(sprintf("Expected '%s' in the plot statement.", value), private$peek(), private$filename)
            private$take()
          }
          column_name <- function() {
            if (!private$peek()$kind %in% c("name", "text")) rss_error("Expected a column name or quoted header.", private$peek(), private$filename)
            private$take()$value
          }
          word("x")
          x <- column_name()
          word("y")
          y <- column_name()
          word("as")
          word("bar")
          word("to")
          path <- private$expect("text", "Expected a quoted PNG output path.")
          if (!grepl("\\.png$", path$value, ignore.case = TRUE)) rss_error("Bar charts currently require a .png output path.", path, private$filename)
          statement <- private$node("plot", token, table = table$value, table_token = table,
                            x = x, y = y, path = path$value)
        } else if (token$kind == "filter") {
          private$take()
          table <- private$expect("name", "Expected a table variable after 'filter'.")
          private$expect("where", "Expected 'where' after the table name.")
          predicate <- private$expression()
          skip <- FALSE
          if (private$peek()$kind == "skipping") {
            private$take()
            private$expect("missing", "Expected 'missing' after 'skipping'.")
            skip <- TRUE
          }
          private$expect("into", "Expected 'into' after the filter condition.")
          mutable <- FALSE
          if (private$peek()$kind == "mut") { private$take(); mutable <- TRUE }
          target <- private$expect("name", "Expected a variable name after 'into' or 'into mut'.")
          statement <- private$node("assign", token, name = target$value, name_token = target,
                            mutable = mutable, value = private$node("filter", token, table = table$value,
                            table_token = table, predicate = predicate, skip = skip))
        } else if (token$kind == "read") {
          private$take()
          path <- private$expect("text", "Expected a quoted CSV path after 'read'.")
          private$expect("into", "Expected 'into' after the CSV path.")
          mutable <- FALSE
          if (private$peek()$kind == "mut") {
            private$take()
            mutable <- TRUE
          }
          name <- private$expect("name", "Expected a variable name after 'into' or 'into mut'.")
          separator <- ","
          schema <- character()
          missing_values <- c("", "NA")
          options <- character()
          while (private$peek()$kind == "with") {
            private$take()
            option <- private$take()
            if (!(option$kind %in% c("delimiter", "missing") || (option$kind == "name" && option$value == "columns"))) rss_error("Expected 'delimiter', 'columns', or 'missing' after 'with'.", option, private$filename)
            if (option$value %in% options) rss_error("Each read option may appear only once.", option, private$filename)
            options <- c(options, option$value)
            if (option$value == "delimiter") {
              delimiter <- private$expect("text", "Expected a quoted delimiter.")
              separator <- delimiter$value
              if (nchar(separator, type = "bytes") != 1L || separator %in% c('"', "\n", "\r")) {
                rss_error("Delimiter must be one ASCII character other than a quote or newline.", delimiter, private$filename)
              }
            } else if (option$value == "missing") {
              private$expect("[", "Expected '[' before missing-value text markers.")
              missing_values <- character()
              if (private$peek()$kind != "]") repeat {
                marker <- private$expect("text", "Missing-value markers must be quoted text.")
                if (marker$value %in% missing_values) rss_error("Missing-value markers must be unique.", marker, private$filename)
                missing_values <- c(missing_values, marker$value)
                if (private$peek()$kind != ",") break
                private$take()
              }
              private$expect("]", "Expected ']' after missing-value markers.")
            } else {
              private$expect("{", "Expected '{' before CSV column types.")
              while (private$peek()$kind == "newline") private$take()
              repeat {
                field <- private$peek()
                if (!field$kind %in% c("name", "text")) rss_error("Expected a column name or quoted header.", field, private$filename)
                private$take()
                if (!nzchar(trimws(field$value)) || field$value %in% names(schema)) rss_error("Schema column names must be nonempty and unique.", field, private$filename)
                private$expect(":", "Expected ':' before the column type.")
                type <- private$expect("name", "Expected Text, Number, or Boolean.")
                if (!type$value %in% c("Text", "Number", "Boolean")) rss_error("CSV column types must be Text, Number, or Boolean.", type, private$filename)
                schema[[field$value]] <- type$value
                while (private$peek()$kind == "newline") private$take()
                if (private$peek()$kind != ",") break
                private$take()
                while (private$peek()$kind == "newline") private$take()
              }
              private$expect("}", "Expected '}' after CSV column types; separate columns with commas.")
            }
          }
          statement <- private$node("assign", token, name = name$value, name_token = name,
                            mutable = mutable,
                            value = private$node("read", token, path = path$value, separator = separator, schema = schema, missing_values = missing_values))
        } else if (token$kind == "name" && private$tokens[[private$position + 1L]]$kind == ".") {
          call <- private$expression()
          if (call$kind != "method_call") rss_error("Expected '=' after the variable name; external field assignment is unsupported.", token, private$filename)
          if (call$value$kind != "name") {
            rss_error("A mutating call requires a simple named mutable receiver.", token, private$filename)
          }
          call$mutating <- TRUE
          statement <- private$node("mutation", token, name = call$value$value, value = call)
        } else {
          mutable <- FALSE
          if (token$kind == "mut") {
            private$take()
            mutable <- TRUE
          }
          name <- private$expect("name", "Expected a variable name or a 'print' statement.")
          private$expect("=", "Expected '=' after the variable name.")
          statement <- private$node("assign", token, name = name$value, name_token = name,
                            mutable = mutable, value = private$expression())
        }
        if (!(private$peek()$kind %in% c("newline", "eof"))) {
          rss_error("Expected a new line after the statement.", private$peek(), private$filename)
        }
        statements[[length(statements) + 1L]] <- statement
      }
      statements
    }
  ),
  private = list(
    position = NULL,
    tokens = NULL,
    filename = NULL,
    peek = function() private$tokens[[private$position]],
    take = function() {
      token <- private$peek()
      private$position <- private$position + 1L
      token
    },
    expect = function(kind, message) {
      if (private$peek()$kind != kind) rss_error(message, private$peek(), private$filename)
      private$take()
    },
    node = function(kind, token, ...) {
      # Force child parsing before recording the exclusive end position.
      fields <- list(...)
      # Nodes span their entire construct; token retains the diagnostic start.
      end <- private$tokens[[max(1L, private$position - 1L)]]
      c(list(kind = kind, token = token,
             span = list(line = token$line, column = token$column,
                         end_line = end$end_line, end_column = end$end_column)), fields)
    },
    call_arguments = function() {
      private$take()
      arguments <- list()
      labels <- character()
      argument_tokens <- list()
      named <- FALSE
      if (private$peek()$kind != ")") {
        repeat {
          start <- private$peek()
          label <- ""
          if (private$peek()$kind == "name" && private$tokens[[private$position + 1L]]$kind == ":") {
            label <- private$take()$value
            private$take()
            named <- TRUE
          } else if (named) {
            rss_error("Positional arguments must come before named arguments.", start, private$filename)
          }
          arguments[[length(arguments) + 1L]] <- private$expression()
          labels <- c(labels, label)
          argument_tokens[[length(argument_tokens) + 1L]] <- start
          if (private$peek()$kind != ",") break
          private$take()
        }
      }
      private$expect(")", "Expected ')' after function arguments.")
      list(arguments = arguments, labels = labels, argument_tokens = argument_tokens)
    },
    atom = function() {
      token <- private$peek()
      if (token$kind == "if") {
        private$take()
        condition <- private$expression()
        private$expect("then", "Expected 'then' after the condition.")
        yes <- private$expression()
        private$expect("else", "Expected 'else' and a fallback value.")
        no <- private$expression()
        return(private$node("conditional", token, condition = condition, yes = yes, no = no))
      }
      if (token$kind == "name" && token$value %in% c("average", "sum", "count") && private$tokens[[private$position + 1L]]$kind == "(") {
        private$take()
        private$take()
        value <- private$expression()
        private$expect(")", "Expected ')' after the summary input.")
        skip <- FALSE
        if (private$peek()$kind == "skipping") {
          private$take()
          private$expect("missing", "Expected 'missing' after 'skipping'.")
          skip <- TRUE
        }
        return(private$node("summary", token, operation = token$value, value = value, skip = skip))
      }
      if (token$kind %in% c("number", "text", "true", "false", "name")) {
        private$take()
        standard <- FALSE
        operation <- token$value
        if (token$kind == "name" && private$peek()$kind == "::") {
          private$take()
          if (token$value != "std") rss_error("Only the bundled 'std' namespace is supported.", token, private$filename)
          operation <- private$expect("name", "Expected a bundled operation after 'std::'.")$value
          standard <- TRUE
          if (private$peek()$kind != "(") rss_error("Standard-library operations must be called with parentheses.", private$peek(), private$filename)
        }
        if (token$kind == "name" && private$peek()$kind == "(") {
          args <- private$call_arguments()
          return(private$node(if (standard) "standard_call" else "call", token, name = operation, arguments = args$arguments,
                      labels = args$labels, argument_tokens = args$argument_tokens))
        }
        return(private$node(token$kind, token, value = token$value))
      }
      if (token$kind == "@") {
        private$take()
        variable <- private$expect("name", "Expected a variable name after '@'.")
        return(private$node("local", token, value = variable$value))
      }
      if (token$kind == "(") {
        private$take()
        value <- private$expression()
        private$expect(")", "Expected ')' to close the expression.")
        return(private$node("group", token, value = value))
      }
      if (token$kind == "[") {
        private$take()
        if (private$peek()$kind == "]") rss_error("Empty vectors need a type; they are not supported yet.", private$peek(), private$filename)
        values <- list(private$expression())
        while (private$peek()$kind == ",") {
          private$take()
          values[[length(values) + 1L]] <- private$expression()
        }
        private$expect("]", "Expected ']' to close the vector.")
        return(private$node("vector", token, values = values))
      }
      rss_error("Expected a value, variable, vector, or parenthesized expression.", token, private$filename)
    },
    primary = function() {
      value <- private$atom()
      while (private$peek()$kind %in% c("with", ".")) {
        token <- private$take()
        if (token$kind == ".") {
          field <- private$peek()
          if (!field$kind %in% c("name", "text")) rss_error(if (value$kind == "name") "Expected a column name or quoted column after '.'." else "Expected a field name or quoted header after '.'.", field, private$filename)
          private$take()
          if (private$peek()$kind == "(") {
            if (field$kind != "name") rss_error("Method names must be identifiers, not quoted text.", field, private$filename)
            args <- private$call_arguments()
            member <- private$node("method_call", token, value = value, name = field$value,
                           arguments = args$arguments, labels = args$labels, argument_tokens = args$argument_tokens)
          } else if (value$kind == "name") {
            member <- private$node("column", value$token, table = value$value, column = field$value)
          } else {
            member <- private$node("member", token, value = value, column = field$value)
          }
          member$span$line <- value$span$line
          member$span$column <- value$span$column
          value <- member
          next
        }
        private$expect("{", "Expected '{' after 'with' for a record update.")
        while (private$peek()$kind == "newline") private$take()
        fields <- character()
        values <- list()
        field_tokens <- list()
        if (private$peek()$kind == "}") rss_error("A record update must name at least one field.", private$peek(), private$filename)
        repeat {
          field <- private$expect("name", "Expected a field name in the record update.")
          if (field$value %in% fields) rss_error("Record update field names must be unique.", field, private$filename)
          private$expect(":", "Expected ':' before the replacement value.")
          fields <- c(fields, field$value)
          field_tokens[[length(field_tokens) + 1L]] <- field
          values[[length(values) + 1L]] <- private$expression()
          while (private$peek()$kind == "newline") private$take()
          if (private$peek()$kind != ",") break
          private$take()
          while (private$peek()$kind == "newline") private$take()
        }
        private$expect("}", "Expected '}' after the record update; separate fields with commas.")
        updated <- private$node("record_update", token, value = value, fields = fields,
                        values = values, field_tokens = field_tokens)
        updated$span$line <- value$span$line
        updated$span$column <- value$span$column
        value <- updated
      }
      value
    },
    unary = function() {
      if (private$peek()$kind %in% c("+", "-")) {
        token <- private$take()
        return(private$node("unary", token, operator = token$kind, value = private$unary()))
      }
      private$primary()
    },
    product = function() {
      value <- private$unary()
      while (private$peek()$kind %in% c("*", "/")) {
        operator <- private$take()
        value <- private$node("binary", value$token, operator = operator$kind,
                      operator_token = operator, left = value, right = private$unary())
      }
      value
    },
    sum_expression = function() {
      value <- private$product()
      while (private$peek()$kind %in% c("+", "-")) {
        operator <- private$take()
        value <- private$node("binary", value$token, operator = operator$kind,
                      operator_token = operator, left = value, right = private$product())
      }
      value
    },
    comparison = function() {
      value <- private$sum_expression()
      if (private$peek()$kind == "is") {
        operator <- private$take()
        negate <- FALSE
        if (private$peek()$kind == "not") { private$take(); negate <- TRUE }
        private$expect("missing", "Expected 'missing' or 'not missing' after 'is'.")
        return(private$node("missing", value$token, value = value, negate = negate))
      }
      comparisons <- c("==", "!=", "<", "<=", ">", ">=")
      if (private$peek()$kind %in% comparisons) {
        operator <- private$take()
        value <- private$node("binary", value$token, operator = operator$kind,
                      operator_token = operator, left = value, right = private$sum_expression())
        if (private$peek()$kind %in% comparisons) rss_error("Comparisons cannot be chained; join separate comparisons with 'and'.", private$peek(), private$filename)
      }
      value
    },
    negation = function() {
      if (private$peek()$kind == "not") {
        token <- private$take()
        return(private$node("unary", token, operator = "not", value = private$negation()))
      }
      private$comparison()
    },
    conjunction = function() {
      value <- private$negation()
      while (private$peek()$kind == "and") {
        operator <- private$take()
        value <- private$node("binary", value$token, operator = "and",
                      operator_token = operator, left = value, right = private$negation())
      }
      value
    },
    expression = function() {
      value <- private$conjunction()
      while (private$peek()$kind == "or") {
        operator <- private$take()
        value <- private$node("binary", value$token, operator = "or",
                      operator_token = operator, left = value, right = private$conjunction())
      }
      value
    },
    parse_function = function(method = FALSE, class_method = FALSE) {
      token <- private$peek()
      private$take()
      name <- private$expect("name", "Expected a function name after 'fn'.")
      if (!method && name$value %in% c("average", "sum", "count")) rss_error("A function cannot replace a built-in summary.", name, private$filename)
      private$expect("(", "Expected '(' after the function name.")
      parameters <- character()
      mutating <- class_method && private$peek()$kind == "mut"
      if (mutating) private$take()
      if (private$peek()$kind != ")") {
        repeat {
          parameter <- private$expect("name", "Expected a parameter name.")
          if (parameter$value %in% parameters) rss_error("Parameter names must be unique.", parameter, private$filename)
          parameters <- c(parameters, parameter$value)
          if (private$peek()$kind != ",") break
          private$take()
        }
      }
      private$expect(")", "Expected ')' after function parameters.")
      private$expect("{", "Expected '{' before the function body.")
      while (private$peek()$kind == "newline") private$take()
      if (mutating) {
        body <- list()
        repeat {
          start <- private$expect("name", "Mutating methods require self.field = expression assignments.")
          if (start$value != "self") rss_error("Mutating methods may assign only self.field.", start, private$filename)
          private$expect(".", "Expected self.field in a mutating assignment.")
          field <- private$expect("name", "Expected a private field name.")
          private$expect("=", "Expected '=' after self.field.")
          body[[length(body) + 1L]] <- private$node("field_assign", start,
            field = field$value, field_token = field, value = private$expression())
          if (private$peek()$kind == "}") break
          private$expect("newline", "Expected a new line between field assignments.")
          while (private$peek()$kind == "newline") private$take()
          if (private$peek()$kind == "}") break
        }
        private$expect("}", "Expected '}' after the mutating method.")
      } else {
        private$expect("return", "Functions currently require one 'return' expression.")
        body <- private$expression()
        while (private$peek()$kind == "newline") private$take()
        private$expect("}", "Expected '}' after the return expression; multi-statement functions are not supported yet.")
      }
      if (method && (!length(parameters) || parameters[[1L]] != "self")) rss_error("A method must declare self as its first parameter.", name, private$filename)
      private$node("function", token, name = name$value, name_token = name,
                        parameters = parameters, body = body, mutating = mutating)
    }
  )
)
