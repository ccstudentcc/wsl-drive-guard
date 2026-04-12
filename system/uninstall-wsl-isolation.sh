#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_PATH="/etc/wsl-drive-guard/system.conf"
FALLBACK_CONFIG_PATH="${SCRIPT_DIR}/system.conf"
remove_config=0

usage() {
  cat <<'EOF'
Usage:
  uninstall-wsl-isolation.sh [--remove-config]
EOF
}

load_config() {
  local config_path=""

  if [[ -f "$DEFAULT_CONFIG_PATH" ]]; then
    config_path="$DEFAULT_CONFIG_PATH"
  elif [[ -f "$FALLBACK_CONFIG_PATH" ]]; then
    config_path="$FALLBACK_CONFIG_PATH"
  else
    printf '%s\n' "Missing system config." >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  . "$config_path"
}

backup_if_exists() {
  local path="$1"

  if [[ -e "$path" ]]; then
    sudo mkdir -p "$BACKUP_ROOT"
    sudo cp -a "$path" "$BACKUP_ROOT/"
  fi
}

strip_managed_block() {
  local path="$1"

  awk -v begin="$WSL_GUARD_MANAGED_BEGIN" -v end="$WSL_GUARD_MANAGED_END" '
    BEGIN { in_block = 0 }
    $0 == begin { in_block = 1; next }
    $0 == end { in_block = 0; next }
    in_block == 0 { print }
  ' "$path"
}

write_or_remove() {
  local source_path="$1"
  local target_path="$2"

  if [[ -s "$source_path" ]]; then
    sudo install -m 0644 "$source_path" "$target_path"
  else
    sudo rm -f "$target_path"
  fi
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

BACKUP_ROOT="${WSL_GUARD_BACKUP_ROOT_PARENT}/$(date +%Y%m%d-%H%M%S)"
tmp_root="${SCRIPT_DIR}/tmp"
mkdir -p "$tmp_root"
tmp_wsl_conf="$(mktemp -p "$tmp_root" uninstall.wsl.conf.XXXXXX)"
tmp_fstab="$(mktemp -p "$tmp_root" uninstall.fstab.XXXXXX)"
trap 'rm -f "$tmp_wsl_conf" "$tmp_fstab"' EXIT

if [[ -f "$WSL_GUARD_WSL_CONF_PATH" ]]; then
  strip_managed_block "$WSL_GUARD_WSL_CONF_PATH" >"$tmp_wsl_conf"
  backup_if_exists "$WSL_GUARD_WSL_CONF_PATH"
  write_or_remove "$tmp_wsl_conf" "$WSL_GUARD_WSL_CONF_PATH"
fi

if [[ -f "$WSL_GUARD_FSTAB_PATH" ]]; then
  strip_managed_block "$WSL_GUARD_FSTAB_PATH" >"$tmp_fstab"
  backup_if_exists "$WSL_GUARD_FSTAB_PATH"

  if [[ ! -s "$tmp_fstab" ]]; then
    printf '# UNCONFIGURED FSTAB FOR BASE SYSTEM\n' >"$tmp_fstab"
  fi

  sudo install -m 0644 "$tmp_fstab" "$WSL_GUARD_FSTAB_PATH"
fi

for tool_name in win-drive-mode win-drive-session win-drive-status; do
  backup_if_exists "${WSL_GUARD_SYSTEM_BIN_DIR}/${tool_name}"
  sudo rm -f "${WSL_GUARD_SYSTEM_BIN_DIR}/${tool_name}"
done

if ((remove_config)); then
  backup_if_exists "$WSL_GUARD_SYSTEM_CONFIG_PATH"
  sudo rm -f "$WSL_GUARD_SYSTEM_CONFIG_PATH"
fi

printf '%s\n' "Removed WSL Drive Guard system files."
printf '%s\n' "If you changed mount behavior, run 'wsl --shutdown' from Windows PowerShell before reopening WSL."
