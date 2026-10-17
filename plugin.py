# -*- coding: utf-8 -*-
# =========================================================================
# WordOfEnigma2 - Universal Enigma2 Plugin
# Compatible with: OpenATV, OpenPLi, Egami, BlackHole, OBH, VTi, DreamOS
# Python 2.7 & Python 3.x
# =========================================================================
from Plugins.Plugin import PluginDescriptor
from Screens.Screen import Screen
from Screens.MessageBox import MessageBox
from Components.MenuList import MenuList
from Components.Label import Label
from Components.ActionMap import ActionMap
from Components.Console import Console
from Components.Pixmap import Pixmap
import json
import os
import sys
import time
import threading

try:
    from Screens.Standby import TryQuitMainloop
except ImportError:
    TryQuitMainloop = None

try:
    from enigma import eTimer
except ImportError:
    eTimer = None

try:
    from enigma import ePicLoad
except ImportError:
    ePicLoad = None


# =====================================================================
# CONFIG
# =====================================================================
PLUGIN_VERSION = "1.0.26"
PLUGIN_AUTHOR = "Karim Azrou"
QR_FALLBACK_B64 = (
    "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"
    "VAMAlraF1sbeTFsAAAAASUVORK5CYII="
)

GITHUB_BASE = "https://raw.githubusercontent.com/azroukarim/OurStore/main"
STORE_URL = GITHUB_BASE + "/feed/index.json"
UPDATE_SCRIPT_URL = GITHUB_BASE + "/install.sh"

PLUGIN_DIR = "/usr/lib/enigma2/python/Plugins/Extensions/WordOfEnigma2"
try:
    if not os.path.isdir(PLUGIN_DIR):
        PLUGIN_DIR = os.path.dirname(__file__)
except Exception:
    pass

CACHE_FILE = os.path.join(PLUGIN_DIR, "store_cache.json")


# =====================================================================
# HELPERS
# =====================================================================
def load_json_network(url):
    """Load JSON from network (compatible with Python 2.7 and Python 3.x)"""
    try:
        req = None
        if sys.version_info >= (3, 0):
            import urllib.request as urllib2
            import ssl
            try:
                context = ssl._create_unverified_context()
            except AttributeError:
                context = None
            req = urllib2.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            if context is not None:
                response = urllib2.urlopen(req, timeout=10, context=context)
            else:
                response = urllib2.urlopen(req, timeout=10)
        else:
            import urllib2
            import ssl
            try:
                context = ssl._create_unverified_context()
            except AttributeError:
                context = None
            req = urllib2.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            response = None
            if context is not None:
                # Python 2 urllib2.urlopen() has no "context" argument,
                # so build an opener that carries the custom SSL context.
                try:
                    handler = urllib2.HTTPSHandler(context=context)
                    opener = urllib2.build_opener(handler)
                    response = opener.open(req, timeout=10)
                except TypeError:
                    response = None
            if response is None:
                response = urllib2.urlopen(req, timeout=10)
        data = response.read()
        if isinstance(data, bytes):
            data = data.decode('utf-8')
        return json.loads(data)
    except Exception:
        return None


def gui_call(func, *args, **kwargs):
    """Run a GUI operation on the main (reactor) thread.

    Enigma2's GUI is not thread-safe: session.open()/widget updates must happen
    on the main thread. Worker threads use this helper to marshal back safely.
    """
    try:
        from twisted.internet import reactor
        reactor.callFromThread(func, *args, **kwargs)
    except Exception:
        try:
            func(*args, **kwargs)
        except Exception:
            pass


def count_items(items):
    """Count items recursively"""
    if not isinstance(items, list):
        return 0
    total = 0
    for it in items:
        if isinstance(it, dict) and "items" in it and isinstance(it["items"], list):
            total += count_items(it["items"])
        else:
            total += 1
    return total


def batch_install_body(url, dest):
    """Return the shell command that installs the file already saved at dest."""
    pure = url.split("?")[0]
    leaf = pure.split("/")[-1]
    if leaf.endswith(".tar.gz"):
        ext = ".tar.gz"
    elif "." in leaf:
        ext = "." + leaf.split(".")[-1].lower()
    else:
        ext = ""
    if ext == ".ipk":
        return "opkg install --force-overwrite %s" % dest
    if ext == ".deb":
        return "dpkg -i %s" % dest
    if ext == ".sh":
        return "chmod +x %s && sh %s" % (dest, dest)
    if ext == ".zip":
        return "unzip -o %s -d /" % dest
    if ext in (".tar.gz", ".tgz"):
        return "tar -xzf %s -C /" % dest
    return "opkg install --force-overwrite %s" % dest


# Shell preamble that neutralises every Enigma2 restart attempt while a batch
# install is running. It drops small stub commands (init, reboot, shutdown,
# killall, systemctl, service...) into a temp dir and puts that dir first in
# PATH, so an installer that calls "init 4; init 3" (or "killall enigma2")
# becomes a harmless no-op. The user is asked to restart ONCE at the very end.
BATCH_RESTART_BLOCKER = r'''
# --- WordOfEnigma2: block per-item Enigma2 restarts until the batch is done ---
BLOCKDIR="/tmp/wordofenigma2_block"
rm -rf "$BLOCKDIR"; mkdir -p "$BLOCKDIR"
RKILLALL=$(command -v killall 2>/dev/null)
[ -z "$RKILLALL" ] && RKILLALL="busybox killall"
RSYSTEMCTL=$(command -v systemctl 2>/dev/null)
RSERVICE=$(command -v service 2>/dev/null)

for c in init reboot shutdown halt poweroff telinit; do
cat > "$BLOCKDIR/$c" <<'EOS'
#!/bin/sh
echo "WordOfEnigma2: '$0' suppressed (batch in progress)"
exit 0
EOS
done

cat > "$BLOCKDIR/killall" <<EOS
#!/bin/sh
for a in "\$@"; do
  case "\$a" in
    *enigma2*) echo "WordOfEnigma2: killall \$a suppressed (batch)"; exit 0;;
  esac
done
exec $RKILLALL "\$@"
EOS

if [ -n "$RSYSTEMCTL" ]; then
cat > "$BLOCKDIR/systemctl" <<EOS
#!/bin/sh
case "\$*" in
  *enigma2*) echo "WordOfEnigma2: systemctl \$* suppressed (batch)"; exit 0;;
esac
exec $RSYSTEMCTL "\$@"
EOS
fi

if [ -n "$RSERVICE" ]; then
cat > "$BLOCKDIR/service" <<EOS
#!/bin/sh
case "\$*" in
  *enigma2*) echo "WordOfEnigma2: service \$* suppressed (batch)"; exit 0;;
esac
exec $RSERVICE "\$@"
EOS
fi

chmod +x "$BLOCKDIR"/* 2>/dev/null
export PATH="$BLOCKDIR:$PATH"
export WORD_OF_ENIGMA2_BATCH=1
echo "WordOfEnigma2: Enigma2 restarts are disabled until the batch finishes."
echo ""
'''


def build_batch_script(items):
    """Build one shell script that installs all selected items in order.

    It is run fully detached (setsid) so an Enigma2 restart triggered by one
    installer cannot kill the rest of the batch. Per-item restarts are also
    actively suppressed (see BATCH_RESTART_BLOCKER) so only ONE restart is
    needed at the very end, after every item has been installed.
    """
    dest = "/tmp/wordofenigma2_batch_file"
    out = ["#!/bin/sh", "# WordOfEnigma2 batch installer", ""]
    out.extend(BATCH_RESTART_BLOCKER.strip("\n").split("\n"))
    out.append("")
    total = len(items)
    for i, item in enumerate(items):
        url = (item.get("file") or "").strip()
        if not url:
            continue
        name = item.get("name", "item")
        # keep the header shell-safe and ASCII
        safe = "".join([ch for ch in name
                        if 32 <= ord(ch) < 127 and ch not in "'\"`$\\;"])
        if not safe:
            safe = "item"
        body = batch_install_body(url, dest)
        out.append('echo ""')
        out.append('echo "======== [%d/%d] %s ========"' % (i + 1, total, safe))
        out.append('rm -f %s' % dest)
        out.append('if wget -q --no-check-certificate --timeout=120 --tries=3 -O %s "%s"; then'
                   % (dest, url))
        out.append('    if %s; then' % body)
        out.append('        echo ">>> OK: %s"' % safe)
        out.append('    else')
        out.append('        echo ">>> FAILED: %s"' % safe)
        out.append('    fi')
        out.append('else')
        out.append('    echo ">>> DOWNLOAD FAILED: %s"' % safe)
        out.append('fi')
        out.append('rm -f %s' % dest)
        out.append('')
    out.append('echo ""')
    out.append('echo "======== ALL DONE ========"')
    out.append('rm -rf "$BLOCKDIR" 2>/dev/null')
    out.append('exit 0')
    return "\n".join(out) + "\n"


