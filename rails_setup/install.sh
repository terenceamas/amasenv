#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/setup.conf"
TEMPLATE_DIR="${SCRIPT_DIR}/setup_config"
STAGING_DIR="${HOME}/server-setup"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

append_bashrc_once() {
    local line="$1"
    grep -Fqx "${line}" "${HOME}/.bashrc" \
        || printf '%s\n' "${line}" >> "${HOME}/.bashrc"
}

[[ "${EUID}" -ne 0 ]] || die "Run this script as the application user, not root."
[[ -f "${CONFIG_FILE}" ]] || die "Missing ${CONFIG_FILE}"

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

touch "${HOME}/.bashrc"
[[ "${NVM_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "NVM_VERSION must look like v0.40.4."

# Expand variables such as ${HOME}/${APP_NAME} after loading setup.conf.
APP_USER="$(eval "echo ${APP_USER}")"
APP_ROOT="$(eval "echo ${APP_ROOT}")"
APP_CURRENT="$(eval "echo ${APP_CURRENT}")"

render_template() {
    local src="$1"
    local dst="$2"

    sed \
        -e "s|__APP_NAME__|${APP_NAME}|g" \
        -e "s|__APP_CURRENT__|${APP_CURRENT}|g" \
        -e "s|__SERVER_NAME__|${SERVER_NAME}|g" \
        -e "s|__PUMA_PORT__|${PUMA_PORT}|g" \
        -e "s|__SSL_CERTIFICATE__|${SSL_CERTIFICATE}|g" \
        -e "s|__SSL_CERTIFICATE_KEY__|${SSL_CERTIFICATE_KEY}|g" \
        -e "s|__PHP_FPM_SOCKET__|${PHP_FPM_SOCKET:-PHP_FPM_SOCKET_NOT_DETECTED}|g" \
        -e "s|__HOME__|${HOME}|g" \
        "${src}" > "${dst}"
}

command -v sudo >/dev/null 2>&1 || die "sudo is required."

. /etc/os-release
[[ "${ID}" == "ubuntu" ]] || die "This script supports Ubuntu only."

case "${VERSION_ID}" in
    "22.04"|"24.04") ;;
    *) die "Unsupported Ubuntu ${VERSION_ID}. Recommended: Ubuntu 22.04 or 24.04." ;;
esac

CODENAME="${VERSION_CODENAME}"

for f in \
    "${TEMPLATE_DIR}/nginx.conf" \
    "${TEMPLATE_DIR}/nginx-app.conf.template" \
    "${TEMPLATE_DIR}/nginx-app-http.conf.template" \
    "${TEMPLATE_DIR}/nginx-phpmyadmin.conf.example" \
    "${TEMPLATE_DIR}/puma.rb.template" \
    "${TEMPLATE_DIR}/puma.service.template"
do
    [[ -f "${f}" ]] || die "Missing template: ${f}"
done

[[ -f "${SCRIPT_DIR}/configure_nginx.sh" ]] \
    || die "Missing ${SCRIPT_DIR}/configure_nginx.sh"

log "Ubuntu ${VERSION_ID} (${CODENAME})"
log "Application: ${APP_NAME}"
log "Application user: ${APP_USER}"
log "Application path: ${APP_CURRENT}"
log "Puma port: ${PUMA_PORT}"
log "Ruby ${RUBY_VERSION} / Rails ${RAILS_VERSION}"

if [[ "${USE_NCHC_MIRROR}" == "yes" && -f /etc/apt/sources.list ]]; then
    log "Switching tw.archive.ubuntu.com to free.nchc.org.tw"
    sudo cp -a /etc/apt/sources.list \
        "/etc/apt/sources.list.before-rails-setup-$(date +%Y%m%d-%H%M%S)"
    sudo sed -i 's#tw.archive.ubuntu.com#free.nchc.org.tw#g' /etc/apt/sources.list
fi

log "Installing base packages"
sudo apt update
sudo apt install -y \
    curl ca-certificates gnupg2 lsb-release ubuntu-keyring git openssl \
    build-essential autoconf patch rustc \
    libssl-dev libyaml-dev libreadline-dev zlib1g-dev libgmp-dev \
    libncurses5-dev libffi-dev libgdbm-dev libdb-dev uuid-dev \
    libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev \
    libcurl4-openssl-dev pkg-config

