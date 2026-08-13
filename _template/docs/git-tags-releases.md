# Tags and releases

What this covers: creating and pushing tags, cutting a GitHub Release by hand or via CI, and managing releases afterward. For version-number conventions, see [versioning.md](./versioning.md).

---

## Tags

Tags mark a specific commit as significant - usually a release.

```bash
# Create an annotated tag (recommended, has a message and author)
git tag -a v1.2.0 -m "Release v1.2.0"

# Create a lightweight tag (no metadata)
git tag v1.2.0

# Push tags to GitHub (they don't go up with normal push!)
git push origin v1.2.0                       # one specific tag
git push --tags                              # all tags (use with care)
git push --follow-tags                       # only annotated tags reachable from current branch (safest)

# List tags
git tag                                      # all tags
git tag -l "v1.*"                            # pattern match
git show v1.2.0                              # see what the tag points at

# Delete a tag (you typo'd, etc.)
git tag -d v1.2.0                            # locally
git push origin :refs/tags/v1.2.0            # also on the remote
# or:
git push --delete origin v1.2.0
```

See [versioning.md](./versioning.md) for the `vMAJOR.MINOR.PATCH` convention used above.

---

## Releases

A "Release" on GitHub is a tag + a notes page + (optional) attached binaries.

### Manual release with `gh`

```bash
# 1. Make sure your CHANGELOG / version files are committed and pushed
git push

# 2. Tag the release commit
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0

# 3. Create the GitHub Release
gh release create v1.2.0 \
  --title "v1.2.0 - Cron support + HTML digest" \
  --notes-file CHANGELOG-v1.2.0.md
# or auto-generate notes from PRs since the last tag:
gh release create v1.2.0 --generate-notes

# Attach files (tarballs, binaries, etc.)
gh release create v1.2.0 dist/*.tar.gz dist/*.zip --generate-notes

# Mark as a pre-release
gh release create v1.2.0-rc1 --prerelease --generate-notes

# Mark as draft (publish later)
gh release create v1.2.0 --draft --generate-notes
```

### Automated release (the way this template's repos already do it)

See [release-workflow.md](./release-workflow.md) for the full workflow. The flow from your side is just:

```bash
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
# CI builds artifacts and creates the GitHub Release automatically
```

### Manage existing releases

```bash
gh release list
gh release view v1.2.0
gh release view v1.2.0 --web
gh release edit v1.2.0 --notes "..."
gh release upload v1.2.0 some-extra-file.tar.gz
gh release delete v1.2.0                     # also offers to delete the git tag
```

### Conventional release flow (this project's CHANGELOG style)

You use [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). See [changelog-format.md](./changelog-format.md) for the exact formatting rules. The mechanical steps:

1. Decide the new version number (see [versioning.md](./versioning.md)).
2. In `CHANGELOG.md`, move the items currently under `## [Unreleased]` down into a new `## [X.Y.Z] - YYYY-MM-DD` heading, keeping them under their existing subsection headings (Added, Changed, Deprecated, Removed, Fixed, Security).
3. Leave a fresh, empty `## [Unreleased]` section at the top of the file.
4. Update version pins / scripts that reference the version.
5. Commit: `git commit -am "release: vX.Y.Z"`
6. Tag and push: `git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push --follow-tags`
7. (CI handles the GitHub Release.)

---

Back to [template index](../README.md)
