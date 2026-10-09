#!/bin/sh
# OpenATV Image Downloader - v8.0
# Downloads the latest OpenATV image for this box

VER="8.0"
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
    read -p "Press Enter..."
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
    read -p "Press Enter..."
    exit 1
fi

mkdir -p "$TARGET"
echo "Target: $TARGET"
echo ""

# ---- Fetch page (CORRECT URL with index.php) ----
echo "Fetching image list from OpenATV..."
PAGE_URL="$BASE/index.php?v=$VER&open=$BOXTYPE"
echo "URL: $PAGE_URL"
TMP="/tmp/atv_page.html"

wget -q --no-check-certificate -O "$TMP" "$PAGE_URL" 2>/dev/null

if [ ! -s "$TMP" ]; then
    echo "ERROR: Cannot fetch page"
    echo "Trying alternate URL..."
    PAGE_URL="$BASE/$VER/$BOXTYPE/"
    wget -q --no-check-certificate -O "$TMP" "$PAGE_URL" 2>/dev/null
fi

if [ ! -s "$TMP" ]; then
    echo "ERROR: Cannot fetch page from either URL"
    read -p "Press Enter..."
    exit 1
fi

echo "Page fetched ($(wc -c < $TMP) bytes)"
echo ""

# ---- Extract latest image filename ----
# Look for various patterns
FILENAME=$(grep -oE "openatv-${VER}-${BOXTYPE}-[0-9]+_usb\.zip" "$TMP" | sort -r | head -1)

if [ -z "$FILENAME" ]; then
    FILENAME=$(grep -oE "openatv-${VER}-${BOXTYPE}-[0-9]+_mmc\.zip" "$TMP" | sort -r | head -1)
fi

if [ -z "$FILENAME" ]; then
    FILENAME=$(grep -oE "openatv-[0-9.]+-${BOXTYPE}-[0-9]+_usb\.zip" "$TMP" | sort -r | head -1)
fi

if [ -z "$FILENAME" ]; then
    FILENAME=$(grep -oE "openatv-[0-9.]+-${BOXTYPE}-[0-9]+_mmc\.zip" "$TMP" | sort -r | head -1)
fi

if [ -z "$FILENAME" ]; then
    echo "ERROR: No image found for $BOXTYPE in OpenATV $VER"
    echo ""
    echo "Looking for .zip files in page:"
    grep -oE "[a-zA-Z0-9_.-]+\.zip" "$TMP" | head -10
    echo ""
    echo "Page preview (first 50 lines):"
    head -50 "$TMP"
    rm -f "$TMP"
    read -p "Press Enter..."
    exit 1
fi

echo "Latest image: $FILENAME"
echo ""

# ---- Build download URL ----
URL="$BASE/$VER/$BOXTYPE/$FILENAME"

# Try with index.php path first
if ! wget --spider --no-check-certificate "$URL" 2>/dev/null; then
    # Try alternate URL structure
    URL="$BASE/$VER/$BOXTYPE/$FILENAME"
fi

DEST="$TARGET/$FILENAME"

echo "Downloading..."
echo "  From: $URL"
echo "  To:   $DEST"
echo ""
echo "This may take 10-30 minutes..."
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
    echo "  Use Flash Online to install it."
    echo "=========================================="
else
    echo "ERROR: Download failed"
fi

rm -f "$TMP"
echo ""
read -p "Press Enter to return..."