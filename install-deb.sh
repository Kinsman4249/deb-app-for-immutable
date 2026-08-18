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
#   2. for each `--target`, classifies it (a .deb or a .tar.gz that bundles a
#      .deb) and stages it under $HOME so the container can reach it;
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
BUILD="2026.08.17-1"

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
  die "no --target given. Pass --target path/to/app.deb or --target app.tar.gz."
fi
if [ -n "$GPU_MODE" ] && [ "$GPU_MODE" = "gpu" ] && [ ! -d /dev/dri ]; then
  echo "Note: --gpu was passed but no /dev/dri exists on this host."
fi

# install_one TARGET: full auto-detect pipeline for a single artifact.
install_one() {
  local target="$1" kind
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
  local staged="$1" before after out
  ensure_container
  before="$(mktemp)"
  after="$(mktemp)"
  staged="$(stage_file "$staged")"
  list_desktops > "$before"

  out="$(run_provision "$staged")"
  capture_facts "$out"
  echo "$out" | grep -v '^##DEBAPP_' | grep -v '^\(package \|shimmed \|desktop \)' || true

  list_desktops > "$after"
  choose_and_export "$before" "$after"
  rm -f "$before" "$after"
}

# choose_and_export BEFORE AFTER: diff desktops, filter hidden, disambiguate,
# then export each. Records each entry in the manifest (via export_desktops).
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
    if ! is_hidden "$base"; then
      visible+=("$base")
    fi
  done

  if [ "${#visible[@]}" -eq 0 ]; then
    note "all new entries are Hidden/NoDisplay - nothing exported to the app grid."
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
echo "or run ./uninstall-app.sh --list to query and remove exported launchers."
echo "GPU notes are logged above per target; --app-args can pass launch flags."
[ -n "$APP_ARGS" ] && echo "Note: --app-args='$APP_ARGS' is accepted for per-app launch flags; the exported launcher does not inject extra args by default."
