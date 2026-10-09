#!/bin/sh
# OpenPLi Image Downloader
# VERSION: 9.2
# SLOT: Stable release

echo "=========================================="
echo "  OpenPLi 9.2 - Image Downloader"
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

# ---- Download URL pattern ----
# OpenPLi uses different URL patterns based on version
VERSION_TAG="9.2"

case "$VERSION_TAG" in
    "9.2")
        PATTERN="openpli-9.2-release-${BOXTYPE}-[0-9]+_usb.zip"
        ;;
    "9.1")
        PATTERN="openpli-9.1-release-${BOXTYPE}-[0-9]+_usb.zip"
        ;;
    "8.3")
        PATTERN="openpli-8.3-release-${BOXTYPE}-[0-9]+_usb.zip"
        ;;
    "scarthgap")
        PATTERN="openpli-scarthgap-${BOXTYPE}-[0-9]+_usb.zip"
        ;;
    *)
        PATTERN="openpli-${VERSION_TAG}-${BOXTYPE}-[0-9]+_usb.zip"
        ;;
esac

# ---- Fetch OpenPLi download page ----
echo "Fetching image list..."
URL="https://downloads.openpli.org/builds/$BOXTYPE/"
TMP="/tmp/pli_page.html"

wget -q --no-check-certificate -O "$TMP" "$URL" 2>/dev/null

# If failed, try openpli.org
if [ ! -s "$TMP" ]; then
    echo "Trying alternate URL..."
    case "$BOXTYPE" in
        vuduo4kse) BOXNAME="Duo+4K+SE" ;;
        vuduo4k) BOXNAME="Duo+4K" ;;
        vuuno4kse) BOXNAME="Uno+4K+SE" ;;
        vuzero4k) BOXNAME="Zero+4K" ;;
        vusolo4k) BOXNAME="Solo+4K" ;;
        vuultimo4k) BOXNAME="Ultimo+4K" ;;
        *) BOXNAME="$BOXTYPE" ;;
    esac
    URL="https://openpli.org/download/vuplus/$BOXNAME/"
    wget -q --no-check-certificate -O "$TMP" "$URL" 2>/dev/null
fi

if [ ! -s "$TMP" ]; then
    echo "ERROR: Cannot fetch page"
    exit 1
fi

echo "Page fetched ($(wc -c < $TMP) bytes)"
echo ""

# ---- Find latest image ----
FILENAME=$(grep -oE "$PATTERN" "$TMP" | sort -r | head -n 1)

if [ -z "$FILENAME" ]; then
    echo "ERROR: No image found for OpenPLi 9.2"
    echo ""
    echo "Available files in page:"
    grep -oE "openpli-[a-zA-Z0-9.-]+\.zip" "$TMP" | sort -u | head -n 10
    exit 1
fi

echo "Latest image: $FILENAME"
echo ""

# ---- Download ----
DL_URL="https://downloads.openpli.org/builds/$BOXTYPE/$FILENAME"
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