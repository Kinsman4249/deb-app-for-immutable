#!/usr/bin/env bash
#
# Removes an app installed by install-deb.sh.
#
# What it removes:
#   - the exported host launcher + .desktop entry for the app (via
#     distrobox-export --delete), so it leaves the host app grid;
#   - the deb package itself inside the container, if --package NAME is given
#     (otherwise the .deb stays installed, just unexported - default).
#
# The container itself is left in place so other installed apps keep working.
# To tear down the whole container instead, run `distrobox rm deb-apps` and
# `./uninstall-app.sh --all`-style cleanup is intentionally not automatic.
#
# Usage:
#   ./uninstall-app.sh --app NAME            unexport an app by desktop filename
#                                             or app name (e.g. splashtop)
#   ./uninstall-app.sh --package PKG         also `apt-get remove` PKG in the container
#   ./uninstall-app.sh --container NAME      container to act on (default deb-apps)
#   ./uninstall-app.sh --list                list apps this project has exported
#   ./uninstall-app.sh --debug               print every command run
#   ./uninstall-app.sh --help                show this help
#
set -euo pipefail

BUILD="2026.08.16-1"

CONTAINER_NAME="deb-apps"
APP_NAME=""
PACKAGE=""
DO_LIST=0
DEBUG=0

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${CONTAINER_NAME}"
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
    --app)
      APP_NAME="${2:-}"
      [ -n "$APP_NAME" ] || die "--app requires a name."
      shift 2
      ;;
    --app=*)
      APP_NAME="${1#*=}"
      shift
      ;;
    --package)
      PACKAGE="${2:-}"
      [ -n "$PACKAGE" ] || die "--package requires a package name."
      shift 2
      ;;
    --package=*)
      PACKAGE="${1#*=}"
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
    --list)
      DO_LIST=1
      shift
      ;;
    -h|--help)
      sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      die "Unknown option: $1 (use --help)"
      ;;
  esac
done

if [ "$DEBUG" -eq 1 ]; then
  echo "[debug] uninstall-app.sh build $BUILD (container=$CONTAINER_NAME)"
  set -x
fi

require_host() {
  if [ -f /run/.containerenv ] || [ -f /.dockerenv ] || [ -n "${container:-}" ]; then
    die "this looks like it's running inside a container. Run it from a host terminal instead."
  fi
  command -v distrobox >/dev/null 2>&1 \
    || die "distrobox is not installed or not on PATH."
}

container_exists() {
  distrobox list 2>/dev/null | awk '{print $1}' | grep -qx "$CONTAINER_NAME"
}

list_exported() {
  if [ -f "$EXPORTED_FILE" ]; then
    sort -u "$EXPORTED_FILE"
  fi
}

do_unexport() {
  local name="${1%.desktop}"
  # Tell distrobox-export exactly which .desktop file to drop from the host.
  # If it is not present in the container there is nothing else to unexport, but
  # a stale host entry may still exist - so also remove any planted launcher.
  if distrobox enter "$CONTAINER_NAME" -- \
      test -f "/usr/share/applications/${name}.desktop"; then
    distrobox enter "$CONTAINER_NAME" -- distrobox-export \
      --app "$name" --desktop-file "/usr/share/applications/${name}.desktop" --delete
  elif distrobox enter "$CONTAINER_NAME" -- \
      test -f "\$HOME/.local/share/applications/${name}.desktop"; then
    local home_path
    home_path="$(distrobox enter "$CONTAINER_NAME" -- printf '%s' "\$HOME/.local/share/applications/${name}.desktop")"
    distrobox enter "$CONTAINER_NAME" -- distrobox-export \
      --app "$name" --desktop-file "$home_path" --delete
  else
    echo "Note: ${name}.desktop not found in the container - removing any stale host launcher."
    rm -f "$HOME/.local/bin/${name}" \
      "$HOME/.local/share/applications/${name}.desktop"
  fi
  # Drop it from the state file so a later --list is accurate.
  local tmp
  tmp="$(mktemp)"
  grep -vxF "${name}.desktop" "$EXPORTED_FILE" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$EXPORTED_FILE" 2>/dev/null || rm -f "$EXPORTED_FILE"
}

do_purge() {
  echo "Removing package '$PACKAGE' inside $CONTAINER_NAME..."
  distrobox enter "$CONTAINER_NAME" -- sudo apt-get remove -y "$PACKAGE" \
    || echo "Warning: apt remove reported a problem (it may not be installed)."
}

refresh_desktop_db() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  fi
}

if [ "$DO_LIST" -eq 1 ]; then
  require_host
  echo "Apps exported by $CONTAINER_NAME (from $EXPORTED_FILE):"
  if [ -s "$EXPORTED_FILE" ]; then
    list_exported
  else
    echo "  (none recorded)"
  fi
  exit 0
fi

if [ -z "$APP_NAME" ] && [ -z "$PACKAGE" ]; then
  die "nothing to do. Pass --app NAME and/or --package PKG, or --list."
fi

require_host
container_exists || die "container '$CONTAINER_NAME' does not exist. Nothing to uninstall."

if [ -n "$APP_NAME" ]; then
  do_unexport "$APP_NAME"
fi
if [ -n "$PACKAGE" ]; then
  do_purge
fi

refresh_desktop_db
echo "Done."

# If the state file is now empty, there is nothing left this project manages;
# hint at how to drop the container itself.
if [ ! -s "$EXPORTED_FILE" ]; then
  echo "No exported launchers remain for '$CONTAINER_NAME'. To remove the container"
  echo "itself, run:  distrobox rm $CONTAINER_NAME"
fi