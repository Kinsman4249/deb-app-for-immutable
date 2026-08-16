#!/usr/bin/env bash
#
# dbx-app-for-immutable: installer for .deb GUI apps on immutable Fedora hosts.
#
# How it works: immutable Fedora (Bazzite, Silverblue, Kinoite, and similar)
# keeps the base OS read-only, so you cannot `apt`/`dnf install` a .deb desktop
# app onto it. This script instead:
#
#   1. ensures a shared Debian distrobox container exists (named "deb-apps" by
#      default, reused across apps);
#   2. copies the .deb into a staging directory under $HOME (distrobox mounts
#      host $HOME at the same path inside the container, so the container can
#      reach it);
#   3. installs the .deb inside the container, resolving dependencies;
#   4. finds every .desktop entry the package added under /usr/share/applications,
#      and runs `distrobox-export --app` for each one. That writes a launcher +
#      .desktop entry onto the HOST that runs the app via `distrobox enter`, so
#      the app shows up in your app grid and opens like a native app.
#
# This is the distrobox-based design (as opposed to this repo's sibling
# vscodium-for-immutable, which drives podman directly for scoped file access).
# Distrobox is convenient - one shared container, automatic ~/ mount, host app
# integration via distrobox-export - but it is NOT scoped: the container sees
# your whole home and host filesystem. That is the tradeoff. See README.md.
#
# Run this from a HOST terminal (a real desktop session), not from inside a
# container.
#
# Usage:
#   ./install-deb.sh path/to/app.deb              install the app and export it
#   ./install-deb.sh --deb path/app.deb           same, explicit flag
#   ./install-deb.sh --container NAME             container to use (default deb-apps)
#   ./install-deb.sh --image IMAGE                image for a new container (default debian:12)
#   ./install-deb.sh --name APP                   export only the matching desktop
#                                                  entry (by filename) instead of all
#   ./install-deb.sh --debug                      print every command run
#   ./install-deb.sh --help                       show this help
#
# To remove an app, run ./uninstall-app.sh instead.
#
set -euo pipefail

# Bump whenever the script's install logic changes. Only shown in --debug, so
# you can tell which version produced a given log.
BUILD="2026.08.16-1"

CONTAINER_NAME="deb-apps"
CONTAINER_IMAGE="debian:12"
APP_FILTER=""
DEBUG=0
DEB=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVISION_SCRIPT="${SCRIPT_DIR}/provision-container.sh"

# distrobox mounts the host's $HOME at the same absolute path inside the
# container, so anything staged under $HOME is visible to it at an identical
# path. That is why the .deb is copied into .local/state rather than looked up
# at its original location - the original might be outside $HOME entirely.
STAGE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/${CONTAINER_NAME}/stage"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${CONTAINER_NAME}"
# State file listing each desktop entry this project has exported, so
# uninstall-app.sh can remove exactly what this script created.
EXPORTED_FILE="${CONFIG_DIR}/exported"

die() {
  echo "Error: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --debug)
      DEBUG=1
      shift
      ;;
    --deb)
      DEB="${2:-}"
      [ -n "$DEB" ] || die "--deb requires a path to a .deb file."
      shift 2
      ;;
    --deb=*)
      DEB="${1#*=}"
      shift
      ;;
    --container)
      CONTAINER_NAME="${2:-}"
      [ -n "$CONTAINER_NAME" ] || die "--container requires a name."
      shift 2
      ;;
    --container=*)
      CONTAINER_NAME="${1#*=}"
      shift
      ;;
    --image)
      CONTAINER_IMAGE="${2:-}"
      [ -n "$CONTAINER_IMAGE" ] || die "--image requires an image name."
      shift 2
      ;;
    --image=*)
      CONTAINER_IMAGE="${1#*=}"
      shift
      ;;
    --name)
      APP_FILTER="${2:-}"
      [ -n "$APP_FILTER" ] || die "--name requires a desktop filename."
      shift 2
      ;;
    --name=*)
      APP_FILTER="${1#*=}"
      shift
      ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      # Positional arg: a bare path to the .deb.
      if [ -z "$DEB" ]; then
        DEB="$1"
        shift
      else
        die "Unknown option or extra argument: $1 (use --help)"
      fi
      ;;
  esac
done

if [ "$DEBUG" -eq 1 ]; then
  echo "[debug] install-deb.sh build $BUILD (container=$CONTAINER_NAME)"
  set -x
fi

require_host() {
  # Inside a container there is no usable host app grid to export into, and
  # /run/.containerenv is the marker podman/distrobox sets. Catch it early.
  if [ -f /run/.containerenv ] || [ -f /.dockerenv ] || [ -n "${container:-}" ]; then
    die "this looks like it's running inside a container. Run it from a host desktop session instead."
  fi
  command -v distrobox >/dev/null 2>&1 \
    || die "distrobox is not installed or not on PATH. https://distrobox.it/"
  command -v podman >/dev/null 2>&1 \
    || die "podman is not installed or not on PATH. https://podman.io/docs/installation"
  [ -f "$PROVISION_SCRIPT" ] \
    || die "provision-container.sh not found next to this script (looked in $SCRIPT_DIR)."
}

container_exists() {
  # distrobox list prints one container per line, first column is the name.
  distrobox list 2>/dev/null | awk '{print $1}' | grep -qx "$CONTAINER_NAME"
}

