# <PROJECT_NAME>

<ONE_LINE_DESCRIPTION>

## Install

<INSTALL_INSTRUCTIONS>

## Usage

<USAGE_INSTRUCTIONS>

## Configuration

<CONFIGURATION_INSTRUCTIONS>

## Development

<DEVELOPMENT_INSTRUCTIONS>

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full contribution workflow, and `<TESTING_INSTRUCTIONS>` above for how to verify a change locally.

## Releases

Push a tag matching `vX.Y.Z` to `main` (`git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`). CI builds and publishes the GitHub Release automatically - nothing else to do.

## License

See [LICENSE](<REPO_URL>/blob/main/LICENSE).

## Community

- [CONTRIBUTING.md](./CONTRIBUTING.md) - how to report bugs, propose features, and submit changes.
- [SECURITY.md](./SECURITY.md) - how to report a vulnerability.
- [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) - the standards this project holds contributors to.

<!-- ============================================================
     TEMPLATE INDEX - delete everything from this marker down,
     and delete the _template/ folder, when starting a real project.
     ============================================================ -->

## What this template gives you

Everything above this marker is a real project README, ready to fill in and
keep. Everything below it, plus the whole `_template/` folder, is reference
material for setting the project up: a step-by-step new-project walkthrough,
the release workflow this repo ships with, and a git/GitHub command reference.
None of it is needed once the project is running - delete `_template/` and
this section together and you are left with a normal README.

### Getting started

- [new-project.md](./_template/docs/new-project.md) - the full walkthrough from idea to first shipped release.
- [vscode-setup.md](./_template/docs/vscode-setup.md) - one-time VS Code and GitHub sign-in setup.
- [troubleshooting.md](./_template/docs/troubleshooting.md) - common gotchas when setting up a new project.

The dev environment these docs assume is provisioned by
[vscodium-for-immutable](https://github.com/Kinsman4249/vscodium-for-immutable):
it builds the `vscodium-box` container and installs the editor, git, gh, and
the lint toolchain (shellcheck, actionlint, jq, fd, yamllint). Environment
changes belong in that installer rather than in one-off commands, so they
survive a container rebuild.

### Release workflow

- [release-workflow.md](./_template/docs/release-workflow.md) - what `release.yml` does and how to run it.
- [release-languages.md](./_template/docs/release-languages.md) - adding a compiled build on top of the default source bundle.
- [release-hardening.md](./_template/docs/release-hardening.md) - the security rationale behind the workflow's defaults.

### Git and GitHub

- [git-setup.md](./_template/docs/git-setup.md) - one-time machine setup for git and the `gh` CLI.
- [git-daily-flow.md](./_template/docs/git-daily-flow.md) - when to push to `main` directly versus opening a PR.
- [git-pr-flow.md](./_template/docs/git-pr-flow.md) - branching, opening a PR, and the `gh pr` commands.
- [git-merging.md](./_template/docs/git-merging.md) - the three PR merge strategies and how to set a default.
- [git-tags-releases.md](./_template/docs/git-tags-releases.md) - creating and pushing tags, cutting a release.
- [git-recovery.md](./_template/docs/git-recovery.md) - recovering from the git mistakes that come up most often.
- [git-aliases.md](./_template/docs/git-aliases.md) - time-saving git and `gh` aliases plus a summary card.

### Conventions

- [versioning.md](./_template/docs/versioning.md) - the SemVer rules used across tags, releases, and the changelog.
- [changelog-format.md](./_template/docs/changelog-format.md) - how to write `CHANGELOG.md` entries.

To start a real project: delete everything from the marker above down, delete
the `_template/` folder, and fill in the placeholders left in Part A. For the
full library index - what this repo is, why it is private, and the complete
doc list - see [_template/README.md](./_template/README.md).
