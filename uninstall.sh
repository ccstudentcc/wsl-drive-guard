#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
remove_system=1
remove_user=1
remove_config=0

usage() {
  cat <<'EOF'
Usage:
  ./uninstall.sh [--system-only | --user-only] [--remove-config]
EOF
}

while (($# > 0)); do
  case "$1" in
    --system-only)
      remove_user=0
      ;;
    --user-only)
      remove_system=0
      ;;
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

if ((remove_system == 0 && remove_user == 0)); then
  printf '%s\n' "Nothing selected to uninstall." >&2
  exit 1
fi

if ((remove_system)); then
  if ((remove_config)); then
    "${SCRIPT_DIR}/system/uninstall-wsl-isolation.sh" --remove-config
  else
    "${SCRIPT_DIR}/system/uninstall-wsl-isolation.sh"
  fi
fi

if ((remove_user)); then
  if ((remove_config)); then
    "${SCRIPT_DIR}/user/uninstall-user-guard.sh" --remove-config
  else
    "${SCRIPT_DIR}/user/uninstall-user-guard.sh"
  fi
fi