# Ensures the shared container exists, creating it if needed. --additional-packages
# makes gdebi-core + sudo available from the first boot, so the provision step
# below only has to install the .deb and its dependencies.
ensure_container() {
  if container_exists; then
    return
  fi
  echo "Creating container '$CONTAINER_NAME' from $CONTAINER_IMAGE..."
  distrobox create \
    --name "$CONTAINER_NAME" \
    --image "$CONTAINER_IMAGE" \
    --yes \
    --additional-packages "sudo ca-certificates gdebi-core" \
    || die "distrobox create failed. See distrobox's error above."
  # First boot pulls the image and runs distrobox-init; a simple enter primes it
  # so the provision step below starts from a fully initialised container.
  distrobox enter "$CONTAINER_NAME" -- true >/dev/null 2>&1 \
    || die "container '$CONTAINER_NAME' did not start. See distrobox's error above."
}

# Copies the given .deb into the staging dir and echoes its path. The copy is
# what the container installs; the original is left untouched.
stage_deb() {
  local src="$1" base staged
  [ -f "$src" ] || die "not a file: $src"
  case "$src" in
    *:*|*,*) die "path must not contain ':' or ',': $src" ;;
  esac
  mkdir -p "$STAGE_DIR"
  base="$(basename "$src")"
  staged="$STAGE_DIR/${base}"
  if [ "$(realpath -e "$src")" != "$(realpath -e "$staged")" ]; then
    cp -f "$src" "$staged"
  fi
  realpath -e "$staged"
}

# Lists the base names of every *.desktop file visible in the container, in the
# locations distrobox-export scans. One per line. The single-quoted sh script is
# intentional: $HOME must expand inside the container, not on the host.
# shellcheck disable=SC2016
list_desktops() {
  distrobox enter "$CONTAINER_NAME" -- \
    sh -c 'ls -1 /usr/share/applications/*.desktop "$HOME"/.local/share/applications/*.desktop 2>/dev/null \
           | xargs -r -n1 basename | sort -u'
}

install_deb() {
  local staged="$1"
  echo "Installing $(basename "$staged") inside $CONTAINER_NAME (this pulls dependencies)..."
  # provision-container.sh expects the container path to the .deb as argv[1].
  # BOX_DEBUG is inherited by distrobox enter, so the piped script can honour
  # this run's --debug.
  export BOX_DEBUG="$DEBUG"
  distrobox enter "$CONTAINER_NAME" -- bash -s -- "$staged" < "$PROVISION_SCRIPT"
}

# Exports every desktop entry the .deb added (all entries present in the
# container that were not there before this run, unless --name narrowed it) onto
# the host app grid via distrobox-export. Appends each exported filename to the
# state file.
export_new() {
  local before after base export_name desktop_path home_path
  # Capture entries present before install, so only what the .deb added is
  # exported rather than the container image's own entries.
  before="$(mktemp)"
  after="$(mktemp)"
  list_desktops > "$before"
  install_deb "$1"
  list_desktops > "$after"

  mkdir -p "$CONFIG_DIR"

  while IFS= read -r base; do
    [ -n "$base" ] || continue
    # Skip entries that existed before this install - they are not from this .deb.
    grep -qxF "$base" "$before" && continue
    desktop_path=""
    # Tell distrobox-export exactly which file to export so it does not have to
    # guess which location held it.
    if distrobox enter "$CONTAINER_NAME" -- test -f "/usr/share/applications/$base"; then
      desktop_path="/usr/share/applications/$base"
    elif distrobox enter "$CONTAINER_NAME" -- \
        test -f "\$HOME/.local/share/applications/$base"; then
      home_path="$(distrobox enter "$CONTAINER_NAME" -- printf '%s' "\$HOME/.local/share/applications/$base")"
      desktop_path="$home_path"
    else
      echo "Note: could not locate $base in the container - skipping."
      continue
    fi
    export_name="${base%.desktop}"
    if [ -n "$APP_FILTER" ] && [ "$export_name" != "$APP_FILTER" ] \
       && [ "$base" != "$APP_FILTER" ]; then
      continue
    fi
    echo "Exporting $base to the host app grid..."
    # Run inside the container: distrobox-export writes the host launcher +
    # .desktop entry and copies the icon out itself.
    distrobox enter "$CONTAINER_NAME" -- distrobox-export \
      --app "$export_name" --desktop-file "$desktop_path" \
      || echo "Warning: could not export $export_name. See distrobox's error above."
    printf '%s\n' "$base" >> "$EXPORTED_FILE"
  done < <(sort -u "$after")

  rm -f "$before" "$after"
}

refresh_desktop_db() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

do_install() {
  local staged
  require_host

  [ -n "$DEB" ] || die "no .deb given. Pass it as an argument or --deb PATH."
  staged="$(stage_deb "$DEB")"

  ensure_container

  if [ -n "$APP_FILTER" ]; then
    echo "Narrowed --name given: exporting only entries matching '$APP_FILTER'."
  fi
  export_new "$staged"

  refresh_desktop_db

  echo
  echo "Done. Installed $(basename "$DEB") into '$CONTAINER_NAME' and exported its"
  echo "desktop entries to the host app menu. Launch them like any native app -"
  echo "they open the app via 'distrobox enter $CONTAINER_NAME -- ...'."
  echo "Re-run this script with another .deb to add more apps to the same container,"
  echo "or run ./uninstall-app.sh to remove exported launchers."
}

do_install