# Troubleshooting

What this covers: common gotchas when setting up a new project and its release workflow.

---

- **Tag must start with `v` and have three numbers.** `v1.0.0` is valid. `1.0.0`, `v1.0`, `version-1` are all invalid. The workflow only triggers on `v*.*.*`.
- **Tags push separately from commits.** Pushing your code does NOT push your tags. Use **Push Tags** in VS Code or `git push --tags` in the terminal.
- **The workflow needs `main` as the default branch.** If you used `master` or something else, edit `release.yml` to match (or change the default branch on GitHub).
- **The workflow didn't run?** Repo > Actions tab. If there's a red X, click it to see the error. Most common cause: a language block in `release.yml` wasn't uncommented correctly (look for stray `#` characters) - see [release-languages.md](./release-languages.md).
- **You re-tagged the same version.** Git won't let you push a tag that already exists on the remote. Either pick a higher version or delete the tag first: `git tag -d v0.1.0 && git push origin --delete v0.1.0`. Avoid this on tags that have already been used by anyone - version numbers are forever.
- **You can't sign in to GitHub from VS Code.** Make sure you don't have multiple GitHub accounts logged into your default browser. Sign out of the others temporarily, or use an incognito window for the VS Code auth flow.

---

Back to [template index](../README.md)
