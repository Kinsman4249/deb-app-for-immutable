# Customizing the build matrix and language blocks

What this covers: trimming the OS matrix and adding a compiled build for your language, on top of the default source bundle described in [release-workflow.md](./release-workflow.md).

---

## Customizing the build matrix

The workflow builds on Ubuntu, macOS, and Windows by default. If your project only needs Linux (most shell scripts, Cloudflare Workers, Docker images, etc.), trim the matrix:

```yaml
matrix:
  os: [ubuntu-latest]
```

That cuts your build minutes by 3x, and is also required for languages whose output is identical across OSes (see the per-language notes below) - without trimming, the release step fails once two matrix legs try to upload a file with the same name.

## Adding a compiled build

The source bundle (`.tar.gz` + `.zip` of the tagged tree) always runs and needs no edits. Uncommenting a language block adds a compiled build alongside it - you don't need to remove the bundle step. `release.yml` ships with six blocks, each split into a toolchain-setup step and a build step:

- **Go** - `actions/setup-go`, then `go build`. Replace the binary name and main package path.
- **Node / TypeScript** - `actions/setup-node`, then `npm ci && npm run build`, packaged into a `.tar.gz`.
- **Python** - `actions/setup-python`, then `python -m build` to produce a wheel and sdist. Wheel/sdist filenames are fixed by PEP 427/440 and must not be renamed; since they're OS-agnostic, trim the matrix to `[ubuntu-latest]` for a pure-Python package.
- **Rust** - `dtolnay/rust-toolchain`, then `cargo build --release`. Replace the binary name to match `Cargo.toml`.
- **Java (Gradle)** - `actions/setup-java`, then `./gradlew build`. A plain JAR is identical across OS runners; either keep the per-OS naming loop or trim the matrix to `[ubuntu-latest]` and drop it.
- **Shell / no build** - no separate block needed. The default source bundle already covers this case.

Uncomment only the blocks matching your language; adjust binary names, package paths, or build commands as needed for your project.

---

Back to [template index](../README.md)
