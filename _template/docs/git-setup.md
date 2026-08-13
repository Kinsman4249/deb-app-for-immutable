# Git and GitHub one-time setup

What this covers: the one-time machine setup needed before you use git and the `gh` CLI day to day.

---

## Identify yourself to git

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Use the same email that's set on your GitHub account so commits link to your profile.

## Sensible defaults

```bash
git config --global init.defaultBranch main
git config --global pull.rebase false       # merge on pull (simpler for noobs)
git config --global core.autocrlf input     # macOS/Linux; use 'true' on Windows
git config --global push.autoSetupRemote true
```

## Authenticate the GitHub CLI

```bash
gh auth login
# Pick: GitHub.com -> HTTPS -> "Login with a web browser"
# Authorize in browser. Done.

gh auth status                               # verify
```

The `gh` CLI uses this auth for every command referenced in these docs - including `gh pr`, `gh release`, etc.

## Clone a repo

```bash
gh repo clone Kinsman4249/morning-email-security
# or
git clone https://github.com/Kinsman4249/morning-email-security.git
```

---

Back to [template index](../README.md)
