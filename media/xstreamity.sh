#!/bin/sh
# XStreamity Installer - Background execution
# Source: biko-73/xstreamity

# Run everything in background, detached from Enigma2
nohup sh -c '
wget -q --no-check-certificate "https://raw.githubusercontent.com/biko-73/xstreamity/main/installer.sh" -O /tmp/xstreamity-installer.sh
chmod +x /tmp/xstreamity-installer.sh
sh /tmp/xstreamity-installer.sh
' > /tmp/xstreamity.log 2>&1 &

# Exit immediately - installation continues in background
exit 0