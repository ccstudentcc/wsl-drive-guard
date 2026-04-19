# SPEC

## Goal

Redesign the user-layer trash flow so `wsl-drive-guard` can route common
interactive delete commands into a single SQLite-backed trash backend while
preserving the current interactive safety model.

## Scope

- Add a SQLite-backed metadata store for trash entries
- Keep trashed file contents on disk under a managed trash root
- Add a unified trash command surface for put/list/restore/purge/stats
- Keep `safe-trash`, `trash-list`, and `trash-restore` as compatibility entry
  points over the same backend
- Extend interactive shell routing from `rm` to `rmdir` and `unlink`
- Preserve native command semantics for wrapped `rmdir` and `unlink`
- Add crash-consistent staging and orphan reconciliation rules
- Add a defined legacy import path for existing `files/` + `info/*.trashinfo`
  entries
- Add lightweight retention controls and bounded housekeeping
- Update install, uninstall, config, docs, and validation to match the new
  backend

## Non-Goals

- No rewrite of the repository into Python
- No background daemon, watcher, or scheduled cleanup service
- No global interception of every deletion mechanism on the machine
- No convenience permanent-delete path added to guarded interactive wrappers
- No permanent dual-read runtime model for both SQLite metadata and legacy
  `.trashinfo` metadata

## Key Constraints

- Keep the repository shell-first
- Use SQLite as the authoritative metadata store
- Preserve Windows-drive confirmation behavior in guarded shells
- Keep `command rm`, `command rmdir`, and `command unlink` as wrapper bypasses
- Treat installed copies under `~/.local/bin` and `~/.config/wsl-drive-guard`
  as deployment targets, not source-of-truth files

## Acceptance

- `safe-trash`, `trash-list`, and `trash-restore` work through the new backend
- A new explicit trash command surface exists for put/list/restore/purge/stats
- Interactive bash and zsh wrappers cover `rm`, `rmdir`, and `unlink`
- Wrapped `rmdir` and `unlink` keep native operand and exit-status semantics
- Existing legacy trash entries become visible to the new backend through the
  defined import path
- Backend consistency rules cover staging failures, missing objects, and orphan
  objects
- Retention controls remain optional and bounded
- Install and uninstall flows manage all new user-layer files
- Docs describe the new command surface, migration behavior, and validation
- Validation covers static checks, direct backend behavior, wrapper bypasses,
  and legacy-upgrade scenarios
