#!/usr/bin/env bash
#
# dbx-app-for-immutable: installer for .deb/.tar.gz GUI apps on immutable Fedora
# hosts.
#
# How it works: immutable Fedora (Bazzite, Silverblue, Kinoite, and similar)
# keeps the base OS read-only, so you cannot `apt`/`dnf install` a .deb desktop
# app onto it. This script instead:
#
#   1. ensures a shared Debian distrobox container exists (named "deb-apps" by
#      default, reused across apps);
#   2. for each `--target`, classifies it (a .deb, a .tar.gz that bundles a
#      .deb, or an `apt install` request) and stages it under $HOME so the
#      container can reach it;
#   3. installs the deb inside the container (resolving dependencies, with a
#      systemctl shim so .debs whose postinst calls systemctl still install in
#      the no-systemd box);
#   4. finds every .desktop entry the package added, filters out hidden ones,
#      and runs `distrobox-export --app` for each - so the app shows up in your
#      host app grid and opens like a native app.
#
# Per-app behavior is auto-detected; when detection can't resolve something
# (a tar with many/zero .debs, several desktop entries) it falls back to an
# interactive wizard when stdin is a TTY (or --wizard forces one), and logs a
# Note with the safest default otherwise. No downloads happen here - you supply
# the artifact.
#
# Run this from a HOST terminal (a real desktop session), not from inside a
# container.
#
# Usage:
#   ./install-deb.sh --target path/to/app.deb            install and export an app
#   ./install-deb.sh --target path/to/app.tar.gz         tarball bundling a .deb
#   ./install-deb.sh --target "apt install vlc"          install a package from Debian apt
#   ./install-deb.sh --target htop                       bare package name works too
#   ./install-deb.sh --target a.deb --target b.tar.gz    install several (one box)
#   ./install-deb.sh --target app.deb --name APP         export only the matching
#                                                          desktop entry
#   ./install-deb.sh --container NAME                    container to use (default deb-apps)
#   ./install-deb.sh --image IMAGE                       image for a new container (default debian:12)
#   ./install-deb.sh --gpu / --no-gpu                    force / disable GPU passthrough
#   ./install-deb.sh --wizard                            force instructive prompts
#   ./install-deb.sh --non-interactive                   never prompt (CI-safe)
#   ./install-deb.sh --app-args "..."                    extra args passed to the app
#   ./install-deb.sh --debug                             print every command run
#   ./install-deb.sh --help                              show this help
#
# To remove an app, run ./uninstall-app.sh instead.
#
set -euo pipefail

# Bump whenever the script's install logic changes. Only shown in --debug, so
# you can tell which version produced a given log.
BUILD="2026.08.18-2"

DEBUG=0
GPU_MODE=""          # ""=auto, gpu, no-gpu
# shellcheck disable=SC2034 # APP_ARGS is a documented launch-flag passthrough
APP_ARGS=""

# Source the host-side helper library (defines CONTAINER_NAME, CONTAINER_IMAGE,
# APP_FILTER, WIZARD, NON_INTERACTIVE + all the functions below). Its defaults
# are overridden by the flags parsed after this line.
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-auto.sh"

usage() {
  sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

declare -a TARGETS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      TARGETS+=("${2:-}")
      [ -n "${TARGETS[-1]}" ] || die "--target requires a path."
      shift 2
      ;;
    --target=*)
      TARGETS+=("${1#*=}")
      shift
      ;;
    --debug)
      DEBUG=1
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
    --gpu)
      GPU_MODE="gpu"
      shift
      ;;
    --no-gpu)
      GPU_MODE="no-gpu"
      shift
      ;;
    --wizard)
      WIZARD=1
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;
    --app-args)
      APP_ARGS="${2:-}"
      shift 2
      ;;
    --app-args=*)
      APP_ARGS="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      die "Unknown option or extra argument: $1 (use --help)"
      ;;
  esac
done

if [ "$DEBUG" -eq 1 ]; then
  echo "[debug] install-deb.sh build $BUILD (container=$CONTAINER_NAME)"
  set -x
fi

if [ "$WIZARD" -eq 1 ] && [ "$NON_INTERACTIVE" -eq 1 ]; then
  die "--wizard and --non-interactive are mutually exclusive."
fi
if [ "${#TARGETS[@]}" -eq 0 ]; then
  die "no --target given. Pass --target path/to/app.deb, app.tar.gz, or \"apt install P\"/a package name."
fi
if [ -n "$GPU_MODE" ] && [ "$GPU_MODE" = "gpu" ] && [ ! -d /dev/dri ]; then
  echo "Note: --gpu was passed but no /dev/dri exists on this host."
fi

# install_one TARGET: install a single archive or apt-package target.
install_one() {
  local target="$1" kind
  if is_apt_target "$target"; then
    _install_apt_target "$target"
    return 0
  fi
  [ -f "$target" ] || die "not a file: $target"
  kind="$(classify_target "$target")"
  case "$kind" in
    deb)
      _install_deb_target "$target"
      ;;
    tar)
      _install_tar_target "$target"
      ;;
    *)
      die "could not classify $target (file reported: $(file -b "$target"))."
      ;;
  esac
}

# _install_apt_target TARGET: parse an `apt install P` / bare package list and
# install it inside the box. If no GUI launcher is exported, the shared
# _run_and_export pipeline offers the packages' binaries for host PATH export.
_install_apt_target() {
  local pkgs
  local -a pkglist
  pkgs="$(apt_packages "$1")"
  [ -n "$pkgs" ] || die "no package names in apt target: $1"
  read -ra pkglist <<<"$pkgs"
  echo "apt target detected; installing package(s): $pkgs"
  _run_and_export "apt:${pkgs}" "${pkglist[@]}"
}

