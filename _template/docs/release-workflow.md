# The release workflow

What this covers: what `release.yml` does, how to add it to a new repo, and how to run it manually. For adding a compiled build, see [release-languages.md](./release-languages.md); for the security rationale behind its defaults, see [release-hardening.md](./release-hardening.md).

---

## What it does

When you push a version tag (e.g. `v0.1.0`), the workflow runs three jobs in order:

1. **prepare** - stamps release metadata into the tagged commit (see [BSL Change Date](#bsl-change-date) below), then moves the tag onto the amended commit. Does nothing in a repo with no metadata to stamp, which is the common case.
2. **build** - checks out the tag, bundles the repo into a `.tar.gz` and a `.zip` (always runs, no setup needed), and optionally builds your project on Linux, macOS, and Windows if you've uncommented a language block.
3. **release** - attaches the resulting artifacts to a new GitHub Release and auto-generates notes from PRs and commits since the last tag.

A manual "Run workflow" button is also provided in the **Actions** tab for re-running a release.

## BSL Change Date

If your repo uses the Business Source License 1.1, the `prepare` job keeps the licence's `Change Date:` current for you. On each release it rolls that date forward to four years out, bumps the copyright year, commits the change, and moves the tag onto that commit.

This has to happen before packaging, not after: BSL caps the Change Date at the fourth anniversary of a version's first public distribution, so the date must be inside the commit the tag points at. A date edited after the fact would leave the published archive claiming the old one.

Nothing to configure. A repo with no `LICENSE`, or a `LICENSE` with no `Change Date:` line, skips the whole thing silently.

Two constraints worth knowing:

- The tag must point at the tip of your default branch. The job fails loudly rather than rewriting history somewhere unexpected. Tag from the default branch and this is automatic.
- The job pushes to the default branch. If that branch is protected, either grant the actions bot an exception or delete the `prepare` job and bump `LICENSE` by hand before tagging.

Only `LICENSE` and a top-level `README` are rewritten. This is deliberately not a tree-wide search-and-replace: a CHANGELOG that records "Change Date set to <old date>" is stating history, and rewriting it would falsify the record.

## How to use it in a new repo

1. Copy `.github/workflows/release.yml` from this repo into your project at the same path.
2. That's it - the source bundle runs by default with no edits.
3. If you also want a compiled build for your language, uncomment the matching block. See [release-languages.md](./release-languages.md).
4. Commit and push.

## Cutting your first release

From your local clone of the project:

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Push the one tag by name rather than `git push --tags`, which would also push any stale or experimental tags sitting in your local clone.

Within a minute or two, a new Release appears under the **Releases** tab on GitHub with your artifacts attached.

For subsequent releases, bump the version number - see [versioning.md](./versioning.md).

## Running manually

Go to your repo on GitHub > **Actions** > **Release** > **Run workflow**. Enter an existing tag name and click Run.

---

Back to [template index](../README.md)
