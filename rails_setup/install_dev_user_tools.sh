#!/usr/bin/env bash
set -euo pipefail

# Compatibility entry point. The implementation is maintained in host_setup.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${SCRIPT_DIR}/../host_setup/install_rbenv_nvm.sh"

if [[ ! -f "${TARGET}" ]]; then
    printf 'ERROR: Missing %s\n' "${TARGET}" >&2
    printf 'Run host_setup/install_rbenv_nvm.sh from the complete repository.\n' >&2
    exit 1
fi

exec bash "${TARGET}" "$@"
