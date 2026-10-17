#!/bin/sh
# ============================================================
# Word Of Enigma2 - OTHERS - curl + CA certificates
# ============================================================
# Installs curl together with ca-certificates so https:// downloads work
# without --no-check-certificate.
echo "=== Word Of Enigma2: curl ==="

if ! command -v opkg >/dev/null 2>&1; then
    echo "!! opkg was not found - this image does not use opkg"
    exit 1
fi

opkg update >/dev/null 2>&1

echo ""
echo "--- opkg install curl ca-certificates ---"
if ! opkg install curl ca-certificates; then
    echo "!! curl/ca-certificates could not be installed from the feed"
    exit 1
fi

echo ""
if command -v curl >/dev/null 2>&1; then
    echo "=== curl is ready ==="
    curl --version 2>/dev/null | head -n 1
else
    echo "!! curl is still missing"
    exit 1
fi
