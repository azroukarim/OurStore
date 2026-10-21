#!/bin/sh
# ============================================================
# Word Of Enigma2 - PLUGINS - Satelliweb Live Feeds 3.4r4
#
# Original setup command:
#   wget -q --no-check-certificate http://dreambox4u.com/dreamarabia/Satelliweb_e2/install_satelliweb_test.sh -O - | bash
#
# What the official installer does:
#   - detects the architecture and the Python version
#   - downloads the matching IPK from dreambox4u.com and installs it
#     with opkg --force-reinstall (or a .deb with apt on DreamOS)
#   - does NOT back up the old Fatima plugin
#   - does NOT restart Enigma2; it only prints "Please restart Enigma2"
#
# This wrapper adds what the one-liner cannot do:
#   1. the installer is downloaded into a writable folder first and only
#      started when it arrived completely
#   2. /tmp is repaired when it is missing or not writable
#   3. the installer's own wget calls tolerate an image without CA
#      certificates and get a real timeout
#   4. the old Fatima plugin is moved aside before the install and is
#      restored when the package could not be installed or is incomplete
#   5. the plugin files are checked after the install
#   6. Enigma2 is restarted once after a successful install; batch mode
#      leaves the single restart to the store
#
# Note: the 3.4r4 packages on the server are published for Python 3.13
# and 3.14 only (aarch64 and cortexa15hf-neon-vfpv4).  On an image with
# Python 3.12/3.11 or on MIPS the download will be refused by the
# server; the wrapper then restores the old plugin and says so.
# ============================================================

URL="${SATELLIWEB_URL:-https://dreambox4u.com/dreamarabia/Satelliweb_e2/install_satelliweb_test.sh}"
NAME="Satelliweb Live Feeds"
FATIMA_DIR="/usr/lib/enigma2/python/Plugins/Extensions/Fatima"
FATIMA_OLD="$FATIMA_DIR.woe-backup"

echo "==============================================="
echo " $NAME"
echo " source: dreambox4u.com/dreamarabia/Satelliweb_e2"
echo "==============================================="

check_fatima() {
    [ -s "$FATIMA_DIR/__init__.py" ] || return 1
    [ -s "$FATIMA_DIR/plugin.py" ] || return 1
    [ -s "$FATIMA_DIR/SatelliwebScreen.so" ] || return 1
    [ -s "$FATIMA_DIR/icon.png" ] || return 1
    return 0
}

# ---- recover from an interrupted previous run ----
if [ -e "$FATIMA_OLD" ]; then
    if check_fatima; then
        # the current installation is complete; the old copy is stale
        rm -rf "$FATIMA_OLD" 2>/dev/null
    else
        rm -rf "$FATIMA_DIR" 2>/dev/null
        if mv "$FATIMA_OLD" "$FATIMA_DIR" 2>/dev/null; then
            echo "   recovered the previous Fatima plugin"
        fi
    fi
fi

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/satelliweb.$$"
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

# ---- [1/6] download the official installer + check it ----
echo ""
echo ">> [1/6] Downloading the installer ..."
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
if ! grep -qi "satelliweb" "$INST" 2>/dev/null; then
    echo "!! The downloaded file is not the Satelliweb installer."
    rm -rf "$WORK"
    exit 1
fi
tr -d '\r' < "$INST" > "$INST.lf" 2>/dev/null && mv -f "$INST.lf" "$INST"
echo "   installer ok: $(wc -c < "$INST") bytes"

if [ "${SATELLIWEB_DRY_RUN:-0}" = "1" ]; then
    echo "   dry run: installer downloaded and validated; not executing."
    rm -rf "$WORK"
    exit 0
fi

# ---- [2/6] make sure the installer can use /tmp ----
echo ""
echo ">> [2/6] Checking /tmp ..."
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

# ---- [3/6] back up the old Fatima plugin ----
echo ""
echo ">> [3/6] Moving the old Fatima plugin aside ..."
HAD_OLD="0"
if [ -d "$FATIMA_DIR" ]; then
    rm -rf "$FATIMA_OLD" 2>/dev/null
    if mv "$FATIMA_DIR" "$FATIMA_OLD" 2>/dev/null; then
        HAD_OLD="1"
        echo "   old plugin saved"
    else
        echo "!! Could not move the old Fatima plugin aside - nothing was changed."
        rm -rf "$WORK"
        exit 1
    fi
