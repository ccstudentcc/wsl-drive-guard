#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_PATH="${XDG_CONFIG_HOME:-${HOME}/.config}/wsl-drive-guard/user.conf"
FALLBACK_CONFIG_PATH="${SCRIPT_DIR}/user.conf"

load_config() {
  local config_path=""

  if [[ -f "$DEFAULT_CONFIG_PATH" ]]; then
    config_path="$DEFAULT_CONFIG_PATH"
  elif [[ -f "$FALLBACK_CONFIG_PATH" ]]; then
    config_path="$FALLBACK_CONFIG_PATH"
  else
    printf '%s\n' "Missing user config." >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  . "$config_path"
}

load_config

mkdir -p \
  "$WSL_GUARD_USER_BASHRC_D" \
  "$WSL_GUARD_USER_ZSHRC_D" \
  "$WSL_GUARD_USER_BIN_DIR" \
  "$WSL_GUARD_USER_CONFIG_DIR" \
  "$WSL_GUARD_USER_LIB_DIR"

if [[ ! -f "$WSL_GUARD_USER_CONFIG_PATH" ]]; then
  install -m 0644 "${FALLBACK_CONFIG_PATH}" "${WSL_GUARD_USER_CONFIG_PATH}"
fi

install -m 0644 "${SCRIPT_DIR}/bashrc.d/30-wsl-guard.sh" "${WSL_GUARD_USER_BASHRC_D}/30-wsl-guard.sh"
install -m 0644 "${SCRIPT_DIR}/zshrc.d/30-wsl-guard.zsh" "${WSL_GUARD_USER_ZSHRC_D}/30-wsl-guard.zsh"
install -m 0644 "${SCRIPT_DIR}/lib/wsl-guard-core.sh" "${WSL_GUARD_USER_LIB_DIR}/wsl-guard-core.sh"
install -m 0755 "${SCRIPT_DIR}/bin/safe-trash" "${WSL_GUARD_USER_BIN_DIR}/safe-trash"
install -m 0755 "${SCRIPT_DIR}/bin/trash-list" "${WSL_GUARD_USER_BIN_DIR}/trash-list"
install -m 0755 "${SCRIPT_DIR}/bin/trash-restore" "${WSL_GUARD_USER_BIN_DIR}/trash-restore"

printf '%s\n' "Installed user guard files."
printf '%s\n' "Next step:"
printf '%s\n' "  source ~/.bashrc"
printf '%s\n' "  source ~/.zshrc  # after loading ~/.zshrc.d/*.zsh from your zsh config"
