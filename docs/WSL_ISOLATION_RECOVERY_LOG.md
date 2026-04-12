# WSL Windows Drive Isolation Recovery Log

Date: 2026-04-12
Host: `chenpeng@Peng`
Environment: WSL on Ubuntu 24.04

## Goal

Restore the previous WSL "isolated mount mode" setup with the same behavior:

- Disable automatic Windows drive mounting in WSL
- Let `/etc/fstab` define the default mount policy
- Mount existing `C:`, `D:`, `E:` under `/mnt/*` as read-only by default
- Provide `win-drive-mode rw <drive>` and `win-drive-mode ro <drive>` for temporary switching
- Provide `win-drive-session rw <drive>` for a temporary writable sub-shell that auto-restores `ro`
- Provide `win-drive-status` to inspect current `/mnt/*` mount states
- Add interactive-shell safety rails for `/mnt/*` work:
  - prompt marker while inside Windows drives
  - confirmation before `cp` and `mv` target `/mnt/*`
  - `rm` redirected to Trash instead of direct deletion

## Current Package Location

All recovery files were rebuilt under:

- `/home/chenpeng/tmp/wsl-isolation/install-wsl-isolation.sh`
- `/home/chenpeng/tmp/wsl-isolation/wsl.conf`
- `/home/chenpeng/tmp/wsl-isolation/fstab`
- `/home/chenpeng/tmp/wsl-isolation/win-drive-mode`
- `/home/chenpeng/tmp/wsl-isolation/win-drive-session`
- `/home/chenpeng/tmp/wsl-isolation/win-drive-status`

User-level safety helpers were added at:

- `/home/chenpeng/.bashrc.d/30-wsl-guard.sh`
- `/home/chenpeng/.local/bin/safe-trash`
- `/home/chenpeng/.local/bin/win-drive-session`
- `/home/chenpeng/.local/bin/trash-list`
- `/home/chenpeng/.local/bin/trash-restore`

## What Was Found

The previous isolation setup had been removed from the live system:

- `/etc/wsl.conf` still existed, but it was a normal config with automount enabled
- `/etc/fstab` was still the default `# UNCONFIGURED FSTAB FOR BASE SYSTEM`
- `win-drive-mode` and `win-drive-status` were no longer in `PATH`

At the same time, the current session already showed these mounts as read-only:

- `/mnt/c`
- `/mnt/d`
- `/mnt/e`

## Rebuilt Files

### `wsl.conf`

The rebuilt config is focused on mount isolation:

```ini
[automount]
enabled=false
mountFsTab=true
root=/mnt/
options="metadata,umask=22,fmask=11"
```

The installer is designed to preserve the existing non-automount sections already present in `/etc/wsl.conf`, such as:

- `[boot]`
- `[network]`
- `[user]`
- `[interop]`

### `fstab`

The rebuilt `fstab` template mounts `C:`, `D:`, `E:` read-only by default and lets the installer replace `uid/gid` with the current Linux user values at install time.

### `win-drive-mode`

Features:

- Supports `ro` and `rw`
- Accepts one or more drive letters
- Uses `sudo mount -o remount,...` when the drive is already mounted
- Falls back to `sudo mount -t drvfs ...` when the mount does not yet exist

Examples:

```bash
win-drive-mode rw c
win-drive-mode ro c
win-drive-mode rw d e
```

### `win-drive-session`

Features:

- Opens a nested interactive shell
- Switches the selected drives to `rw` before the shell starts
- Restores the same drives to `ro` automatically when the shell exits
- Exports `WSL_DRIVE_SESSION_DRIVES` so the prompt can show an active session marker
- Is installed by the package installer and also exposed through `~/.local/bin/win-drive-session`

Example:

```bash
win-drive-session rw c
win-drive-session rw d e
```

### `win-drive-status`

Reads `/proc/mounts` and prints a compact summary like:

