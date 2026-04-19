# IMPLEMENTATION PLAN

## Stage 1

- Add task tracking files
- Define config layout and default values

Status: completed

## Stage 2

- Add top-level install script
- Add top-level uninstall script
- Add system uninstall script
- Add user uninstall script

Status: completed

## Stage 3

- Update system scripts to read config instead of relying on hard-coded values
- Update user scripts to read config where appropriate

Status: completed

## Stage 4

- Expand README with:
  - install flows
  - config reference
  - uninstall flows
  - FAQ
  - troubleshooting

Status: completed

## Stage 5

- Split user guard into a shared core plus shell-specific thin entry points
- Add zsh entry-point installation and uninstall support
- Update docs and task tracking for bash + zsh support

Status: completed

## Validation

- `bash -n` for all shell scripts
- `zsh -n` for zsh entry scripts
- minimal config rendering check
- user-layer install and source checks in a repo-local temporary home for bash and zsh
- `rm -> safe-trash` verification in the temporary home for bash and zsh
