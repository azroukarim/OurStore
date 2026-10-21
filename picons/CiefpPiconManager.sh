#!/bin/sh
# ============================================================
# Word Of Enigma2 - PICONS - CiefpPiconManager (ciefp)
#
# Original setup command:
#   wget -q "--no-check-certificate" https://raw.githubusercontent.com/ciefp/CiefpPiconManager/main/installer.sh -O - | /bin/sh
#
# What the official installer does:
#   - installs python requests / pillow when they are missing
#   - deletes the old plugin folder
#   - downloads the repository archive into /tmp
#   - copies its usr/ tree to / and kills Enigma2 at the end
#
# This wrapper adds what the one-liner cannot do:
#   1. the installer is downloaded into a writable folder first and only
#      started when it arrived completely
#   2. /tmp is repaired when it is missing or not writable
#   3. the old plugin is backed up before the installer deletes it
#   4. the installer runs with SKIP_REBOOT=1, so the wrapper can verify
#      the result first and restart Enigma2 exactly once
#   5. every important plugin file is checked; when the install failed,
#      the archive is downloaded and copied again directly
#   6. the plugin is also placed in /usr/lib64 when the image uses that
#      path (the upstream archive only contains usr/lib)
#   7. the old installation is restored when the new one is incomplete
# ============================================================

URL="${CIEFP_URL:-https://raw.githubusercontent.com/ciefp/CiefpPiconManager/main/installer.sh}"
ARCHIVE_URL="${CIEFP_ARCHIVE_URL:-https://github.com/ciefp/CiefpPiconManager/archive/refs/heads/main.tar.gz}"
NAME="CiefpPiconManager"
PLUGIN_REL="enigma2/python/Plugins/Extensions/CiefpPiconManager"
PLUGIN_LIB="/usr/lib/$PLUGIN_REL"
PLUGIN_LIB64="/usr/lib64/$PLUGIN_REL"

echo "==============================================="
echo " $NAME"
echo " source: github.com/ciefp/CiefpPiconManager"
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
INST="$WORK/installer.sh"
BACKUP_LIB="$WORK/backup-lib"
BACKUP_LIB64="$WORK/backup-lib64"

# ---- [1/7] download the official installer + check it ----
echo ""
echo ">> [1/7] Downloading the installer ..."
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
if ! grep -qi "CiefpPiconManager" "$INST" 2>/dev/null; then
    echo "!! The downloaded file is not the CiefpPiconManager installer."
    rm -rf "$WORK"
    exit 1
fi
tr -d '\r' < "$INST" > "$INST.lf" 2>/dev/null && mv -f "$INST.lf" "$INST"
echo "   installer ok: $(wc -c < "$INST") bytes"

if [ "${CIEFP_DRY_RUN:-0}" = "1" ]; then
    echo "   dry run: installer downloaded and validated; not executing."
    rm -rf "$WORK"
    exit 0
fi

# ---- [2/7] make sure the installer can use /tmp ----
echo ""
echo ">> [2/7] Checking /tmp ..."
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

check_plugin_dir() {
    [ -d "$1" ] || return 1
    for _f in __init__.py plugin.py components/picon_manager.py screens/download_picons.py; do
        [ -s "$1/$_f" ] || return 1
    done
    return 0
}
plugin_found() {
    check_plugin_dir "$PLUGIN_LIB" && return 0
    check_plugin_dir "$PLUGIN_LIB64" && return 0
    return 1
}
normalize_plugin() {
    if [ -d /usr/lib64 ] && check_plugin_dir "$PLUGIN_LIB" && ! check_plugin_dir "$PLUGIN_LIB64"; then
        mkdir -p "/usr/lib64/enigma2/python/Plugins/Extensions" 2>/dev/null
        cp -R "$PLUGIN_LIB" "$PLUGIN_LIB64" 2>/dev/null
        if check_plugin_dir "$PLUGIN_LIB64"; then
            echo "   plugin also placed in /usr/lib64"
        fi
    fi
}

# ---- [3/7] back up the old plugin ----
echo ""
echo ">> [3/7] Backing up the old installation ..."
HAD_LIB="0"
HAD_LIB64="0"
if [ -d "$PLUGIN_LIB" ]; then
    if mkdir -p "$BACKUP_LIB" 2>/dev/null && cp -R "$PLUGIN_LIB/." "$BACKUP_LIB/" 2>/dev/null; then
        HAD_LIB="1"
        echo "   /usr/lib copy saved"
    else
        echo "!! could not back up $PLUGIN_LIB - aborting before touching it."
        rm -rf "$WORK"
        exit 1
    fi
fi
if [ -d "$PLUGIN_LIB64" ]; then
    if mkdir -p "$BACKUP_LIB64" 2>/dev/null && cp -R "$PLUGIN_LIB64/." "$BACKUP_LIB64/" 2>/dev/null; then
        HAD_LIB64="1"
        echo "   /usr/lib64 copy saved"
    else
        echo "!! could not back up $PLUGIN_LIB64 - aborting before touching it."
        rm -rf "$WORK"
        exit 1
    fi
fi
if [ "$HAD_LIB" = "0" ] && [ "$HAD_LIB64" = "0" ]; then
    echo "   no old installation"
