# WSL Drive Guard

Reusable WSL tooling for two related goals:

- keep Windows drives mounted read-only by default under `/mnt/*`
- add lightweight shell safety rails when working with Windows-mounted paths

The project is split into two layers:

- `system/`: WSL mount isolation and drive mode tools, installed with `sudo`
- `user/`: prompt markers, Windows-drive write confirmations, and Trash helpers for interactive shells

## What It Provides

### System layer

- `win-drive-mode ro|rw <drive>`
- `win-drive-session rw <drive>`
- `win-drive-status`
- automatic rendering of managed `/etc/wsl.conf`
- automatic rendering of managed `/etc/fstab`

### User layer

- prompt marker when you work under Windows-mounted paths
- prompt marker for active temporary writable sessions
- confirmation before `cp` and `mv` target Windows-mounted paths
- interactive `rm` redirected into Trash
- `trash-list`
- `trash-restore`

## Repository Layout

```text
.
├── CHANGELOG.md
├── LICENSE
├── install.sh
├── uninstall.sh
├── system/
│   ├── install-wsl-isolation.sh
│   ├── uninstall-wsl-isolation.sh
│   ├── system.conf
│   ├── win-drive-mode
│   ├── win-drive-session
│   ├── win-drive-status
│   ├── wsl.conf
│   └── fstab
├── user/
│   ├── install-user-guard.sh
│   ├── uninstall-user-guard.sh
│   ├── user.conf
│   ├── bashrc.d/30-wsl-guard.sh
│   └── bin/
│       ├── safe-trash
│       ├── trash-list
│       └── trash-restore
└── docs/
    └── WSL_ISOLATION_RECOVERY_LOG.md
```

## Project Metadata

- license: [MIT](LICENSE)
- changelog: [CHANGELOG.md](CHANGELOG.md)

## Quick Start

Install both layers:

```bash
./install.sh
```

Install only the system layer:

```bash
./install.sh --system-only
```

Install only the user layer:

```bash
./install.sh --user-only
```

If you install the system layer, finish with:

```powershell
wsl --shutdown
```

Then reopen WSL and verify:

```bash
win-drive-status
source ~/.bashrc
```

## Uninstall

Remove both layers:

```bash
./uninstall.sh
```

Remove only the user layer:

```bash
./uninstall.sh --user-only
```

Remove only the system layer:

```bash
./uninstall.sh --system-only
```

Also remove installed config files:

```bash
./uninstall.sh --remove-config
```

If you uninstall the system layer, run:

```powershell
wsl --shutdown
```

before reopening WSL, so the mount behavior is refreshed.

## Configuration

You usually edit the installed config files, not the repository copies.

### System config

Installed path:

```text
/etc/wsl-drive-guard/system.conf
```

Main options:

- `WSL_GUARD_MANAGED_DRIVES`
  Example: `c d e`
- `WSL_GUARD_MOUNT_ROOT`
  Default: `/mnt`
- `WSL_GUARD_DEFAULT_MODE`
  Default: `ro`
- `WSL_GUARD_AUTOMOUNT_OPTIONS`
  Default: `metadata,umask=22,fmask=11`
- `WSL_GUARD_DRVFS_OPTIONS`
  Default: `noatime,metadata,umask=22,fmask=11`
- `WSL_GUARD_SYSTEM_BIN_DIR`
  Default: `/usr/local/bin`
- `WSL_GUARD_SYSTEM_CONFIG_DIR`
  Default: `/etc/wsl-drive-guard`

Typical changes:

```bash
WSL_GUARD_MANAGED_DRIVES="c"
WSL_GUARD_DEFAULT_MODE="ro"
WSL_GUARD_MOUNT_ROOT="/mnt"
```

After editing the system config, rerun:

```bash
./system/install-wsl-isolation.sh
```

then:

```powershell
wsl --shutdown
```

### User config

Installed path:

```text
~/.config/wsl-drive-guard/user.conf
```

Main options:

- `WSL_GUARD_ENABLE_PROMPT`
  `1` to show prompt markers, `0` to disable them
- `WSL_GUARD_ENABLE_SESSION_MARKER`
  `1` to show `RW-SESSION:<drives>`
- `WSL_GUARD_ENABLE_COPY_MOVE_CONFIRM`
  `1` to confirm `cp` and `mv` into Windows-mounted paths
- `WSL_GUARD_ENABLE_SAFE_RM`
  `1` to redirect interactive `rm` into Trash
- `WSL_GUARD_WINDOWS_MOUNT_ROOT`
  Default: `/mnt`
- `WSL_GUARD_TRASH_ROOT`
  Default: `~/.local/share/Trash`
- `WSL_GUARD_USER_BASHRC_D`
  Default: `~/.bashrc.d`
- `WSL_GUARD_USER_BIN_DIR`
  Default: `~/.local/bin`

Typical changes:

```bash
WSL_GUARD_ENABLE_PROMPT="1"
WSL_GUARD_ENABLE_COPY_MOVE_CONFIRM="1"
WSL_GUARD_ENABLE_SAFE_RM="1"
```

