# Trash Backend Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat `.trashinfo`-based user-layer trash flow with a SQLite-backed backend that preserves interactive shell safety while expanding guarded delete coverage to `rm`, `rmdir`, and `unlink`.

**Architecture:** Add a new `wsl-trash` backend command plus shared backend library and schema file under `user/`. Compatibility commands (`safe-trash`, `trash-list`, `trash-restore`) and shell wrappers become thin dispatch layers that preserve current command contracts while routing to the backend. Validation stays shell-first, using `sqlite3`, repo-owned test scripts, and temporary homes under repo-local `tmp/`.

**Tech Stack:** Bash, zsh, sqlite3, install(1), shellcheck, repo-local shell integration tests

---

## File Structure

### Existing files to modify

- `user/bin/safe-trash`
  Compatibility frontend for trash put operations.
- `user/bin/trash-list`
  Compatibility frontend for list output.
- `user/bin/trash-restore`
  Compatibility frontend for restore behavior.
- `user/lib/wsl-guard-core.sh`
  Shared shell guard helpers and wrapper dispatch logic.
- `user/bashrc.d/30-wsl-guard.sh`
  Interactive bash wrappers.
- `user/zshrc.d/30-wsl-guard.zsh`
  Interactive zsh wrappers.
- `user/install-user-guard.sh`
  Installs user-layer commands and libraries.
- `user/uninstall-user-guard.sh`
  Removes user-layer commands and libraries.
- `user/user.conf`
  User-layer defaults, including new retention settings.
- `README.md`
  User-facing behavior, migration, and command docs.
- `SPEC.md`
  Root task scope for the redesign.
- `IMPLEMENTATION_PLAN.md`
  Root execution summary pointing at this plan.
- `TASK_STATUS.md`
  Current truth and handoff state.

### New files to create

- `user/bin/wsl-trash`
  Primary backend CLI with subcommands for `put`, `import`, `list`, `restore`, `purge`, and `stats`.
- `user/lib/wsl-trash-backend.sh`
  Shared backend functions: config load, schema bootstrap, import, put, list, restore, purge, housekeeping.
- `user/lib/wsl-trash-schema.sql`
  SQLite schema and indexes for `trash_entries`, `trash_events`, and optional tags.
- `tests/user/helpers/assert.sh`
  Small shell assertions shared by test scripts.
- `tests/user/helpers/install-test-home.sh`
  Installs the user layer into a repo-local temporary home for wrapper tests.
- `tests/user/test-trash-backend.sh`
  Direct backend smoke and regression tests.
- `tests/user/test-trash-command-semantics.sh`
  `rm`/`rmdir`/`unlink` semantic preservation tests in temporary homes.
- `tests/user/test-trash-legacy-import.sh`
  Legacy `files/` + `info/*.trashinfo` import coverage.
- `tests/user/run-user-trash-tests.sh`
  Single entrypoint for repo-owned trash redesign tests.

### Runtime-only paths used during tests

- `tmp/test-home-trash-backend/`
  Temporary home for shell wrapper and install validation.
- `tmp/test-trash-root/`
  Temporary trash root for backend tests.

## Task 1: Add Backend Scaffolding And Schema Bootstrap

**Files:**
- Create: `user/bin/wsl-trash`
- Create: `user/lib/wsl-trash-backend.sh`
- Create: `user/lib/wsl-trash-schema.sql`
- Modify: `user/install-user-guard.sh`
- Modify: `user/uninstall-user-guard.sh`
- Test: `tests/user/helpers/assert.sh`
- Test: `tests/user/helpers/install-test-home.sh`
- Test: `tests/user/run-user-trash-tests.sh`

