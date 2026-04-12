# SPEC

## Goal

Turn `wsl-drive-guard` into a reusable toolkit that can be installed, configured,
and uninstalled cleanly on another WSL machine without editing the scripts by
hand.

## Scope

- Add repository-level configuration with sensible defaults
- Add install entry points that can install both the system layer and the user layer
- Add uninstall entry points for both layers
- Keep current default behavior unchanged unless the config is edited
- Expand the README with practical setup guidance and troubleshooting

## Non-Goals

- No GUI configuration layer
- No support for shells other than bash in this pass
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
  - install targets for `~/.bashrc.d` and `~/.local/bin`

## Acceptance

- Fresh install works through a documented install command
- Uninstall removes the installed files for this project without removing unrelated config
- Existing defaults still give:
  - read-only `C:`, `D:`, `E:`
  - `win-drive-mode`, `win-drive-session`, `win-drive-status`
  - prompt markers and interactive command safety rails
  - `safe-trash`, `trash-list`, `trash-restore`
- README documents install, uninstall, config, daily usage, and troubleshooting