log "Configuring nginx.org stable repository"
curl -fsSL https://nginx.org/keys/nginx_signing.key \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

NGINX_FINGERPRINT="$(
    gpg --dry-run --quiet --no-keyring \
        --import --import-options import-show \
        /usr/share/keyrings/nginx-archive-keyring.gpg 2>/dev/null \
        | tr -d ' ' \
        | grep -o '573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62' \
        | head -n1 || true
)"

[[ "${NGINX_FINGERPRINT}" == "573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62" ]] \
    || die "nginx signing-key fingerprint verification failed."

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/ubuntu ${CODENAME} nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null

cat <<'EOF' | sudo tee /etc/apt/preferences.d/99nginx >/dev/null
Package: *
Pin: origin nginx.org
Pin: release o=nginx
Pin-Priority: 900
EOF

sudo apt update

if [[ -n "${NGINX_VERSION}" ]]; then
    sudo apt install -y "nginx=${NGINX_VERSION}"
else
    sudo apt install -y nginx
fi

sudo systemctl enable nginx

if [[ "${INSTALL_MYSQL}" == "yes" ]]; then
    log "Installing MySQL"
    sudo apt install -y mysql-server default-libmysqlclient-dev
    sudo systemctl enable mysql
fi

if [[ "${INSTALL_PHP}" == "yes" ]]; then
    log "Installing PHP"
    sudo apt install -y php-fpm php-mysql php-mbstring

    PHP_FPM_SOCKET="$(find /run/php -maxdepth 1 -type s -name 'php*-fpm.sock' \
        -print -quit 2>/dev/null || true)"
    if [[ -n "${PHP_FPM_SOCKET}" ]]; then
        log "Detected PHP-FPM socket: ${PHP_FPM_SOCKET}"
    else
        log "PHP-FPM socket was not detected; update the phpMyAdmin example manually."
    fi
fi

log "Installing/updating nvm ${NVM_VERSION}"
NVM_INSTALLER="$(mktemp)"
trap 'rm -f "${NVM_INSTALLER}"' EXIT
curl -fsSL \
    "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
    -o "${NVM_INSTALLER}"

# Keep shell configuration idempotent and managed by this installer.
PROFILE=/dev/null bash "${NVM_INSTALLER}"
rm -f "${NVM_INSTALLER}"
trap - EXIT

append_bashrc_once 'export NVM_DIR="$HOME/.nvm"'
append_bashrc_once '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
append_bashrc_once '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

export NVM_DIR="${HOME}/.nvm"
# shellcheck source=/dev/null
[[ -s "${NVM_DIR}/nvm.sh" ]] || die "nvm installation verification failed."
. "${NVM_DIR}/nvm.sh"
command -v nvm >/dev/null 2>&1 || die "nvm installation verification failed."

log "Installing Node.js LTS"
NODE_SETUP="/tmp/nodesource_setup.sh"
curl -fsSL https://deb.nodesource.com/setup_lts.x -o "${NODE_SETUP}"
sudo -E bash "${NODE_SETUP}"
rm -f "${NODE_SETUP}"
sudo apt install -y nodejs

if ! command -v yarn >/dev/null 2>&1; then
    sudo npm install -g yarn
fi

log "Installing/updating rbenv"
if [[ ! -d "${HOME}/.rbenv/.git" ]]; then
    git clone https://github.com/rbenv/rbenv.git "${HOME}/.rbenv"
else
    git -C "${HOME}/.rbenv" pull --ff-only
fi

append_bashrc_once 'export PATH="$HOME/.rbenv/bin:$PATH"'
append_bashrc_once 'eval "$(rbenv init - bash)"'

export PATH="${HOME}/.rbenv/bin:${PATH}"
eval "$(rbenv init - bash)"

mkdir -p "$(rbenv root)/plugins"

if [[ ! -d "$(rbenv root)/plugins/ruby-build/.git" ]]; then
    git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)/plugins/ruby-build"
else
    git -C "$(rbenv root)/plugins/ruby-build" pull --ff-only
fi

log "Installing Ruby ${RUBY_VERSION}"
if ! rbenv versions --bare | grep -Fxq "${RUBY_VERSION}"; then
    rbenv install "${RUBY_VERSION}"
fi

rbenv global "${RUBY_VERSION}"
gem install bundler
gem install rails -v "${RAILS_VERSION}"
rbenv rehash

sudo mkdir -p /var/log/nginx
sudo chown nginx:nginx /var/log/nginx

