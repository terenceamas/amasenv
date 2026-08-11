#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/setup.conf"
TEMPLATE_DIR="${SCRIPT_DIR}/setup_config"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -ne 0 ]] || die "Run this script as the application user, not root."
[[ -f "${CONFIG_FILE}" ]] || die "Missing ${CONFIG_FILE}"
command -v sudo >/dev/null 2>&1 || die "sudo is required."
command -v nginx >/dev/null 2>&1 || die "nginx is not installed."

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

APP_ROOT="$(eval "echo ${APP_ROOT}")"
APP_CURRENT="$(eval "echo ${APP_CURRENT}")"

case "${ENABLE_SSL}" in
    yes|no) ;;
    *) die "ENABLE_SSL must be yes or no." ;;
esac

[[ -n "${SERVER_NAME}" ]] || die "SERVER_NAME is required."

if [[ "${ENABLE_SSL}" == "yes" ]]; then
    [[ "${SERVER_NAME}" != "_" ]] \
        || die "SERVER_NAME must be a real hostname when SSL is enabled."
    [[ -n "${SSL_CERTIFICATE}" ]] || die "SSL_CERTIFICATE is required."
    [[ -n "${SSL_CERTIFICATE_KEY}" ]] || die "SSL_CERTIFICATE_KEY is required."
    [[ -f "${SSL_CERTIFICATE}" ]] \
        || die "TLS certificate not found: ${SSL_CERTIFICATE}"
    [[ -f "${SSL_CERTIFICATE_KEY}" ]] \
        || die "TLS certificate key not found: ${SSL_CERTIFICATE_KEY}"
    TEMPLATE="${TEMPLATE_DIR}/nginx-app.conf.template"
else
    TEMPLATE="${TEMPLATE_DIR}/nginx-app-http.conf.template"
fi

[[ -f "${TEMPLATE}" ]] || die "Missing template: ${TEMPLATE}"

render_template() {
    local src="$1"
    local dst="$2"

    sed \
        -e "s|__APP_CURRENT__|${APP_CURRENT}|g" \
        -e "s|__SERVER_NAME__|${SERVER_NAME}|g" \
        -e "s|__PUMA_PORT__|${PUMA_PORT}|g" \
        -e "s|__SSL_CERTIFICATE__|${SSL_CERTIFICATE}|g" \
        -e "s|__SSL_CERTIFICATE_KEY__|${SSL_CERTIFICATE_KEY}|g" \
        -e "s|__PROXY_CONNECT_TIMEOUT__|${PROXY_CONNECT_TIMEOUT}|g" \
        -e "s|__PROXY_SEND_TIMEOUT__|${PROXY_SEND_TIMEOUT}|g" \
        -e "s|__PROXY_READ_TIMEOUT__|${PROXY_READ_TIMEOUT}|g" \
        "${src}" > "${dst}"
}

TARGET="/etc/nginx/conf.d/${APP_NAME}.conf"
TMP_NGINX="$(mktemp)"
BACKUP=""
trap 'rm -f "${TMP_NGINX}"' EXIT

render_template "${TEMPLATE}" "${TMP_NGINX}"

if [[ -f "${TARGET}" ]]; then
    BACKUP="${TARGET}.before-rails-setup-$(date +%Y%m%d-%H%M%S)"
    sudo cp -a "${TARGET}" "${BACKUP}"
fi

log "Installing ${TARGET}"
sudo cp "${TMP_NGINX}" "${TARGET}"

if ! sudo nginx -t; then
    if [[ -n "${BACKUP}" ]]; then
        sudo cp "${BACKUP}" "${TARGET}"
    else
        sudo rm -f "${TARGET}"
    fi
    sudo nginx -t || true
    die "Nginx configuration test failed; the previous application configuration was restored."
fi

if systemctl is-active --quiet nginx; then
    log "Reloading Nginx"
    sudo systemctl reload nginx
else
    log "Starting Nginx"
    sudo systemctl start nginx
fi

if [[ "${ENABLE_SSL}" == "yes" ]]; then
    URL="https://${SERVER_NAME}"
else
    URL="http://${SERVER_NAME}"
fi

cat <<EOF

==============================================================================
Nginx application configuration completed.

Configuration:
  ${TARGET}

Application URL:
  ${URL}

/etc/nginx/nginx.conf was not modified.
==============================================================================
EOF
