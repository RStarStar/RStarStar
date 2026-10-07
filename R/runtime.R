# Shared exact method argument matching, also embedded in standalone runtime code.
rss_match_method <- function(parameters, labels, token, filename) {
  fail <- function(message) {
    stop(structure(list(message = sprintf("%s:%d:%d: %s", filename, token$line, token$column, message),
      call = NULL, filename = filename, line = token$line, column = token$column,
      end_line = token$line, end_column = token$column + 1L),
      class = c("rstarstar_error", "error", "condition")))
  }
  if (length(labels) != length(parameters)) fail(sprintf("Method expects %d arguments; received %d.", length(parameters), length(labels)))
  matched <- integer()
  for (i in seq_along(labels)) {
    index <- if (nzchar(labels[[i]])) match(labels[[i]], parameters) else i
    if (is.na(index)) fail(sprintf("Unknown method parameter '%s'; names must match exactly.", labels[[i]]))
    if (index %in% matched) fail(sprintf("Method parameter '%s' was supplied more than once.", parameters[[index]]))
    matched <- c(matched, index)
  }
  matched
}

# Self-contained runtime helper, embedded only in programs containing read.
# Keep all dependencies inside this function or explicitly namespace-qualified.
rss_read_csv <- function(path, separator, filename, line, column, schema = character(), missing_values = c("", "NA")) {
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
  absent <- setdiff(names(schema), header)
  if (length(absent)) fail(sprintf("schema column '%s' is absent from the CSV header.", absent[[1L]]))
  rows <- records[-1L]
  convert <- function(index) {
    values <- vapply(rows, function(row) row[[index]], character(1))
    missing <- values %in% missing_values
    values[missing] <- NA_character_
    present <- values[!missing]
    declared <- if (header[[index]] %in% names(schema)) schema[[header[[index]]]] else "Infer"
    if (declared == "Text") return(values)
    if (declared == "Infer" && !length(present)) return(values)
    numeric_pattern <- "^[+-]?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([eE][+-]?[0-9]+)?$"
    numeric_valid <- grepl(numeric_pattern, present)
    boolean_valid <- present %in% c("true", "false", "TRUE", "FALSE")
    valid <- if (declared == "Number") numeric_valid else boolean_valid
    if (declared %in% c("Number", "Boolean") && any(!valid)) {
      row <- which(!missing)[which(!valid)[[1L]]]
      fail(sprintf("column '%s' requires %s; invalid value at data row %d.", header[[index]], declared, row))
    }
    if (declared == "Number" || (declared == "Infer" && all(numeric_valid))) {
      result <- as.numeric(values)
      if (any(!is.finite(result[!missing]))) fail(sprintf("column '%s' contains a number outside the finite range.", header[[index]]))
      return(result)
    }
    if (declared == "Boolean" || all(boolean_valid)) {
      result <- tolower(values) == "true"
      result[missing] <- NA
      return(result)
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
rss_runtime <- function(match_method) {
  methods <- list()
  schemas <- list()
  mutable_fields <- list()
  fail <- function(message, filename, line, column) {
    stop(structure(list(message = sprintf("%s:%d:%d: %s", filename, line, column, message),
                        call = NULL, filename = filename, line = line, column = column,
                        end_line = line, end_column = column + 1L),
                   class = c("rstarstar_error", "error", "condition")))
  }
  type <- function(value) {
    class_name <- attr(value, "rss_class_type", exact = TRUE)
    if (is.list(value) && is.character(class_name) && length(class_name) == 1L && !is.na(class_name)) return(paste0("Class:", class_name))
    record <- attr(value, "rss_record_type", exact = TRUE)
    if (is.list(value) && is.character(record) && length(record) == 1L && !is.na(record)) return(paste0("Record:", record))
    if (is.data.frame(value)) return("Table")
    if (is.numeric(value)) return("Number")
    if (is.character(value)) return("Text")
    if (is.logical(value)) return("Boolean")
    "Unsupported"
  }
  plain_scalar <- function(value) {
    length(value) == 1L && is.null(attributes(value)) &&
      typeof(value) %in% c("double", "integer", "logical", "character")
  }
  plain_record <- function(value) {
    if (!startsWith(type(value), "Record:") || !length(value) ||
        !setequal(names(attributes(value)), c("names", "rss_record_type")) ||
        is.null(names(value)) || anyNA(names(value)) || any(!nzchar(names(value))) || anyDuplicated(names(value))) return(FALSE)
    all(vapply(value, function(field) plain_scalar(field) || plain_record(field), logical(1)))
  }
  plain_class <- function(value) {
    startsWith(type(value), "Class:") && length(value) > 0L &&
      setequal(names(attributes(value)), c("names", "rss_class_type")) &&
      !is.null(names(value)) && !anyNA(names(value)) &&
      all(nzchar(names(value))) && !anyDuplicated(names(value)) &&
      all(vapply(value, function(field) plain_scalar(field) || plain_record(field), logical(1)))
  }
  binary <- function(op, left, right, filename, line, column) {
    error <- function(message) fail(message, filename, line, column)
    types <- c(type(left), type(right))
    if (op %in% c("+", "-", "*", "/")) {
      if (any(types != "Number")) error("Arithmetic requires numbers; text and booleans are not converted automatically.")
    } else if (op %in% c("and", "or")) {
      if (any(types != "Boolean")) error("Logical operations require booleans.")
    } else {
      if (any(startsWith(types, "Class:"))) error("Class comparison is not supported.")
      if (any(startsWith(types, "Record:"))) {
        if (!op %in% c("==", "!=")) error("Records support == and != only; ordering is not defined.")
        if (types[[1L]] != types[[2L]]) error("Record equality requires the same declared record type.")
        if (!identical(names(left), names(right)) || !length(left)) error("Record equality requires matching field layouts.")
        matches <- vapply(seq_along(left), function(i) {
          a <- left[[i]]
          b <- right[[i]]
          if (any(startsWith(c(type(a), type(b)), "Record:"))) {
            if (!plain_record(a) || !plain_record(b)) error("Nested record equality requires plain record values.")
            return(binary("==", a, b, filename, line, column))
          }
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
    schema = function(type, fields, types, filename, line, column) {
      names(types) <- fields
      schemas[[type]] <<- types
      invisible(NULL)
    },
    method = function(id, type, parameters, implementation, mutating, filename, line, column) {
      methods[[id]] <<- list(type = type, parameters = parameters, implementation = implementation, mutating = mutating)
      invisible(NULL)
    },
    class_permissions = function(type, fields, filename, line, column) {
      mutable_fields[[type]] <<- fields
      invisible(NULL)
    },
    class_value = function(class_name, fields, types, values, filename, line, column) {
      for (i in seq_along(fields)) {
        value <- values[[i]]
        if (!valid_class_field(value, types[[i]])) {
          fail(sprintf("Field '%s' requires one plain %s value.", fields[[i]], types[[i]]), filename, line, column)
        }
      }
      names(values) <- fields
      structure(values, rss_class_type = class_name)
    },
    class_field = function(value, expected, field, filename, line, column) {
      if (!valid_receiver(value, expected)) fail("Class receiver does not match its declared layout.", filename, line, column)
      if (!field %in% names(value)) fail(sprintf("Unknown class field '%s'.", field), filename, line, column)
      value[[field, exact = TRUE]]
    },
    class_set = function(value, expected, field, replacement, filename, line, column) {
      if (!valid_receiver(value, expected)) fail("Class receiver does not match its declared layout.", filename, line, column)
      if (!field %in% mutable_fields[[expected]]) fail(sprintf("Field '%s' is immutable or unknown.", field), filename, line, column)
      required <- schemas[[expected]][[field]]
      if (!valid_class_field(replacement, required)) {
        fail(sprintf("Field '%s' requires one plain %s value.", field, required), filename, line, column)
      }
      # Plain scalars and record trees contain no references; slot replacement preserves aliases.
      value[[field]] <- replacement
      value
    },
    record = function(record_name, fields, types, values, filename, line, column) {
      for (i in seq_along(fields)) {
        value <- values[[i]]
        valid <- if (startsWith(types[[i]], "Record:")) plain_record(value) else plain_scalar(value)
        if (type(value) != types[[i]] || !valid) {
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
    write = function(table, path, separator, missing_value, filename, line, column) {
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
        utils::write.table(table, file = temporary, sep = separator, dec = ".", quote = TRUE,
                           row.names = FALSE, col.names = TRUE, na = missing_value, eol = "\n",
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
      if (any(startsWith(types, "Class:"))) fail("Classes cannot be vector elements.", filename, line, column)
      if (any(startsWith(types, "Record:"))) fail("Records cannot be vector elements yet.", filename, line, column)
      if (any(types %in% c("Table", "Unsupported")) || length(unique(types)) != 1L) fail("Vector elements must have the same non-table type.", filename, line, column)
      do.call(base::c, values)
    },
    column = function(table, name, filename, line, column) {
      if (startsWith(type(table), "Class:")) fail("Class fields are private; use a read-only method.", filename, line, column)
      if (startsWith(type(table), "Record:")) {
        if (!name %in% names(table)) fail(sprintf("Unknown record field '%s'.", name), filename, line, column)
        return(table[[name, exact = TRUE]])
      }
      if (!is.data.frame(table)) fail("Field access requires a table or record.", filename, line, column)
      if (!(name %in% names(table))) fail(sprintf("Unknown column '%s'. Check the table's column names.", name), filename, line, column)
      table[[name, exact = TRUE]]
    },
    missing = function(value, negate, filename, line, column) {
      if (startsWith(type(value), "Class:")) fail("Operate on class values through methods.", filename, line, column)
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
  valid_receiver <- function(value, expected) {
    if (type(value) != expected || !(if (startsWith(expected, "Class:")) plain_class(value) else plain_record(value))) return(FALSE)
    schema <- schemas[[expected]]
    if (is.null(schema) || !identical(names(value), names(schema))) return(FALSE)
    all(vapply(seq_along(schema), function(i) {
      if (startsWith(schema[[i]], "Record:")) return(valid_receiver(value[[i]], schema[[i]]))
      plain_scalar(value[[i]]) && type(value[[i]]) == schema[[i]]
    }, logical(1)))
  }
  valid_class_field <- function(value, expected) {
    if (startsWith(expected, "Record:")) return(valid_receiver(value, expected))
    plain_scalar(value) && type(value) == expected
  }
  runtime$method_call <- function(receiver, name, candidates, arguments, labels, mutating, filename, line, column) {
    force(receiver)
    arguments <- lapply(arguments, identity)
    error <- function(message) fail(message, filename, line, column)
    if (!startsWith(type(receiver), "Record:") && !startsWith(type(receiver), "Class:")) error("Method calls require a record receiver or class receiver.")
    selected <- Filter(function(id) methods[[id]]$type == type(receiver), candidates)
    if (!length(selected)) error(sprintf("No visible method '%s' for this receiver.", name))
    entry <- methods[[selected[[1L]]]]
    if (!identical(entry$mutating, mutating)) error(if (mutating) "Standalone calls require a mutating method." else "Mutating methods cannot be used in expressions.")
    if (!valid_receiver(receiver, entry$type)) error("Method receiver does not match its declared record or class layout.")
    matched <- match_method(entry$parameters, labels, list(line = line, column = column), filename)
    candidate <- runtime$call(entry$implementation, c(list(receiver), arguments[order(matched)]), filename, line, column)
    if (mutating && !valid_receiver(candidate, entry$type)) error("Mutating method returned an invalid class receiver.")
    candidate
  }
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
