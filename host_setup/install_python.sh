#!/usr/bin/env bash
set -euo pipefail

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -ne 0 ]] || die "Run this script as a normal user, not root."
command -v sudo >/dev/null 2>&1 || die "sudo is required."

[[ -r /etc/os-release ]] || die "/etc/os-release is required."
# shellcheck source=/dev/null
. /etc/os-release

[[ "${ID}" == "ubuntu" ]] || die "This script supports Ubuntu only."
case "${VERSION_ID}" in
    "22.04"|"24.04") ;;
    *) die "Unsupported Ubuntu ${VERSION_ID}. Supported: 22.04 and 24.04." ;;
esac

log "Installing the Ubuntu Python development environment"
sudo apt update
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential

command -v python3 >/dev/null 2>&1 || die "python3 installation verification failed."

log "Verifying Python virtual environments"
TEST_VENV="$(mktemp -d)"
trap 'rm -rf "${TEST_VENV}"' EXIT

python3 -m venv "${TEST_VENV}/venv"
"${TEST_VENV}/venv/bin/python" -m pip --version

cat <<EOF

==============================================================================
Python host environment installed.

Python:
  $(python3 --version)

No project packages were installed. Create a virtual environment inside each
project instead of installing packages into Ubuntu's system Python:

  cd <project-directory>
  python3 -m venv .venv
  source .venv/bin/activate
  python -m pip install --upgrade pip
  pip install -r requirements.txt
==============================================================================
EOF
