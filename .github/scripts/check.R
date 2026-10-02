# Developer/CI runner, invoked from the repository root; not a public package API.
local({
  if (!file.exists("DESCRIPTION") || !file.exists("tests/run.R")) {
    stop("Run this script from the repository root.", call. = FALSE)
  }
  metadata <- read.dcf("DESCRIPTION")
  package <- metadata[1L, "Package"]
  version <- metadata[1L, "Version"]
  archive <- paste0(package, "_", version, ".tar.gz")
  library <- tempfile("rstarstar-check-library-")
  dir.create(library)
  on.exit(unlink(library, recursive = TRUE), add = TRUE)
  # Child R processes must test this installation, not an older user installation.
  Sys.setenv(R_LIBS = library, R_LIBS_USER = library)
  executable <- function(name) {
    file.path(R.home("bin"), paste0(name, if (.Platform$OS.type == "windows") ".exe" else ""))
  }
  command <- function(name, args) {
    cat("\nRunning", name, paste(args, collapse = " "), "\n")
    status <- system2(executable(name), vapply(args, shQuote, character(1L)))
    if (status != 0L) stop(name, " failed with exit status ", status, call. = FALSE)
  }
  cat(R.version.string, "\nPlatform:", R.version$platform,
      "\nCairo:", capabilities("cairo"), "\n")
  command("R", c("CMD", "INSTALL", paste0("--library=", library), "."))
  command("Rscript", "tests/run.R")
  for (demo in c("demo", "read-csv", "filter", "grouped", "functions", "run-file")) {
    command("Rscript", file.path("examples", paste0(demo, ".R")))
  }
  if (isTRUE(capabilities("cairo"))) {
    chart <- tempfile("rstarstar-check-chart-", fileext = ".png")
    on.exit(unlink(chart), add = TRUE)
    command("Rscript", c("examples/workflow.R", chart))
  } else {
    cat("SKIP workflow chart demo: Cairo is unavailable.\n")
  }
  command("R", c("CMD", "build", "."))
  command("R", c("CMD", "check", "--no-manual", archive))
  # R CMD check may exit successfully despite warnings or notes.
  log <- file.path(paste0(package, ".Rcheck"), "00check.log")
  if (!file.exists(log) || !any(trimws(readLines(log, warn = FALSE)) == "Status: OK")) {
    stop("Package check must finish with Status: OK; inspect ", log, call. = FALSE)
  }
})
