<!-- LINT.IfChange(project_header) -->
# {{ project }}

{{ description }}
<!-- LINT.ThenChange(//README.md:project_header) -->

## Project structure

<!-- LINT.IfChange(project_structure) -->
- `cmd/<name>/` — one directory per executable; keep `main.go` thin and call into `internal/`
- `internal/` — application code, not importable by other modules
- Tests live next to the code they test as `*_test.go` files, with fixtures in a package-local `testdata/`
<!-- LINT.ThenChange(//README.md:project_structure) -->

## Commands

<!-- LINT.IfChange(commands) -->
Run `mise install` to provision Go and the development tools pinned in `mise.toml`, then use mise tasks (`mise tasks` lists them):

- `mise run fmt` — format Go code
- `mise run lint` — formatting, `go.mod` tidiness, govulncheck, and golangci-lint. Always run after making changes.
- `mise run test` — tests with the race detector
- `mise run doc` — browse the documentation locally in the pkg.go.dev style
<!-- LINT.ThenChange(//README.md:commands, //mise.toml:lint_task) -->

## Conventions

<!-- LINT.IfChange(commit_subject) -->
- Write commit messages as Conventional Commits with a capitalized subject of at most 50 characters (e.g. `feat: Add login`). Check them with `mise run check-commits`.
<!-- LINT.ThenChange(//committed.toml:commit_subject) -->
- `CHANGELOG.md` is generated from commit messages; regenerate it with `mise run changelog` instead of editing it.
- Use narrow `LINT.IfChange` / `LINT.ThenChange` directives when duplicated cross-file content must stay in sync and cannot be eliminated.
  Write targets as repository-root paths starting with `//` (e.g. `//mise.toml:go_version`); ifttt-lint enforces them in CI.

## Version control

If a `.jj` directory exists in the repository root, default to using `jj` (Jujutsu) for version control; otherwise, use `git`.
