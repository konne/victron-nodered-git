#!/bin/sh
# Install Git and enable Node-RED Projects, including after firmware updates.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS_FILE="/data/home/nodered/.node-red/settings-user.js"
RC_LOCAL="/data/rc.local"
SETUP_SCRIPT="${SCRIPT_DIR}/setup.sh"
MARKER="victron-nodered-git"
LOG="${SCRIPT_DIR}/setup.log"
BOOT_MODE=false
FORCE_RESTART=false
for option in "$@"; do
    case "$option" in
        --boot) BOOT_MODE=true ;;
        --restart) FORCE_RESTART=true ;;
        *) echo "Usage: $0 [--boot] [--restart]" >&2; exit 2 ;;
    esac
done

if ! $BOOT_MODE; then
    echo "Running setup; output is recorded in $LOG"
fi
exec >> "$LOG" 2>&1
trap 'result=$?; echo "Setup finished with exit code $result"' 0
echo ""
echo "=== $(date) ==="
echo "Starting victron-nodered-git setup (boot=$BOOT_MODE, pid=$$)..."
if [ -r /proc/sys/kernel/random/boot_id ]; then
    echo "Boot ID: $(cat /proc/sys/kernel/random/boot_id)"
fi

. "${SCRIPT_DIR}/boot-common.sh"
# Register before any operation that needs rootfs write access or internet.
# Boot runs leave the shared hook alone; installation updates it sequentially.
if ! $BOOT_MODE; then
    register_boot_hook
fi
prepare_rootfs

SIGNALK_DIR="/usr/lib/node_modules/signalk-server"
if [ -d "$SIGNALK_DIR" ]; then
    echo "Removing signalk-server..."
    rm -rf "$SIGNALK_DIR"
    echo "signalk-server removed."
else
    echo "signalk-server not present, skipping."
fi

RESTART_NEEDED=$FORCE_RESTART
if command -v git > /dev/null 2>&1; then
    echo "git already installed: $(git --version)"
else
    echo "Installing git via opkg..."
    opkg update
    opkg install git
    echo "git installed: $(git --version)"
    RESTART_NEEDED=true
fi

echo "Checking Node-RED Projects settings..."
PATCH_RESULT="$(node "${SCRIPT_DIR}/enable-projects.js" "$SETTINGS_FILE")"
echo "$PATCH_RESULT"
if [ "$(printf '%s\n' "$PATCH_RESULT" | tail -n 1)" = "changed" ]; then
    RESTART_NEEDED=true
fi

if $RESTART_NEEDED; then
    NR_SERVICE=""
    for candidate in /service/node-red-venus /service/nodered; do
        if [ -d "$candidate" ]; then
            NR_SERVICE="$candidate"
            break
        fi
    done
    if [ -n "$NR_SERVICE" ] && command -v svc >/dev/null 2>&1; then
        echo "Restarting Node-RED through $NR_SERVICE..."
        svc -t "$NR_SERVICE"
    else
        NR_PID="$(pgrep -f 'node-red|node_modules/.bin/node-red' | head -n 1)"
        if [ -n "$NR_PID" ]; then
            echo "Restarting Node-RED (pid $NR_PID)..."
            kill "$NR_PID"
        else
            echo "Node-RED is not running; it will read the settings when started."
        fi
    fi
else
    echo "Git and settings unchanged; no Node-RED restart needed."
fi
echo "Setup complete."
