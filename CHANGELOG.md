# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project uses a simple
date-based unreleased section until versioning becomes useful.

## [Unreleased]

### Added

- top-level `install.sh` and `uninstall.sh`
- system-layer uninstall flow
- user-layer uninstall flow
- configurable `system/system.conf`
- configurable `user/user.conf`
- expanded README with install, uninstall, FAQ, and troubleshooting
- task tracking files: `SPEC.md`, `IMPLEMENTATION_PLAN.md`, `TASK_STATUS.md`

## 2026-04-12

### Added

- initial reusable packaging for WSL Drive Guard
- system tools for read-only Windows drive mounting and temporary writable sessions
- user shell guard for prompt markers, copy/move confirmation, and Trash-based delete flow
- Trash inspection and restore helpers
