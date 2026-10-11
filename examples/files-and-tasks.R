# Run after reinstalling the package; keep demo outputs outside installed examples.
library(RStarStar)
local({
  directory <- tempfile("rstarstar-files-tasks-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  path <- system.file("examples", "files-and-tasks.rsspps", package = "RStarStar", mustWork = TRUE)
  previous <- getwd()
  result <- run_file(path, working_dir = directory)
  stopifnot(result$first == "hello", result$second == "world", identical(getwd(), previous),
            file.exists(file.path(directory, "first.txt")), file.exists(file.path(directory, "second.txt")))
})
