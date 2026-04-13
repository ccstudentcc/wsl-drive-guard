#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_PATH="/etc/wsl-drive-guard/system.conf"
FALLBACK_CONFIG_PATH="${SCRIPT_DIR}/system.conf"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_GID="$(id -g "$TARGET_USER")"
TMP_ROOT="${SCRIPT_DIR}/tmp"

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

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    sudo mkdir -p "$BACKUP_ROOT"
    sudo cp -a "$path" "$BACKUP_ROOT/"
  fi
}

strip_automount_section() {
  local path="$1"
  awk '
    BEGIN { skip = 0 }
    /^\[automount\][[:space:]]*$/ { skip = 1; next }
    /^\[[^]]+\][[:space:]]*$/ { skip = 0 }
    skip == 0 { print }
  ' "$path"
}

render_wsl_conf() {
  local current_file="$1"
  local temp_file="$2"
  local mount_root="${WSL_GUARD_MOUNT_ROOT%/}"
  local generated_block

  generated_block="$(cat <<EOF
[automount]
enabled=false
mountFsTab=true
root=${mount_root}/
options="${WSL_GUARD_AUTOMOUNT_OPTIONS}"
EOF
)"

  if [[ -f "$current_file" ]]; then
    strip_automount_section "$current_file" >"$temp_file"
    printf '\n%s\n' "$WSL_GUARD_MANAGED_BEGIN" >>"$temp_file"
    printf '%s\n' "$generated_block" >>"$temp_file"
    printf '%s\n' "$WSL_GUARD_MANAGED_END" >>"$temp_file"
  else
    printf '%s\n' "$WSL_GUARD_MANAGED_BEGIN" >"$temp_file"
    printf '%s\n' "$generated_block" >>"$temp_file"
    printf '%s\n' "$WSL_GUARD_MANAGED_END" >>"$temp_file"
  fi
}

strip_managed_block_and_targets() {
  local path="$1"
  awk \
    -v begin="$WSL_GUARD_MANAGED_BEGIN" \
    -v end="$WSL_GUARD_MANAGED_END" \
    -v mount_root="${WSL_GUARD_MOUNT_ROOT%/}" \
    -v drive_list="$WSL_GUARD_MANAGED_DRIVES" '
    BEGIN { in_block = 0 }
    BEGIN {
      split(drive_list, drives, " ")
      for (i in drives) {
        targets[mount_root "/" drives[i]] = 1
      }
    }
    $0 == begin { in_block = 1; next }
    $0 == end { in_block = 0; next }
    in_block == 1 { next }
    targets[$2] && $3 == "drvfs" { next }
    { print }
  ' "$path"
}

render_fstab() {
  local current_file="$1"
  local temp_file="$2"
  local mount_root="${WSL_GUARD_MOUNT_ROOT%/}"
  local drive
  local upper_drive
  local mountpoint
  local options

  if [[ -f "$current_file" ]]; then
    strip_managed_block_and_targets "$current_file" >"$temp_file"
  else
    : >"$temp_file"
  fi

  [[ -s "$temp_file" ]] || printf '# UNCONFIGURED FSTAB FOR BASE SYSTEM\n' >"$temp_file"

  if [[ -s "$temp_file" ]] && [[ "$(tail -c 1 "$temp_file" || true)" != $'\n' ]]; then
    printf '\n' >>"$temp_file"
  fi

  printf '\n%s\n' "$WSL_GUARD_MANAGED_BEGIN" >>"$temp_file"

  for drive in $WSL_GUARD_MANAGED_DRIVES; do
    upper_drive="${drive^^}"
    mountpoint="${mount_root}/${drive}"
    options="${WSL_GUARD_DEFAULT_MODE},${WSL_GUARD_DRVFS_OPTIONS},uid=${TARGET_UID},gid=${TARGET_GID}"
    printf '%s %s drvfs %s 0 0\n' "${upper_drive}:" "$mountpoint" "$options" >>"$temp_file"
  done

  printf '%s\n' "$WSL_GUARD_MANAGED_END" >>"$temp_file"
}

main() {
  load_config

  BACKUP_ROOT="${WSL_GUARD_BACKUP_ROOT_PARENT}/$(date +%Y%m%d-%H%M%S)"

  require_file "$FALLBACK_CONFIG_PATH"
  require_file "$SCRIPT_DIR/win-drive-mode"
  require_file "$SCRIPT_DIR/win-drive-session"
  require_file "$SCRIPT_DIR/win-drive-status"

  mkdir -p "$TMP_ROOT"
  tmp_wsl_conf="$(mktemp -p "$TMP_ROOT" wsl.conf.XXXXXX)"
  tmp_fstab="$(mktemp -p "$TMP_ROOT" fstab.XXXXXX)"
  trap 'rm -f "$tmp_wsl_conf" "$tmp_fstab"' EXIT

  render_wsl_conf "$WSL_GUARD_WSL_CONF_PATH" "$tmp_wsl_conf"
  render_fstab "$WSL_GUARD_FSTAB_PATH" "$tmp_fstab"

  backup_if_exists "$WSL_GUARD_WSL_CONF_PATH"
  backup_if_exists "$WSL_GUARD_FSTAB_PATH"
  backup_if_exists "${WSL_GUARD_SYSTEM_BIN_DIR}/win-drive-mode"
  backup_if_exists "${WSL_GUARD_SYSTEM_BIN_DIR}/win-drive-session"
  backup_if_exists "${WSL_GUARD_SYSTEM_BIN_DIR}/win-drive-status"
  backup_if_exists "$WSL_GUARD_SYSTEM_CONFIG_PATH"

  sudo mkdir -p "$WSL_GUARD_SYSTEM_CONFIG_DIR" "$WSL_GUARD_SYSTEM_BIN_DIR"

  if [[ ! -f "$WSL_GUARD_SYSTEM_CONFIG_PATH" ]]; then
    sudo install -m 0644 "$FALLBACK_CONFIG_PATH" "$WSL_GUARD_SYSTEM_CONFIG_PATH"
  fi

  sudo install -m 0644 "$tmp_wsl_conf" "$WSL_GUARD_WSL_CONF_PATH"
  sudo install -m 0644 "$tmp_fstab" "$WSL_GUARD_FSTAB_PATH"
  sudo install -m 0755 "$SCRIPT_DIR/win-drive-mode" "${WSL_GUARD_SYSTEM_BIN_DIR}/win-drive-mode"
  sudo install -m 0755 "$SCRIPT_DIR/win-drive-session" "${WSL_GUARD_SYSTEM_BIN_DIR}/win-drive-session"
  sudo install -m 0755 "$SCRIPT_DIR/win-drive-status" "${WSL_GUARD_SYSTEM_BIN_DIR}/win-drive-status"

  echo "Installed WSL isolation config."
  echo "Next steps:"
  echo "  1. In Windows PowerShell, run: wsl --shutdown"
  echo "  2. Reopen WSL"
  echo "  3. Check default mount mode with: win-drive-status"
  echo "  4. Temporarily enable write access with: sudo win-drive-mode rw c"
  echo "  5. Prefer temporary rw shells with: sudo win-drive-session rw c"
}

main "$@"
