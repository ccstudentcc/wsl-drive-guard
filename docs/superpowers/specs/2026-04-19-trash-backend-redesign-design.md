# Trash Backend Redesign

Date: 2026-04-19
Repository: `wsl-drive-guard`
Status: proposed design

## Summary

Redesign the user-layer trash flow so that common interactive delete commands
route into a single SQLite-backed trash backend instead of relying on ad hoc
shell wrappers plus flat `.trashinfo` metadata files.

The new design keeps the current safety posture:

- interactive shell deletes should default to trash instead of permanent removal
- Windows-mounted paths should keep their extra confirmation behavior
- users should keep familiar commands such as `rm`

The redesign adds three things that the current implementation does not handle
well enough:

1. broader command routing for common delete entry points
2. indexed metadata for fast listing and reliable restore
3. lightweight retention controls so trash data does not grow without bounds

## Goals

- Route common interactive delete commands through one backend
- Replace flat trash metadata files with a SQLite-backed source of truth
- Keep file contents on disk while indexing metadata separately
- Make `list`, `restore`, and future `purge` operations scale better as entry
  count grows
- Preserve current interactive-shell ergonomics for `rm`
- Add a light retention model without introducing a daemon or background service

## Non-Goals

- No full rewrite of the repository into Python
- No attempt to intercept every deletion mechanism on the machine
- No forced compatibility with the current `.trashinfo` layout as a primary data
  model
- No background watcher, cron-like scheduler, or always-on cleanup process
- No permanent-delete shortcut in the guarded interactive wrappers during this
  pass

## Current Problems

The current user layer has a useful safety baseline, but the implementation is
still too shallow for long-term use:

- `rm` is redirected to `safe-trash`, but `rmdir` and `unlink` are not
- trash metadata is stored as one sidecar file per entry, so list and restore
  behavior depends on filesystem traversal and repeated text parsing
- the current layout does not provide a durable event history or indexed lookup
- cleanup policy is manual and underdefined
- command behavior is spread across thin shell wrappers and standalone scripts
  without a strong shared backend boundary

## Proposed Architecture

Split the user-layer trash system into two layers.

### 1. Interactive entry layer

Keep shell integration in the existing bash and zsh entry files, but narrow
their responsibility to:

- deciding whether the current shell session should intercept a command
- preserving interactive confirmations for Windows-mounted paths
- forwarding normalized arguments to the shared trash backend
- falling back to the system command when the guard is disabled or the user
  explicitly bypasses shell wrappers

### 2. Trash backend layer

Turn the trash commands into thin frontends over one SQLite-backed backend.

The backend should become the only component responsible for:

- creating trash entries
- generating stable entry ids and storage paths
- moving objects into managed storage
- recording and querying metadata
- restoring objects
- purging objects
- running low-cost housekeeping

## Storage Layout

Use a managed trash root with explicit object storage and an indexed metadata
store.

```text
$WSL_GUARD_TRASH_ROOT/
  objects/
    2026/04/<entry-id>
  db/
    trash.sqlite3
  tmp/
```

### Layout rules

- `objects/` stores the real deleted files and directories
- objects are bucketed by year and month to avoid very large flat directories
- `db/trash.sqlite3` is the single metadata source of truth
- `tmp/` is reserved for restore staging and maintenance operations

The backend may create the storage root lazily on first use.

## Command Routing

The redesign should support a medium-scope routing model:

- keep `rm` interception in interactive bash and zsh shells
- add interactive wrappers for `rmdir`
- add interactive wrappers for `unlink`
- provide an explicit trash command surface for direct use
- do not override the entire `gio` command

### Direct user-facing commands

Keep compatibility names, but treat them as thin aliases or wrappers around the
same backend behavior:

- `safe-trash`
- `trash-list`
- `trash-restore`

Add a single explicit command surface for future subcommands. The exact command
name can be chosen during implementation, but the intended shape is:

```text
wsl-trash put
wsl-trash list
wsl-trash restore
wsl-trash purge
wsl-trash stats
```

### Wrapper behavior

- interactive `rm`, `rmdir`, and `unlink` should route to the backend when
  `WSL_GUARD_ENABLE_SAFE_RM=1`
- `command rm`, `command rmdir`, and `command unlink` should still bypass shell
  wrappers
- non-interactive scripts should not gain implicit wrapper behavior from this
  change
