# TASK STATUS

## Session Start

- Date: 2026-04-19
- Objective: add zsh support to the user layer without duplicating bash guard logic

## Current State

- Repository now includes config files, top-level install/uninstall scripts, and per-layer uninstall scripts
- System defaults are configurable through `/etc/wsl-drive-guard/system.conf` after installation
- User defaults are configurable through `~/.config/wsl-drive-guard/user.conf` after installation
- User-layer shell support now uses a shared core plus bash and zsh entry points
- User install/uninstall now manages `~/.bashrc.d`, `~/.zshrc.d`, shared user libs, and the Trash helpers
- README now documents bash + zsh setup, including the need to load `~/.zshrc.d/*.zsh` after zsh prompt themes
- Validation passed for `bash -n`, `zsh -n`, temp-home install/load checks, and `rm -> safe-trash` in bash and zsh

## Decisions

- Keep current default behavior as the default config
- Prefer small sourced config files over introducing a more complex parser
- Split uninstall into `system/` and `user/`, then provide top-level wrappers
- Keep system `wsl.conf` and `fstab` files as reference defaults while the installer renders from config
- Do not edit a user's `~/.zshrc` automatically; install the zsh entry point and document how to load it

## Next Step

- Commit and push the bash + zsh user-layer update when ready
