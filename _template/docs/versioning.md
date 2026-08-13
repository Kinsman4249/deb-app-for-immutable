# Versioning convention (SemVer)

What this covers: the single source of truth for version-number conventions used across tags, releases, and the changelog.

---

`vMAJOR.MINOR.PATCH` (e.g. `v1.2.3`).

- `MAJOR` - incompatible/breaking change
- `MINOR` - new feature, backward compatible
- `PATCH` - bug fix, backward compatible

Pre-1.0? Convention is "anything goes" - many projects use `0.MINOR.PATCH` and break things at minor bumps. After 1.0, take SemVer seriously.

## Quick lookup

| Going from | To | When |
|---|---|---|
| `v0.1.0` | `v0.1.1` | Bug fix only |
| `v0.1.0` | `v0.2.0` | New feature, no breaking changes |
| `v0.x.x` | `v1.0.0` | First "stable" release - public API is now considered final |
| `v1.0.0` | `v2.0.0` | Breaking change - existing users will need to update their code |

Pre-1.0 (`v0.x.x`) is the "I'm still figuring this out" phase. You can break things between minor versions. After 1.0, breaking changes go in major versions only.

Reference: [semver.org](https://semver.org).

---

Back to [template index](../README.md)
