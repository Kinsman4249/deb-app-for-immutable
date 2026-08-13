# Claude directives: maintaining this template library

These rules apply only while working inside `.github-private` itself (the
template library). They are deleted along with `_template/` when a real
project is scaffolded from this repo - see `PROJECT_CLAUDE.md` for the rules
that travel with a real project instead.

Style and comment rules come from the global `~/.claude/CLAUDE.md`; only what
is specific to this repo is written out below.

## Doc structure

- One topic per `.md` file under `_template/docs/`. Link to sibling docs
  instead of duplicating their content.
- Keep each doc under ~120 lines. Split into a new topic file rather than
  letting one grow past that.
- When adding, removing, or renaming a doc, update BOTH `_template/README.md`
  (the full index) and the template index section in the root `README.md`
  (the short index).
- After editing any doc, re-run the link check:
  ```
  grep -oP '\]\(\K[^)#]+' README.md _template/README.md _template/docs/*.md | sort -u
  ```
  then confirm every relative path it prints actually exists.

## Root vs. `_template/`

- The repo root holds only files a real project keeps (README stub,
  CHANGELOG stub, CONTRIBUTING/SECURITY/CODE_OF_CONDUCT, issue/PR templates,
  the one `release.yml`).
- Anything about the template library itself - its own index, its own
  changelog, its own Claude rules, the reference docs - goes in `_template/`.

## Release and CI workflows

- There is exactly one `release.yml`, at `.github/workflows/release.yml`, and
  one `lint-ascii.yml` beside it (which enforces the ASCII-only rule on every
  push/PR touching a `.md` file). Both ship to every downstream repo. Never
  reintroduce a second copy of either.
- Do NOT SHA-pin their `uses:` actions, and do NOT run `pinact` against this
  repo, without asking the maintainer first. This repo has no Dependabot
  upkeep, so pins rot into unpatched dependencies.

Back to [template index](README.md).