# =====================================================================
# SKIN - HEADER (shared by the grid and item screens)
# =====================================================================
_HEADER_SKIN = """    <eLabel position="40,22" size="470,46" text="WORD OF ENIGMA2" font="Regular;36" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <widget name="version" position="42,72" size="300,30" font="Regular;22" foregroundColor="#3b82f6" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <widget name="devname" position="540,20" size="420,38" font="Regular;26" foregroundColor="#e5e7eb" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <widget name="devtemp" position="540,62" size="420,34" font="Regular;22" foregroundColor="#10b981" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <widget name="imagename" position="980,20" size="420,38" font="Regular;26" foregroundColor="#e5e7eb" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <widget name="pyver" position="980,62" size="420,34" font="Regular;22" foregroundColor="#3b82f6" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <eLabel position="1640,35" size="240,50" text="Plugin Store" font="Regular;26" foregroundColor="#8b5cf6" backgroundColor="#131A2A" transparent="1" halign="right" zPosition="2" />"""


# =====================================================================
# SKIN - MAIN SCREEN (category grid 4 x 3 with icons)
# =====================================================================
GRID_COLS = 4
GRID_ROWS = 3
GRID_SIZE = GRID_COLS * GRID_ROWS
CELL_W = 450
CELL_H = 266
CELL_GAP_X = 20
CELL_GAP_Y = 20
GRID_X0 = 40
GRID_Y0 = 150
CELL_ICON = 170


def _grid_cells_skin():
    cells = []
    for i in range(GRID_SIZE):
        r, c = divmod(i, GRID_COLS)
        x = GRID_X0 + c * (CELL_W + CELL_GAP_X)
        y = GRID_Y0 + r * (CELL_H + CELL_GAP_Y)
        ix = x + (CELL_W - CELL_ICON) // 2
        iy = y + 14
        cells.append(
            '    <widget name="cellsel%d" position="%d,%d" size="%d,%d" '
            'backgroundColor="#0B0F19" transparent="0" zPosition="0" />'
            % (i, x - 5, y - 5, CELL_W + 10, CELL_H + 10))
        cells.append(
            '    <widget name="cellbg%d" position="%d,%d" size="%d,%d" '
            'backgroundColor="#131A2A" transparent="0" zPosition="1" />'
            % (i, x, y, CELL_W, CELL_H))
        cells.append(
            '    <widget name="cellicon%d" position="%d,%d" size="%d,%d" '
            'transparent="1" alphatest="blend" scale="1" zPosition="2" />'
            % (i, ix, iy, CELL_ICON, CELL_ICON))
        cells.append(
            '    <widget name="celltxt%d" position="%d,%d" size="%d,%d" font="Regular;30" '
            'foregroundColor="#d1d5db" backgroundColor="#131A2A" transparent="1" '
            'halign="center" valign="center" zPosition="2" />'
            % (i, x + 10, y + 186, CELL_W - 20, 74))
    return "\n".join(cells)


SKIN = """
<screen name="WordOfEnigma2" position="0,0" size="1920,1080" title="Word Of Enigma2" flags="wfNoBorder">
    <eLabel position="0,0" size="1920,1080" backgroundColor="#0B0F19" zPosition="-100" />
    <eLabel position="0,0" size="1920,110" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,110" size="1920,3" backgroundColor="#3b82f6" zPosition="-89" />
""" + _HEADER_SKIN + """

    <!-- Category grid (4 x 3) -->
""" + _grid_cells_skin() + """

    <!-- Footer -->
    <eLabel position="0,1010" size="1920,70" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,1010" size="1920,2" backgroundColor="#1A2235" zPosition="-89" />
    <widget name="description" position="40,1020" size="1020,50" font="Regular;24" foregroundColor="#9ca3af" backgroundColor="#131A2A" transparent="1" valign="center" zPosition="2" />
    <widget name="key_red"    position="1090,1020" size="190,50" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#e11d48" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_green"  position="1290,1020" size="190,50" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#059669" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_yellow" position="1490,1020" size="190,50" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#d97706" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_blue"   position="1690,1020" size="190,50" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#0284c7" transparent="0" halign="center" valign="center" zPosition="3" />
</screen>
"""


# =====================================================================
# SKIN - ITEMS SCREEN (content of a category, shown as a grid too)
# =====================================================================
ITEMS_COLS = 4
ITEMS_PER_PAGE = 16
ITILE_W = 450
ITILE_H = 168
ITILE_GAP_X = 20
ITILE_GAP_Y = 16
ITEMS_X0 = 40
ITEMS_Y0 = 180


def _items_cells_skin():
    cells = []
    for i in range(ITEMS_PER_PAGE):
        r, c = divmod(i, ITEMS_COLS)
        x = ITEMS_X0 + c * (ITILE_W + ITILE_GAP_X)
        y = ITEMS_Y0 + r * (ITILE_H + ITILE_GAP_Y)
        cells.append(
            '    <widget name="itilesel%d" position="%d,%d" size="%d,%d" '
            'backgroundColor="#0B0F19" transparent="0" zPosition="1" />'
            % (i, x - 4, y - 4, ITILE_W + 8, ITILE_H + 8))
        cells.append(
            '    <widget name="itile%d" position="%d,%d" size="%d,%d" font="Regular;26" '
            'foregroundColor="#d1d5db" backgroundColor="#131A2A" transparent="0" '
            'halign="center" valign="center" zPosition="2" />'
            % (i, x, y, ITILE_W, ITILE_H))
    return "\n".join(cells)


ITEMS_SKIN = """
<screen name="WordOfEnigma2Items" position="0,0" size="1920,1080" title="Word Of Enigma2" flags="wfNoBorder">
    <eLabel position="0,0" size="1920,1080" backgroundColor="#0B0F19" zPosition="-100" />
    <eLabel position="0,0" size="1920,110" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,110" size="1920,3" backgroundColor="#3b82f6" zPosition="-89" />
""" + _HEADER_SKIN + """

    <!-- Section title + page indicator -->
    <widget name="header" position="40,150" size="900,40" font="Regular;30" foregroundColor="#ffffff" backgroundColor="#0B0F19" transparent="1" zPosition="2" />
    <widget name="page"   position="1450,150" size="450,40" font="Regular;24" foregroundColor="#8b5cf6" backgroundColor="#0B0F19" transparent="1" halign="right" zPosition="2" />
    <eLabel position="40,192" size="1860,2" backgroundColor="#1A2235" zPosition="-50" />

    <!-- Item tiles (4 x 4) -->
""" + _items_cells_skin() + """

    <!-- Info strip -->
    <eLabel position="0,905" size="1920,102" backgroundColor="#131A2A" zPosition="-50" />
    <eLabel position="0,905" size="1920,2" backgroundColor="#1A2235" zPosition="-49" />
    <widget name="description" position="40,912" size="1840,88" font="Regular;24" foregroundColor="#9ca3af" backgroundColor="#131A2A" transparent="1" valign="top" zPosition="2" />

    <!-- Footer -->
    <eLabel position="0,1010" size="1920,70" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,1010" size="1920,2" backgroundColor="#1A2235" zPosition="-89" />
    <widget name="key_red"    position="30,1020"  size="300,50" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#e11d48" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_green"  position="340,1020" size="300,50" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#059669" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_yellow" position="650,1020" size="300,50" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#d97706" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_blue"   position="960,1020" size="480,50" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#0284c7" transparent="0" halign="center" valign="center" zPosition="3" />
    <eLabel position="1450,1020" size="440,50" text="Arrows: move   OK: open/select" font="Regular;24" foregroundColor="#8b5cf6" backgroundColor="#131A2A" transparent="1" halign="right" valign="center" zPosition="3" />
</screen>
"""


# =====================================================================
# CONSOLE SKIN
# =====================================================================
CONSOLE_SKIN = """
<screen name="WordOfEnigma2Console" position="0,0" size="1920,1080" title="Installation Console" flags="wfNoBorder">
    <eLabel position="0,0" size="1920,1080" backgroundColor="#05070D" zPosition="-100" />

    <!-- Header -->
    <eLabel position="0,0" size="1920,90" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,90" size="1920,3" backgroundColor="#10b981" zPosition="-89" />
    <widget name="header" position="40,25" size="1300,45" font="Regular;34" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <widget name="status" position="1360,28" size="520,40" font="Regular;28" foregroundColor="#10b981" backgroundColor="#131A2A" transparent="1" halign="right" zPosition="2" />

    <!-- Log -->
    <widget name="log" position="40,110" size="1840,900" font="Regular;22" foregroundColor="#d1d5db" backgroundColor="#05070D" transparent="1" valign="top" zPosition="2" />

    <!-- Footer -->
    <eLabel position="0,1025" size="1920,55" backgroundColor="#131A2A" zPosition="-90" />
    <widget name="key_red"  position="60,1032"  size="560,40" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#e11d48" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_blue" position="700,1032" size="560,40" font="Regular;26" foregroundColor="#ffffff" backgroundColor="#0284c7" transparent="0" halign="center" valign="center" zPosition="3" />
    <eLabel   position="1360,1032" size="500,40" text="Up/Down: scroll log" font="Regular;24" foregroundColor="#8b5cf6" backgroundColor="#131A2A" transparent="1" halign="right" zPosition="3" />
</screen>
"""


