# The PR flow

What this covers: branching, opening a PR, and the `gh pr` commands for everything that isn't a tiny solo change. See [git-daily-flow.md](./git-daily-flow.md) for when a PR is warranted at all.

---

## The PR flow (everything else)

```bash
# 1. Start fresh from main
git switch main
git pull

# 2. Create a feature branch (use a short kebab-case description)
git switch -c feat/digest-html-output

# 3. Work normally, edit, add, commit (multiple commits OK on a branch)
# ... edit, add, commit ...

# 4. Push the branch to GitHub
git push                                     # works because of push.autoSetupRemote

# 5. Open the PR
gh pr create --fill                          # uses your last commit message as title/body
# or, with explicit fields:
gh pr create --title "feat: HTML digest output" \
             --body "Adds an --html flag to setup-cve-alerts.sh." \
             --base main

# 6. Watch CI
gh pr checks --watch                         # blocks until checks finish

# 7. (Optional) Address review feedback
# ... edit, add, commit ...
git push                                     # pushes new commits to the same PR

# 8. Merge
gh pr merge --squash --delete-branch         # see git-merging.md for strategy choice

# 9. Sync local main and tidy up
git switch main
git pull
git branch -d feat/digest-html-output        # local branch (already deleted on remote)
```

### Branch naming conventions

| Prefix | When |
|---|---|
| `feat/<thing>` | new feature or capability |
| `fix/<thing>` | bug fix |
| `docs/<thing>` | documentation only |
| `chore/<thing>` | tooling, deps, CI, refactor with no behavior change |
| `release/<version>` | release-prep branches (rare for solo work) |

---

## Pull request commands (`gh` CLI)

```bash
# Create
gh pr create                                 # interactive
gh pr create --fill                          # auto-fill title/body from commits
gh pr create --draft                         # mark as draft (no review pings)
gh pr create --web                           # open web UI to compose

# View
gh pr list                                   # PRs in current repo
gh pr list --author "@me"
gh pr list --state open
gh pr view                                   # current branch's PR
gh pr view 42                                # specific PR number
gh pr view 42 --web                          # open in browser
gh pr diff 42                                # full diff
gh pr checks 42                              # CI status

# Work with someone else's PR
gh pr checkout 42                            # check out PR #42 locally
gh pr review 42 --approve --body "LGTM"
gh pr review 42 --request-changes --body "..."
gh pr review 42 --comment --body "..."

# Update your own PR
git push                                     # adds new commits to existing PR
gh pr edit 42 --title "new title"
gh pr edit 42 --add-label "needs-tests"
gh pr ready                                  # promote draft PR to ready-for-review
gh pr ready --undo                           # back to draft

# Merge
gh pr merge --squash --delete-branch         # most common
gh pr merge --merge                          # preserve commits as merge commit
gh pr merge --rebase                         # linear history
gh pr merge --auto --squash                  # auto-merge once checks pass

# Close without merging
gh pr close 42 --comment "superseded by #57"

# Revert a merged PR
gh pr revert 42                              # opens a "revert PR"
```

---

Back to [template index](../README.md)
