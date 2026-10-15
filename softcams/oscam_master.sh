#!/bin/sh
###############################################################
#  oscam_master.sh - AllStore Panel
#  Install & Control OSCam Master from Mynonpublic Feed
###############################################################

BINARY="/usr/bin/oscam-master"
CONFIG_DIR="/etc/tuxbox/config/oscam-master"
PIDFILE="/var/run/oscam-master.pid"
LOGFILE="/var/log/oscam-master.log"
EMUNAME="oscam-master"

install_oscam_master() {
    echo ">>> Installing OSCam Master from Mynonpublic feed..."

    # 1) Add the secret feed for this box
    wget -qO- --no-check-certificate "http://updates.mynonpublic.com/oea/feed" | bash

    # 2) Update package lists
    echo ">>> opkg update"
    opkg update

    # 3) Install oscam-master
    echo ">>> opkg install oscam-master"
    opkg install oscam-master

    # 4) Install libdvbcsa1 (required dependency)
    echo ">>> opkg install libdvbcsa1"
    opkg install libdvbcsa1

    # Make sure config dir exists
    [ -d "$CONFIG_DIR" ] || mkdir -p "$CONFIG_DIR"

    echo ">>> OSCam Master installation finished."
}

case "$1" in
    install|"")
        install_oscam_master
        ;;
    start)
        if [ ! -x "$BINARY" ]; then
            echo "oscam-master binary not found, installing..."
            install_oscam_master
        fi
        if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
            echo "oscam-master already running"
            exit 0
        fi
        echo "Starting oscam-master..."
        start-stop-daemon --start --background --make-pidfile \
            --pidfile "$PIDFILE" \
            --exec "$BINARY" -- -c "$CONFIG_DIR" -b
        ;;
    stop)
        echo "Stopping oscam-master..."
        start-stop-daemon --stop --pidfile "$PIDFILE" --retry 5
        rm -f "$PIDFILE"
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
            echo "oscam-master is running (PID: $(cat $PIDFILE))"
        else
            echo "oscam-master is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {install|start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0