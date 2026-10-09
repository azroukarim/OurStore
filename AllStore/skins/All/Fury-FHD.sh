#!/bin/sh
# Fury FHD Skin Installer
# Source: islam-2412/IPKS

opkg update
opkg install wget
wget --no-check-certificate "https://raw.githubusercontent.com/islam-2412/IPKS/refs/heads/main/fury/installer.sh" -O - | /bin/sh