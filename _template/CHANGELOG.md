# Changelog

All notable changes to this repository are documented in this file. For the
rules on how entries here should be written, see
[changelog-format.md](./docs/changelog-format.md).

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.3.1] - 2026-08-08

### Added

- Added `.release-changelog` file and documentation in `changelog-format.md` explaining the override mechanism. Template repositories that keep their changelog elsewhere (not at the root) can now point the `release-gh` and `release-coach` skills to the real changelog location with a one-line `.release-changelog` file.

## [2.3.0] - 2026-08-08

### Changed

- `_template/PROJECT_CLAUDE.md` now carries its guidance below a `DELETE-ON-ADOPT` marker, so an adopted copy keeps roughly 175 bytes rather than 929. The previous version retained a `## Releases` and a `## Changelog` section in every scaffolded repo, and both restated rules that already live in the global `~/.claude/CLAUDE.md` and in the `release-*` skills; the global file carries "releases: release-* skill only, never ad hoc" almost verbatim. That duplication costs more here than anywhere else, because `newproj` gitignores the adopted file: it loads into every session in the repo while no CI can lint it, cap its size, or fix it in bulk, so a copied rule keeps saying the old thing indefinitely after the original moves on. The text below the marker now says that outright and lists what does belong - an undiscoverable build or test command, a convention the project deliberately breaks, a path that must not be hand-edited, a gotcha that has already cost someone an hour - and tells the reader to delete a heading rather than fill it with the default answer.
- `_template/README.md` adoption step 3 now says to delete from the `DELETE-ON-ADOPT` marker down when adopting the starter directives by hand, which is what the `newproj` skill does automatically.

## [2.2.0] - 2026-08-08

### Changed

- `_template/PROJECT_CLAUDE.md` now states only what is specific to a scaffolded project, deferring style, comment, and changelog-entry rules to the global `~/.claude/CLAUDE.md` and the `release-gh` skill that already enforce them. Its `## Style` section was removed outright: besides duplicating the global ASCII and ambiguity rules, it instructed that comments explain why rather than what and be skipped where code is self-explanatory, which contradicted the global preference for novice-level comments on non-obvious choices. Because a project-local `CLAUDE.md` takes precedence over the global one, every repo scaffolded from this template had been silently overriding that preference. The `## Releases` section previously described tagging by hand, which conflicted with the rule that releases go through the `release-gh` skill, and now points at the skill and notes that the skill is what pushes the tag the release workflow reacts to. The `## Changelog` section keeps the Keep a Changelog reference and the heading shape and defers the entry-writing rules, dropping roughly twenty lines that restated them.
- `_template/CLAUDE.md` lost the same duplicated `## Style` section, and its `## Release workflow` and `## CI` sections were merged into one, since both existed mainly to repeat that the shipped workflows must not be SHA-pinned or run through `pinact` without asking first. The doc-structure rules, the root versus `_template/` split, and the single-copy rule for `release.yml` and `lint-ascii.yml` are unchanged. Both files now carry a line naming where the omitted base rules live, so a later edit does not reintroduce them.

### Fixed

- Removed a stray literal `</content>` line left at the end of `README.md`, `_template/README.md`, `_template/CLAUDE.md`, and `_template/PROJECT_CLAUDE.md`. The occurrence in the root `README.md` was the significant one, since that file is the project stub every repo scaffolded from this template inherits, and the artifact was being copied into each of them.

## [2.1.0] - 2026-08-06

### Added

- The root README's template index and `_template/docs/vscode-setup.md` now point at [vscodium-for-immutable](https://github.com/Kinsman4249/vscodium-for-immutable) as the source of the development environment these docs assume. `vscode-setup.md` gained an "On an immutable Fedora host" subsection, because its first two prerequisites tell the reader to install VS Code and git onto the host OS, which is not possible on an immutable one. Both places state that environment changes belong in that installer rather than in one-off commands, since a tool installed by hand into the container does not survive a rebuild and a missing tool is how a verification step gets silently skipped.

### Fixed

- The ASCII lint workflow no longer misses violations in repositories with enough Markdown files to split the file list across several `grep` invocations. The step branched on the exit status of `xargs`, which reflects only the last invocation it ran, so a violation in an earlier batch was reported as a pass. It now collects the matches and tests that output for content instead. The check also handles filenames containing spaces, and always prints the filename alongside the match.

## [2.0.0] - 2026-08-05

### Changed

- Reorganized the repository into a `_template/` split: the root now holds
  only what a real project keeps (README stub, CONTRIBUTING, CODE_OF_CONDUCT,
  SECURITY, issue/PR templates, `.gitignore`, `.gitattributes`), and
  everything specific to maintaining this template library moved under
  `_template/` (its own README, CLAUDE.md, PROJECT_CLAUDE.md, CHANGELOG.md,
  and topic-split docs under `_template/docs/`). Starting a real project from
  this template is now "delete `_template/`" and nothing else.
- Collapsed the two near-duplicate release workflows into a single
  `.github/workflows/release.yml`, rebased on the most-evolved copy (from
  `intune-script-wizard`), with a default single-OS matrix, an always-on
  source bundle step, and per-language build blocks kept commented and
  additive rather than mutually exclusive.
- Split `GIT_GITHUB_CHEATSHEET.md`, `VSCODE_QUICKSTART.md`, and
  `RELEASE_TEMPLATE_README.md` into topic-level files under `_template/docs/`,
  each capped at roughly 120 lines, so a future edit touches one topic
  instead of one large file.
