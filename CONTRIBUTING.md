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

## Local checks today

The prototype uses base R with no external dependencies. From the repository
root, run the behavioral suite and example for compiler changes:

```sh
Rscript tests/run.R
Rscript examples/demo.R
Rscript examples/read-csv.R
Rscript examples/filter.R
Rscript examples/workflow.R
Rscript examples/grouped.R
git diff --check
git status --short
```

Also check relative Markdown links and compare examples with the decision record.
See the [implemented subset](docs/implemented-subset.md) for the API and supported
syntax. Documentation-only changes need link and whitespace checks; code checks
are appropriate when examples or language claims change.
