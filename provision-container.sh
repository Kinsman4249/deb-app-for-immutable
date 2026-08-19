#!/usr/bin/env bash
#
# Container-side installer for a .deb, piped into the deb-apps distrobox
# container by install-deb.sh:
#
#   distrobox enter deb-apps -- bash -s -- /path/to/app.deb < provision-container.sh
#
# It runs as the host user (distrobox maps you through, rootless podman), so
# privileged operations go through 'sudo'. gdebi-core is guaranteed present
# because install-deb.sh passes it to `distrobox create --additional-packages`.
#
# $1 = either an absolute path to the .deb, inside the container (distrobox
#      mounts host $HOME at the same path, so the staged file in
#      ~/.local/state is visible here at an identical path), or "apt:<pkgs>"
#      to install package(s) from the Debian repos (an `--target "apt install
#      P"` request).
#
# After installing, it prints a machine-parseable FACTS block on stdout so the
# host side knows the package name, whether the systemctl shim was active, and
# every .desktop file the container now has plus its Icon= value - without the
# host having to re-query the container or guess.
#
#   ##DEBAPP_FACTS
#   package <name>
#   shimmed 0|1
#   desktop <base>.desktop <icon-value-or->
#   ...
#   ##DEBAPP_END
#
set -euo pipefail

BUILD="2026.08.18-2"

# install-deb.sh exports BOX_DEBUG=1/0 to honour its --debug flag.
if [ "${BOX_DEBUG:-0}" = "1" ]; then
  echo "[debug] provision-container.sh build $BUILD"
  set -x
fi

ARG="${1:-}"
MODE=deb
DEB_PATH=""
APT_PACKAGES=""
case "$ARG" in
  apt:*)
    MODE=apt
    APT_PACKAGES="${ARG#apt:}"
    ;;
  *)
    DEB_PATH="$ARG"
    ;;
esac

if [ "$MODE" = deb ]; then
  if [ -z "$DEB_PATH" ] || [ ! -f "$DEB_PATH" ]; then
    echo "Error: provision-container.sh expects the container path to a .deb as argv[1]," >&2
    echo "       or an 'apt:<packages>' target." >&2
    exit 1
  fi
