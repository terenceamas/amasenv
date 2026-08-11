#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/setup.conf"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -ne 0 ]] || die "Run this script as the application user, not root."
[[ -f "${CONFIG_FILE}" ]] || die "Missing ${CONFIG_FILE}"

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

APP_USER="$(eval "echo ${APP_USER}")"
APP_ROOT="$(eval "echo ${APP_ROOT}")"
APP_CURRENT="$(eval "echo ${APP_CURRENT}")"

SERVICE_SOURCE="${SCRIPT_DIR}/${APP_NAME}-puma.service"
PUMA_SOURCE="${SCRIPT_DIR}/puma.rb"

TARGET_SERVICE="${HOME}/.config/systemd/user/${APP_NAME}-puma.service"
TARGET_PUMA="${APP_CURRENT}/config/puma.rb"

[[ -d "${APP_CURRENT}" ]] || die "Application directory not found: ${APP_CURRENT}"
[[ -f "${APP_CURRENT}/Gemfile" ]] || die "Gemfile not found: ${APP_CURRENT}/Gemfile"
[[ -f "${SERVICE_SOURCE}" ]] || die "Missing ${SERVICE_SOURCE}"
[[ -f "${PUMA_SOURCE}" ]] || die "Missing ${PUMA_SOURCE}"

cd "${APP_CURRENT}"

log "Checking bundle"
if ! bundle check >/dev/null 2>&1; then
    die "bundle check failed. Run bundle install first."
fi

log "Checking Puma"
if ! bundle exec puma --version >/dev/null 2>&1; then
    die "Puma is not available in this Rails project."
fi

log "Checking Rails production boot"
RAILS_ENV=production bundle exec rails runner \
    'puts "Rails production boot OK"' >/dev/null

if [[ -f "${TARGET_PUMA}" ]]; then
    log "${TARGET_PUMA} already exists; keeping the project version."
else
    log "Installing Puma configuration"
    cp "${PUMA_SOURCE}" "${TARGET_PUMA}"
fi

log "Installing systemd user service"
mkdir -p "${HOME}/.config/systemd/user"
cp "${SERVICE_SOURCE}" "${TARGET_SERVICE}"

systemctl --user daemon-reload
systemctl --user enable "${APP_NAME}-puma.service"

log "Enabling linger for ${APP_USER}"
sudo loginctl enable-linger "${APP_USER}"

log "Starting Puma"
systemctl --user restart "${APP_NAME}-puma.service"

sleep 2

if ! systemctl --user is-active --quiet "${APP_NAME}-puma.service"; then
    journalctl --user -u "${APP_NAME}-puma.service" -n 50 --no-pager
    die "Puma service failed to start."
fi

log "Checking Puma listener"
if ! ss -lnt | grep -q "127.0.0.1:${PUMA_PORT}"; then
    journalctl --user -u "${APP_NAME}-puma.service" -n 50 --no-pager
    die "Puma is not listening on 127.0.0.1:${PUMA_PORT}"
fi

log "Testing Puma directly"
curl -sS -I "http://127.0.0.1:${PUMA_PORT}/" | head

cat <<EOF

==============================================================================
Puma service installation completed.

Service:
  ${APP_NAME}-puma.service

Useful commands:
  systemctl --user status ${APP_NAME}-puma.service
  systemctl --user restart ${APP_NAME}-puma.service
  journalctl --user -u ${APP_NAME}-puma.service -f

Nginx is already configured for:
  http://127.0.0.1:${PUMA_PORT}

No nginx restart/reload is required.
==============================================================================
EOF