# =====================================================================
# MENU SKIN (MENU key popup: Information / Check for updates)
# =====================================================================
BATCH_MENU_SKIN = """
<screen name="WordOfEnigma2Menu" position="center,center" size="820,600" title="Menu" flags="wfNoBorder">
    <eLabel position="0,0" size="820,600" backgroundColor="#0B0F19" zPosition="-100" />
    <eLabel position="0,0" size="820,90" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,90" size="820,3" backgroundColor="#8b5cf6" zPosition="-89" />
    <widget name="menuheader" position="30,22" size="760,50" font="Regular;32" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <widget name="list" position="30,120" size="760,450" itemHeight="76" font="Regular;30" foregroundColor="#d1d5db" backgroundColor="#0B0F19" transparent="1" scrollbarMode="showOnDemand" zPosition="2" />
</screen>
"""


# =====================================================================
# INFORMATION SCREEN (MENU -> Information)
# Shows plugin version, author and the Facebook QR code.
# =====================================================================
INFO_SKIN = """
<screen name="WordOfEnigma2Info" position="center,center" size="1180,660" title="Information" flags="wfNoBorder">
    <eLabel position="0,0" size="1180,660" backgroundColor="#0B0F19" zPosition="-100" />
    <eLabel position="0,0" size="1180,80" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,80" size="1180,3" backgroundColor="#8b5cf6" zPosition="-89" />
    <widget name="header" position="30,20" size="1120,50" font="Regular;34" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />

    <widget name="appname" position="40,140" size="620,60" font="Regular;44" foregroundColor="#8b5cf6" backgroundColor="#0B0F19" transparent="1" zPosition="2" />
    <widget name="version" position="40,220" size="620,46" font="Regular;32" foregroundColor="#e5e7eb" backgroundColor="#0B0F19" transparent="1" zPosition="2" />
    <widget name="author" position="40,275" size="620,46" font="Regular;32" foregroundColor="#e5e7eb" backgroundColor="#0B0F19" transparent="1" zPosition="2" />
    <widget name="note" position="40,345" size="610,200" font="Regular;25" foregroundColor="#9ca3af" backgroundColor="#0B0F19" transparent="1" zPosition="2" />

    <eLabel position="680,110" size="470,470" backgroundColor="#ffffff" zPosition="0" />
    <widget name="qrcode" position="690,120" size="450,450" zPosition="2" />

    <eLabel position="0,580" size="1180,80" backgroundColor="#131A2A" zPosition="-90" />
    <widget name="key_red" position="40,600" size="300,44" font="Regular;30" foregroundColor="#ef4444" backgroundColor="#131A2A" transparent="1" zPosition="2" />
</screen>
"""


# =====================================================================
# SYSTEM INFO HELPERS (header)
# =====================================================================
def _read_first_line(path):
    try:
        f = open(path, "r")
        try:
            return f.read().strip()
        finally:
            f.close()
    except Exception:
        return ""


def get_device_name():
    name = ""
    try:
        from boxbranding import getMachineBrand, getMachineName
        brand = getMachineBrand() or ""
        model = getMachineName() or ""
        name = (brand + " " + model).strip()
    except Exception:
        name = ""
    if not name:
        for p in ("/proc/stb/info/boxtype", "/proc/stb/info/model", "/etc/hostname"):
            v = _read_first_line(p)
            if v:
                name = v
                break
    return name or "Unknown"


def get_image_name():
    distro = ""
    ver = ""
    try:
        from boxbranding import getImageDistro, getImageVersion
        distro = getImageDistro() or ""
        ver = getImageVersion() or ""
    except Exception:
        pass
    if not distro:
        for p in ("/etc/image-version", "/etc/issue"):
            v = _read_first_line(p)
            if v:
                distro = v.split("\n")[0]
                break
    name = (distro + ((" " + ver) if ver else "")).strip()
    return name or "Unknown"


def get_python_version():
    try:
        from boxbranding import getPythonVersion
        v = getPythonVersion()
        if v:
            return str(v)
    except Exception:
        pass
    try:
        return "%d.%d.%d" % (sys.version_info[0], sys.version_info[1], sys.version_info[2])
    except Exception:
        return "-"


def get_temperature():
    import re
    for p in ("/proc/stb/fp/temp_sensor_ma",
              "/proc/stb/fp/temp_sensor",
              "/sys/class/thermal/thermal_zone0/temp",
              "/proc/hisi/msp/pm_cpu",
              "/proc/vuplus/temp"):
        v = _read_first_line(p)
        if not v:
            continue
        m = re.search(r"(-?\d+(?:\.\d+)?)", v)
        if not m:
            continue
        try:
            t = float(m.group(1))
        except Exception:
            continue
        if t > 1000:
            t = t / 1000.0
        if 0 < t < 150:
            return "%d\u00b0C" % int(round(t))
    return "--"


