# IMPLEMENTATION PLAN

## Active Plan

- Detailed execution plan: `docs/superpowers/plans/2026-04-19-trash-backend-redesign.md`
- Approved design source: `docs/superpowers/specs/2026-04-19-trash-backend-redesign-design.md`

## Planned Stages

### Stage 1

- Align root task docs to the trash-backend redesign
- Introduce the SQLite-backed trash backend scaffolding and schema bootstrap

Status: pending

### Stage 2

- Implement backend put/list/restore behavior with staging consistency and
  legacy import

Status: pending

### Stage 3

- Add purge, stats, bounded housekeeping, and retention configuration

Status: pending

### Stage 4

- Wire the user-layer shell wrappers and compatibility commands into the new
  backend without widening native command semantics

Status: pending

### Stage 5

- Update install/uninstall flows, user config, README, and validation coverage

Status: pending

## Validation Focus

- Static shell checks for bash/zsh scripts
- Direct backend command checks for put/list/restore/purge/stats
- Crash-consistency and orphan-reconciliation coverage
- Legacy-import coverage for pre-existing `files/` + `info/*.trashinfo`
- Interactive bash/zsh wrapper checks, including `command ...` bypass behavior
