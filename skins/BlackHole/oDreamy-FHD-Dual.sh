#!/bin/sh
# ============================================================
# Word Of Enigma2 - SKINS/BlackHole - oDreamy FHD Dual (BlackHole)
#
# Original skin: oDreamy-FHD-Dual by buwalla (Tunisia-Sat)
# https://www.tunisia-sat.com/forums/threads/4449947/
#
# The package is a plain tar.gz that must be extracted into /:
#   usr/share/enigma2/oDreamy-FHD-Dual/...
#   usr/lib/enigma2/python/Components/Converter/bu*.py
#
# This installer:
#   1. downloads the BlackHole archive into a writable folder and
#      checks the tar before anything is extracted
#   2. makes sure the archive only touches the skin folder and the
#      twelve bu*.py converters
#   3. moves the old oDreamy-FHD-Dual folder aside and backs up any
#      existing bu*.py converter files
#   4. extracts the archive into /
#   5. checks the skin files afterwards
#   6. restores the old files when the extraction failed or is
#      incomplete
#   7. restarts Enigma2 once after a successful install; batch mode
#      leaves the single restart to the store
#
# The skin is not selected automatically.  After the restart choose
# "oDreamy-FHD-Dual" in Menu -> Setup -> System -> Skin.
# ============================================================

URL="${ODREAMY_URL:-https://raw.githubusercontent.com/azroukarim/OurStore/main/skins/BlackHole/oDreamy-FHD-Dual-BlackHole.tar.gz}"
NAME="oDreamy FHD Dual (BlackHole)"
EXPECTED="BlackHole"
SKIN_DIR="/usr/share/enigma2/oDreamy-FHD-Dual"
SKIN_OLD="$SKIN_DIR.woe-backup"
CONV_DIR="/usr/lib/enigma2/python/Components/Converter"
WORK=""
PKG=""
BU_BACKUP=""
BU_LIST=""
HAD_SKIN="0"
RESTORE_FAILED="0"

echo "==============================================="
echo " $NAME"
echo " source: Tunisia-Sat - buwalla"
echo "==============================================="

check_skin() {
    [ -s "$SKIN_DIR/skin.xml" ] || return 1
    [ -d "$SKIN_DIR/main" ] || return 1
    [ -s "$SKIN_DIR/modules/skin_parameters.xml" ] || return 1
    [ -s "$SKIN_DIR/modules/skin_templates.xml" ] || return 1
    [ -s "$SKIN_DIR/modules/skin_plugins.xml" ] || return 1
    [ -s "$SKIN_DIR/modules/skin_team.xml" ] || return 1
    [ -s "$CONV_DIR/buBase.py" ] || return 1
    true
    _size=$(wc -c < "$SKIN_DIR/skin.xml" 2>/dev/null | tr -d ' ')
    [ "${_size:-0}" -gt 50000 ] || return 1
    return 0
}

# ---- recover from an interrupted previous run ----
if [ -e "$SKIN_OLD" ]; then
    if [ -s "$SKIN_DIR/skin.xml" ]; then
        rm -rf "$SKIN_OLD" 2>/dev/null
    else
        rm -rf "$SKIN_DIR" 2>/dev/null
        if mv "$SKIN_OLD" "$SKIN_DIR" 2>/dev/null; then
            echo "   recovered the previous oDreamy-FHD-Dual folder"
        fi
    fi
fi

# ---- a writable work folder ----
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/odreamy.$$"
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
PKG="$WORK/skin.tar.gz"
BU_BACKUP="$WORK/bu-backup"
BU_LIST="$WORK/bu-list.txt"

# ---- [1/6] download + validate ----
echo ""
echo ">> [1/6] Downloading the BlackHole package (about 5 MB) ..."
rm -f "$PKG"
wget -q -T 240 --tries=3 --no-check-certificate "$URL" -O "$PKG"
if [ ! -s "$PKG" ]; then
    echo "   retrying without the certificate option ..."
    wget -q -T 240 --tries=3 "$URL" -O "$PKG"
fi
if [ ! -s "$PKG" ]; then
    echo "!! Download failed - check the internet connection."
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi

SIZE=$(wc -c < "$PKG" 2>/dev/null | tr -d ' ')
if [ "${SIZE:-0}" -lt 1000000 ]; then
    echo "!! The downloaded file is too small ($SIZE bytes) - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
if ! tar -tzf "$PKG" > "$WORK/files.raw" 2>/dev/null; then
    echo "!! The downloaded file is not a valid tar.gz archive - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
sed 's#^\./##; s#/$##' "$WORK/files.raw" > "$WORK/files.txt"
if ! grep -qx "usr/share/enigma2/oDreamy-FHD-Dual/skin.xml" "$WORK/files.txt"; then
    echo "!! The archive does not contain the oDreamy-FHD-Dual skin."
    rm -rf "$WORK"
    exit 1
fi
LIST_COUNT=$(wc -l < "$WORK/files.txt" 2>/dev/null | tr -d ' ')
if [ "${LIST_COUNT:-0}" -lt 500 ]; then
    echo "!! The archive looks incomplete ($LIST_COUNT entries) - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
BAD=$(grep -v -E '^(usr|usr/share|usr/share/enigma2|usr/share/enigma2/oDreamy-FHD-Dual(/.*)?|usr/lib|usr/lib/enigma2|usr/lib/enigma2/python|usr/lib/enigma2/python/Components|usr/lib/enigma2/python/Components/Converter|usr/lib/enigma2/python/Components/Converter/bu[A-Za-z0-9_]+\.py)$' "$WORK/files.txt" | head -n 1)
if [ -n "$BAD" ]; then
    echo "!! The archive contains an unexpected path:"
    echo "   $BAD"
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
echo "   archive ok: $SIZE bytes, $LIST_COUNT entries"

