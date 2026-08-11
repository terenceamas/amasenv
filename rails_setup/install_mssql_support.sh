#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-}"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -ne 0 ]] || die "Run this script as the application user, not root."
command -v sudo >/dev/null 2>&1 || die "sudo is required."

[[ -r /etc/os-release ]] || die "/etc/os-release is required."
# shellcheck source=/dev/null
. /etc/os-release

[[ "${ID}" == "ubuntu" ]] || die "This script supports Ubuntu only."
case "${VERSION_ID}" in
    "22.04"|"24.04") ;;
    *) die "Unsupported Ubuntu ${VERSION_ID}. Supported: 22.04 and 24.04." ;;
esac

if [[ -n "${APP_DIR}" ]]; then
    APP_DIR="$(cd "${APP_DIR}" 2>/dev/null && pwd)" \
        || die "Application directory not found: ${1}"
elif [[ -f "${PWD}/Gemfile" ]]; then
    APP_DIR="${PWD}"
fi

log "Installing TinyTDS/FreeTDS system dependencies"
sudo apt update
sudo apt install -y \
    freetds-bin \
    freetds-dev \
    libsybdb5

command -v tsql >/dev/null 2>&1 || die "tsql was not installed correctly."

LDCONFIG="$(command -v ldconfig || true)"
[[ -n "${LDCONFIG}" ]] || die "ldconfig is required to verify libsybdb."

LIBSYBDB_PATH="$(${LDCONFIG} -p 2>/dev/null \
    | awk '/libsybdb\.so/{print $NF; exit}')"
[[ -n "${LIBSYBDB_PATH}" ]] || die "libsybdb was not found by the dynamic linker."

log "FreeTDS configuration"
tsql -C

log "FreeTDS runtime library"
printf '%s\n' "${LIBSYBDB_PATH}"

if [[ -n "${APP_DIR}" ]]; then
    log "Checking Rails project: ${APP_DIR}"
    [[ -f "${APP_DIR}/Gemfile" ]] || die "Gemfile not found in ${APP_DIR}."
    [[ -f "${APP_DIR}/Gemfile.lock" ]] || die "Gemfile.lock not found in ${APP_DIR}."

    if ! grep -Eq '^[[:space:]]+tiny_tds([[:space:](]|$)' "${APP_DIR}/Gemfile.lock"; then
        die "tiny_tds was not found in ${APP_DIR}/Gemfile.lock."
    fi

    command -v bundle >/dev/null 2>&1 \
        || die "Bundler is not available for the current user."

    cd "${APP_DIR}"
    if bundle check >/dev/null 2>&1; then
        log "Checking TinyTDS Ruby extension"
        bundle exec ruby -e \
            'require "tiny_tds"; puts "TinyTDS #{TinyTds::VERSION} loaded successfully"'
    else
        log "Bundle is not complete; skipping the TinyTDS Ruby runtime check."
    fi
else
    log "No Rails project was supplied; skipping the TinyTDS Ruby runtime check."
fi

cat <<'EOF'

==============================================================================
MSSQL support installation completed.

Installed support:
  FreeTDS command-line tools (including tsql)
  FreeTDS development headers
  libsybdb runtime library used by TinyTDS

No ODBC driver, Microsoft repository, SQL Server account, password, or Rails
database configuration was installed.

Test a SQL Server connection without putting the password in shell history:

  TDSVER=auto tsql -H <mssql-host> -p 1433 -U <username>

tsql will prompt for the password interactively.
==============================================================================
EOF
