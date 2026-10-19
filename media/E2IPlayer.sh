#!/bin/sh
# ============================================================
# Word Of Enigma2 - MEDIA - E2IPlayer (biko-73)
#
# Original setup command:
#   wget https://raw.githubusercontent.com/biko-73/E2IPlayer/main/installer_E2.sh -O - | /bin/sh
#
# What the official installer does:
#   - installs the dependencies (e2iplayer-deps, exteplayer3, gstplayer,
#     python3-curl/sqlite3/requests/...)
#   - downloads the repository and copies the plugin for the python version
#     of the image (3.9.9 / 3.12 / 3.13)
#   - writes the iptvplayer settings into /etc/enigma2/settings, which is
#     only safe while Enigma2 is stopped (the script does init 4 / init 3)
#
# This wrapper adds what the one-liner cannot do:
#   1. the installer is downloaded into a writable folder first and only
#      started when it arrived completely
#   2. /tmp is repaired when it is missing or not writable (the installer
#      extracts the repository into /tmp)
#   3. the installer is started with bash (it uses bash arrays); if bash is
#      missing it is installed from the feed first
#   4. the installer's own wget calls and its init 4 / init 3 use the real
#      commands, also when this runs inside a batch install (the store
#      blocks init during a batch; the settings file must not be written
#      while Enigma2 is running)
#   5. Enigma2 is checked at the end and started again if it did not come
#      back (reboot as last resort)
# ============================================================

URL="${E2I_URL:-https://raw.githubusercontent.com/biko-73/E2IPlayer/main/installer_E2.sh}"
NAME="E2IPlayer (IPTVPlayer)"
PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/IPTVPlayer"

echo "==============================================="
echo " $NAME"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/e2iplayer.$$"
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
REAL_WGET=$(command -v wget 2>/dev/null)
mkdir -p "$WORK/bin" 2>/dev/null
if [ -n "$REAL_WGET" ] && [ -d "$WORK/bin" ]; then
    {
        echo "#!/bin/sh"
        echo "exec \"$REAL_WGET\" --no-check-certificate \"\$@\""
    } > "$WORK/bin/wget" 2>/dev/null
    chmod +x "$WORK/bin/wget" 2>/dev/null
fi
if [ "$BATCH" = "1" ] && [ -d "$WORK/bin" ]; then
    # the store blocks init during a batch, but this installer must stop
    # Enigma2 while it writes /etc/enigma2/settings
    {
        echo "#!/bin/sh"
        echo "exec /sbin/init \"\$@\""
    } > "$WORK/bin/init" 2>/dev/null
    chmod +x "$WORK/bin/init" 2>/dev/null
    echo "   (real init is used, the store blocks it during a batch)"
fi
if [ -x "$WORK/bin/wget" ] || [ -x "$WORK/bin/init" ]; then
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
if [ -e "$PLUGIN_DIR" ]; then
    echo "   ok: $PLUGIN_DIR"
else
    echo "   !! $PLUGIN_DIR was not created - see the installer log above."
fi

# ---- [5/5] make sure Enigma2 is back ----
echo ""
echo ">> [5/5] Checking Enigma2 ..."
if [ "${E2I_TEST_NO_RESTART:-0}" = "1" ]; then
    echo "   test mode: Enigma2 is not touched"
elif e2_running; then
    echo "   Enigma2 is running"
else
    echo "   Enigma2 is not running - starting it ..."
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
fi

echo ""
echo "==============================================="
if [ "$rc" = "0" ]; then
    echo " $NAME: finished."
    echo " Start it from the plugin list (IPTVPlayer)."
else
    echo " $NAME: the installer stopped with exit code $rc."
    echo " Run it again once the connection is stable."
fi
echo "==============================================="

rm -f "$INST"
rm -rf "$WORK/bin" 2>/dev/null
exit "$rc"
