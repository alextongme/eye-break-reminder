#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
#  Count Tongula's Eye Break Reminder
#  Installer for macOS
# ─────────────────────────────────────────────

INSTALL_DIR="$HOME/.eye-break"
AGENT_LABEL="com.counttongula.eyebreak"
AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT_PLIST="$AGENT_DIR/$AGENT_LABEL.plist"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Count Tongula's Eye Break"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"

ok()   { echo "  ✅ $1"; }
info() { echo "  🦇 $1"; }
fail() { echo "  ❌ $1" >&2; exit 1; }

# ── Preflight ──
[[ "$(uname)" == "Darwin" ]] || fail "This only works on macOS."
command -v swift >/dev/null || fail "swift not found (install Xcode Command Line Tools)."

echo ""
echo "  🧛 Count Tongula's Eye Break Reminder"
echo "  ─────────────────────────────────────"
echo ""

# ── Compile Swift UI ──
info "Compiling Dracula UI (Swift Package Manager) ..."
swift build -c release --package-path "$REPO_DIR" 2>&1
ok "Binary compiled"

# ── Install binary + assets ──
info "Installing to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
# Symlink the compiled binary
rm -f "$INSTALL_DIR/eye_break_ui"
ln -s "$REPO_DIR/.build/release/eye_break_ui" "$INSTALL_DIR/eye_break_ui"
# Strip macOS quarantine/provenance attributes
xattr -cr "$INSTALL_DIR" 2>/dev/null || true
ok "Binary installed → $INSTALL_DIR"

# ── Symlink assets ──
info "Symlinking assets ..."
rm -rf "$INSTALL_DIR/assets"
ln -s "$REPO_DIR/assets" "$INSTALL_DIR/assets"
ok "Assets symlinked → $REPO_DIR/assets/"

# ── Build .app bundle (for Login Items name + icon) ──
info "Building app bundle ..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Symlink binary into the .app bundle
ln -sf "$INSTALL_DIR/eye_break_ui" "$APP_BUNDLE/Contents/MacOS/eye_break_ui"

# Copy icon
cp "$REPO_DIR/assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Symlink assets into bundle Resources so assetPath() finds them when launched via open
ln -sf "$REPO_DIR/assets" "$APP_BUNDLE/Contents/Resources/assets"

# Derive version from git tag
APP_VERSION=$(git -C "$REPO_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "dev")

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$AGENT_LABEL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleExecutable</key>
    <string>eye_break_ui</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST
ok "App bundle created"

# ── Restart app if it was running ──
if pgrep -f "eye_break_ui" >/dev/null 2>&1; then
    info "Restarting app ..."
    pkill -f "eye_break_ui" 2>/dev/null || true
    # Wait for the old process to fully exit so the single-instance
    # flock is released before the new process tries to acquire it.
    for _ in $(seq 1 20); do
        pgrep -f "eye_break_ui" >/dev/null 2>&1 || break
        sleep 0.25
    done
    open "$APP_BUNDLE"
    ok "App restarted"
else
    info "App is not running. Launch it with:"
    echo "     open \"$APP_BUNDLE\""
fi

echo ""
echo "  🦇 Count Tongula will remind you to rest your eyes."
echo "     Menu bar icon: 🦇 with countdown timer."
echo ""
echo "  To uninstall:  ./uninstall.sh"
echo ""
