#!/bin/sh
# ============================================================
# AllStore - Installation Script
# ============================================================

PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/AllStore"
BASE_URL="https://raw.githubusercontent.com/azroukarim/OurStore/main"

echo "========================================="
echo "    Installing AllStore..."
echo "========================================="

rm -rf "$PLUGIN_DIR"

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

echo "Downloading core files..."
wget -q -O "$PLUGIN_DIR/plugin.py"       "$BASE_URL/plugin.py"
wget -q -O "$PLUGIN_DIR/plugin.png"      "$BASE_URL/plugin.png"
wget -q -O "$PLUGIN_DIR/__init__.py"     "$BASE_URL/__init__.py"
wget -q -O "$PLUGIN_DIR/version.json"    "$BASE_URL/version.json"
wget -q -O "$PLUGIN_DIR/feed/index.json" "$BASE_URL/feed/index.json"

echo "Downloading main images..."
wget -q -O "$PLUGIN_DIR/images/logo.png"       "$BASE_URL/images/logo.png"
wget -q -O "$PLUGIN_DIR/images/background.png" "$BASE_URL/images/background.png"
wget -q -O "$PLUGIN_DIR/images/avatar.png"     "$BASE_URL/images/avatar.png"
wget -q -O "$PLUGIN_DIR/images/qrcode.png"     "$BASE_URL/images/qrcode.png"
wget -q -O "$PLUGIN_DIR/images/key_red.png"    "$BASE_URL/images/key_red.png"
wget -q -O "$PLUGIN_DIR/images/key_green.png"  "$BASE_URL/images/key_green.png"
wget -q -O "$PLUGIN_DIR/images/key_yellow.png" "$BASE_URL/images/key_yellow.png"
wget -q -O "$PLUGIN_DIR/images/key_blue.png"   "$BASE_URL/images/key_blue.png"
wget -q -O "$PLUGIN_DIR/images/progress.png"   "$BASE_URL/images/progress.png"

echo "Downloading section icons..."
wget -q -O "$PLUGIN_DIR/images/Icons/plugins.png"       "$BASE_URL/images/Icons/plugins.png"
wget -q -O "$PLUGIN_DIR/images/Icons/skins.png"         "$BASE_URL/images/Icons/skins.png"
wget -q -O "$PLUGIN_DIR/images/Icons/tools.png"         "$BASE_URL/images/Icons/tools.png"
wget -q -O "$PLUGIN_DIR/images/Icons/system_images.png" "$BASE_URL/images/Icons/system_images.png"
wget -q -O "$PLUGIN_DIR/images/Icons/picons.png"        "$BASE_URL/images/Icons/picons.png"
wget -q -O "$PLUGIN_DIR/images/Icons/channels.png"      "$BASE_URL/images/Icons/channels.png"
wget -q -O "$PLUGIN_DIR/images/Icons/novaler.png"       "$BASE_URL/images/Icons/novaler.png"

find "$PLUGIN_DIR" -name "*.pyc" -delete 2>/dev/null
find "$PLUGIN_DIR" -name "__pycache__" -exec rm -rf {} \; 2>/dev/null

chmod -R 755 "$PLUGIN_DIR"

sync

echo "Restarting Enigma2..."
sleep 2
killall -9 enigma2

exit 0