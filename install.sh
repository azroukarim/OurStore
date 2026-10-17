#!/bin/sh
# ============================================================
# Word Of Enigma2 - Installation / Update Script
# ============================================================

PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/WordOfEnigma2"
# Old installation path (previous name "AllStore") - removed during migration
LEGACY_DIR="/usr/lib/enigma2/python/Plugins/Extensions/AllStore"
BASE_URL="https://raw.githubusercontent.com/azroukarim/OurStore/main"
TS=$(date +%s)

echo "========================================="
echo "    Installing Word Of Enigma2..."
echo "========================================="

# Preserve the user's settings (font / text size) across a full reinstall
SETTINGS_BAK="/tmp/wordofenigma2_settings.json"
if [ -f "$PLUGIN_DIR/settings.json" ]; then
    cp "$PLUGIN_DIR/settings.json" "$SETTINGS_BAK" 2>/dev/null
fi

rm -rf "$PLUGIN_DIR"
rm -rf "$LEGACY_DIR"

mkdir -p "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR/feed"
mkdir -p "$PLUGIN_DIR/images"
mkdir -p "$PLUGIN_DIR/images/Icons"
mkdir -p "$PLUGIN_DIR/plugins"
mkdir -p "$PLUGIN_DIR/skins"
mkdir -p "$PLUGIN_DIR/tools"
mkdir -p "$PLUGIN_DIR/channels"
mkdir -p "$PLUGIN_DIR/picons"
mkdir -p "$PLUGIN_DIR/novaler"
mkdir -p "$PLUGIN_DIR/system_images"

# dl <dest> <relative-url>  (cache-buster + ignore old certificates)
dl() {
    wget -q --no-check-certificate -O "$1" "$BASE_URL/$2?t=$TS"
}

echo "Downloading core files..."
dl "$PLUGIN_DIR/plugin.py"       "plugin.py"
dl "$PLUGIN_DIR/plugin.png"      "plugin.png"
dl "$PLUGIN_DIR/__init__.py"     "__init__.py"
dl "$PLUGIN_DIR/version.json"    "version.json"
dl "$PLUGIN_DIR/feed/index.json" "feed/index.json"

echo "Downloading main images..."
dl "$PLUGIN_DIR/images/logo.png"       "images/logo.png"
dl "$PLUGIN_DIR/images/background.png" "images/background.png"
dl "$PLUGIN_DIR/images/avatar.png"     "images/avatar.png"
dl "$PLUGIN_DIR/images/qrcode.png"     "images/qrcode.png"
dl "$PLUGIN_DIR/images/key_red.png"    "images/key_red.png"
dl "$PLUGIN_DIR/images/key_green.png"  "images/key_green.png"
dl "$PLUGIN_DIR/images/key_yellow.png" "images/key_yellow.png"
dl "$PLUGIN_DIR/images/key_blue.png"   "images/key_blue.png"
dl "$PLUGIN_DIR/images/progress.png"   "images/progress.png"

echo "Downloading section icons..."
dl "$PLUGIN_DIR/images/Icons/plugins.png"       "images/Icons/plugins.png"
dl "$PLUGIN_DIR/images/Icons/skins.png"         "images/Icons/skins.png"
dl "$PLUGIN_DIR/images/Icons/media.png"         "images/Icons/media.png"
dl "$PLUGIN_DIR/images/Icons/tools.png"         "images/Icons/tools.png"
dl "$PLUGIN_DIR/images/Icons/system_images.png" "images/Icons/system_images.png"
dl "$PLUGIN_DIR/images/Icons/picons.png"        "images/Icons/picons.png"
dl "$PLUGIN_DIR/images/Icons/channels.png"      "images/Icons/channels.png"
dl "$PLUGIN_DIR/images/Icons/emus.png"          "images/Icons/emus.png"
dl "$PLUGIN_DIR/images/Icons/novaler.png"       "images/Icons/novaler.png"
dl "$PLUGIN_DIR/images/Icons/default.png"       "images/Icons/default.png"

find "$PLUGIN_DIR" -name "*.pyc" -delete 2>/dev/null
find "$PLUGIN_DIR" -name "__pycache__" -exec rm -rf {} \; 2>/dev/null

# Restore the user's settings saved before the wipe
if [ -f "$SETTINGS_BAK" ]; then
    cp "$SETTINGS_BAK" "$PLUGIN_DIR/settings.json" 2>/dev/null
    rm -f "$SETTINGS_BAK"
fi

chmod -R 755 "$PLUGIN_DIR"

sync

echo "Installed version:"
cat "$PLUGIN_DIR/version.json"

echo "Restarting Enigma2..."
sleep 2
killall -9 enigma2

exit 0
