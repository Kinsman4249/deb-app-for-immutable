# deb-app-for-immutable

Run any `.deb` GUI application on immutable Fedora hosts (Bazzite, Silverblue,
Kinoite, and similar) where you can't install `.deb`/`.rpm` packages onto the
base OS.

It installs the `.deb` into a shared Debian **distrobox** container and exports
every desktop entry it ships to the host app grid, so the app opens like a
native application - via `distrobox enter`, automatically starting the container.

It's the natural pair for [vscodium-for-immutable](https://github.com/Kinsman4249/vscodium-for-immutable),
this repo's sibling scoped to a read-only repos directory, which drives podman
directly instead of distrobox.

## Why distrobox here, not scoped podman

The vscodium repo deliberately keeps its container scoped (only a shared repos
directory), because an AI coding agent lives in it. That container also runs
`--privileged` in a shared user namespace and mounts all of `/` at `/run/host`
under its security labels disabled - exactly why it does not run the app grid.
But the scoping costs convenience.

This project deliberately uses distrobox and accepts the wider mount:
distrobox always bind-mounts your whole `$HOME`, mounts all of `/` at
`/run/host`, and disables SELinux confinement - the container can reach the
files and services your user can. That is the right trade for a **trusted** GUI
app that simply doesn't ship for Bazzite and for which convenience (one shared
container, automatic `~/` mount, icon + launcher integration) matters more than
containment. It is the wrong trade for a network-facing agent that can run
code. Install trusted apps you chose here; put agents in the scoped container.

Don't install untrusted or unfamiliar `.deb`s this way - the box is not a
security boundary. Its value is mutability on an immutable OS, not isolation.

## Install

Prerequisites: a Fedora desktop (immutable or not), rootless **podman**, and
**distrobox** (`sudo dnf install distrobox`; Silverblue/Bazzite ship both).

No host install step for this project - clone the repo and run a script. The
container is created on first use (Debian 12 by default).

```
git clone https://github.com/Kinsman4249/deb-app-for-immutable.git
cd deb-app-for-immutable
```

## Usage

Run from a host desktop terminal:

```
./install-deb.sh --target ~/Downloads/splashtop.tar.gz   # tarball bundling a .deb
./install-deb.sh --target ~/Downloads/app.deb             # plain .deb
./install-deb.sh --target "apt install vlc"              # install from Debian apt
./install-deb.sh --target htop                            # bare package name works too
./install-deb.sh --target a.deb --target b.tar.gz         # several apps, one container
./install-deb.sh --target app.deb --name APP              # export one entry only
./uninstall-app.sh --list                                  # query what's installed
./uninstall-app.sh --remove APP                            # unexport + purge that app
./uninstall-app.sh --app APP                               # unexport only (keep pkg)
./uninstall-app.sh --all                                   # unexport + purge everything
./uninstall-app.sh --all --force                           # ... skip the confirmation
distrobox rm deb-apps                                      # remove the whole container
```

`install-deb.sh --target PATH` installs each target's `.deb` into a shared
Debian container and exports the desktop entries it ships to the host app grid.
Each target is auto-detected as a plain `.deb` or a bundled `.tar.gz` (the format
some Debian apps publish in). The `.deb` is installed inside the container with
dependency resolution, under a systemctl shim so packages whose `postinst` calls
`systemctl` still work in the no-systemd box. The container's desktop set is
diffed before/after, hidden entries (`NoDisplay`/`Hidden`) are skipped by
default, and each newly added entry is exported with `distrobox-export`, which
plants a launcher + `.desktop` file on your host (whose `Exec` runs the app via
`distrobox enter`). Icons are re-installed into the host icon theme so they show
up in taskbars/docks, not just the app grid.

A manifest under `~/.config/deb-apps/manifest.tsv` records each exported entry
(package name, desktop base, container), so `uninstall-app.sh` can query and
remove one app atomically without touching the box or the other apps. For
`.deb`/`.tar.gz` targets no downloads happen here - you supply the artifact;
`apt` targets instead pull their packages from the Debian repos inside the box.

