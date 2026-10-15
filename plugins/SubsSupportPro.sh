#!/bin/sh
# SubsSupport Pro Installer - Fully Detached
# Source: popking159/SubsSupportPro

cat > /tmp/subs_install.sh << 'EOF'
#!/bin/sh
wget -qO - https://raw.githubusercontent.com/popking159/SubsSupportPro/refs/heads/main/myinstaller.sh | /bin/sh
echo "=== INSTALLATION COMPLETE ==="
EOF

chmod +x /tmp/subs_install.sh

# Run fully detached with setsid (survives Enigma2 restart)
setsid /tmp/subs_install.sh > /tmp/subssupport_install.log 2>&1 < /dev/null &

# Return immediately
sleep 1
echo "SubsSupport Pro installation started in background"
exit 0