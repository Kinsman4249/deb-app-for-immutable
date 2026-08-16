# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Added `install-deb.sh`: a host-side installer that installs any `.deb` GUI
  app into a shared Debian distrobox container (`deb-apps` by default) and
  exports every desktop entry it ships to the host app grid via
  `distrobox-export`. The container is created on first use (Debian 12, with
  `gdebi-core` and `sudo`), the `.deb` is staged under `~/.local/state` (so
  distrobox's `$HOME` mount makes it reachable), dependencies are resolved, and
  the set of `/usr/share/applications` entries present before the install is
  diffed against after so only what the package actually added gets exported.
  Adds a `~/.config/deb-apps/exported` state file so the project can uninstall
  exactly what it created. Supports `--container`, `--image`, `--name`
  (narrow export to one entry), `--debug`, and `--help`.
- Added `provision-container.sh`: the container-side routine piped into the box
  by `install-deb.sh`; installs the `.deb` with `gdebi --non-interactive`
  (falling back to `apt-get install` if passwordless sudo is unavailable).
- Added `uninstall-app.sh`: removes an app's exported host launcher/`.desktop`
  entry via `distrobox-export --delete`, optionally `apt-get remove`s the
  package inside the container, and lists what this project has exported
  (`--list`). Supports `--container`, `--app`, `--package`, `--debug`, `--help`.
- Filled in the template README stub with real install/usage/configuration/
  development docs for the `deb-app-for-immutable` tool, including an explicit
  "why distrobox here, not scoped podman" section contrasting this project with
  its `vscodium-for-immutable` sibling.

### Changed

### Deprecated

### Removed

### Fixed

### Security