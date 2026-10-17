#!/bin/sh
# ============================================================
# Word Of Enigma2 - OTHERS - ServiceApp + ExtePlayer3
# ============================================================
# Both packages come from the image feed (oe-alliance based images such as
# OpenATV/OpenPLi/VTi).  ServiceApp adds the extra players in the menu
# (5001/5002 and 8193) and ExtePlayer3 is the engine behind 5002.
echo "=== Word Of Enigma2: ServiceApp ==="

if ! command -v opkg >/dev/null 2>&1; then
    echo "!! opkg was not found - this image does not use opkg"
    exit 1
fi

opkg update >/dev/null 2>&1

installed=0
for pkg in enigma2-plugin-systemplugins-serviceapp exteplayer3; do
    echo ""
    echo "--- $pkg ---"
    if opkg install "$pkg"; then
        installed=$((installed + 1))
    else
        echo "!! $pkg could not be installed from the feed"
    fi
done

echo ""
if [ "$installed" -gt 0 ]; then
    echo "=== ServiceApp step finished ($installed package(s) ok) ==="
    echo "Restart Enigma2, then check: Menu -> Setup -> Usage & GUI -> ServiceApp"
else
    echo "=== nothing was installed ==="
    echo "Run 'opkg update' first or check the internet connection."
    exit 1
fi
