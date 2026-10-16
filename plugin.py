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


# =====================================================================
# CONFIG
# =====================================================================
PLUGIN_VERSION = "1.0.6"
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

    <widget name="key_red"    position="40,1020"  size="440,50" font="Regular;28" foregroundColor="#ffffff" backgroundColor="#e11d48" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_green"  position="500,1020" size="440,50" font="Regular;28" foregroundColor="#ffffff" backgroundColor="#059669" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_yellow" position="960,1020" size="440,50" font="Regular;28" foregroundColor="#ffffff" backgroundColor="#d97706" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_blue"   position="1420,1020" size="460,50" font="Regular;28" foregroundColor="#ffffff" backgroundColor="#0284c7" transparent="0" halign="center" valign="center" zPosition="3" />
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
    <eLabel position="40,25" size="1300,45" text="INSTALLATION CONSOLE" font="Regular;34" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
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
        self["key_blue"] = Label("Update Plugin")

        self["actions"] = ActionMap(
            ["OkCancelActions", "DirectionActions", "ColorActions"],
            {
                "cancel": self.close,
                "red": self.close,
                "green": self.download_item,
                "yellow": self.load_store,
                "blue": self.self_update,
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
        data = load_json_network(STORE_URL)
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
    # SELF UPDATE - Blue button
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

            remote_data = load_json_network(GITHUB_BASE + "/version.json")
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
            cmd = (
                'cd /tmp && '
                'wget -q --no-check-certificate "' + GITHUB_BASE + '/plugin.py" -O plugin.py && '
                'wget -q --no-check-certificate "' + GITHUB_BASE + '/plugin.png" -O plugin.png && '
                'wget -q --no-check-certificate "' + GITHUB_BASE + '/version.json" -O version.json && '
                'wget -q --no-check-certificate "' + GITHUB_BASE + '/feed/index.json" -O feed_index.json && '
                'cp plugin.py ' + PLUGIN_DIR + '/plugin.py && '
                'cp plugin.png ' + PLUGIN_DIR + '/plugin.png && '
                'cp version.json ' + PLUGIN_DIR + '/version.json && '
                'mkdir -p ' + PLUGIN_DIR + '/feed && '
                'cp feed_index.json ' + PLUGIN_DIR + '/feed/index.json && '
                'rm -f plugin.py plugin.png version.json feed_index.json ' + PLUGIN_DIR + '/store_cache.json ' + PLUGIN_DIR + '/plugin.pyc && '
                'rm -rf ' + PLUGIN_DIR + '/__pycache__'
            )
            self.my_console.ePopen(cmd + " 2>&1", self.update_done)
        except Exception as e:
            self.update_in_progress = False
            gui_call(self.set_description, "Update error: " + str(e))

    def update_done(self, result, retval, extra_args=None):
        def _ui():
            self.update_in_progress = False
            if retval == 0:
                self.session.openWithCallback(
                    self.restart_callback,
                    MessageBox,
                    "Plugin updated successfully!\n\nRestart Enigma2 now?",
                    MessageBox.TYPE_YESNO
                )
            else:
                err = result.strip() if result else "Unknown error"
                self.set_description("Update failed:\n" + err)
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
                    display.append(item.get("name", "?"))
            self["items_list"].setList(display)
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
                self["description"].setText(
                    "Name: %s\n\nDescription:\n%s"
                    % (item.get("name", ""), item.get("description", "No description"))
                )
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
                self.download_item()

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