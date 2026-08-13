# Oh no - common git mistakes and fixes

What this covers: recovering from the git mistakes that come up most often.

---

### "I committed to `main` but meant to use a branch"

```bash
git switch -c feat/my-fix                    # creates branch, keeps your commit
git switch main
git reset --hard origin/main                 # reset main to clean state
git switch feat/my-fix                       # back to your work
git push -u origin feat/my-fix
```

### "I committed but forgot to add a file"

```bash
git add forgotten-file.md
git commit --amend --no-edit                 # tacks the file onto the previous commit
# If you've already pushed: needs --force-with-lease (see below)
```

### "I want to change the last commit message"

```bash
git commit --amend                           # opens editor
git commit --amend -m "new message"
# If already pushed:
git push --force-with-lease                  # safer than --force
```

### "I made a commit I want to undo"

```bash
# Haven't pushed yet:
git reset --soft HEAD~1                      # undo commit, keep changes staged
git reset HEAD~1                             # undo commit, keep changes unstaged
git reset --hard HEAD~1                      # undo commit AND throw changes away (!)

# Already pushed and others may have pulled, don't rewrite history:
git revert HEAD                              # creates a new "undo" commit. Safe.
```

### "I'm on the wrong branch and have uncommitted changes"

```bash
git stash                                    # save current changes
git switch correct-branch
git stash pop                                # bring changes back
```

### "I have merge conflicts"

```bash
# After a pull/merge that conflicted:
git status                                   # see which files conflict
# Open each file. Find <<<<<<< / ======= / >>>>>>> markers. Edit to resolve.
git add <resolved-file>
git commit                                   # finishes the merge
# (or `git merge --abort` to bail)
```

### "I'm in detached HEAD mode"

```bash
git switch main                              # go back to main
# If you made commits in detached state and want to keep them:
git switch -c rescue-branch                  # before switching away
```

### "I want to delete a branch that won't delete"

```bash
git branch -d feat/done                      # safe delete (refuses if unmerged)
git branch -D feat/done                      # force delete (destroys unmerged commits!)
git push origin --delete feat/done           # remote branch
```

### "I need to throw away ALL my local changes"

```bash
git restore .                                # discard unstaged changes
git restore --staged .                       # unstage everything
git clean -fd                                # delete untracked files & dirs (be sure!)
git reset --hard origin/main                 # nuclear: match remote main exactly
```

### Force-push safely

`git push --force` overwrites remote history blindly - bad if anyone else has pulled. Use `--force-with-lease`, which refuses if the remote moved since you fetched:

```bash
git push --force-with-lease
```

Never force-push to `main` on a shared repo unless you've coordinated with everyone.

### `--no-verify` warning

`git commit --no-verify` skips pre-commit hooks. If a hook is failing, **fix the underlying issue**. Skipping hooks defeats the point of having them.

---

Back to [template index](../README.md)
