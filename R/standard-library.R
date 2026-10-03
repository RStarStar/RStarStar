# Private metadata: compilation inspects functions without executing their bodies.
rss_standard_catalog <- function() {
  list(
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
    text_length = list(parameter = "values", input_type = "Text", output_type = "Number", implementation = quote(function(values, filename, line, column) {
      check(values, "Text", "text_length", filename, line, column)
      result <- tryCatch(nchar(values, type = "chars", allowNA = FALSE, keepNA = TRUE),
        error = function(e) fail("std::text_length requires valid character text; byte-encoded or invalid text is unsupported.", filename, line, column))
      as.double(result)
    })),
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

# Shared checks and only the selected operations are embedded in a base-only scope.
rss_standard_generate <- function(operations) {
  fail <- function(message, filename, line, column) {
    stop(structure(list(message = sprintf("%s:%d:%d: %s", filename, line, column, message),
                        call = NULL, filename = filename, line = line, column = column,
                        end_line = line, end_column = column + 3L),
                   class = c("rstarstar_error", "error", "condition")))
  }
  check <- function(values, input_type, operation, filename, line, column) {
    storage <- if (input_type == "Text") "character" else c("integer", "double")
    description <- if (input_type == "Text") "text" else "numbers"
    if (!typeof(values) %in% storage || !is.null(attributes(values))) {
      fail(paste0("std::", operation, " requires plain ", description, " without attributes."), filename, line, column)
    }
  }
  code <- function(value) paste(deparse(value, width.cutoff = 100L), collapse = "\n")
  catalog <- rss_standard_catalog()
  implementations <- vapply(operations, function(operation) {
    paste0(operation, " = ", code(catalog[[operation]]$implementation))
  }, character(1))
  paste0(".rss_std <- base::eval(base::quote({\nfail <- ", code(fail),
         "\ncheck <- ", code(check), "\nlist(", paste(implementations, collapse = ",\n"),
         ")\n}), base::new.env(parent = base::baseenv()))")
}
