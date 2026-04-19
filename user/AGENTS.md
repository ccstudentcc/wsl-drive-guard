# User Layer Agent Guide

- Scope: everything under `user/`.
- Keep shell entrypoints in `bashrc.d/` and `zshrc.d/` thin. Shared behavior belongs in `lib/` or the trash backend surface, not duplicated across shells.
- User-facing commands in `bin/` should share one backend contract for trash operations. Do not let `rm`, `rmdir`, `unlink`, and compatibility helpers drift into separate semantics.
- When wrapping a system delete command, preserve that command's operand rules, option boundaries, and exit-status contract. Do not broaden `rmdir` or `unlink` into generic recursive trash operations just because the backend can accept wider inputs.
- Preserve the interactive safety model: guarded shell commands default to trash, Windows-mounted paths keep explicit confirmation, and `command <tool>` continues to bypass shell wrappers.
- Validate bash and zsh separately for user-layer behavior changes, and cover real wrapper behavior in both shells instead of relying on syntax-only zsh checks.
- When changing delete or trash behavior, cover the common wrapped commands plus direct helper commands in a repo-local temporary home under `tmp/`.
- If a compatibility command such as `safe-trash`, `trash-list`, or `trash-restore` is kept, test that command directly; backend and wrapper coverage alone is not enough.
- Keep install and uninstall scripts aligned with any command, config, or library path changes made in this subtree.
