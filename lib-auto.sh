#!/usr/bin/env bash
#
# Host-side helper library for install-deb.sh (source me, do not execute).
#
# Kept separate so install-deb.sh stays a thin orchestrator and every file stays
# well under ~500 lines. Everything here runs on the HOST:
#
#   - target classification + tarball bundling (classify_target / bundle_tarball)
#   - apt-package targets (is_apt_target / apt_packages): --target "apt install P"
#   - staging a file so the shared $HOME mount makes it visible in the container
#   - container ensure + GPU detection (ensure_container / detect_gpu)
#   - desktop discovery, filtering and export (list_desktops / export_desktops)
#   - icon detection + theme install (detect_icon / install_icon)
#   - terminal-only binary export (offer_export_bins / _export_bin) shared by
#     .deb, tarball and apt targets
#   - the manifest recording each exported entry
#   - wizard/prompt helpers with a CI-safe non-interactive path
#
# Configuration is via global variables, set here with defaults so both
# install-deb.sh and uninstall-app.sh can override before sourcing or inline.

set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-deb-apps}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-debian:12}"
DEBUG="${DEBUG:-0}"
APP_FILTER="${APP_FILTER:-}"
WIZARD="${WIZARD:-0}"          # --wizard: force prompts
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"  # --non-interactive: never prompt

# Set by export_desktops: 1 once a target exported a desktop launcher. Lets the
# caller distinguish "terminal-only app, nothing to launch" from "GUI app
# exported", so it can offer a --bin export instead.
EXPORTED_ANY="${EXPORTED_ANY:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVISION_SCRIPT="${SCRIPT_DIR}/provision-container.sh"

STAGE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/${CONTAINER_NAME}/stage"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${CONTAINER_NAME}"
EXPORTED_FILE="${CONFIG_DIR}/exported"
MANIFEST="${CONFIG_DIR}/manifest.tsv"
# Host launcher + .desktop files distrobox-export plants next to the app grid.
HOST_APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

# The bare name distrobox-export writes onto the host. Default label is the
# container name, so a desktop entry exported as "codium" from container
# "deb-apps" becomes "deb-apps-codium.desktop".
export_label() {
  printf '%s' "$CONTAINER_NAME"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

note() {
  echo "Note: $*"
}

# --- Prompt / wizard helpers ------------------------------------------------
#
# Prompts only fire when stdin is a TTY and --non-interactive wasn't passed
# (unless --wizard forces them). In CI (no TTY) we log a Note and pick the safe
# default instead of hanging on an unreadable prompt.

may_prompt() {
  [ "$WIZARD" -eq 1 ] && return 0
  [ "$NON_INTERACTIVE" -eq 1 ] && return 1
  [ -t 0 ]
}

wait_enter() {
  if may_prompt; then
    printf 'Press Enter to continue... '
    read -r _
  fi
}

# pick_one PROMPT DEFAULT ARG...  -> echoes the chosen value.
# When >1 candidate and we cannot prompt, quiet_first is $QUIET_DEFAULT.
# ONLY the selected value goes to stdout - prompts and notes go to stderr, so
# $-captured callers never pick up the prose.
pick_one() {
  local prompt="$1" default="$2"
  shift 2
  local -a choices=("$@")
  if [ "${#choices[@]}" -eq 1 ]; then
    printf '%s\n' "${choices[0]}"
    return 0
  fi
  if ! may_prompt; then
    echo "Note: $prompt -> using '$default' (non-interactive)." >&2
    printf '%s\n' "$default"
    return 0
  fi
  echo "$prompt" >&2
  local i=1 choice
  for choice in "${choices[@]}"; do
    printf '  %d) %s\n' "$i" "$choice" >&2
    i=$((i + 1))
  done
  printf 'Choose (%d-%d, default %s): ' 1 "${#choices[@]}" "$default" >&2
  local sel=""
  read -r sel
  if [ -n "$sel" ]; then
    if [ "$sel" -ge 1 ] 2>/dev/null && [ "$sel" -le "${#choices[@]}" ] 2>/dev/null; then
      printf '%s\n' "${choices[$((sel - 1))]}"
    else
      printf '%s\n' "$default"
    fi
  else
    printf '%s\n' "$default"
  fi
}

# --- Target classification + bundling ---------------------------------------

classify_target() {
  local path="$1"
  local type
  type="$(file -b --mime-type "$path" 2>/dev/null || true)"
  case "$type" in
    application/vnd.debian.binary-package)
      printf 'deb\n'
      ;;
    application/x-tar|application/gzip|application/x-gzip|application/x-xz|application/x-bzip2|application/zip)
      printf 'tar\n'
      ;;
    *)
      # Fall back to the extension if `file` is missing or unsure.
      case "${path,,}" in
        *.deb) printf 'deb\n' ;;
        *.tar|*.tgz|*.tar.gz|*.tar.xz|*.tar.bz2|*.zip) printf 'tar\n' ;;
        *) printf 'unknown\n' ;;
      esac
      ;;
  esac
}

