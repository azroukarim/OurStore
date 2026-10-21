#!/bin/sh
# ============================================================
# Word Of Enigma2 - SKINS / ALL - TeamNitro DesertFHD 3.1
#
# Original setup command:
#   wget https://raw.githubusercontent.com/biko-73/TeamNitro/main/script/installerDs.sh -O - | /bin/sh
#
# What the official installer does:
#   - deletes the old TeamNitro plugin and DesertFHD skin BEFORE it
#     downloads anything
#   - downloads two tarballs into /var/volatile/tmp
#   - extracts them to / and restarts Enigma2
#   - its two-file check is broken: "if [ -f file1 ]; [ -f file2 ]"
#     only tests the first file, so a half download is extracted anyway
#
# This wrapper does the same installation safely:
#   1. downloads both official tarballs into a writable folder and
#      checks their size and gzip/tar structure BEFORE touching anything
#   2. moves the old plugin and skin folders aside (same filesystem, no
#      extra 40 MB copy), and backs up the shared renderer/converter
#      files and Tools/Directories2.py that the skin overwrites
#   3. extracts both tarballs, then checks the plugin, the skin, the
#      version file and the shared files
#   4. on any failure the old plugin/skin and the old shared files are
#      restored and the partial files are removed
#   5. Enigma2 is restarted once after a successful install; batch mode
#      leaves the single restart to the store
#
# The skin is installed but NOT selected automatically.  After the
# restart choose DesertFHD in Menu > Setup > System > Skin, or open
# TeamNitro from the plugin list.
# ============================================================

TN_URL="${TEAMNITRO_PLUGIN_URL:-https://github.com/biko-73/TeamNitro/raw/main/skins/TeamNitro.tar.gz}"
SKIN_URL="${TEAMNITRO_SKIN_URL:-https://github.com/biko-73/TeamNitro/raw/main/skins/DesertFHD_v-3.1.tar.gz}"
NAME="TeamNitro DesertFHD 3.1"
PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/TeamNitro"
PLUGIN_OLD="$PLUGIN_DIR.woe-backup"
SKIN_DIR="/usr/share/enigma2/DesertFHD"
SKIN_OLD="$SKIN_DIR.woe-backup"
VERSION_FILE="/usr/share/enigma2/TN_Skins_version"
VERSION_OLD="$VERSION_FILE.woe-backup"

# files from the skin archive that go into shared Enigma2 folders
SHARED_FILES="
usr/lib/enigma2/python/Tools/Directories2.py
usr/lib/enigma2/python/Components/Renderer/TNRUN.py
usr/lib/enigma2/python/Components/Renderer/TNGenrePic.py
usr/lib/enigma2/python/Components/Renderer/TNPosterbgBN.py
usr/lib/enigma2/python/Components/Renderer/TNWatches.py
usr/lib/enigma2/python/Components/Renderer/TNEmptyEpg.py
usr/lib/enigma2/python/Components/Renderer/TNPosterbgD.py
usr/lib/enigma2/python/Components/Renderer/TNPosterbgP.py
usr/lib/enigma2/python/Components/Renderer/TNPicEmuF.py
usr/lib/enigma2/python/Components/Renderer/TNPosterX.py
usr/lib/enigma2/python/Components/Renderer/TNPosterbgDN.py
usr/lib/enigma2/python/Components/Renderer/TNPiconUni.py
usr/lib/enigma2/python/Components/Renderer/TNNxtEvnt.py
usr/lib/enigma2/python/Components/Renderer/TNPosterXDownloadThread.py
usr/lib/enigma2/python/Components/Renderer/TNPosterbgG.py
usr/lib/enigma2/python/Components/Renderer/TNVolumeText.py
usr/lib/enigma2/python/Components/Converter/TNTemp.py
usr/lib/enigma2/python/Components/Converter/TNCaidInfo2.py
usr/lib/enigma2/python/Components/Converter/TNTitle.py
usr/lib/enigma2/python/Components/Converter/TNServName2.py
usr/lib/enigma2/python/Components/Converter/TNRouteInfo.py
usr/lib/enigma2/python/Components/Converter/TNAnalogClock.py
usr/lib/enigma2/python/Components/Converter/TNxtraInfo.py
usr/lib/enigma2/python/Components/Converter/TN_MSNWeather.py
usr/lib/enigma2/python/Components/Converter/TNEXTRA.py
"

