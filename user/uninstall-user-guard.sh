#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_PATH="${XDG_CONFIG_HOME:-${HOME}/.config}/wsl-drive-guard/user.conf"
FALLBACK_CONFIG_PATH="${SCRIPT_DIR}/user.conf"
remove_config=0

usage() {
  cat <<'EOF'
Usage:
  uninstall-user-guard.sh [--remove-config]
EOF
}

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

while (($# > 0)); do
  case "$1" in
    --remove-config)
      remove_config=1
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      printf '%s\n' "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

load_config

rm -f \
  "${WSL_GUARD_USER_BASHRC_D}/30-wsl-guard.sh" \
  "${WSL_GUARD_USER_ZSHRC_D}/30-wsl-guard.zsh" \
  "${WSL_GUARD_USER_LIB_DIR}/wsl-guard-core.sh" \
  "${WSL_GUARD_USER_BIN_DIR}/safe-trash" \
  "${WSL_GUARD_USER_BIN_DIR}/trash-list" \
  "${WSL_GUARD_USER_BIN_DIR}/trash-restore"

if ((remove_config)); then
  rm -f "${WSL_GUARD_USER_CONFIG_PATH}"
fi

printf '%s\n' "Removed WSL Drive Guard user files."