if [ "${ODREAMY_DRY_RUN:-0}" = "1" ]; then
    echo "   dry run: archive downloaded and validated; not installing."
    rm -rf "$WORK"
    exit 0
fi

# ---- [2/6] image hint ----
echo ""
echo ">> [2/6] Checking the image ..."
IMG=""
for _f in /etc/image-version /etc/issue; do
    if [ -f "$_f" ]; then
        IMG="$IMG $(cat "$_f" 2>/dev/null)"
    fi
done
if [ -n "$IMG" ]; then
    if echo "$IMG" | grep -qi "blackhole"; then
        echo "   image looks right for this package"
    else
        echo "   note: this package is prepared for $EXPECTED."
        echo "   The image reports a different name; the skin itself is the same,"
        echo "   only the logos/extra subtitle support differ. Continuing."
    fi
else
    echo "   could not detect the image name; continuing"
fi

# ---- [3/6] back up the old skin + bu*.py converters ----
echo ""
echo ">> [3/6] Backing up the old files ..."
mkdir -p "$BU_BACKUP" 2>/dev/null
: > "$BU_LIST"
for _f in "$CONV_DIR"/bu*.py; do
    [ -f "$_f" ] || continue
    _b=${_f##*/}
    if ! cp -p "$_f" "$BU_BACKUP/$_b" 2>/dev/null; then
        echo "!! Could not back up $_f - nothing was changed."
        rm -rf "$WORK"
        exit 1
    fi
    echo "$_b" >> "$BU_LIST"
done
if [ -s "$BU_LIST" ]; then
    echo "   old bu*.py converters saved"
else
    echo "   no old bu*.py converters"
fi

restore_all() {
    rm -f "$CONV_DIR"/bu*.py 2>/dev/null
    if [ -s "$BU_LIST" ]; then
        while IFS= read -r _b; do
            [ -n "$_b" ] || continue
            if ! cp -p "$BU_BACKUP/$_b" "$CONV_DIR/$_b" 2>/dev/null; then
                echo "   !! Could not restore $CONV_DIR/$_b"
                RESTORE_FAILED="1"
            fi
        done < "$BU_LIST"
    fi
    if [ "$HAD_SKIN" = "1" ]; then
        if [ -e "$SKIN_OLD" ]; then
            rm -rf "$SKIN_DIR" 2>/dev/null
            if ! mv "$SKIN_OLD" "$SKIN_DIR" 2>/dev/null; then
                echo "   !! Could not restore the previous skin folder."
                RESTORE_FAILED="1"
            fi
        fi
    else
        rm -rf "$SKIN_DIR" 2>/dev/null
    fi
}

if [ -d "$SKIN_DIR" ]; then
    rm -rf "$SKIN_OLD" 2>/dev/null
    if mv "$SKIN_DIR" "$SKIN_OLD" 2>/dev/null; then
        HAD_SKIN="1"
        echo "   old skin saved"
    else
        echo "!! Could not move the old skin aside - nothing was changed."
        rm -rf "$WORK"
        exit 1
    fi
else
    echo "   no old oDreamy-FHD-Dual skin"
fi

# ---- [4/6] extract ----
echo ""
echo ">> [4/6] Installing $NAME ..."
if ! tar -xzf "$PKG" -C /; then
    echo "   !! extraction failed"
    restore_all
    rm -rf "$WORK"
    echo ""
    echo " $NAME: installation failed."
    if [ "$RESTORE_FAILED" = "0" ]; then
        echo " The previous files were restored."
    else
        echo " !! Some previous files could not be restored."
    fi
    exit 1
fi

# ---- [5/6] verify ----
echo ""
echo ">> [5/6] Checking the installation ..."
if check_skin; then
    echo "   ok: $SKIN_DIR"
    rc=0
else
    echo "   !! the oDreamy-FHD-Dual files are missing or incomplete"
    restore_all
    rc=1
fi

# ---- [6/6] finish ----
if [ "$rc" = "0" ]; then
    rm -rf "$SKIN_OLD" "$BU_BACKUP" 2>/dev/null
    rm -f "$PKG" 2>/dev/null

    echo ""
    echo "==============================================="
    echo " $NAME: installed."
    echo " After the restart choose oDreamy-FHD-Dual in:"
    echo " Menu -> Setup -> System -> Skin"
    echo "==============================================="

    echo ""
    echo ">> [6/6] Checking Enigma2 ..."
    if [ "${ODREAMY_TEST_NO_RESTART:-0}" = "1" ]; then
        echo "   test mode: Enigma2 is not touched"
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
                rm -rf "$WORK" 2>/dev/null
                sync
                "$REBOOT_BIN"
            fi
        else
            echo "   restarting Enigma2 to load oDreamy-FHD-Dual ..."
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
                rm -rf "$WORK" 2>/dev/null
                sync
                "$REBOOT_BIN"
            fi
        fi
    fi

    rm -rf "$WORK" 2>/dev/null
    sync
    exit 0
else
    echo ""
    echo "==============================================="
    echo " $NAME: installation failed."
    if [ "$RESTORE_FAILED" = "0" ]; then
        echo " The previous files were restored."
    else
        echo " !! Some previous files could not be restored."
    fi
    echo "==============================================="
    rm -rf "$WORK" 2>/dev/null
    sync
    exit 1
fi
