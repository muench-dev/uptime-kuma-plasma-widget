#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "==> 1. Validating metadata.json..."
echo "========================================="
jq . metadata.json > /dev/null

APPLET_ID=$(jq -r '.KPlugin.Id' metadata.json)
API_VERSION=$(jq -r '."X-Plasma-API-Minimum-Version"' metadata.json)
MAIN_SCRIPT=$(jq -r '."X-Plasma-MainScript"' metadata.json)
PLUGIN_VERSION=$(jq -r '.KPlugin.Version' metadata.json)

if [ "$APPLET_ID" != "dev.muench.uptime-kuma" ]; then
    echo "Error: Unexpected plugin ID '$APPLET_ID'"
    exit 1
fi
if [ "$API_VERSION" != "6.0" ]; then
    echo "Error: Invalid X-Plasma-API-Minimum-Version '$API_VERSION', expected '6.0'"
    exit 1
fi
if [ "$MAIN_SCRIPT" != "ui/main.qml" ]; then
    echo "Error: Invalid X-Plasma-MainScript '$MAIN_SCRIPT', expected 'ui/main.qml'"
    exit 1
fi
echo "✅ Metadata verified: $APPLET_ID v$PLUGIN_VERSION (Plasma API $API_VERSION)"

echo ""
echo "========================================="
echo "==> 2. Validating Config XML..."
echo "========================================="
xmllint --noout contents/config/main.xml
echo "✅ Config XML syntax is valid."

echo ""
echo "========================================="
echo "==> 3. Running Unit Tests..."
echo "========================================="
node --test tests/service.test.js
echo "✅ Unit tests passed."

echo ""
echo "========================================="
echo "==> 4. Linting QML & JavaScript..."
echo "========================================="
MOCK_DIR=$(mktemp -d)
for mod in \
    "org.kde.kirigami" \
    "org.kde.plasma.core" \
    "org.kde.plasma.extras" \
    "org.kde.plasma.components" \
    "org.kde.kcmutils"; do
    MOD_PATH="$MOCK_DIR/$(echo $mod | tr '.' '/')"
    mkdir -p "$MOD_PATH"
    echo "module $mod" > "$MOD_PATH/qmldir"
done

LINT_OUTPUT=$(qmllint -I "$MOCK_DIR" contents/ui/*.qml contents/ui/config/*.qml contents/code/*.js 2>&1) || true
rm -rf "$MOCK_DIR"

SYNTAX_ERRORS=$(echo "$LINT_OUTPUT" | grep -iE "(:[0-9]+.*(error|expected token|parse error|syntax error)|fatal error)" | grep -v -i "Unqualified access" || true)
if [ -n "$SYNTAX_ERRORS" ]; then
    echo "::error::Syntax errors detected in QML/JS files:"
    echo "$SYNTAX_ERRORS"
    exit 1
fi
echo "✅ All QML and JavaScript files passed syntax verification."

echo ""
echo "========================================="
echo "==> 5. Building Plasmoid Package..."
echo "========================================="
PKG_NAME="dev.muench.uptime-kuma.plasmoid"
PKG_VERSIONED="dev.muench.uptime-kuma-v${PLUGIN_VERSION}.plasmoid"

rm -f "$PKG_NAME" "$PKG_VERSIONED"
zip -q -r "$PKG_NAME" metadata.json contents/ LICENSE README.md -x "*.DS_Store" "*~" "*.swp"
cp "$PKG_NAME" "$PKG_VERSIONED"
echo "✅ Package created successfully: $PKG_NAME"

echo ""
echo "========================================="
echo "==> 6. Verifying Package Structure..."
echo "========================================="
unzip -l "$PKG_NAME" | grep -q " metadata.json$" || { echo "Missing metadata.json"; exit 1; }
unzip -l "$PKG_NAME" | grep -q " contents/ui/main.qml$" || { echo "Missing main.qml"; exit 1; }
unzip -l "$PKG_NAME" | grep -q " contents/code/uptimeKumaService.js$" || { echo "Missing service script"; exit 1; }
unzip -l "$PKG_NAME" | grep -q " contents/config/main.xml$" || { echo "Missing main.xml"; exit 1; }
unzip -l "$PKG_NAME" | grep -q " LICENSE$" || { echo "Missing LICENSE"; exit 1; }
echo "✅ Package structure verified successfully."
