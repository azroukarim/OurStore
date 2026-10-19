#!/bin/sh
# ============================================================
# Word Of Enigma2 - CHANNELS - Ciefp E2 channel list 23.09.2026
# Variant : 5sat  (19E 16E 13E 1.9E 0.8W)
# Archive : ciefp-E2-5sat-19E-16E-13E-1.9E-0.8W-23.09.2026.tar.gz
# Source  : github.com/azroukarim/plugins  (folder: channels)
#
# A channel list must be written while Enigma2 is NOT running, otherwise the
# old list is saved back on exit.  This script therefore:
#   1. downloads the archive and checks it BEFORE anything is touched
#   2. backs up lamedb / bouquets / satellites.xml
#   3. stops Enigma2 (this script runs detached, so the restart at the end
#      cannot be killed halfway - that is what froze boxes in the past)
#   4. removes the old bouquets + lamedb and extracts the new list
#   5. deletes lamedb5 (Enigma2 rebuilds it) and starts Enigma2 again
# ============================================================

URL="https://raw.githubusercontent.com/azroukarim/plugins/main/channels/ciefp-E2-5sat-19E-16E-13E-1.9E-0.8W-23.09.2026.tar.gz"
LABEL="5sat"

# Hooks used by the Word Of Enigma2 test suite (a normal install never sets
# them):  CIEFP_URL = other download url, CIEFP_ROOT = install below another
# root instead of /, CIEFP_TEST_NO_RESTART=1 = keep Enigma2 running.
URL="${CIEFP_URL:-$URL}"
ROOT="${CIEFP_ROOT:-}"
ETC="$ROOT/etc/enigma2"
TUXBOX="$ROOT/etc/tuxbox"
STOPPED=1

echo "==============================================="
echo " Ciefp channel list : $LABEL"
echo " 19E 16E 13E 1.9E 0.8W"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/ciefp.$$"
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
TAR="$WORK/ciefp.tar.gz"
BAK="$WORK/ciefp-bak"

# ---- [1/5] download + verify ----
echo ""
echo ">> [1/5] Downloading the channel list ..."
rm -f "$TAR"
wget -q -T 90 --tries=2 --no-check-certificate "$URL" -O "$TAR"
if [ ! -s "$TAR" ]; then
    echo "   retrying without the certificate option ..."
    wget -q -T 90 --tries=2 "$URL" -O "$TAR"
fi
if [ ! -s "$TAR" ]; then
    echo "!! Download failed - check the internet connection."
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
if ! tar -tzf "$TAR" >/dev/null 2>&1; then
    echo "!! The downloaded file is not a valid .tar.gz - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
echo "   archive ok: $(wc -c < "$TAR") bytes"

# ---- [2/5] backup of the current list ----
echo ""
echo ">> [2/5] Backing up the current channel list ..."
mkdir -p "$BAK/old" 2>/dev/null
for _f in lamedb lamedb5 bouquets.tv bouquets.radio blacklist whitelist; do
    [ -f "$ETC/$_f" ] && cp -f "$ETC/$_f" "$BAK/$_f" 2>/dev/null
done
[ -f "$TUXBOX/satellites.xml" ] && cp -f "$TUXBOX/satellites.xml" "$BAK/satellites.xml" 2>/dev/null
(cd "$ETC" 2>/dev/null && cp -f userbouquet.*.tv userbouquet.*.radio "$BAK/old/" 2>/dev/null)
echo "   backup: $BAK"

# ---- In a batch install "init"/"reboot" are replaced by stubs, so the real
# ---- binaries are used directly (a channel list needs the restart).
INIT_BIN=$(command -v init 2>/dev/null)
case "$INIT_BIN" in
    *wordofenigma2_block*) INIT_BIN="/sbin/init" ;;
esac
[ -x "$INIT_BIN" ] || INIT_BIN="/sbin/init"
SYSCTL_BIN=$(command -v systemctl 2>/dev/null)
case "$SYSCTL_BIN" in
    *wordofenigma2_block*) SYSCTL_BIN="/bin/systemctl" ;;
esac
REBOOT_BIN=$(command -v reboot 2>/dev/null)
case "$REBOOT_BIN" in
    *wordofenigma2_block*) REBOOT_BIN="/sbin/reboot" ;;
esac
[ -x "$REBOOT_BIN" ] || REBOOT_BIN="/sbin/reboot"

# ---- [3/5] stop Enigma2 ----
echo ""
if [ "${CIEFP_TEST_NO_RESTART:-0}" = "1" ]; then
    echo ">> [3/5] Test mode: Enigma2 is not stopped."
    STOPPED=0
else
    echo ">> [3/5] Stopping Enigma2 ..."
    if [ -d /run/systemd/system ] && [ -x "$SYSCTL_BIN" ]; then
        "$SYSCTL_BIN" stop enigma2
        START="$SYSCTL_BIN start enigma2"
    else
        "$INIT_BIN" 4
        START="$INIT_BIN 3"
    fi
    _n=0
    while pidof enigma2 >/dev/null 2>&1 && [ "$_n" -lt 25 ]; do
        sleep 1
        _n=$((_n + 1))
    done
    sleep 1
fi

# ---- [4/5] replace the channel data ----
echo ""
echo ">> [4/5] Installing the new channel list ..."
rm -f "$ETC"/userbouquet.*.tv "$ETC"/userbouquet.*.radio
rm -f "$ETC"/lamedb "$ETC"/lamedb5
if tar -xzf "$TAR" -C "$ROOT/"; then
    rm -f "$ETC/lamedb5"
    sync
    echo "   new list written to $ETC"
else
    echo "!! Extraction failed - restoring the previous list."
    cp -f "$BAK/lamedb" "$ETC/" 2>/dev/null
    cp -f "$BAK/bouquets.tv" "$ETC/" 2>/dev/null
    cp -f "$BAK/bouquets.radio" "$ETC/" 2>/dev/null
    cp -f "$BAK/old/"* "$ETC/" 2>/dev/null
    sync
fi

# ---- [5/5] start Enigma2 again ----
echo ""
if [ "$STOPPED" = "1" ]; then
    echo ">> [5/5] Starting Enigma2 ..."
    $START
    sleep 20
    if ! pidof enigma2 >/dev/null 2>&1; then
        echo "   Enigma2 is still down, starting it once more ..."
        $START
        sleep 25
    fi
    echo ""
    if pidof enigma2 >/dev/null 2>&1; then
        echo "==============================================="
        echo " DONE: $LABEL installed."
        echo " Backup of the old list: $BAK"
        echo "==============================================="
    else
        echo "!! Enigma2 did not come back - rebooting the box."
        sync
        "$REBOOT_BIN"
    fi
else
    echo ">> [5/5] Test mode: Enigma2 is not started."
fi

rm -f "$TAR"
exit 0
