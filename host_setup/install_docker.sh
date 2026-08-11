#!/usr/bin/env bash
set -euo pipefail

ADD_USER_TO_DOCKER_GROUP="${ADD_USER_TO_DOCKER_GROUP:-no}"
RUN_HELLO_WORLD="${RUN_HELLO_WORLD:-yes}"
INSTALL_USER="$(id -un)"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -ne 0 ]] || die "Run this script as a normal user, not root."
command -v sudo >/dev/null 2>&1 || die "sudo is required."

for value_name in ADD_USER_TO_DOCKER_GROUP RUN_HELLO_WORLD; do
    value="${!value_name}"
    case "${value}" in
        yes|no) ;;
        *) die "${value_name} must be yes or no." ;;
    esac
done

[[ -r /etc/os-release ]] || die "/etc/os-release is required."
# shellcheck source=/dev/null
. /etc/os-release

[[ "${ID}" == "ubuntu" ]] || die "This script supports Ubuntu only."
case "${VERSION_ID}" in
    "22.04"|"24.04") ;;
    *) die "Unsupported Ubuntu ${VERSION_ID}. Supported: 22.04 and 24.04." ;;
esac

CONFLICTING_PACKAGES=(
    docker.io
    docker-compose
    docker-compose-v2
    docker-doc
    docker-buildx
    podman-docker
    containerd
    runc
)
INSTALLED_CONFLICTS=()

for package_name in "${CONFLICTING_PACKAGES[@]}"; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "${package_name}" 2>/dev/null \
        | grep -q '^ii'; then
        INSTALLED_CONFLICTS+=("${package_name}")
    fi
done

if (( ${#INSTALLED_CONFLICTS[@]} > 0 )); then
    printf '\nConflicting Docker packages are installed:\n' >&2
    printf '  %s\n' "${INSTALLED_CONFLICTS[@]}" >&2
    die "Review and remove conflicting packages before installing Docker CE."
fi

log "Configuring Docker's official apt repository"
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

ARCHITECTURE="$(dpkg --print-architecture)"
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME}}"

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Architectures: ${ARCHITECTURE}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

log "Installing Docker Engine and plugins"
sudo apt update
sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

sudo systemctl enable --now docker
sudo systemctl enable containerd

sudo docker version >/dev/null
sudo docker compose version >/dev/null

if [[ "${RUN_HELLO_WORLD}" == "yes" ]]; then
    log "Running Docker hello-world verification"
    sudo docker run --rm hello-world
fi

if [[ "${ADD_USER_TO_DOCKER_GROUP}" == "yes" ]]; then
    log "Adding ${INSTALL_USER} to the docker group"
    sudo usermod -aG docker "${INSTALL_USER}"
fi

cat <<EOF

==============================================================================
Docker host environment installed.

Docker:
  $(sudo docker --version)

Compose:
  $(sudo docker compose version)

No project image, container, volume, network, or Compose application was
created by this script.
EOF

if [[ "${ADD_USER_TO_DOCKER_GROUP}" == "yes" ]]; then
    cat <<EOF

${INSTALL_USER} was added to the docker group. Log out and back in before
running Docker without sudo. Membership in this group grants root-equivalent
control of the host; grant it only to trusted users.
EOF
else
    cat <<'EOF'

The current user was not added to the docker group. Use sudo for Docker
commands, or explicitly rerun with:

  ADD_USER_TO_DOCKER_GROUP=yes ./install_docker.sh
EOF
fi

cat <<'EOF'
==============================================================================
EOF
