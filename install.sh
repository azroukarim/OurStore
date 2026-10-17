#!/bin/sh
# ============================================================
# Word Of Enigma2 - Installation / Update Script
# ============================================================
# Everything is downloaded into a staging folder first and the important
# files are size checked.  Only when that succeeded is the installed
# plugin replaced.  An interrupted or empty download therefore can never
# leave the plugin without its feed and icons behind.

PLUGIN_DIR="${WOE_PLUGIN_DIR:-/usr/lib/enigma2/python/Plugins/Extensions/WordOfEnigma2}"
# Old installation path (previous name "AllStore") - removed during migration
LEGACY_DIR="${WOE_LEGACY_DIR:-/usr/lib/enigma2/python/Plugins/Extensions/AllStore}"
BASE_URL="${WOE_BASE_URL:-https://raw.githubusercontent.com/azroukarim/OurStore/main}"
TS=$(date +%s)
STAGE="/tmp/wordofenigma2_stage.$$"

echo "========================================="
echo "    Installing Word Of Enigma2..."
echo "========================================="

rm -rf "$STAGE"
mkdir -p "$STAGE/feed" "$STAGE/images/Icons" "$STAGE/fonts"

# dl <relative-url> <min-bytes>
# Downloads into the staging folder; returns 0 only if the file arrived
# completely, otherwise the incomplete file is deleted again.
dl() {
    _rel="$1"
    _min="$2"
    _out="$STAGE/$_rel"
    rm -f "$_out"
    wget -q --no-check-certificate -O "$_out" "$BASE_URL/$_rel?t=$TS" || true
    _size=$(wc -c < "$_out" 2>/dev/null | tr -d " ")
    if [ "${_size:-0}" -ge "$_min" ]; then
        return 0
    fi
    echo "  !! $_rel is incomplete (${_size:-0} bytes) - skipped"
    rm -f "$_out"
    return 1
}

echo "Downloading core files..."
dl "plugin.py" 10000 || {
    echo "plugin.py could not be downloaded - aborting, nothing was changed."
    rm -rf "$STAGE"
    exit 1
}
dl "version.json" 10 || {
    echo "version.json could not be downloaded - aborting, nothing was changed."
    rm -rf "$STAGE"
    exit 1
}
dl "feed/index.json" 200 || {
    echo "feed/index.json could not be downloaded - aborting, nothing was changed."
    rm -rf "$STAGE"
    exit 1
}
dl "plugin.png" 200 || true
dl "__init__.py" 0 || true

echo "Downloading main images..."
for img in qrcode logo background avatar key_red key_green key_yellow key_blue progress; do
    dl "images/$img.png" 200 || true
done

echo "Downloading section icons..."
for ic in plugins plugins_islamics skins media tools system_images picons channels backups others emus novaler default; do
    dl "images/Icons/$ic.png" 200 || true
done

echo "Downloading fonts..."
for fnt in OpenSans-Regular OpenSans-Bold; do
    dl "fonts/$fnt.ttf" 1000 || true
done

# ---------- every important file arrived: now install ----------------
echo "Installing to $PLUGIN_DIR ..."

# Preserve the user's settings (font / text size) and the last known store
# across the reinstall, so the plugin keeps working even without network.
SETTINGS_BAK="/tmp/wordofenigma2_settings.json"
CACHE_BAK="/tmp/wordofenigma2_cache.json"
rm -f "$SETTINGS_BAK" "$CACHE_BAK"
if [ -f "$PLUGIN_DIR/settings.json" ]; then
    cp "$PLUGIN_DIR/settings.json" "$SETTINGS_BAK" 2>/dev/null
elif [ -f "$LEGACY_DIR/settings.json" ]; then
    cp "$LEGACY_DIR/settings.json" "$SETTINGS_BAK" 2>/dev/null
fi
if [ -f "$PLUGIN_DIR/store_cache.json" ]; then
    cp "$PLUGIN_DIR/store_cache.json" "$CACHE_BAK" 2>/dev/null
fi

rm -rf "$PLUGIN_DIR"
rm -rf "$LEGACY_DIR"

mkdir -p "$PLUGIN_DIR"
cp -R "$STAGE/." "$PLUGIN_DIR/" 2>/dev/null
rm -rf "$STAGE"

[ -f "$PLUGIN_DIR/__init__.py" ] || : > "$PLUGIN_DIR/__init__.py"

# The plugin installs downloaded files into these folders, keep the same
# layout the updater uses.
for _d in feed images images/Icons fonts plugins skins tools channels picons novaler system_images; do
    mkdir -p "$PLUGIN_DIR/$_d"
done

if [ -f "$SETTINGS_BAK" ]; then
    cp "$SETTINGS_BAK" "$PLUGIN_DIR/settings.json" 2>/dev/null
    rm -f "$SETTINGS_BAK"
fi
if [ -f "$CACHE_BAK" ]; then
    cp "$CACHE_BAK" "$PLUGIN_DIR/store_cache.json" 2>/dev/null
    rm -f "$CACHE_BAK"
fi

find "$PLUGIN_DIR" -name "*.pyc" -delete 2>/dev/null
find "$PLUGIN_DIR" -name "__pycache__" -exec rm -rf {} \; 2>/dev/null

chmod -R 755 "$PLUGIN_DIR"

sync

echo "Installed version:"
cat "$PLUGIN_DIR/version.json"

if [ "${WOE_NO_RESTART:-0}" != "1" ]; then
    echo "Restarting Enigma2..."
    sleep 2
    killall -9 enigma2
fi

exit 0
