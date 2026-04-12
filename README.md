# WSL Drive Guard

Reusable WSL tooling for two related goals:

- Keep Windows drives mounted read-only by default under `/mnt/*`
- Add lightweight shell safety rails when working with Windows-mounted paths

The setup is split into two layers so you can install them independently:

- `system/`: WSL mount isolation and drive mode tools, installed with `sudo`
- `user/`: shell prompt markers, Windows-drive write confirmations, and Trash helpers for interactive shells

## What It Includes

### System tools

- `install-wsl-isolation.sh`
- `wsl.conf`
- `fstab`
- `win-drive-mode`
- `win-drive-session`
- `win-drive-status`

### User tools

- `install-user-guard.sh`
- `bashrc.d/30-wsl-guard.sh`
- `bin/safe-trash`
- `bin/trash-list`
- `bin/trash-restore`

## Features

- Disable automatic Windows drive mounting and let `/etc/fstab` define defaults
- Mount `C:`, `D:`, and `E:` as read-only by default
- Toggle drive mode with `win-drive-mode ro|rw <drive>`
- Open a temporary writable sub-shell with `win-drive-session rw <drive>`
- Show `WIN:<drive>:RO|RW` in the prompt when you work under `/mnt/*`
- Show `RW-SESSION:<drives>` while a temporary writable shell is active
- Ask before `cp` and `mv` write into Windows-mounted paths
- Redirect interactive `rm` into Trash instead of deleting directly
- List and restore trashed files with `trash-list` and `trash-restore`

## Install

### 1. Install system mount isolation

```bash
cd system
./install-wsl-isolation.sh
```

Then in Windows PowerShell:

```powershell
wsl --shutdown
```

Reopen WSL and verify:

```bash
win-drive-status
```

### 2. Install user shell guard

```bash
cd user
./install-user-guard.sh
source ~/.bashrc
```

## Daily Usage

Check mount status:

```bash
win-drive-status
```

Temporarily switch a drive:

```bash
win-drive-mode rw c
win-drive-mode ro c
```

Prefer a temporary writable shell:

```bash
win-drive-session rw c
exit
```

List trashed files:

```bash
trash-list
```

Restore a trashed file:

```bash
trash-restore some-file.txt
```

## Repository Layout

```text
system/
  install-wsl-isolation.sh
  wsl.conf
  fstab
  win-drive-mode
  win-drive-session
  win-drive-status
user/
  install-user-guard.sh
  bashrc.d/30-wsl-guard.sh
  bin/safe-trash
  bin/trash-list
  bin/trash-restore
docs/
  WSL_ISOLATION_RECOVERY_LOG.md
```

## Notes

- `system/install-wsl-isolation.sh` preserves the non-automount sections already present in `/etc/wsl.conf`
- The user guard only affects interactive shell usage; it does not globally replace system commands for non-interactive scripts
- The Trash implementation writes under `~/.local/share/Trash/`