After editing the user config, usually this is enough:

```bash
source ~/.bashrc
```

## Daily Usage

Check current drive status:

```bash
win-drive-status
```

Temporarily switch a drive:

```bash
win-drive-mode rw c
win-drive-mode ro c
```

Prefer a temporary writable sub-shell:

```bash
win-drive-session rw c
exit
```

Inspect the Trash:

```bash
trash-list
```

Restore a file:

```bash
trash-restore some-file.txt
```

## How Install Works

### System layer

The installer:

- preserves non-automount sections already present in `/etc/wsl.conf`
- replaces only the managed block inside `/etc/wsl.conf`
- replaces only the managed block inside `/etc/fstab`
- installs helper commands into the configured system bin directory
- installs a default config into `/etc/wsl-drive-guard/system.conf` if that file does not already exist
- stores backups under `/etc/wsl-isolation-backups/<timestamp>/`

### User layer

The installer:

- installs `30-wsl-guard.sh` into the configured `~/.bashrc.d`
- installs Trash helpers into the configured user bin directory
- installs a default config into `~/.config/wsl-drive-guard/user.conf` if that file does not already exist

## FAQ

### Does this fully isolate WSL from Windows?

No. The default setup focuses on file-safety, not total interop isolation.

By default it:

- keeps selected Windows drives mounted read-only
- removes Windows PATH injection if you install the system layer with the bundled `wsl.conf`
- keeps Windows interop available unless you separately disable it

That means VS Code Remote - WSL can still work, but you also need to remember that Windows programs may still be callable if your environment exposes them.

### Will this break VS Code WSL?

The default setup is designed not to break typical VS Code WSL usage.

It does not set `interop=false`. It only manages mount behavior and shell safety rails.

### Why not disable interop entirely?

Because that often hurts workflows like:

- `code .`
- launching Windows-side tools from WSL
- some VS Code WSL bridge flows

This project takes the softer path: keep interop, but reduce accidental writes.

### Does interactive `rm` affect scripts?

No. The guard lives in `bashrc.d` and only affects interactive shells that load the guard script.

Non-interactive scripts still use the regular system `rm` unless you intentionally replace it elsewhere.

### What happens if the original path already exists during restore?

`trash-restore` avoids overwriting an existing path. It restores the file next to the original path and appends a `.restored.<timestamp>.<n>` suffix.

## Troubleshooting

### `win-drive-status` still shows old mount state after install

Usually WSL has not been restarted yet.

Run in Windows PowerShell:

```powershell
wsl --shutdown
```

Then reopen WSL and run:

```bash
win-drive-status
```

### `/mnt/c` is still visible even though automount is disabled

That can still be expected if your managed `/etc/fstab` mounts `C:` explicitly. This project disables automatic mounting and then remounts selected drives through `fstab`, usually as read-only.

### `win-drive-mode` or `win-drive-status` says command not found

Check whether the system layer was installed into the configured bin directory:

```bash
grep '^WSL_GUARD_SYSTEM_BIN_DIR=' /etc/wsl-drive-guard/system.conf
echo "$PATH"
```

If needed, run:

```bash
./system/install-wsl-isolation.sh
```

### Prompt markers do not appear

Check that:

- your shell is bash
- `~/.bashrc` loads `~/.bashrc.d/*.sh`
- `WSL_GUARD_ENABLE_PROMPT="1"` in `~/.config/wsl-drive-guard/user.conf`

Then reload:

```bash
source ~/.bashrc
```

### `rm` does not go to Trash

Check that:

- you are in an interactive shell
- `WSL_GUARD_ENABLE_SAFE_RM="1"`
- `safe-trash` exists in your configured user bin directory

You can verify with:

```bash
type rm
type safe-trash
```

### `cp` and `mv` do not prompt before writing to `/mnt/*`

Check that:

- `WSL_GUARD_ENABLE_COPY_MOVE_CONFIRM="1"`
- the guard script is loaded in the current shell
- the destination resolves under the configured `WSL_GUARD_WINDOWS_MOUNT_ROOT`

Try:

```bash
type cp
type mv
source ~/.bashrc
```

### `win-drive-session` exits but the drive stays writable

First verify the actual state:

```bash
win-drive-status
```

If needed, restore it directly:

```bash
win-drive-mode ro c
```

If this happens repeatedly, reinstall the system layer and reopen WSL:

```bash
./system/install-wsl-isolation.sh
```

then:

```powershell
wsl --shutdown
```

### A pasted multi-line command behaves strangely inside `win-drive-session`

That can happen with shell line editors or readline enhancements. The safer pattern is:

1. Run `win-drive-session rw c`
2. Wait for the new prompt
3. Type the risky commands one by one
4. Run `exit`

### I changed the config, but behavior did not change

For system config:

- rerun `./system/install-wsl-isolation.sh`
- run `wsl --shutdown`
- reopen WSL

For user config:

- run `source ~/.bashrc`

## Validation

Recommended checks after editing the repository:

```bash
bash -n install.sh uninstall.sh
bash -n system/*.sh
bash -n user/*.sh user/bin/*
```