- [ ] **Step 1: Write the failing backend smoke test entrypoint**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
"${repo_root}/tests/user/test-trash-backend.sh"
```

- [ ] **Step 2: Write the first failing backend test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${repo_root}/tests/user/helpers/assert.sh"

tmp_root="${repo_root}/tmp/test-trash-root"
rm -rf "${tmp_root}"
mkdir -p "${tmp_root}"

export HOME="${repo_root}/tmp/test-home-trash-backend"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export WSL_GUARD_TRASH_ROOT="${tmp_root}"

"${repo_root}/user/bin/wsl-trash" stats >/dev/null 2>&1 || status=$?
assert_nonzero "${status:-0}" "wsl-trash stats should fail before backend exists"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash tests/user/test-trash-backend.sh`
Expected: FAIL because `user/bin/wsl-trash` does not exist yet.

- [ ] **Step 4: Add minimal backend files and schema bootstrap**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/../lib/wsl-trash-backend.sh"

subcommand="${1:-}"
shift || true

case "$subcommand" in
  stats) wsl_trash_cmd_stats "$@" ;;
  *) printf '%s\n' "wsl-trash: unsupported subcommand '${subcommand}'" >&2; exit 1 ;;
esac
```

```sql
CREATE TABLE IF NOT EXISTS trash_entries (
  id TEXT PRIMARY KEY,
  original_path TEXT NOT NULL,
  stored_path TEXT NOT NULL,
  delete_command TEXT NOT NULL,
  deleted_at TEXT NOT NULL,
  file_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  status TEXT NOT NULL,
  restore_path_last TEXT,
  restored_at TEXT,
  purged_at TEXT
);

CREATE TABLE IF NOT EXISTS trash_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  created_at TEXT NOT NULL,
  details_json TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_trash_entries_status_deleted_at
  ON trash_entries(status, deleted_at DESC);
CREATE INDEX IF NOT EXISTS idx_trash_entries_original_path
  ON trash_entries(original_path);
CREATE INDEX IF NOT EXISTS idx_trash_entries_delete_command_deleted_at
  ON trash_entries(delete_command, deleted_at DESC);
CREATE INDEX IF NOT EXISTS idx_trash_events_entry_id_created_at
  ON trash_events(entry_id, created_at);
```

- [ ] **Step 5: Install the new backend files**

Update `user/install-user-guard.sh` and `user/uninstall-user-guard.sh` so they manage:

```bash
install -m 0644 "${SCRIPT_DIR}/lib/wsl-trash-backend.sh" "${WSL_GUARD_USER_LIB_DIR}/wsl-trash-backend.sh"
install -m 0644 "${SCRIPT_DIR}/lib/wsl-trash-schema.sql" "${WSL_GUARD_USER_LIB_DIR}/wsl-trash-schema.sql"
install -m 0755 "${SCRIPT_DIR}/bin/wsl-trash" "${WSL_GUARD_USER_BIN_DIR}/wsl-trash"
```

Also add a reusable temp-home install helper:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_home="$1"

export HOME="${test_home}"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"

mkdir -p "${HOME}"
"${repo_root}/user/install-user-guard.sh"
```

- [ ] **Step 6: Flip the smoke test from red to green**

Replace the failing assertion in `tests/user/test-trash-backend.sh` with:

```bash
"${repo_root}/user/bin/wsl-trash" stats >/dev/null
assert_file_exists "${tmp_root}/db/trash.sqlite3" "stats should bootstrap the sqlite database"
```

- [ ] **Step 7: Re-run the backend test**

Run: `bash tests/user/test-trash-backend.sh`
Expected: PASS for `wsl-trash stats` bootstrap and database creation.

- [ ] **Step 8: Run static checks for the new files**

Run: `bash -n user/bin/wsl-trash user/lib/wsl-trash-backend.sh user/install-user-guard.sh user/uninstall-user-guard.sh`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add user/bin/wsl-trash user/lib/wsl-trash-backend.sh user/lib/wsl-trash-schema.sql \
  user/install-user-guard.sh user/uninstall-user-guard.sh \
  tests/user/helpers/assert.sh tests/user/helpers/install-test-home.sh \
  tests/user/test-trash-backend.sh tests/user/run-user-trash-tests.sh
