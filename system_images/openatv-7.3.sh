#!/bin/sh
# OpenATV 7.3 Image Downloader
VER="7.3"

echo "=========================================="
echo "  Downloading OpenATV 7.3$VER"
echo "=========================================="
echo ""

# ---- Detect box ----
if [ -f /proc/stb/info/boxtype ]; then
    BOXTYPE=$(cat /proc/stb/info/boxtype | tr 'A-Z' 'a-z')
elif [ -f /proc/stb/info/model ]; then
    BOXTYPE=$(cat /proc/stb/info/model | tr 'A-Z' 'a-z')
elif [ -f /proc/stb/info/vumodel ]; then
    BOXTYPE="vu$(cat /proc/stb/info/vumodel)"
else
    BOXTYPE="unknown"
fi

echo "Detected box: $BOXTYPE"

# ---- Detect storage ----
if [ -d /media/hdd ] && [ -w /media/hdd ]; then
    TARGET="/media/hdd/images"
elif [ -d /media/usb ] && [ -w /media/usb ]; then
    TARGET="/media/usb/images"
else
    echo "ERROR: No writable storage found at /media/hdd or /media/usb"
    read -p "Press Enter to return..."
    exit 1
fi

mkdir -p "$TARGET"
echo "Target: $TARGET"
echo ""

# ---- Fetch list ----
URL="https://images.mynonpublic.com/openatv/$VER/json/openatv-$VER.json"
TMP="/tmp/openatv_$VER.json"

echo "Fetching image list..."
wget -q --no-check-certificate -O "$TMP" "$URL" 2>/dev/null

if [ ! -s "$TMP" ]; then
    echo "ERROR: Could not fetch image list"
    read -p "Press Enter..."
    exit 1
fi

echo "OK ($(wc -c < $TMP) bytes)"
echo ""

# ---- Find image URL ----
IMAGE_URL=$(grep -o "\"$BOXTYPE\":{[^}]*}" "$TMP" | grep -o '"url":"[^"]*"' | head -1 | sed 's/"url":"//;s/"//')

if [ -z "$IMAGE_URL" ]; then
    echo "ERROR: No image found for '$BOXTYPE' in OpenATV 7.3$VER"
    echo ""
    echo "Available boxes:"
    grep -o '"[a-z0-9]*":{"url"' "$TMP" | head -30 | sed 's/:{"url"//;s/"//g' | sed 's/^/  - /'
    read -p "Press Enter..."
    rm -f "$TMP"
    exit 1
fi

echo "Found: $IMAGE_URL"
echo ""

# ---- Download ----
FILENAME=$(basename "$IMAGE_URL")
DEST="$TARGET/$FILENAME"

echo "Downloading to: $DEST"
echo "This may take several minutes..."
echo ""

wget --no-check-certificate --timeout=300 -O "$DEST" "$IMAGE_URL"

if [ $? -eq 0 ] && [ -s "$DEST" ]; then
    SIZE=$(ls -lh "$DEST" | awk '{print $5}')
    echo ""
    echo "=========================================="
    echo "  Download complete!"
    echo "=========================================="
    echo "  File: $DEST"
    echo "  Size: $SIZE"
    echo "=========================================="
else
    echo "ERROR: Download failed"
fi

rm -f "$TMP"
echo ""
read -p "Press Enter to return..."