```text
DRIVE MOUNTPOINT   MODE   SOURCE
C     /mnt/c       ro     C:\
D     /mnt/d       ro     D:\
E     /mnt/e       ro     E:\
```

### Interactive shell safety layer

The current shell setup adds a lightweight guard for day-to-day work:

- When a temporary writable shell is active, the prompt shows `RW-SESSION:<drive list>` even outside `/mnt/*`
- When the working directory is under `/mnt/<drive>`, the prompt shows a `WIN:<drive>:RO|RW` marker
- `cp` and `mv` ask for confirmation when the destination resolves under `/mnt/<drive>`
- `rm` is redirected to `safe-trash`, which moves files into `~/.local/share/Trash/` and writes a `.trashinfo` record
- `trash-list` shows recoverable entries from Trash
- `trash-restore <entry>` restores a selected Trash entry back to its original path, or to a suffixed path if the original name is already taken

This safety layer lives in:

- `/home/chenpeng/.bashrc.d/30-wsl-guard.sh`
- `/home/chenpeng/.local/bin/safe-trash`
- `/home/chenpeng/.local/bin/trash-list`
- `/home/chenpeng/.local/bin/trash-restore`

## Validation Already Done

The following checks were completed on the rebuilt package:

- `bash -n install-wsl-isolation.sh`
- `bash -n win-drive-mode`
- `bash -n win-drive-session`
- `bash -n win-drive-status`
- `win-drive-status` output matched the current live mount state for `C/D/E`

## Manual Install Steps

The final install step still needs to be run manually inside WSL because it requires interactive `sudo` authentication:

```bash
/home/chenpeng/tmp/wsl-isolation/install-wsl-isolation.sh
```

Expected output:

```text
Installed WSL isolation config.
Next steps:
  1. In Windows PowerShell, run: wsl --shutdown
  2. Reopen WSL
  3. Check default mount mode with: win-drive-status
  4. Temporarily enable write access with: win-drive-mode rw c
  5. Prefer temporary rw shells with: win-drive-session rw c
```

Then in Windows PowerShell:

```powershell
wsl --shutdown
```

After reopening WSL:

```bash
win-drive-status
```

## Daily Usage

Temporarily enable write access:

```bash
win-drive-mode rw c
win-drive-mode rw d e
```

Prefer temporary writable sub-shells for safer edits:

```bash
win-drive-session rw c
win-drive-session rw d e
```

Switch back to read-only:

```bash
win-drive-mode ro c
win-drive-mode ro d e
```

Check current status:

```bash
win-drive-status
```

Interactive shell safety behavior:

```bash
cd /mnt/c/...
# prompt shows [WIN:C:RO] or [WIN:C:RW]

win-drive-session rw c
# prompt shows [RW-SESSION:C] even if you stay in ~
# exit restores C: back to read-only

cp local-file /mnt/c/target/
mv file /mnt/d/target/
# asks for confirmation before writing into Windows drives

rm file
# moves the target into ~/.local/share/Trash instead of deleting it

trash-list
trash-restore some-file.txt
```

## Notes For Future Reproduction

- Keep the whole directory `/home/chenpeng/tmp/wsl-isolation/` together
- If the live system config is deleted again, rerun the installer from this directory
- The installer writes to:
  - `/etc/wsl.conf`
  - `/etc/fstab`
  - `/usr/local/bin/win-drive-mode`
  - `/usr/local/bin/win-drive-session`
  - `/usr/local/bin/win-drive-status`
- The interactive safety layer is user-scoped and lives in:
  - `/home/chenpeng/.bashrc.d/30-wsl-guard.sh`
  - `/home/chenpeng/.local/bin/safe-trash`
  - `/home/chenpeng/.local/bin/win-drive-session`
  - `/home/chenpeng/.local/bin/trash-list`
  - `/home/chenpeng/.local/bin/trash-restore`
- Existing target files are backed up into `/etc/wsl-isolation-backups/<timestamp>/`
- A full effect requires `wsl --shutdown` from Windows after installation
