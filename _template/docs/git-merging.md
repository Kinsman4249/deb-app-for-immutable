# Merging - which strategy?

What this covers: the three PR merge strategies and how to set a repo's default.

---

Three flavors. Pick based on what you want the history to look like.

### `--squash` (default for most solo work)
Collapses the entire branch into **one** commit on `main`. Your branch's individual commits disappear; the PR title becomes the commit message.

+ Clean linear history, one PR = one commit
+ Easy to revert (`git revert <sha>`)
- You lose the branch's individual commits forever

### `--merge` (creates a merge commit)
Preserves all branch commits, adds a "Merge pull request #42" commit on top.

+ Full history preserved
- History becomes branchy and harder to read

### `--rebase`
Replays branch commits onto `main` one by one, no merge commit.

+ Linear history with each commit preserved
- Rewrites SHAs; don't use if anyone else might have based work on your branch

**Recommendation for solo + small-team work:** use `--squash` by default. Switch to `--merge` only for big features where the individual-commit story matters.

You can also set the default per-repo so the GitHub UI nudges you correctly:

```bash
gh repo edit --enable-squash-merge         # allow squash
gh repo edit --enable-merge-commit=false   # disallow regular merge commits
gh repo edit --enable-rebase-merge=false   # disallow rebase
gh repo edit --delete-branch-on-merge      # auto-delete merged branches
```

---

Back to [template index](../README.md)
