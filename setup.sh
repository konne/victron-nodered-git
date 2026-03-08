#!/bin/sh
# setup.sh – idempotent setup for victron-nodered-git.
#
# Run directly:
#   sh /data/victron-nodered-git/setup.sh
#
# Steps:
#   1. Remove signalk-server to free space (skipped if already absent)
#   2. Install git via opkg (skipped if already installed)
#   3. Enable Node-RED projects in settings-user.js (idempotent)
#   4. Register in /data/rc.local so setup re-runs after firmware updates

set -e

SETTINGS_FILE="/data/home/nodered/.node-red/settings-user.js"
RC_LOCAL="/data/rc.local"
SETUP_SCRIPT="/data/victron-nodered-git/setup.sh"
LOG="/data/victron-nodered-git/setup.log"

mkdir -p "$(dirname "$LOG")"
exec >> "$LOG" 2>&1
echo ""
echo "=== $(date) ==="
echo "Starting victron-nodered-git setup..."

# ---------------------------------------------------------------------------
# 1. Remove signalk-server to free space
# ---------------------------------------------------------------------------
SIGNALK_DIR="/usr/lib/node_modules/signalk-server"
if [ -d "$SIGNALK_DIR" ]; then
    echo "Removing signalk-server..."
    rm -rf "$SIGNALK_DIR"
    echo "signalk-server removed."
else
    echo "signalk-server not present, skipping."
fi

# ---------------------------------------------------------------------------
# 2. Install git
# ---------------------------------------------------------------------------
if command -v git > /dev/null 2>&1; then
    echo "git already installed: $(git --version)"
else
    echo "Installing git via opkg..."
    opkg update
    opkg install git
    echo "git installed: $(git --version)"
fi

# ---------------------------------------------------------------------------
# 3. Enable Node-RED projects in settings-user.js
# ---------------------------------------------------------------------------
patch_settings() {
    node - "$SETTINGS_FILE" << 'EOF'
const fs   = require('fs');
const path = process.argv[2];

if (!fs.existsSync(path)) {
    console.error('settings-user.js not found at: ' + path);
    process.exit(1);
}

// Read the file and evaluate it to get the exported object.
// We use a sandboxed require so module.exports is captured.
const Module = require('module');
const src = fs.readFileSync(path, 'utf8');

// Evaluate in a temporary module context.
const m = new Module(path);
m.filename = path;
m._compile(src, path);
const cfg = m.exports;

// Ensure the nested structure exists.
if (!cfg.editorTheme) cfg.editorTheme = {};
if (!cfg.editorTheme.projects) cfg.editorTheme.projects = {};

const projects = cfg.editorTheme.projects;

let changed = false;

if (projects.enabled !== true) {
    projects.enabled = true;
    changed = true;
}

if (!projects.workflow) {
    projects.workflow = { mode: 'manual' };
    changed = true;
} else if (!projects.workflow.mode) {
    projects.workflow.mode = 'manual';
    changed = true;
}

if (!changed) {
    console.log('settings-user.js already has projects enabled, no changes needed.');
    process.exit(0);
}

const out = 'module.exports = ' + JSON.stringify(cfg, null, 4) + ';\n';
fs.writeFileSync(path, out, 'utf8');
console.log('settings-user.js updated: projects enabled.');
EOF
}

if [ -f "$SETTINGS_FILE" ]; then
    echo "Patching $SETTINGS_FILE ..."
    patch_settings
else
    echo "settings-user.js not found at $SETTINGS_FILE"
    echo "Creating it with projects enabled..."
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    cat > "$SETTINGS_FILE" << 'SETTINGS'
module.exports = {
    editorTheme: {
        projects: {
            /** To enable the Projects feature, set this value to true */
            enabled: true,
            workflow: {
                /** Set the default projects workflow mode.
                 *  - manual - you must manually commit changes
                 *  - auto   - changes are automatically committed
                 */
                mode: "manual"
            }
        }
    }
};
SETTINGS
    echo "settings-user.js created."
fi

# ---------------------------------------------------------------------------
# 4. Register in /data/rc.local for firmware-update survival
# ---------------------------------------------------------------------------
MARKER="victron-nodered-git"
if [ -f "$RC_LOCAL" ] && grep -q "$MARKER" "$RC_LOCAL"; then
    echo "rc.local already contains victron-nodered-git entry."
else
    echo "Registering setup.sh in $RC_LOCAL ..."
    # Ensure rc.local exists and is executable.
    if [ ! -f "$RC_LOCAL" ]; then
        printf '#!/bin/sh\n' > "$RC_LOCAL"
        chmod +x "$RC_LOCAL"
    fi
    # Append before any trailing 'exit 0', or at end of file.
    if grep -q '^exit 0' "$RC_LOCAL"; then
        # Insert before the last exit 0.
        sed -i '/^exit 0/i # '"$MARKER"'\nsh '"$SETUP_SCRIPT"' &' "$RC_LOCAL"
    else
        printf '\n# %s\nsh %s &\n' "$MARKER" "$SETUP_SCRIPT" >> "$RC_LOCAL"
    fi
    echo "rc.local updated."
fi

echo ""
echo "Setup complete."
echo ""

# Restart Node-RED by killing the process – VenusOS will restart it automatically.
NR_PID="$(pgrep -f 'node-red\|node_modules/.bin/node-red' | head -1)"
if [ -n "$NR_PID" ]; then
    echo "Restarting Node-RED (pid $NR_PID)..."
    kill "$NR_PID"
    echo "Node-RED killed. VenusOS will restart it."
else
    echo "Node-RED process not found, skipping restart."
fi
echo ""