fi

# the official installer removes only one of the two paths; remove both
# so no stale files from an older release remain
rm -rf "$PLUGIN_LIB" "$PLUGIN_LIB64"

# ---- [4/7] run the official installer ----
echo ""
echo ">> [4/7] Running the official installer ..."
echo ""
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

SH_BIN="/bin/sh"
if command -v bash >/dev/null 2>&1; then
    SH_BIN=$(command -v bash)
fi
SKIP_REBOOT=1 "$SH_BIN" "$INST"
rc=$?
normalize_plugin

# ---- [5/7] check the installation ----
echo ""
echo ">> [5/7] Checking the installation ..."
FOUND="0"
USED_FALLBACK="0"
if plugin_found; then
    FOUND="1"
    if check_plugin_dir "$PLUGIN_LIB64"; then
        echo "   ok: $PLUGIN_LIB64"
    else
        echo "   ok: $PLUGIN_LIB"
    fi
else
    echo "   !! the plugin files are missing - retrying directly ..."
fi

# ---- [6/7] direct archive fallback ----
if [ "$FOUND" != "1" ]; then
    WGET="$REAL_WGET"
    [ -n "$WGET" ] || WGET="wget"
    ARCHIVE="$WORK/main.tar.gz"
    rm -f "$ARCHIVE"
    "$WGET" -q -T 180 --tries=2 --no-check-certificate "$ARCHIVE_URL" -O "$ARCHIVE"
    ASIZE=$(wc -c < "$ARCHIVE" 2>/dev/null | tr -d ' ')
    if [ -z "$ASIZE" ] || [ "$ASIZE" -lt 100000 ]; then
        echo "   !! archive download failed or is too small."
    else
        rm -rf "$WORK/extract"
        mkdir -p "$WORK/extract"
        if ! tar -xzf "$ARCHIVE" -C "$WORK/extract" 2>/dev/null; then
            echo "   !! could not extract the archive."
        else
            SRC="$WORK/extract/CiefpPiconManager-main/usr/lib/enigma2/python/Plugins/Extensions/CiefpPiconManager"
            if [ ! -d "$SRC" ]; then
                echo "   !! the expected plugin folder is not in the archive."
            else
                rm -rf "$PLUGIN_LIB" "$PLUGIN_LIB64"
                mkdir -p "$PLUGIN_LIB" 2>/dev/null
                if cp -R "$SRC/." "$PLUGIN_LIB/" 2>/dev/null; then
                    normalize_plugin
                    chmod -R 755 "$PLUGIN_LIB" 2>/dev/null
                    [ -d "$PLUGIN_LIB64" ] && chmod -R 755 "$PLUGIN_LIB64" 2>/dev/null
                    if plugin_found; then
                        echo "   ok: the archive was installed directly"
                        FOUND="1"
                        USED_FALLBACK="1"
                    fi
                fi
            fi
        fi
    fi
fi

if [ "$FOUND" != "1" ]; then
    echo "   restoring the old installation ..."
    rm -rf "$PLUGIN_LIB" "$PLUGIN_LIB64" 2>/dev/null
    if [ "$HAD_LIB" = "1" ] && [ -d "$BACKUP_LIB" ]; then
        mkdir -p "$PLUGIN_LIB" 2>/dev/null
        cp -R "$BACKUP_LIB/." "$PLUGIN_LIB/" 2>/dev/null
    fi
    if [ "$HAD_LIB64" = "1" ] && [ -d "$BACKUP_LIB64" ]; then
        mkdir -p "$PLUGIN_LIB64" 2>/dev/null
        cp -R "$BACKUP_LIB64/." "$PLUGIN_LIB64/" 2>/dev/null
    fi
    if [ "$HAD_LIB" = "0" ] && [ "$HAD_LIB64" = "0" ]; then
        echo "   the incomplete installation was removed."
    fi
    rc=1
fi

if [ "$FOUND" = "1" ]; then
    rc=0
fi

# ---- [7/7] make sure Enigma2 is running again ----
echo ""
echo ">> [7/7] Checking Enigma2 ..."
if [ "${CIEFP_TEST_NO_RESTART:-0}" = "1" ]; then
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
else
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
fi

if [ "$FOUND" = "1" ]; then
    PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
    if [ -n "$PY" ]; then
        "$PY" -c 'import requests' >/dev/null 2>&1 || echo "   warning: python requests is missing - the installer could not add it."
        "$PY" -c 'import PIL' >/dev/null 2>&1 || echo "   warning: python PIL/Pillow is missing - the installer could not add it."
    fi
fi

echo ""
echo "==============================================="
if [ "$FOUND" = "1" ] && [ "$rc" = "0" ]; then
    echo " $NAME: installed."
    echo " Start it from the plugin list (CiefpPiconManager)."
else
    echo " $NAME: installation failed (exit $rc)."
    echo " Run it again once the connection is stable."
    [ "$rc" = "0" ] && rc=1
fi
echo "==============================================="

rm -f "$INST" 2>/dev/null
rm -rf "$WORK/bin" "$WORK/extract" 2>/dev/null
rm -rf /tmp/CiefpPiconManager 2>/dev/null
rm -rf "$WORK"
exit "$rc"
