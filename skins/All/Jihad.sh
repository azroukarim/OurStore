#!/bin/sh
# ============================================================
# Word Of Enigma2 - SKINS/ALL - Jihad Skin 2.22 (Ahmed Shawky)
#
# Original setup command:
#   https://raw.githubusercontent.com/ahmeds200917/A.Shawky/refs/heads/main/install_jihad.sh
#
# The official one-liner downloads jihad.ipk and installs it with:
#   opkg install --force-overwrite --force-reinstall --force-depends
# It does not back up anything, does not check the result and does not
# restart Enigma2.
#
# This wrapper adds:
#   1. the IPK is downloaded into a writable folder first and checked
#      (ar signature and real size) before opkg sees it
#   2. /tmp is repaired when it is missing or not writable
#   3. the old Jihad skin/plugin and the old GeminiPatcher are moved
#      aside; the shared Converter/Renderer folders are backed up
#   4. the package is installed with the same force options as upstream
#   5. the skin files are checked afterwards
#   6. on failure the incomplete package is removed and the previous
#      files are restored
#   7. Enigma2 is restarted once after a successful install; batch mode
#      leaves the single restart to the store
#
# The IPK also carries a few packaging leftovers (./control, ./postinst,
# ./prerm, ./postrm, ./preinst) at the archive root.  They are removed
# after the install; pre-existing files with those names are restored.
# ============================================================

URL="${JIHAD_URL:-https://raw.githubusercontent.com/ahmeds200917/A.Shawky/refs/heads/main/jihad.ipk}"
NAME="Jihad Skin 2.22"
SKIN_DIR="/usr/share/enigma2/Jihad"
SKIN_OLD="$SKIN_DIR.woe-backup"
PLUGIN_DIR="/usr/lib/enigma2/python/Plugins/Extensions/Jihad"
PLUGIN_OLD="$PLUGIN_DIR.woe-backup"
GEMINI_DIR="/usr/lib/enigma2/python/Plugins/Extensions/GeminiPatcher"
GEMINI_OLD="$GEMINI_DIR.woe-backup"
COMP_DIR="/usr/lib/enigma2/python/Components"

HAD_SKIN="0"
HAD_PLUGIN="0"
HAD_GEMINI="0"
HAD_CONVERTER="0"
HAD_RENDERER="0"
RESTORE_FAILED="0"
BACKUP_TAR=""
ROOT_LIST=""
WORK=""
IPK=""

echo "==============================================="
echo " $NAME"
echo " source: github.com/ahmeds200917/A.Shawky"
echo "==============================================="

check_jihad() {
    [ -s "$SKIN_DIR/skin.xml" ] || return 1
    [ -d "$SKIN_DIR/main" ] || return 1
    [ -s "$PLUGIN_DIR/plugin.py" ] || return 1
    [ -s "$PLUGIN_DIR/__init__.py" ] || return 1
    [ -d "$PLUGIN_DIR/screens" ] || return 1
    _size=$(wc -c < "$SKIN_DIR/skin.xml" 2>/dev/null | tr -d ' ')
    [ "${_size:-0}" -gt 100000 ] || return 1
    return 0
}

recover_one() {
    _cur="$1"
    _old="$2"
    _marker="$3"
    if [ -e "$_old" ]; then
        if [ -s "$_cur/$_marker" ]; then
            # the current installation is complete; the old copy is stale
            rm -rf "$_old" 2>/dev/null
        else
            rm -rf "$_cur" 2>/dev/null
            if mv "$_old" "$_cur" 2>/dev/null; then
                echo "   recovered the previous $_cur"
            fi
        fi
    fi
}

recover_one "$SKIN_DIR" "$SKIN_OLD" "skin.xml"
recover_one "$PLUGIN_DIR" "$PLUGIN_OLD" "plugin.py"
recover_one "$GEMINI_DIR" "$GEMINI_OLD" "plugin.py"

