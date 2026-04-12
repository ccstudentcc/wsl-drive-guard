# WSL Windows-drive safety helpers for interactive shells.

__WSL_GUARD_BASE_PS1="${__WSL_GUARD_BASE_PS1:-$PS1}"

__wsl_guard_mount_mode() {
  local drive="$1"
  local mountpoint="/mnt/${drive}"

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

__wsl_guard_prompt_prefix() {
  local session_prefix=""
  local drive
  local mode
  local color

  if [[ -n "${WSL_DRIVE_SESSION_DRIVES:-}" ]]; then
    session_prefix="\\[\\033[1;31m\\][RW-SESSION:${WSL_DRIVE_SESSION_DRIVES^^}]\\[\\033[0m\\] "
  fi

  if [[ "$PWD" =~ ^/mnt/([[:alpha:]])(/|$) ]]; then
    drive="${BASH_REMATCH[1],,}"
    mode="$(__wsl_guard_mount_mode "$drive")"
    color='33'

    if [[ "$mode" == "RW" ]]; then
      color='31'
    fi

    printf '%s\\[\\033[1;%sm\\][WIN:%s:%s]\\[\\033[0m\\] ' "$session_prefix" "$color" "${drive^^}" "$mode"
    return
  fi

  printf '%s' "$session_prefix"
}

__wsl_guard_update_prompt() {
  local prefix

  prefix="$(__wsl_guard_prompt_prefix)"
  PS1="${prefix}${__WSL_GUARD_BASE_PS1}"
}

__wsl_guard_install_prompt_hook() {
  local hook="__wsl_guard_update_prompt"

  case ";${PROMPT_COMMAND:-};" in
    *";${hook};"*)
      ;;
    ";;")
      PROMPT_COMMAND="${hook}"
      ;;
    *)
      PROMPT_COMMAND="${hook};${PROMPT_COMMAND}"
      ;;
  esac
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
  [[ "$resolved_path" =~ ^/mnt/[[:alpha:]]($|/) ]]
}

__wsl_guard_confirm() {
  local prompt="$1"
  local reply

  read -r -p "${prompt} [y/N] " reply
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

cp() {
  __wsl_guard_warn_copy_target cp "$@" || return $?
  command cp "$@"
}

mv() {
  __wsl_guard_warn_copy_target mv "$@" || return $?
  command mv "$@"
}

rm() {
  local trash_cmd="$HOME/.local/bin/safe-trash"

  if [[ ! -x "$trash_cmd" ]]; then
    printf '%s\n' "safe-trash is missing: $trash_cmd" >&2
    return 127
  fi

  __wsl_guard_warn_rm_targets "$@" || return $?
  "$trash_cmd" "$@"
}

__wsl_guard_install_prompt_hook
