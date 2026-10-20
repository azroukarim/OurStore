#!/bin/sh
# ============================================================
# Word Of Enigma2 - EMUS - oscam-feed-OpenATV
#
# Original setup command:
#   wget -O - -q http://updates.mynonpublic.com/oea/feed | bash
#
# What the official feed script does:
#   - detects the OE version and the architecture of the image
#   - removes old secret-feed files and writes the OpenATV 3rdparty feed
#     into /etc/opkg/<arch>-3rdparty-secret-feed.conf
#   - installs "softcam-feed-universal" (the OSCam/softcam packages)
#     ONLY when the script is started as "feed" / "bash" / "sh"
#   - it does not restart Enigma2 (a feed needs no restart)
#
# This wrapper adds what the one-liner cannot do:
#   1. the script is downloaded into a writable folder first and only
#      started when it arrived completely
#   2. it is saved as "feed", because the official script checks its own
#      file name before it installs softcam-feed-universal
#   3. it runs with bash (the script uses [[ ... ]] and [[ -e ... ]])
#   4. $D is cleared, so the feed files are written to the real /etc
#      and not into a staging folder
#   5. the result is checked: the feed file and the installed package
# ============================================================

URL="${OATVFEED_URL:-http://updates.mynonpublic.com/oea/feed}"
NAME="oscam-feed-OpenATV"

echo "==============================================="
echo " $NAME"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/oscamfeed.$$"
    rm -rf "$_dir" 2>/dev/null
    if mkdir -p "$_dir" 2>/dev/null; then
        WORK="$_dir"
        break
    fi
done
if [ -z "$WORK" ]; then
    echo "!! No writable folder found - nothing was changed."
    exit 1
fi
# the file MUST be named "feed" (see the name check inside the script)
INST="$WORK/feed"

# ---- [1/4] download the official feed script + check it ----
echo ""
echo ">> [1/4] Downloading the feed script ..."
rm -f "$INST"
wget -q -T 90 --tries=2 --no-check-certificate "$URL" -O "$INST"
if [ ! -s "$INST" ]; then
    echo "   retrying without the certificate option ..."
    wget -q -T 90 --tries=2 "$URL" -O "$INST"
fi
if [ ! -s "$INST" ]; then
    echo "!! Download failed - check the internet connection."
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
if ! head -n 1 "$INST" | grep -q "^#!"; then
    echo "!! The downloaded file is not a shell installer - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
echo "   installer ok: $(wc -c < "$INST") bytes"

# ---- [2/4] check /tmp (kept for images that use a tmp based opkg) ----
echo ""
echo ">> [2/4] Checking /tmp ..."
tmp_works() {
    ( : > /tmp/.woe_tmp_test ) 2>/dev/null || return 1
    rm -f /tmp/.woe_tmp_test 2>/dev/null
    return 0
}
if tmp_works; then
    echo "   /tmp is writable"
else
    echo "   /tmp is not writable - repairing it ..."
    if [ -L /tmp ]; then
        _target=$(readlink /tmp 2>/dev/null)
        case "$_target" in
            /*) mkdir -p "$_target" 2>/dev/null ;;
        esac
    fi
    if ! tmp_works; then
        if [ -L /tmp ] || [ -f /tmp ]; then
            rm -f /tmp 2>/dev/null
        fi
        mkdir -p /tmp 2>/dev/null
        chmod 1777 /tmp 2>/dev/null
    fi
    if tmp_works; then
        echo "   /tmp was repaired"
    else
        echo "   !! /tmp still not writable - the installer may fail"
    fi
fi

# ---- [3/4] run the official feed script ----
echo ""
echo ">> [3/4] Installing the OpenATV softcam feed ..."
echo ""
unset D
if command -v bash >/dev/null 2>&1; then
    echo "   using bash"
    bash "$INST"
else
    echo "   bash is missing - installing it from the feed ..."
    opkg update >/dev/null 2>&1
    opkg install bash >/dev/null 2>&1
    if command -v bash >/dev/null 2>&1; then
        echo "   bash installed"
        bash "$INST"
    else
        echo "   !! bash is still missing - running with sh (may fail)"
        sh "$INST"
    fi
fi
rc=$?

# ---- [4/4] check the result ----
echo ""
echo ">> [4/4] Checking the installation ..."
FOUND="0"
for _conf in /etc/opkg/*-3rdparty-secret-feed.conf; do
    if [ -f "$_conf" ]; then
        echo "   ok: $_conf"
        FOUND="1"
        break
    fi
done
if command -v opkg >/dev/null 2>&1 && opkg list-installed 2>/dev/null | grep -q "softcam-feed-universal"; then
    echo "   ok: softcam-feed-universal is installed"
    FOUND="1"
fi
if [ "$FOUND" != "1" ]; then
    echo "   !! no secret feed was found - see the log above."
fi

echo ""
echo ">> Enigma2 is not restarted: a feed needs no restart."
if [ "${OATVFEED_TEST_NO_RESTART:-0}" = "1" ]; then
    echo "   test mode: Enigma2 is not touched"
fi

echo ""
echo "==============================================="
if [ "$rc" = "0" ]; then
    echo " $NAME: finished."
    echo " Now install an OSCam/softcam package from the feed (EMUS section)."
else
    echo " $NAME: the feed script stopped with exit code $rc."
    echo " Run it again once the connection is stable."
fi
echo "==============================================="

rm -f "$INST"
exit "$rc"