else
    echo "   no old Fatima plugin"
fi

restore_fatima() {
    rm -rf "$FATIMA_DIR" 2>/dev/null
    if [ "$HAD_OLD" = "1" ] && [ -e "$FATIMA_OLD" ]; then
        mv "$FATIMA_OLD" "$FATIMA_DIR" 2>/dev/null
    fi
}

# ---- [4/6] run the official installer ----
echo ""
echo ">> [4/6] Running the official installer ..."
echo ""
BASH_BIN=$(command -v bash 2>/dev/null)
if [ -z "$BASH_BIN" ]; then
    echo "!! bash was not found - the official installer needs bash."
    restore_fatima
    rm -rf "$WORK"
    exit 1
fi

REAL_WGET=$(command -v wget 2>/dev/null)
if [ -n "$REAL_WGET" ]; then
    mkdir -p "$WORK/bin" 2>/dev/null
    {
        echo "#!/bin/sh"
        echo "exec \"$REAL_WGET\" -T 180 --no-check-certificate \"\$@\""
    } > "$WORK/bin/wget" 2>/dev/null
    if chmod +x "$WORK/bin/wget" 2>/dev/null && [ -x "$WORK/bin/wget" ]; then
        PATH="$WORK/bin:$PATH"
        export PATH
        echo "   (download timeout and certificate check adjusted)"
        echo ""
    fi
fi

"$BASH_BIN" "$INST"
rc=$?

# ---- [5/6] check the installation ----
echo ""
echo ">> [5/6] Checking the installation ..."
if check_fatima; then
    echo "   ok: $FATIMA_DIR"
    rc=0
else
    echo "   !! the Fatima plugin files are missing"
    restore_fatima
    rc=1
fi

PYV=""
if command -v python3 >/dev/null 2>&1; then
    PYV=$(python3 -c 'import sys;print("py%d.%d" % sys.version_info[:2])' 2>/dev/null)
fi
ARCH=$(uname -m 2>/dev/null)

# ---- [6/6] Enigma2 ----
echo ""
echo ">> [6/6] Checking Enigma2 ..."
if [ "${SATELLIWEB_TEST_NO_RESTART:-0}" = "1" ]; then
    echo "   test mode: Enigma2 is not touched"
elif [ "$rc" != "0" ]; then
    echo "   the installation failed - no restart needed"
else
    INIT_BIN=$(command -v init 2>/dev/null)
    BATCH="0"
    case "$INIT_BIN" in
        *wordofenigma2_block*) BATCH="1"; INIT_BIN="/sbin/init" ;;
    esac
    [ "${WORD_OF_ENIGMA2_BATCH:-0}" = "1" ] && BATCH="1"
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

    if [ "$BATCH" = "1" ]; then
        echo "   batch install: the store restarts Enigma2 once at the end"
    elif ! e2_running; then
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
    else
        echo "   restarting Enigma2 to load Satelliweb ..."
        e2_restart
        sleep 15
        if ! e2_running; then
            echo "   second try ..."
            e2_restart
            sleep 20
        fi
        if e2_running; then
            echo "   ok: Enigma2 restarted"
        else
            echo "!! Enigma2 did not come back - rebooting the box."
            sync
            "$REBOOT_BIN"
        fi
    fi
fi

if [ "$rc" = "0" ]; then
    rm -rf "$FATIMA_OLD" 2>/dev/null
fi

echo ""
echo "==============================================="
if [ "$rc" = "0" ]; then
    echo " $NAME: installed."
    echo " Start it from the plugin list (Satelliweb / Fatima)."
else
    echo " $NAME: installation failed."
    echo " The previous Fatima plugin was restored."
    echo " Image: ${ARCH:-unknown} ${PYV:-unknown}"
    case "$PYV" in
        py3.13|py3.14) echo " See the installer log above (libc / python dependencies)." ;;
        "") echo " Satelliweb 3.4r4 is published for Python 3.13/3.14 only." ;;
        *) echo " Satelliweb 3.4r4 is published for Python 3.13/3.14 only; this image reports $PYV." ;;
    esac
fi
echo "==============================================="

rm -f "$INST" 2>/dev/null
rm -rf "$WORK/bin" 2>/dev/null
rm -rf /tmp/satelliweb_install 2>/dev/null
rm -rf "$WORK"
sync
exit "$rc"
