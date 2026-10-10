#!/bin/sh
# XStreamity Installer
# Waits for opkg to complete before exiting

echo "=========================================="
echo "  XStreamity Installer"
echo "=========================================="
echo ""

# Download installer
echo "Downloading installer..."
wget -q --no-check-certificate "https://raw.githubusercontent.com/biko-73/xstreamity/main/installer.sh" -O /tmp/xstreamity-installer.sh

if [ ! -s /tmp/xstreamity-installer.sh ]; then
    echo "ERROR: Failed to download installer"
    exit 1
fi

# Run installer
echo "Running installer..."
chmod +x /tmp/xstreamity-installer.sh
sh /tmp/xstreamity-installer.sh

# Wait for opkg to finish (max 5 minutes)
echo ""
echo "Waiting for installation to complete..."
COUNT=0
while [ $COUNT -lt 150 ]; do
    if ! pgrep opkg >/dev/null 2>&1; then
        break
    fi
    sleep 2
    COUNT=$((COUNT + 1))
done

# Verify installation
echo ""
if opkg list-installed 2>/dev/null | grep -q xstreamity; then
    echo "=========================================="
    echo "  XStreamity installed successfully!"
    echo "=========================================="
    echo ""
    echo "Restarting Enigma2..."
    sleep 2
    killall -9 enigma2
    exit 0
else
    echo "=========================================="
    echo "  WARNING: Installation may not be complete"
    echo "=========================================="
    echo ""
    echo "Please check manually:"
    echo "  opkg list-installed | grep xstreamity"
    exit 0
fi