# victron-nodered-git

Enables Node-RED git projects on a Victron Ekrano (or Cerbo GX) by:

1. Making the root filesystem writable and removing `signalk-server` to free space
2. Installing `git` via `opkg`
3. Patching `/data/home/nodered/.node-red/settings-user.js` to enable the Node-RED Projects feature

The module lives under `/data/victron-nodered-git`, which survives Victron firmware updates. A hook in `/data/rc.local` re-runs `setup.sh --boot` on each boot so git and the settings patch are re-applied after a firmware update.

## How it works

Victron firmware updates wipe `/usr/bin` and `/etc/init.d` but leave `/data` intact. This module uses `/data/rc.local` — the [Victron-native boot hook](https://www.victronenergy.com/live/ccgx:root_access#hooks_to_installrun_own_code_at_boot) — to re-apply everything on each boot:

1. `setup.sh` registers itself in `/data/rc.local` on first install.
2. On every boot, `rc.local` starts `setup.sh --boot` in the background. Setup remounts the root filesystem read/write when needed, removes Signal K, re-installs Git if missing, and checks Node-RED settings.
3. Firmware updates already reboot the device. Recovery needs internet when Git must be downloaded; there is no package cache or automatic retry loop.
4. The `settings-user.js` patch is idempotent — existing settings are preserved, only the `editorTheme.projects` section is added or updated.

## Installation

SSH into the device and run:

```sh
wget -qO- https://raw.githubusercontent.com/konne/victron-nodered-git/main/install.sh | sh
```

## Manual install

```sh
wget -qO /tmp/vng.tgz https://github.com/konne/victron-nodered-git/archive/refs/heads/main.tar.gz
mkdir -p /data/victron-nodered-git
tar -xzf /tmp/vng.tgz -C /data/victron-nodered-git --strip-components=1
rm /tmp/vng.tgz
sh /data/victron-nodered-git/setup.sh
```

## What setup.sh does

1. **Registers the boot hook and prepares the root filesystem** — manual setup repairs the executable hook before downloads. Rootfs is remounted read/write when needed and remains writable until reboot. A failed remount stops setup.
2. **Removes signalk-server** (`/usr/lib/node_modules/signalk-server/`) if present — this frees several hundred MB needed for git.
3. **Installs git** via `opkg update && opkg install git` — skipped if git is already present.
4. **Patches settings-user.js** — adds or updates the `editorTheme.projects` block to enable projects with `workflow.mode = "manual"`. Existing JavaScript, comments, functions, and relative imports are preserved. Changed files are backed up as `settings-user.js.backup-<timestamp>` before an override is appended; existing workflow choices are retained.
5. **Restarts Node-RED only when needed** — through its supervisor, with a process fallback, when Git was installed or settings changed.

## After install

`setup.sh` requests a Node-RED restart only when Git or settings changed. No device reboot is issued. Repeated setup with no changes leaves Node-RED running.

Open the Node-RED editor. You will see a **Projects** panel in the sidebar. Use it to clone your flow repository or create a new project.

## Updating

Re-run the installer. It downloads the latest archive and re-runs `setup.sh`:

```sh
wget -qO- https://raw.githubusercontent.com/konne/victron-nodered-git/main/install.sh | sh
```

## Uninstall

```sh
sh /data/victron-nodered-git/uninstall.sh
```

This removes the `rc.local` hook and the `/data/victron-nodered-git` directory. It does **not** restore signalk-server, remove git, or revert `settings-user.js`.

## File layout

```
/data/
├── rc.local                          # Victron boot hook (updated by setup.sh)
└── victron-nodered-git/
    ├── install.sh                    # bootstrap (fetched from GitHub)
    ├── setup.sh                      # setup, re-run on each boot
    ├── boot-common.sh                # hook registration and rootfs preparation
    ├── enable-projects.js            # preserves existing JavaScript settings
    ├── uninstall.sh                  # full removal
    ├── setup.log                     # log of all setup runs
    └── tmp/                          # temporary download directory (auto-cleaned)
```

## Troubleshooting

**Check the setup log:**

```sh
cat /data/victron-nodered-git/setup.log
```

**Re-run setup manually:**

```sh
sh /data/victron-nodered-git/setup.sh
```

**git not found after firmware update:** Inspect `setup.log` first. Each run records boot mode, boot ID when available, and exit status. If a download failed, connect to the internet and re-run setup or reboot. If the hook did not run, check `ls -l /data/rc.local` and Settings → General → Modification checks → Modifications enabled. Firmware updates already include a reboot.

**Node-RED Projects panel not visible:** Confirm `settings-user.js` contains `editorTheme.projects.enabled = true`, then restart Node-RED with `svc -t /service/nodered`.

## Permissions and local verification

`install.sh`, `setup.sh`, and `uninstall.sh` are executable in the repository and installer. Helpers are loaded by the scripts. You can also explicitly run setup with `sh`.

Run the isolated regression checks on a development machine with Python 3 and Node.js:

```sh
python3 -m unittest discover -s tests -v
```

The checks use temporary files and mocked system commands; they do not reboot or alter a GX device. Verify on-device recovery with a controlled reboot after installation.
