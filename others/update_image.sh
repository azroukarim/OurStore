#!/bin/sh
# ============================================================
# Word Of Enigma2 - OTHERS - update the image (all packages)
# ============================================================
# Runs "opkg update" and then upgrades every installed package that has a
# newer version in the image feed.  Nothing is removed and no settings are
# touched; the user is asked to restart Enigma2 at the end.
echo "=== Word Of Enigma2: image update ==="

if ! command -v opkg >/dev/null 2>&1; then
    echo "!! opkg was not found - this image does not use opkg"
    exit 1
fi

echo ""
echo "--- opkg update ---"
if ! opkg update; then
    echo "!! opkg update failed (internet connection or feed problem)"
    exit 1
fi

echo ""
echo "--- packages with an update ---"
opkg list-upgradable 2>/dev/null || true

echo ""
echo "--- opkg upgrade ---"
opkg upgrade
rc=$?

echo ""
if [ "$rc" = "0" ]; then
    echo "=== image update finished successfully ==="
    echo "Restart Enigma2 (or reboot the box) to apply everything."
else
    echo "=== image update finished with errors (exit $rc) ==="
    echo "You can run it again; already updated packages are skipped."
fi
exit "$rc"