# ---- a writable work folder (some images never mount /tmp) ----
for _base in "${TMPDIR:-}" /tmp /var/volatile/tmp /run /dev/shm "${HOME:-}" /home/root; do
    [ -n "$_base" ] || continue
    _dir="$_base/jihad.$$"
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
IPK="$WORK/jihad.ipk"
BACKUP_TAR="$WORK/components-backup.tar.gz"
ROOT_LIST="$WORK/root-existing.txt"

# ---- [1/8] download the IPK + validate it ----
echo ""
echo ">> [1/8] Downloading the Jihad package (about 23 MB) ..."
rm -f "$IPK"
wget -q -T 300 --tries=3 --no-check-certificate "$URL" -O "$IPK"
if [ ! -s "$IPK" ]; then
    echo "   retrying without the certificate option ..."
    wget -q -T 300 --tries=3 "$URL" -O "$IPK"
fi
if [ ! -s "$IPK" ]; then
    echo "!! Download failed - check the internet connection."
    echo "!! Nothing was changed."
    rm -rf "$WORK"
    exit 1
fi

SIZE=$(wc -c < "$IPK" 2>/dev/null | tr -d ' ')
if [ "${SIZE:-0}" -lt 10000000 ]; then
    echo "!! The downloaded file is too small ($SIZE bytes) - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
MAGIC=$(head -c 8 "$IPK" 2>/dev/null)
if [ "$MAGIC" != "!<arch>" ]; then
    echo "!! The downloaded file is not an IPK archive - nothing was changed."
    rm -rf "$WORK"
    exit 1
fi
echo "   package ok: $SIZE bytes"

if [ "${JIHAD_DRY_RUN:-0}" = "1" ]; then
    echo "   dry run: package downloaded and validated; not installing."
    rm -rf "$WORK"
    exit 0
fi

# ---- [2/8] basic checks ----
echo ""
echo ">> [2/8] Checking the installer ..."
OPKG_BIN=$(command -v opkg 2>/dev/null)
if [ -z "$OPKG_BIN" ]; then
    echo "!! opkg was not found on this image - the IPK cannot be installed."
    rm -rf "$WORK"
    exit 1
fi

tmp_works() {
    ( : > /tmp/.woe_tmp_test ) 2>/dev/null || return 1
    rm -f /tmp/.woe_tmp_test 2>/dev/null
    return 0
}
if ! tmp_works; then
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
        echo "   !! /tmp still not writable - opkg may fail"
    fi
fi

DEP_MISSING="0"
for _dep in enigma2-plugin-extensions-bitrate python3-pillow; do
    if ! opkg list-installed 2>/dev/null | grep -q "^$_dep "; then
        echo "   note: $_dep is not installed (the skin may miss that feature)"
        DEP_MISSING="1"
    fi
done

# ---- [3/8] back up the shared component folders ----
echo ""
echo ">> [3/8] Backing up the shared Converter/Renderer folders ..."
if [ -d "$COMP_DIR/Converter" ]; then
    HAD_CONVERTER="1"
fi
if [ -d "$COMP_DIR/Renderer" ]; then
    HAD_RENDERER="1"
fi
make_components_backup() {
    set --
    [ "$HAD_CONVERTER" = "1" ] && set -- "$@" "usr/lib/enigma2/python/Components/Converter"
    [ "$HAD_RENDERER" = "1" ] && set -- "$@" "usr/lib/enigma2/python/Components/Renderer"
    [ "$#" -gt 0 ] || return 0
    ( cd / && tar -czf "$BACKUP_TAR" "$@" )
}
if [ "$HAD_CONVERTER" = "1" ] || [ "$HAD_RENDERER" = "1" ]; then
    if ! make_components_backup; then
        echo "!! Could not back up the shared component folders."
        echo "!! Nothing was changed."
        rm -f "$BACKUP_TAR"
        rm -rf "$WORK"
        exit 1
    fi
    echo "   shared files saved"
else
    echo "   no existing Converter/Renderer folders"
fi

