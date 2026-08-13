# .github-private (template library)

Private home for **reusable community-health files and project templates**
that get copied into Kinsman4249's public projects.

If you are reading this inside a real project: someone forgot to delete
`_template/`. Delete this whole folder and the template index section of the
root `README.md` - see [../README.md](../README.md) for the exact marker.

## Why a separate private repo

GitHub natively supports a `.github` repo on user/org accounts that
automatically applies community-health files to all public repos. That's nice
in theory but couples every project to a single set of templates. Keeping
these as **canonical sources you copy from** rather than **defaults that
auto-apply** lets each project tweak its own templates (test commands,
supported versions, etc.) without diverging from the originals here.

## What lives here

```
.github-private/
|-- README.md                  project stub + delete-me template index (the hub)
|-- CHANGELOG.md               blank Keep a Changelog stub, ready to use
|-- CONTRIBUTING.md            placeholders intact
|-- CODE_OF_CONDUCT.md         placeholders intact
|-- SECURITY.md                placeholders intact
|-- .gitignore
|-- .gitattributes             keeps _template/ and .github/ out of release zips
|-- .github/
|   |-- PULL_REQUEST_TEMPLATE.md
|   |-- ISSUE_TEMPLATE/
|   |   |-- bug_report.md
|   |   `-- feature_request.md
|   `-- workflows/
|       `-- release.yml        THE workflow. One file. Ships everywhere.
`-- _template/                 <-- delete this folder to start a real project
    |-- README.md              this file: the full library index
    |-- CLAUDE.md              rules for maintaining this template library
    |-- PROJECT_CLAUDE.md      optional starter; rename to /CLAUDE.md in a real project
    |-- CHANGELOG.md           this library's own real history
    `-- docs/
        |-- new-project.md
        |-- vscode-setup.md
        |-- release-workflow.md
        |-- release-languages.md
        |-- release-hardening.md
        |-- versioning.md
        |-- changelog-format.md
        |-- git-setup.md
        |-- git-daily-flow.md
        |-- git-pr-flow.md
        |-- git-merging.md
        |-- git-tags-releases.md
        |-- git-recovery.md
        |-- git-aliases.md
        `-- troubleshooting.md
```

## Using this repo

**Starting a new project?** Copy this whole repo (or use "Use this template"
on GitHub, once it is marked as a template repo), then:

1. Fill in the placeholders in the root `README.md` (`<PROJECT_NAME>`,
   `<REPO_URL>`, etc. - see [new-project.md](docs/new-project.md) for the full
   walkthrough).
2. Delete everything from the `TEMPLATE INDEX` marker down in the root
   `README.md`, and delete this `_template/` folder.
3. Optionally rename `_template/PROJECT_CLAUDE.md` to `/CLAUDE.md` if you want
   a starting set of Claude directives; otherwise it goes with the folder. If
   you keep it, delete everything from its `DELETE-ON-ADOPT` marker down - that
   part explains what belongs in the file and is not meant to be reloaded by
   every session in the repo. The `newproj` skill does this for you.

**Updating a community-health policy that should apply across all
projects?** Edit the canonical version here first, then open PRs to each
downstream public repo to bring them into sync.

## The full doc list

### Getting started

- [new-project.md](docs/new-project.md) - the full walkthrough from idea to first shipped release.
- [vscode-setup.md](docs/vscode-setup.md) - one-time VS Code and GitHub sign-in setup.
- [troubleshooting.md](docs/troubleshooting.md) - common gotchas when setting up a new project.

### Release workflow

- [release-workflow.md](docs/release-workflow.md) - what `release.yml` does and how to run it.
- [release-languages.md](docs/release-languages.md) - adding a compiled build on top of the default source bundle.
- [release-hardening.md](docs/release-hardening.md) - the security rationale behind the workflow's defaults.

### Git and GitHub

- [git-setup.md](docs/git-setup.md) - one-time machine setup for git and the `gh` CLI.
- [git-daily-flow.md](docs/git-daily-flow.md) - when to push to `main` directly versus opening a PR.
- [git-pr-flow.md](docs/git-pr-flow.md) - branching, opening a PR, and the `gh pr` commands.
- [git-merging.md](docs/git-merging.md) - the three PR merge strategies and how to set a default.
- [git-tags-releases.md](docs/git-tags-releases.md) - creating and pushing tags, cutting a release.
- [git-recovery.md](docs/git-recovery.md) - recovering from the git mistakes that come up most often.
- [git-aliases.md](docs/git-aliases.md) - time-saving git and `gh` aliases plus a summary card.

### Conventions

- [versioning.md](docs/versioning.md) - the SemVer rules used across tags, releases, and the changelog.
- [changelog-format.md](docs/changelog-format.md) - how to write `CHANGELOG.md` entries.

Back to [root README](../README.md).
