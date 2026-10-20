#!/bin/sh
# ============================================================
# Word Of Enigma2 - PLUGINS - ReaderManager
#
# Original setup command:
#   wget -qO- https://raw.githubusercontent.com/ismail9875/ReaderManager/main/installer.sh | /bin/sh
#
# The official installer is POSIX sh. It detects the Enigma2 restart
# method, backs up an existing ReaderManager, downloads
# ReaderManager.tar.gz, installs it, and restarts Enigma2.
#
# This wrapper downloads the installer into a file first (so a broken
# connection cannot execute half a script), checks it, then runs it.
# ============================================================

URL="${READERMANAGER_URL:-https://raw.githubusercontent.com/ismail9875/ReaderManager/main/installer.sh}"
NAME="ReaderManager"
PDIR="/usr/lib/enigma2/python/Plugins/Extensions/ReaderManager"

echo "==============================================="
echo " $NAME installer"
echo " source: github.com/ismail9875/ReaderManager"
echo "==============================================="

# ---- a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/readermanager.$$"
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

# ---- [1/3] download + check ----
echo ""
echo ">> [1/3] Downloading the official installer ..."
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
if ! grep -q 'ReaderManager' "$INST" 2>/dev/null; then
    echo "!! The downloaded file is not the ReaderManager installer."
    rm -rf "$WORK"
    exit 1
fi
tr -d '\r' < "$INST" > "$INST.lf" 2>/dev/null && mv -f "$INST.lf" "$INST"
echo "   installer ok: $(wc -c < "$INST") bytes"

if [ "${READERMANAGER_DRY_RUN:-0}" = "1" ]; then
    echo "   dry run: installer downloaded and validated; not executing."
    rm -rf "$WORK"
    exit 0
fi

# ---- [2/3] run the official installer ----
echo ""
echo ">> [2/3] Running the official installer ..."
echo ""
sh "$INST"
rc=$?

# ---- [3/3] verify ----
echo ""
echo ">> [3/3] Checking the installation ..."
if [ -d "$PDIR" ] && [ -f "$PDIR/plugin.py" ]; then
    echo "   ok: $PDIR"
else
    echo "   !! $NAME was not found in $PDIR"
    [ "$rc" = "0" ] && rc=1
fi

echo ""
echo "==============================================="
if [ "$rc" = "0" ]; then
    echo " DONE: $NAME installed."
    echo " Start it from the plugin list."
else
    echo " $NAME: the installer stopped with exit code $rc."
    echo " Run it again once the connection is stable."
fi
echo "==============================================="

rm -f "$INST"
rm -rf "$WORK"
exit "$rc"
