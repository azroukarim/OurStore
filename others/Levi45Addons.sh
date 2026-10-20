#!/bin/sh
# ============================================================
# Word Of Enigma2 - OTHERS - Levi45 Addons (Levi45)
#
# Original setup command:
#   wget -q "--no-check-certificate" https://raw.githubusercontent.com/levi-45/Addon/main/installer.sh -O - | /bin/sh
#
# What the official installer does:
#   - installs python-requests / python3-six from the feed when missing
#   - downloads the repository archive into /tmp and unpacks it there
#   - copies the plugin to .../Plugins/Extensions/Levi45Addons
#   - at the very end it runs "killall -9 enigma2" and does NOT start
#     Enigma2 again: the box stays without a GUI until it is rebooted
#
# This wrapper adds what the one-liner cannot do:
#   1. the installer is downloaded into a writable folder first and only
#      started when it arrived completely
#   2. /tmp is repaired when it is missing or not writable (the installer
#      keeps its archive and unpacked files in /tmp)
#   3. its wget calls tolerate an image without CA certificates
#   4. after the installer killed Enigma2, Enigma2 is started again
#      (second try, then a reboot as last resort)
# ============================================================

URL="${LEVIADDONS_URL:-https://raw.githubusercontent.com/levi-45/Addon/main/installer.sh}"
NAME="Levi45 Addons"
PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/Levi45Addons"
PLUGIN_DIR64="/usr/lib64/enigma2/python/Plugins/Extensions/Levi45Addons"

echo "==============================================="
echo " $NAME"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/leviaddons.$$"
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
e2_restart() {
    if [ -d /run/systemd/system ] && [ -x "$SYSCTL_BIN" ]; then
        "$SYSCTL_BIN" restart enigma2
    else
        "$INIT_BIN" 4
        sleep 4
        "$INIT_BIN" 3
    fi
}

# ---- [3/5] run the official installer ----
echo ""
echo ">> [3/5] Running the official installer ..."
echo "   (the installer stops Enigma2 itself - this script starts it again)"
echo ""
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

# ---- [4/5] check the installed folder ----
echo ""
echo ">> [4/5] Checking the installation ..."
FOUND="0"
if [ -d "$PLUGIN_DIR" ]; then
    echo "   ok: $PLUGIN_DIR"
    FOUND="1"
elif [ -d "$PLUGIN_DIR64" ]; then
    echo "   ok: $PLUGIN_DIR64"
    FOUND="1"
else
    echo "   !! the Levi45Addons folder was not created - see the log above."
fi

# ---- [5/5] make sure Enigma2 is running again ----
echo ""
echo ">> [5/5] Checking Enigma2 ..."
if [ "${LEVIADDONS_TEST_NO_RESTART:-0}" = "1" ]; then
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
elif [ "$BATCH" = "1" ]; then
    echo "   batch install: the store restarts Enigma2 once at the end"
elif [ "$FOUND" != "1" ]; then
    echo "   the plugin folder is missing - no restart needed"
else
    echo "   restarting Enigma2 to load $NAME ..."
    e2_restart
    sleep 15
    if ! e2_running; then
        echo "   second try ..."
        e2_restart
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
    echo " Start it from the plugin list (Levi45 Addons)."
else
    echo " $NAME: the installer stopped with exit code $rc."
    echo " Run it again once the connection is stable."
fi
echo "==============================================="

rm -f "$INST"
rm -rf "$WORK/bin" 2>/dev/null
exit "$rc"
