#!/bin/sh
# OpenViX Image Downloader
# Downloads the latest OpenViX image for this box

echo "=========================================="
echo "  OpenViX Image Downloader"
echo "=========================================="
echo ""

# ---- Detect box ----
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

# ---- Detect storage ----
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

# ---- Fetch page ----
# OpenViX uses a direct page for each box model
PAGE_URL="https://www.openvix.co.uk/index.php/downloads/vu-plus-images/vu-${BOXTYPE}/"
echo "Fetching: $PAGE_URL"
TMP="/tmp/vix_page.html"

wget -q --no-check-certificate -O "$TMP" "$PAGE_URL" 2>/dev/null

if [ ! -s "$TMP" ]; then
    echo "ERROR: Cannot fetch page"
    echo ""
    echo "Please visit manually:"
    echo "  https://www.openvix.co.uk/index.php/downloads/"
    exit 1
fi

echo "Page fetched ($(wc -c < $TMP) bytes)"
echo ""

# ---- Find latest image ----
# Pattern: openvix-6.9.xxx.release-vuduo4kse_usb.zip
FILENAME=$(grep -oE "openvix-[0-9.]+[a-z-]*${BOXTYPE}_usb\.zip" "$TMP" | sort -V | tail -n 1)

if [ -z "$FILENAME" ]; then
    # Try broader pattern
    FILENAME=$(grep -oE "openvix-[0-9.]+[a-z-]*${BOXTYPE}\.zip" "$TMP" | sort -V | tail -n 1)
fi

if [ -z "$FILENAME" ]; then
    echo "ERROR: No image found for $BOXTYPE"
    echo ""
    echo "Files in page:"
    grep -oE "[a-zA-Z0-9_.-]+\.zip" "$TMP" | sort -u | head -n 10
    exit 1
fi

echo "Latest image: $FILENAME"
echo ""

# ---- Build URL and download ----
# Try direct URL from the page first
DL_URL=$(grep -oE "href=\"[^\"]*${FILENAME}\"" "$TMP" | head -n 1 | sed 's/href="//;s/"//')

if [ -z "$DL_URL" ]; then
    # Fallback: construct URL
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