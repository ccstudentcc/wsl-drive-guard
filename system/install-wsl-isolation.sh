#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_GID="$(id -g "$TARGET_USER")"
BACKUP_ROOT="/etc/wsl-isolation-backups/$(date +%Y%m%d-%H%M%S)"
TMP_ROOT="$SCRIPT_DIR/tmp"
MANAGED_BEGIN="# BEGIN WSL ISOLATION MANAGED BLOCK"
MANAGED_END="# END WSL ISOLATION MANAGED BLOCK"

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

  if [[ -f "$current_file" ]]; then
    strip_automount_section "$current_file" >"$temp_file"
    printf '\n%s\n' "$MANAGED_BEGIN" >>"$temp_file"
    cat "$SCRIPT_DIR/wsl.conf" >>"$temp_file"
    printf '%s\n' "$MANAGED_END" >>"$temp_file"
  else
    printf '%s\n' "$MANAGED_BEGIN" >"$temp_file"
    cat "$SCRIPT_DIR/wsl.conf" >>"$temp_file"
    printf '%s\n' "$MANAGED_END" >>"$temp_file"
  fi
}

strip_managed_block_and_drvfs_targets() {
  local path="$1"
  awk -v begin="$MANAGED_BEGIN" -v end="$MANAGED_END" '
    BEGIN { in_block = 0 }
    $0 == begin { in_block = 1; next }
    $0 == end { in_block = 0; next }
    in_block == 1 { next }
    $2 ~ /^\/mnt\/[cde]$/ && $3 == "drvfs" { next }
    { print }
  ' "$path"
}

render_fstab() {
  local current_file="$1"
  local temp_file="$2"

  if [[ -f "$current_file" ]]; then
    strip_managed_block_and_drvfs_targets "$current_file" >"$temp_file"
  else
    : >"$temp_file"
  fi

  [[ -s "$temp_file" ]] || printf '# UNCONFIGURED FSTAB FOR BASE SYSTEM\n' >"$temp_file"

  if [[ -s "$temp_file" ]] && [[ "$(tail -c 1 "$temp_file" || true)" != $'\n' ]]; then
    printf '\n' >>"$temp_file"
  fi

  printf '\n%s\n' "$MANAGED_BEGIN" >>"$temp_file"
  sed \
    -e "s/uid=1000/uid=${TARGET_UID}/g" \
    -e "s/gid=1000/gid=${TARGET_GID}/g" \
    "$SCRIPT_DIR/fstab" >>"$temp_file"
  printf '%s\n' "$MANAGED_END" >>"$temp_file"
}

main() {
  require_file "$SCRIPT_DIR/wsl.conf"
  require_file "$SCRIPT_DIR/fstab"
  require_file "$SCRIPT_DIR/win-drive-mode"
  require_file "$SCRIPT_DIR/win-drive-session"
  require_file "$SCRIPT_DIR/win-drive-status"

  mkdir -p "$TMP_ROOT"
  tmp_wsl_conf="$(mktemp -p "$TMP_ROOT" wsl.conf.XXXXXX)"
  tmp_fstab="$(mktemp -p "$TMP_ROOT" fstab.XXXXXX)"
  trap 'rm -f "$tmp_wsl_conf" "$tmp_fstab"' EXIT

  render_wsl_conf /etc/wsl.conf "$tmp_wsl_conf"
  render_fstab /etc/fstab "$tmp_fstab"

  backup_if_exists /etc/wsl.conf
  backup_if_exists /etc/fstab
  backup_if_exists /usr/local/bin/win-drive-mode
  backup_if_exists /usr/local/bin/win-drive-session
  backup_if_exists /usr/local/bin/win-drive-status

  sudo install -m 0644 "$tmp_wsl_conf" /etc/wsl.conf
  sudo install -m 0644 "$tmp_fstab" /etc/fstab
  sudo install -m 0755 "$SCRIPT_DIR/win-drive-mode" /usr/local/bin/win-drive-mode
  sudo install -m 0755 "$SCRIPT_DIR/win-drive-session" /usr/local/bin/win-drive-session
  sudo install -m 0755 "$SCRIPT_DIR/win-drive-status" /usr/local/bin/win-drive-status

  echo "Installed WSL isolation config."
  echo "Next steps:"
  echo "  1. In Windows PowerShell, run: wsl --shutdown"
  echo "  2. Reopen WSL"
  echo "  3. Check default mount mode with: win-drive-status"
  echo "  4. Temporarily enable write access with: win-drive-mode rw c"
  echo "  5. Prefer temporary rw shells with: win-drive-session rw c"
}

main "$@"
