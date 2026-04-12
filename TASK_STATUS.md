# TASK STATUS

## Session Start

- Date: 2026-04-12
- Objective: add config, install/uninstall flows, and stronger documentation

## Current State

- Repository now includes config files, top-level install/uninstall scripts, and per-layer uninstall scripts
- System defaults are configurable through `/etc/wsl-drive-guard/system.conf` after installation
- User defaults are configurable through `~/.config/wsl-drive-guard/user.conf` after installation
- README now covers install, uninstall, config, FAQ, and troubleshooting
- Shell syntax validation passed for all touched scripts
- User-layer Trash flow was revalidated with a custom Trash root in a temporary home

## Decisions

- Keep current default behavior as the default config
- Prefer small sourced config files over introducing a more complex parser
- Split uninstall into `system/` and `user/`, then provide top-level wrappers
- Keep system `wsl.conf` and `fstab` files as reference defaults while the installer renders from config

## Next Step

- Commit and push the enhanced toolkit update
