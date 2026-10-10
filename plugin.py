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
PLUGIN_VERSION = "1.0.0"
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
<screen name="AllStore" position="0,0" size="1920,1080" title="AllStore" flags="wfNoBorder">
    <!-- Background -->
    <eLabel position="0,0" size="1920,1080" backgroundColor="#0B0F19" zPosition="-100" />

    <!-- Header -->
    <eLabel position="0,0" size="1920,110" backgroundColor="#131A2A" zPosition="-90" />
    <eLabel position="0,110" size="1920,3" backgroundColor="#3b82f6" zPosition="-89" />

    <!-- Logo / Title -->
    <ePixmap position="40,30" size="200,50" pixmap="/usr/lib/enigma2/python/Plugins/Extensions/AllStore/images/logo.png" zPosition="2" scale="1" transparent="1" alphatest="blend" />
    <eLabel position="260,25" size="500,45" text="ALLSTORE" font="Regular;40" foregroundColor="#ffffff" backgroundColor="#131A2A" transparent="1" zPosition="2" />
    <eLabel position="260,75" size="150,26" text="v1.0.0" font="Regular;22" foregroundColor="#3b82f6" backgroundColor="#131A2A" transparent="1" zPosition="2" />

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
        self.active_focus = "categories"
        self.my_console = Console()
        self.install_cmd = ""
        self.install_item_name = ""
        self.download_dest_path = ""
        self.script_exec_cmd = ""
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
            # Fallback: read local feed/index.json
            try:
                local_feed = os.path.join(PLUGIN_DIR, "feed", "index.json")
                if os.path.exists(local_feed):
                    with open(local_feed, "r") as f:
                        local_data = json.load(f)
                    if local_data and "categories" in local_data:
                        self.apply_store_data(local_data)
                        self["description"].setText("Loaded from local feed.")
                        return
            except Exception:
                pass
            self["description"].setText("Failed to connect to server.")

    def confirm_system_image(self, answer):
        if not answer:
            self["description"].setText("Download cancelled.")
            return
        try:
            idx = self["items_list"].getSelectionIndex()
            if idx < 0 or idx >= len(self.visible_items):
                return
            item = self.visible_items[idx]
            url = item.get("file", "").strip()
            name = item.get("name", "package")
            if not url:
                self.session.open(MessageBox, "URL not found", MessageBox.TYPE_ERROR)
                return
            dest = "/tmp/allstore.sh"
            cmd = "chmod +x %s && cd /tmp && sh %s 2>&1; rm -f %s" % (dest, dest, dest)
            self.install_cmd = cmd
            self.install_item_name = name
            self.download_dest_path = dest
            self["description"].setText("Downloading: %s\n\nPlease wait..." % name)
            wget_cmd = "wget -L --no-check-certificate --timeout=60 --tries=3 --user-agent='Mozilla/5.0' -O %s '%s'" % (dest, url)
            self.wget_thread = threading.Thread(target=self.run_wget, args=(wget_cmd,))
            self.wget_thread.daemon = True
            self.wget_thread.start()
        except Exception as e:
            self["description"].setText("Error: " + str(e))
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
                self.show_update_dialog(msg)
            elif self.version_newer(local_ver, remote_ver):
                msg = "Local version is newer (dev build)\n\nLocal: %s\nGitHub: %s" % (local_ver, remote_ver)
                self.show_update_dialog(msg, info_only=True)
            else:
                msg = "You are using the latest version\n\nVersion: %s" % local_ver
                self.show_update_dialog(msg, info_only=True)
        except Exception as e:
            self.update_in_progress = False
            self["description"].setText("Check error: " + str(e))

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
        def _apply():
            if info_only:
                self.session.open(MessageBox, msg, MessageBox.TYPE_INFO)
            else:
                self.session.openWithCallback(
                    self.confirm_update,
                    MessageBox,
                    msg,
                    MessageBox.TYPE_YESNO
                )
        try:
            from twisted.internet import reactor
            reactor.callFromThread(_apply)
        except Exception:
            _apply()
        try:
            from twisted.internet import reactor
            reactor.callFromThread(_apply)
        except Exception:
            _apply()

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
                'rm -f plugin.py plugin.png version.json feed_index.json ' + PLUGIN_DIR + '/store_cache.json'
            )
            self.my_console.ePopen(cmd + " 2>&1", self.update_done)
        except Exception as e:
            self["description"].setText("Update error: " + str(e))
            self.update_in_progress = False

    def update_done(self, result, retval, extra_args=None):
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
            self["description"].setText("Update failed:\n" + err)

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

            # System image confirmation
            cat_idx = self["categories_list"].getSelectionIndex()
            if cat_idx >= 0:
                cat_name = str(self.categories[cat_idx]).lower()
                if "system" in cat_name or "image" in cat_name:
                    idx = self["items_list"].getSelectionIndex()
                    if idx >= 0 and idx < len(self.visible_items):
                        item = self.visible_items[idx]
                        nm = item.get("name", "")
                        self.session.openWithCallback(
                            self.confirm_system_image,
                            MessageBox,
                            "Download System Image\n\n%s\n\nSaved to: /media/hdd/images/\n\nThis may take 10-30 minutes.\n\nContinue?" % nm,
                            MessageBox.TYPE_YESNO
                        )
                    return


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
            
            # Ù‚Ø±Ø§Ø¡Ø© Ø§Ù„Ù„ÙˆØº
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
        if retval != 0:
            err = result.strip() if result else "Unknown error"
            self["description"].setText("Download failed:\n\n" + err)
            self.session.open(MessageBox, "Download failed!\n\n%s" % err, MessageBox.TYPE_ERROR)
            return

        # If we downloaded a .sh script â†’ execute it!
        if ".sh" in self.download_dest_path:
            self["description"].setText("Executing script...\n\nThis may take 10-30 minutes.\nPlease wait...")
            # Execute the script in background
            exec_cmd = "chmod +x %s && cd /tmp && sh %s" % (self.download_dest_path, self.download_dest_path)
            self.script_exec_cmd = exec_cmd
            t = threading.Thread(target=self.run_script_exec)
            t.daemon = True
            t.start()
            return

        # For packages (.ipk, .deb, .zip, .tar.gz) â†’ show install prompt
        self.session.openWithCallback(
            self.install_confirm,
            MessageBox,
            "Downloaded: %s\n\nInstall now?" % self.install_item_name,
            MessageBox.TYPE_YESNO
        )

    def run_script_exec(self):
        try:
            log_file = "/tmp/allstore_script.log"
            
            # Build the command as a simple shell script
            shell_script = "/tmp/allstore_run.sh"
            try:
                with open(shell_script, "w") as f:
                    f.write("#!/bin/sh\n")
                    f.write("cd /tmp\n")
                    f.write(self.script_exec_cmd + "\n")
                os.system("chmod +x " + shell_script)
            except Exception as e:
                self.script_exec_done("Cannot create script: " + str(e), 1)
                return
            
            # Run it with output redirected (foreground, but in thread)
            full_cmd = "sh " + shell_script + " > " + log_file + " 2>&1"
            retval = os.system(full_cmd)
            
            output = ""
            try:
                if os.path.exists(log_file):
                    with open(log_file, "r") as f:
                        output = f.read()
            except Exception:
                pass
            
            # Cleanup
            try:
                if os.path.exists(shell_script):
                    os.remove(shell_script)
            except Exception:
                pass
            try:
                if os.path.exists(self.download_dest_path):
                    os.remove(self.download_dest_path)
            except Exception:
                pass
            
            # Deliver result on UI thread
            def _deliver():
                try:
                    self.script_exec_done(output, retval)
                except Exception:
                    pass
            
            try:
                from twisted.internet import reactor
                reactor.callFromThread(_deliver)
            except Exception:
                _deliver()
        except Exception as e:
            def _deliver_err():
                try:
                    self.script_exec_done("Exception: " + str(e), 1)
                except Exception:
                    pass
            try:
                from twisted.internet import reactor
                reactor.callFromThread(_deliver_err)
            except Exception:
                _deliver_err()

    def script_exec_done(self, result, retval):
        try:
            # Get last 20 lines of output
            lines = result.strip().split("\n") if result else []
            tail = "\n".join(lines[-20:]) if lines else "No output"
            
            if retval == 0:
                msg = "%s\n\nDownload completed successfully!\n\nThe image has been saved to /media/hdd/images or /media/usb/images.\n\nUse Flash Online to install it." % self.install_item_name
                self.session.open(MessageBox, msg, MessageBox.TYPE_INFO)
            else:
                msg = "%s\n\nScript finished with code: %d\n\nLast output:\n%s" % (self.install_item_name, retval, tail)
                self.session.open(MessageBox, msg, MessageBox.TYPE_WARNING)
            
            self["description"].setText("%s\n\nDone. Check /media/hdd/images/" % self.install_item_name)
            self.item_changed()
        except Exception as e:
            self["description"].setText("Error: " + str(e))

    def install_confirm(self, answer):
        if answer:
            self["description"].setText("Installing...\n\nPlease wait, this may take a minute...")
            
            # ÙƒØªØ§Ø¨Ø© Ø§Ù„Ø£Ù…Ø± Ø¥Ù„Ù‰ Ù…Ù„Ù Ø³ÙƒØ±Ø¨Øª Ù…Ø¤Ù‚Øª
            if self.install_cmd and "allstore.sh" in self.install_cmd:
                # Ø§Ø³ØªØ®Ø±Ø§Ø¬ Ù…Ø³Ø§Ø± Ø§Ù„Ø³ÙƒØ±Ø¨Øª Ù…Ù† Ø§Ù„Ø£Ù…Ø±
                wrapper = "/tmp/allstore_run.sh"
                with open(wrapper, "w") as f:
                    f.write("#!/bin/sh\n")
                    f.write("cd /tmp\n")
                    f.write("sh /tmp/allstore.sh </dev/null\n")
                os.system("chmod +x " + wrapper)
                
                # Ø§Ù„ØªÙ†ÙÙŠØ° Ø¨Ø§Ø³ØªØ®Ø¯Ø§Ù… sh Ù…Ø¹ session Ø¬Ø¯ÙŠØ¯
                full_cmd = "/bin/sh " + wrapper + " 2>&1"
            else:
                full_cmd = self.install_cmd + " 2>&1"
            
            self.install_full_cmd = full_cmd
            t = threading.Thread(target=self.run_install)
            t.daemon = True
            t.start()
        else:
            self["description"].setText("Skipped.")
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
            
            # Ù†Ù†Ø¸Ù Ø£ÙŠ wrapper
            try:
                if os.path.exists("/tmp/allstore_run.sh"):
                    os.remove("/tmp/allstore_run.sh")
            except Exception:
                pass
            
            self.install_finished(output, retval)
        except Exception as e:
            self.install_finished("Exception: " + str(e), 1)

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
