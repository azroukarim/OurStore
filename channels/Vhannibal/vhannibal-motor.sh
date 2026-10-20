#!/bin/sh
# ============================================================
# Word Of Enigma2 - CHANNELS - Vhannibal Motor 70E-45W
# Package : Vhannibal Motor (official ZIP, latest id=5)
# Source  : https://www.vhannibal.net/
#
# IMPORTANT
# This installer does NOT contain and does NOT redistribute any
# Vhannibal setting. The ZIP is downloaded directly from the
# official Vhannibal server at install time. All rights remain
# with Vhannibal (https://www.vhannibal.net/).
#
# The ZIP contains one folder with:
#   lamedb, bouquets.tv/radio, userbouquet.*.tv/radio,
#   blacklist, satellites.xml
# so the files are copied into /etc/enigma2 and
# /etc/tuxbox/satellites.xml (they are not extracted to /).
#
# A channel list must be written while Enigma2 is NOT running,
# otherwise the old list is saved back on exit. This script:
#   1. downloads + extracts the ZIP and checks it BEFORE touching
#      the current list
#   2. backs up lamedb / bouquets / userbouquets / satellites.xml
#   3. stops Enigma2 (the script runs detached, so the restart at
#      the end cannot be killed halfway)
#   4. replaces the channel data
#   5. starts Enigma2 again
# ============================================================

URL="https://www.vhannibal.net/download_setting.php?id=5&action=download"
LABEL="Motor 70E-45W"

# Hooks used by the Word Of Enigma2 test suite (a normal install
# never sets them): VHANNIBAL_URL = other download url,
# VHANNIBAL_ROOT = install below another root instead of /,
# VHANNIBAL_TEST_NO_RESTART=1 = keep Enigma2 running.
URL="${VHANNIBAL_URL:-$URL}"
ROOT="${VHANNIBAL_ROOT:-}"
ETC="$ROOT/etc/enigma2"
TUXBOX="$ROOT/etc/tuxbox"
STOPPED=1

echo "==============================================="
echo " Vhannibal channel list : $LABEL"
echo " official download from vhannibal.net"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/vhannibal.$$"
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
ZIP="$WORK/vhannibal.zip"
EXTRACT="$WORK/extract"
BAK="$WORK/vhannibal-bak"

# ---- [1/5] download ----
echo ""
echo ">> [1/5] Downloading the official Vhannibal package ..."
rm -f "$ZIP"
wget -q -T 180 --tries=2 --no-check-certificate "$URL" -O "$ZIP"
if [ ! -s "$ZIP" ]; then
    echo "   retrying without the certificate option ..."
    wget -q -T 180 --tries=2 "$URL" -O "$ZIP"
fi
if [ ! -s "$ZIP" ]; then
    echo "!! Download failed - check the internet connection."
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
if [ "$(head -c 2 "$ZIP" 2>/dev/null)" != "PK" ]; then
    echo "!! The downloaded file is not a valid ZIP - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
echo "   archive ok: $(wc -c < "$ZIP") bytes"

# ---- [2/5] extract + verify before stopping Enigma2 ----
echo ""
echo ">> [2/5] Extracting and checking the package ..."
mkdir -p "$EXTRACT" 2>/dev/null
if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "$ZIP" -d "$EXTRACT"
elif busybox unzip -q -o "$ZIP" -d "$EXTRACT" 2>/dev/null; then
    :
elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$ZIP" "$EXTRACT"
elif command -v python >/dev/null 2>&1; then
    python -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$ZIP" "$EXTRACT"
else
    echo "!! Neither unzip nor python is available on this image."
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi

SRC=""
SATSRC=""
if [ -f "$EXTRACT/etc/enigma2/lamedb" ]; then
    SRC="$EXTRACT/etc/enigma2"
    SATSRC="$EXTRACT/etc/tuxbox/satellites.xml"
else
    for d in "$EXTRACT"/*; do
        [ -d "$d" ] || continue
        if [ -f "$d/lamedb" ] && [ -f "$d/bouquets.tv" ]; then
            SRC="$d"
            break
        fi
    done
    SATSRC="$SRC/satellites.xml"
fi

if [ -z "$SRC" ] || [ ! -f "$SRC/lamedb" ] || [ ! -f "$SRC/bouquets.tv" ]; then
    echo "!! Unexpected archive content (lamedb/bouquets.tv not found)."
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi

_n=0
for _f in "$SRC"/userbouquet.*.tv "$SRC"/userbouquet.*.radio; do
    [ -f "$_f" ] && _n=$((_n + 1))
done
if [ "$_n" -eq 0 ]; then
    echo "!! No userbouquet files found in the archive."
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
echo "   package: $(basename "$SRC")"
echo "   bouquets: $_n"

# ---- [3/5] backup of the current list ----
echo ""
echo ">> [3/5] Backing up the current channel list ..."
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

# ---- [4/5] stop Enigma2 ----
echo ""
if [ "${VHANNIBAL_TEST_NO_RESTART:-0}" = "1" ]; then
    echo ">> [4/5] Test mode: Enigma2 is not stopped."
    STOPPED=0
else
    echo ">> [4/5] Stopping Enigma2 ..."
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

# ---- [5/5] replace the channel data ----
echo ""
echo ">> [5/5] Installing the new channel list ..."
rm -f "$ETC"/userbouquet.*.tv "$ETC"/userbouquet.*.radio
rm -f "$ETC"/lamedb "$ETC"/lamedb5

_ok=1
for _f in "$SRC"/*; do
    [ -f "$_f" ] || continue
    _base=$(basename "$_f")
    case "$_base" in
        satellites.xml)
            mkdir -p "$TUXBOX" 2>/dev/null
            cp -f "$_f" "$TUXBOX/satellites.xml" || _ok=0
            ;;
        *)
            cp -f "$_f" "$ETC/$_base" || _ok=0
            ;;
    esac
done

if [ "$_ok" = "1" ]; then
    rm -f "$ETC/lamedb5"
    chmod 644 "$ETC"/lamedb "$ETC"/bouquets.* "$ETC"/userbouquet.* 2>/dev/null
    chmod 644 "$TUXBOX/satellites.xml" 2>/dev/null
    sync
    echo "   new list written to $ETC"
else
    echo "!! Copy failed - restoring the previous list."
    cp -f "$BAK/lamedb" "$ETC/" 2>/dev/null
    cp -f "$BAK/bouquets.tv" "$ETC/" 2>/dev/null
    cp -f "$BAK/bouquets.radio" "$ETC/" 2>/dev/null
    cp -f "$BAK/old/"* "$ETC/" 2>/dev/null
    [ -f "$BAK/satellites.xml" ] && cp -f "$BAK/satellites.xml" "$TUXBOX/satellites.xml" 2>/dev/null
    sync
fi

# ---- restart ----
echo ""
if [ "$STOPPED" = "1" ]; then
    echo ">> Starting Enigma2 ..."
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
        echo " DONE: Vhannibal $LABEL installed."
        echo " Backup of the old list: $BAK"
        echo "==============================================="
    else
        echo "!! Enigma2 did not come back - rebooting the box."
        sync
        "$REBOOT_BIN"
    fi
else
    echo ">> Test mode: Enigma2 is not started."
fi

rm -f "$ZIP"
exit 0
