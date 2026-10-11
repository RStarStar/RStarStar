# Private metadata: compilation inspects functions without executing their bodies.
# Returns a named operation catalog: exact parameter, input/output language types,
# and a quoted runtime function. Vector transforms preserve input length and receive
# source coordinates; shared check/fail helpers are supplied by the emitter below.
rss_standard_catalog <- function() {
  list(
    file_exists = list(parameters = "path", input_types = "Text", sizes = 1L,
      output_type = "Boolean", output_size = 1L, family = "files"),
    read_text = list(parameters = "path", input_types = "Text", sizes = 1L,
      output_type = "Text", output_size = 1L, family = "files"),
    write_text = list(parameters = c("path", "text"), input_types = c("Text", "Text"), sizes = c(1L, 1L),
      output_type = "Text", output_size = 1L, family = "files"),
    start_task = list(parameters = c("worker", "value"), input_types = c("Function", "Value"),
      output_type = "Task", output_size = 1L, family = "tasks"),
    await_task = list(parameters = c("task", "timeout"), input_types = c("Task", "Number"),
      sizes = c(1L, 1L), optional = "timeout", output_type = "Unknown", output_size = NA_integer_, family = "tasks"),
    # Numeric operations preserve missing values; square roots reject negative inputs.
    absolute = list(parameter = "values", input_type = "Number", output_type = "Number", implementation = quote(function(values, filename, line, column) {
      check(values, "Number", "absolute", filename, line, column)
      abs(values)
    })),
    square_root = list(parameter = "values", input_type = "Number", output_type = "Number", implementation = quote(function(values, filename, line, column) {
      check(values, "Number", "square_root", filename, line, column)
      if (any(values < 0, na.rm = TRUE)) {
        fail("std::square_root requires nonnegative values; a nonmissing value is negative.", filename, line, column)
      }
      sqrt(values)
    })),
    # Predicate results are never missing: NA, NaN, and either infinity map to false.
    # Validate plain numeric storage before base R can accept other input types.
    is_finite = list(parameter = "values", input_type = "Number", output_type = "Boolean", implementation = quote(function(values, filename, line, column) {
      check(values, "Number", "is_finite", filename, line, column)
      is.finite(values)
    })),
    # Count characters, not bytes or grapheme clusters; return language Number values.
    text_length = list(parameter = "values", input_type = "Text", output_type = "Number", implementation = quote(function(values, filename, line, column) {
      check(values, "Text", "text_length", filename, line, column)
      result <- tryCatch(nchar(values, type = "chars", allowNA = FALSE, keepNA = TRUE),
        error = function(e) fail("std::text_length requires valid character text; byte-encoded or invalid text is unsupported.", filename, line, column))
      as.double(result)
    })),
    # Follow the caller's current locale without changing it or normalizing Unicode.
    lower_text = list(parameter = "values", input_type = "Text", output_type = "Text", implementation = quote(function(values, filename, line, column) {
      check(values, "Text", "lower_text", filename, line, column)
      tryCatch({
        nchar(values, type = "chars", allowNA = FALSE, keepNA = TRUE)
        tolower(values)
      }, error = function(e) fail("std::lower_text requires valid character text supported by the current locale; invalid or byte-encoded text is unsupported.", filename, line, column))
    })),
    # Remove only the documented boundary whitespace; internal spaces remain intact.
    trim_text = list(parameter = "values", input_type = "Text", output_type = "Text", implementation = quote(function(values, filename, line, column) {
      check(values, "Text", "trim_text", filename, line, column)
      tryCatch({
        # Validate encoding before regex processing, including R caller inputs.
        nchar(values, type = "chars", allowNA = FALSE, keepNA = TRUE)
        trimws(values, whitespace = "[ \t\r\n]")
      }, error = function(e) fail("std::trim_text requires valid character text; byte-encoded or invalid text is unsupported.", filename, line, column))
    }))
  )
}

# Match extended library signatures without partial matching. The returned indices
# preserve written order; code generation uses them to name already-evaluated values.
rss_standard_match <- function(entry, labels, tokens, token, filename) {
  parameters <- entry$parameters
  if (length(labels) > length(parameters)) rss_error("Too many arguments for this standard-library operation.", token, filename)
  matched <- integer()
  for (i in seq_along(labels)) {
    index <- if (nzchar(labels[[i]])) match(labels[[i]], parameters) else i
    if (is.na(index)) rss_error(sprintf("Unknown parameter '%s'; expected exact names: %s.", labels[[i]], paste(parameters, collapse = ", ")), tokens[[i]], filename)
    if (index %in% matched) rss_error(sprintf("Parameter '%s' was supplied more than once.", parameters[[index]]), tokens[[i]], filename)
    matched <- c(matched, index)
  }
  missing <- setdiff(parameters, c(parameters[matched], entry$optional))
  if (length(missing)) rss_error(paste("Missing required parameters:", paste(missing, collapse = ", ")), token, filename)
  matched
}

# Shared checks and only the selected operations are embedded in a base-only scope.
# operations: unique catalog names already validated by analysis.
# Returns R text constructing .rss_std; generating this text runs no user operation.
rss_standard_generate <- function(operations) {
  # These local functions are also deparsed, so their dependencies must be standalone.
  fail <- function(message, filename, line, column) {
    stop(structure(list(message = sprintf("%s:%d:%d: %s", filename, line, column, message),
                        call = NULL, filename = filename, line = line, column = column,
                        end_line = line, end_column = column + 3L),
                   class = c("rstarstar_error", "error", "condition")))
  }
  # Validate plain storage without coercion or attributed-object dispatch.
  check <- function(values, input_type, operation, filename, line, column) {
    storage <- if (input_type == "Text") "character" else c("integer", "double")
    description <- if (input_type == "Text") "text" else "numbers"
    if (!typeof(values) %in% storage || !is.null(attributes(values))) {
      fail(paste0("std::", operation, " requires plain ", description, " without attributes."), filename, line, column)
    }
  }
  # Serialize a function/expression as R source, not an evaluated result.
  code <- function(value) paste(deparse(value, width.cutoff = 100L), collapse = "\n")
  catalog <- rss_standard_catalog()
  families <- unique(unlist(lapply(catalog[operations], function(entry) entry$family)))
  setup <- character()
  for (family in families) {
    factory <- if (family == "files") rss_file_runtime else rss_task_runtime
    setup <- c(setup, paste0(family, " <- (", code(factory), ")(fail)"))
  }
  implementations <- vapply(operations, function(operation) {
    if (!is.null(catalog[[operation]]$family)) return(paste0(operation, " = ", catalog[[operation]]$family, "$", operation))
    paste0(operation, " = ", code(catalog[[operation]]$implementation))
  }, character(1))
  paste0(".rss_std <- base::eval(base::quote({\nfail <- ", code(fail),
         "\ncheck <- ", code(check), "\n", paste(setup, collapse = "\n"), "\nlist(", paste(implementations, collapse = ",\n"),
         ")\n}), base::new.env(parent = base::baseenv()))")
}