echo "==============================================="
echo " $NAME"
echo " source: github.com/biko-73/TeamNitro"
echo "==============================================="

# ---- recover from an interrupted previous run ----
recover_old() {
    if [ -e "$PLUGIN_OLD" ]; then
        rm -rf "$PLUGIN_DIR" 2>/dev/null
        if mv "$PLUGIN_OLD" "$PLUGIN_DIR" 2>/dev/null; then
            echo "   recovered the previous TeamNitro plugin"
        fi
    fi
    if [ -e "$SKIN_OLD" ]; then
        rm -rf "$SKIN_DIR" 2>/dev/null
        if mv "$SKIN_OLD" "$SKIN_DIR" 2>/dev/null; then
            echo "   recovered the previous DesertFHD skin"
        fi
    fi
    if [ -e "$VERSION_OLD" ]; then
        rm -f "$VERSION_FILE" 2>/dev/null
        if mv "$VERSION_OLD" "$VERSION_FILE" 2>/dev/null; then
            echo "   recovered the previous skin version file"
        fi
    fi
}
recover_old

# ---- a writable work folder (26 MB is downloaded here) ----
WORK=""
for _base in /var/volatile/tmp "${TMPDIR:-}" /tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/teamnitro.$$"
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
TN_ARCHIVE="$WORK/TeamNitro.tar.gz"
SKIN_ARCHIVE="$WORK/DesertFHD.tar.gz"
SHARED_BACKUP="$WORK/shared"
SHARED_LIST="$WORK/shared.list"

# ---- [1/6] download and validate both official tarballs ----
echo ""
echo ">> [1/6] Downloading the official TeamNitro packages ..."
rm -f "$TN_ARCHIVE" "$SKIN_ARCHIVE"
echo "   plugin archive (about 4.9 MB) ..."
wget -q -T 300 --tries=2 --no-check-certificate "$TN_URL" -O "$TN_ARCHIVE"
if [ ! -s "$TN_ARCHIVE" ]; then
    echo "   retrying without the certificate option ..."
    wget -q -T 300 --tries=2 "$TN_URL" -O "$TN_ARCHIVE"
fi
echo "   skin archive (about 21.7 MB) ..."
wget -q -T 300 --tries=2 --no-check-certificate "$SKIN_URL" -O "$SKIN_ARCHIVE"
if [ ! -s "$SKIN_ARCHIVE" ]; then
    echo "   retrying without the certificate option ..."
    wget -q -T 300 --tries=2 "$SKIN_URL" -O "$SKIN_ARCHIVE"
fi

TN_SIZE=$(wc -c < "$TN_ARCHIVE" 2>/dev/null | tr -d ' ')
SKIN_SIZE=$(wc -c < "$SKIN_ARCHIVE" 2>/dev/null | tr -d ' ')
if [ -z "$TN_SIZE" ] || [ "$TN_SIZE" -lt 1000000 ]; then
    echo "!! The plugin archive is missing or too small - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
if [ -z "$SKIN_SIZE" ] || [ "$SKIN_SIZE" -lt 10000000 ]; then
    echo "!! The skin archive is missing or too small - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
if ! tar -tzf "$TN_ARCHIVE" >/dev/null 2>&1; then
    echo "!! The plugin archive is damaged - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
if ! tar -tzf "$SKIN_ARCHIVE" >/dev/null 2>&1; then
    echo "!! The skin archive is damaged - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
echo "   archives ok: $(($TN_SIZE / 1024)) KB + $(($SKIN_SIZE / 1024)) KB"

