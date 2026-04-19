# Shared user-layer helpers for WSL Drive Guard.

: "${WSL_GUARD_ENABLE_PROMPT:=1}"
: "${WSL_GUARD_ENABLE_SESSION_MARKER:=1}"
: "${WSL_GUARD_ENABLE_COPY_MOVE_CONFIRM:=1}"
: "${WSL_GUARD_ENABLE_SAFE_RM:=1}"
: "${WSL_GUARD_WINDOWS_MOUNT_ROOT:=/mnt}"
: "${WSL_GUARD_USER_BIN_DIR:=${HOME}/.local/bin}"

__WSL_GUARD_MOUNT_ROOT="${WSL_GUARD_WINDOWS_MOUNT_ROOT%/}"

__wsl_guard_to_upper() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

__wsl_guard_to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

__wsl_guard_mount_mode() {
  local drive="$1"
  local mountpoint="${__WSL_GUARD_MOUNT_ROOT}/${drive}"

  awk -v mp="$mountpoint" '
    $2 == mp {
      if ($4 ~ /(^|,)ro(,|$)/) {
        print "RO"
      } else {
        print "RW"
      }
      found = 1
      exit
    }
    END {
      if (!found) {
        print "??"
      }
    }
  ' /proc/mounts
}

__wsl_guard_current_windows_drive() {
  local drive=""

  case "$PWD" in
    "${__WSL_GUARD_MOUNT_ROOT}"/[[:alpha:]]|"${__WSL_GUARD_MOUNT_ROOT}"/[[:alpha:]]/*)
      drive="${PWD#${__WSL_GUARD_MOUNT_ROOT}/}"
      drive="${drive%%/*}"
      __wsl_guard_to_lower "$drive"
      ;;
  esac
}

__wsl_guard_session_marker_text() {
  if ((WSL_GUARD_ENABLE_SESSION_MARKER)) && [[ -n "${WSL_DRIVE_SESSION_DRIVES:-}" ]]; then
    printf 'RW-SESSION:%s' "$(__wsl_guard_to_upper "$WSL_DRIVE_SESSION_DRIVES")"
  fi
}

__wsl_guard_drive_marker_text() {
  local drive="$1"
  local mode="$2"

  printf 'WIN:%s:%s' "$(__wsl_guard_to_upper "$drive")" "$mode"
}

__wsl_guard_resolve_path() {
  local raw_path="$1"

  if command -v realpath >/dev/null 2>&1; then
    realpath -sm -- "$raw_path"
  elif [[ "$raw_path" == /* ]]; then
    printf '%s\n' "$raw_path"
  else
    printf '%s/%s\n' "$PWD" "$raw_path"
  fi
}

__wsl_guard_is_windows_drive_path() {
  local resolved_path

  resolved_path="$(__wsl_guard_resolve_path "$1")"
  [[ "$resolved_path" == "$__WSL_GUARD_MOUNT_ROOT"/[[:alpha:]] || "$resolved_path" == "$__WSL_GUARD_MOUNT_ROOT"/[[:alpha:]]/* ]]
}

__wsl_guard_confirm() {
  local prompt="$1"
  local reply

  printf '%s' "${prompt} [y/N] " >&2
  IFS= read -r reply
  [[ "$reply" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}

__wsl_guard_extract_copy_target() {
  local args=("$@")
  local positional=()
  local arg
  local stop_opts=0
  local i

  for ((i = 0; i < ${#args[@]}; i++)); do
    arg="${args[i]}"

    if ((stop_opts)); then
      positional+=("$arg")
      continue
    fi

    case "$arg" in
      --target-directory=*)
        printf '%s\n' "${arg#*=}"
        return 0
        ;;
      -t)
        if ((i + 1 < ${#args[@]})); then
          printf '%s\n' "${args[i + 1]}"
          return 0
        fi
        return 1
        ;;
      -t?*)
        printf '%s\n' "${arg#-t}"
        return 0
        ;;
      --)
        stop_opts=1
        ;;
      -*)
        ;;
      *)
        positional+=("$arg")
        ;;
    esac
  done

  if ((${#positional[@]} > 0)); then
    printf '%s\n' "${positional[${#positional[@]} - 1]}"
  fi
}

__wsl_guard_collect_rm_targets() {
  local args=("$@")
  local arg
  local stop_opts=0
  local i

  for ((i = 0; i < ${#args[@]}; i++)); do
    arg="${args[i]}"

    if ((stop_opts)); then
      printf '%s\n' "$arg"
      continue
    fi

    case "$arg" in
      --)
        stop_opts=1
        ;;
      -*)
        ;;
      *)
        printf '%s\n' "$arg"
        ;;
    esac
  done
}

__wsl_guard_warn_copy_target() {
  local tool_name="$1"
  shift

  local target
  local resolved_target

  target="$(__wsl_guard_extract_copy_target "$@")"

  if [[ -n "${target:-}" ]] && __wsl_guard_is_windows_drive_path "$target"; then
    resolved_target="$(__wsl_guard_resolve_path "$target")"

    if ! __wsl_guard_confirm "${tool_name} target is on a Windows drive: ${resolved_target}"; then
      printf '%s\n' "${tool_name} cancelled."
      return 1
    fi
  fi
}

__wsl_guard_warn_rm_targets() {
  local target
  local resolved_target

  while IFS= read -r target; do
    if [[ -n "$target" ]] && __wsl_guard_is_windows_drive_path "$target"; then
      resolved_target="$(__wsl_guard_resolve_path "$target")"

      if ! __wsl_guard_confirm "rm will move a Windows-drive path to trash: ${resolved_target}"; then
        printf '%s\n' 'rm cancelled.'
        return 1
      fi

      break
    fi
  done < <(__wsl_guard_collect_rm_targets "$@")
}

__wsl_guard_safe_trash_cmd() {
  printf '%s\n' "${WSL_GUARD_USER_BIN_DIR}/safe-trash"
}
