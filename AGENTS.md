# WSL Drive Guard Agent Guide

- Scope: this repository packages a shell-first WSL toolkit with a `system/` layer for mount behavior and a `user/` layer for interactive shell guards and trash helpers.
- Read this file, `README.md`, and `TASK_STATUS.md` before editing. When an active design exists under `docs/superpowers/specs/`, treat that approved design doc as the current feature-level source of truth until the implementation plan is rewritten for it.
- `system/` changes affect rendered files, install scripts, and sudo-managed commands. `user/` changes affect interactive shell entrypoints, shared shell logic, and user-facing helper commands.
- Edit repository sources, not installed copies under `/etc/wsl-drive-guard`, `~/.config/wsl-drive-guard`, or `~/.local/bin`.
- For non-trivial behavior changes, write or update a design doc under `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` before implementation planning.
- Before moving from a written design doc to an implementation plan, send the design doc to a `reviewer` subagent and resolve or record the findings.
- When an implementation plan exists under `docs/superpowers/plans/`, treat the approved plan as the execution source of truth for coding work and keep the root task docs aligned to it.
- Before starting implementation from a new plan, send that plan to a `reviewer` subagent and resolve or record the findings.
- When the user explicitly asks for delegation or subagents and the approved plan has bounded, non-overlapping tasks, prefer a Subagent-Driven workflow: dispatch one fresh subagent per task, keep write scopes disjoint, then review and integrate on the main thread between tasks.
- Keep blocking synthesis, scope changes, shared-file integration, and any overlapping-write work on the main thread instead of parallelizing for appearance.
- At the end of each completed stage, run the `agents-md-improver` decision loop: add or refine the nearest `AGENTS.md` only for durable, repo-local rules; keep one-off observations in task docs instead.
- Keep repository task docs current. Rewrite stale sections in `SPEC.md`, `IMPLEMENTATION_PLAN.md`, and `TASK_STATUS.md` when the active task changes instead of appending another historical layer.
- Validation should stay as small as possible but honest. For user-layer behavior changes, prefer repo-local temporary-home checks before touching real home config.
