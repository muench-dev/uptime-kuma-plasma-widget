# Justfile for Uptime Kuma KDE Plasma 6 Widget
set shell := ["bash", "-c"]

APPLET_ID := "dev.muench.uptime-kuma"
VERSION := `jq -r '.KPlugin.Version // "1.0.0"' metadata.json 2>/dev/null || echo "1.0.0"`
PKG_NAME := APPLET_ID + ".plasmoid"
PKG_VERSIONED := APPLET_ID + "-v" + VERSION + ".plasmoid"

# Default recipe: list available recipes
default:
    @just --list

# Create .plasmoid package
package:
    @echo "==> Packaging {{APPLET_ID}} (v{{VERSION}})..."
    @rm -f {{PKG_NAME}} {{PKG_VERSIONED}}
    zip -r {{PKG_NAME}} metadata.json contents/ LICENSE README.md -x "*.DS_Store" "*~" "*.swp"
    @cp {{PKG_NAME}} {{PKG_VERSIONED}}
    @echo ""
    @echo "✅ Plasmoid package successfully created:"
    @echo "   - {{PKG_NAME}}"
    @echo "   - {{PKG_VERSIONED}}"
    @echo ""
    @echo "👉 To install via kpackagetool6:"
    @echo "   kpackagetool6 --type Plasma/Applet --install {{PKG_NAME}}"

# Alias for package
plasmoid: package

# Lint all QML files with qmllint
lint:
    qmllint contents/ui/*.qml contents/ui/config/*.qml

# Validate metadata and config XML schemas
validate:
    jq . metadata.json > /dev/null
    xmllint --noout contents/config/main.xml

# Run unit tests
test-unit:
    node --test tests/*.test.js

# Install development symlink to ~/.local/share/plasma/plasmoids/
install:
    ./install.sh

# Remove widget from ~/.local/share/plasma/plasmoids/
uninstall:
    ./uninstall.sh

# Test widget in a standalone window using plasmawindowed
test:
    plasmawindowed {{APPLET_ID}}

# Clean built package files
clean:
    rm -f *.plasmoid