# =====================================================================
# BASE SCREEN - shared store / update / system-info logic
# =====================================================================
class WoeStoreBase(Screen):
    update_in_progress = False

    # -----------------------------------------------------------------
    # SYSTEM INFO (header)
    # -----------------------------------------------------------------
    def update_system_info(self):
        try:
            self["devname"].setText("Box: " + get_device_name())
        except Exception:
            pass
        self.refresh_temperature()
        try:
            self["imagename"].setText("Image: " + get_image_name())
        except Exception:
            pass
        try:
            self["pyver"].setText("Python: " + get_python_version())
        except Exception:
            pass

    def refresh_temperature(self):
        try:
            self["devtemp"].setText("Temp: " + get_temperature())
        except Exception:
            pass

    def init_system_info(self):
        self.update_system_info()
        if eTimer is None:
            return
        try:
            self.info_timer = eTimer()
            try:
                self.info_timer.callback.append(self.refresh_temperature)
            except AttributeError:
                self.info_timer.timeout.connect(self.refresh_temperature)
            self.info_timer.start(5000)
        except Exception:
            pass

    def set_description(self, text):
        try:
            self["description"].setText(text)
        except Exception:
            pass

    # -----------------------------------------------------------------
    # STORE LOADING
    # -----------------------------------------------------------------
    def schedule_fetch(self):
        if getattr(self, "bg_timer", None):
            self.bg_timer.start(200, True)

    def start_network_fetch(self):
        t = threading.Thread(target=self.async_fetch)
        t.daemon = True
        t.start()

    def async_fetch(self):
        # Cache-buster so the GitHub CDN cannot serve a stale feed
        # (otherwise newly added/removed store items don't appear).
        data = load_json_network(STORE_URL + "?t=" + str(int(time.time())))
        if data and "categories" in data:
            try:
                with open(CACHE_FILE, "w") as f:
                    json.dump(data, f)
            except Exception:
                pass
            gui_call(self.apply_store_data, data)
        elif getattr(self, "categories", None):
            gui_call(self.set_description,
                     "Refresh failed - showing cached data.\n"
                     "Press YELLOW to retry.")
        else:
            gui_call(self.set_description, "Failed to connect to server.")

    def load_local_cache(self):
        try:
            if os.path.exists(CACHE_FILE):
                with open(CACHE_FILE, "r") as f:
                    data = json.load(f)
                if data and "categories" in data:
                    self.apply_store_data(data)
                    return True
        except Exception:
            pass
        return False

    def load_store(self):
        self["description"].setText("Refreshing store...")
        t = threading.Thread(target=self.async_fetch)
        t.daemon = True
        t.start()

    def render_categories(self):
        # Overridden by the grid screen.
        pass

    def apply_store_data(self, data):
        try:
            name = data.get("store_name", "Word Of Enigma2")
            ver = data.get("version", PLUGIN_VERSION)
            self.setTitle("%s v%s" % (name, ver))

            self.store_data = data.get("categories", {})
            if isinstance(self.store_data, dict):
                self.categories = list(self.store_data.keys())
            else:
                self.store_data = {}
                self.categories = []

            self.render_categories()
        except Exception as e:
            self.set_description("Error: " + str(e))

    # -----------------------------------------------------------------
    # SELF UPDATE - MENU -> "Check for updates"
    # -----------------------------------------------------------------
    def self_update(self):
        if self.update_in_progress:
            return
        self["description"].setText("Checking for updates...")
        t = threading.Thread(target=self.check_version)
        t.daemon = True
        t.start()

    def check_version(self):
        try:
            local_ver = "0.0.0"
            local_file = "/usr/lib/enigma2/python/Plugins/Extensions/WordOfEnigma2/version.json"
            if not os.path.exists(local_file):
                local_file = os.path.join(PLUGIN_DIR, "version.json")
            if os.path.exists(local_file):
                try:
                    with open(local_file, "r") as f:
                        data = json.load(f)
                    local_ver = data.get("version", "0.0.0")
                except Exception:
                    pass

            remote_data = load_json_network(
                GITHUB_BASE + "/version.json?t=" + str(int(time.time())))
            remote_ver = remote_data.get("version", "0.0.0") if remote_data else "0.0.0"

            if self.version_newer(remote_ver, local_ver):
                msg = "New update available!\n\nLocal: %s\nGitHub: %s\n\nDo you want to update now?" % (local_ver, remote_ver)
                gui_call(self.show_update_dialog, msg)
            elif self.version_newer(local_ver, remote_ver):
                msg = "Local version is newer (dev build)\n\nLocal: %s\nGitHub: %s" % (local_ver, remote_ver)
                gui_call(self.show_update_dialog, msg, True)
            else:
                msg = "You are using the latest version\n\nVersion: %s" % local_ver
                gui_call(self.show_update_dialog, msg, True)
        except Exception as e:
            self.update_in_progress = False
            gui_call(self.set_description, "Check error: " + str(e))

    def version_newer(self, v1, v2):
        try:
            parts1 = [int(x) for x in str(v1).split(".")]
            parts2 = [int(x) for x in str(v2).split(".")]
            while len(parts1) < len(parts2):
                parts1.append(0)
            while len(parts2) < len(parts1):
                parts2.append(0)
            return parts1 > parts2
        except Exception:
            return False

    def show_update_dialog(self, msg, info_only=False):
        # Always invoked on the main thread via gui_call().
        if info_only:
            self.session.open(MessageBox, msg, MessageBox.TYPE_INFO)
        else:
            self.session.openWithCallback(
                self.confirm_update,
                MessageBox,
                msg,
                MessageBox.TYPE_YESNO
            )

    def confirm_update(self, answer):
        if not answer:
            return
        self.update_in_progress = True
        self["description"].setText("Updating plugin...\n\nPlease wait...")
        t = threading.Thread(target=self.run_update)
        t.daemon = True
        t.start()

    def run_update(self):
        try:
            # Use a cache-busting timestamp so the GitHub CDN cannot serve a
            # stale plugin.py/version.json right after a new release.
            base = GITHUB_BASE
            script = (
                "#!/bin/sh\n"
                "cd /tmp || exit 1\n"
                'BASE="%s"\n'
                'DEST="%s"\n'
                "TS=$(date +%%s)\n"
                'mkdir -p "$DEST/feed" "$DEST/images/Icons"\n'
                'echo "Downloading core files..."\n'
                'wget -q --no-check-certificate "$BASE/plugin.py?t=$TS" -O wordofenigma2_dl.py || exit 2\n'
                'wget -q --no-check-certificate "$BASE/plugin.png?t=$TS" -O wordofenigma2_dl.png || exit 3\n'
                'wget -q --no-check-certificate "$BASE/version.json?t=$TS" -O wordofenigma2_dl.json || exit 4\n'
                'wget -q --no-check-certificate "$BASE/feed/index.json?t=$TS" -O wordofenigma2_dl_feed.json || exit 5\n'
                'echo "Downloading images..."\n'
                'for img in qrcode logo background avatar key_red key_green key_yellow key_blue progress; do\n'
                '    wget -q --no-check-certificate "$BASE/images/$img.png?t=$TS" -O "wordofenigma2_img_$img.png" || exit 20\n'
                'done\n'
                'for ic in plugins skins media tools system_images picons channels emus novaler default; do\n'
                '    wget -q --no-check-certificate "$BASE/images/Icons/$ic.png?t=$TS" -O "wordofenigma2_ic_$ic.png" || true\n'
                'done\n'
                'echo "Installing to $DEST ..."\n'
                'cp wordofenigma2_dl.py "$DEST/plugin.py" || exit 7\n'
                'cp wordofenigma2_dl.png "$DEST/plugin.png" || exit 8\n'
                'cp wordofenigma2_dl.json "$DEST/version.json" || exit 9\n'
                'cp wordofenigma2_dl_feed.json "$DEST/feed/index.json" || exit 10\n'
                'for img in qrcode logo background avatar key_red key_green key_yellow key_blue progress; do\n'
                '    cp "wordofenigma2_img_$img.png" "$DEST/images/$img.png" || true\n'
                'done\n'
                'for ic in plugins skins media tools system_images picons channels emus novaler default; do\n'
                '    [ -f "wordofenigma2_ic_$ic.png" ] && cp "wordofenigma2_ic_$ic.png" "$DEST/images/Icons/$ic.png"\n'
                'done\n'
                'rm -f "$DEST/plugin.pyc" "$DEST/store_cache.json"\n'
                'rm -rf "$DEST/__pycache__"\n'
                'LEGACY="/usr/lib/enigma2/python/Plugins/Extensions/AllStore"\n'
                'if [ "$DEST" != "$LEGACY" ] && [ -d "$LEGACY" ]; then rm -rf "$LEGACY"; echo "Removed legacy AllStore folder"; fi\n'
                'rm -f wordofenigma2_dl.py wordofenigma2_dl.png wordofenigma2_dl.json wordofenigma2_dl_feed.json\n'
                'rm -f wordofenigma2_img_*.png wordofenigma2_ic_*.png\n'
                'echo "DONE. Installed version.json:"\n'
                'cat "$DEST/version.json"\n'
            ) % (base, PLUGIN_DIR)
            script_path = "/tmp/wordofenigma2_update.sh"
            log_file = "/tmp/wordofenigma2_update.log"
            data = script if isinstance(script, bytes) else script.encode("utf-8")
            f = open(script_path, "wb")
            f.write(data)
            f.close()
            retval = os.system("chmod +x %s && sh %s > %s 2>&1" % (script_path, script_path, log_file))
            output = ""
            try:
                f = open(log_file, "r")
                output = f.read()
                f.close()
            except Exception:
                pass
            code = 0
            try:
                if retval:
                    code = retval >> 8 if (retval >> 8) else retval
            except Exception:
                code = retval
            self.update_done(output, code)
        except Exception as e:
            self.update_in_progress = False
            gui_call(self.set_description, "Update error: " + str(e))

    def update_done(self, result, retval, extra_args=None):
        def _ui():
            self.update_in_progress = False
            out = result.strip() if result else "(no output)"
            if retval == 0:
                self.session.openWithCallback(
                    self.restart_callback,
                    MessageBox,
                    "Plugin updated successfully!\n\n%s\n\nRestart Enigma2 now?" % out,
                    MessageBox.TYPE_YESNO
                )
            else:
                self.session.open(
                    MessageBox,
                    "Update FAILED (step %s):\n\n%s" % (retval, out[-1500:]),
                    MessageBox.TYPE_ERROR
                )
                self.set_description("Update failed at step %s.\nSee the message for details." % retval)
        gui_call(_ui)

    def restart_callback(self, answer):
        if answer:
            try:
                if TryQuitMainloop:
                    self.session.open(TryQuitMainloop, 3)
                else:
                    os.system("killall -9 enigma2")
            except Exception:
                os.system("killall -9 enigma2")

    # -----------------------------------------------------------------
    # MENU popup: Information + Item details + Check for updates
    # -----------------------------------------------------------------
    def main_menu(self):
        try:
            options = [
                ("Information", "info"),
                ("Item details", "item"),
                ("Check for updates", "update"),
            ]
            self.session.openWithCallback(
                self.main_menu_done,
                WordOfEnigma2Menu,
                "Menu",
                options
            )
        except Exception:
            pass

    def main_menu_done(self, choice):
        if not choice:
            return
        if choice == "info":
            try:
                self.session.open(WordOfEnigma2Info)
            except Exception:
                pass
        elif choice == "item":
            if hasattr(self, "show_info_popup"):
                self.show_info_popup()
        elif choice == "update":
            self.self_update()


# =====================================================================
# IMAGE HELPERS (category icons)
# =====================================================================
def load_pixmap_ptr(path):
    """Load a PNG into an ePixmap pointer using the most common APIs."""
    if not path:
        return None
    try:
        from Tools.LoadPixmap import LoadPixmap
        ptr = LoadPixmap(path)
        if ptr is not None:
            return ptr
    except Exception:
        pass
    try:
        from Tools.LoadPixmap import loadPixmap
        ptr = loadPixmap(path)
        if ptr is not None:
            return ptr
    except Exception:
        pass
    try:
        from enigma import loadPNG
        return loadPNG(path, 0, 1)
    except Exception:
        return None