# is_apt_target TARGET -> returns 0 when TARGET should be handled as an in-box
# `apt install` rather than a local artifact. Artifacts always win: an existing
# file, or a path-like arg (`/...`, `./...`), is never an apt target. Anything
# else (a bare package name / list, or an `apt install ...` / `apt-get install
# ...` command) is treated as packages to install from the Debian repos.
is_apt_target() {
  local s="$1"
  if [ -e "$s" ]; then
    return 1
  fi
  case "$s" in
    /*|./*|../*|~*) return 1 ;;
  esac
  # Trim whitespace, then require something to install.
  s="$(printf '%s' "$s" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -n "$s" ]
}

# apt_packages TARGET -> echoes just the package name(s) to install, stripping a
# leading `apt install` / `apt-get install` wrapper if present.
apt_packages() {
  printf '%s\n' "$1" | sed -E \
    's/^[[:space:]]*(apt(-get)?[[:space:]]+install[[:space:]]+)?//; s/[[:space:]]+$//'
}

bundle_tarball() {
  local path="$1" bundle_dir
  bundle_dir="${STAGE_DIR}/bundle-$(basename "$path" | tr ' .' '__')-$$"
  mkdir -p "$bundle_dir"
  tar --transform='s#^\./##' -xf "$path" -C "$bundle_dir" || {
    rm -rf "$bundle_dir"
    die "could not extract $path"
  }
  # Locate every .deb recursively inside the extracted bundle.
  local -a debs=()
  while IFS= read -r f; do
    debs+=("$f")
  done < <(find "$bundle_dir" -type f -name '*.deb' 2>/dev/null)
  printf 'bundle_dir=%s\n' "$bundle_dir"
  if [ "${#debs[@]}" -eq 0 ]; then
    die "no .deb found inside tarball $path${BUNDLE_DIR_HINT:+; $BUNDLE_DIR_HINT}"
  fi
  local d
  for d in "${debs[@]}"; do
    printf 'deb=%s\n' "$d"
  done
}

# stage_file SRC -> echoes restaged path (copies into $HOME-visible STAGE_DIR).
# The same ':'/',' rejection as the old stage_deb, so distrobox/podman args are
# never ambiguous.
stage_file() {
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

# --- Container ensure + GPU ------------------------------------------------

container_exists() {
  # Older distrobox (1.8.x) prefixes each row with the podman container ID, so
  # `awk '{print $1}'` yields the ID, not the NAME. Match the pipe-delimited
  # name column instead, which is stable across versions and never the header.
  distrobox list 2>/dev/null | grep -qE "\|\s*${CONTAINER_NAME}\s*\|"
}

# detect_gpu -> echoes "nvidia" / "dri" / "none".
# distrobox shares host /dev and /sys by default, so /dev/dri is already visible
# in the container with no extra flags. NVIDIA is the only case that needs an
# explicit create-time flag, and it cannot be retrofitted onto an existing box
# (the plan documents NVIDIA hosts should first-install before the box exists).
detect_gpu() {
  if lspci 2>/dev/null | grep -qi nvidia; then
    printf 'nvidia\n'
  elif [ -d /dev/dri ]; then
    printf 'dri\n'
  else
    printf 'none\n'
  fi
}

ensure_container() {
  if container_exists; then
    return
  fi
  local gpu extra=()
  printf 'Detecting GPU... '
  gpu="$(detect_gpu)"
  echo "$gpu"
  if [ "$gpu" = "nvidia" ]; then
    note "NVIDIA host detected; adding --nvidia at container create time."
    extra+=(--nvidia)
  elif [ "$gpu" = "none" ]; then
    note "no GPU device (no /dev/dri, no NVIDIA) - apps may need software rendering."
  fi
  echo "Creating container '$CONTAINER_NAME' from $CONTAINER_IMAGE..."
  distrobox create \
    --name "$CONTAINER_NAME" \
    --image "$CONTAINER_IMAGE" \
    --yes \
    --additional-packages "sudo ca-certificates gdebi-core" \
    "${extra[@]:-}" \
    || die "distrobox create failed. See distrobox's error above."
  distrobox enter "$CONTAINER_NAME" -- true >/dev/null 2>&1 \
    || die "container '$CONTAINER_NAME' did not start. See distrobox's error above."
}

# --- Desktop discovery -----------------------------------------------------

list_desktops() {
  # shellcheck disable=SC2016
  distrobox enter "$CONTAINER_NAME" -- \
    sh -c 'ls -1 /usr/share/applications/*.desktop "$HOME"/.local/share/applications/*.desktop 2>/dev/null \
           | xargs -r -n1 basename | sort -u'
}

# run_provision STAGED_DEB -> echoes the full provision stdout (facts + prose).
run_provision() {
  local staged="$1"
  export BOX_DEBUG="$DEBUG"
  distrobox enter "$CONTAINER_NAME" -- bash -s -- "$staged" < "$PROVISION_SCRIPT"
}

# capture_facts PROVISION_OUTPUT -> parses the ##DEBAPP_FACTS block into global
# FACTS_PACKAGE / FACTS_SHIIMMED and array FACTS_DESKTOPS (base|icon lines).
# shellcheck disable=SC2034 # FACTS_SHIIMMED is read by the sourcing script.
capture_facts() {
  local out="$1" infacts=0 line
  FACTS_PACKAGE=""
  FACTS_SHIIMMED=""
  FACTS_DESKTOPS=()
  while IFS= read -r line; do
    case "$line" in
      '##DEBAPP_FACTS') infacts=1 ; continue ;;
      '##DEBAPP_END') infacts=0 ;;
    esac
    [ "$infacts" -eq 1 ] || continue
    case "$line" in
      'package '* ) FACTS_PACKAGE="${line#package }" ;;
      'shimmed '* ) FACTS_SHIIMMED="${line#shimmed }" ;;
      'desktop '* ) FACTS_DESKTOPS+=("${line#desktop }") ;;
    esac
  done <<< "$out"
}

# is_hidden BASE -> returns 0 if the entry should be skipped by default
# (NoDisplay=true / Hidden=true), matching app-grid expectations.
is_hidden() {
  local base="$1" one
  local -a paths=( "/usr/share/applications/$base" "\$HOME/.local/share/applications/$base" )
  for one in "${paths[@]}"; do
    if distrobox enter "$CONTAINER_NAME" -- sh -c \
        "grep -E '^(NoDisplay|Hidden)=' \"$one\" 2>/dev/null | grep -qi '=true'"; then
      return 0
    fi
  done
  return 1
}

# desktop_is_terminal BASE -> returns 0 when the entry is a terminal-only app.
#
# "Terminal application only" means the app runs in a terminal and never opens
# its own window, even though it may ship a `.desktop` for menu convenience
# (htop does exactly this). We only ever downgrade a launcher on a POSITIVE
# terminal signal - never downgrade a real GUI into a PATH command by mistake:
#   - declarative: the entry has `Terminal=true` or a `ConsoleOnly` category;
#   - empirical guard: IF such a flag is set, we still trust the binary over the
#     metadata - if its Exec target links GUI toolkit libs (X11/XCB/Wayland/GTK/
#     Qt/SDL/EGL/GL), it is actually a GUI app despite the flag.
# An entry with no terminal flag keeps its launcher export (GUI or ambiguous).
desktop_is_terminal() {
  local base="$1" path exe
  path="$(locate_desktop "$base" 2>/dev/null || true)"
  [ -n "$path" ] || return 1
  # No declarative terminal signal -> GUI/ambiguous -> keep the launcher.
  # shellcheck disable=SC2016 # the sh -c body must run in the container.
  if ! distrobox enter "$CONTAINER_NAME" -- sh -c \
      "grep -qiE '^(Terminal=[Tt]rue|Categories=.*ConsoleOnly)' \"\$1\" 2>/dev/null" \
      b "$path"; then
    return 1
  fi
  # Exec binary; bare commands resolve to a path inside the container.
  # shellcheck disable=SC2016 # the sh -c body must run in the container.
  exe="$(distrobox enter "$CONTAINER_NAME" -- sh -c \
      "sed -n -E 's/^Exec=([^ %]+).*/\\1/p' \"\$1\" | head -n1" b "$path" 2>/dev/null || true)"
  case "$exe" in
    '') return 0 ;;                       # flag set, no Exec -> treat as terminal
    /*) ;;
    *) exe="$(distrobox enter "$CONTAINER_NAME" -- command -v "$exe" 2>/dev/null || true)" ;;
  esac
  [ -n "$exe" ] || return 0
  # Flag set but the binary actually links a GUI toolkit -> it IS a GUI app.
  # shellcheck disable=SC2016 # the sh -c body must run in the container.
  if distrobox enter "$CONTAINER_NAME" -- sh -c \
      "ldd \"\$1\" 2>/dev/null | grep -qiE 'libX11|libxcb|wayland-client|libgtk|libQt|libSDL|libEGL|libGL'" \
      b "$exe"; then
    return 1
  fi
  return 0
}

locate_desktop() {
  local base="$1" path
  if distrobox enter "$CONTAINER_NAME" -- test -f "/usr/share/applications/$base"; then
    printf '/usr/share/applications/%s\n' "$base"
  elif distrobox enter "$CONTAINER_NAME" -- \
      test -f "\$HOME/.local/share/applications/$base"; then
    distrobox enter "$CONTAINER_NAME" -- printf '%s' "\$HOME/.local/share/applications/$base"
  fi
}

# export_desktops BASES... -> distrobox-export each onto the host, record state.
# After export it hands each launcher to install_icon so the icon resolves from
# the host (theme name or patched absolute path, never a container-private path).
# Note: distrobox-export's --app accepts a name OR an absolute .desktop path
# (this distrobox 1.8.x has no separate --desktop-file flag), so we hand it the
# path to avoid guessing which location held the entry.
export_desktops() {
  local base desktop_path export_name
  EXPORTED_ANY=0
  mkdir -p "$CONFIG_DIR"
  for base in "$@"; do
    desktop_path="$(locate_desktop "$base")"
    if [ -z "$desktop_path" ]; then
      note "could not locate $base in the container - skipping."
      continue
    fi
    export_name="${base%.desktop}"
    echo "Exporting $base to the host app grid..."
    distrobox enter "$CONTAINER_NAME" -- distrobox-export \
      --app "$desktop_path" \
      || { echo "Warning: could not export $export_name." >&2; continue; }
    printf '%s\n' "$base" >> "$EXPORTED_FILE"
    record_manifest "$base"
    install_icon "$export_name" "$desktop_path"
    EXPORTED_ANY=1
  done
}

# --- Manifest --------------------------------------------------------------
# One row per exported desktop entry: desktop_base<TAB>package_name<TAB>container.
# The first column keeps the full *.desktop filename so uninstall can resolve
# the exact entry; package comes from the provision facts.
record_manifest() {
  local base="$1"
  mkdir -p "$CONFIG_DIR"
  printf '%s\t%s\t%s\n' "$base" "${FACTS_PACKAGE:-unknown}" "$CONTAINER_NAME" >> "$MANIFEST"
  dedup_manifest
}

# record_manifest_bin NAME: record a terminal-only binary export the same way a
# desktop entry is recorded, as a `bin:<name>` row so uninstall can resolve it.
record_manifest_bin() {
  local name="$1"
  mkdir -p "$CONFIG_DIR"
  printf 'bin:%s\t%s\t%s\n' "$name" "${FACTS_PACKAGE:-unknown}" "$CONTAINER_NAME" >> "$MANIFEST"
  dedup_manifest
}

dedup_manifest() {
  [ -s "$MANIFEST" ] || return 0
  local tmp
  tmp="$(mktemp)"
  sort -u "$MANIFEST" > "$tmp"
  mv "$tmp" "$MANIFEST"
}

# manifest_has_pkg PACKAGE -> returns 0 if an app with that package name is
# already recorded (desktop or bin row). Used so a re-run of an already-exported
# app never re-offers a terminal-only bin export.
manifest_has_pkg() {
  local p="$1" b c _
  [ -s "$MANIFEST" ] || return 1
  while IFS=$'\t' read -r b c _; do
    [ "$c" = "$p" ] && return 0
  done < "$MANIFEST"
  return 1
}

# --- Icon handling ---------------------------------------------------------

# detect_icon CONTAINER_DESKTOP -> echoes icon category + value as "TYPE VALUE":
#   abs /abs/path        absolute path inside the container rootfs
#   name some-name       bare icon-theme name (e.g. Icon=vscodium)
#   empty                 no usable Icon=
detect_icon() {
  local desktop_path="$1" icon
  icon="$(distrobox enter "$CONTAINER_NAME" -- sh -c \
    "sed -n -E 's/^Icon=(.*)/\\1/p' \"$desktop_path\" 2>/dev/null | tail -n1")"
  if [ -z "$icon" ]; then
    printf 'empty\n'
  elif printf '%s' "$icon" | grep -q '^/'; then
    printf 'abs %s\n' "$icon"
  else
    printf 'name %s\n' "$icon"
  fi
}

# install_icon EXPORT_NAME CONTAINER_DESKTOP
#
# distrobox-export copies the referenced icon out itself, but for a bare theme
# name the taskbar/dock path must be able to resolve the name through the icon
# theme - an absolute path or a file that isn't in the theme won't show up in a
# running window's taskbar. So for a name-based Icon we re-install the PNG into
# the hicolor theme; for an absolute container path we copy it to $HOME and
# repoint the exported launcher at that shared path.
install_icon() {
  local export_name="$1" desktop_path="$2"
  local kind icon
  IFS=' ' read -r kind icon <<<"$(detect_icon "$desktop_path")"
  if [ "$kind" = "name" ] && [ -n "$icon" ]; then
    _install_icon_theme "$export_name" "$icon"
  elif [ "$kind" = "abs" ] && [ -n "$icon" ]; then
    _install_icon_patch "$export_name" "$icon"
  fi
}

_install_icon_theme() {
  local export_name="$1" icon="$2"
  local icon_dir="$HOME/.local/share/icons/hicolor/512x512/apps"
  local target="${icon_dir}/${icon}.png"
  if [ -f "$target" ]; then
    return 0
  fi
  mkdir -p "$icon_dir"
  local src
  src="$(distrobox enter "$CONTAINER_NAME" -- sh -c \
    "for f in /usr/share/icons/hicolor/512x512/apps/${icon}.png \
              /usr/share/pixmaps/${icon}.png; do [ -f \"\$f\" ] && { echo \"\$f\"; break; }; done")"
  if [ -z "$src" ]; then
    note "could not locate a source file for icon '$icon' - launcher will fall back."
    return 0
  fi
  if distrobox enter "$CONTAINER_NAME" -- cat "$src" > "$target" 2>/dev/null; then
    echo "Installed $icon into the hicolor icon theme."
  else
    note "could not copy $icon out of the container."
  fi
  gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
}

_install_icon_patch() {
  local export_name="$1" icon="$2"
  local target_dir="$HOME/.local/share/icons"
  local target="${target_dir}/${export_name}.png"
  if [ ! -f "$target" ]; then
    mkdir -p "$target_dir"
    if distrobox enter "$CONTAINER_NAME" -- cat "$icon" > "$target" 2>/dev/null; then
      echo "Copied $icon to $target"
    else
      note "could not copy $icon out of the container." 
      echo "${export_name}:$icon" >> "$CONFIG_DIR/icon-missing.log" 2>/dev/null || true
      return 0
    fi
  fi
  # Repoint the host launcher (written by distrobox-export) at the shared path.
  local launcher
  launcher="${HOST_APPS_DIR}/$(export_label)-${export_name}.desktop"
  sed -i -E "s#^Icon=.*#Icon=${target}#" "$launcher" 2>/dev/null \
    || note "could not repoint Icon= in $launcher (does the file exist?)."
  gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
}

# --- Shared desktop-db refresh --------------------------------------------
refresh_desktop_db() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOST_APPS_DIR" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

require_host() {
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

# --- Terminal-only binary export ------------------------------------------
#
# A target that turns out terminal-only - a command-line tool with no GUI
# window, whether it shipped a .desktop (htop) or none (ripgrep) - has nothing
# to export to the host app grid. Instead of a launcher, offer to
# `distrobox-export --bin` each binary the packages provide: that lands a
# wrapper in ~/.local/bin so you can run the command from any host terminal.
# This fires for any target kind (.deb, .tar.gz, apt) when no GUI launcher was
# exported and the app is not already recorded in the manifest.
# `Terminal=true` / `ConsoleOnly` entries are classified terminal-only unless
# their Exec binary actually links a GUI toolkit (see desktop_is_terminal).

# binaries_for PKG -> echoes every executable the package owns under /usr/bin
# or /usr/sbin (deduped across calls by the caller's sort -u).
binaries_for() {
  local pkg="$1"
  # shellcheck disable=SC2016 # 'dpkg...' runs in the container; host must not expand $.
  distrobox enter "$CONTAINER_NAME" -- sh -c \
    'dpkg -L "$1" 2>/dev/null | grep -E "^/usr/(bin|sbin)/" | grep -v "/$" \
     | while read -r b; do [ -x "$b" ] && printf "%s\n" "$b"; done | sort -u' \
    b "$pkg" 2>/dev/null || true
}

# offer_export_bins PKGS... : given the requested package list, find the
# binaries they provide and ask whether to export them to the host PATH.
# In non-interactive/CI runs, log a Note and skip instead of changing the env
# without a yes.
offer_export_bins() {
  local pkg b
  local -a bins=()
  for pkg in "$@"; do
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      bins+=("$b")
    done < <(binaries_for "$pkg")
  done
  if [ "${#bins[@]}" -eq 0 ]; then
    note "no binaries exported by these packages were found on PATH - run them inside the box via 'distrobox enter $CONTAINER_NAME -- <cmd>'."
    return 0
  fi

  if ! may_prompt; then
    note "terminal-only target: binaries (${bins[*]}) not exported because no TTY/--wizard. Re-run to add them to host PATH."
    return 0
  fi

  echo "This target added no GUI launcher - it looks like a terminal-only app."
  echo "Binaries it provides:"
  local i=1
  for b in $(printf '%s\n' "${bins[@]}" | sort -u); do
    echo "  $((i++)). $b"
  done
  printf 'Export these to the host PATH so you can run them from any terminal? [y/N] '
  local ans
  read -r ans || ans=""
  case "$ans" in
    [yY]|[yY][eE][sS])
      for b in $(printf '%s\n' "${bins[@]}" | sort -u); do
        _export_bin "$b"
      done
      ;;
    *)
      echo "Skipping. Run them inside the box with: distrobox enter $CONTAINER_NAME -- <cmd>"
      ;;
  esac
}

# _export_bin ABS_PATH: distrobox-export one container binary onto the host
# PATH and record it in the manifest for uninstall.
_export_bin() {
  local abs="$1" name
  name="$(basename "$abs")"
  echo "Exporting '$name' to host PATH..."
  if distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin "$abs"; then
    record_manifest_bin "$name"
  else
    echo "Warning: could not export $name to the host PATH." >&2
  fi
}