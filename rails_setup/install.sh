#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/setup.conf"
TEMPLATE_DIR="${SCRIPT_DIR}/setup_config"
STAGING_DIR="${HOME}/server-setup"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -ne 0 ]] || die "Run this script as the application user, not root."
[[ -f "${CONFIG_FILE}" ]] || die "Missing ${CONFIG_FILE}"

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

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
    "${TEMPLATE_DIR}/puma.rb.template" \
    "${TEMPLATE_DIR}/puma.service.template"
do
    [[ -f "${f}" ]] || die "Missing template: ${f}"
done

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
    curl ca-certificates gnupg2 lsb-release ubuntu-keyring git \
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
fi

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

grep -Fq 'export PATH="$HOME/.rbenv/bin:$PATH"' "${HOME}/.bashrc" \
    || echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> "${HOME}/.bashrc"

grep -Fq 'eval "$(rbenv init - bash)"' "${HOME}/.bashrc" \
    || echo 'eval "$(rbenv init - bash)"' >> "${HOME}/.bashrc"

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

log "Installing nginx configuration"
if [[ -f /etc/nginx/nginx.conf ]]; then
    sudo cp -a /etc/nginx/nginx.conf \
        "/etc/nginx/nginx.conf.before-rails-setup-$(date +%Y%m%d-%H%M%S)"
fi

sudo cp "${TEMPLATE_DIR}/nginx.conf" /etc/nginx/nginx.conf

TMP_NGINX="$(mktemp)"
render_template "${TEMPLATE_DIR}/nginx-app.conf.template" "${TMP_NGINX}"
sudo cp "${TMP_NGINX}" "/etc/nginx/conf.d/${APP_NAME}.conf"
rm -f "${TMP_NGINX}"

sudo mkdir -p /var/log/nginx
sudo chown nginx:nginx /var/log/nginx

sudo nginx -t
sudo systemctl restart nginx

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

chmod 755 "${STAGING_DIR}/install_puma_service.sh"

cat <<EOF

==============================================================================
Base installation completed.

Nginx:
  $(nginx -v 2>&1)
  /etc/nginx/nginx.conf
  /etc/nginx/conf.d/${APP_NAME}.conf

Ruby / Rails:
  $(ruby -v)
  $(rails -v)

Puma staging:
  ${STAGING_DIR}/setup.conf
  ${STAGING_DIR}/puma.rb
  ${STAGING_DIR}/${APP_NAME}-puma.service
  ${STAGING_DIR}/install_puma_service.sh

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
