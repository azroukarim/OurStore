#!/bin/sh
# OpenATV Image Downloader
# Downloads the latest OpenATV image for this box

VER="7.5.1"
BASE="https://images.mynonpublic.com/openatv"

echo "=========================================="
echo "  OpenATV $VER - Image Downloader"
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
    echo "ERROR: Cannot detect box type"
        exit 1
fi

echo "Detected box: $BOXTYPE"

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
echo "Fetching image list..."
PAGE_URL="$BASE/index.php?v=$VER&open=$BOXTYPE"
TMP="/tmp/atv_page.html"

wget -q --no-check-certificate -O "$TMP" "$PAGE_URL" 2>/dev/null

if [ ! -s "$TMP" ]; then
    echo "ERROR: Cannot fetch page"
        exit 1
fi

echo "Page fetched ($(wc -c < $TMP) bytes)"
echo ""

# ---- Extract latest image ----
FILENAME=$(grep -oE "openatv-[0-9.]+-${BOXTYPE}-[0-9]+_usb\.zip" "$TMP" | sort -r | head -1)

if [ -z "$FILENAME" ]; then
    echo "ERROR: No image found for $BOXTYPE"
    echo ""
    echo "Files found in page:"
    grep -oE "[a-zA-Z0-9_.-]+\.zip" "$TMP" | sort -u | head -10
    rm -f "$TMP"
        exit 1
fi

echo "Latest image: $FILENAME"
echo ""

# ---- Build URL ----
URL="$BASE/$VER/$BOXTYPE/$FILENAME"
DEST="$TARGET/$FILENAME"

echo "Downloading..."
echo "  From: $URL"
echo "  To:   $DEST"
echo ""
echo "This may take 10-30 minutes. Please wait..."
echo ""

wget --no-check-certificate --timeout=600 -O "$DEST" "$URL"

if [ $? -eq 0 ] && [ -s "$DEST" ]; then
    SIZE=$(ls -lh "$DEST" | awk '{print $5}')
    echo ""
    echo "=========================================="
    echo "  DOWNLOAD COMPLETE"
    echo "=========================================="
    echo "  File: $DEST"
    echo "  Size: $SIZE"
    echo ""
    echo "  Use Flash Online to install it,"
    echo "  or reboot into recovery mode."
    echo "=========================================="
else
    echo "ERROR: Download failed"
fi

rm -f "$TMP"
echo ""
