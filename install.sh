#!/bin/sh
# install.sh – install or update victron-nodered-git on a Victron device.
#
# Fetch and run in one command:
#
#   wget -qO- https://raw.githubusercontent.com/konne/victron-nodered-git/main/install.sh | sh
#
# What this script does:
#   1. Downloads the repo archive and extracts it
#   2. Runs setup.sh

set -e

REPO_ARCHIVE_URL="https://github.com/konne/victron-nodered-git/archive/refs/heads/main.tar.gz"
INSTALL_DIR="/data/victron-nodered-git"
TMP_ARCHIVE="${INSTALL_DIR}/tmp/update.tgz"
TMP_EXTRACT="${INSTALL_DIR}/tmp/update-extract"

echo "============================================================"
echo " victron-nodered-git installer"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Download and extract
# ---------------------------------------------------------------------------
mkdir -p "${INSTALL_DIR}/tmp"

echo "Downloading latest release..."
wget -qO "$TMP_ARCHIVE" "$REPO_ARCHIVE_URL" || {
    echo "ERROR: download failed. Check network connectivity."
    exit 1
}

echo "Extracting..."
rm -rf "$TMP_EXTRACT"
mkdir -p "$TMP_EXTRACT"
tar -xzf "$TMP_ARCHIVE" -C "$TMP_EXTRACT" --strip-components=1
rm -f "$TMP_ARCHIVE"

for f in "$TMP_EXTRACT"/*; do
    name="$(basename "$f")"
    cp -r "$f" "${INSTALL_DIR}/${name}"
done

rm -rf "$TMP_EXTRACT"

chmod +x "${INSTALL_DIR}/setup.sh" \
         "${INSTALL_DIR}/uninstall.sh"

echo "Files updated."

# ---------------------------------------------------------------------------
# 2. Run setup
# ---------------------------------------------------------------------------
echo ""
echo "Running setup.sh ..."
sh "${INSTALL_DIR}/setup.sh"
