#!/usr/bin/env bash
set -euo pipefail

# Per-user rbenv and nvm bootstrap for a host whose system dependencies are
# already installed. This script does not install project runtimes or packages.
NVM_VERSION="${NVM_VERSION:-v0.40.4}"
DEV_USER="$(id -un)"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -ne 0 ]] || die "Run this script as the development user, not root."
[[ -n "${HOME:-}" && -d "${HOME}" ]] || die "A valid HOME directory is required."
[[ "${NVM_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "NVM_VERSION must look like v0.40.4."

for command_name in git curl bash; do
    command -v "${command_name}" >/dev/null 2>&1 \
        || die "${command_name} is required. Ask the host administrator to install it."
done

BASHRC="${HOME}/.bashrc"
touch "${BASHRC}"

append_once() {
    local line="$1"
    grep -Fqx "${line}" "${BASHRC}" || printf '%s\n' "${line}" >> "${BASHRC}"
}

log "Installing/updating rbenv for ${DEV_USER}"
if [[ ! -d "${HOME}/.rbenv/.git" ]]; then
    [[ ! -e "${HOME}/.rbenv" ]] \
        || die "${HOME}/.rbenv exists but is not a Git checkout."
    git clone https://github.com/rbenv/rbenv.git "${HOME}/.rbenv"
else
    git -C "${HOME}/.rbenv" pull --ff-only
fi

mkdir -p "${HOME}/.rbenv/plugins"

if [[ ! -d "${HOME}/.rbenv/plugins/ruby-build/.git" ]]; then
    [[ ! -e "${HOME}/.rbenv/plugins/ruby-build" ]] \
        || die "ruby-build exists but is not a Git checkout."
    git clone https://github.com/rbenv/ruby-build.git \
        "${HOME}/.rbenv/plugins/ruby-build"
else
    git -C "${HOME}/.rbenv/plugins/ruby-build" pull --ff-only
fi

append_once 'export PATH="$HOME/.rbenv/bin:$PATH"'
append_once 'eval "$(rbenv init - bash)"'

export PATH="${HOME}/.rbenv/bin:${PATH}"
eval "$(rbenv init - bash)"
command -v rbenv >/dev/null 2>&1 || die "rbenv installation verification failed."

log "Installing/updating nvm ${NVM_VERSION} for ${DEV_USER}"
NVM_INSTALLER="$(mktemp)"
trap 'rm -f "${NVM_INSTALLER}"' EXIT

curl -fsSL \
    "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
    -o "${NVM_INSTALLER}"

# Keep shell configuration under this script's idempotent control.
PROFILE=/dev/null bash "${NVM_INSTALLER}"

append_once 'export NVM_DIR="$HOME/.nvm"'
append_once '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
append_once '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

export NVM_DIR="${HOME}/.nvm"
# shellcheck source=/dev/null
[[ -s "${NVM_DIR}/nvm.sh" ]] || die "nvm installation verification failed."
. "${NVM_DIR}/nvm.sh"
command -v nvm >/dev/null 2>&1 || die "nvm installation verification failed."

cat <<EOF

==============================================================================
Development user tools installed.

User:
  ${DEV_USER}

rbenv:
  $(rbenv --version)

nvm:
  $(nvm --version)

No Ruby, Rails, Node.js, or Yarn version was installed.

Open a new login shell, then install the versions required by the project.
Examples:

  rbenv install --list
  rbenv install <ruby-version>
  rbenv global <ruby-version>
  gem install bundler

  nvm ls-remote --lts
  nvm install <node-version>
  nvm alias default <node-version>

Install additional Ruby gems and Node packages only when they are needed.
==============================================================================
EOF
