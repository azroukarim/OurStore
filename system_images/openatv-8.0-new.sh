#!/bin/sh
# OpenATV Image Downloader with Confirmation
# VERSION: 8.0

echo "=========================================="
echo "  OpenATV 8.0 - Image Downloader"
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
echo ""

# ---- Detect storage ----
if [ -d /media/hdd ] && [ -w /media/hdd ]; then
    TARGET="/media/hdd/images"
elif [ -d /media/usb ] && [ -w /media/usb ]; then
    TARGET="/media/usb/images"
else
    echo "ERROR: No writable storage at /media/hdd or /media/usb"
    exit 1
fi

mkdir -p "$TARGET"
echo "Target: $TARGET"
echo ""

# ---- Fetch page ----
VER="8.0"
BASE="https://images.mynonpublic.com/openatv"

echo "Fetching image list from OpenATV..."
PAGE_URL="$BASE/index.php?v=$VER&open=$BOXTYPE"
TMP="/tmp/atv_page.html"

wget -q --no-check-certificate -O "$TMP" "$PAGE_URL" 2>/dev/null

if [ ! -s "$TMP" ]; then
    echo "ERROR: Cannot fetch page from OpenATV server"
    echo ""
    echo "Possible reasons:"
    echo "  - No internet connection"
    echo "  - OpenATV server is down"
    echo "  - Device '$BOXTYPE' is not supported"
    echo ""
    echo "Please verify manually:"
    echo "  https://images.mynonpublic.com/openatv/"
    exit 1
fi

echo "Page fetched ($(wc -c < $TMP) bytes)"
echo ""

# ---- Verify device support (C) ----
echo "Verifying device support..."
if ! grep -q "$BOXTYPE" "$TMP"; then
    echo "ERROR: Device '$BOXTYPE' is NOT supported by OpenATV $VER"
    echo ""
    echo "Devices mentioned in page (first 20):"
    grep -oE 'data-id="[^"]*"' "$TMP" | sed 's/data-id="//;s/"//' | head -n 20
    echo ""
    echo "Please check manually:"
    echo "  https://images.mynonpublic.com/openatv/"
    exit 1
fi
echo "  [OK] Device is supported"
echo ""

# ---- Find latest image ----
FILENAME=$(grep -oE "openatv-[0-9.]+-${BOXTYPE}-[0-9]+_usb\.zip" "$TMP" | sort -r | head -n 1)

if [ -z "$FILENAME" ]; then
    echo "ERROR: No image found for $BOXTYPE in OpenATV $VER"
    echo ""
    echo "Files found in page (first 10):"
    grep -oE "[a-zA-Z0-9_.-]+\.zip" "$TMP" | sort -u | head -n 10
    exit 1
fi

echo "Latest image: $FILENAME"
echo ""

# ---- Build URL ----
URL="$BASE/$VER/$BOXTYPE/$FILENAME"
DEST="$TARGET/$FILENAME"

# ---- Confirmation (A) ----
echo "=========================================="
echo "  READY TO DOWNLOAD"
echo "=========================================="
echo ""
echo "  Device:   $BOXTYPE"
echo "  Version:  OpenATV $VER"
echo "  Storage:  $TARGET"
echo "  File:     $FILENAME"
echo ""
echo "  URL: $URL"
echo ""
echo "  Continue? (y/n)"
echo ""
read -r ANSWER

case "$ANSWER" in
    y|Y|yes|YES)
        echo ""
        echo "Starting download..."
        echo "This may take 10-30 minutes. Please wait."
        echo ""
        
        wget --no-check-certificate --timeout=600 --tries=3 -O "$DEST" "$URL"
        
        if [ $? -eq 0 ] && [ -s "$DEST" ]; then
            SIZE=$(ls -lh "$DEST" | awk '{print $5}')
            echo ""
            echo "=========================================="
            echo "  DOWNLOAD COMPLETE"
            echo "=========================================="
            echo "  File: $DEST"
            echo "  Size: $SIZE"
            echo "=========================================="
        else
            echo ""
            echo "ERROR: Download failed"
            echo "You can try again or check your internet connection"
        fi
        ;;
    *)
        echo ""
        echo "Cancelled by user."
        ;;
esac

rm -f "$TMP"