git commit -m "feat(user): scaffold sqlite-backed trash backend"
```

## Task 2: Implement `put` With Staging And Legacy Import

**Files:**
- Modify: `user/bin/wsl-trash`
- Modify: `user/lib/wsl-trash-backend.sh`
- Modify: `user/lib/wsl-trash-schema.sql`
- Modify: `user/bin/safe-trash`
- Test: `tests/user/test-trash-backend.sh`
- Test: `tests/user/test-trash-legacy-import.sh`

- [ ] **Step 1: Add failing tests for `put` and legacy import**

```bash
test_put_moves_file_into_objects_and_writes_active_row
test_put_moves_directory_into_objects_and_writes_active_row
test_put_moves_symlink_into_objects_and_writes_active_row
test_put_creates_staging_row_before_activation
test_legacy_import_makes_existing_trashinfo_visible
test_manual_import_picks_up_late_legacy_entries
test_stale_staging_row_is_reconciled_on_backend_init
```

Expected checks:

- object moves under `${WSL_GUARD_TRASH_ROOT}/objects/YYYY/MM/<entry-id>`
- SQLite row ends in `status='active'`
- file, directory, and symlink payloads all round-trip through the backend
- imported legacy rows appear in `wsl-trash list`
- a manual `wsl-trash import` command picks up later legacy entries
- stale `staging` rows or staged objects are reconciled on backend init

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bash tests/user/test-trash-backend.sh
bash tests/user/test-trash-legacy-import.sh
```

Expected: FAIL because `put`, manual import, and staging recovery do not exist yet.

- [ ] **Step 3: Implement staging, activation, and import helpers**

Add backend functions with responsibilities:

```bash
wsl_trash_backend_init
wsl_trash_import_legacy_if_needed
wsl_trash_import_legacy
wsl_trash_put_targets
wsl_trash_insert_staging_row
wsl_trash_activate_entry
wsl_trash_record_event
wsl_trash_reconcile_staging_entries
```

Key implementation constraints:

- allocate entry id before moving the object
- insert `status='staging'` row first
- move target into `${trash_root}/tmp/<entry-id>.staging`
- rename into final `objects/YYYY/MM/<entry-id>`
- update row to `status='active'`
- record `trashed` event
- on backend init, reconcile stale `staging` rows and staged objects before
  serving normal commands
- expose a manual `wsl-trash import` path for later legacy discovery after
  first-start migration

- [ ] **Step 4: Rework `safe-trash` into a compatibility frontend**

Make `safe-trash` parse its current CLI surface, then dispatch:

```bash
exec "${WSL_GUARD_USER_BIN_DIR}/wsl-trash" put --source-command=safe-trash "$@"
```

Preserve existing accepted option forms: `-f`, `-i`, `-I`, `-r`, `-R`, `-d`, `-v`.

- [ ] **Step 5: Re-run direct backend and import tests**

Run:

```bash
bash tests/user/test-trash-backend.sh
bash tests/user/test-trash-legacy-import.sh
```

Expected: PASS for object move, staging activation, stale-staging recovery,
one-time legacy import visibility, and manual re-import.

- [ ] **Step 6: Run sqlite schema sanity checks**

Run:

```bash
sqlite3 tmp/test-trash-root/db/trash.sqlite3 ".schema trash_entries"
sqlite3 tmp/test-trash-root/db/trash.sqlite3 ".schema trash_events"
sqlite3 tmp/test-trash-root/db/trash.sqlite3 ".indexes trash_entries"
sqlite3 tmp/test-trash-root/db/trash.sqlite3 ".indexes trash_events"
sqlite3 tmp/test-trash-root/db/trash.sqlite3 "select status,count(*) from trash_entries group by status;"
```

Expected: schema prints cleanly; required indexes exist; imported or trashed rows appear with expected statuses.

- [ ] **Step 7: Commit**

```bash
git add user/bin/wsl-trash user/lib/wsl-trash-backend.sh user/lib/wsl-trash-schema.sql \
  user/bin/safe-trash tests/user/test-trash-backend.sh tests/user/test-trash-legacy-import.sh
git commit -m "feat(user): implement staged trash put and legacy import"
```

## Task 3: Implement List, Restore, Selector Contract, And Broken-State Handling