- Replaced the round-based numbered changelog format with Keep a Changelog
  1.1.0 across this file, the root `CHANGELOG.md` stub,
  `_template/docs/changelog-format.md`, `CONTRIBUTING.md`,
  `.github/PULL_REQUEST_TEMPLATE.md`, and `_template/docs/git-tags-releases.md`.

### Removed

- Deleted `.github/workflow-templates/`. GitHub only surfaces workflow
  templates from an organization's public `.github` repository, and this repo
  is a personal, private repo, so the picker never showed them.
- Deleted `GIT_GITHUB_CHEATSHEET.md`, `VSCODE_QUICKSTART.md`,
  `RELEASE_TEMPLATE_README.md`, and `CHANGELOG_TEMPLATE.md` once their
  content had fully landed in `_template/docs/`.

## [0.6.0] - 2026-07-11

### Added

- Added `.github/workflows/release.yml`, this repository's own release
  workflow, separate from the multi-language build template kept under
  `.github/workflow-templates/`. Because the repository ships only markdown
  and template files with nothing to compile, the workflow does not build
  binaries. It runs on a single Ubuntu runner and uses `git archive` to
  package the tagged commit into a `.tar.gz` and a `.zip` source snapshot,
  then attaches both to a GitHub Release with auto-generated notes.

### Changed

- Scoped the workflow permissions to read-only by default and elevated only
  the release job to `contents: write`, so the token holds the minimum
  access needed to publish. Added a concurrency group keyed on the tag so a
  re-pushed tag cannot race an in-progress publish, configured so an
  in-flight run is not cancelled.
- Set the release step to fail when its file glob matches nothing, so a
  broken archive step cannot silently publish an empty release. The workflow
  triggers on tags matching the `v*.*.*` pattern and also supports a manual
  `workflow_dispatch` run that takes an existing tag name.
- Updated the README file tree to add the `.github/workflows/` directory and
  to note the distinction between this repository's own release workflow and
  the reusable release template kept under `.github/workflow-templates/`.

## [0.5.0] - 2026-07-10

### Added

- Added a changelog formatting guide as a reusable template, later renamed to
  `CHANGELOG_TEMPLATE.md` so it would not be mistaken for an actual
  changelog.
- Added this changelog file, with entries reconstructed from the
  repository's commit history.

### Changed

- Updated the README's file index to include the changelog files and the Git
  and GitHub cheatsheet, which existed in the repo but were missing from the
  documented file tree, and added a line to the workflow section instructing
  that every new project should get its own changelog copied from the
  template.
- Merged the post-1.0 security policy variant into a single `SECURITY.md`,
  since backporting fixes across major versions is not the normal workflow
  for these projects. The default policy is simply: only the latest release
  receives fixes, regardless of version number.
- Corrected references to `CHANGELOG.md` in `CONTRIBUTING.md`,
  `PULL_REQUEST_TEMPLATE.md`, and `GIT_GITHUB_CHEATSHEET.md`, which had
  assumed Keep a Changelog format (an `[Unreleased]` section with
  version-numbered headers) instead of the round-based numbered format the
  repo used at the time. Also corrected a handful of remaining em dash
  characters in `README.md` and `GIT_GITHUB_CHEATSHEET.md` that the earlier
  ASCII cleanup round had missed.

### Removed

- Deleted `SECURITY-POST-1.0.md`, which had been left in the repository
  after its content was merged into `SECURITY.md`. Its presence contradicted
  the current security policy, since it still described the old
  multi-major-version support window.

## [0.4.0] - 2026-07-08

### Changed

- Cleaned up non-ASCII characters across the markdown files, replacing smart
  quotes, em dashes, and similar characters with plain ASCII equivalents for
  consistency and portability.

## [0.3.0] - 2026-05-05

### Added

- Added a post-1.0 variant of the security policy, narrowing support to only
  the newest major release line once a project matures past its initial 0.x
  versions.
- Added a Git and GitHub cheatsheet covering the daily solo workflow, the
  full PR-based workflow, merge strategies, tagging, releases, and common
  recovery commands for mistakes.

## [0.2.0] - 2026-05-04

### Added

- Added the tag-driven release workflow template (`release.yml`) plus its
  registration file (`release.properties.json`) so it appears in GitHub's
  workflow picker, along with a README explaining how to wire it into a new
  project and customize the build matrix.
- Added a full VS Code walkthrough guide covering the entire project
  lifecycle, from creating a new repo through cloning, adding the release
  workflow, committing, and tagging a first release, with cross-links added
  to the release template README.

## [0.1.0] - 2026-05-03

### Added

- Created the repository as an empty private repo with the default
  auto-generated README.
- Replaced the auto-generated README with a templates index describing what
  the repo is for and how to use it.
- Added a generic Code of Conduct template based on Contributor Covenant 2.1,
  with a project-agnostic placeholder for the repo URL.
- Added a generic Contributing guide template covering bug reports, feature
  requests, PR submission steps, and pre-1.0 versioning rules.
- Added a generic Security policy template covering vulnerability reporting
  through GitHub Security Advisories.
- Added a generic bug report issue template with sections for environment
  details, reproduction steps, and log output.
- Added a generic feature request issue template that asks for the use case
  before the proposed solution.
- Added a generic pull request template with sections for summary, type of
  change, testing, and documentation.
