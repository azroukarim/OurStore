#!/bin/sh
# ============================================================
# Word Of Enigma2 - CHANNELS - Morph883 satellites.xml (12.10.2026)
# 88 Ku-Band satellites - source: morpheus883.altervista.org
# Updates /etc/tuxbox/satellites.xml only (no channel list touched).
# ============================================================

URL="https://raw.githubusercontent.com/azroukarim/OurStore/main/channels/Morph/satellites.xml"
ROOT="${MORPH_ROOT:-}"
DEST="$ROOT/etc/tuxbox/satellites.xml"
TMP="${TMPDIR:-/tmp}/satellites.xml.new"

echo ">> Downloading satellites.xml ..."
wget -q -T 90 --tries=2 --no-check-certificate "$URL" -O "$TMP" || \
wget -q -T 90 --tries=2 "$URL" -O "$TMP"

if [ -s "$TMP" ] && grep -q "<satellites>" "$TMP" 2>/dev/null; then
    [ -f "$DEST" ] && cp -f "$DEST" "$DEST.bak" 2>/dev/null
    mv -f "$TMP" "$DEST"
    sync
    echo "==============================================="
    echo " DONE: satellites.xml installed (88 sats)."
    [ -f "$DEST.bak" ] && echo " Backup: $DEST.bak"
    echo " Restart Enigma2 to apply."
    echo "==============================================="
else
    rm -f "$TMP"
    echo "!! Download failed - nothing was changed."
    exit 1
fi
exit 0