- Windows-mounted paths should keep the existing extra confirmation before the
  backend runs
- when the guard is disabled, wrappers should fall back to the system command
- wrapped commands must preserve the original command contract for accepted
  operands, option handling, and exit status rather than widening semantics just
  because the backend can store more object types
- interactive `rmdir` may only trash directories that already satisfy native
  `rmdir` success conditions; non-empty directories must still fail as native
  `rmdir` would
- interactive `unlink` must keep the single-path, non-directory contract of the
  native command

### `gio trash` compatibility

Do not replace `gio` globally. If compatibility is needed, provide a local thin
wrapper command or alias shape that maps trash-like behavior into the backend
without shadowing unrelated `gio` subcommands.

## Metadata Model

SQLite becomes the only authoritative metadata store. File contents remain on
disk under `objects/`.

### Core table: `trash_entries`

One row per trashed object.

Recommended fields:

- `id` primary key
- `original_path`
- `stored_path`
- `delete_command`
- `deleted_at`
- `file_type`
- `size_bytes`
- `status`
- `restore_path_last`
- `restored_at`
- `purged_at`

Recommended status values:

- `staging`
- `active`
- `restored`
- `purged`
- `missing`
- `corrupt`

### Event table: `trash_events`

Record state changes and notable operations so later inspection can explain
backend decisions.

Recommended event kinds:

- `trashed`
- `restore_conflict_renamed`
- `restored`
- `purged`
- `housekeeping_reconciled_missing_object`

Recommended fields:

- `id`
- `entry_id`
- `event_type`
- `created_at`
- `details_json`

### Optional tag table: `trash_tags`

This table is not required for the first command surface, but it is worth
reserving for future filtering if implementation cost stays low.

Potential uses:

- `windows-drive`
- `interactive-shell`
- `rw-session`

## Indexing Strategy

Add indexes that support the expected hot paths:

- `trash_entries(status, deleted_at desc)` for active listing
- `trash_entries(original_path)` for restore lookup and diagnostics
- `trash_entries(delete_command, deleted_at desc)` for usage inspection
- `trash_events(entry_id, created_at)` for history lookup

The backend should query SQLite first and avoid directory-wide scans for normal
listing and restore behavior.

## Entry Id and Object Naming

Use a stable backend-generated entry id rather than relying on the original
basename as the primary identity.

Desired properties:

- sortable enough for recent-first inspection
- unique without repeated filesystem probing
- readable enough for debugging

A timestamp-prefixed id with a short random suffix is sufficient.

The object storage path should derive from the entry id rather than the original
filename. The original filename stays in metadata.

## Put Consistency Protocol

Normal `put` operations need an explicit crash-consistency contract because the
filesystem move and SQLite writes cannot be one atomic operation.

Required write flow:

1. allocate an entry id and create a `staging` row in SQLite
2. move the original target into a staging location under
   `$WSL_GUARD_TRASH_ROOT/tmp/`
3. atomically rename the staged object into its final `objects/` path
4. update the row to `active` and append the `trashed` event

Housekeeping must reconcile both failure directions:

- a row exists but its staged or final object is missing
- a staged or final object exists but the expected row is missing

If the backend finds an object without a valid row, it must not silently ignore
it. The recovery path must either:

- reattach it to a reconstructed row, or
- quarantine it and create a `corrupt` row that keeps the object visible for
  later manual handling

If the backend finds an `active` row whose object disappeared, it should move
the row to `missing` and record the housekeeping event.

## Restore Semantics

Default restore behavior:

- restore to `original_path` when free
- if the target path already exists, restore to an automatically renamed path
- record the rename decision in `trash_events`
- update `restore_path_last` in `trash_entries`

Suggested conflict naming pattern:

```text
<original>.restored.<timestamp>.<n>
```

Restore should create parent directories when needed.

## CLI Selection Contract

The redesign changes entry identity from basename-driven storage to backend
entry ids, so the external CLI contract must stay explicit.

Default user-facing shape:

- `trash-list` displays at least `ENTRY ID`, `DELETION DATE`, `STATUS`, and
  `ORIGINAL PATH`
- `trash-restore` restores by `entry-id`
- if future selector forms are added, ambiguous selectors must fail loudly
  rather than restoring an arbitrary match

Compatibility command names remain:

- `safe-trash`
- `trash-list`
- `trash-restore`

