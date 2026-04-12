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

## Validation

- `bash -n` for all shell scripts
- minimal config rendering check
- install/uninstall dry-run style checks where possible without mutating the live system
