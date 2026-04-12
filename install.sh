#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install_system=1
install_user=1

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--system-only | --user-only]
EOF
}

while (($# > 0)); do
  case "$1" in
    --system-only)
      install_user=0
      ;;
    --user-only)
      install_system=0
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

if ((install_system == 0 && install_user == 0)); then
  printf '%s\n' "Nothing selected to install." >&2
  exit 1
fi

if ((install_system)); then
  "${SCRIPT_DIR}/system/install-wsl-isolation.sh"
fi

if ((install_user)); then
  "${SCRIPT_DIR}/user/install-user-guard.sh"
fi
