# Contributing to RStarStar

RStarStar has a small compiler prototype and an evolving language design. Beginners, experienced R users, and
AI-assisted contributors are welcome. Useful contributions include small example
programs, clearer explanations, confusing-error examples, and design critiques.

## Before changing behavior

Read the [guide](docs/language-guide.md), [decisions](docs/design-decisions.md),
and [roadmap](docs/roadmap.md). For language changes, open an issue or include a
short proposal in your pull request describing:

1. The user problem and a small motivating example.
2. Proposed syntax, expected behavior, and at least one failure case.
3. Relevant alternatives and tradeoffs for beginners.
4. Interactions with mutation, types, missing data, and R interoperability.
5. What remains unresolved and how the behavior could be checked.

Small documentation fixes do not need a separate proposal. A proposal is not an
accepted language rule until it is reviewed and recorded as such. Keep examples
explicitly provisional while decisions are open.

## Pull requests

- Keep each change focused and explain the problem it solves.
- Update affected documentation together so examples and rules agree.
- State what you verified and any checks you could not run.
- Record significant implementation changes and verification in [PROGRESS.md](PROGRESS.md).
- For compiler changes, include meaningful cases for intended behavior
  and relevant errors, with expected generated-R behavior.
- Respect other contributors; critique designs and code rather than people.
- Submit only material you have the right to contribute under the project's MIT license.

## AI-assisted contributions

AI tools are allowed. Contributors remain responsible for understanding their
changes, checking correctness, and responding to review. Do not submit generated
code you cannot explain, fabricated test results, or unverified claims about R.
Keep contributions small enough to review. Do not send secrets or private data
to tools. Review standards are the same regardless of how a contribution was made.

Coding agents should also follow [AGENTS.md](AGENTS.md).

## Package workflow

RStarStar is an installable R package with a .rsspps-file-only public source API.
The string compiler and rss_* helpers are internal. Language examples and data
live in inst/examples/; development runners live in examples/. See the
[package guide](docs/r-package.md).

From the repository root, install the current source before testing:

```sh
R CMD INSTALL .
Rscript tests/run.R
Rscript examples/demo.R
Rscript examples/run-file.R
Rscript examples/functions.R
Rscript examples/records.R
Rscript examples/standard-library.R
Rscript examples/csv-export.R
Rscript examples/grouped.R
Rscript examples/workflow.R
R CMD build .
R CMD check --no-manual RStarStar_0.0.17.tar.gz
git diff --check
```

Use the current package version in the archive name. Choose a writable R library
with --library=/path/to/library when needed, and set R_LIBS to that library when
running tests or demos. These Rscript files are development runners, not a public
CLI. Reinstall after R/ changes so tests exercise the current implementation.

The suite combines internal compiler tests with public API tests against the
installed namespace. It also runs under R CMD check. Chart-rendering tests report
skips when Cairo is unavailable; compiler and file-API checks remain available.
--no-manual skips PDF manual generation; API help and examples are still checked.
Only R-bundled packages are dependencies. Package metadata declares R >= 4.1.0;
local validation is on R 4.6.0. The configured CI matrix must run successfully
before broader compatibility is claimed.

Also check relative Markdown links and compare examples with the decision record.
See the [implemented subset](docs/implemented-subset.md) for the API and supported
syntax. Documentation-only changes need link and whitespace checks; code checks
are appropriate when examples or language claims change.


## Automated package checks

[Package checks](.github/workflows/package-check.yaml) runs on pushes, pull requests,
and manual dispatch. It targets R release on Linux, macOS, and Windows, and exactly
R 4.1.0 on Ubuntu 22.04. A configured target is not evidence of a successful run;
inspect the checks for your commit. No hosted results have been verified yet.

Run the same dependency-free developer script locally from the repository root:

```sh
Rscript .github/scripts/check.R
```

It installs into a temporary library, runs the behavioral suite and developer
demos, builds the current DESCRIPTION version, and runs R CMD check --no-manual.
Errors, warnings, and notes fail the check. Charts explicitly skip when Cairo is
unavailable; read the skip count before claiming chart coverage. Temporary library
and demo chart files are cleaned up; the ignored archive and .Rcheck logs remain.
CI uploads available .Rcheck logs for 14 days, including failed checks. Failures
before package checking are visible in the job console. The runner needs network
access for R's dependency-index checks. PDF manuals are not checked.

The workflow uses read-only repository permissions, ordinary pull_request events,
and no publication step. Its R setup follows the
[official setup-r action documentation](https://github.com/r-lib/actions/tree/v2/setup-r).
GitHub workflow infrastructure may change; review action upgrades separately.