# ---- [4/8] back up pre-existing root-level packaging leftovers ----
: > "$ROOT_LIST"
for _f in control postinst prerm postrm preinst; do
    if [ -e "/$_f" ]; then
        if ! cp -a "/$_f" "$WORK/root-$_f" 2>/dev/null; then
            if ! cp -pR "/$_f" "$WORK/root-$_f" 2>/dev/null; then
                echo "!! Could not back up /$_f - nothing was changed."
                rm -f "$BACKUP_TAR"
                rm -rf "$WORK"
                exit 1
            fi
        fi
        echo "$_f" >> "$ROOT_LIST"
    fi
done

fix_root_scripts() {
    [ -f "$ROOT_LIST" ] || return 0
    for _f in control postinst prerm postrm preinst; do
        if grep -qx "$_f" "$ROOT_LIST" 2>/dev/null; then
            if [ -e "$WORK/root-$_f" ]; then
                rm -rf "/$_f" 2>/dev/null
                cp -pR "$WORK/root-$_f" "/$_f" 2>/dev/null
            fi
        else
            rm -rf "/$_f" 2>/dev/null
        fi
    done
}

# ---- [5/8] move the old Jihad files aside ----
echo ""
echo ">> [5/8] Moving the old Jihad files aside ..."
if [ -d "$SKIN_DIR" ]; then
    rm -rf "$SKIN_OLD" 2>/dev/null
    if mv "$SKIN_DIR" "$SKIN_OLD" 2>/dev/null; then
        HAD_SKIN="1"
        echo "   old skin saved"
    else
        echo "!! Could not move the old skin aside - nothing was changed."
        fix_root_scripts
        rm -f "$BACKUP_TAR"
        rm -rf "$WORK"
        exit 1
    fi
else
    echo "   no old Jihad skin"
