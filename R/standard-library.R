# Private metadata: compilation inspects functions without executing their bodies.
rss_standard_catalog <- function() {
  list(
    absolute = list(parameter = "values", implementation = quote(function(values, filename, line, column) {
      check(values, "absolute", filename, line, column)
      abs(values)
    })),
    square_root = list(parameter = "values", implementation = quote(function(values, filename, line, column) {
      check(values, "square_root", filename, line, column)
      if (any(values < 0, na.rm = TRUE)) {
        fail("std::square_root requires nonnegative values; a nonmissing value is negative.", filename, line, column)
      }
      sqrt(values)
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
  check <- function(values, operation, filename, line, column) {
    if (!typeof(values) %in% c("integer", "double") || !is.null(attributes(values))) {
      fail(paste0("std::", operation, " requires plain numbers without attributes."), filename, line, column)
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