log "Configuring Nginx application virtual host"
bash "${SCRIPT_DIR}/configure_nginx.sh"

log "Preparing Puma staging files"
mkdir -p "${STAGING_DIR}"

render_template \
    "${TEMPLATE_DIR}/puma.rb.template" \
    "${STAGING_DIR}/puma.rb"

render_template \
    "${TEMPLATE_DIR}/puma.service.template" \
    "${STAGING_DIR}/${APP_NAME}-puma.service"

cp "${SCRIPT_DIR}/install_puma_service.sh" \
   "${STAGING_DIR}/install_puma_service.sh"

cp "${CONFIG_FILE}" \
   "${STAGING_DIR}/setup.conf"

cp "${SCRIPT_DIR}/configure_nginx.sh" \
   "${STAGING_DIR}/configure_nginx.sh"

mkdir -p "${STAGING_DIR}/setup_config"
cp "${TEMPLATE_DIR}/nginx-app.conf.template" \
   "${STAGING_DIR}/setup_config/nginx-app.conf.template"
cp "${TEMPLATE_DIR}/nginx-app-http.conf.template" \
   "${STAGING_DIR}/setup_config/nginx-app-http.conf.template"

if [[ "${INSTALL_PHP}" == "yes" ]]; then
    render_template \
        "${TEMPLATE_DIR}/nginx-phpmyadmin.conf.example" \
        "${STAGING_DIR}/nginx-phpmyadmin.conf.example"

    PHPMYADMIN_SECRET="$(openssl rand -hex 16)"
    PHPMYADMIN_SECRET_FILE="${STAGING_DIR}/phpmyadmin-blowfish-secret.php"
    printf '%s\n' \
        "\$cfg['blowfish_secret'] = '${PHPMYADMIN_SECRET}';" \
        > "${PHPMYADMIN_SECRET_FILE}"
    chmod 600 "${PHPMYADMIN_SECRET_FILE}"
fi

chmod 755 \
    "${STAGING_DIR}/install_puma_service.sh" \
    "${STAGING_DIR}/configure_nginx.sh"

cat <<EOF

==============================================================================
Base installation completed.

Nginx:
  $(nginx -v 2>&1)
  /etc/nginx/nginx.conf
  /etc/nginx/conf.d/${APP_NAME}.conf

Nginx main configuration:
  /etc/nginx/nginx.conf was not replaced by this installer.
  Review the reference configuration before changing it manually:
  ${TEMPLATE_DIR}/nginx.conf

Ruby / Rails:
  $(ruby -v)
  $(rails -v)

Node.js tools:
  $(node --version)
  nvm $(nvm --version)

Puma staging:
  ${STAGING_DIR}/setup.conf
  ${STAGING_DIR}/puma.rb
  ${STAGING_DIR}/${APP_NAME}-puma.service
  ${STAGING_DIR}/install_puma_service.sh
  ${STAGING_DIR}/configure_nginx.sh

Expected application path:
  ${APP_CURRENT}

After RD finishes deploying/preparing the Rails project, run:
  ${STAGING_DIR}/install_puma_service.sh

Nginx is already configured for:
  127.0.0.1:${PUMA_PORT}

Before Puma starts, application requests may return 502.
Installing Puma later does NOT require nginx restart/reload.
==============================================================================
EOF

if [[ "${INSTALL_PHP}" == "yes" ]]; then
    cat <<EOF

==============================================================================
Optional phpMyAdmin setup:

phpMyAdmin is not installed by this script. Download and install it manually
from the official phpMyAdmin website.

After installing phpMyAdmin, review this Nginx configuration example:
  ${STAGING_DIR}/nginx-phpmyadmin.conf.example

A 32-character Blowfish secret was generated for config.inc.php:
  ${STAGING_DIR}/phpmyadmin-blowfish-secret.php

The secret file is readable only by the application user. Copy its PHP
configuration line into phpMyAdmin's config.inc.php, then remove the secret
file when it is no longer needed.

Before enabling it, update the server name, phpMyAdmin installation path,
PHP-FPM socket, TLS certificate paths, and customer-specific access
restrictions. Check the installed PHP-FPM socket with:
  ls /run/php/

Copy the adjusted configuration to /etc/nginx/conf.d/, then verify and reload:
  sudo nginx -t
  sudo systemctl reload nginx
==============================================================================
EOF
fi
