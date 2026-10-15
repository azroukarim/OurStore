#!/bin/sh
# ============================================
# Ncam EMU - Safe Installer (No Enigma2 restart, no auto-start)
# Fixes the "device stuck / freeze" problem on Vu+ boxes.
#
# Why this is different from the vendor installer:
#   The biko-73 installer ends with "init 4; sleep 4; init 3", i.e. it
#   restarts Enigma2 from inside the plugin process. When Enigma2 stops,
#   the process group (including that installer) is killed before "init 3"
#   runs, so Enigma2 never comes back -> the box looks frozen (exit code 15
#   = SIGTERM). Here we install the package directly and never restart
#   Enigma2; we also disable auto-start.
# ============================================

echo ""
echo "************************************************************"
echo "**            Ncam EMU - Safe Install Mode                **"
echo "************************************************************"
echo ""

# 1. Stop any running Ncam
echo ">> [1/6] Stopping any running Ncam..."
killall -9 ncam 2>/dev/null
sleep 1

# 2. Remove old packages
echo ">> [2/6] Removing old packages..."
opkg remove enigma2-plugin-softcams-ncam 2>/dev/null
opkg remove enigma2-softcams-ncam 2>/dev/null

# 3. Clean leftovers
echo ">> [3/6] Cleaning old files..."
rm -rf /etc/tuxbox/config/ncam
rm -f /etc/tuxbox/config/ncam.*
rm -f /etc/init.d/*ncam* /etc/init.d/*Ncam*
rm -f /usr/bin/*ncam* /usr/bin/*Ncam*

# 4. Download the package directly (no vendor installer -> no restart)
echo ">> [4/6] Downloading Ncam package..."
IPK="https://raw.githubusercontent.com/biko-73/Ncam_EMU/main/enigma2-plugin-softcams-ncam_V15.8-r0_all.ipk"
DEB="https://raw.githubusercontent.com/biko-73/Ncam_EMU/main/enigma2-plugin-softcams-ncam-osdreambox_V15.8-r0.deb"
if which dpkg >/dev/null 2>&1; then
    URL="$DEB"
    FILE="/tmp/ncam.deb"
else
    URL="$IPK"
    FILE="/tmp/ncam.ipk"
fi

rm -f "$FILE"
wget -T 60 --no-check-certificate "$URL" -O "$FILE" 2>/dev/null

if [ ! -s "$FILE" ]; then
    echo "!! Download failed. Check your internet connection."
    exit 1
fi

# 5. Install WITHOUT restarting Enigma2
echo ">> [5/6] Installing Ncam (Enigma2 will NOT be restarted)..."
if which dpkg >/dev/null 2>&1; then
    dpkg -i "$FILE"
else
    opkg install --force-overwrite "$FILE"
fi
rm -f "$FILE"

# Disable auto-start (this is what prevents the freeze)
chmod -x /etc/init.d/*ncam* 2>/dev/null
chmod -x /etc/init.d/*Ncam* 2>/dev/null
rm -f /etc/rc*.d/*ncam* /etc/rc*.d/*Ncam* 2>/dev/null
mv /etc/init.d/ncam /etc/init.d/ncam.disabled 2>/dev/null
mv /etc/init.d/Ncam /etc/init.d/Ncam.disabled 2>/dev/null
killall -9 ncam 2>/dev/null

# 6. Create default configs
echo ">> [6/6] Creating default configs..."
mkdir -p /etc/tuxbox/config/ncam

cat > /etc/tuxbox/config/ncam/ncam.conf << 'EOF'
[global]
nice = -1
logfile = /tmp/ncam.log
pidfile = /tmp/ncam.pid
EOF

cat > /etc/tuxbox/config/ncam/ncam.server << 'EOF'
# Ncam Server Configuration
EOF

cat > /etc/tuxbox/config/ncam/ncam.user << 'EOF'
# Ncam User Configuration
EOF

cat > /etc/tuxbox/config/ncam/ncam.services << 'EOF'
# Ncam Services
EOF

cp -n /etc/tuxbox/config/ncam/ncam.* /etc/tuxbox/config/ 2>/dev/null

echo ""
echo "************************************************************"
echo "**              INSTALLATION COMPLETED!                   **"
echo "**                                                        **"
echo "**  Ncam is installed but auto-start is DISABLED.         **"
echo "**  This prevents the freeze on restart.                  **"
echo "**                                                        **"
echo "**  You can now restart Enigma2 safely.                   **"
echo "************************************************************"
echo ""
sleep 2

exit 0