# _install_tar_target TARBALL: extract, locate its .deb(s), install one.
_install_tar_target() {
  local target="$1" line bundle_dir=""
  echo "Bundled tarball detected; extracting to find its .deb..."
  # bundle_tarball prints bundle_dir= and deb= lines (paths under $HOME).
  while IFS= read -r line; do
    case "$line" in
      'bundle_dir='*) bundle_dir="${line#bundle_dir=}" ;;
      'deb='*) _install_deb_target "${line#deb=}" ;;
    esac
  done < <(bundle_tarball "$target")
  # The extracted staging dir is only needed during the install; drop it now.
  rm -rf "$bundle_dir"
}

_install_deb_target() {
  local staged="$1"
  staged="$(stage_file "$staged")"
  _run_and_export "$staged"
}

# _run_and_export PROVISION_ARG [PKGS...]: shared provision + desktop-diff +
# export pipeline for .deb, tarball and apt-package targets. PROVISION_ARG is
# either a staged container-visible .deb path or "apt:<packages>"; PKGS is the
# requested package list (apt targets only), used to offer a terminal-only bin
# export when the target adds no GUI launcher. Apps already recorded in the
# manifest never re-trigger the offer.
_run_and_export() {
  local arg="$1"
  local -a offer_pkgs=() fresh=()
  local p
  if [ $# -gt 1 ]; then
    read -ra offer_pkgs <<<"$2" 2>/dev/null || true
  fi
  local before after out
  ensure_container
  before="$(mktemp)"
  after="$(mktemp)"
  list_desktops > "$before"

  out="$(run_provision "$arg")"
  capture_facts "$out"
  echo "$out" | grep -v '^##DEBAPP_' | grep -v '^\(package \|shimmed \|desktop \)' || true

  list_desktops > "$after"
  EXPORTED_ANY=0
  choose_and_export "$before" "$after"
  rm -f "$before" "$after"

  # Terminal-only target (no GUI launcher exported): fall back to the requested
  # packages' binaries, for .deb/.tar.gz/apt alike, unless already recorded.
  if [ "$EXPORTED_ANY" -eq 0 ]; then
    if [ "${#offer_pkgs[@]}" -eq 0 ] && [ -n "$FACTS_PACKAGE" ]; then
      offer_pkgs=("$FACTS_PACKAGE")
    fi
    for p in "${offer_pkgs[@]}"; do
      manifest_has_pkg "$p" || fresh+=("$p")
    done
    if [ "${#fresh[@]}" -gt 0 ]; then
      offer_export_bins "${fresh[@]}"
    fi
  fi
}

# choose_and_export BEFORE AFTER: diff desktops, then split the new entries into
# hidden (never export) / terminal-only (no GUI window - skip the launcher, the
# caller offers a PATH command instead) / visible GUI (export). Records each
# exported entry in the manifest (via export_desktops).
choose_and_export() {
  local before="$1" after="$2" base export_name
  local -a new=() visible=() chosen=()
  while IFS= read -r base; do
    [ -n "$base" ] || continue
    grep -qxF "$base" "$before" && continue
    new+=("$base")
  done < <(sort -u "$after")

  if [ "${#new[@]}" -eq 0 ]; then
    echo "No new desktop entries were added for this target."
    return 0
  fi

  echo "New desktop entries from this target:"
  local i=1
  for base in "${new[@]}"; do
    echo "  $((i++)). $base"
    if is_hidden "$base"; then
      continue                                        # hidden: never exported
    elif desktop_is_terminal "$base"; then
      echo "     terminal-only (no GUI window); offering a host PATH command instead."
    else
      visible+=("$base")
    fi
  done

  if [ "${#visible[@]}" -eq 0 ]; then
    note "no GUI desktop entries were added (hidden and/or terminal-only) - offering a CLI export instead."
    return 0
  fi

  if [ -n "$APP_FILTER" ]; then
    # --name narrows to the matching entry if present, else export the visible set.
    for base in "${visible[@]}"; do
      export_name="${base%.desktop}"
      if [ "$export_name" = "$APP_FILTER" ] || [ "$base" = "$APP_FILTER" ]; then
        chosen=("$base")
        break
      fi
    done
    if [ "${#chosen[@]}" -eq 0 ]; then
      note "--name '$APP_FILTER' did not match any new visible entry; exporting all visible."
      chosen=("${visible[@]}")
    fi
  elif [ "${#visible[@]}" -gt 1 ]; then
    echo "This target shipped multiple visible desktop entries."
    chosen=("$(pick_one 'Which desktop entry should be exported?' "${visible[0]}" "${visible[@]}")")
    if [ -z "${chosen[0]:-}" ]; then
      chosen=("${visible[@]}")
    fi
  else
    chosen=("${visible[0]}")
  fi

  export_desktops "${chosen[@]}"
}

require_host

for target in "${TARGETS[@]}"; do
  echo
  echo "=== Target: $target ==="
  install_one "$target"
done

refresh_desktop_db
echo
echo "Done. Every target was installed into '$CONTAINER_NAME' and its desktop"
echo "entries exported to the host app menu. Launch them like any native app -"
echo "they open the app via 'distrobox enter $CONTAINER_NAME -- ...'."
echo "Re-run this script with more --targets to add apps to the same container,"
echo "including apt packages (--target \"apt install P\"). Terminal-only"
echo "packages that ship no GUI launcher are offered for host PATH export instead."
echo "Query/remove any of it with ./uninstall-app.sh --list."
echo "GPU notes are logged above per target; --app-args can pass launch flags."
if [ -n "$APP_ARGS" ]; then
  echo "Note: --app-args='$APP_ARGS' is accepted for per-app launch flags; the exported launcher does not inject extra args by default."
fi
