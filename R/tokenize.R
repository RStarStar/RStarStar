# Internal tokenize stage. Each call resets its private state, including after errors.
RSSTokenizer <- R6::R6Class(
  "RSSTokenizer",
  cloneable = FALSE,
  public = list(
    tokenize = function(source, filename) {
      private$filename <- filename
      source <- gsub("\r\n?", "\n", source)
      private$chars <- strsplit(source, "", fixed = TRUE)[[1L]]
      private$n <- length(private$chars)
      private$i <- 1L
      private$line <- 1L
      private$column <- 1L
      private$depth <- 0L
      private$tokens <- list()
      while (private$i <= private$n) {
        ch <- private$current()
        start <- private$location()
        if (ch %in% c(" ", "\t")) {
          private$advance()
        } else if (ch == "#") {
          while (private$i <= private$n && private$current() != "\n") private$advance()
        } else if (ch == "\n") {
          private$advance()
          if (private$depth == 0L) private$add("newline", "\n", start)
        } else if (grepl("^[A-Za-z_]$", ch)) {
          begin <- private$i
          while (private$i <= private$n && grepl("^[A-Za-z0-9_]$", private$current())) private$advance()
          value <- paste0(private$chars[begin:(private$i - 1L)], collapse = "")
          kind <- if (value %in% c("mut", "print", "true", "false", "read", "into", "with", "delimiter", "filter", "where", "skipping", "missing", "is", "and", "or", "not", "plot", "summarize", "fn", "return", "write", "if", "then", "else", "record", "class")) value else "name"
          private$add(kind, value, start)
        } else if (grepl("^[0-9]$", ch)) {
          rest <- paste0(private$chars[private$i:private$n], collapse = "")
          value <- regmatches(rest, regexpr("^[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?", rest))
          if (!is.finite(as.numeric(value))) rss_error("Number is outside the supported finite range.", start, private$filename)
          for (unused in seq_len(nchar(value))) private$advance()
          private$add("number", value, start)
        } else if (ch == '"') {
          private$advance()
          value <- ""
          while (private$i <= private$n && private$current() != '"') {
            if (private$current() == "\n") rss_error("Text must close on the same line; use \\n for a newline.", start, private$filename)
            if (private$current() == "\\") {
              escape_start <- private$location()
              private$advance()
              escapes <- c('"' = '"', "\\" = "\\", n = "\n", t = "\t", r = "\r")
              if (!(private$current() %in% names(escapes))) rss_error("Unsupported text escape. Use \\n, \\t, \\r, \\\\, or \\\".", escape_start, private$filename)
              value <- paste0(value, escapes[[private$current()]])
            } else {
              value <- paste0(value, private$current())
            }
            private$advance()
          }
          if (private$i > private$n) rss_error("Unclosed text literal; expected a double quote.", start, private$filename)
          private$advance()
          private$add("text", value, start)
        } else if (ch == ":" && private$i < private$n && private$chars[[private$i + 1L]] == ":") {
          private$advance()
          private$advance()
          private$add("::", "::", start)
        } else if (ch %in% c("=", "!", "<", ">") && private$i < private$n && private$chars[[private$i + 1L]] == "=") {
          private$advance()
          private$advance()
          private$add(paste0(ch, "="), paste0(ch, "="), start)
        } else if (ch %in% c("{", "}", ":", ".", "@", "<", ">", "=", "+", "-", "*", "/", "(", ")", "[", "]", ",")) {
          private$advance()
          if (ch %in% c("(", "[")) private$depth <- private$depth + 1L
          if (ch %in% c(")", "]")) private$depth <- max(0L, private$depth - 1L)
          private$add(ch, ch, start)
        } else {
          rss_error(sprintf("Unexpected character '%s'.", ch), start, private$filename)
        }
      }
      private$add("eof", "", private$location())
      private$tokens
    }
  ),
  private = list(
    chars = NULL,
    n = NULL,
    i = NULL,
    line = NULL,
    column = NULL,
    depth = NULL,
    tokens = NULL,
    filename = NULL,
    current = function() if (private$i <= private$n) private$chars[[private$i]] else "",
    advance = function() {
      if (private$current() == "\n") {
        private$line <- private$line + 1L
        private$column <- 1L
      } else {
        private$column <- private$column + 1L
      }
      private$i <- private$i + 1L
    },
    location = function() list(line = private$line, column = private$column,
                                end_line = private$line, end_column = private$column),
    add = function(kind, value, start) {
      start$kind <- kind
      start$value <- value
      start$end_line <- private$line
      start$end_column <- private$column # Exclusive end position.
      private$tokens[[length(private$tokens) + 1L]] <- start
    }
  )
)
