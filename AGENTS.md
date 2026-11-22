# Agent instructions

For the project layout and development commands, read the [Project structure](README.md#project-structure) and [Commands](README.md#commands) sections of README.md. The rest of the README is written for people; skip it unless the task needs it.

<!-- init.sh:start -->
## Template

This repository is a project template; `init.sh` turns a copy into a real project and deletes this section.

- Keep the `{{ project }}` and `{{ description }}` placeholders and the `template-go` name (module path, `cmd/template-go/`) as they are: `init.sh` substitutes them.
- If you rename or move anything `init.sh` rewrites, update `init.sh` in the same change.
- Tests run on Linux only by default; `init.sh` can add macOS and Windows to the CI test matrix, so keep template code and tests portable.
- Try `init.sh` only in a scratch copy of the repository, since it rewrites files and deletes itself. Pass every value as a flag so it doesn't prompt: `./init.sh --name demo --description Demo --module github.com/example/demo --no-macos --no-windows </dev/null`.
<!-- init.sh:end -->

## CI

<!-- LINT.IfChange(checks) -->
CI also runs checks that `mise run lint` does not: `typos`, `ifttt-lint`, and `gitleaks`. Their tools are pinned in `mise.ci.toml`, which mise loads only when `MISE_ENV=ci` is set, so prefix every command with it: install with `MISE_ENV=ci mise install`, then run `MISE_ENV=ci typos` and `MISE_ENV=ci ifttt-lint --diff 'main..@'` (`main...HEAD` with git) before pushing.
<!-- LINT.ThenChange(//mise.toml:lint_task) -->
<!-- LINT.IfChange(test_os) -->
CI runs tests on Linux.
<!-- LINT.ThenChange(//init.sh:test_os) -->

GitHub requires only the `CI`, `Audit`, and `Lint Commits` checks. `CI` and `Audit` are aggregate jobs, so add any new job to the `needs` list of its workflow's aggregate job, and don't rename those three jobs. zizmor audits the workflows in CI, so follow the existing jobs: pin actions to a commit SHA with a version comment, and check out with `persist-credentials: false`.

## Conventions

<!-- LINT.IfChange(commit_subject) -->
- Write commit messages as Conventional Commits with a capitalized subject of at most 50 characters (e.g. `feat: Add login`). Check them with `mise run check-commits`.
<!-- LINT.ThenChange(//committed.toml:commit_subject) -->
- Use narrow `LINT.IfChange` / `LINT.ThenChange` directives when duplicated cross-file content must stay in sync and cannot be eliminated.
  Write targets as repository-root paths starting with `//` (e.g. `//mise.toml:go_version`); ifttt-lint enforces them in CI.
- Don't repeat README.md in AGENTS.md. When agents need something from the README, link the specific sections rather than the whole file, since most of the README is written for people.

## Version control

If a `.jj` directory exists in the repository root, default to using `jj` (Jujutsu) for version control; otherwise, use `git`. Under jj, `mise run check-commits` checks `main..HEAD`, and `HEAD` is `@-`, so it skips the working-copy change: run it after `jj commit`. It reports a change with no description as "Empty commits are disallowed".

- Every commit on `main` must pass CI. Pull requests land as a squash or a merge commit, so a PR's own commits need not each pass.
- Keep commits atomic: one responsibility each, with code, tests, and docs updated together. Put file renames in their own commit.
- Squash pull requests by default. Use a merge commit only when the history is worth keeping, such as what was tried or how a bug was tracked down.