if [ "${TEAMNITRO_DRY_RUN:-0}" = "1" ]; then
    echo "   dry run: both archives downloaded and validated; not installing."
    rm -rf "$WORK"
    exit 0
fi

# ---- [2/6] back up the shared files that the skin overwrites ----
echo ""
echo ">> [2/6] Backing up shared skin files ..."
rm -rf "$SHARED_BACKUP"
mkdir -p "$SHARED_BACKUP" 2>/dev/null
: > "$SHARED_LIST"
for _f in $SHARED_FILES; do
    if [ -f "/$_f" ]; then
        _d=${_f%/*}
        mkdir -p "$SHARED_BACKUP/$_d" 2>/dev/null
        if ! cp -p "/$_f" "$SHARED_BACKUP/$_f" 2>/dev/null; then
            echo "!! Could not back up /$_f - nothing was changed."
            rm -rf "$WORK"
            exit 1
        fi
        echo "$_f" >> "$SHARED_LIST"
    fi
done
echo "   shared files saved: $(wc -l < "$SHARED_LIST" | tr -d ' ')"

# ---- [3/6] move the old plugin and skin aside ----
echo ""
echo ">> [3/6] Moving the old installation aside ..."
HAD_PLUGIN="0"
HAD_SKIN="0"
HAD_VERSION="0"

undo_moves() {
    if [ "$HAD_PLUGIN" = "1" ] && [ -e "$PLUGIN_OLD" ]; then
        rm -rf "$PLUGIN_DIR" 2>/dev/null
        mv "$PLUGIN_OLD" "$PLUGIN_DIR" 2>/dev/null
    fi
    if [ "$HAD_SKIN" = "1" ] && [ -e "$SKIN_OLD" ]; then
        rm -rf "$SKIN_DIR" 2>/dev/null
        mv "$SKIN_OLD" "$SKIN_DIR" 2>/dev/null
    fi
    if [ "$HAD_VERSION" = "1" ] && [ -e "$VERSION_OLD" ]; then
        rm -f "$VERSION_FILE" 2>/dev/null
        mv "$VERSION_OLD" "$VERSION_FILE" 2>/dev/null
    fi
}

if [ -d "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_OLD" 2>/dev/null
    if mv "$PLUGIN_DIR" "$PLUGIN_OLD" 2>/dev/null; then
        HAD_PLUGIN="1"
    else
        echo "!! Could not move the old TeamNitro plugin aside."
        undo_moves
        rm -rf "$WORK"
        exit 1
    fi
fi
if [ -d "$SKIN_DIR" ]; then
    rm -rf "$SKIN_OLD" 2>/dev/null
    if mv "$SKIN_DIR" "$SKIN_OLD" 2>/dev/null; then
        HAD_SKIN="1"
    else
        echo "!! Could not move the old DesertFHD skin aside."
        undo_moves
        rm -rf "$WORK"
        exit 1
    fi
fi
if [ -e "$VERSION_FILE" ]; then
    rm -f "$VERSION_OLD" 2>/dev/null
    if mv "$VERSION_FILE" "$VERSION_OLD" 2>/dev/null; then
        HAD_VERSION="1"
    else
        echo "!! Could not move the old skin version file aside."
        undo_moves
        rm -rf "$WORK"
        exit 1
    fi
fi
if [ "$HAD_PLUGIN" = "0" ] && [ "$HAD_SKIN" = "0" ]; then
    echo "   no old TeamNitro/DesertFHD installation"
else
    echo "   old plugin/skin moved aside"
fi

# ---- [4/6] extract both archives ----
echo ""
echo ">> [4/6] Extracting the plugin and skin ..."
EXTRACT_OK="1"
tar -xzf "$TN_ARCHIVE" -C / 2>/dev/null || EXTRACT_OK="0"
if [ "$EXTRACT_OK" = "1" ]; then
    tar -xzf "$SKIN_ARCHIVE" -C / 2>/dev/null || EXTRACT_OK="0"
fi
sync

# ---- [5/6] verify, or restore the old installation ----
echo ""
echo ">> [5/6] Checking the installation ..."
check_install() {
    [ -s "$PLUGIN_DIR/__init__.py" ] || return 1
    [ -s "$PLUGIN_DIR/plugin.py" ] || return 1
    [ -s "$PLUGIN_DIR/plugin.png" ] || return 1
    [ -s "$SKIN_DIR/skin.xml" ] || return 1
    [ -s "$VERSION_FILE" ] || return 1
    [ -s /usr/lib/enigma2/python/Tools/Directories2.py ] || return 1
    [ -s /usr/lib/enigma2/python/Components/Renderer/TNRUN.py ] || return 1
    [ -s /usr/lib/enigma2/python/Components/Converter/TNTemp.py ] || return 1
    return 0
}

was_backed_up() {
    while read _line; do
        [ "$_line" = "$1" ] && return 0
    done < "$SHARED_LIST"
    return 1
}

restore_all() {
    echo "   restoring the previous installation ..."
    if [ "$HAD_PLUGIN" = "1" ] && [ -e "$PLUGIN_OLD" ]; then
        rm -rf "$PLUGIN_DIR" 2>/dev/null
        mv "$PLUGIN_OLD" "$PLUGIN_DIR" 2>/dev/null
    else
        rm -rf "$PLUGIN_DIR" 2>/dev/null
    fi
    if [ "$HAD_SKIN" = "1" ] && [ -e "$SKIN_OLD" ]; then
        rm -rf "$SKIN_DIR" 2>/dev/null
        mv "$SKIN_OLD" "$SKIN_DIR" 2>/dev/null
    else
        rm -rf "$SKIN_DIR" 2>/dev/null
    fi
    if [ "$HAD_VERSION" = "1" ] && [ -e "$VERSION_OLD" ]; then
        rm -f "$VERSION_FILE" 2>/dev/null
        mv "$VERSION_OLD" "$VERSION_FILE" 2>/dev/null
    else
        rm -f "$VERSION_FILE" 2>/dev/null
    fi

    while read _f; do
        [ -n "$_f" ] || continue
        _d=${_f%/*}
        mkdir -p "/$_d" 2>/dev/null
        cp -p "$SHARED_BACKUP/$_f" "/$_f" 2>/dev/null
    done < "$SHARED_LIST"
    for _f in $SHARED_FILES; do
        if ! was_backed_up "$_f"; then
            rm -f "/$_f" 2>/dev/null
        fi
    done
    sync
}

RC="0"
if [ "$EXTRACT_OK" = "1" ] && check_install; then
    echo "   ok: plugin and skin files are in place"
    RC="0"
else
    echo "   !! the extraction is incomplete"
    restore_all
    RC="1"
fi

# the new files are verified, the old copies are no longer needed;
# remove them before the restart so a reboot cannot restore them later
if [ "$RC" = "0" ]; then
    rm -rf "$PLUGIN_OLD" "$SKIN_OLD" 2>/dev/null
    rm -f "$VERSION_OLD" 2>/dev/null
fi

# ---- [6/6] Enigma2 and cleanup ----
echo ""
echo ">> [6/6] Checking Enigma2 ..."
if [ "${TEAMNITRO_TEST_NO_RESTART:-0}" = "1" ]; then
    echo "   test mode: Enigma2 is not touched"
elif [ "$RC" != "0" ]; then
    echo "   the installation was restored - no restart needed"
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
        echo "   restarting Enigma2 to load the new plugin ..."
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

echo ""
echo "==============================================="
if [ "$RC" = "0" ]; then
    echo " $NAME: installed."
    echo " Choose DesertFHD in Menu > Setup > System > Skin,"
    echo " or open TeamNitro from the plugin list."
else
    echo " $NAME: installation failed."
    echo " The previous plugin/skin was restored."
fi
echo "==============================================="

rm -rf "$WORK"
sync
exit "$RC"