`--target` also accepts an apt package instead of a file: `--target "apt
install vlc"` (or a bare package name like `--target htop`) installs it from
the Debian repos inside the box. GUI packages are handled the same way as a
`.deb` (their desktop entries are diffed and exported). If the target turns out
to be terminal-only - a command-line tool with no GUI window, whether it shipped
a `.desktop` (`htop`) or none (`ripgrep`) - `install-deb.sh` instead offers to
run `distrobox-export --bin` on the binaries the packages provide, putting
wrapper commands on your host PATH so you can run them from any terminal
(recorded as `bin:<name>` in the manifest, so `uninstall-app.sh --remove` cleans
them up too). This terminal-only fallback applies to every target kind: `.deb`,
`.tar.gz`, and apt. A `.desktop` is treated as terminal-only only on a positive
signal - `Terminal=true` or a `ConsoleOnly` category - and we still trust the
Exec binary over the metadata: if it links a GUI toolkit (X11/XCB/Wayland/GTK/
Qt/SDL/EGL/GL), we export the launcher rather than downgrade a real GUI app to a
PATH command. Apps already recorded in the manifest are never re-offered.

## Configuration

- Container name and image: `--container NAME` and `--image IMAGE` on
  `install-deb.sh`. The name (default `deb-apps`) is stored in the manifest;
  pass the same `--container` to `uninstall-app.sh`. Multiple containers let
  you keep apps isolated from each other.
- `--name APP` narrows an install to export only the matching desktop entry
  (a filename or extension-less app name), for `.deb`s that ship several
  launchers you don't all want.
- `--gpu` / `--no-gpu` force/disable GPU handling; auto-detection is the
  default (distrobox already shares `/dev/dri`; `--nvidia` is only added at
  container-create time when an NVIDIA device is detected).
- `--wizard` forces instructive prompts when an install is ambiguous
  (a tar with several `.deb`s, multiple visible desktop entries). Without it,
  prompts only fire when stdin is a TTY; in CI (`--non-interactive` or no TTY)
  the script picks the safest default and logs a `Note:` instead of hanging.
- `--app-args "..."` is accepted as a documented passthrough for per-app launch
  flags; the generated launcher does not inject extra args by default.
- `--debug` prints every command; `--help` prints usage.

## Development

Four shell scripts: `install-deb.sh` and `uninstall-app.sh` run on the host,
`lib-auto.sh` is the host-side helper library they source, and
`provision-container.sh` is piped into the container by `install-deb.sh`.
All lint clean with shellcheck (which this repo doesn't vendor; install it
if you want to re-run):

```
bash -n install-deb.sh uninstall-app.sh lib-auto.sh provision-container.sh
shellcheck install-deb.sh uninstall-app.sh lib-auto.sh provision-container.sh
```

End-to-end check against a real `.deb`: run `install-deb.sh` with a small
public `.deb` under a throwaway name (`--container test`), confirm its launcher
appears in `~/.local/share/applications` with an `Exec` line that calls
`distrobox enter test --`, launch it from the app grid, then
`uninstall-app.sh --container test --app <name>` and confirm the launcher and
the container stay clean.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full contribution workflow, and
the Development section above for how to verify a change locally.

## Releases

Push a tag matching `vX.Y.Z` to `main` (`git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`). CI builds and publishes the GitHub Release automatically - nothing else to do.

## License

See [LICENSE](https://github.com/Kinsman4249/deb-app-for-immutable/blob/main/LICENSE).

## Community

- [CONTRIBUTING.md](./CONTRIBUTING.md) - how to report bugs, propose features, and submit changes.
- [SECURITY.md](./SECURITY.md) - how to report a vulnerability.
- [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) - the standards this project holds contributors to.