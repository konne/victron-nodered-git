# victron-nodered-git

Enables Node-RED git projects on a Victron Ekrano (or Cerbo GX) by:

1. Removing `signalk-server` to free space on the read-only rootfs
2. Installing `git` via `opkg`
3. Patching `/data/home/nodered/.node-red/settings-user.js` to enable the Node-RED Projects feature

The module lives under `/data/victron-nodered-git`, which survives Victron firmware updates. A hook in `/data/rc.local` re-runs `setup.sh` on each boot so git and the settings patch are re-applied after a firmware update.

## How it works

Victron firmware updates wipe `/usr/bin` and `/etc/init.d` but leave `/data` intact. This module uses `/data/rc.local` — the [Victron-native boot hook](https://www.victronenergy.com/live/ccgx:root_access#hooks_to_installrun_own_code_at_boot) — to re-apply everything on each boot:

1. `setup.sh` registers itself in `/data/rc.local` on first install.
2. On every boot, `rc.local` calls `setup.sh`, which re-installs git if missing and ensures the Node-RED settings are correct.
3. The `settings-user.js` patch is idempotent — existing settings are preserved, only the `editorTheme.projects` section is added or updated.

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

1. **Removes signalk-server** (`/usr/lib/node_modules/signalk-server/`) if present — this frees several hundred MB needed for git.
2. **Installs git** via `opkg update && opkg install git` — skipped if git is already present.
3. **Patches settings-user.js** — adds or updates the `editorTheme.projects` block to enable projects with `workflow.mode = "manual"`. All other settings in the file are left untouched.
4. **Registers in `/data/rc.local`** — so the above steps are re-applied after a firmware update.

## After install

`setup.sh` kills the Node-RED process at the end. VenusOS restarts it automatically with the new settings applied.

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
    ├── setup.sh                      # idempotent setup, re-run on each boot
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

**git not found after firmware update:** Reboot the device. The `rc.local` hook will detect the missing binary and re-install it automatically.

**Node-RED Projects panel not visible:** Confirm `settings-user.js` contains `editorTheme.projects.enabled = true`, then restart Node-RED with `svc -t /service/nodered`.
