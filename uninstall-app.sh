#!/usr/bin/env bash
#
# Removes an app installed by install-deb.sh and queries what's installed.
#
# install-deb.sh records each exported desktop entry in a manifest
# (~/.config/deb-apps/manifest.tsv, one tab-separated row per entry:
# desktop_base<TAB>package_name<TAB>container). This script reads that manifest
# so it can query the installed apps and remove one app atomically without
# touching the shared container or the other apps in it.
#
# Usage:
#   ./uninstall-app.sh --list                  query: show every installed app
#   ./uninstall-app.sh --query                 (same as --list)
#   ./uninstall-app.sh --remove APP            default: unexport + purge that app
#   ./uninstall-app.sh --app NAME              unexport only (leave package)
#   ./uninstall-app.sh --container NAME        container to act on (default deb-apps)
#   ./uninstall-app.sh --debug                 print every command run
#   ./uninstall-app.sh --help                  show this help
#
set -euo pipefail

BUILD="2026.08.17-1"

DO_LIST=0
DO_REMOVE=""
APP_NAME=""
DEBUG=0

# Source the shared host-side library for CONTAINER_NAME/CONFIG_DIR/manifest
# paths + the systemctl-aware purge shim derivation.
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-auto.sh"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --debug)
      DEBUG=1
      shift
      ;;
    --list|--query)
      DO_LIST=1
      shift
      ;;
    --remove)
      DO_REMOVE="${2:-}"
      [ -n "$DO_REMOVE" ] || die "--remove requires an app name or package name."
      shift 2
      ;;
    --app)
      APP_NAME="${2:-}"
      [ -n "$APP_NAME" ] || die "--app requires a name."
      shift 2
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
    -h|--help)
      usage
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

require_host

# --- Manifest helpers ------------------------------------------------------

manifest_exists() {
  [ -s "$MANIFEST" ]
}

# rows APP -> prints "desktop_base<TAB>container" for every row matching APP by
# package name OR desktop stem (codium, codium.desktop, splashtop-business...).
rows() {
  local app="$1" base pkg ctn
  [ "$DO_LIST" -eq 1 ] && return 0
  while IFS=$'\t' read -r base pkg ctn; do
    [ -n "$base" ] || continue
    if [ "$pkg" = "$app" ] || [ "${base%.desktop}" = "${app%.desktop}" ] \
       || [ "$base" = "$app" ]; then
      printf '%s\t%s\n' "$base" "$ctn"
    fi
  done < "$MANIFEST"
}

# --- Query ----------------------------------------------------------------

list_apps() {
  local base pkg ctn current=""
  if ! manifest_exists; then
    echo "Nothing installed yet (no manifest at $MANIFEST)."
    return 0
  fi
  echo "Apps installed via $CONTAINER_NAME:"
  while IFS=$'\t' read -r base pkg ctn; do
    [ -n "$base" ] || continue
    if [ "$pkg" != "$current" ]; then
      current="$pkg"
      echo
      printf '  %s (container: %s)\n' "$pkg" "$ctn"
    fi
    printf '    - %s\n' "$base"
  done < <(sort -u "$MANIFEST")
  echo
  echo "Remove one with: ./uninstall-app.sh --remove <app-or-package>"
  echo "To remove the whole container: distrobox rm $CONTAINER_NAME"
}

# --- Unexport -------------------------------------------------------------

do_unexport() {
  local base="$1" name="${1%.desktop}" desktop_path
  desktop_path="$(locate_desktop "$base" 2>/dev/null || true)"
  if [ -n "$desktop_path" ]; then
    distrobox enter "$CONTAINER_NAME" -- distrobox-export \
      --app "$desktop_path" --delete \
      || echo "Warning: could not unexport $name. See distrobox's error above."
  else
    echo "Note: $base not found in the container - removing any stale host launcher."
    rm -f "$HOME/.local/bin/${name}" \
      "$HOME/.local/share/applications/${name}.desktop" \
      "${HOST_APPS_DIR}/$(export_label)-${name}.desktop" 2>/dev/null || true
  fi
  rm -f "$HOME/.local/share/icons/${name}.png" \
    "${HOST_APPS_DIR}/$(export_label)-${name}.desktop" 2>/dev/null || true
}

# do_unexport_by_app APP: unexport every manifest entry matching APP (no purge).
do_unexport_by_app() {
  local app="$1" base ctn
  while IFS=$'\t' read -r base ctn; do
    [ -n "$base" ] || continue
    do_unexport "$base"
  done < <(rows "$app") || true
}

