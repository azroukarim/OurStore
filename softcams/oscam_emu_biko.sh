#!/bin/sh
# ============================================================
# Word Of Enigma2 - EMUS - OSCam EMU 11.726 (biko-73)
#
# Original setup command:
#   wget https://raw.githubusercontent.com/biko-73/OsCam_EMU/main/installer.sh -O - | /bin/sh
#
# The official installer chooses the package for the image:
#   - IPK via opkg: enigma2-plugin-softcams-oscam_11.726-emu-r798_all.ipk
#   - DEB via dpkg: enigma2-plugin-softcams-oscam-osdreambox_11.726.deb
# and restarts Enigma2 after a successful install.
#
# This wrapper:
#   1. downloads the official installer into a file and checks it
#   2. repairs /tmp when the image has a broken /tmp
#   3. runs the official installer
#   4. verifies the package; if the install failed it retries the
#      package directly with a longer timeout (the official script
#      uses wget -T 2, which is short for a 3 MB IPK)
# ============================================================

URL="${OSCAM_EMU_URL:-https://raw.githubusercontent.com/biko-73/OsCam_EMU/main/installer.sh}"
NAME="OSCam EMU 11.726"
PKG_NAME="enigma2-plugin-softcams-oscam"

IPK_URL="https://raw.githubusercontent.com/biko-73/OsCam_EMU/main/enigma2-plugin-softcams-oscam_11.726-emu-r798_all.ipk"
DEB_URL="https://raw.githubusercontent.com/biko-73/OsCam_EMU/main/enigma2-plugin-softcams-oscam-osdreambox_11.726.deb"

echo "==============================================="
echo " $NAME"
echo " source: github.com/biko-73/OsCam_EMU"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/oscamemu.$$"
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

# ---- [1/5] download + check the official installer ----
echo ""
echo ">> [1/5] Downloading the official installer ..."
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
if ! head -n 1 "$INST" | grep -q '^#!'; then
    echo "!! The downloaded file is not a shell installer - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
if ! grep -qi 'oscam' "$INST" 2>/dev/null; then
    echo "!! The downloaded file is not the OSCam installer."
    rm -rf "$WORK"
    exit 1
fi
tr -d '\r' < "$INST" > "$INST.lf" 2>/dev/null && mv -f "$INST.lf" "$INST"
echo "   installer ok: $(wc -c < "$INST") bytes"

if [ "${OSCAM_EMU_DRY_RUN:-0}" = "1" ]; then
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

# ---- helpers ----
pkg_installed() {
    if command -v dpkg >/dev/null 2>&1; then
        dpkg -l 2>/dev/null | grep -qi 'softcams-oscam'
    else
        opkg list-installed 2>/dev/null | grep -qi 'softcams-oscam'
    fi
}

# ---- [3/5] run the official installer ----
echo ""
echo ">> [3/5] Running the official installer ..."
echo ""
sh "$INST"
rc=$?

# ---- [4/5] verify + fallback ----
USED_FALLBACK="0"
echo ""
echo ">> [4/5] Checking the installation ..."
if pkg_installed; then
    echo "   ok: $PKG_NAME is installed"
else
    echo "   !! $PKG_NAME was not found - retrying the package directly ..."
    if command -v dpkg >/dev/null 2>&1; then
        PKG_URL="$DEB_URL"
        PKG_FILE="$WORK/oscam.deb"
        INSTALL_CMD="dpkg -i --force-overwrite"
    else
        PKG_URL="$IPK_URL"
        PKG_FILE="$WORK/oscam.ipk"
        INSTALL_CMD="opkg install --force-reinstall"
    fi
    rm -f "$PKG_FILE"
    wget -q -T 180 --tries=2 --no-check-certificate "$PKG_URL" -O "$PKG_FILE"
    if [ ! -s "$PKG_FILE" ]; then
        echo "   retrying without the certificate option ..."
        wget -q -T 180 --tries=2 "$PKG_URL" -O "$PKG_FILE"
    fi
    if [ -s "$PKG_FILE" ]; then
        echo "   package: $(wc -c < "$PKG_FILE") bytes"
        $INSTALL_CMD "$PKG_FILE"
        rc=$?
        rm -f "$PKG_FILE"
        if pkg_installed; then
            echo "   ok: $PKG_NAME is installed (direct retry)"
            USED_FALLBACK="1"
            rc=0
        else
            echo "   !! the direct install also failed"
            rc=1
        fi
    else
        echo "   !! package download failed"
        rc=1
    fi
fi

# ---- [5/5] Enigma2 ----
BATCH="0"
[ "${WORD_OF_ENIGMA2_BATCH:-0}" = "1" ] && BATCH="1"
INIT_BIN=$(command -v init 2>/dev/null)
case "$INIT_BIN" in
    *wordofenigma2_block*) BATCH="1"; INIT_BIN="/sbin/init" ;;
esac
[ -x "$INIT_BIN" ] || INIT_BIN="/sbin/init"
SYSCTL_BIN=$(command -v systemctl 2>/dev/null)
case "$SYSCTL_BIN" in
    *wordofenigma2_block*) SYSCTL_BIN="/bin/systemctl" ;;
esac

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

echo ""
if [ "$BATCH" = "1" ]; then
    echo ">> [5/5] Batch install: the store restarts Enigma2 once at the end."
elif ! pkg_installed; then
    echo ">> [5/5] $NAME is not installed - Enigma2 is not restarted."
elif [ "$USED_FALLBACK" = "1" ]; then
    echo ">> [5/5] Restarting Enigma2 for the new softcam ..."
    e2_restart
    sleep 15
    if ! e2_running; then
        e2_restart
        sleep 20
    fi
    if e2_running; then
        echo "   ok: Enigma2 is running"
    else
        echo "!! Enigma2 did not come back - please reboot the box."
    fi
else
    echo ">> [5/5] Waiting for Enigma2 (the official installer restarted it) ..."
    sleep 10
    if e2_running; then
        echo "   ok: Enigma2 is running"
    else
        echo "   Enigma2 is still down - starting it ..."
        e2_start
        sleep 15
        if e2_running; then
            echo "   ok: Enigma2 is running"
        else
            echo "!! Enigma2 did not come back - please reboot the box."
        fi
    fi
fi

echo ""
echo "==============================================="
if pkg_installed; then
    echo " DONE: $NAME installed."
    echo " Config: /etc/tuxbox/config"
else
    echo " $NAME: installation failed (exit $rc)."
    [ "$rc" = "0" ] && rc=1
fi
echo "==============================================="

rm -f "$INST"
rm -rf "$WORK"
exit "$rc"