def _icons_dir():
    dirs = [os.path.join(PLUGIN_DIR, "images", "Icons")]
    try:
        dirs.append(os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "images", "Icons"))
    except Exception:
        pass
    return dirs


def category_icon_path(cat):
    """Return the icon path for a category, or the default icon."""
    for base in _icons_dir():
        for name in (cat, "default"):
            p = os.path.join(base, name + ".png")
            try:
                if os.path.exists(p) and os.path.getsize(p) > 200:
                    return p
            except Exception:
                continue
    return None


# =====================================================================
# MAIN SCREEN - category grid (4 x 3) with icons
# =====================================================================
class WordOfEnigma2(WoeStoreBase):
    skin = SKIN

    def __init__(self, session):
        Screen.__init__(self, session)
        self.setTitle("Word Of Enigma2")

        self["version"] = Label("v" + PLUGIN_VERSION)
        self["devname"] = Label("")
        self["devtemp"] = Label("")
        self["imagename"] = Label("")
        self["pyver"] = Label("")
        self["description"] = Label("Loading...")
        self["key_red"] = Label("Exit")
        self["key_green"] = Label("Open")
        self["key_yellow"] = Label("Refresh")
        self["key_blue"] = Label("Menu")

        # Category tiles: background + icon + text
        self.cell_bg = []
        self.cell_txt = []
        self.cell_icon = []
        self.cell_sel = []
        for i in range(GRID_SIZE):
            bg = Label("")
            tx = Label("")
            ic = Pixmap()
            fs = Label("")
            self["cellbg%d" % i] = bg
            self["celltxt%d" % i] = tx
            self["cellicon%d" % i] = ic
            self["cellsel%d" % i] = fs
            self.cell_bg.append(bg)
            self.cell_txt.append(tx)
            self.cell_icon.append(ic)
            self.cell_sel.append(fs)

        self["actions"] = ActionMap(
            ["OkCancelActions", "DirectionActions", "ColorActions", "MenuActions"],
            {
                "cancel": self.close,
                "red": self.close,
                "green": self.open_category,
                "yellow": self.load_store,
                "blue": self.main_menu,
                "menu": self.main_menu,
                "ok": self.open_category,
                "up": lambda: self.move_selection(0, -1),
                "down": lambda: self.move_selection(0, 1),
                "left": lambda: self.move_selection(-1, 0),
                "right": lambda: self.move_selection(1, 0),
            },
            -1
        )

        self.store_data = {}
        self.categories = []
        self.grid_categories = []
        self.grid_index = 0

        self.load_local_cache()

        self.bg_timer = eTimer()
        try:
            self.bg_timer.callback.append(self.start_network_fetch)
        except AttributeError:
            try:
                self.bg_timer.timeout.connect(self.start_network_fetch)
            except Exception:
                pass
        self.onLayoutFinish.append(self.render_categories)
        self.onLayoutFinish.append(self.schedule_fetch)
        self.onLayoutFinish.append(self.init_system_info)

    # -----------------------------------------------------------------
    def render_categories(self):
        # Only categories that actually contain items are shown in the grid.
        self.grid_categories = []
        for cat in self.categories:
            if count_items(self.store_data.get(cat, [])) > 0:
                self.grid_categories.append(cat)

        for i in range(GRID_SIZE):
            if i < len(self.grid_categories):
                cat = self.grid_categories[i]
                count = count_items(self.store_data.get(cat, []))
                clean = cat.replace("_", " ").upper()
                try:
                    self.cell_txt[i].setText("%s\n(%d)" % (clean, count))
                except Exception:
                    pass
                self._load_cat_icon(i, cat)
            else:
                try:
                    self.cell_txt[i].setText("")
                except Exception:
                    pass
                try:
                    self.cell_icon[i].instance.hide()
                except Exception:
                    pass

        if self.grid_index >= len(self.grid_categories):
            self.grid_index = 0
        self.highlight_cells()
        self.update_grid_status()

    def _load_cat_icon(self, i, cat):
        inst = None
        try:
            inst = self.cell_icon[i].instance
        except Exception:
            inst = None
        if inst is None:
            return
        ptr = load_pixmap_ptr(category_icon_path(cat))
        if ptr is not None:
            try:
                inst.setPixmap(ptr)
                inst.show()
                return
            except Exception:
                pass
        try:
            inst.hide()
        except Exception:
            pass

    def highlight_cells(self):
        try:
            from skin import parseColor
        except Exception:
            return
        normal_bg = parseColor("#131A2A")
        normal_fg = parseColor("#d1d5db")
        sel_bg = parseColor("#1C2438")
        sel_fg = parseColor("#ffffff")
        frame = parseColor("#8b5cf6")
        empty_bg = parseColor("#0F1522")
        empty_fg = parseColor("#374151")
        n = len(self.grid_categories)
        for i in range(GRID_SIZE):
            try:
                bg = self.cell_bg[i].instance
                tx = self.cell_txt[i].instance
                fr = self.cell_sel[i].instance
                if fr:
                    if i < n and i == self.grid_index:
                        fr.setBackgroundColor(frame)
                        fr.show()
                    else:
                        fr.hide()
                if i >= n:
                    if bg:
                        bg.setBackgroundColor(empty_bg)
                    if tx:
                        tx.setForegroundColor(empty_fg)
                elif i == self.grid_index:
                    if bg:
                        bg.setBackgroundColor(sel_bg)
                    if tx:
                        tx.setForegroundColor(sel_fg)
                else:
                    if bg:
                        bg.setBackgroundColor(normal_bg)
                    if tx:
                        tx.setForegroundColor(normal_fg)
            except Exception:
                pass

    def update_grid_status(self):
        n = len(self.grid_categories)
        if n == 0:
            self.set_description("No categories available. Press YELLOW to refresh.")
            return
        if self.grid_index >= n:
            self.grid_index = 0
        cat = self.grid_categories[self.grid_index]
        count = count_items(self.store_data.get(cat, []))
        note = ""
        if n > GRID_SIZE:
            note = "   (+%d more not shown)" % (n - GRID_SIZE)
        self.set_description("%s  -  %d item(s).   OK / GREEN: open%s"
                             % (cat.replace("_", " ").title(), count, note))

    def move_selection(self, dx, dy):
        n = len(self.grid_categories)
        if n == 0:
            return
        row, col = divmod(self.grid_index, GRID_COLS)
        col = max(0, min(GRID_COLS - 1, col + dx))
        row = max(0, min(GRID_ROWS - 1, row + dy))
        new = row * GRID_COLS + col
        if new >= n:
            new = n - 1
        if new != self.grid_index:
            self.grid_index = new
            self.highlight_cells()
            self.update_grid_status()

    def open_category(self):
        if not self.grid_categories or self.grid_index >= len(self.grid_categories):
            return
        cat = self.grid_categories[self.grid_index]
        items = self.store_data.get(cat, [])
        if not items:
            self.set_description("%s is empty." % cat.replace("_", " ").title())
            return
        self.session.openWithCallback(
            self._items_closed,
            WordOfEnigma2Items,
            self.store_data,
            cat
        )

    def _items_closed(self, *args):
        self.update_grid_status()


