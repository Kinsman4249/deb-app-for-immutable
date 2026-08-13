# The daily git flow

What this covers: when to push straight to `main` versus opening a PR, and the commands for the simple solo flow.

---

## The big question: PR or commit to `main`?

Default rule: **anything you'd be embarrassed to break in front of a stranger goes through a PR.**

| Situation | Direct push to `main` | Open a PR |
|---|:---:|:---:|
| Fixing a typo in README / comments | yes | |
| Adjusting a version number, bumping a comment | yes | |
| Adding a brand-new file with no risk of breakage | yes | |
| Editing CI workflow you wrote five minutes ago | yes | (or PR if you want CI to dry-run it) |
| Refactoring code | | yes |
| Anything touching auth, secrets, network, file system writes | | yes |
| Anything you want CI to verify before it lands | | yes |
| Anything you want a record of *why* you changed it | | yes |
| Working with collaborators | | (always) |
| Solo, but the change spans 3+ files or 50+ lines | | yes |
| You want to think about it overnight before merging | | yes |

For the PR mechanics themselves, see [git-pr-flow.md](./git-pr-flow.md).

### Why bother PR'ing on a solo project?

1. **CI gate** - your tests/linters run before the change reaches `main`, so `main` stays green.
2. **Audit trail** - six months later, "why did I change this?" has a clean answer (the PR description).
3. **Easy revert** - `gh pr revert` undoes the whole PR as one commit. Reverting a direct push to `main` is messier.
4. **Discipline** - separates "I'm working on it" from "this is done."

### When direct-to-`main` is genuinely fine

You're solo, the change is tiny, you tested it locally, and the worst-case outcome is a one-line follow-up commit. Don't ceremony-yourself into paralysis.

---

## The daily flow (solo, low-risk changes)

```bash
# 1. Make sure you're starting from latest main
git switch main
git pull

# 2. Edit files in your editor

# 3. See what changed
git status                                   # which files changed
git diff                                     # what changed in them

# 4. Stage the changes you want to commit
git add path/to/file.md                      # specific file
git add -p                                   # interactively pick hunks (great for review)
git add .                                    # everything in current dir (use with care)

# 5. Commit
git commit -m "docs: fix typo in install steps"

# 6. Push
git push
```

That's it. You're done.

### Conventional commit message style (recommended)

```
<type>(<optional-scope>): <short description>

<optional longer body explaining the why>
```

Common types: `feat` (new feature), `fix` (bug fix), `docs`, `chore` (tooling/deps), `refactor`, `test`, `ci`, `perf`, `style`.

Examples:
```
feat: add cron-driven email digest
fix(installer): handle missing /etc/cron.d gracefully
docs: clarify SMTP2GO setup in README
chore: bump apticron version pin
```

---

Back to [template index](../README.md)
