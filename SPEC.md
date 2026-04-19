# SPEC

## Goal

Keep `wsl-drive-guard` reusable as a cleanly installable toolkit, while extending
the user layer from bash-only support to a shared-core design with bash and zsh
entry points.

## Scope

- Add repository-level configuration with sensible defaults
- Add install entry points that can install both the system layer and the user layer
- Add uninstall entry points for both layers
- Refactor the user guard into a shared core plus bash and zsh shell entry points
- Keep current default behavior unchanged unless the config is edited
- Expand the README with practical setup guidance and troubleshooting

## Non-Goals

- No GUI configuration layer
- No support for shells other than bash and zsh in this pass
- No change to the default Windows interop setting

## Expected Configuration Surface

- System layer:
  - managed drive list
  - mount root
  - default mount mode
  - drvfs mount options
  - install targets for helper commands
- User layer:
  - whether prompt markers are enabled
  - whether `cp` / `mv` confirmation is enabled
  - whether interactive `rm` is redirected into Trash
  - Trash directory location
  - install targets for `~/.bashrc.d`, `~/.zshrc.d`, shared user libs, and `~/.local/bin`

## Acceptance

- Fresh install works through a documented install command
- Uninstall removes the installed files for this project without removing unrelated config
- Existing defaults still give:
  - read-only `C:`, `D:`, `E:`
  - `win-drive-mode`, `win-drive-session`, `win-drive-status`
  - prompt markers and interactive command safety rails in bash and zsh
  - `safe-trash`, `trash-list`, `trash-restore`
- README documents install, uninstall, config, daily usage, and troubleshooting
