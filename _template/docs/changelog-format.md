# Changelog formatting guide

What this covers: how entries in `CHANGELOG.md` should be written. This
project follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
paired with [Semantic Versioning](https://semver.org). This file does not
contain real entries; copy the structure below and fill it in as you work.

If the real changelog does not live at the repo root (this template repo is
one example: its root `CHANGELOG.md` is a blank stub for downstream projects,
and its own history is in `_template/CHANGELOG.md`), add a one-line
`.release-changelog` file at the repo root containing the real path. The
`release-gh` and `release-coach` skills read it; without it they assume
`CHANGELOG.md` at the root.

---

## Overall structure

```
# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2026-08-05

### Added

- ...
```

- `## [Unreleased]` always sits at the top, above every version heading. It
  collects work as it lands, before a release ships.
- Version headings are `## [X.Y.Z] - YYYY-MM-DD`, newest first.
- At release time, the `[Unreleased]` items move under a new version heading
  dated with the release, and a fresh empty `[Unreleased]` is left at the top.

## The six subsections

Use only the ones that apply to a given release; skip empty ones rather than
including them with no content.

```
### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security
```

## Bullet points, not numbered items

Each entry is a `-` bullet under the relevant subsection heading:

```
### Added

- Short description of the change.
- Another change, same subsection.
```

## What belongs in a single entry

An entry should read as a short sentence stating what changed, from the point
of view of someone consuming the project (not someone reading the diff). Keep
it to one or two sentences. Save deep implementation detail for the commit
history or PR description, not the changelog.

## Language rules

- No em dashes anywhere in the file
- No emojis anywhere in the file
- No exclamation points
- Write in full sentences, not sentence fragments
- Avoid marketing language ("blazing fast," "seamless," "powerful"). State what the thing does and let that speak for itself
- Avoid vague verbs like "improved" or "enhanced" without saying what specifically changed
- Past tense throughout, since a changelog describes what was already done

## Formatting rules

- Use `##` for version headings and `###` for subsection headings
- Use a plain bullet list (`-`), not numbered items or nested sub-bullets
- No tables
- No bold or italic text inside entries themselves
- Keep line wrapping natural. Do not hard-wrap lines mid-sentence

## What not to include

- Do not list every commit. A changelog entry describes a finished, coherent piece of work, not individual git commits
- Do not include internal file names or line numbers unless the reader would actually need them to act on the information
- Do not include placeholder or "coming soon" items. Only document what has actually shipped

---

Back to [template index](../README.md)
