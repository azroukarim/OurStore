#!/bin/sh
# SubsSupport Pro Installer - Fully detached
# Source: popking159/SubsSupportPro

cat > /tmp/subs_install.sh << 'EOF'
#!/bin/sh
wget -qO - https://raw.githubusercontent.com/popking159/SubsSupportPro/refs/heads/main/myinstaller.sh | /bin/sh
echo "=== INSTALLATION COMPLETE ===" >> /tmp/subssupport_install.log
EOF

chmod +x /tmp/subs_install.sh

# Run fully detached with setsid
setsid /tmp/subs_install.sh > /tmp/subssupport_install.log 2>&1 < /dev/null &

echo "SubsSupport Pro installation started in background"
echo "Check /tmp/subssupport_install.log for progress"
exit 0