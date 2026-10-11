# Internal generate stage. Each call resets its private state, including after errors.
# Emits R text from an analyzed AST; it never executes the text. Runtime functions
# are deparsed into the result so generated programs need neither this package nor R6.
RSSGenerator <- R6::R6Class(
  "RSSGenerator",
  cloneable = FALSE,
  public = list(
    # statements must already pass analysis; filename is embedded in runtime errors.
    # Returns a single R-source string, with only the required helper families.
    generate = function(statements, filename) {
      private$filename <- filename
      private$has_data <- any(vapply(statements, function(x) x$kind == "assign" && x$value$kind == "read", logical(1)))
      private$checked <- private$has_data || private$contains_conditional(statements) ||
        any(vapply(statements, function(x) x$kind %in% c("function", "record", "class"), logical(1)))
      private$method_entries <- list()
      private$class_context <- NULL
      private$standard_operations <- character()
      private$needs_runtime <- FALSE
      private$declared <- character()
      lines <- vapply(statements, function(statement) {
        if (statement$kind %in% c("record", "class")) {
          is_class <- statement$kind == "class"
          nominal <- paste0(if (is_class) "Class:" else "Record:", statement$name)
          private$declared <- c(private$declared, statement$name)
          vector <- function(values) paste0("base::c(", paste(vapply(values, private$quote_text, character(1)), collapse = ", "), ")")
          values <- paste0("base::list(", paste(vapply(statement$fields, private$name, character(1)), collapse = ", "), ")")
          types <- ifelse(statement$types %in% c("Number", "Text", "Boolean"), statement$types, paste0("Record:", statement$types))
          body <- private$call_runtime(if (is_class) "class_value" else "record", c(private$quote_text(statement$name), vector(statement$fields), vector(types), values), statement$token)
          parameters <- vapply(statement$fields, function(field) {
            default <- statement$defaults[[field]]
            paste0(private$name(field), if (!is.null(default)) paste0(" = ", private$emit(default)) else "")
          }, character(1))
          constructor <- paste0(private$name(statement$name), " <- function(", paste(parameters, collapse = ", "), ") {\n  return(", body, ")\n}")
          schema_code <- private$call_runtime("schema", c(private$quote_text(nominal), vector(statement$fields), vector(types)), statement$token)
          if (is_class) schema_code <- paste(schema_code,
            private$call_runtime("class_permissions", c(private$quote_text(nominal), vector(statement$mutable_fields)), statement$token), sep = "\n")
          implementations <- vapply(statement$methods, function(method) {
            private$class_context <- if (is_class) nominal else NULL
            # Mutations build a local self candidate. The caller's binding is only
            # replaced after method dispatch returns successfully.
            if (isTRUE(method$mutating)) {
              assignments <- vapply(method$body, function(assignment) {
                paste0(" self <- ", private$call_runtime("class_set",
                  c("self", private$quote_text(nominal), private$quote_text(assignment$field),
                    private$emit(assignment$value)), assignment$field_token))
              }, character(1))
              body <- paste(c(assignments, " return(self)"), collapse = "\n")
            } else body <- paste0(" return(", private$emit(method$body), ")")
            private$class_context <- NULL
            id <- length(private$method_entries) + 1L
            private$method_entries[[id]] <- method$name
            implementation <- paste0("function(", paste(vapply(method$parameters, private$name, character(1)), collapse = ", "), ") {\n", body, "\n}")
            private$call_runtime("method", c(as.character(id), private$quote_text(nominal),
              vector(method$parameters[-1L]), implementation, if (isTRUE(method$mutating)) "TRUE" else "FALSE"), method$token)
          }, character(1))
          return(paste(c(schema_code, constructor, implementations), collapse = "\n"))
        }
        if (statement$kind == "mutation") {
          return(paste0(private$name(statement$name), " <- ", private$emit(statement$value)))
        }
        if (statement$kind == "function") {
          private$declared <- c(private$declared, statement$name)
          return(paste0(private$name(statement$name), " <- function(", paste(vapply(statement$parameters, private$name, character(1)), collapse = ", "), ") {\n  return(", private$emit(statement$body), ")\n}"))
        }
        if (statement$kind == "write") return(private$call_runtime("write", c(private$name(statement$table), private$quote_text(statement$path), private$quote_text(statement$separator), private$quote_text(statement$missing_value)), statement$token))
        if (statement$kind == "plot") return(private$call_runtime("plot", c(private$name(statement$table), private$quote_text(statement$x), private$quote_text(statement$y), private$quote_text(statement$path)), statement$token))
        if (statement$kind == "print") return(paste0("base::print(", private$emit(statement$value), ")"))
        rhs <- private$emit(statement$value)
        if (private$checked && statement$name %in% private$declared) rhs <- private$call_runtime("update", c(private$name(statement$name), rhs), statement$name_token)
        private$declared <- c(private$declared, statement$name)
        paste0(private$name(statement$name), " <- ", rhs)
      }, character(1))
      # Emission records dependencies first, then prepends standalone helpers.
      helpers <- character()
      if (length(private$standard_operations)) helpers <- c(helpers, rss_standard_generate(private$standard_operations))
      if (private$needs_runtime) helpers <- c(helpers, paste0(".rss <- base::eval(base::quote((", paste(deparse(rss_runtime, width.cutoff = 100L), collapse = "\n"), ")(", paste(deparse(rss_match_method, width.cutoff = 100L), collapse = "\n"), ")), base::new.env(parent = base::baseenv()))"))
      if (private$has_data) {
        helpers <- c(helpers, paste0(".rss_read_csv <- base::eval(base::quote(", paste(deparse(rss_read_csv, width.cutoff = 100L), collapse = "\n"), "), base::baseenv())"))
      }
      paste(c(helpers, if (length(helpers)) "", lines), collapse = "\n")
    }
  ),
  private = list(
    has_data = NULL,
    checked = NULL,
    method_entries = NULL,
    class_context = NULL,
    standard_operations = NULL,
    needs_runtime = NULL,
    declared = NULL,
    filename = NULL,
    # Quote lexer-validated identifiers so names that are R keywords remain usable.
    name = function(value) paste0("`", value, "`"),
    # Escape literal text as R source; never interpolate raw user text into code.
    quote_text = function(value) encodeString(value, quote = '"'),
    # Scan nested AST lists to enable dynamic checks for branch-dependent values.
    contains_conditional = function(value) {
      if (!is.list(value)) return(FALSE)
      if (identical(value$kind, "conditional")) return(TRUE)
      any(vapply(value, private$contains_conditional, logical(1)))
    },
    # args contains already-emitted R fragments. Add source coordinates and mark
    # the shared runtime as required; return a call expression as text.
    call_runtime = function(method, args, token) {
      private$needs_runtime <- TRUE
      paste0(".rss$", method, "(", paste(c(args, private$quote_text(private$filename), paste0(token$line, "L"),
             paste0(token$column, "L")), collapse = ", "), ")")
    },
    # Recursively emit one expression. table is the R fragment for the current
    # filter input: bare names read its columns, while @bindings bypass it.
    # Native R if preserves lazy branches; argument lists preserve written order.
    emit = function(value, table = NULL) {
      recurse <- function(x) private$emit(x, table)
      switch(value$kind,
        method_call = {
          ids <- which(vapply(private$method_entries, function(entry) entry == value$name, logical(1)))
          args <- paste0("base::list(", paste(vapply(value$arguments, recurse, character(1)), collapse = ", "), ")")
          labels <- paste0("base::c(", paste(vapply(value$labels, private$quote_text, character(1)), collapse = ", "), ")")
          private$call_runtime("method_call", c(recurse(value$value), private$quote_text(value$name),
            paste0("base::c(", paste(ids, collapse = ", "), ")"), args, labels, if (isTRUE(value$mutating)) "TRUE" else "FALSE"), value$token)
        },
        standard_call = {
          private$standard_operations <- unique(c(private$standard_operations, value$name))
          entry <- rss_standard_catalog()[[value$name]]
          if (!is.null(entry$family)) {
            matched <- rss_standard_match(entry, value$labels, value$argument_tokens, value$token, private$filename)
            arguments <- vapply(seq_along(value$arguments), function(i) {
              index <- matched[[i]]
              argument <- value$arguments[[i]]
              emitted <- if (entry$input_types[[index]] == "Function") private$name(argument$value) else recurse(argument)
              paste0(private$name(entry$parameters[[index]]), " = ", emitted)
            }, character(1))
            # Building the list eagerly preserves source order even for named calls.
            return(paste0("base::do.call(.rss_std$", value$name, ", base::list(",
              paste(c(arguments, paste0("filename = ", private$quote_text(private$filename)),
                paste0("line = ", value$token$line, "L"), paste0("column = ", value$token$column, "L")), collapse = ", "), "))"))
          }
          paste0(".rss_std$", value$name, "(", recurse(value$arguments[[1L]]), ", ",
                 private$quote_text(private$filename), ", ", value$token$line, "L, ", value$token$column, "L)")
        },
        record_update = private$call_runtime("record_update", c(recurse(value$value),
          paste0("base::c(", paste(vapply(value$fields, private$quote_text, character(1)), collapse = ", "), ")"),
          paste0("base::list(", paste(vapply(value$values, recurse, character(1)), collapse = ", "), ")")), value$token),
        conditional = paste0("(if (", private$call_runtime("condition", recurse(value$condition), value$condition$token),
                             ") ", recurse(value$yes), " else ", recurse(value$no), ")"),
        call = {
          arguments <- vapply(seq_along(value$arguments), function(i) {
            prefix <- if (nzchar(value$labels[[i]])) paste0(private$name(value$labels[[i]]), " = ") else ""
            paste0(prefix, recurse(value$arguments[[i]]))
          }, character(1))
          private$call_runtime("call", c(private$name(value$name), paste0("base::list(", paste(arguments, collapse = ", "), ")")), value$token)
        },
        summarize = {
          specs <- vapply(value$summaries, function(spec) {
            input <- spec$value$value
            column <- if (input$kind == "name") input$value else input$column
            paste0("base::list(name = ", private$quote_text(spec$name), ", operation = ", private$quote_text(spec$value$operation),
                   ", column = ", private$quote_text(column), ", skip = ", if (spec$value$skip) "TRUE" else "FALSE",
                   ", line = ", spec$value$token$line, "L, position = ", spec$value$token$column, "L)")
          }, character(1))
          private$call_runtime("summarize", c(private$name(value$table), paste0("base::c(", paste(vapply(value$keys, private$quote_text, character(1)), collapse = ", "), ")"),
                       paste0("base::list(", paste(specs, collapse = ", "), ")")), value$token)
        },
        summary = private$call_runtime("summary", c(private$quote_text(value$operation), recurse(value$value), if (value$skip) "TRUE" else "FALSE"), value$token),
        read = {
          vector <- function(values) paste0("base::c(", paste(vapply(values, private$quote_text, character(1)), collapse = ", "), ")")
          schema <- if (length(value$schema)) paste0("base::structure(", vector(unname(value$schema)),
            ", names = ", vector(names(value$schema)), ")") else "base::character()"
          paste0(".rss_read_csv(", private$quote_text(value$path), ", ", private$quote_text(value$separator),
                 ", ", private$quote_text(private$filename), ", ", value$token$line, "L, ", value$token$column, "L, ", schema, ", ",
                 if (length(value$missing_values)) vector(value$missing_values) else "base::character()", ")")
        },
        filter = {
          predicate <- private$emit(value$predicate, private$name(value$table))
          private$call_runtime("filter", c(private$name(value$table), predicate, if (value$skip) "TRUE" else "FALSE"), value$token)
        },
        member = private$call_runtime("column", c(recurse(value$value), private$quote_text(value$column)), value$token),
        column = if (!is.null(private$class_context) && value$table == "self")
          private$call_runtime("class_field", c("self", private$quote_text(private$class_context), private$quote_text(value$column)), value$token) else private$call_runtime("column", c(private$name(value$table), private$quote_text(value$column)), value$token),
        local = private$name(value$value),
        number = value$value,
        text = private$quote_text(value$value),
        true = "TRUE",
        false = "FALSE",
        name = if (is.null(table)) private$name(value$value) else private$call_runtime("column", c(table, private$quote_text(value$value)), value$token),
        group = paste0("(", recurse(value$value), ")"),
        missing = if (private$checked) private$call_runtime("missing", c(recurse(value$value), if (value$negate) "TRUE" else "FALSE"), value$token) else
          paste0(if (value$negate) "!" else "", "base::is.na(", recurse(value$value), ")"),
        vector = if (!private$checked) paste0("base::c(", paste(vapply(value$values, recurse, character(1)), collapse = ", "), ")") else private$call_runtime("vector", paste0("base::list(", paste(vapply(value$values, recurse, character(1)), collapse = ", "), ")"), value$token),
        unary = if (!private$checked) paste0("(", if (value$operator == "not") "!" else value$operator, recurse(value$value), ")") else private$call_runtime("unary", c(private$quote_text(value$operator), recurse(value$value)), value$token),
        binary = if (!private$checked) paste0("(", recurse(value$left), " ", switch(value$operator, "and" = "&", "or" = "|", value$operator), " ", recurse(value$right), ")") else private$call_runtime("binary", c(private$quote_text(value$operator), recurse(value$left), recurse(value$right)), value$operator_token)
      )
    }
  )
)
