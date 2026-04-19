# WSL Windows-drive safety helpers for interactive zsh shells.

__wsl_guard_default_config_path="${XDG_CONFIG_HOME:-$HOME/.config}/wsl-drive-guard/user.conf"

if [[ -f "$__wsl_guard_default_config_path" ]]; then
  . "$__wsl_guard_default_config_path"
fi

: "${WSL_GUARD_USER_CONFIG_DIR:=${XDG_CONFIG_HOME:-${HOME}/.config}/wsl-drive-guard}"
: "${WSL_GUARD_USER_LIB_DIR:=${WSL_GUARD_USER_CONFIG_DIR}/lib}"

if [[ -f "${WSL_GUARD_USER_LIB_DIR}/wsl-guard-core.sh" ]]; then
  . "${WSL_GUARD_USER_LIB_DIR}/wsl-guard-core.sh"
else
  printf '%s\n' "wsl-drive-guard: missing core script at ${WSL_GUARD_USER_LIB_DIR}/wsl-guard-core.sh" >&2
  return 1
fi

typeset -g __WSL_GUARD_BASE_PROMPT="${__WSL_GUARD_BASE_PROMPT:-$PROMPT}"

__wsl_guard_format_zsh_segment() {
  local text="$1"
  local color="$2"

  printf '%%F{%s}[%s]%%f ' "$color" "$text"
}

__wsl_guard_update_prompt_zsh() {
  local prefix=""
  local session_text=""
  local drive=""
  local mode=""
  local color="yellow"

  if ((WSL_GUARD_ENABLE_PROMPT == 0)); then
    PROMPT="${__WSL_GUARD_BASE_PROMPT}"
    return
  fi

  session_text="$(__wsl_guard_session_marker_text)"
  if [[ -n "$session_text" ]]; then
    prefix+="$(__wsl_guard_format_zsh_segment "$session_text" red)"
  fi

  drive="$(__wsl_guard_current_windows_drive)"
  if [[ -n "$drive" ]]; then
    mode="$(__wsl_guard_mount_mode "$drive")"
    if [[ "$mode" == "RW" ]]; then
      color="red"
    fi
    prefix+="$(__wsl_guard_format_zsh_segment "$(__wsl_guard_drive_marker_text "$drive" "$mode")" "$color")"
  fi

  PROMPT="${prefix}${__WSL_GUARD_BASE_PROMPT}"
}

autoload -Uz add-zsh-hook

if [[ " ${precmd_functions[*]-} " != *" __wsl_guard_update_prompt_zsh "* ]]; then
  add-zsh-hook precmd __wsl_guard_update_prompt_zsh
fi

cp() {
  if ((WSL_GUARD_ENABLE_COPY_MOVE_CONFIRM)); then
    __wsl_guard_warn_copy_target cp "$@" || return $?
  fi
  command cp "$@"
}

mv() {
  if ((WSL_GUARD_ENABLE_COPY_MOVE_CONFIRM)); then
    __wsl_guard_warn_copy_target mv "$@" || return $?
  fi
  command mv "$@"
}

rm() {
  local trash_cmd

  trash_cmd="$(__wsl_guard_safe_trash_cmd)"

  if ((WSL_GUARD_ENABLE_SAFE_RM == 0)); then
    command rm "$@"
    return
  fi

  if [[ ! -x "$trash_cmd" ]]; then
    printf '%s\n' "safe-trash is missing: $trash_cmd" >&2
    return 127
  fi

  __wsl_guard_warn_rm_targets "$@" || return $?
  "$trash_cmd" "$@"
}