# =====================================================================
# ITEMS SCREEN - content of a selected category (shown as a grid)
# =====================================================================
class WordOfEnigma2Items(WoeStoreBase):
    skin = ITEMS_SKIN

    def __init__(self, session, store_data=None, category=None):
        Screen.__init__(self, session)
        self.category = category or ""
        self.store_data = store_data if isinstance(store_data, dict) else {}
        self.setTitle("Word Of Enigma2 - " + self.category.replace("_", " ").title())

        self["version"] = Label("v" + PLUGIN_VERSION)
        self["devname"] = Label("")
        self["devtemp"] = Label("")
        self["imagename"] = Label("")
        self["pyver"] = Label("")
        self["header"] = Label("")
        self["page"] = Label("")
        self["description"] = Label("")
        self["key_red"] = Label("Back")
        self["key_green"] = Label("Install")
        self["key_yellow"] = Label("Select")
        self["key_blue"] = Label("Batch Install")

        self.tile_widgets = []
        self.tile_sel = []
        for i in range(ITEMS_PER_PAGE):
            lbl = Label("")
            fs = Label("")
            self["itile%d" % i] = lbl
            self["itilesel%d" % i] = fs
            self.tile_widgets.append(lbl)
            self.tile_sel.append(fs)

        self["actions"] = ActionMap(
            ["OkCancelActions", "DirectionActions", "ColorActions", "MenuActions"],
            {
                "cancel": self.back,
                "red": self.back,
                "green": self.download_item,
                "yellow": self.toggle_select,
                "blue": self.blue_pressed,
                "menu": self.main_menu,
                "ok": self.ok_pressed,
                "up": lambda: self.move(0, -1),
                "down": lambda: self.move(0, 1),
                "left": lambda: self.move(-1, 0),
                "right": lambda: self.move(1, 0),
            },
            -1
        )

        self.items = self.store_data.get(self.category, [])
        self.current_path = []
        self.path_stack = []
        self.selected = []
        self.sel = 0
        self.page = 0
        self.install_cmd = ""
        self.install_item_name = ""
        self.is_image_download = False
        self.download_dest_path = ""

        self.update_view()
        self.onLayoutFinish.append(self.init_system_info)

    # -----------------------------------------------------------------
    def update_view(self):
        n = len(self.items)
        if n == 0:
            self.sel = 0
        elif self.sel >= n:
            self.sel = n - 1
        elif self.sel < 0:
            self.sel = 0
        self.page = self.sel // ITEMS_PER_PAGE

        try:
            title = self.category.replace("_", " ").title() if self.category else "Items"
            if self.current_path:
                title = " / ".join([str(c.get("name", "?")) for c in self.current_path])
            self["header"].setText(title.upper())
        except Exception:
            pass

        start = self.page * ITEMS_PER_PAGE
        for i, lbl in enumerate(self.tile_widgets):
            idx = start + i
            try:
                if idx < n:
                    it = self.items[idx]
                    if isinstance(it, dict) and "items" in it:
                        nm = "[+] " + str(it.get("name", "?"))
                    else:
                        nm = str(it.get("name", "?"))
                        if self.is_selected(it):
                            nm = "[x] " + nm
                    lbl.setText(nm)
                else:
                    lbl.setText("")
            except Exception:
                pass

        self.highlight_tiles()
        self.update_page_label()
        self.update_info()

    def highlight_tiles(self):
        try:
            from skin import parseColor
        except Exception:
            return
        normal_bg = parseColor("#131A2A")
        normal_fg = parseColor("#d1d5db")
        sel_bg = parseColor("#1C2438")
        sel_fg = parseColor("#ffffff")
        frame = parseColor("#8b5cf6")
        empty_bg = parseColor("#0F1522")
        empty_fg = parseColor("#374151")
        n = len(self.items)
        start = self.page * ITEMS_PER_PAGE
        for i, lbl in enumerate(self.tile_widgets):
            try:
                inst = lbl.instance
                fr = self.tile_sel[i].instance
                idx = start + i
                if fr:
                    if idx == self.sel and idx < n:
                        fr.setBackgroundColor(frame)
                        fr.show()
                    else:
                        fr.hide()
                if inst is None:
                    continue
                if idx >= n:
                    inst.setBackgroundColor(empty_bg)
                    inst.setForegroundColor(empty_fg)
                elif idx == self.sel:
                    inst.setBackgroundColor(sel_bg)
                    inst.setForegroundColor(sel_fg)
                else:
                    inst.setBackgroundColor(normal_bg)
                    inst.setForegroundColor(normal_fg)
            except Exception:
                pass

    def update_page_label(self):
        n = len(self.items)
        pages = max(1, (n + ITEMS_PER_PAGE - 1) // ITEMS_PER_PAGE)
        try:
            self["page"].setText("Page %d/%d   -   %d item(s)"
                                 % (self.page + 1, pages, n))
        except Exception:
            pass

    def update_info(self):
        n = len(self.items)
        if n == 0 or self.sel >= n:
            self.set_description("No items in this section.")
            return
        it = self.items[self.sel]
        if isinstance(it, dict) and "items" in it:
            self.set_description("Folder: %s   (%d items)   -   OK: open"
                                 % (it.get("name", "?"), count_items(it["items"])))
        else:
            txt = "%s\n%s" % (it.get("name", "?"),
                              it.get("description", "No description") or "")
            if self.is_selected(it):
                txt += "    [SELECTED]"
            elif self.is_selectable(it):
                txt += "    OK: select   GREEN: install"
            self.set_description(txt)

    def move(self, dx, dy):
        n = len(self.items)
        if n == 0:
            return
        new = self.sel + dx + dy * ITEMS_COLS
        if new < 0:
            new = 0
        if new >= n:
            new = n - 1
        if new != self.sel:
            self.sel = new
            self.page = self.sel // ITEMS_PER_PAGE
            self.update_view()

    # -----------------------------------------------------------------
    def ok_pressed(self):
        n = len(self.items)
        if self.sel < 0 or self.sel >= n:
            return
        it = self.items[self.sel]
        if isinstance(it, dict) and "items" in it:
            self.path_stack.append(self.items)
            self.current_path.append(it)
            self.items = it["items"]
            self.sel = 0
            self.page = 0
            self.update_view()
        else:
            self.toggle_select()

    def back(self):
        if self.path_stack:
            self.items = self.path_stack.pop()
            if self.current_path:
                self.current_path.pop()
            self.sel = 0
            self.page = 0
            self.update_view()
        else:
            self.close()

    # -----------------------------------------------------------------
    # MULTI-SELECT + BATCH INSTALL
    # -----------------------------------------------------------------
    def is_selected(self, item):
        url = item.get("file", "")
        for s in self.selected:
            if s.get("file") == url:
                return True
        return False

    def is_selectable(self, item):
        if not isinstance(item, dict) or "items" in item:
            return False
        url = (item.get("file") or "").strip()
        if not url:
            return False
        # system images take very long and are not meant for batch install
        if "/system_images/" in url:
            return False
        return True

    def toggle_select(self):
        try:
            n = len(self.items)
            if self.sel < 0 or self.sel >= n:
                return
            it = self.items[self.sel]
            if not self.is_selectable(it):
                self.set_description("Folders and system images cannot be\n"
                                     "added to a batch install.")
                return
            if self.is_selected(it):
                url = it.get("file", "")
                self.selected = [s for s in self.selected if s.get("file") != url]
            else:
                self.selected.append(it)
            self.update_view()
        except Exception:
            pass

    def show_info_popup(self):
        """Show full details of the highlighted item."""
        try:
            n = len(self.items)
            if self.sel < 0 or self.sel >= n:
                return
            it = self.items[self.sel]
            name = it.get("name", "?")
            if "items" in it:
                msg = "Folder: %s\n\nItems: %d" % (name, count_items(it["items"]))
            else:
                msg = "Name: %s\n\nDescription:\n%s" % (
                    name, it.get("description", "No description"))
                url = (it.get("file") or "").strip()
                if url:
                    msg += "\n\nSource:\n" + url
                if self.is_selected(it):
                    msg += "\n\nStatus: selected for batch install"
            self.session.open(MessageBox, msg, MessageBox.TYPE_INFO)
        except Exception:
            pass

    def update_blue_label(self):
        try:
            n = len(self.selected)
            if n > 0:
                self["key_blue"].setText("Batch Install (%d)" % n)
            else:
                self["key_blue"].setText("Batch Install")
        except Exception:
            pass

    def blue_pressed(self):
        if self.selected:
            self.start_batch_install()
        else:
            self.set_description("No items selected.   OK: select items, then BLUE to install all.")

    def start_batch_install(self):
        items = list(self.selected)
        if not items:
            return
        names = [it.get("name", "?") for it in items]
        preview = "\n".join("  - %s" % nm for nm in names[:10])
        if len(names) > 10:
            preview += "\n  ... and %d more" % (len(names) - 10)
        prompt = ("Install %d selected item(s)?\n\n%s\n\n"
                  "Any restart requested by an individual installer is "
                  "postponed. Enigma2 restarts ONCE at the end, after every "
                  "item has been installed." % (len(items), preview))
        self.session.openWithCallback(
            self.start_batch_confirm,
            MessageBox,
            prompt,
            MessageBox.TYPE_YESNO
        )

    def start_batch_confirm(self, answer):
        if not answer:
            self.set_description("Batch install cancelled.")
            self.update_info()
            return
        items = list(self.selected)
        script = build_batch_script(items)
        script_path = "/tmp/wordofenigma2_batch.sh"
        log_file = "/tmp/wordofenigma2_console.log"
        done_file = "/tmp/wordofenigma2_done"
        try:
            data = script if isinstance(script, bytes) else script.encode("utf-8")
            f = open(script_path, "wb")
            f.write(data)
            f.close()
        except Exception as e:
            self.session.open(MessageBox, "Cannot write batch script:\n%s" % str(e),
                              MessageBox.TYPE_ERROR)
            return
        cmd = ("rm -f %s %s; chmod +x %s; "
               "setsid sh -c 'sh %s > %s 2>&1 < /dev/null; echo done > %s' "
               "> /dev/null 2>&1 < /dev/null &"
               % (log_file, done_file, script_path, script_path, log_file, done_file))
        self.session.openWithCallback(
            self.batch_finished,
            WordOfEnigma2Console,
            "Batch Install (%d items)" % len(items),
            cmd,
            log_file,
            done_file,
            False
        )

    def batch_finished(self, *args):
        self.selected = []
        self.update_view()

    # -----------------------------------------------------------------
    def download_item(self):
        try:
            n = len(self.items)
            if self.sel < 0 or self.sel >= n:
                return
            it = self.items[self.sel]
            if not isinstance(it, dict):
                return

            # A folder is selected -> open it instead of trying to download it.
            if "items" in it:
                self.path_stack.append(self.items)
                self.current_path.append(it)
                self.items = it["items"]
                self.sel = 0
                self.page = 0
                self.update_view()
                return

            url = it.get("file", "").strip()
            name = it.get("name", "package")

            if not url:
                self.session.open(MessageBox, "Download URL not found", MessageBox.TYPE_ERROR)
                return

            # System-image scripts live under /system_images/ and only download
            # an image to disk, while the other .sh files actually install something.
            self.is_image_download = "/system_images/" in url
            pure = url.split("?")[0]
            ext = ""
            if pure.endswith(".tar.gz"):
                ext = ".tar.gz"
            elif "." in pure.split("/")[-1]:
                ext = "." + pure.split(".")[-1].lower()

            if ext == ".ipk":
                dest = "/tmp/wordofenigma2.ipk"
                cmd = "opkg install --force-overwrite %s && rm -f %s" % (dest, dest)
            elif ext == ".deb":
                dest = "/tmp/wordofenigma2.deb"
                cmd = "dpkg -i %s && rm -f %s" % (dest, dest)
            elif ext == ".sh":
                dest = "/tmp/wordofenigma2.sh"
                cmd = "chmod +x %s && cd /tmp && sh %s 2>&1; rm -f %s" % (dest, dest, dest)
            elif ext == ".zip":
                dest = "/tmp/wordofenigma2.zip"
                cmd = "unzip -o %s -d / && rm -f %s" % (dest, dest)
            elif ext in (".tar.gz", ".tgz"):
                dest = "/tmp/wordofenigma2.tar.gz"
                cmd = "tar -xzf %s -C / && rm -f %s" % (dest, dest)
            else:
                dest = "/tmp/wordofenigma2.ipk"
                cmd = "opkg install --force-overwrite %s && rm -f %s" % (dest, dest)

            self.install_cmd = cmd
            self.install_item_name = name
            self.download_dest_path = dest

            self.set_description("Downloading: %s\n\nPlease wait..." % name)

            wget_cmd = "wget -q --no-check-certificate --timeout=60 --tries=3 -O %s '%s'" % (dest, url)
            self.wget_thread = threading.Thread(target=self.run_wget, args=(wget_cmd,))
            self.wget_thread.daemon = True
            self.wget_thread.start()
        except Exception as e:
            self.set_description("Error: " + str(e))

    def run_wget(self, wget_cmd):
        try:
            log_file = "/tmp/wordofenigma2_wget.log"
            full_cmd = wget_cmd + " > " + log_file + " 2>&1"
            retval = os.system(full_cmd)

            output = ""
            try:
                if os.path.exists(log_file):
                    with open(log_file, "r") as f:
                        output = f.read()
                    os.remove(log_file)
            except Exception:
                pass

            if not output:
                output = "wget returncode: " + str(retval)

            self.download_finished(output, retval)
        except Exception as e:
            self.download_finished("Exception: " + str(e), 1)

    def download_finished(self, result, retval, extra_args=None):
        def _ui():
            if retval != 0:
                err = result.strip() if result else "Unknown error"
                self.set_description("Download failed:\n\n" + err)
                self.session.open(MessageBox, "Download failed!\n\n%s" % err, MessageBox.TYPE_ERROR)
                return

            # .sh -> ask before running remote code on the box
            if self.download_dest_path.endswith(".sh"):
                if self.is_image_download:
                    prompt = "Downloaded: %s\n\nStart the image download now?" % self.install_item_name
                else:
                    prompt = ("Downloaded: %s\n\nRun this installer script now?\n"
                              "It will modify your system.") % self.install_item_name
                self.session.openWithCallback(
                    self.script_run_confirm,
                    MessageBox,
                    prompt,
                    MessageBox.TYPE_YESNO
                )
                return

            # Packages (.ipk, .deb, .zip, .tar.gz) -> ask to install
            self.session.openWithCallback(
                self.install_confirm,
                MessageBox,
                "Downloaded: %s\n\nInstall now?" % self.install_item_name,
                MessageBox.TYPE_YESNO
            )
        gui_call(_ui)

    def script_run_confirm(self, answer):
        if not answer:
            self.set_description("Skipped.")
            self.update_info()
            return
        # Run the script fully detached (setsid) so an Enigma2 restart inside
        # it (init 4; init 3) is not killed halfway, then show its live output
        # in the console until the box restarts.
        log_file = "/tmp/wordofenigma2_console.log"
        done_file = "/tmp/wordofenigma2_done"
        dest = self.download_dest_path
        cmd = ("rm -f %s %s; chmod +x %s; "
               "setsid sh -c 'sh %s > %s 2>&1 < /dev/null; echo done > %s' "
               "> /dev/null 2>&1 < /dev/null &"
               % (log_file, done_file, dest, dest, log_file, done_file))
        self.session.open(
            WordOfEnigma2Console,
            self.install_item_name,
            cmd,
            log_file,
            done_file,
            self.is_image_download
        )

    def install_confirm(self, answer):
        if answer:
            self.set_description("Installing...\n\nPlease wait, this may take a minute...")
            self.install_full_cmd = self.install_cmd + " 2>&1"
            t = threading.Thread(target=self.run_install)
            t.daemon = True
            t.start()
        else:
            self.set_description("Skipped.")
            self.update_info()

    def run_install(self):
        try:
            log_file = "/tmp/wordofenigma2_install.log"
            full_cmd = self.install_full_cmd + " > " + log_file + " 2>&1"
            retval = os.system(full_cmd)

            output = ""
            try:
                if os.path.exists(log_file):
                    with open(log_file, "r") as f:
                        output = f.read()
                    os.remove(log_file)
            except Exception:
                pass

            self.install_finished(output, retval)
        except Exception as e:
            self.install_finished("Exception: " + str(e), 1)

    def install_finished(self, result, retval, extra_args=None):
        def _ui():
            if retval == 0:
                self.session.openWithCallback(
                    self.restart_callback,
                    MessageBox,
                    "Installed successfully!\n\nRestart GUI now?",
                    MessageBox.TYPE_YESNO
                )
            else:
                self.set_description("Install failed:\n" + str(result))
        gui_call(_ui)


# =====================================================================
# INSTALLATION CONSOLE
# =====================================================================
class WordOfEnigma2Console(Screen):
    """Live console for an install/download script.

    The script runs fully detached (setsid) so an Enigma2 restart inside it
    (init 4; init 3) is not killed halfway. We stream its output by polling
    the log file, so the user sees the whole process until the box restarts.
    """
    skin = CONSOLE_SKIN
    VISIBLE_LINES = 27

    def __init__(self, session, title, cmd, log_file, done_file, is_image=False):
        Screen.__init__(self, session)
        self.setTitle(title or "Installation")
        self.cmd = cmd
        self.log_file = log_file
        self.done_file = done_file
        self.is_image = is_image
        self.all_lines = []
        self.view_end = 0
        self.finished = False
        self.last_raw = ""

        self["header"] = Label("INSTALLATION CONSOLE - %s" % (title or "Install"))
        self["status"] = Label("Running...")
        self["log"] = Label("")
        self["key_red"] = Label("Close")
        self["key_blue"] = Label("Restart GUI")

        self["actions"] = ActionMap(
            ["OkCancelActions", "DirectionActions", "ColorActions"],
            {
                "cancel": self.close,
                "red": self.close,
                "blue": self.restart_gui,
                "up": self.scroll_up,
                "down": self.scroll_down,
            },
            -1
        )

        self.timer = eTimer()
        try:
            self.timer.callback.append(self.poll)
        except AttributeError:
            try:
                self.timer.timeout.connect(self.poll)
            except Exception:
                pass

        self.onLayoutFinish.append(self.start)

    def start(self):
        try:
            os.system(self.cmd)
        except Exception as e:
            self["log"].setText("Error: " + str(e))
        try:
            if self.timer:
                self.timer.start(500)
        except Exception:
            pass

    def _read_log(self):
        try:
            if os.path.exists(self.log_file):
                size = os.path.getsize(self.log_file)
                with open(self.log_file, "rb") as f:
                    if size > 65536:
                        f.seek(size - 65536)
                    raw = f.read()
                return raw.decode("utf-8", "replace") if isinstance(raw, bytes) else raw
        except Exception:
            pass
        return ""

    def visible_count(self):
        return self.VISIBLE_LINES

    def scroll_up(self):
        if not self.all_lines:
            return
        self.view_end = max(self.visible_count(), self.view_end - 1)
        self.refresh()

    def scroll_down(self):
        self.view_end = min(len(self.all_lines), self.view_end + 1)
        self.refresh()

    def refresh(self):
        end = self.view_end if self.view_end > 0 else len(self.all_lines)
        start = max(0, end - self.visible_count())
        self["log"].setText("\n".join(self.all_lines[start:end]))

    def poll(self):
        raw = self._read_log()
        if raw != self.last_raw:
            self.last_raw = raw
            follow = (self.view_end >= len(self.all_lines))
            self.all_lines = raw.splitlines()
            if follow:
                self.view_end = len(self.all_lines)
            self.refresh()

        if not self.finished and self.done_file and os.path.exists(self.done_file):
            self.finished = True
            try:
                if self.timer:
                    self.timer.stop()
            except Exception:
                pass
            self.view_end = len(self.all_lines)
            self.refresh()
            self["status"].setText("Finished")
            self.finish()

    def finish(self):
        if self.is_image:
            self.session.openWithCallback(
                self.close,
                MessageBox,
                "Image download finished.\n\nSaved to /media/hdd/images (or /media/usb/images).\n"
                "Use Flash Online to install it.",
                MessageBox.TYPE_INFO
            )
        else:
            self.session.openWithCallback(
                self.restart_cb,
                MessageBox,
                "Installation finished.\n\nRestart Enigma2 now?",
                MessageBox.TYPE_YESNO
            )

    def restart_cb(self, answer):
        if answer:
            self.restart_gui()
        else:
            self.close()

    def restart_gui(self):
        try:
            if TryQuitMainloop:
                self.session.open(TryQuitMainloop, 3)
            else:
                os.system("killall -9 enigma2")
        except Exception:
            os.system("killall -9 enigma2")


# =====================================================================
# MENU POPUP (MENU key) - Information / Check for updates
# =====================================================================
class WordOfEnigma2Menu(Screen):
    skin = BATCH_MENU_SKIN

    def __init__(self, session, title, options):
        Screen.__init__(self, session)
        self.setTitle("Menu")
        self.options = options or []
        self["menuheader"] = Label(title or "Menu")
        self["list"] = MenuList([label for (label, _value) in self.options])
        self["actions"] = ActionMap(
            ["OkCancelActions"],
            {
                "ok": self.ok,
                "cancel": self.close,
            },
            -1
        )

    def ok(self):
        try:
            idx = self["list"].getSelectionIndex()
            if 0 <= idx < len(self.options):
                self.close(self.options[idx][1])
            else:
                self.close(None)
        except Exception:
            self.close(None)


# =====================================================================
# INFORMATION SCREEN (MENU -> Information)
# =====================================================================
class WordOfEnigma2Info(Screen):
    skin = INFO_SKIN

    def __init__(self, session):
        Screen.__init__(self, session)
        self.setTitle("Information")
        self.picload = None

        self["header"] = Label("Information")
        self["appname"] = Label("Word Of Enigma2")
        self["version"] = Label("Version: v" + PLUGIN_VERSION)
        self["author"] = Label("Author: " + PLUGIN_AUTHOR)
        self["note"] = Label("Universal plugins & skins store for Enigma2 boxes.\n"
                             "Scan the QR code to open our Facebook page.")
        self["qrcode"] = Pixmap()
        self["key_red"] = Label("Close")

        self["actions"] = ActionMap(
            ["OkCancelActions", "ColorActions"],
            {
                "ok": self.close,
                "cancel": self.close,
                "red": self.close,
            },
            -1
        )

        self.onLayoutFinish.append(self.show_qr)

    def _qr_log(self, msg):
        try:
            f = open("/tmp/wordofenigma2_qr.log", "a")
            f.write(msg + "\n")
            f.close()
        except Exception:
            pass

    def show_qr(self):
        """Render the QR image inside the qrcode Pixmap widget."""
        try:
            path = self._qr_source()
            exists = bool(path and os.path.exists(path))
            self._qr_log("show_qr source=%s exists=%s" % (path, exists))
            if not exists:
                return
            if self._show_qr_loadpixmap(path):
                self._qr_log("loaded via loadPixmap")
                return
            self._qr_log("builtin loaders failed -> ePicLoad")
            self._show_qr_picload(path)
        except Exception as e:
            self._qr_log("show_qr ERROR: " + str(e))

    def _show_qr_loadpixmap(self, path):
        """Load the QR pixmap using the most widely available APIs."""
        ptr = None
        method = ""
        # 1) Tools.LoadPixmap.LoadPixmap (OpenATV / OpenPLi / OpenViX)
        try:
            from Tools.LoadPixmap import LoadPixmap
            ptr = LoadPixmap(path)
            method = "LoadPixmap"
        except Exception:
            ptr = None
        # 2) legacy lowercase name on some images
        if ptr is None:
            try:
                from Tools.LoadPixmap import loadPixmap
                ptr = loadPixmap(path)
                method = "loadPixmap"
            except Exception:
                ptr = None
        # 3) direct enigma loader
        if ptr is None:
            try:
                from enigma import loadPNG
                ptr = loadPNG(path, 0, 1)
                method = "loadPNG"
            except Exception:
                ptr = None
        if ptr is not None:
            try:
                self["qrcode"].instance.setPixmap(ptr)
                self._qr_log("loaded via " + method)
                return True
            except Exception as e:
                self._qr_log("setPixmap error: " + str(e))
        return False

    def _show_qr_picload(self, path):
        """Fallback: decode through ePicLoad into the widget's size."""
        try:
            w = self["qrcode"].instance.size().width()
            h = self["qrcode"].instance.size().height()
        except Exception:
            w, h = 450, 450
        try:
            self.picload = ePicLoad()
            try:
                self.picload.PictureData.get().append(self._qr_picture)
            except Exception:
                pass
            try:
                # width, height, aspect_w, aspect_h, accel, background, bgcolor
                self.picload.setPara((w, h, w, h, False, 1, "#00000000"))
            except Exception:
                try:
                    self.picload.setPara((w, h, w, h, False, 0, "#00000000"))
                except Exception:
                    self._qr_last_resort(path)
                    return
            self.picload.startDecode(path)
            # if decoding was synchronous, apply straight away
            self._qr_picture()
        except Exception:
            self.picload = None
            self._qr_last_resort(path)

    def _qr_last_resort(self, path):
        # some builds expose setPixmapFromFile directly on ePixmap
        try:
            self["qrcode"].instance.setPixmapFromFile(path)
        except Exception:
            pass

    def _qr_picture(self, picInfo=None):
        """Attach the decoded pixmap to the qrcode widget (once ready)."""
        if self.picload is None:
            return
        ptr = None
        for meth in ("getPixmap", "getData"):
            try:
                ptr = getattr(self.picload, meth)()
            except Exception:
                ptr = None
            if ptr is not None:
                break
        if ptr is not None:
            try:
                self["qrcode"].instance.setPixmap(ptr)
            except Exception:
                pass

    def _qr_source(self):
        """Path to a usable QR image.

        Prefer the shipped images/qrcode.png. If it is missing, or is the
        1x1 placeholder (older installs never refreshed images), fall back
        to the copy embedded in this module so the QR always renders.
        """
        candidates = [os.path.join(PLUGIN_DIR, "images", "qrcode.png")]
        try:
            candidates.append(os.path.join(
                os.path.dirname(os.path.abspath(__file__)),
                "images", "qrcode.png"))
        except Exception:
            pass
        for path in candidates:
            try:
                if os.path.exists(path) and os.path.getsize(path) > 500:
                    return path
            except Exception:
                continue
        tmp = "/tmp/wordofenigma2_qrcode.png"
        try:
            import base64
            if not os.path.exists(tmp) or os.path.getsize(tmp) < 500:
                f = open(tmp, "wb")
                f.write(base64.b64decode(QR_FALLBACK_B64))
                f.close()
            if os.path.exists(tmp):
                return tmp
        except Exception:
            pass
        return None


# =====================================================================
# ENTRY POINT
# =====================================================================
def main(session, **kwargs):
    session.open(WordOfEnigma2)


def Plugins(**kwargs):
    return [
        PluginDescriptor(
            name="Word Of Enigma2",
            description="Plugins and Skins Store",
            where=PluginDescriptor.WHERE_PLUGINMENU,
            icon="plugin.png",
            fnc=main
        )
    ]