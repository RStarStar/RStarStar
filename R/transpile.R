# Source-located diagnostics shared by the internal compiler stages.
rss_error <- function(message, token, filename) {
  stop(structure(list(
    message = sprintf("%s:%d:%d: %s", filename, token$line, token$column, message),
    call = NULL, filename = filename, line = token$line, column = token$column,
    end_line = token$end_line, end_column = token$end_column
  ), class = c("rstarstar_error", "error", "condition")))
}

# Internal adapters retained for focused compiler tests.
rss_tokenize <- function(source, filename) RSSTokenizer$new()$tokenize(source, filename)
rss_parse <- function(tokens, filename) RSSParser$new()$parse(tokens, filename)
rss_analyze <- function(statements, filename) RSSAnalyzer$new()$analyze(statements, filename)
rss_generate <- function(statements, filename) RSSGenerator$new()$generate(statements, filename)

# Coordinate fresh stages for every compilation; never execute user source.
RSSCompiler <- R6::R6Class(
  "RSSCompiler",
  cloneable = FALSE,
  public = list(
    compile = function(source, filename = "<input>") {
      if (!is.character(source) || length(source) != 1L || is.na(source)) {
        stop("source must be one non-missing character string.", call. = FALSE)
      }
      if (!is.character(filename) || length(filename) != 1L || is.na(filename)) {
        stop("filename must be one non-missing character string.", call. = FALSE)
      }
      tokens <- RSSTokenizer$new()$tokenize(source, filename)
      statements <- RSSParser$new()$parse(tokens, filename)
      RSSAnalyzer$new()$analyze(statements, filename)
      RSSGenerator$new()$generate(statements, filename)
    }
  )
)

# Return R source as a single string. The caller decides whether to save or run it.
rss_compile <- function(source, filename = "<input>") {
  RSSCompiler$new()$compile(source, filename)
}
