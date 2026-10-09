#!/bin/sh
# OpenViX Image Downloader - VERSION 6.7

echo "=========================================="
echo "  OpenViX 6.7 - Image Downloader"
echo "=========================================="
echo ""

# Detect box
if [ -f /proc/stb/info/boxtype ]; then
    BOXTYPE=$(cat /proc/stb/info/boxtype | tr 'A-Z' 'a-z')
elif [ -f /proc/stb/info/vumodel ]; then
    BOXTYPE="vu$(cat /proc/stb/info/vumodel | tr 'A-Z' 'a-z')"
elif [ -f /proc/stb/info/model ]; then
    BOXTYPE=$(cat /proc/stb/info/model | tr 'A-Z' 'a-z')
else
    echo "ERROR: Cannot detect box"
    exit 1
fi

echo "Detected box: $BOXTYPE"
echo ""

# Detect storage
if [ -d /media/hdd ] && [ -w /media/hdd ]; then
    TARGET="/media/hdd/images"
elif [ -d /media/usb ] && [ -w /media/usb ]; then
    TARGET="/media/usb/images"
else
    echo "ERROR: No writable storage"
    exit 1
fi

mkdir -p "$TARGET"
echo "Target: $TARGET"
echo ""

# Detect box name for OpenViX page
case "$BOXTYPE" in
    vuduo4kse) BOXNAME="vu-duo-4k-se" ;;
    vuduo4k) BOXNAME="vu-duo-4k" ;;
    vuuno4kse) BOXNAME="vu-uno-4k-se" ;;
    vuuno4k) BOXNAME="vu-uno-4k" ;;
    vuultimo4k) BOXNAME="vu-ultimo-4k" ;;
    vusolo4k) BOXNAME="vu-solo-4k" ;;
    vuzero4k) BOXNAME="vu-zero-4k" ;;
    *) BOXNAME="$BOXTYPE" ;;
esac

# Fetch page
URL="https://www.openvix.co.uk/index.php/downloads/vu-plus-images/$BOXNAME/"
echo "Fetching: $URL"
TMP="/tmp/vix_page.html"

wget -q --no-check-certificate -O "$TMP" "$URL" 2>/dev/null

if [ ! -s "$TMP" ]; then
    echo "ERROR: Cannot fetch page"
    exit 1
fi

echo "Page fetched ($(wc -c < $TMP) bytes)"
echo ""

# Find latest sub-version for this version
FILENAME=$(grep -oE "openvix-6.7\.[0-9]+\.release-${BOXTYPE}_usb\.zip" "$TMP" | sort -V | tail -n 1)

if [ -z "$FILENAME" ]; then
    echo "ERROR: No image found for OpenViX 6.7"
    echo ""
    echo "Available versions:"
    grep -oE "openvix-[0-9.]+[a-z.-]*-${BOXTYPE}[^\"']*\.zip" "$TMP" | head -n 10
    exit 1
fi

echo "Latest: $FILENAME"
echo ""

# Build URL
DL_URL=$(grep -oE "href=\"[^\"]*${FILENAME}\"" "$TMP" | head -n 1 | sed 's/href="//;s/"$//')

if [ -z "$DL_URL" ]; then
    DL_URL="https://www.openvix.co.uk/openvix-builds/$FILENAME"
fi

DEST="$TARGET/$FILENAME"

echo "Downloading..."
echo "  From: $DL_URL"
echo "  To:   $DEST"
echo ""

wget --no-check-certificate --timeout=600 -O "$DEST" "$DL_URL"

if [ $? -eq 0 ] && [ -s "$DEST" ]; then
    SIZE=$(ls -lh "$DEST" | awk '{print $5}')
    echo ""
    echo "=========================================="
    echo "  DOWNLOAD COMPLETE"
    echo "  File: $DEST"
    echo "  Size: $SIZE"
    echo "=========================================="
else
    echo "ERROR: Download failed"
fi

rm -f "$TMP"