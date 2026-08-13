# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [2.0.0] - 2026-08-05

### Added

- Added `.github/workflows/lint-ascii.yml`, a CI workflow that scans every tracked markdown file for em dashes, smart quotes, and emoji on push, pull request, and manual dispatch, and fails the build if any are found. It ships to every downstream repo scaffolded from this template the same way `release.yml` does, and is documented in `_template/CLAUDE.md` alongside the release workflow section.
- Added `.gitattributes`, marking `_template/`, `.github/`, and `.gitattributes` itself as `export-ignore` so `git archive` (and by extension the release workflow) leaves template-only scaffolding and CI configuration out of the source `.tar.gz`/`.zip` attached to a release.
- Added a "prepare" job to the release workflow that stamps release metadata into the tagged commit before the build and publish jobs run. When a `LICENSE` file with a `Change Date:` line is present (Business Source License 1.1), it rolls the date forward to four years out, bumps the copyright year, commits the change, and force-moves the tag onto the amended commit so the stamped values ship inside the release archive; repos without a BSL license skip the step silently. The job also supports optionally stamping a version constant into a configured file and verifies the tag points at the default branch tip before amending anything.
- Added `_template/CLAUDE.md`, `_template/PROJECT_CLAUDE.md`, and `_template/README.md`: a maintenance guide for the template library itself, an optional starter `CLAUDE.md` a downstream project can rename and keep, and a full index of the library's layout and docs.
- Added 15 topic-specific reference docs under `_template/docs/` (`new-project`, `vscode-setup`, `troubleshooting`, `release-workflow`, `release-languages`, `release-hardening`, `versioning`, `changelog-format`, and seven git-related topics covering setup, daily flow, PRs, merging, tags/releases, recovery, and aliases), each kept to roughly 120 lines, replacing the handful of large reference files that previously lived at the repo root.

### Changed

- Reorganized the repository into a `_template/` split: the root now holds only what a real project keeps (README stub, `CHANGELOG.md` stub, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, issue/PR templates, `.gitignore`, `.gitattributes`, and the single `release.yml`), while everything specific to maintaining this template library moved under `_template/`. Starting a real project from this template is now "delete `_template/`" and nothing else.
- Consolidated two near-duplicate release workflows into a single `.github/workflows/release.yml`, rebased on the more evolved of the two, with a default single-OS matrix, an always-on source bundle step, and per-language build blocks kept commented out and additive rather than mutually exclusive.
- Rewrote the root `README.md` as a fill-in-the-placeholders project stub (install, usage, configuration, development, releases, license, community sections) followed by a deletable template-index section that links out to every doc now under `_template/`, replacing the previous README that was only a templates index.
- Replaced the old round-based numbered changelog format with Keep a Changelog 1.1.0 across `CHANGELOG.md`, `_template/CHANGELOG.md`, `_template/docs/changelog-format.md`, `CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE.md`, and `_template/docs/git-tags-releases.md`.

### Removed

- Deleted `.github/workflow-templates/`, since GitHub only surfaces workflow templates from an organization's public `.github` repository and this repo is a personal, private one, so the picker never showed them.
- Deleted `GIT_GITHUB_CHEATSHEET.md`, `VSCODE_QUICKSTART.md`, `RELEASE_TEMPLATE_README.md`, and `CHANGELOG_TEMPLATE.md` once their content had fully landed in `_template/docs/`.

### Fixed

- Fixed release archive filenames for this repository. `github.event.repository.name` resolves to `.github-private`; used verbatim, the archive filename became a dotfile, which `ls -l` does not list and `actions/upload-artifact`'s `dist/**` glob does not match by default, so the build step silently produced no uploadable artifacts. The workflow now strips a leading dot before building the archive name and lists build output with `ls -la` so this class of failure is visible next time.
