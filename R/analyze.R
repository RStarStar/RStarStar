# Internal analyze stage. Each call resets its private state, including after errors.
RSSAnalyzer <- R6::R6Class(
  "RSSAnalyzer",
  cloneable = FALSE,
  public = list(
    analyze = function(statements, filename) {
      private$filename <- filename
      private$bindings <- new.env(parent = emptyenv())
      private$records <- new.env(parent = emptyenv())
      private$methods <- list()
      for (statement in statements) {
        if (statement$kind == "record") {
          if (exists(statement$name, private$bindings, inherits = FALSE)) rss_error("Record name is already declared.", statement$name_token, private$filename)
          record_type <- paste0("Record:", statement$name)
          if (statement$name %in% c("Number", "Text", "Boolean")) rss_error("A record name cannot replace a built-in field type.", statement$name_token, private$filename)
          schema <- vapply(seq_along(statement$types), function(i) {
            field_type <- statement$types[[i]]
            if (field_type %in% c("Number", "Text", "Boolean")) return(field_type)
            nested <- paste0("Record:", field_type)
            if (!exists(nested, private$records, inherits = FALSE)) rss_error(sprintf("Unknown field type '%s'; use Number, Text, Boolean, or an earlier record type.", field_type), statement$type_tokens[[i]], private$filename)
            nested
          }, character(1))
          names(schema) <- statement$fields
          assign(record_type, schema, private$records)
          for (method in statement$methods) {
            outer <- private$bindings
            private$bindings <- new.env(parent = emptyenv())
            for (key in ls(outer, all.names = TRUE)) {
              entry <- get(key, outer, inherits = FALSE)
              if (entry$info$type == "Function") assign(key, entry, private$bindings)
            }
            for (parameter in method$parameters) assign(parameter,
              list(info = if (parameter == "self") private$info(record_type, 1L) else private$info("Unknown", NA_integer_), mutable = FALSE), private$bindings)
            result <- private$infer(method$body)
            private$bindings <- outer
            private$methods[[length(private$methods) + 1L]] <- list(name = method$name, type = record_type,
              parameters = method$parameters[-1L], result = result)
          }
          signature <- private$info("Function", 1L)
          signature$parameters <- statement$fields
          signature$field_types <- unname(schema)
          signature$result <- private$info(record_type, 1L)
          assign(statement$name, list(info = signature, mutable = FALSE), private$bindings)
          next
        }
        if (statement$kind == "function") {
          if (exists(statement$name, private$bindings, inherits = FALSE)) rss_error("Function name is already declared.", statement$name_token, private$filename)
          outer <- private$bindings
          private$bindings <- new.env(parent = emptyenv())
          # Bodies can see only parameters and earlier functions, never ambient data.
          for (key in ls(outer, all.names = TRUE)) {
            entry <- get(key, outer, inherits = FALSE)
            if (entry$info$type == "Function") assign(key, entry, private$bindings)
          }
          for (parameter in statement$parameters) assign(parameter, list(info = private$info("Unknown", NA_integer_), mutable = FALSE), private$bindings)
          result <- private$infer(statement$body)
          private$bindings <- outer
          signature <- private$info("Function", 1L)
          signature$parameters <- statement$parameters
          signature$result <- result
          assign(statement$name, list(info = signature, mutable = FALSE), private$bindings)
          next
        }
        if (statement$kind %in% c("plot", "write")) {
          private$require_table(statement$table, statement$table_token)
          next
        }
        if (statement$kind == "print") {
          private$infer(statement$value)
          next
        }
        name <- statement$name
        existing <- exists(name, private$bindings, inherits = FALSE)
        if (existing) {
          previous <- get(name, private$bindings, inherits = FALSE)
          if (statement$mutable) rss_error(sprintf("Variable '%s' is already declared. Omit 'mut' to update a mutable binding.", name), statement$name_token, private$filename)
          if (!previous$mutable) rss_error(sprintf("Cannot reassign '%s'. Declare it with 'mut' if you intend to change it, or choose a new name.", name), statement$name_token, private$filename)
        }
        result <- private$infer(statement$value)
        if (existing && previous$info$type != "Unknown" && result$type != "Unknown" && previous$info$type != result$type) {
          rss_error(sprintf("Cannot change '%s' from %s to %s.", name, previous$info$type, result$type), statement$name_token, private$filename)
        }
        assign(name, list(info = result, mutable = if (existing) previous$mutable else statement$mutable), private$bindings)
      }
      invisible(statements)
    }
  ),
  private = list(
    bindings = NULL,
    records = NULL,
    methods = NULL,
    filename = NULL,
    info = function(type, size) list(type = type, size = size),
    lookup = function(name, token) {
      if (!exists(name, private$bindings, inherits = FALSE)) {
        rss_error(sprintf("Unknown variable '%s'. Define it before using it.", name), token, private$filename)
      }
      get(name, private$bindings, inherits = FALSE)$info
    },
    require_table = function(name, token) {
      if (!private$lookup(name, token)$type %in% c("Table", "Unknown")) rss_error("Column access and filtering require a table.", token, private$filename)
    },
    infer = function(value, in_filter = FALSE) {
      kind <- value$kind
      recurse <- function(x) private$infer(x, in_filter)
      if (kind == "record_update") {
        receiver <- recurse(value$value)
        if (receiver$type != "Unknown" && !startsWith(receiver$type, "Record:")) rss_error("A with update requires a record.", value$token, private$filename)
        schema <- if (receiver$type == "Unknown") NULL else get(receiver$type, private$records, inherits = FALSE)
        for (i in seq_along(value$fields)) {
          field <- value$fields[[i]]
          if (!is.null(schema) && !field %in% names(schema)) rss_error(sprintf("Unknown record field '%s'.", field), value$field_tokens[[i]], private$filename)
          replacement <- recurse(value$values[[i]])
          if (!is.null(schema) && (!replacement$type %in% c(schema[[field]], "Unknown") ||
              (!is.na(replacement$size) && replacement$size != 1L))) {
            rss_error(sprintf("Field '%s' requires one %s value.", field, schema[[field]]), value$field_tokens[[i]], private$filename)
          }
        }
        return(private$info(receiver$type, 1L))
      }
      if (kind == "conditional") {
        condition <- recurse(value$condition)
        if (!condition$type %in% c("Boolean", "Unknown")) rss_error("An if condition must be boolean.", value$condition$token, private$filename)
        if (!is.na(condition$size) && condition$size != 1L) rss_error("An if condition must contain exactly one boolean.", value$condition$token, private$filename)
        yes <- recurse(value$yes)
        no <- recurse(value$no)
        return(private$info(if (yes$type == no$type) yes$type else "Unknown",
                    if (!is.na(yes$size) && !is.na(no$size) && yes$size == no$size) yes$size else NA_integer_))
      }
      if (kind == "method_call") {
        receiver <- recurse(value$value)
        if (!receiver$type %in% c("Unknown") && !startsWith(receiver$type, "Record:")) rss_error("Method calls require a record receiver.", value$token, private$filename)
        candidates <- Filter(function(entry) entry$name == value$name &&
          (receiver$type == "Unknown" || entry$type == receiver$type), private$methods)
        if (!length(candidates)) rss_error(sprintf("No visible method '%s' for this receiver.", value$name), value$token, private$filename)
        if ("self" %in% value$labels) rss_error("The method receiver supplies self; do not pass it as an argument.", value$token, private$filename)
        if (receiver$type != "Unknown") rss_match_method(candidates[[1L]]$parameters, value$labels, value$token, private$filename)
        invisible(lapply(value$arguments, recurse))
        results <- lapply(candidates, function(entry) entry$result)
        if (all(vapply(results, identical, logical(1), results[[1L]]))) return(results[[1L]])
        return(private$info("Unknown", NA_integer_))
      }
      if (kind == "standard_call") {
        entry <- rss_standard_catalog()[[value$name]]
        if (is.null(entry)) rss_error(sprintf("Unknown bundled operation 'std::%s'.", value$name), value$token, private$filename)
        if (length(value$arguments) != 1L) rss_error(sprintf("std::%s expects exactly one argument.", value$name), value$token, private$filename)
        if (nzchar(value$labels[[1L]]) && value$labels[[1L]] != entry$parameter) rss_error("Expected the exact parameter name 'values'.", value$argument_tokens[[1L]], private$filename)
        operand <- recurse(value$arguments[[1L]])
        if (!operand$type %in% c(entry$input_type, "Unknown")) {
          description <- if (entry$input_type == "Text") "text" else "numbers"
          rss_error(paste0("Standard-library operations require plain ", description, "."), value$token, private$filename)
        }
        return(private$info(entry$output_type, operand$size))
      }
      if (kind == "call") {
        target <- private$lookup(value$name, value$token)
        if (target$type != "Function") rss_error(sprintf("'%s' is not a declared function.", value$name), value$token, private$filename)
        if (length(value$arguments) != length(target$parameters)) rss_error(sprintf("Function '%s' expects %d arguments; received %d.", value$name, length(target$parameters), length(value$arguments)), value$token, private$filename)
        matched <- integer()
        for (i in seq_along(value$arguments)) {
          label <- value$labels[[i]]
          parameter <- if (nzchar(label)) match(label, target$parameters) else i
          if (is.na(parameter)) rss_error(sprintf("Unknown parameter '%s' for function '%s'; names must match exactly.", label, value$name), value$argument_tokens[[i]], private$filename)
          if (parameter %in% matched) rss_error(sprintf("Parameter '%s' was supplied more than once.", target$parameters[[parameter]]), value$argument_tokens[[i]], private$filename)
          matched <- c(matched, parameter)
        }
        arguments <- lapply(value$arguments, recurse)
        if (!is.null(target$field_types)) {
          for (i in seq_along(arguments)) {
            expected <- target$field_types[[matched[[i]]]]
            actual <- arguments[[i]]
            if (!actual$type %in% c(expected, "Unknown") || (!is.na(actual$size) && actual$size != 1L)) {
              rss_error(sprintf("Field '%s' requires one %s value.", target$parameters[[matched[[i]]]], expected), value$argument_tokens[[i]], private$filename)
            }
          }
        }
        return(target$result)
      }
      if (kind == "read") return(private$info("Table", 1L))
      if (kind == "summarize") {
        private$require_table(value$table, value$table_token)
        return(private$info("Table", 1L))
      }
      if (kind == "summary") {
        operand <- recurse(value$value)
        if (value$operation != "count" && !operand$type %in% c("Number", "Unknown")) rss_error("Numeric summaries require numbers.", value$token, private$filename)
        if (startsWith(operand$type, "Record:")) rss_error("Summaries require a vector or table, not a record.", value$token, private$filename)
        if (value$operation == "count" && operand$type == "Table" && value$skip) rss_error("count(table) counts rows; choose a column to skip missing values.", value$token, private$filename)
        return(private$info("Number", 1L))
      }
      if (kind == "filter") {
        private$require_table(value$table, value$table_token)
        predicate <- private$infer(value$predicate, TRUE)
        if (!predicate$type %in% c("Boolean", "Unknown")) rss_error("Filter condition must be boolean.", value$predicate$token, private$filename)
        return(private$info("Table", 1L))
      }
      if (kind %in% c("column", "member")) {
        receiver <- if (kind == "column") private$lookup(value$table, value$token) else recurse(value$value)
        if (startsWith(receiver$type, "Record:")) {
          schema <- get(receiver$type, private$records, inherits = FALSE)
          if (!value$column %in% names(schema)) rss_error(sprintf("Unknown record field '%s'.", value$column), value$token, private$filename)
          return(private$info(schema[[value$column]], 1L))
        }
        if (kind == "column") private$require_table(value$table, value$token) else if (!receiver$type %in% c("Table", "Unknown")) {
          rss_error("Field access requires a table or record.", value$token, private$filename)
        }
        return(private$info("Unknown", NA_integer_))
      }
      if (kind == "local") {
        result <- private$lookup(value$value, value$token)
        if (result$type == "Function") rss_error("Functions must be called; function values are not supported yet.", value$token, private$filename)
        return(result)
      }
      if (kind == "number") return(private$info("Number", 1L))
      if (kind == "text") return(private$info("Text", 1L))
      if (kind %in% c("true", "false")) return(private$info("Boolean", 1L))
      if (kind == "name") {
        if (in_filter) return(private$info("Unknown", NA_integer_))
        result <- private$lookup(value$value, value$token)
        if (result$type == "Function") rss_error("Functions must be called; function values are not supported yet.", value$token, private$filename)
        return(result)
      }
      if (kind == "group") return(recurse(value$value))
      if (kind == "missing") {
        operand <- recurse(value$value)
        if (startsWith(operand$type, "Record:")) rss_error("Test a record field for missing values, not a record.", value$token, private$filename)
        if (operand$type == "Table") rss_error("Test a column or vector for missing values, not a table.", value$token, private$filename)
        return(private$info("Boolean", operand$size))
      }
      if (kind == "vector") {
        elements <- lapply(value$values, recurse)
        if (any(vapply(elements, function(x) !is.na(x$size) && x$size != 1L, logical(1)))) {
          rss_error("Vector elements must each contain one value; nested vectors are not supported.", value$token, private$filename)
        }
        types <- vapply(elements, function(x) x$type, character(1))
        if (any(startsWith(types, "Record:"))) rss_error("Records cannot be vector elements yet.", value$token, private$filename)
        if (any(types == "Table")) rss_error("Tables cannot be vector elements.", value$token, private$filename)
        known <- unique(types[types != "Unknown"])
        if (length(known) > 1L) rss_error("Vector elements must have the same type.", value$token, private$filename)
        return(private$info(if (length(known)) known[[1L]] else "Unknown", length(elements)))
      }
      if (kind == "unary") {
        operand <- recurse(value$value)
        required <- if (value$operator == "not") "Boolean" else "Number"
        if (!operand$type %in% c(required, "Unknown")) rss_error(if (required == "Number") "Arithmetic requires numbers." else "Logical operations require booleans.", value$token, private$filename)
        return(private$info(required, operand$size))
      }
      left <- recurse(value$left)
      right <- recurse(value$right)
      op <- value$operator
      types <- c(left$type, right$type)
      known <- types[types != "Unknown"]
      if (op %in% c("+", "-", "*", "/")) {
        if (any(known != "Number")) rss_error("Arithmetic requires numbers; text and booleans are not converted automatically.", value$operator_token, private$filename)
        result_type <- "Number"
      } else if (op %in% c("and", "or")) {
        if (any(known != "Boolean")) rss_error("Logical operations require booleans.", value$operator_token, private$filename)
        result_type <- "Boolean"
      } else {
        if (any(startsWith(known, "Record:")) && !op %in% c("==", "!=")) rss_error("Records support == and != only; ordering is not defined.", value$operator_token, private$filename)
        if ("Table" %in% known || length(unique(known)) > 1L) rss_error("Comparisons require matching value types.", value$operator_token, private$filename)
        if (op %in% c("<", "<=", ">", ">=") && "Boolean" %in% known) rss_error("Ordered comparisons require numbers or text.", value$operator_token, private$filename)
        result_type <- "Boolean"
      }
      sizes <- c(left$size, right$size)
      if (!anyNA(sizes) && left$size != right$size && left$size != 1L && right$size != 1L) {
        rss_error("Vector lengths must match, or one operand must contain a single value.", value$operator_token, private$filename)
      }
      size <- if (anyNA(sizes)) NA_integer_ else if (0L %in% sizes) 0L else max(sizes)
      private$info(result_type, size)
    }
  )
)
