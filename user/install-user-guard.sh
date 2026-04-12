#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BASHRC_D="${HOME}/.bashrc.d"
TARGET_BIN="${HOME}/.local/bin"

mkdir -p "$TARGET_BASHRC_D" "$TARGET_BIN"

install -m 0644 "${SCRIPT_DIR}/bashrc.d/30-wsl-guard.sh" "${TARGET_BASHRC_D}/30-wsl-guard.sh"
install -m 0755 "${SCRIPT_DIR}/bin/safe-trash" "${TARGET_BIN}/safe-trash"
install -m 0755 "${SCRIPT_DIR}/bin/trash-list" "${TARGET_BIN}/trash-list"
install -m 0755 "${SCRIPT_DIR}/bin/trash-restore" "${TARGET_BIN}/trash-restore"

printf '%s\n' "Installed user guard files."
printf '%s\n' "Next step:"
printf '%s\n' "  source ~/.bashrc"
