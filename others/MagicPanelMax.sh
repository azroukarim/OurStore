#!/bin/sh
# ============================================================
# Word Of Enigma2 - OTHERS - MagicPanelMax (Ham-ahmed)
#
# Original setup command:
#   wget -q "--no-check-certificate" https://raw.githubusercontent.com/Ham-ahmed/G12/refs/heads/main/MagicPanelMax-install.sh -O - | /bin/sh
#
# The official installer is a bash script (it uses arrays), so this
# wrapper downloads it first, checks it, and runs it with bash.
# It installs MagicPanelMax v12.0 (the only archive published at
# the moment) into:
#   /usr/lib/enigma2/python/Plugins/Extensions/MagicPanelMax
# and restarts Enigma2 itself.
#
# This wrapper adds:
#   1. a complete download check before anything is executed
#   2. a /tmp repair for images where /tmp is broken
#   3. bash detection/installation (busybox sh cannot run the arrays)
#   4. a backup of the old plugin, restored if the install fails
# ============================================================

URL="${MAGICPANEL_URL:-https://raw.githubusercontent.com/Ham-ahmed/G12/refs/heads/main/MagicPanelMax-install.sh}"
NAME="MagicPanelMax"

if [ -d /usr/lib64 ]; then
    PDIR="/usr/lib64/enigma2/python/Plugins/Extensions/MagicPanelMax"
else
    PDIR="/usr/lib/enigma2/python/Plugins/Extensions/MagicPanelMax"
fi

echo "==============================================="
echo " $NAME installer"
echo " source: github.com/Ham-ahmed/G12"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/magicpanel.$$"
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

# ---- [1/5] download + check ----
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
if ! grep -q 'MagicPanelMax' "$INST" 2>/dev/null; then
    echo "!! The downloaded file is not the MagicPanelMax installer."
    rm -rf "$WORK"
    exit 1
fi
tr -d '\r' < "$INST" > "$INST.lf" 2>/dev/null && mv -f "$INST.lf" "$INST"
echo "   installer ok: $(wc -c < "$INST") bytes"

if [ "${MAGICPANEL_DRY_RUN:-0}" = "1" ]; then
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

# ---- [3/5] the installer needs bash ----
echo ""
echo ">> [3/5] Checking bash ..."
RUNNER=""
if command -v bash >/dev/null 2>&1; then
    RUNNER="bash"
    echo "   using bash"
else
    if command -v opkg >/dev/null 2>&1; then
        echo "   bash is missing - installing it from the feed ..."
        opkg update >/dev/null 2>&1
        opkg install bash >/dev/null 2>&1
    elif command -v apt-get >/dev/null 2>&1; then
        echo "   bash is missing - installing it with apt-get ..."
        apt-get update >/dev/null 2>&1
        apt-get install -y bash >/dev/null 2>&1
    fi
    if command -v bash >/dev/null 2>&1; then
        RUNNER="bash"
        echo "   bash installed"
    elif sh -c '[ -n "$BASH_VERSION" ]' 2>/dev/null; then
        RUNNER="sh"
        echo "   /bin/sh is bash - using it"
    else
        echo "!! bash is required by the official installer and could not be installed."
        echo "!! Nothing was installed."
        rm -rf "$WORK"
        exit 1
    fi
fi

# ---- [4/5] backup the old plugin ----
BACKUP=""
if [ -d "$PDIR" ]; then
    mkdir -p "$WORK/plugin.bak" 2>/dev/null
    if cp -r "$PDIR/." "$WORK/plugin.bak/" 2>/dev/null; then
        BACKUP="$WORK/plugin.bak"
        echo ""
        echo "   backup: $PDIR"
    else
        echo ""
        echo "   !! could not back up the old plugin - continuing"
    fi
fi

# ---- [5/5] run the official installer ----
echo ""
echo ">> [4/5] Running the official installer ..."
echo "   (it may pause ~10 seconds for its version check)"
echo ""
"$RUNNER" "$INST"
rc=$?

# ---- check + restore ----
echo ""
echo ">> [5/5] Checking the installation ..."
FOUND="0"
if [ -d "$PDIR" ] && [ -f "$PDIR/plugin.py" ]; then
    echo "   ok: $PDIR"
    FOUND="1"
elif [ -d "$PDIR" ] && [ -n "$(ls -A "$PDIR" 2>/dev/null)" ]; then
    echo "   ok (files present): $PDIR"
    FOUND="1"
else
    echo "   !! $NAME was not found in $PDIR"
fi

if [ "$FOUND" = "0" ] && [ -n "$BACKUP" ] && [ ! -f "$PDIR/plugin.py" ]; then
    echo "   restoring the previous installation ..."
    rm -rf "$PDIR" 2>/dev/null
    mkdir -p "$(dirname "$PDIR")" 2>/dev/null
    if cp -r "$BACKUP" "$PDIR" 2>/dev/null; then
        echo "   previous installation restored"
    fi
fi

# ---- Enigma2 restart fallback (the installer usually restarts it) ----
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

echo ""
if [ "$BATCH" = "1" ]; then
    echo ">> Batch install: the store restarts Enigma2 once at the end."
elif [ "$FOUND" != "1" ]; then
    echo ">> $NAME is not installed - Enigma2 is not restarted."
elif e2_running; then
    echo ">> Enigma2 is running."
else
    echo ">> Enigma2 is down - starting it ..."
    e2_start
    sleep 15
    if ! e2_running; then
        echo "   second try ..."
        e2_start
        sleep 20
    fi
    if e2_running; then
        echo "   ok: Enigma2 is running"
    else
        echo "!! Enigma2 did not come back - please reboot the box."
    fi
fi

echo ""
echo "==============================================="
if [ "$FOUND" = "1" ]; then
    echo " DONE: $NAME installed."
    echo " Start it from the plugin list."
else
    echo " $NAME: installation failed (exit $rc)."
    [ "$rc" = "0" ] && rc=1
fi
echo "==============================================="

rm -f "$INST"
rm -rf "$WORK"
exit "$rc"
