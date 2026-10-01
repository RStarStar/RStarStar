# Contributing to RStarStar

RStarStar is at the language-design stage. Beginners, experienced R users, and
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
- For future compiler changes, include meaningful cases for intended behavior
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

There is no installation or automated test suite yet. For documentation changes:

```sh
git diff --check
git status --short
```

Also check relative Markdown links and compare examples with the decision record.
Build and test instructions will be added with the first implementation.
