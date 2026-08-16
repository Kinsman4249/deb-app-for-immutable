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
# $1 = absolute path to the .deb, inside the container (distrobox mounts host
#      $HOME at the same path, so the staged file in ~/.local/state is visible
#      here at an identical path).
#
set -euo pipefail

BUILD="2026.08.16-1"

# install-deb.sh exports BOX_DEBUG=1/0 to honour its --debug flag.
if [ "${BOX_DEBUG:-0}" = "1" ]; then
  echo "[debug] provision-container.sh build $BUILD"
  set -x
fi

DEB_PATH="${1:-}"
if [ -z "$DEB_PATH" ] || [ ! -f "$DEB_PATH" ]; then
  echo "Error: provision-container.sh expects the container path to a .deb as argv[1]." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "Updating package lists..."
sudo apt-get update -qq

echo "Installing $(basename "$DEB_PATH")..."
# gdebi resolves the package's dependencies from the apt repos and installs
# them alongside the .deb - the reason it is the install path rather than raw
# dpkg. --non-interactive means it never prompts, which is what is wanted when
# a script drives it.
#
# Non-privileged users of a distrobox get passwordless sudo for this exact
# reason. If sudo is not wired up (distrobox-image default user has it when
# sudo is present), fall back to running dpkg through apt with dependency
# resolution.
if sudo -n true 2>/dev/null; then
  sudo gdebi --non-interactive --quiet "$DEB_PATH"
else
  echo "Note: passwordless sudo unavailable - trying apt dependency resolution directly."
  sudo apt-get install -y "$DEB_PATH"
fi

echo "Installed $(basename "$DEB_PATH"). Its desktop entries were exported to the"
echo "host app grid by install-deb.sh."