#!/bin/sh
# SubsSupport Pro Installer - Background
# Source: popking159/SubsSupportPro

# Run the installer in the background, detached from Enigma2
nohup sh -c '
wget -qO - https://raw.githubusercontent.com/popking159/SubsSupportPro/refs/heads/main/myinstaller.sh | /bin/sh
' > /tmp/subssupport_install.log 2>&1 &

# Give it a moment to start
sleep 2

# Signal that it started
echo "SubsSupport Pro installation started in background"
echo "Check /tmp/subssupport_install.log for progress"
exit 0