**Files:**
- Modify: `user/bin/wsl-trash`
- Modify: `user/lib/wsl-trash-backend.sh`
- Modify: `user/bin/trash-list`
- Modify: `user/bin/trash-restore`
- Test: `tests/user/test-trash-backend.sh`

- [ ] **Step 1: Add failing tests for list and restore behavior**

```bash
test_list_shows_entry_id_deletion_date_status_and_original_path
test_list_all_shows_missing_and_corrupt_entries
test_restore_by_entry_id_restores_to_original_path
test_restore_creates_missing_parent_directories
test_restore_conflict_renames_target
test_missing_object_becomes_missing_state
test_ambiguous_non_id_selector_fails
test_restore_writes_restore_metadata_and_events
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/user/test-trash-backend.sh`
Expected: FAIL because list and restore behavior are incomplete.

- [ ] **Step 3: Implement `list` and `restore` backend subcommands**

Required output contract:

```text
ENTRY ID  DELETION DATE  STATUS  ORIGINAL PATH
```

Required selector contract:

- `trash-restore` restores by entry id
- ambiguous selector support is not implicit
- `wsl-trash list --all` must surface `missing` / `corrupt` rows for
  maintenance visibility

Required restore conflict behavior:

```bash
<original>.restored.<timestamp>.<n>
```

Required metadata updates:

- `restore_path_last` stores the final restore target
- `restored_at` is populated on successful restore
- restore operations write `restored` and, when applicable,
  `restore_conflict_renamed` events

- [ ] **Step 4: Convert compatibility commands into thin wrappers**

Examples:

```bash
exec "${WSL_GUARD_USER_BIN_DIR}/wsl-trash" list "$@"
exec "${WSL_GUARD_USER_BIN_DIR}/wsl-trash" restore "$@"
```

- [ ] **Step 5: Add broken-state reconciliation**

Implement bounded housekeeping helpers that:

- mark rows as `missing` when the object vanished
- quarantine orphaned staged/final objects into `corrupt` rows or reconstructed rows
- record `housekeeping_reconciled_missing_object` or equivalent event

- [ ] **Step 6: Re-run tests**

Run: `bash tests/user/test-trash-backend.sh`
Expected: PASS for list columns, restore-by-id, conflict rename, and broken-state visibility.

- [ ] **Step 7: Commit**

```bash
git add user/bin/wsl-trash user/lib/wsl-trash-backend.sh user/bin/trash-list user/bin/trash-restore \
  tests/user/test-trash-backend.sh
git commit -m "feat(user): add sqlite-backed list and restore flows"
```

## Task 4: Add Purge, Stats, Retention, And Housekeeping Boundaries

**Files:**
- Modify: `user/bin/wsl-trash`
- Modify: `user/lib/wsl-trash-backend.sh`
- Modify: `user/user.conf`
- Test: `tests/user/test-trash-backend.sh`

- [ ] **Step 1: Add failing tests for purge, stats, and retention**

```bash
test_stats_reports_active_missing_corrupt_counts
test_purge_by_entry_id_removes_object_and_marks_row_purged
test_purge_by_older_than_respects_retention_cutoff
test_retention_max_bytes_trims_oldest_entries_with_bounded_work
test_purge_writes_purged_metadata_and_events
test_purge_missing_and_corrupt_entries
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/user/test-trash-backend.sh`
Expected: FAIL because purge and retention are not implemented.

- [ ] **Step 3: Extend config defaults**

Add to `user/user.conf`:

```bash
WSL_GUARD_TRASH_RETENTION_DAYS="${WSL_GUARD_TRASH_RETENTION_DAYS:-0}"
WSL_GUARD_TRASH_MAX_BYTES="${WSL_GUARD_TRASH_MAX_BYTES:-0}"
WSL_GUARD_TRASH_HOUSEKEEPING_BATCH="${WSL_GUARD_TRASH_HOUSEKEEPING_BATCH:-20}"
```

- [ ] **Step 4: Implement backend subcommands**

Required subcommands:

