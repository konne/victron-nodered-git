#!/bin/sh
# uninstall.sh – remove victron-nodered-git setup.
#
# This does NOT restore signalk-server or remove git.
# It only removes the rc.local hook and the install directory.

set -e

RC_LOCAL="/data/rc.local"
INSTALL_DIR="/data/victron-nodered-git"
MARKER="victron-nodered-git"

echo "============================================================"
echo " victron-nodered-git uninstaller"
echo "============================================================"
echo ""

# Remove rc.local hook
if [ -f "$RC_LOCAL" ] && grep -q "$MARKER" "$RC_LOCAL"; then
    echo "Removing rc.local hook..."
    # Remove the comment line and the sh ... line that follows it
    sed -i "/# ${MARKER}/,+1d" "$RC_LOCAL"
    echo "rc.local hook removed."
else
    echo "No rc.local hook found, skipping."
fi

# Remove install directory
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing $INSTALL_DIR ..."
    rm -rf "$INSTALL_DIR"
    echo "Done."
else
    echo "$INSTALL_DIR not found, skipping."
fi

echo ""
echo "Uninstall complete."
echo ""
echo "Note: signalk-server was not restored and git was not removed."
echo "Note: settings-user.js was not reverted. To disable projects,"
echo "      set editorTheme.projects.enabled = false in:"
echo "      /data/home/nodered/.node-red/settings-user.js"
echo ""
