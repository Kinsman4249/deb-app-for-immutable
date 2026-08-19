# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] - 2026-08-18

### Added

- `install-deb.sh --target "apt install vlc"` (or a bare package name like `--target htop`) now installs a package from the Debian apt repos directly inside the box, so the target no longer has to be a local `.deb`/`.tar.gz`. It goes through the same `provision-container.sh` pipeline (systemctl shim, apt-get install, desktop diff and export).
- Terminal-only targets - a command-line tool with no GUI window, whether it shipped a `.desktop` (`htop`) or none (`ripgrep`) - are now offered a `distrobox-export --bin` host PATH export instead of a desktop launcher. `lib-auto.sh` lists every executable the target's packages own under `/usr/bin`/`/usr/sbin` and, on a `y` prompt (subject to `--wizard`/`--non-interactive`), exports each so you can run it from any host terminal. These are recorded in the manifest as `bin:<name>` and are cleaned up by `uninstall-app.sh`. The fallback now applies to every target kind (`.deb`, `.tar.gz`, apt), not just apt packages.
- Terminal-only detection now matches the spirit, not the letter: a `.desktop` is classified terminal-only only on a positive signal (`Terminal=true` or a `ConsoleOnly` category), and only when its Exec binary links no GUI toolkit (X11/XCB/Wayland/GTK/Qt/SDL/EGL/GL) - so a flagged-but-GUI app still exports its launcher, and an app already recorded in the manifest is never re-offered a PATH export.
- `uninstall-app.sh --list` / `--query` now shows every recorded app grouped by package (desktop entries and `bin:` PATH exports), so you can see what's installed and remove by app or package name.
- `uninstall-app.sh --all` now unexports and purges every app recorded for the container in one pass, deduplicating packages so each is purged once. It prompts for confirmation on a TTY and aborts in non-interactive runs; `--force` skips the prompt.

## [1.0.0] - 2026-08-18

### Added

- Added `install-deb.sh`: a host-side installer that runs any `.deb` GUI app on an immutable Fedora host (Bazzite, Silverblue, Kinoite, and similar). It creates a shared Debian distrobox container (`deb-apps` by default, Debian 12, with `gdebi-core` and `sudo`) on first use, stages each supplied `.deb` under `~/.local/state` so the container's `$HOME` mount reaches it, installs it with dependency resolution, diffs the container's desktop entries before and after, and exports each newly added visible entry to the host app grid with `distrobox-export`. Targets are auto-detected as a plain `.deb` or a `.tar.gz` that bundles one. Supports `--container`, `--image`, `--name` (narrow the export to one entry), `--gpu`/`--no-gpu`, `--wizard`, `--non-interactive`, `--app-args`, `--debug`, and `--help`.
- Added `provision-container.sh`: the container-side routine piped into the box by `install-deb.sh`. It applies a `dpkg-divert` systemctl shim so `.deb`s whose `postinst` calls `systemctl` install cleanly in the no-systemd container, installs the package with `gdebi --non-interactive` (falling back to `apt-get install` when passwordless sudo is unavailable), repairs missing runtime libraries by installing Debian-convention provider packages, and emits a machine-parseable facts block (package, shim usage, desktop entries) for the host side.
- Added `uninstall-app.sh`: removes an app by unexporting its host launcher and `.desktop` entry via `distrobox-export --delete` and optionally purging the package inside the container under the same systemctl shim. `--list`/`--query` shows what the project has installed. Supports `--remove`, `--app` (unexport only, keep the package), `--container`, `--debug`, and `--help`.
- Added `lib-auto.sh`: the host-side helper library sourced by the install/uninstall scripts. It handles target classification and tarball bundling, container creation with GPU detection (NVIDIA-aware, plus `/dev/dri` detection), desktop discovery and filtering of hidden entries, icon re-installation into the hicolor theme, and the manifest under `~/.config/deb-apps/manifest.tsv` that records each exported entry (desktop file, package, container). Prompts fire only with a TTY, `--wizard`, or `--non-interactive` resets them to safe defaults in CI.
- Added an ASCII-only lint workflow (`lint-ascii.yml`) that fails if any tracked Markdown file contains em dashes, smart quotes, or emoji.
- Added a release workflow (`release.yml`) that builds `.tar.gz` and `.zip` source archives of a pushed `vX.Y.Z` tag and publishes a GitHub Release with the archives attached, plus a manual `workflow_dispatch` fallback and BSL change-date stamping.
- Added the README, CONTRIBUTING, CODE_OF_CONDUCT, and SECURITY documents, along with bug report and feature request templates and a pull request template.