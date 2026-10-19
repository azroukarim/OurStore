#!/bin/sh
# ============================================
# OSCamicam Kitte888 - Safe Installer (No Enigma2 restart)
#
# Vendor command:
#   wget https://raw.githubusercontent.com/biko-73/OSCamicam_Kitte888/main/installer.sh -O - | /bin/sh
#
# Why this is different from the vendor installer:
#   The biko-73 installer ends with "init 4; sleep 4; init 3", i.e. it
#   restarts Enigma2 from inside the plugin process. When Enigma2 stops, the
#   process group (including that installer) can be killed before "init 3"
#   runs, so Enigma2 never comes back and the box looks frozen.
#   Like ncam.sh/oscam.sh in this store, this script only installs the
#   package and never restarts Enigma2.
#
# What it does:
#   1. picks the package for the image (ipk for opkg, deb for DreamOS)
#   2. downloads it into a writable folder (not a hardcoded /tmp)
#   3. checks that the file really is a package before touching opkg
#   4. installs it with --force-reinstall --force-overwrite
#   5. tells you what to do next (restart Enigma2, enable the cam)
# ============================================

NAME="OSCamicam Kitte888"
BASE="https://raw.githubusercontent.com/biko-73/OSCamicam_Kitte888/main"
MY_IPK="enigma2-plugin-softcams-oscamicamall_017-Update-Kitte888_all.ipk"
MY_DEB="enigma2-plugin-softcams-oscam_dream-update-D004-kitte888_11906-802.deb"

echo ""
echo "************************************************************"
echo "**        $NAME - Safe Install Mode"
echo "************************************************************"
echo ""

# ---- [1/5] a writable work folder (some images never mount /tmp) ----
WORK=""
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/oscamkit.$$"
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

echo ">> [1/5] Preparing ..."
if command -v dpkg >/dev/null 2>&1; then
    FILE="$WORK/$MY_DEB"
    URL="${OSCKIT_URL:-$BASE/$MY_DEB}"
    echo "   system: DreamOS (deb)"
else
    FILE="$WORK/$MY_IPK"
    URL="${OSCKIT_URL:-$BASE/$MY_IPK}"
    echo "   system: opkg (ipk)"
fi
echo "   package: $(basename "$FILE")"

# ---- [2/5] download the package ----
echo ""
echo ">> [2/5] Downloading the package ..."
rm -f "$FILE"
wget -q -T 120 --tries=2 --no-check-certificate "$URL" -O "$FILE"
if [ ! -s "$FILE" ]; then
    echo "   retrying without the certificate option ..."
    wget -q -T 120 --tries=2 "$URL" -O "$FILE"
fi
if [ ! -s "$FILE" ]; then
    echo "!! Download failed - check the internet connection."
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
echo "   downloaded: $(wc -c < "$FILE") bytes"

# ---- [3/5] check the package before opkg sees it ----
echo ""
echo ">> [3/5] Checking the package ..."
MAGIC=$(head -c 8 "$FILE" 2>/dev/null)
if [ "$MAGIC" != "!<arch>" ]; then
    echo "!! The downloaded file is not a valid ipk/deb package."
    echo "!! Nothing was installed."
    rm -rf "$WORK"
    exit 1
fi
echo "   package ok"

# ---- [4/5] install (Enigma2 is NOT restarted) ----
echo ""
echo ">> [4/5] Installing (Enigma2 will NOT be restarted) ..."
echo ""
if command -v dpkg >/dev/null 2>&1; then
    dpkg -i --force-overwrite "$FILE"
    rc=$?
    apt install -f -y >/dev/null 2>&1
else
    opkg install --force-reinstall --force-overwrite "$FILE"
    rc=$?
fi
rm -f "$FILE"

# ---- [5/5] result ----
echo ""
echo ">> [5/5] Result ..."
echo ""
echo "************************************************************"
if [ "$rc" = "0" ]; then
    echo "**              INSTALLATION COMPLETED!                   **"
    echo "**                                                        **"
    echo "**  $NAME is installed."
    echo "**  Enigma2 was NOT restarted (safe mode).                 **"
    echo "**                                                        **"
    echo "**  Restart Enigma2 yourself, then open the softcam menu   **"
    echo "**  and choose the OSCam/Icam entry to start the cam.      **"
else
    echo "**              INSTALLATION FAILED !                     **"
    echo "**                                                        **"
    echo "**  opkg reported errors - see the output above.           **"
    echo "**  Nothing else was changed.                             **"
fi
echo "************************************************************"
echo ""

rm -rf "$WORK" 2>/dev/null
exit "$rc"