else
  # shellcheck disable=SC2086 # APT_PACKAGES is a word-split package list below.
  set -- $APT_PACKAGES
  if [ $# -eq 0 ]; then
    echo "Error: 'apt:' target had no package names." >&2
    exit 1
  fi
  # First requested package is the manifest's package column (fine for one or
  # several packages installed from a single target).
  PKG="$1"
fi

export DEBIAN_FRONTEND=noninteractive

SHIMMED=0
cleanup_shim() {
  if [ "$SHIMMED" -eq 1 ]; then
    sudo rm -f /usr/bin/systemctl
    sudo dpkg-divert --local --rename --remove /usr/bin/systemctl >/dev/null 2>&1 || true
  fi
}
trap cleanup_shim EXIT

# A plain (non--init) Distrobox container has no live systemd manager, so
# `systemctl daemon-reload` in a .deb's postinst fails with "Failed to connect
# to bus" and, under the postinst's own `set -e`, aborts the whole install.
# A no-op shim earlier on PATH is NOT reliable: apt-get install may pull in the
# systemd package, which unpacks a real /usr/bin/systemctl mid-transaction, and
# apt/dpkg's internal postinst subprocess env can still resolve that real
# binary. dpkg-divert sidesteps it by acting on the literal path
# /usr/bin/systemctl, so it doesn't matter what unpacks there or what PATH the
# postinst sees. The divert is removed by trap on EXIT (even on failure) so a
# later app install in this container is not left shimmed.
if ! systemctl daemon-reload >/dev/null 2>&1; then
  echo "No live systemd manager in this container; neutralizing systemctl for the install..."
  sudo dpkg-divert --local --rename --divert /usr/bin/systemctl.real --add /usr/bin/systemctl >/dev/null
  sudo ln -sf /bin/true /usr/bin/systemctl
  SHIMMED=1
fi

echo "Updating package lists..."
sudo apt-get update -qq

if [ "$MODE" = deb ]; then
  echo "Installing $(basename "$DEB_PATH")..."
  # gdebi resolves the package's dependencies from the apt repos and installs
  # them alongside the .deb - the reason it is the install path rather than raw
  # dpkg. --non-interactive means it never prompts, which is what is wanted when
  # a script drives it.
  if sudo -n true 2>/dev/null; then
    sudo gdebi --non-interactive --quiet "$DEB_PATH"
  else
    echo "Note: passwordless sudo unavailable - trying apt dependency resolution directly."
    sudo apt-get install -y "$DEB_PATH"
  fi
else
  echo "Installing from apt: $APT_PACKAGES"
  # shellcheck disable=SC2086 # intended word-split package list; apt pulls
  # Recommends just like the gdebi .deb path, so e.g. `vlc` gets its codecs.
  sudo apt-get install -y $APT_PACKAGES
fi

# Some vendor .debs omit a runtime library from Depends (splashtop relies on
# Recommends). Those libs only show up when the binary is actually run, so
# repair them here: ldd every Exec target the package ships a .desktop for, and
# for each "not found" shared lib install the Debian-convention provider package
# (libfoo.so.N -> libfooN), verified to exist in the apt cache first. This lives
# here (not on the host) because it's a runtime requirement OF the installed app.
find_app_bins() {
  local f exe
  for f in /usr/share/applications/*.desktop "$HOME"/.local/share/applications/*.desktop; do
    [ -e "$f" ] || continue
    exe="$(sed -n -E 's/^Exec=([^ %]+).*/\1/p' "$f" | head -n1)"
    [ -n "$exe" ] || continue
    case "$exe" in
      /*) printf '%s\n' "$exe" ;;
      *)
        command -v "$exe" 2>/dev/null || true
        ;;
    esac
  done | sort -u
}

# libxdo.so.3 -> libxdo3 (strip lib prefix, keep lib<name><soname>). Returns
# empty for names that don't fit a simple Debian shlib naming (e.g. libc.so.6)
# so the caller skips reconciling those - they are already gdebi-resolved deps.
so_to_pkg() {
  local name="$1" base
  base="$(printf '%s' "$name" | sed -n -E 's/^lib([^.]*)\.so\.([0-9]+).*$/\1 \2/p')"
  [ -n "$base" ] || return 0
  # shellcheck disable=SC2086 # word-split into the shlib-name + soname-major
  set -- $base
  printf 'lib%s%s\n' "$1" "$2"
}

fix_missing_libs() {
  local bin so pkg
  while IFS= read -r bin; do
    [ -n "$bin" ] || continue
    while IFS= read -r so; do
      pkg="$(so_to_pkg "$so")"
      [ -n "$pkg" ] || continue
      if apt-cache show "$pkg" >/dev/null 2>&1; then
        echo "Missing runtime lib $so ($bin) - installing provider package $pkg..."
        sudo apt-get install -y --no-install-recommends "$pkg" || true
      else
        echo "Note: $so missing, no apt candidate for '$pkg'; app may still fail at runtime."
      fi
    done < <(ldd "$bin" 2>/dev/null | awk '/not found/{print $1}')
  done < <(find_app_bins)
  # Always return success: this is a best-effort repair pass, and under
  # `set -e` a non-zero return here (e.g. nothing was missing) would abort the
  # whole provision after the package already installed but before the FACTS
  # block is emitted, leaving the app installed but not exported and the host
  # seeing a silent failure.
  return 0
}
fix_missing_libs

# The control stanza inside the .deb names the installed package. The host is
# immutable Fedora and has no dpkg, but this runs in Debian, where dpkg-deb is
# always present - this is the authoritative source for the manifest's package
# column. Multiple Package: fields do not happen for a real control file; the
# last one wins if a corrupted deb sneaks through. (For an apt target, PKG was
# already set to the first requested package above.)
if [ "$MODE" = deb ]; then
  PKG="$(dpkg-deb -f "$DEB_PATH" Package 2>/dev/null | tail -n1)"
fi

emit_facts() {
  echo "##DEBAPP_FACTS"
  echo "package ${PKG:-unknown}"
  echo "shimmed $SHIMMED"
  local f base icon
  for f in /usr/share/applications/*.desktop "$HOME"/.local/share/applications/*.desktop; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    icon="$(sed -n -E 's/^Icon=(.*)/\1/p' "$f" | head -n1)"
    echo "desktop $base ${icon:-}"
  done
  echo "##DEBAPP_END"
}

emit_facts

if [ "$MODE" = deb ]; then
  echo "Installed $(basename "$DEB_PATH"). Its desktop entries were exported to the"
  echo "host app grid by install-deb.sh."
else
  echo "Installed $APT_PACKAGES from apt. install-deb.sh exported any GUI launchers"
  echo "it provides, or offered the CLI binaries for host PATH export."
fi