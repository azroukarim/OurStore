#!/bin/sh
# ============================================================
# Word Of Enigma2 - PLUGINS - PomBiss (Shr776)
#
# Original setup command:
#   cd /tmp && wget https://raw.githubusercontent.com/Shr776/PomBiss/main/installer.sh && sh installer.sh
#
# What the official installer does:
#   - downloads the PomBiss python files and its picon into /tmp
#   - copies them to /usr/lib/enigma2/python/Plugins/Extensions/PomBiss
#   - removes old .pyo/.pyc files and restarts Enigma2
#
# This wrapper adds what the one-liner cannot do:
#   1. the installer is downloaded into a writable folder first and only
#      started when it arrived completely
#   2. /tmp is repaired when it is missing or not writable
#   3. the old plugin is backed up before the update
#   4. every required file is checked after the install; when a download
#      failed, the files are downloaded again directly and verified
#   5. the old installation is restored when the new one is incomplete
#   6. Enigma2 is started again if the installer stopped it; batch mode
#      leaves the single restart to the store
# ============================================================

URL="${POMBISS_URL:-https://raw.githubusercontent.com/Shr776/PomBiss/main/installer.sh}"
BASE="${POMBISS_BASE:-https://raw.githubusercontent.com/Shr776/PomBiss/main}"
NAME="PomBiss"
PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/PomBiss"
FILES="
__init__.py
plugin.py
signalfinder.py
signalfinder_pli_py2.py
signalfinder_atv.py
signalfinder_obh.py
updater.py
registration.py
version.txt
"

echo "==============================================="
echo " $NAME"
echo " source: github.com/Shr776/PomBiss"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/pombiss.$$"
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
BACKUP="$WORK/backup"

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
if ! grep -qi "pombiss" "$INST" 2>/dev/null; then
    echo "!! The downloaded file is not the PomBiss installer."
    rm -rf "$WORK"
    exit 1
fi
tr -d '\r' < "$INST" > "$INST.lf" 2>/dev/null && mv -f "$INST.lf" "$INST"
echo "   installer ok: $(wc -c < "$INST") bytes"

if [ "${POMBISS_DRY_RUN:-0}" = "1" ]; then
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

# ---- real binaries for a restart (batch installs block "init") ----
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

check_files() {
    for _f in $FILES; do
        [ -s "$PLUGIN_DIR/$_f" ] || return 1
    done
    [ -s "$PLUGIN_DIR/picon/PomBiss_logo.png" ] || return 1
    return 0
}

# ---- [3/6] back up the old plugin ----
echo ""
echo ">> [3/6] Backing up the old installation ..."
HAD_OLD="0"
if [ -d "$PLUGIN_DIR" ]; then
    if cp -R "$PLUGIN_DIR" "$BACKUP" 2>/dev/null; then
        HAD_OLD="1"
        echo "   old installation saved"
    else
        echo "   !! could not back up the old installation - continuing"
    fi
else
    echo "   no old installation"
fi

# ---- [4/6] run the official installer ----
echo ""
echo ">> [4/6] Running the official installer ..."
echo ""
REAL_WGET=$(command -v wget 2>/dev/null)
if [ -n "$REAL_WGET" ]; then
    mkdir -p "$WORK/bin" 2>/dev/null
    {
        echo "#!/bin/sh"
        echo "exec \"$REAL_WGET\" -T 90 --no-check-certificate \"\$@\""
    } > "$WORK/bin/wget" 2>/dev/null
    if chmod +x "$WORK/bin/wget" 2>/dev/null && [ -x "$WORK/bin/wget" ]; then
        PATH="$WORK/bin:$PATH"
        export PATH
        echo "   (download timeout and certificate check adjusted)"
        echo ""
    fi
fi

sh "$INST"
rc=$?

# ---- [5/6] check every file, retry directly when needed ----
echo ""
echo ">> [5/6] Checking the installation ..."
FOUND="0"
USED_FALLBACK="0"
if check_files; then
    echo "   ok: $PLUGIN_DIR"
    FOUND="1"
