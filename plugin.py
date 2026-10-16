# -*- coding: utf-8 -*-
# =========================================================================
# AllStore - Universal Enigma2 Plugin
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
PLUGIN_VERSION = "1.0.15"
PLUGIN_AUTHOR = "Azrou Karim"
GITHUB_BASE = "https://raw.githubusercontent.com/azroukarim/OurStore/main"
STORE_URL = GITHUB_BASE + "/feed/index.json"
UPDATE_SCRIPT_URL = GITHUB_BASE + "/install.sh"

PLUGIN_DIR = "/usr/lib/enigma2/python/Plugins/Extensions/AllStore"
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
# --- AllStore: block per-item Enigma2 restarts until the batch is done ---
BLOCKDIR="/tmp/allstore_block"
rm -rf "$BLOCKDIR"; mkdir -p "$BLOCKDIR"
RKILLALL=$(command -v killall 2>/dev/null)
[ -z "$RKILLALL" ] && RKILLALL="busybox killall"
RSYSTEMCTL=$(command -v systemctl 2>/dev/null)
RSERVICE=$(command -v service 2>/dev/null)

for c in init reboot shutdown halt poweroff telinit; do
cat > "$BLOCKDIR/$c" <<'EOS'
#!/bin/sh
echo "AllStore: '$0' suppressed (batch in progress)"
exit 0
EOS
done

cat > "$BLOCKDIR/killall" <<EOS
#!/bin/sh
for a in "\$@"; do
  case "\$a" in
    *enigma2*) echo "AllStore: killall \$a suppressed (batch)"; exit 0;;
  esac
done
exec $RKILLALL "\$@"
EOS

if [ -n "$RSYSTEMCTL" ]; then
cat > "$BLOCKDIR/systemctl" <<EOS
#!/bin/sh
case "\$*" in
  *enigma2*) echo "AllStore: systemctl \$* suppressed (batch)"; exit 0;;
esac
exec $RSYSTEMCTL "\$@"
EOS
fi

if [ -n "$RSERVICE" ]; then
cat > "$BLOCKDIR/service" <<EOS
#!/bin/sh
case "\$*" in
  *enigma2*) echo "AllStore: service \$* suppressed (batch)"; exit 0;;
esac
exec $RSERVICE "\$@"
EOS
fi

