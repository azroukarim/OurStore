#!/bin/sh
# ============================================================
# Word Of Enigma2 - OTHERS - wget
# ============================================================
# Installs wget (it is used by this plugin for every download, some minimal
# images ship only busybox wget).
echo "=== Word Of Enigma2: wget ==="

if ! command -v opkg >/dev/null 2>&1; then
    echo "!! opkg was not found - this image does not use opkg"
    exit 1
fi

opkg update >/dev/null 2>&1

echo ""
echo "--- opkg install wget ---"
if ! opkg install wget; then
    echo "!! wget could not be installed from the feed"
    exit 1
fi

echo ""
if command -v wget >/dev/null 2>&1; then
    echo "=== wget is ready ==="
    wget --version 2>/dev/null | head -n 1
else
    echo "!! wget is still missing"
    exit 1
fi
