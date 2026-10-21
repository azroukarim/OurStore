#!/bin/sh
# ============================================================
# Word Of Enigma2 - MULTIBOOT - MOHBoot (mido00020)
#
# Original setup command:
#   wget -qO- https://raw.githubusercontent.com/mido00020/MOHBoot/main/install.sh | sh
#
# What the official installer does:
#   - reads version.json, downloads the newest MOHBoot IPK
#   - checks its sha256, installs it with opkg --force-reinstall
#   - at the end it kills Enigma2 (killall -9 enigma2) and does
#     NOT start it again
#
# This wrapper adds what the one-liner cannot do:
#   1. the installer is downloaded into a writable folder first and only
#      started when it arrived completely
#   2. /tmp is repaired when it is missing or not writable
#   3. the installer's own wget calls tolerate an image without CA
#      certificates
#   4. the plugin folder is checked; when the installer failed, the
#      package is downloaded and verified again directly (also works on
#      Python 2 images, where the official version.json parser fails)
#   5. Enigma2 is started again after the installer killed it, and the
#      plugin is loaded with one restart; batch mode leaves the single
#      restart to the store
# ============================================================

URL="${MOHBOOT_URL:-https://raw.githubusercontent.com/mido00020/MOHBoot/main/install.sh}"
BASE="${MOHBOOT_BASE:-https://raw.githubusercontent.com/mido00020/MOHBoot/main}"
NAME="MOHBoot"
PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/MOHBoot"

echo "==============================================="
echo " $NAME"
echo " source: github.com/mido00020/MOHBoot"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/mohboot.$$"
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
INST="$WORK/install.sh"

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
if ! grep -qi "mohboot" "$INST" 2>/dev/null; then
    echo "!! The downloaded file is not the MOHBoot installer."
    rm -rf "$WORK"
    exit 1
fi
tr -d '\r' < "$INST" > "$INST.lf" 2>/dev/null && mv -f "$INST.lf" "$INST"
echo "   installer ok: $(wc -c < "$INST") bytes"

if [ "${MOHBOOT_DRY_RUN:-0}" = "1" ]; then
    echo "   dry run: installer downloaded and validated; not executing."
    rm -rf "$WORK"
    exit 0
fi

# ---- [2/5] make sure the installer can use /tmp ----
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
echo ""
PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PY" ]; then
    echo "   !! python was not found - the official installer may fail."
fi

REAL_WGET=$(command -v wget 2>/dev/null)
if [ -n "$REAL_WGET" ]; then
    mkdir -p "$WORK/bin" 2>/dev/null
    {
        echo "#!/bin/sh"
        echo "exec \"$REAL_WGET\" --no-check-certificate \"\$@\""
    } > "$WORK/bin/wget" 2>/dev/null
    if chmod +x "$WORK/bin/wget" 2>/dev/null && [ -x "$WORK/bin/wget" ]; then
        PATH="$WORK/bin:$PATH"
        export PATH
        echo "   (certificate check disabled for the installer's downloads)"
        echo ""
    fi
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
fi

if [ "$FOUND" != "1" ]; then
    echo ""
    echo "   retrying the package directly ..."
    if [ -z "$PY" ]; then
        echo "   !! python is required to read version.json - cannot retry."
        rc=1
    else
        WGET="$REAL_WGET"
        [ -n "$WGET" ] || WGET="wget"
        rm -f "$WORK/version.json"
        "$WGET" -q -T 90 --tries=2 --no-check-certificate "$BASE/version.json" -O "$WORK/version.json"
        if [ ! -s "$WORK/version.json" ]; then
            echo "   !! version.json download failed."
            rc=1
        else
            set -- $("$PY" -c 'import json,sys;d=json.load(open(sys.argv[1]));print("%s %s %s" % (d["ipk"], d["sha256"], d["version"]))' "$WORK/version.json" 2>/dev/null)
            IPK="$1"; SHA="$2"; VER="$3"
            case "$IPK" in
                enigma2-plugin-extensions-mohboot_*_all.ipk) ;;
                *) IPK="" ;;
            esac
            if [ -z "$IPK" ] || [ ${#SHA} -ne 64 ]; then
                echo "   !! version.json is not valid - cannot retry."
                rc=1
            else
                echo "   downloading MOHBoot $VER (about 17 MB, please wait) ..."
                rm -f "$WORK/$IPK"
                "$WGET" -q -T 300 --tries=2 --no-check-certificate "$BASE/$IPK" -O "$WORK/$IPK"
                if [ ! -s "$WORK/$IPK" ]; then
                    echo "   !! package download failed."
                    rc=1
                else
                    if command -v sha256sum >/dev/null 2>&1; then
                        GOT=$(sha256sum "$WORK/$IPK" | cut -d' ' -f1)
                    else
                        GOT=$("$PY" -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$WORK/$IPK" 2>/dev/null)
                    fi
                    if [ "$GOT" != "$SHA" ]; then
                        echo "   !! checksum mismatch - the package was not installed."
                        rc=1
                    else
                        echo "   checksum ok - installing ..."
                        opkg install --force-reinstall "$WORK/$IPK"
                        rc=$?
                        if [ -d "$PLUGIN_DIR" ] && [ -n "$(ls -A "$PLUGIN_DIR" 2>/dev/null)" ]; then
                            echo "   ok: $PLUGIN_DIR"
                            FOUND="1"
                            rc=0
                        else
                            echo "   !! the direct install did not create $PLUGIN_DIR."
                            rc=1
                        fi
                    fi
                fi
            fi
        fi
    fi
fi

# ---- [5/5] make sure Enigma2 is running again ----
echo ""
echo ">> [5/5] Checking Enigma2 ..."
if [ "${MOHBOOT_TEST_NO_RESTART:-0}" = "1" ]; then
    echo "   test mode: Enigma2 is not touched"
elif [ "$FOUND" != "1" ]; then
    echo "   the plugin folder is missing - no restart needed"
elif [ "$BATCH" = "1" ]; then
    echo "   batch install: the store restarts Enigma2 once at the end"
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

echo ""
echo "==============================================="
if [ "$FOUND" = "1" ] && [ "$rc" = "0" ]; then
    echo " $NAME: installed."
    echo " Start it from the plugin list (MOHBoot)."
else
    echo " $NAME: installation failed (exit $rc)."
    echo " Run it again once the connection is stable."
    [ "$rc" = "0" ] && rc=1
fi
echo "==============================================="

rm -f "$INST" "$WORK/version.json" 2>/dev/null
rm -rf "$WORK/bin" 2>/dev/null
rm -rf "$WORK"
exit "$rc"