# --- Purge under the systemctl shim ---------------------------------------
#
# A package's prerm/postrm can call `systemctl`, which fails in the no-systemd
# box just like an install's postinst does - so purge runs under the same
# dpkg-divert shim that provision-container.sh uses, via a tiny piped script.
purge_package() {
  local pkg="$1"
  echo "Purging package '$pkg' inside $CONTAINER_NAME (with systemctl shim)..."
  export BOX_DEBUG="$DEBUG"
  distrobox enter "$CONTAINER_NAME" -- bash -s -- "$pkg" <<'PURGE'
set -euo pipefail
PKG="$1"
SHIMMED=0
cleanup() {
  if [ "$SHIMMED" -eq 1 ]; then
    sudo rm -f /usr/bin/systemctl
    sudo dpkg-divert --local --rename --remove /usr/bin/systemctl >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
if ! systemctl daemon-reload >/dev/null 2>&1; then
  echo "Neutralizing systemctl for the purge..."
  sudo dpkg-divert --local --rename --divert /usr/bin/systemctl.real --add /usr/bin/systemctl >/dev/null
  sudo ln -sf /bin/true /usr/bin/systemctl
  SHIMMED=1
fi
sudo apt-get purge -y "$PKG" || echo "Warning: apt purge reported a problem (may be a partial state)."
PURGE
}

# --- Remove (default: unexport + purge) -----------------------------------

do_remove() {
  local app="$1" base ctn
  local -a targets=()
  manifest_exists || die "nothing recorded in the manifest at $MANIFEST - nothing to remove."
  while IFS=$'\t' read -r base ctn; do
    targets+=("$base|$ctn")
  done < <(rows "$app")
  if [ "${#targets[@]}" -eq 0 ]; then
    die "no manifest entry matched '$app'. Run --list to see what's installed."
  fi
  local base t cached_pkg=""
  for t in "${targets[@]}"; do
    base="${t%%|*}"
    [ -z "$cached_pkg" ] && cached_pkg="$(pkg_for "$base")"
    do_unexport "$base"
  done
  if [ -n "$cached_pkg" ] && [ "$cached_pkg" != "unknown" ]; then
    purge_package "$cached_pkg"
  fi
  # Drop this app's rows from the manifest (by matching desktop stem) and drop
  # its entries from the legacy flat exported file.
  local tmp
  tmp="$(mktemp)"
  while IFS=$'\t' read -r base2 pkg2 ctn2; do
    # shellcheck disable=SC2046
    if [ "$pkg2" != "$cached_pkg" ] && [ "${base2%.desktop}" != "${app%.desktop}" ]; then
      printf '%s\t%s\t%s\n' "$base2" "$pkg2" "$ctn2"
    fi
  done < "$MANIFEST" > "$tmp" || true
  mv "$tmp" "$MANIFEST"
  if [ -f "$EXPORTED_FILE" ]; then
    tmp="$(mktemp)"
    grep -vxF "${base%.desktop}.desktop" "$EXPORTED_FILE" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$EXPORTED_FILE"
  fi
  refresh_desktop_db
  echo "Removed '$app'."
  if manifest_exists; then
    echo "Other apps remain installed; the container '$CONTAINER_NAME' is untouched."
  else
    echo "No apps remain. To remove the container: distrobox rm $CONTAINER_NAME"
  fi
}

# pkg_for DESKTOP_BASE -> the package name recorded for that entry, if any.
pkg_for() {
  local base="$1" b p
  while IFS=$'\t' read -r b p _; do
    if [ "$b" = "$base" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done < "$MANIFEST"
  printf 'unknown\n'
}

# --- Entry ----------------------------------------------------------------

if [ "$DO_LIST" -eq 1 ]; then
  list_apps
  exit 0
fi

if [ -z "$DO_REMOVE" ] && [ -z "$APP_NAME" ]; then
  die "nothing to do. Pass --remove APP, --app NAME, or --list."
fi

container_exists || die "container '$CONTAINER_NAME' does not exist. Nothing to uninstall."

if [ -n "$APP_NAME" ]; then
  # --app NAME: unexport only (no purge).
  do_unexport_by_app "$APP_NAME"
  refresh_desktop_db
  echo "Done. Unexported '$APP_NAME' (package left installed)."
fi

if [ -n "$DO_REMOVE" ]; then
  do_remove "$DO_REMOVE"
fi