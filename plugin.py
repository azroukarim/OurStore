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

try:
    from Components.ProgressBar import ProgressBar
except ImportError:
    ProgressBar = None


# =====================================================================
# CONFIG
# =====================================================================
PLUGIN_VERSION = "1.0.0"
STORE_URL = "https://raw.githubusercontent.com/azroukarim/OurStore/main/feed/index.json"
UPDATE_SCRIPT_URL = "https://raw.githubusercontent.com/azroukarim/OurStore/main/install.sh"

try:
    PLUGIN_DIR = os.path.dirname(__file__)
except NameError:
    PLUGIN_DIR = "/usr/lib/enigma2/python/Plugins/Extensions/AllStore"

CACHE_FILE = os.path.join(PLUGIN_DIR, "store_cache.json")
ICON_FOLDER = os.path.join(PLUGIN_DIR, "images", "Icons")


# =====================================================================
# HELPERS
# =====================================================================
def load_json_network(url):
    """Load JSON from network"""
    try:
        if sys.version_info >= (3, 0):
            import urllib.request as urllib2
            import ssl
            context = ssl._create_unverified_context()
        else:
            import urllib2
            import ssl
            try:
                context = ssl._create_unverified_context()
            except AttributeError:
                context = None

        req = urllib2.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        if context:
            response = urllib2.urlopen(req, timeout=10, context=context)
        else:
            response = urllib2.urlopen(req, timeout=10)
        data = response.read()
        if isinstance(data, bytes):
            data = data.decode('utf-8')
        return json.loads(data)
    except Exception:
        return None


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
<screen name="AllStore" position="center,center" size="1280,720" title="AllStore" flags="wfNoBorder">
    <eLabel position="0,0" size="1280,720" backgroundColor="#0B0F19" zPosition="-11" />
    <eLabel position="0,0" size="1280,70" backgroundColor="#131A2A" zPosition="-10" />
    <eLabel position="0,70" size="1280,2" backgroundColor="#3b82f6" zPosition="-9" />
    <eLabel position="20,15" size="300,40" text="ALLSTORE" font="Regular;32" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <eLabel position="20,40" size="100,20" text="v1.0.0" font="Regular;16" foregroundColor="#3b82f6" backgroundColor="#131A2A" transparent="1" zPosition="2" />

    <eLabel position="20,90" size="350,560" backgroundColor="#131A2A" zPosition="-1" />
    <eLabel position="20,90" size="350,3" backgroundColor="#3b82f6" zPosition="0" />
    <eLabel position="35,100" size="330,30" text="CATEGORIES" font="Regular;22" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" />
    <widget name="categories_list" position="30,140" size="330,500" itemHeight="50" scrollbarMode="showOnDemand" foregroundColor="#d1d5db" backgroundColor="#131A2A" transparent="1" />

    <eLabel position="390,90" size="550,560" backgroundColor="#131A2A" zPosition="-1" />
    <eLabel position="390,90" size="550,3" backgroundColor="#10b981" zPosition="0" />
    <eLabel position="405,100" size="530,30" text="PACKAGES" font="Regular;22" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" />
    <widget name="items_list" position="400,140" size="530,500" itemHeight="50" scrollbarMode="showOnDemand" foregroundColor="#d1d5db" backgroundColor="#131A2A" transparent="1" />

    <eLabel position="960,90" size="300,560" backgroundColor="#131A2A" zPosition="-1" />
    <eLabel position="960,90" size="300,3" backgroundColor="#8b5cf6" zPosition="0" />
    <eLabel position="975,100" size="280,30" text="INFO" font="Regular;22" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" />
    <widget name="description" position="975,140" size="280,400" font="Regular;18" foregroundColor="#9ca3af" backgroundColor="#131A2A" transparent="1" valign="top" />

    <eLabel position="0,660" size="1280,60" backgroundColor="#131A2A" zPosition="-10" />
    <widget name="key_red"    position="30,670"  size="280,40" font="Regular;20" foregroundColor="#ffffff" backgroundColor="#e11d48" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_green"  position="330,670" size="280,40" font="Regular;20" foregroundColor="#ffffff" backgroundColor="#059669" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_yellow" position="630,670" size="280,40" font="Regular;20" foregroundColor="#ffffff" backgroundColor="#d97706" transparent="0" halign="center" valign="center" zPosition="3" />
    <widget name="key_blue"   position="930,670" size="280,40" font="Regular;20" foregroundColor="#ffffff" backgroundColor="#0284c7" transparent="0" halign="center" valign="center" zPosition="3" />
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

        self["key_red"] = Label("Exit")
        self["key_green"] = Label("Install")
        self["key_yellow"] = Label("Refresh")
        self["key_blue"] = Label("Refresh Store")

        self["actions"] = ActionMap(
            ["OkCancelActions", "DirectionActions", "ColorActions"],
            {
                "cancel": self.close,
                "red": self.close,
                "green": self.download_item,
                "yellow": self.load_store,
                "blue": self.load_store,
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
        self.active_focus = "categories"
        self.my_console = Console()
        self.install_cmd = ""
        self.install_item_name = ""

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

    def async_fetch(self):
        data = load_json_network(STORE_URL)
        if data and "categories" in data:
            self.apply_store_data(data)
            try:
                with open(CACHE_FILE, "w") as f:
                    json.dump(data, f)
            except Exception:
                pass
        elif not self.categories:
            self["description"].setText("Failed to connect to server.")

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
        self["description"].setText("Refreshing...")
        t = threading.Thread(target=self.async_fetch)
        t.daemon = True
        t.start()

    # -----------------------------------------------------------------
    def apply_store_data(self, data):
        try:
            name = data.get("store_name", "AllStore")
            ver = data.get("version", "1.0.0")
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
            url = item.get("file", "").strip()
            name = item.get("name", "package")

            if not url:
                self.session.open(MessageBox, "Download URL not found", MessageBox.TYPE_ERROR)
                return

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
                cmd = "chmod +x %s && %s && rm -f %s" % (dest, dest, dest)
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

            self["description"].setText("Downloading: %s\n\nPlease wait..." % name)

            wget_cmd = "wget -q -O %s '%s'" % (dest, url)
            self.my_console.ePopen(wget_cmd + " 2>&1", self.download_finished)
        except Exception as e:
            self["description"].setText("Error: " + str(e))

    def download_finished(self, result, retval, extra_args=None):
        if retval != 0:
            self["description"].setText("Download failed.")
            return
        self.session.openWithCallback(
            self.install_confirm,
            MessageBox,
            "Downloaded: %s\n\nInstall now?" % self.install_item_name,
            MessageBox.TYPE_YESNO
        )

    def install_confirm(self, answer):
        if answer:
            self["description"].setText("Installing...")
            self.my_console.ePopen(self.install_cmd + " 2>&1", self.install_finished)
        else:
            self["description"].setText("Skipped.")
            self.item_changed()

    def install_finished(self, result, retval, extra_args=None):
        if retval == 0:
            self.session.openWithCallback(
                self.restart_callback,
                MessageBox,
                "Installed successfully!\n\nRestart GUI now?",
                MessageBox.TYPE_YESNO
            )
        else:
            self["description"].setText("Install failed:\n" + str(result))

    def restart_callback(self, answer):
        if answer and TryQuitMainloop:
            self.session.open(TryQuitMainloop, 3)


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