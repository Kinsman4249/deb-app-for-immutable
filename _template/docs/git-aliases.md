# Useful aliases and the summary card

What this covers: time-saving git and `gh` aliases, plus a two-minute cheat-sheet card for the whole flow.

---

## Useful aliases

Add to `~/.gitconfig`:

```ini
[alias]
    s = status -sb
    co = checkout
    sw = switch
    cm = commit -m
    ca = commit --amend --no-edit
    last = log -1 --stat
    lg = log --oneline --graph --decorate -20
    unstage = restore --staged
    discard = restore
    pf = push --force-with-lease
    sync = !git switch main && git pull && git branch --merged | grep -v '^\\*\\| main$' | xargs -r git branch -d
```

Or set them with commands:

```bash
git config --global alias.s "status -sb"
git config --global alias.lg "log --oneline --graph --decorate -20"
```

### `gh` aliases worth knowing

```bash
gh alias set prc 'pr create --fill'
gh alias set prv 'pr view --web'
gh alias set prm 'pr merge --squash --delete-branch'
```

Then: `gh prc`, `gh prv`, `gh prm`.

---

## The 2-minute summary card

```
SOLO + TINY CHANGE                             ANYTHING ELSE
===================                            =============
git switch main                                git switch main
git pull                                        git pull
# edit files                                    git switch -c feat/thing
git add -p                                      # edit, add, commit ...
git commit -m "type: msg"                       git push
git push                                        gh pr create --fill
                                                 gh pr checks --watch
                                                 gh pr merge --squash --delete-branch
                                                 git switch main && git pull

RELEASE
=======
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
# (CI auto-creates the GitHub Release)
```

---

Back to [template index](../README.md)
