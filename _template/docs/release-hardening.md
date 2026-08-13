# Release workflow hardening notes

What this covers: the security and reliability rationale behind `release.yml`'s defaults - why they're set the way they are, and what to change (or not) if you maintain the repo actively.

---

## Permissions

Base workflow permissions are set to read-only (`contents: read`) at the top level, so untrusted dependencies pulled in during the build job can't abuse the token. Two jobs elevate to `contents: write` in their own scoped blocks: `prepare`, which commits stamped release metadata and moves the tag, and `release`, which publishes the Release. The `build` job - the one that runs third-party toolchains and your dependencies - stays read-only.

## Concurrency

A `concurrency` group keyed on the tag prevents two release runs for the same tag from racing - for example, a re-pushed tag while the first run is still publishing. `cancel-in-progress: false` is deliberate: an in-flight publish should finish, not be killed mid-upload.

## SHA-pinning: intentionally off by default

`uses:` lines are pinned to version tags (e.g. `@v7`), not commit SHAs, on purpose. Do not auto-pin or run `pinact` on this workflow without asking the maintainer first.

Reason: pinned SHAs require ongoing maintenance - a Dependabot bump PR every time an action releases a fix. On a plain copied template with no such upkeep, pins rot into unpatched dependencies, so leaving clean version tags is the safer default here. If you do want to pin, [pinact](https://github.com/suzuki-shunsuke/pinact) rewrites every `uses:` tag to a full SHA in one pass - pair it with a `.github/dependabot.yml` (`github-actions` ecosystem) so the pins stay current, and only do this on a repo you'll actually keep patched.

---

Back to [template index](../README.md)