```text
wsl-trash purge --entry-id <id>
wsl-trash purge --older-than <days>
wsl-trash purge --max-bytes <bytes>
wsl-trash stats
```

Required behavior:

- purge removes object payloads and marks rows `purged`
- housekeeping never scans or purges unboundedly in one command
- retention checks run after successful `put`
- purge updates `purged_at` and records `purged` events in SQLite
- purge must also work for `missing` / `corrupt` entries exposed through
  maintenance workflows

- [ ] **Step 5: Re-run backend tests**

Run: `bash tests/user/test-trash-backend.sh`
Expected: PASS for purge, stats, retention, and bounded housekeeping.

- [ ] **Step 6: Commit**

```bash
git add user/bin/wsl-trash user/lib/wsl-trash-backend.sh user/user.conf tests/user/test-trash-backend.sh
git commit -m "feat(user): add purge and retention controls"
```

## Task 5: Wire Shell Wrappers Without Widening Native Command Semantics

**Files:**
- Modify: `user/lib/wsl-guard-core.sh`
- Modify: `user/bashrc.d/30-wsl-guard.sh`
- Modify: `user/zshrc.d/30-wsl-guard.zsh`
- Modify: `tests/user/helpers/install-test-home.sh`
- Test: `tests/user/test-trash-command-semantics.sh`

- [ ] **Step 1: Add failing shell semantics tests**

Cover:

- the same routing matrix runs under both bash and zsh
- interactive `rm` routes to backend
- interactive `rmdir` only succeeds for empty directories
- interactive `rmdir nonempty-dir` still fails like native `rmdir`
- interactive `unlink` only accepts a single non-directory path
- `command rm`, `command rmdir`, `command unlink` bypass wrappers
- `WSL_GUARD_ENABLE_SAFE_RM=0` falls back to native command behavior
- Windows-mounted path confirmations still fire before backend dispatch
- repo-local temporary homes install the user layer before sourcing shell
  entrypoints

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/user/test-trash-command-semantics.sh`
Expected: FAIL because only `rm` is wrapped today.

- [ ] **Step 3: Make the temp-home harness installable before wrapper assertions**

Use `tests/user/helpers/install-test-home.sh` so shell tests source installed
files under the temporary `HOME` rather than raw repo files.

- [ ] **Step 4: Add shared dispatch helpers**

Implement thin helpers in `user/lib/wsl-guard-core.sh` such as:

```bash
__wsl_guard_trash_backend_cmd
__wsl_guard_wrap_rm
__wsl_guard_wrap_rmdir
__wsl_guard_wrap_unlink
```

Requirements:

- `rmdir` wrapper must pre-check emptiness or delegate in a way that preserves native failure
- `unlink` wrapper must reject directories and multiple operands exactly as native use expects

- [ ] **Step 5: Update bash and zsh entrypoints**

Add wrapper functions for:

```bash
rmdir() { ... }
unlink() { ... }
```

but keep:

```bash
command rmdir ...
command unlink ...
```

as explicit bypasses.

- [ ] **Step 6: Re-run shell semantics tests**

Run: `bash tests/user/test-trash-command-semantics.sh`
Expected: PASS for wrapper routing, bypasses, and native semantic preservation.

- [ ] **Step 7: Run syntax checks**

Run:

```bash
bash -n user/lib/wsl-guard-core.sh user/bashrc.d/30-wsl-guard.sh
zsh -n user/zshrc.d/30-wsl-guard.zsh
```

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add user/lib/wsl-guard-core.sh user/bashrc.d/30-wsl-guard.sh user/zshrc.d/30-wsl-guard.zsh \
  tests/user/helpers/install-test-home.sh tests/user/test-trash-command-semantics.sh
git commit -m "feat(user): extend guarded shell delete wrappers"
```

## Task 6: Finish Packaging, Docs, And End-To-End Validation

**Files:**
- Modify: `README.md`
- Modify: `TASK_STATUS.md`
- Modify: `AGENTS.md`
- Modify: `user/AGENTS.md`
- Modify: `tests/user/run-user-trash-tests.sh`
- Test: `tests/user/test-trash-backend.sh`
- Test: `tests/user/test-trash-command-semantics.sh`
- Test: `tests/user/test-trash-legacy-import.sh`