else
    echo "   !! some PomBiss files are missing - retrying directly ..."
    WGET="$REAL_WGET"
    [ -n "$WGET" ] || WGET="wget"
    DL_FAIL="0"
    rm -rf "$WORK/files"
    mkdir -p "$WORK/files/picon" 2>/dev/null
    for _f in $FILES; do
        "$WGET" -q -T 90 --tries=2 --no-check-certificate "$BASE/$_f" -O "$WORK/files/$_f" || DL_FAIL="1"
        [ -s "$WORK/files/$_f" ] || DL_FAIL="1"
    done
    "$WGET" -q -T 90 --tries=2 --no-check-certificate "$BASE/picon/PomBiss_logo.png" -O "$WORK/files/picon/PomBiss_logo.png" || DL_FAIL="1"
    [ -s "$WORK/files/picon/PomBiss_logo.png" ] || DL_FAIL="1"

    if [ "$DL_FAIL" = "0" ]; then
        mkdir -p "$PLUGIN_DIR/picon" 2>/dev/null
        for _f in $FILES; do
            cp -f "$WORK/files/$_f" "$PLUGIN_DIR/$_f" 2>/dev/null || DL_FAIL="1"
        done
        cp -f "$WORK/files/picon/PomBiss_logo.png" "$PLUGIN_DIR/picon/" 2>/dev/null || DL_FAIL="1"
        chmod 644 "$PLUGIN_DIR"/*.py 2>/dev/null
        chmod 644 "$PLUGIN_DIR"/*.png 2>/dev/null
        chmod 755 "$PLUGIN_DIR/picon" 2>/dev/null
        chmod 644 "$PLUGIN_DIR/picon/"* 2>/dev/null
        rm -f "$PLUGIN_DIR"/*.pyo "$PLUGIN_DIR"/*.pyc 2>/dev/null
        if [ "$DL_FAIL" = "0" ] && check_files; then
            echo "   ok: all files downloaded again and installed"
            FOUND="1"
            USED_FALLBACK="1"
        fi
    else
        echo "   !! the direct download did not complete"
    fi

    if [ "$FOUND" != "1" ]; then
        if [ "$HAD_OLD" = "1" ] && [ -d "$BACKUP" ]; then
            echo "   restoring the old installation ..."
            rm -rf "$PLUGIN_DIR" 2>/dev/null
            cp -R "$BACKUP" "$PLUGIN_DIR" 2>/dev/null
        else
            echo "   removing the incomplete installation ..."
            rm -rf "$PLUGIN_DIR" 2>/dev/null
        fi
        rc=1
    fi
fi

if [ "$FOUND" = "1" ]; then
    rc=0
    _ver=$(head -n 1 "$PLUGIN_DIR/version.txt" 2>/dev/null)
    [ -n "$_ver" ] && echo "   version: $_ver"
fi

# ---- [6/6] make sure Enigma2 is running again ----
echo ""
echo ">> [6/6] Checking Enigma2 ..."
if [ "${POMBISS_TEST_NO_RESTART:-0}" = "1" ]; then
    echo "   test mode: Enigma2 is not touched"
elif [ "$FOUND" != "1" ]; then
    echo "   the installation is incomplete - no restart needed"
elif [ "$BATCH" = "1" ]; then
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
elif [ "$USED_FALLBACK" = "1" ]; then
    echo "   restarting Enigma2 to load $NAME ..."
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
else
    echo "   Enigma2 is running (the installer restarted it)"
fi

echo ""
echo "==============================================="
if [ "$FOUND" = "1" ] && [ "$rc" = "0" ]; then
    echo " $NAME: installed."
    echo " Start it from the plugin list (PomBiss)."
else
    echo " $NAME: installation failed (exit $rc)."
    echo " Run it again once the connection is stable."
    [ "$rc" = "0" ] && rc=1
fi
echo "==============================================="

rm -f "$INST" 2>/dev/null
rm -rf "$WORK/bin" "$WORK/files" 2>/dev/null
rm -rf "$WORK"
exit "$rc"
