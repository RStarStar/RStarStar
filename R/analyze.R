# Internal analyze stage. Each call resets its private state, including after errors.
# Checks an AST without reading datasets or evaluating user expressions. Inference
# uses type/size facts; Unknown types and NA sizes defer checks to generated R.
RSSAnalyzer <- R6::R6Class(
  "RSSAnalyzer",
  cloneable = FALSE,
  public = list(
    # statements: parser AST in declaration order; filename: diagnostic label.
    # Returns the same statements invisibly, or raises a source-located error.
    analyze = function(statements, filename) {
      private$filename <- filename
      private$bindings <- new.env(parent = emptyenv())
      private$records <- new.env(parent = emptyenv())
      private$methods <- list()
      private$class_context <- NULL
      for (statement in statements) {
        if (statement$kind %in% c("record", "class")) {
          is_class <- statement$kind == "class"
          if (exists(statement$name, private$bindings, inherits = FALSE)) rss_error(if (is_class) "Class name is already declared." else "Record name is already declared.", statement$name_token, private$filename)
          record_type <- paste0(if (is_class) "Class:" else "Record:", statement$name)
          if (statement$name %in% c("Number", "Text", "Boolean")) rss_error(if (is_class) "A class name cannot replace a built-in field type." else "A record name cannot replace a built-in field type.", statement$name_token, private$filename)
          # Resolve nested types only against earlier records, keeping schemas acyclic.
          schema <- vapply(seq_along(statement$types), function(i) {
            field_type <- statement$types[[i]]
            if (field_type %in% c("Number", "Text", "Boolean")) return(field_type)
            nested <- paste0("Record:", field_type)
            if (is_class && !exists(nested, private$records, inherits = FALSE)) rss_error("Class fields require Number, Text, Boolean, or an earlier record type.", statement$type_tokens[[i]], private$filename)
            if (!exists(nested, private$records, inherits = FALSE)) rss_error(sprintf("Unknown field type '%s'; use Number, Text, Boolean, or an earlier record type.", field_type), statement$type_tokens[[i]], private$filename)
            nested
          }, character(1))
          names(schema) <- statement$fields
          for (field in names(statement$defaults)) {
            default <- statement$defaults[[field]]
            actual <- private$infer(default)
            if (actual$type != schema[[field]]) rss_error(sprintf("Default for field '%s' requires one %s value.", field, schema[[field]]), default$token, private$filename)
          }
          assign(record_type, schema, private$records)
          # Method scopes admit self, parameters, and earlier callable declarations.
          # Register each signature after its body, preserving declaration visibility.
          for (method in statement$methods) {
            outer <- private$bindings
            private$bindings <- new.env(parent = emptyenv())
            for (key in ls(outer, all.names = TRUE)) {
              entry <- get(key, outer, inherits = FALSE)
              if (entry$info$type == "Function") assign(key, entry, private$bindings)
            }
            for (parameter in method$parameters) assign(parameter,
              list(info = if (parameter == "self") private$info(record_type, 1L) else private$info("Unknown", NA_integer_), mutable = FALSE), private$bindings)
            private$class_context <- if (is_class) record_type else NULL
            if (isTRUE(method$mutating)) {
              for (assignment in method$body) {
                field <- assignment$field
                if (!field %in% names(schema)) rss_error(sprintf("Unknown class field '%s'.", field), assignment$field_token, private$filename)
                if (!field %in% statement$mutable_fields) rss_error(sprintf("Field '%s' is immutable; declare it with mut.", field), assignment$field_token, private$filename)
                replacement <- private$infer(assignment$value)
                if (!replacement$type %in% c(schema[[field]], "Unknown") ||
                    (!is.na(replacement$size) && replacement$size != 1L)) {
                  rss_error(sprintf("Field '%s' requires one %s value.", field, schema[[field]]), assignment$field_token, private$filename)
                }
              }
              result <- private$info(record_type, 1L)
            } else result <- private$infer(method$body)
            private$class_context <- NULL
            private$bindings <- outer
            private$methods[[length(private$methods) + 1L]] <- list(name = method$name, type = record_type,
              parameters = method$parameters[-1L], result = result, mutating = isTRUE(method$mutating))
          }
          signature <- private$info("Function", 1L)
          signature$parameters <- statement$fields
          signature$optional <- names(statement$defaults)
          signature$field_types <- unname(schema)
          signature$result <- private$info(record_type, 1L)
          assign(statement$name, list(info = signature, mutable = FALSE), private$bindings)
          next
        }
        if (statement$kind == "mutation") {
          private$lookup(statement$name, statement$token)
          entry <- get(statement$name, private$bindings, inherits = FALSE)
          if (!entry$mutable) rss_error("A mutating call requires a mutable receiver binding; declare it with mut.", statement$token, private$filename)
          private$infer(statement$value)
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
    class_context = NULL,
    filename = NULL,
    # Compact inference result; nominal types use Record:Name or Class:Name tags.
    info = function(type, size) list(type = type, size = size),
    # Resolve only this analysis scope, never an ambient R/global binding.
    lookup = function(name, token) {
      if (!exists(name, private$bindings, inherits = FALSE)) {
        rss_error(sprintf("Unknown variable '%s'. Define it before using it.", name), token, private$filename)
      }
      get(name, private$bindings, inherits = FALSE)$info
    },
    # Reject known non-tables; Unknown parameters must be validated at execution.
    require_table = function(name, token) {
      if (!private$lookup(name, token)$type %in% c("Table", "Unknown")) rss_error("Column access and filtering require a table.", token, private$filename)
    },
    # Recursively return type/size facts and validate every reachable AST form.
    # in_filter makes bare names column references; @name still uses lexical lookup.
    # Both conditional branches are checked, without executing either branch.
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
        if (!receiver$type %in% c("Unknown") && !startsWith(receiver$type, "Record:") && !startsWith(receiver$type, "Class:")) rss_error("Method calls require a record receiver or class receiver.", value$token, private$filename)
        candidates <- Filter(function(entry) entry$name == value$name &&
          (receiver$type == "Unknown" || entry$type == receiver$type), private$methods)
        if (!length(candidates)) rss_error(sprintf("No visible method '%s' for this receiver.", value$name), value$token, private$filename)
        mutating <- isTRUE(value$mutating)
        compatible <- Filter(function(entry) identical(entry$mutating, mutating), candidates)
        if (!length(compatible) || (receiver$type != "Unknown" && !identical(candidates[[1L]]$mutating, mutating))) {
          rss_error(if (mutating) "Standalone calls require a mutating method." else "Mutating methods cannot be used in expressions.", value$token, private$filename)
        }
        if ("self" %in% value$labels) rss_error("The method receiver supplies self; do not pass it as an argument.", value$token, private$filename)
        if (receiver$type != "Unknown") rss_match_method(candidates[[1L]]$parameters, value$labels, value$token, private$filename)
        invisible(lapply(value$arguments, recurse))
        results <- lapply(compatible, function(entry) entry$result)
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
        constructor <- !is.null(target$field_types)
        supplied <- length(value$arguments)
        maximum <- length(target$parameters)
        if (constructor && supplied > maximum) {
          rss_error(sprintf("Constructor '%s' accepts at most %d %s; received %d.", value$name,
            maximum, if (maximum == 1L) "argument" else "arguments", supplied), value$token, private$filename)
        }
        if (!constructor && supplied != maximum) rss_error(sprintf("Function '%s' expects %d arguments; received %d.", value$name, maximum, supplied), value$token, private$filename)
        # Match labels before inferring arguments so diagnostics follow the call
        # contract; matching never evaluates expressions or reorders source effects.
        matched <- integer()
        for (i in seq_along(value$arguments)) {
          label <- value$labels[[i]]
          parameter <- if (nzchar(label)) match(label, target$parameters) else i
          if (is.na(parameter)) rss_error(sprintf("Unknown parameter '%s' for %s '%s'; names must match exactly.", label, if (constructor) "constructor" else "function", value$name), value$argument_tokens[[i]], private$filename)
          if (parameter %in% matched) rss_error(sprintf("Parameter '%s' was supplied more than once.", target$parameters[[parameter]]), value$argument_tokens[[i]], private$filename)
          matched <- c(matched, parameter)
        }
        missing <- setdiff(target$parameters, c(target$parameters[matched], target$optional))
        if (length(missing)) rss_error(sprintf("Missing required %s %s for constructor '%s'.",
          if (length(missing) == 1L) "field" else "fields",
          paste(sprintf("'%s'", missing), collapse = ", "), value$name), value$token, private$filename)
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
        if (startsWith(operand$type, "Class:")) rss_error("Operate on class values through methods.", value$token, private$filename)
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
        if (startsWith(receiver$type, "Class:")) {
          if (kind != "column" || value$table != "self" || !identical(private$class_context, receiver$type)) {
            rss_error("Class fields are private; use a read-only method.", value$token, private$filename)
          }
          schema <- get(receiver$type, private$records, inherits = FALSE)
          if (!value$column %in% names(schema)) rss_error(sprintf("Unknown class field '%s'.", value$column), value$token, private$filename)
          return(private$info(schema[[value$column]], 1L))
        }
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
        if (startsWith(operand$type, "Class:")) rss_error("Operate on class values through methods.", value$token, private$filename)
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
        if (any(startsWith(types, "Class:"))) rss_error("Classes cannot be vector elements.", value$token, private$filename)
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
        if (any(startsWith(known, "Class:"))) rss_error("Class comparison is not supported.", value$operator_token, private$filename)
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
