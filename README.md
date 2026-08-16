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
./install-deb.sh ~/Downloads/splashtop.deb      # install .deb + export its apps
./install-deb.sh --name splashtop ~/Downloads/splashtop.deb   # export one entry only
./uninstall-app.sh --app splashtop              # remove an app's host launcher
./uninstall-app.sh --list                        # what has been exported
./uninstall-app.sh --package deb-name           # also apt-remove the package
distrobox rm deb-apps                            # remove the whole container
```

`install-deb.sh` copies the `.deb` into a staging dir under `~/.local/state`,
installs it inside the container (resolving dependencies with `gdebi`), diffs
the container's `/usr/share/applications` before/after, and runs
`distrobox-export --app` for each newly added entry. That writes a launcher and
`.desktop` file to your host `~/.local/share/applications` whose `Exec` line
runs `distrobox enter deb-apps -- <app>`, so the app appears in the app grid
and opens like a native app. A state file under `~/.config/deb-apps/exported`
tracks what the project created so `uninstall-app.sh` can remove exactly that.

## Configuration

- Container name and image: `--container NAME` and `--image IMAGE` on
  `install-deb.sh`. The name (default `deb-apps`) is stored per-run; pass the
  same `--container` to `uninstall-app.sh`. Multiple containers let you keep
  apps isolated from each other.
- `--name APP` narrows an install to export only the matching desktop entry
  (a filename or extension-less app name), for `.deb`s that ship several
  launchers you don't all want.
- `--debug` prints every command; `--help` prints usage.

## Development

Three shell scripts: `install-deb.sh` and `uninstall-app.sh` run on the host,
and `provision-container.sh` is piped into the container by `install-deb.sh`.
All lint clean with shellcheck (which this repo doesn't vendor; install it
if you want to re-run):

```
bash -n install-deb.sh provision-container.sh uninstall-app.sh
shellcheck install-deb.sh provision-container.sh uninstall-app.sh
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