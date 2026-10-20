#!/bin/sh
# ============================================================
# Word Of Enigma2 - MULTIBOOT - NeoBoot (gutosie)
#
# Original setup command:
#   opkg update
#   opkg install curl
#   curl -kLs https://raw.githubusercontent.com/gutosie/neoboot/master/iNB.sh | sh
#
# What the official installer does:
#   - downloads the NeoBoot repository archive into /tmp
#     (curl, then wget as fallback), unpacks it with unzip
#   - copies the NeoBoot plugin into the Extensions folder
#   - refuses to run when the box is already inside a multiboot slot
#     (it only installs from the flash image)
#   - at the very end it stops Enigma2 (killall -9 enigma2, or
#     systemctl restart on DreamOS) and does NOT always start it again
#
# This wrapper adds what the one-liner cannot do:
#   1. the installer is downloaded into a writable folder first and only
#      started when it arrived completely
#   2. /tmp is repaired when it is missing or not writable (the installer
#      unpacks its archive in /tmp)
#   3. curl and unzip are installed from the image feed when missing
#   4. its wget calls tolerate an image without CA certificates
#   5. after the installer stopped Enigma2, Enigma2 is started again
#      (second try, then a reboot as last resort)
# ============================================================

URL="${NEOBOOT_URL:-https://raw.githubusercontent.com/gutosie/neoboot/master/iNB.sh}"
NAME="NeoBoot"
PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/NeoBoot"

echo "==============================================="
echo " $NAME"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/neoboot.$$"
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
INST="$WORK/installer.sh"

# ---- [1/5] download the official installer + check it ----
echo ""
echo ">> [1/5] Downloading the installer ..."
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

# ---- [2/5] make sure the official installer can use /tmp ----
echo ""
echo ">> [2/5] Checking /tmp ..."
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

# ---- real binaries for a restart (batch installs block "init") ----
INIT_BIN=$(command -v init 2>/dev/null)
BATCH="0"
case "$INIT_BIN" in
    *wordofenigma2_block*) BATCH="1"; INIT_BIN="/sbin/init" ;;
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

e2_running() {
    if command -v pidof >/dev/null 2>&1; then
        pidof enigma2 >/dev/null 2>&1
    else
        ps 2>/dev/null | grep -q "[e]nigma2"
    fi
}
e2_start() {
    if [ -d /run/systemd/system ] && [ -x "$SYSCTL_BIN" ]; then
        "$SYSCTL_BIN" start enigma2
    else
        "$INIT_BIN" 3
    fi
}

# ---- [3/5] run the official installer ----
echo ""
echo ">> [3/5] Running the official installer ..."
echo ""

# NeoBoot needs curl (archive download) and unzip (unpacking).
_need=""
command -v curl >/dev/null 2>&1 || _need="$_need curl"
command -v unzip >/dev/null 2>&1 || _need="$_need unzip"
if [ -n "$_need" ]; then
    echo "   installing missing tools:$_need ..."
    if [ -f /etc/apt/apt.conf ]; then
        apt-get update >/dev/null 2>&1
        apt-get -y install $_need >/dev/null 2>&1
    else
        opkg update >/dev/null 2>&1
        opkg install $_need >/dev/null 2>&1
    fi
    command -v curl >/dev/null 2>&1 || echo "   !! curl is still missing - the installer will try wget"
    command -v unzip >/dev/null 2>&1 || echo "   !! unzip is still missing - the installer may fail"
fi

REAL_WGET=$(command -v wget 2>/dev/null)
mkdir -p "$WORK/bin" 2>/dev/null
if [ -n "$REAL_WGET" ] && [ -d "$WORK/bin" ]; then
    {
        echo "#!/bin/sh"
        echo "exec \"$REAL_WGET\" --no-check-certificate \"\$@\""
    } > "$WORK/bin/wget" 2>/dev/null
    chmod +x "$WORK/bin/wget" 2>/dev/null
    PATH="$WORK/bin:$PATH"
    export PATH
fi

sh "$INST"
rc=$?

# ---- [4/5] check the installed folder ----
echo ""
echo ">> [4/5] Checking the installation ..."
FOUND="0"
if [ -d "$PLUGIN_DIR" ] && [ -n "$(ls -A "$PLUGIN_DIR" 2>/dev/null)" ]; then
    echo "   ok: $PLUGIN_DIR"
    FOUND="1"
else
    echo "   !! $PLUGIN_DIR was not created - see the installer log above."
    echo "   Note: NeoBoot only installs from the flash image, not from a"
    echo "   running multiboot slot."
fi

# ---- [5/5] make sure Enigma2 is running again ----
echo ""
echo ">> [5/5] Checking Enigma2 ..."
if [ "${NEOBOOT_TEST_NO_RESTART:-0}" = "1" ]; then
    echo "   test mode: Enigma2 is not touched"
elif ! e2_running; then
    echo "   Enigma2 was stopped by the installer - starting it ..."
    e2_start
    sleep 15
    if ! e2_running; then
        echo "   second try ..."
        e2_start
        sleep 20
    fi
    if e2_running; then
        echo "   ok: Enigma2 is back"
    else
        echo "!! Enigma2 did not come back - rebooting the box."
        sync
        "$REBOOT_BIN"
    fi
elif [ "$FOUND" != "1" ]; then
    echo "   the plugin folder is missing - no restart needed"
elif [ "$BATCH" = "1" ]; then
    echo "   batch install: the store restarts Enigma2 once at the end"
else
    echo "   restarting Enigma2 to load $NAME ..."
    if [ -d /run/systemd/system ] && [ -x "$SYSCTL_BIN" ]; then
        "$SYSCTL_BIN" restart enigma2
    else
        "$INIT_BIN" 4
        sleep 4
        "$INIT_BIN" 3
    fi
    sleep 15
    if ! e2_running; then
        echo "   second try ..."
        "$INIT_BIN" 4
        sleep 4
        "$INIT_BIN" 3
        sleep 20
    fi
    if ! e2_running; then
        echo "!! Enigma2 did not come back - rebooting the box."
        sync
        "$REBOOT_BIN"
    else
        echo "   ok: Enigma2 restarted"
    fi
fi

echo ""
echo "==============================================="
if [ "$rc" = "0" ]; then
    echo " $NAME: finished."
    echo " Start it from the plugin list (NeoBoot)."
    echo " NeoBoot installs only from the flash image."
else
    echo " $NAME: the installer stopped with exit code $rc."
    echo " Run it again once the connection is stable."
fi
echo "==============================================="

rm -f "$INST"
rm -rf "$WORK/bin" 2>/dev/null
exit "$rc"
