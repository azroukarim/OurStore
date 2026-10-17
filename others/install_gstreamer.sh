#!/bin/sh
# ============================================================
# Word Of Enigma2 - OTHERS - GStreamer 1.0 playback plugins
# ============================================================
# Installs the GStreamer 1.0 plugin set used for media playback.  Packages
# that are already present are simply reported as installed by opkg.
echo "=== Word Of Enigma2: GStreamer 1.0 ==="

if ! command -v opkg >/dev/null 2>&1; then
    echo "!! opkg was not found - this image does not use opkg"
    exit 1
fi

opkg update >/dev/null 2>&1

ok=0
for pkg in \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-alsa
do
    echo ""
    echo "--- $pkg ---"
    if opkg install "$pkg"; then
        ok=$((ok + 1))
    else
        echo "  (not available in this feed: $pkg)"
    fi
done

echo ""
if [ "$ok" -gt 0 ]; then
    echo "=== GStreamer step finished ($ok package(s) ok) ==="
    echo "Restart Enigma2 to load the new plugins."
else
    echo "=== nothing was installed ==="
    echo "This image may already ship everything or use a different feed."
    exit 1
fi