chmod +x "$BLOCKDIR"/* 2>/dev/null
export PATH="$BLOCKDIR:$PATH"
export ALLSTORE_BATCH=1
echo "AllStore: Enigma2 restarts are disabled until the batch finishes."
echo ""
'''


def build_batch_script(items):
    """Build one shell script that installs all selected items in order.

    It is run fully detached (setsid) so an Enigma2 restart triggered by one
    installer cannot kill the rest of the batch. Per-item restarts are also
    actively suppressed (see BATCH_RESTART_BLOCKER) so only ONE restart is
    needed at the very end, after every item has been installed.
    """
    dest = "/tmp/allstore_batch_file"
    out = ["#!/bin/sh", "# AllStore batch installer", ""]
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
# SKIN
# =====================================================================
SKIN = """
<screen name="AllStore" position="0,0" size="1920,1080" title="AllStore" flags="wfNoBorder">
    <!-- Background -->
    <eLabel position="0,0" size="1920,1080" backgroundColor="#0B0F19" zPosition="-100" />

    <!-- Header -->
    <eLabel position="0,0" size="1920,110" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,110" size="1920,3" backgroundColor="#3b82f6" zPosition="-89" />

    <!-- Logo / Title -->
    <ePixmap position="40,30" size="200,50" pixmap="/usr/lib/enigma2/python/Plugins/Extensions/AllStore/images/logo.png" zPosition="2" scale="1" transparent="1" alphatest="blend" />
    <eLabel position="260,25" size="500,45" text="ALLSTORE" font="Regular;40" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <widget name="version" position="260,75" size="150,26" font="Regular;22" foregroundColor="#3b82f6" backgroundColor="#131A2A" transparent="1" zPosition="2" />

    <!-- Header Right -->
    <eLabel position="1520,35" size="360,50" text="Plugin Store" font="Regular;30" foregroundColor="#8b5cf6" backgroundColor="#131A2A" transparent="1" halign="right" zPosition="2" />

    <!-- LEFT PANEL: Categories -->
    <eLabel position="30,140" size="500,850" backgroundColor="#131A2A" zPosition="-50" />
    <eLabel position="30,140" size="500,4" backgroundColor="#3b82f6" zPosition="-49" />
    <eLabel position="50,160" size="460,40" text="CATEGORIES" font="Regular;32" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <eLabel position="50,205" size="460,2" backgroundColor="#1A2235" zPosition="-48" />
    <widget name="categories_list" position="40,225" size="480,750" itemHeight="100" font="Regular;34" scrollbarMode="showOnDemand" foregroundColor="#d1d5db" backgroundColor="#131A2A" transparent="1" zPosition="2" />

    <!-- CENTER PANEL: Items -->
    <eLabel position="550,140" size="880,850" backgroundColor="#131A2A" zPosition="-50" />
    <eLabel position="550,140" size="880,4" backgroundColor="#10b981" zPosition="-49" />
    <eLabel position="570,160" size="840,40" text="AVAILABLE PACKAGES" font="Regular;32" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <eLabel position="570,205" size="840,2" backgroundColor="#1A2235" zPosition="-48" />
    <widget name="items_list" position="560,225" size="860,750" itemHeight="100" font="Regular;34" scrollbarMode="showOnDemand" foregroundColor="#d1d5db" backgroundColor="#131A2A" transparent="1" zPosition="2" />

    <!-- RIGHT PANEL: Info -->
    <eLabel position="1450,140" size="440,850" backgroundColor="#131A2A" zPosition="-50" />
    <eLabel position="1450,140" size="440,4" backgroundColor="#8b5cf6" zPosition="-49" />
    <eLabel position="1470,160" size="400,40" text="INFORMATION" font="Regular;32" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <eLabel position="1470,205" size="400,2" backgroundColor="#1A2235" zPosition="-48" />
    <widget name="description" position="1470,225" size="420,750" font="Regular;30" foregroundColor="#9ca3af" backgroundColor="#131A2A" transparent="1" valign="top" zPosition="2" />

    <!-- Footer Buttons -->
    <eLabel position="0,1010" size="1920,70" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,1010" size="1920,2" backgroundColor="#1A2235" zPosition="-89" />

    <widget name="key_red"    position="30,1020"  size="300,50" font="Regular;28" foregroundColor="#ffffff" backgroundColor="#e11d48" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_green"  position="340,1020" size="300,50" font="Regular;28" foregroundColor="#ffffff" backgroundColor="#059669" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_yellow" position="650,1020" size="300,50" font="Regular;28" foregroundColor="#ffffff" backgroundColor="#d97706" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_blue"   position="960,1020" size="480,50" font="Regular;28" foregroundColor="#ffffff" backgroundColor="#0284c7" transparent="0" halign="center" valign="center" zPosition="3" />
    <eLabel position="1450,1020" size="440,50" text="OK: select    MENU: info / details / update" font="Regular;26" foregroundColor="#8b5cf6" backgroundColor="#131A2A" transparent="1" halign="right" valign="center" zPosition="3" />
</screen>
"""


# =====================================================================
# CONSOLE SKIN
# =====================================================================
CONSOLE_SKIN = """
<screen name="AllStoreConsole" position="0,0" size="1920,1080" title="Installation Console" flags="wfNoBorder">
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
<screen name="AllStoreMenu" position="center,center" size="820,600" title="Menu" flags="wfNoBorder">
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
<screen name="AllStoreInfo" position="center,center" size="1000,580" title="Information" flags="wfNoBorder">
    <eLabel position="0,0" size="1000,580" backgroundColor="#0B0F19" zPosition="-100" />
    <eLabel position="0,0" size="1000,80" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,80" size="1000,3" backgroundColor="#8b5cf6" zPosition="-89" />
    <widget name="header" position="30,20" size="940,50" font="Regular;34" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />

    <widget name="appname" position="40,130" size="600,60" font="Regular;42" foregroundColor="#8b5cf6" backgroundColor="#0B0F19" transparent="1" zPosition="2" />
    <widget name="version" position="40,205" size="600,46" font="Regular;32" foregroundColor="#e5e7eb" backgroundColor="#0B0F19" transparent="1" zPosition="2" />
    <widget name="author" position="40,260" size="600,46" font="Regular;32" foregroundColor="#e5e7eb" backgroundColor="#0B0F19" transparent="1" zPosition="2" />
    <widget name="note" position="40,325" size="590,110" font="Regular;24" foregroundColor="#9ca3af" backgroundColor="#0B0F19" transparent="1" zPosition="2" />

    <eLabel position="664,124" size="292,292" backgroundColor="#ffffff" zPosition="0" />
    <widget name="qrcode" position="670,130" size="280,280" zPosition="2" />
    <widget name="qrlabel" position="664,425" size="292,44" font="Regular;26" foregroundColor="#9ca3af" backgroundColor="#0B0F19" transparent="1" halign="center" zPosition="2" />

    <eLabel position="0,500" size="1000,80" backgroundColor="#131A2A" zPosition="-90" />
    <widget name="key_red" position="40,520" size="260,44" font="Regular;30" foregroundColor="#ef4444" backgroundColor="#131A2A" transparent="1" zPosition="2" />
</screen>
"""


# =====================================================================
# MAIN SCREEN
# =====================================================================
class AllStore(Screen):
    skin = SKIN

    def __init__(self, session):
        Screen.__init__(self, session)
        self.setTitle("AllStore")

        self["categories_list"] = MenuList([])
        self["items_list"] = MenuList([])
        self["description"] = Label("Loading...")
        self["version"] = Label("v" + PLUGIN_VERSION)

        # Enlarge fonts for lists
        try:
            from enigma import gFont
            if self["categories_list"].l:
                self["categories_list"].l.setFont(0, gFont("Regular", 34))
            if self["items_list"].l:
                self["items_list"].l.setFont(0, gFont("Regular", 34))
        except Exception:
            pass

        self["key_red"] = Label("Exit")
        self["key_green"] = Label("Install")
        self["key_yellow"] = Label("Refresh")
        self["key_blue"] = Label("Batch Install")

        self["actions"] = ActionMap(
            ["OkCancelActions", "DirectionActions", "ColorActions", "MenuActions"],
            {
                "cancel": self.close,
                "red": self.close,
                "green": self.download_item,
                "yellow": self.load_store,
                "blue": self.blue_pressed,
                "menu": self.main_menu,
                "ok": self.ok_pressed,
                "up": self.go_up,
                "down": self.go_down,
                "left": self.go_left,
                "right": self.go_right,
            },
            -1
        )

        self.store_data = {}
        self.categories = []
        self.visible_items = []
        self.current_path = []
        self.path_stack = []
        self.active_focus = "categories"
        self.my_console = Console()
        self.install_cmd = ""
        self.install_item_name = ""
        self.is_image_download = False
        self.download_dest_path = ""
        self.update_in_progress = False
        self.selected = []

        self["categories_list"].onSelectionChanged.append(self.category_changed)
        self["items_list"].onSelectionChanged.append(self.item_changed)

        self.load_local_cache()

        self.bg_timer = eTimer()
        try:
            self.bg_timer.callback.append(self.start_network_fetch)
        except AttributeError:
            try:
                self.bg_timer.timeout.connect(self.start_network_fetch)
            except Exception:
                pass
        self.onLayoutFinish.append(self.schedule_fetch)

    # -----------------------------------------------------------------
    def schedule_fetch(self):
        if self.bg_timer:
            self.bg_timer.start(200, True)

    def start_network_fetch(self):
        t = threading.Thread(target=self.async_fetch)
        t.daemon = True
        t.start()

    def set_description(self, text):
        try:
            self["description"].setText(text)
        except Exception:
            pass

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
        elif self.categories:
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
            local_file = "/usr/lib/enigma2/python/Plugins/Extensions/AllStore/version.json"
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
                "TS=$(date +%%s)\n"
                "rm -f allstore_dl.py allstore_dl.png allstore_dl.json allstore_dl_feed.json\n"
                'echo "Downloading plugin.py..."\n'
                'wget -q --no-check-certificate "%s/plugin.py?t=$TS" -O allstore_dl.py || exit 2\n'
                'echo "Downloading plugin.png..."\n'
                'wget -q --no-check-certificate "%s/plugin.png?t=$TS" -O allstore_dl.png || exit 3\n'
                'echo "Downloading version.json..."\n'
                'wget -q --no-check-certificate "%s/version.json?t=$TS" -O allstore_dl.json || exit 4\n'
                'echo "Downloading feed/index.json..."\n'
                'wget -q --no-check-certificate "%s/feed/index.json?t=$TS" -O allstore_dl_feed.json || exit 5\n'
                'echo "Installing to %s ..."\n'
                'mkdir -p "%s/feed" || exit 6\n'
                'cp allstore_dl.py "%s/plugin.py" || exit 7\n'
                'cp allstore_dl.png "%s/plugin.png" || exit 8\n'
                'cp allstore_dl.json "%s/version.json" || exit 9\n'
                'cp allstore_dl_feed.json "%s/feed/index.json" || exit 10\n'
                'rm -f "%s/plugin.pyc" "%s/store_cache.json"\n'
                'rm -rf "%s/__pycache__"\n'
                'rm -f allstore_dl.py allstore_dl.png allstore_dl.json allstore_dl_feed.json\n'
                'echo "DONE. Installed version.json:"\n'
                'cat "%s/version.json"\n'
            ) % (base, base, base, base, PLUGIN_DIR,
                 PLUGIN_DIR, PLUGIN_DIR, PLUGIN_DIR, PLUGIN_DIR, PLUGIN_DIR,
                 PLUGIN_DIR, PLUGIN_DIR, PLUGIN_DIR, PLUGIN_DIR)
            script_path = "/tmp/allstore_update.sh"
            log_file = "/tmp/allstore_update.log"
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
    def apply_store_data(self, data):
        try:
            name = data.get("store_name", "AllStore")
            ver = data.get("version", PLUGIN_VERSION)
            self.setTitle("%s v%s" % (name, ver))

            self.store_data = data.get("categories", {})
            if isinstance(self.store_data, dict):
                self.categories = list(self.store_data.keys())
            else:
                self.categories = []

            display = []
            for cat in self.categories:
                items = self.store_data.get(cat, [])
                count = count_items(items)
                clean = cat.replace("_", " ").title()
                display.append("%s (%d)" % (clean, count))

            self["categories_list"].setList(display)
            self.current_path = []
            self.path_stack = []
            self.category_changed()
        except Exception as e:
            self["description"].setText("Error: " + str(e))

    # -----------------------------------------------------------------
    def category_changed(self):
        try:
            idx = self["categories_list"].getSelectionIndex()
            if idx < 0 or idx >= len(self.categories):
                return
            cat = self.categories[idx]
            self.visible_items = self.store_data.get(cat, [])
            self.current_path = []
            self.path_stack = []
            self.update_items()
        except Exception:
            pass

    def update_items(self):
        try:
            display = []
            for item in self.visible_items:
                if isinstance(item, dict) and "items" in item:
                    count = count_items(item["items"])
                    display.append("[+] %s (%d)" % (item.get("name", "?"), count))
                else:
                    name = item.get("name", "?")
                    if self.is_selected(item):
                        name = "[x] " + name
                    display.append(name)
            self["items_list"].setList(display)
            self.update_blue_label()
            self.item_changed()
        except Exception:
            pass

    def item_changed(self):
        try:
            idx = self["items_list"].getSelectionIndex()
            if idx < 0 or idx >= len(self.visible_items):
                return
            item = self.visible_items[idx]
            if "items" in item:
                self["description"].setText(
                    "Folder: %s\nItems: %d\n\nPress OK to open."
                    % (item.get("name", ""), count_items(item["items"]))
                )
            else:
                txt = ("Name: %s\n\nDescription:\n%s"
                       % (item.get("name", ""), item.get("description", "No description")))
                if self.is_selected(item):
                    txt += ("\n\n[SELECTED] for batch install"
                            "\nOK: deselect")
                elif self.is_selectable(item):
                    txt += ("\n\nOK: select for batch install"
                            "\nBLUE: install all selected")
                self["description"].setText(txt)
        except Exception:
            pass

    # -----------------------------------------------------------------
    def ok_pressed(self):
        if self.active_focus == "categories":
            self.active_focus = "items"
            return
        idx = self["items_list"].getSelectionIndex()
        if 0 <= idx < len(self.visible_items):
            item = self.visible_items[idx]
            if "items" in item:
                self.current_path.append(item)
                self.path_stack.append(self.visible_items)
                self.visible_items = item["items"]
                self.update_items()
            else:
                # OK on a plugin item marks it for the batch install
                self.toggle_select()

    def go_up(self):
        try:
            if self.active_focus == "categories":
                self["categories_list"].up()
            else:
                self["items_list"].up()
        except Exception:
            pass

    def go_down(self):
        try:
            if self.active_focus == "categories":
                self["categories_list"].down()
            else:
                self["items_list"].down()
        except Exception:
            pass

    def go_left(self):
        # Inside a sub-folder: go one level up. Otherwise jump to categories.
        if self.active_focus == "items" and self.path_stack:
            self.visible_items = self.path_stack.pop()
            if self.current_path:
                self.current_path.pop()
            self.update_items()
        else:
            self.active_focus = "categories"

    def go_right(self):
        if self.visible_items:
            self.active_focus = "items"

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
            if self.active_focus != "items":
                return
            idx = self["items_list"].getSelectionIndex()
            if idx < 0 or idx >= len(self.visible_items):
                return
            item = self.visible_items[idx]
            if not self.is_selectable(item):
                self.set_description("Folders and system images cannot be\n"
                                     "added to a batch install.")
                return
            if self.is_selected(item):
                url = item.get("file", "")
                self.selected = [s for s in self.selected if s.get("file") != url]
            else:
                self.selected.append(item)
            self.update_items()
        except Exception:
            pass

    # --- MENU popup: Information + Check for updates -------------------
    def main_menu(self):
        """MENU: small menu with Information, item details and panel update."""
        try:
            options = [
                ("Information", "info"),
                ("Item details", "item"),
                ("Check for updates", "update"),
            ]
            self.session.openWithCallback(
                self.main_menu_done,
                AllStoreMenu,
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
                self.session.open(AllStoreInfo)
            except Exception:
                pass
        elif choice == "item":
            self.show_info_popup()
        elif choice == "update":
            self.self_update()

    def show_info_popup(self):
        """Show full details of the highlighted item."""
        try:
            idx = self["items_list"].getSelectionIndex()
            if idx < 0 or idx >= len(self.visible_items):
                return
            item = self.visible_items[idx]
            name = item.get("name", "?")
            if "items" in item:
                msg = "Folder: %s\n\nItems: %d" % (name, count_items(item["items"]))
            else:
                msg = "Name: %s\n\nDescription:\n%s" % (
                    name, item.get("description", "No description"))
                url = (item.get("file") or "").strip()
                if url:
                    msg += "\n\nSource:\n" + url
                if self.is_selected(item):
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
            self.set_description("No items selected.\n\n"
                                 "Use OK on the plugins you want, then press\n"
                                 "the blue button to install them all.")

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
            self.item_changed()
            return
        items = list(self.selected)
        script = build_batch_script(items)
        script_path = "/tmp/allstore_batch.sh"
        log_file = "/tmp/allstore_console.log"
        done_file = "/tmp/allstore_done"
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
            AllStoreConsole,
            "Batch Install (%d items)" % len(items),
            cmd,
            log_file,
            done_file,
            False
        )

    def batch_finished(self, *args):
        self.selected = []
        self.update_items()

    # -----------------------------------------------------------------
    def download_item(self):
        try:

            idx = self["items_list"].getSelectionIndex()
            if idx < 0 or idx >= len(self.visible_items):
                return
            item = self.visible_items[idx]
            if not isinstance(item, dict):
                return

            # A folder is selected -> open it instead of trying to download it.
            if "items" in item:
                self.current_path.append(item)
                self.path_stack.append(self.visible_items)
                self.visible_items = item["items"]
                self.update_items()
                return

            url = item.get("file", "").strip()
            name = item.get("name", "package")


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
                dest = "/tmp/allstore.ipk"
                cmd = "opkg install --force-overwrite %s && rm -f %s" % (dest, dest)
            elif ext == ".deb":
                dest = "/tmp/allstore.deb"
                cmd = "dpkg -i %s && rm -f %s" % (dest, dest)
            elif ext == ".sh":
                dest = "/tmp/allstore.sh"
                cmd = "chmod +x %s && cd /tmp && sh %s 2>&1; rm -f %s" % (dest, dest, dest)
            elif ext == ".zip":
                dest = "/tmp/allstore.zip"
                cmd = "unzip -o %s -d / && rm -f %s" % (dest, dest)
            elif ext in (".tar.gz", ".tgz"):
                dest = "/tmp/allstore.tar.gz"
                cmd = "tar -xzf %s -C / && rm -f %s" % (dest, dest)
            else:
                dest = "/tmp/allstore.ipk"
                cmd = "opkg install --force-overwrite %s && rm -f %s" % (dest, dest)

            self.install_cmd = cmd
            self.install_item_name = name
            self.download_dest_path = dest

            self["description"].setText("Downloading: %s\n\nPlease wait..." % name)

            wget_cmd = "wget -q --no-check-certificate --timeout=60 --tries=3 -O %s '%s'" % (dest, url)
            self.wget_thread = threading.Thread(target=self.run_wget, args=(wget_cmd,))
            self.wget_thread.daemon = True
            self.wget_thread.start()
        except Exception as e:
            self["description"].setText("Error: " + str(e))

    def run_wget(self, wget_cmd):
        try:
            log_file = "/tmp/allstore_wget.log"
            full_cmd = wget_cmd + " > " + log_file + " 2>&1"
            retval = os.system(full_cmd)
            
            # قراءة اللوغ
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
            self.item_changed()
            return
        # Run the script fully detached (setsid) so an Enigma2 restart inside
        # it (init 4; init 3) is not killed halfway, then show its live output
        # in the console until the box restarts.
        log_file = "/tmp/allstore_console.log"
        done_file = "/tmp/allstore_done"
        dest = self.download_dest_path
        cmd = ("rm -f %s %s; chmod +x %s; "
               "setsid sh -c 'sh %s > %s 2>&1 < /dev/null; echo done > %s' "
               "> /dev/null 2>&1 < /dev/null &"
               % (log_file, done_file, dest, dest, log_file, done_file))
        self.session.open(
            AllStoreConsole,
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
            self.item_changed()

    def run_install(self):
        try:
            log_file = "/tmp/allstore_install.log"
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
class AllStoreConsole(Screen):
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
class AllStoreMenu(Screen):
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
class AllStoreInfo(Screen):
    skin = INFO_SKIN

    def __init__(self, session):
        Screen.__init__(self, session)
        self.setTitle("Information")
        self.picload = None

        self["header"] = Label("Information")
        self["appname"] = Label("AllStore")
        self["version"] = Label("Version: v" + PLUGIN_VERSION)
        self["author"] = Label("Author: " + PLUGIN_AUTHOR)
        self["note"] = Label("Universal plugins & skins store for Enigma2 boxes.\n"
                             "Scan the QR code to open the Facebook page.")
        self["qrcode"] = Pixmap()
        self["qrlabel"] = Label("Facebook page")
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

    def show_qr(self):
        """Render images/qrcode.png inside the qrcode Pixmap widget."""
        if ePicLoad is None:
            return
        path = os.path.join(PLUGIN_DIR, "images", "qrcode.png")
        if not os.path.exists(path):
            try:
                path = os.path.join(
                    os.path.dirname(os.path.abspath(__file__)),
                    "images", "qrcode.png")
            except Exception:
                return
        if not os.path.exists(path):
            return
        try:
            w = self["qrcode"].instance.size().width()
            h = self["qrcode"].instance.size().height()
        except Exception:
            w, h = 280, 280
        try:
            self.picload = ePicLoad()
            try:
                # width, height, aspect_w, aspect_h, stretch, background, bgcolor
                self.picload.setPara((w, h, w, h, False, 0, "#00FFFFFF"))
            except Exception:
                self.picload.setPara((w, h))
            if self.picload.startDecode(path) == 0:
                pixmap = self.picload.getPixmap()
                if pixmap:
                    self["qrcode"].instance.setPixmap(pixmap)
        except Exception:
            self.picload = None


# =====================================================================
# ENTRY POINT
# =====================================================================
def main(session, **kwargs):
    session.open(AllStore)


def Plugins(**kwargs):
    return [
        PluginDescriptor(
            name="AllStore",
            description="Plugins and Skins Store",
            where=PluginDescriptor.WHERE_PLUGINMENU,
            icon="plugin.png",
            fnc=main
        )
    ]