- [ ] **Step 1: Add failing install and documentation checks**

Create assertions that a fresh repo-local install places:

- `wsl-trash`
- updated compatibility commands
- backend library files
- updated config defaults

into the temporary home layout.

- [ ] **Step 2: Update README for the new backend**

Document:

- new `wsl-trash` command surface
- compatibility command behavior
- legacy import rule
- retention configuration
- wrapper semantics for `rm` / `rmdir` / `unlink`

- [ ] **Step 3: Re-run the full user-layer validation suite**

Before running final validation, expand `tests/user/run-user-trash-tests.sh` into
the full suite entrypoint so it executes:

- `tests/user/test-trash-backend.sh`
- `tests/user/test-trash-command-semantics.sh`
- `tests/user/test-trash-legacy-import.sh`

Run:

```bash
bash tests/user/run-user-trash-tests.sh
bash -n user/bin/* user/lib/*.sh user/install-user-guard.sh user/uninstall-user-guard.sh
zsh -n user/zshrc.d/30-wsl-guard.zsh
shellcheck user/bin/* user/lib/*.sh user/bashrc.d/30-wsl-guard.sh user/install-user-guard.sh user/uninstall-user-guard.sh
```

Expected: PASS

- [ ] **Step 4: Update task docs and AGENTS guidance only for durable findings**

Do not append history. Rewrite `TASK_STATUS.md` to current truth.
Run the repo’s stage-end `agents-md-improver` loop and only keep stable local rules.

- [ ] **Step 5: Commit**

```bash
git add README.md TASK_STATUS.md AGENTS.md user/AGENTS.md tests/user/run-user-trash-tests.sh \
  tests/user/test-trash-backend.sh tests/user/test-trash-command-semantics.sh tests/user/test-trash-legacy-import.sh
git commit -m "docs(user): finalize trash backend redesign rollout"
```

## Final Verification Checklist

- [ ] `bash tests/user/run-user-trash-tests.sh`
- [ ] `bash -n user/bin/* user/lib/*.sh user/install-user-guard.sh user/uninstall-user-guard.sh`
- [ ] `zsh -n user/zshrc.d/30-wsl-guard.zsh`
- [ ] `shellcheck user/bin/* user/lib/*.sh user/bashrc.d/30-wsl-guard.sh user/install-user-guard.sh user/uninstall-user-guard.sh`
- [ ] Verify `wsl-trash list` shows `ENTRY ID`, `DELETION DATE`, `STATUS`, and `ORIGINAL PATH`
- [ ] Verify `wsl-trash list --all` shows `missing` / `corrupt` entries for maintenance workflows
- [ ] Verify `wsl-trash purge --entry-id` can purge `missing` / `corrupt` entries shown by `--all`
- [ ] Verify `trash-restore <entry-id>` restores by id and rename-conflicts append `.restored.<timestamp>.<n>`
- [ ] Verify restore creates missing parent directories and updates `restore_path_last` / `restored_at`
- [ ] Verify restore and conflict cases insert the expected SQLite events
- [ ] Verify pre-existing legacy trash entries are imported into SQLite on first backend startup
- [ ] Verify `wsl-trash import` can pull in legacy entries created after first-start migration
- [ ] Verify stale `staging` rows or staged objects are reconciled on backend init
- [ ] Verify directory and symlink payloads survive put/list/restore
- [ ] Verify purge updates `purged_at` and inserts `purged` events
- [ ] Verify `safe-trash` still accepts and forwards its current option forms such as `-f`, `-i`, `-I`, `-d`, and `-v`
- [ ] Verify `trash-list` remains a working compatibility entrypoint over the same backend data as `wsl-trash list`
- [ ] Verify `command rm`, `command rmdir`, and `command unlink` bypass wrappers
- [ ] Verify the routing and bypass matrix under both bash and zsh
- [ ] Verify `WSL_GUARD_ENABLE_SAFE_RM=0` restores native fallback behavior
