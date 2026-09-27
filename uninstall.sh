#!/usr/bin/env bash
set -e

APPLET_ID="dev.muench.uptime-kuma"
TARGET_DIR="${HOME}/.local/share/plasma/plasmoids/${APPLET_ID}"

echo "==> Uninstalling Uptime Kuma Plasma 6 Widget..."

if [ -L "${TARGET_DIR}" ]; then
    unlink "${TARGET_DIR}"
    echo "==> Removed symlink ${TARGET_DIR}"
elif [ -d "${TARGET_DIR}" ]; then
    rm -rf "${TARGET_DIR}"
    echo "==> Removed ${TARGET_DIR}"
else
    echo "==> Widget was not installed in ${TARGET_DIR}"
fi

echo "✅ Uptime Kuma Widget uninstalled successfully."