Compatibility of old operand shapes is not implicit. If imported legacy entries
need name-based lookup during migration, that behavior must be an explicit
selector mode rather than undocumented fallback matching.

## Cleanup and Retention

Cleanup should stay lightweight and explicit by default.

### Passive housekeeping

Run a low-cost reconciliation step after normal backend commands such as put,
restore, or list.

This step should only:

- reconcile rows marked purged whose objects are already gone
- move active rows whose stored object is unexpectedly missing into `missing`
- keep work bounded so one command does not turn into a full cleanup pass

Rows in `missing` or `corrupt` state should remain visible to maintenance
commands. Normal `trash-list` may default to active rows only, but maintenance
commands or `--all` output must let users inspect and purge broken entries.

### Explicit purge operations

Support direct purge commands such as:

- purge by entry id
- purge by age
- purge by total retained size

The first implementation only needs age-based and size-based retention controls.

### Light automatic retention

Add optional config values:

- `WSL_GUARD_TRASH_RETENTION_DAYS`
- `WSL_GUARD_TRASH_MAX_BYTES`

Default both to `0`, meaning disabled.

If enabled, the backend may run a bounded cleanup after successful trash writes:

- process the oldest active entries first
- cap the number of entries processed in one invocation
- stop early when limits are satisfied

This keeps retention cheap and predictable without a background service.

## Configuration Surface

Retain the existing user-layer config style and extend it only where needed.

Existing values that still apply:

- `WSL_GUARD_ENABLE_SAFE_RM`
- `WSL_GUARD_WINDOWS_MOUNT_ROOT`
- `WSL_GUARD_TRASH_ROOT`
- `WSL_GUARD_USER_BIN_DIR`

New values proposed:

- `WSL_GUARD_TRASH_RETENTION_DAYS`
- `WSL_GUARD_TRASH_MAX_BYTES`

If implementation needs one more knob, prefer a bounded maintenance parameter
such as max entries processed per housekeeping run rather than many low-level
flags.

## Migration Direction

The migration boundary is part of the design, not an implementation afterthought.

Chosen migration rule:

- the SQLite backend becomes the only authoritative runtime metadata store
- on first backend startup against an existing trash root, the backend must
  import legacy `files/` + `info/*.trashinfo` entries into SQLite before normal
  list, restore, or put operations proceed
- imported legacy entries may keep their existing stored objects in place during
  migration, but they must become visible through the new SQLite-backed
  `trash-list` and `trash-restore` flow immediately after import
- after migration, entries created by external tools directly under legacy
  `files/` + `info/` are outside the supported visibility contract unless an
  explicit import command is run again

To make that boundary explicit, the implementation should provide a manual
re-import command for later legacy discovery, but normal backend behavior should
not silently dual-read both metadata systems forever.

## Validation Strategy

Validation should cover both shell routing and backend consistency.

### Static checks

- `bash -n` on all shell scripts
- `zsh -n` on zsh entry scripts
- `shellcheck` on user-layer scripts where practical

### Backend behavior

- put file
- put directory
- put symlink
- list entries from SQLite
- restore without conflict
- restore with rename conflict
- purge by id
- bounded housekeeping behavior
- crash-recovery behavior for rows left in `staging`
- orphan-object reconciliation for staged or final objects that exist without a
  valid row
- upgrade import of pre-existing legacy `files/` + `info/*.trashinfo` entries

### Shell routing

In temporary test homes for both bash and zsh:

- interactive `rm` routes to the backend
- interactive `rmdir` routes to the backend
- interactive `unlink` routes to the backend
- `command rm` bypasses wrappers
- `command rmdir` bypasses wrappers
- `command unlink` bypasses wrappers
- guard-disabled mode falls back to system commands

### Windows-drive confirmations

Existing confirmation behavior for Windows-mounted paths must remain intact.
Validation should cover at least one guarded Windows-drive delete flow so the
backend change does not weaken that safety boundary.

## Implementation Notes

- Keep shell wrappers thin and move real logic downward
- Prefer a single backend contract that all trash frontends call
- Keep dangerous bypass behavior explicit rather than convenient
- Do not add a background daemon
- Keep the repository shell-first; SQLite is the only new foundational
  dependency expected in this design

## Open Decision For Planning

The following item should be settled in the implementation plan, not ad hoc in
code:

- which migration path to use for pre-existing `.trashinfo` entries

Everything else in this design is intended to be specific enough to implement
without broad architectural rework.
