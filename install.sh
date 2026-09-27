#!/usr/bin/env bash
set -e

APPLET_ID="dev.muench.uptime-kuma"
TARGET_DIR="${HOME}/.local/share/plasma/plasmoids/${APPLET_ID}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Uptime Kuma Plasma 6 Widget..."

mkdir -p "${HOME}/.local/share/plasma/plasmoids"

if [ -L "${TARGET_DIR}" ]; then
    echo "==> Removing existing symlink..."
    unlink "${TARGET_DIR}"
elif [ -d "${TARGET_DIR}" ]; then
    echo "==> Removing existing directory..."
    rm -rf "${TARGET_DIR}"
fi

if [ "$1" = "--copy" ]; then
    echo "==> Copying files to ${TARGET_DIR}..."
    cp -r "${SOURCE_DIR}" "${TARGET_DIR}"
else
    echo "==> Creating development symlink:"
    echo "    ${TARGET_DIR} -> ${SOURCE_DIR}"
    ln -s "${SOURCE_DIR}" "${TARGET_DIR}"
fi

echo ""
echo "✅ Uptime Kuma Widget successfully installed!"
echo "   Applet ID: ${APPLET_ID}"
echo ""
echo "👉 To test in a standalone window, run:"
echo "   plasmawindowed ${APPLET_ID}"
echo ""
echo "👉 To add the widget to your panel or desktop:"
echo "   Right-click panel/desktop -> 'Add Widgets...' -> Search 'Uptime Kuma'"