fi
if [ -d "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_OLD" 2>/dev/null
    if mv "$PLUGIN_DIR" "$PLUGIN_OLD" 2>/dev/null; then
        HAD_PLUGIN="1"
        echo "   old Jihad plugin saved"
    else
        echo "!! Could not move the old Jihad plugin aside - restoring."
        if [ "$HAD_SKIN" = "1" ] && [ -e "$SKIN_OLD" ]; then
            rm -rf "$SKIN_DIR" 2>/dev/null
            mv "$SKIN_OLD" "$SKIN_DIR" 2>/dev/null
        fi
        fix_root_scripts
        rm -f "$BACKUP_TAR"
        rm -rf "$WORK"
        exit 1
    fi
else
    echo "   no old Jihad plugin"
fi
if [ -d "$GEMINI_DIR" ]; then
    rm -rf "$GEMINI_OLD" 2>/dev/null
    if mv "$GEMINI_DIR" "$GEMINI_OLD" 2>/dev/null; then
        HAD_GEMINI="1"
        echo "   old GeminiPatcher saved"
    else
        echo "!! Could not move the old GeminiPatcher aside - restoring."
        if [ "$HAD_PLUGIN" = "1" ] && [ -e "$PLUGIN_OLD" ]; then
            rm -rf "$PLUGIN_DIR" 2>/dev/null
            mv "$PLUGIN_OLD" "$PLUGIN_DIR" 2>/dev/null
        fi
        if [ "$HAD_SKIN" = "1" ] && [ -e "$SKIN_OLD" ]; then
            rm -rf "$SKIN_DIR" 2>/dev/null
            mv "$SKIN_OLD" "$SKIN_DIR" 2>/dev/null
        fi
        fix_root_scripts
        rm -f "$BACKUP_TAR"
        rm -rf "$WORK"
        exit 1
    fi
else
    echo "   no old GeminiPatcher"
fi

restore_components() {
    rm -rf "$COMP_DIR/Converter" "$COMP_DIR/Renderer" 2>/dev/null
    if [ -n "$BACKUP_TAR" ] && [ -f "$BACKUP_TAR" ]; then
        if ! ( cd / && tar -xzf "$BACKUP_TAR" ); then
            echo "   !! Could not restore the shared Converter/Renderer files."
            RESTORE_FAILED="1"
        fi
    fi
}

restore_all() {
    echo "   restoring the previous files ..."
    restore_components

    if [ "$HAD_SKIN" = "1" ]; then
        if [ -e "$SKIN_OLD" ]; then
            rm -rf "$SKIN_DIR" 2>/dev/null
            if ! mv "$SKIN_OLD" "$SKIN_DIR" 2>/dev/null; then
                echo "   !! Could not restore the previous Jihad skin folder."
                RESTORE_FAILED="1"
            fi
        fi
    else
        rm -rf "$SKIN_DIR" 2>/dev/null
    fi
    if [ "$HAD_PLUGIN" = "1" ]; then
        if [ -e "$PLUGIN_OLD" ]; then
            rm -rf "$PLUGIN_DIR" 2>/dev/null
            if ! mv "$PLUGIN_OLD" "$PLUGIN_DIR" 2>/dev/null; then
                echo "   !! Could not restore the previous Jihad plugin folder."
                RESTORE_FAILED="1"
            fi
        fi
    else
        rm -rf "$PLUGIN_DIR" 2>/dev/null
    fi
    if [ "$HAD_GEMINI" = "1" ]; then
        if [ -e "$GEMINI_OLD" ]; then
            rm -rf "$GEMINI_DIR" 2>/dev/null
            if ! mv "$GEMINI_OLD" "$GEMINI_DIR" 2>/dev/null; then
                echo "   !! Could not restore the previous GeminiPatcher folder."
                RESTORE_FAILED="1"
            fi
        fi
    else
        rm -rf "$GEMINI_DIR" 2>/dev/null
    fi
    fix_root_scripts
}

# ---- [6/8] install ----
echo ""
echo ">> [6/8] Installing $NAME ..."
echo ""
opkg install --force-overwrite --force-reinstall --force-depends "$IPK"
rc=$?

# ---- [7/8] verify ----
echo ""
echo ">> [7/8] Checking the installation ..."
if check_jihad; then
    if [ "$rc" != "0" ]; then
        echo "   note: opkg returned $rc, but the skin files are complete."
    fi
    echo "   ok: $SKIN_DIR"
    rc=0
else
    echo "   !! the Jihad skin files are missing or incomplete"
    if opkg list-installed 2>/dev/null | grep -q "^enigma2-plugin-skins-jihad "; then
        echo "   removing the incomplete package ..."
        opkg remove enigma2-plugin-skins-jihad >/dev/null 2>&1
    fi
    restore_all
    rc=1
fi

# ---- [8/8] finish ----
if [ "$rc" = "0" ]; then
    # the new files are complete; the old copies are no longer needed
    rm -rf "$SKIN_OLD" "$PLUGIN_OLD" "$GEMINI_OLD" 2>/dev/null
    rm -f "$BACKUP_TAR" 2>/dev/null
    fix_root_scripts
    rm -f "$IPK" 2>/dev/null

    echo ""
    echo "==============================================="
    echo " $NAME: installed."
    echo " After the restart choose Jihad in:"
    echo " Menu -> Setup -> System -> Skin"
    if [ "$DEP_MISSING" = "1" ]; then
        echo " Note: bitrate/pillow were missing; install them if icons"
        echo " or the bitrate display do not work."
    fi
    echo "==============================================="

    echo ""
    echo ">> [8/8] Checking Enigma2 ..."
    if [ "${JIHAD_TEST_NO_RESTART:-0}" = "1" ]; then
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
            echo "   restarting Enigma2 to load Jihad ..."
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
    if [ "$HAD_SKIN" = "1" ]; then
        if [ -s "$SKIN_DIR/skin.xml" ]; then
            echo " The previous Jihad skin was restored."
        else
            echo " !! The previous Jihad skin could not be fully restored."
        fi
    else
        echo " No previous Jihad skin was present."
    fi
    echo " The downloaded package was removed."
    echo "==============================================="
    rm -rf "$WORK" 2>/dev/null
    sync
    exit 1
fi
