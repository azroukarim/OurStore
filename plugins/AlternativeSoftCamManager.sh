#!/bin/sh
# ============================================================
# Word Of Enigma2 - PLUGINS - Alternative SoftCam Manager
# Official automatic installer (script by iet5, repo: Saiedf)
#
# Original one-liner:
#   wget -qO- https://raw.githubusercontent.com/Saiedf/alternativesoftcammanager/main/installer_alternativesoftcammanager_auto.sh | /bin/sh
#
# This wrapper adds three things the one-liner cannot do:
#   1. the installer is downloaded into a writable folder first and is only
#      started when it arrived completely (no half-run installer)
#   2. /tmp is repaired when it is missing or not writable, because the
#      official installer downloads its package to /tmp
#   3. everything is logged, so the console shows what happened
#
# The official installer removes old versions, picks the right package for
# the box, installs it and restarts Enigma2 at the end.  This script runs
# detached (setsid, done by the plugin), so that restart cannot be killed
# halfway.
# ============================================================

URL="${ASCM_URL:-https://raw.githubusercontent.com/Saiedf/alternativesoftcammanager/main/installer_alternativesoftcammanager_auto.sh}"
NAME="Alternative SoftCam Manager"

echo "==============================================="
echo " $NAME"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/ascm.$$"
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
INST="$WORK/alternativesoftcammanager.sh"

# ---- [1/3] download the official installer + check it ----
echo ""
echo ">> [1/3] Downloading the installer ..."
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
if ! head -n 1 "$INST" | grep -q "^#!/bin/sh"; then
    echo "!! The downloaded file is not a shell installer - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
echo "   installer ok: $(wc -c < "$INST") bytes"

# ---- [2/3] make sure the official installer can use /tmp ----
# (it downloads its package to /tmp/$PKG_FILE)
echo ""
echo ">> [2/3] Checking /tmp ..."
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

# ---- [3/3] run the official installer ----
echo ""
echo ">> [3/3] Running the official installer ..."
echo ""
sh "$INST"
rc=$?

echo ""
echo "==============================================="
if [ "$rc" = "0" ]; then
    echo " $NAME: finished."
    echo " See the log above for the installed version."
else
    echo " $NAME: the installer stopped with exit code $rc."
    echo " Run it again once the connection is stable."
fi
echo "==============================================="

rm -f "$INST"
exit "$rc"
