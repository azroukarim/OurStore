#!/bin/sh
# OpenPLi Image Downloader
# Downloads the latest OpenPLi image for this box

echo "=========================================="
echo "  OpenPLi Image Downloader"
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

# ---- Determine brand for OpenPLi URL ----
BRAND=""
case "$BOXTYPE" in
    vu*) BRAND="vuplus" ;;
    sf8008*|sf4008*|sx*) BRAND="octagon" ;;
    zgemma*) BRAND="zgemma" ;;
    gb*) BRAND="gigablue" ;;
    dm*) BRAND="dreambox" ;;
    *) BRAND="" ;;
esac

# ---- Determine box display name for OpenPLi ----
BOXNAME=""
case "$BOXTYPE" in
    vuduo4kse) BOXNAME="Duo+4K+SE" ;;
    vuduo4k) BOXNAME="Duo+4K" ;;
    vuuno4kse) BOXNAME="Uno+4K+SE" ;;
    vuuno4k) BOXNAME="Uno+4K" ;;
    vuultimo4k) BOXNAME="Ultimo+4K" ;;
    vusolo4k) BOXNAME="Solo+4K" ;;
    vuzero4k) BOXNAME="Zero+4K" ;;
    vusolo2) BOXNAME="Solo2" ;;
    vuduo2) BOXNAME="Duo2" ;;
    *) BOXNAME="$BOXTYPE" ;;
esac

echo "Brand: $BRAND"
echo "Box name: $BOXNAME"
echo ""

# ---- Try primary URL (openpli.org) ----
URL1="https://openpli.org/download/$BRAND/$BOXNAME/"
echo "Trying: $URL1"
TMP="/tmp/pli_page.html"

wget -q --no-check-certificate -O "$TMP" "$URL1" 2>/dev/null

if [ ! -s "$TMP" ]; then
    echo "Primary URL failed, trying alternate..."
    URL1="https://downloads.openpli.org/builds/$BOXTYPE/"
    wget -q --no-check-certificate -O "$TMP" "$URL1" 2>/dev/null
fi

if [ ! -s "$TMP" ]; then
    echo "ERROR: Cannot fetch page"
    echo ""
    echo "Please visit manually:"
    echo "  https://openpli.org/download/"
    exit 1
fi

echo "Page fetched ($(wc -c < $TMP) bytes)"
echo ""

# ---- Find latest image for this box ----
FILENAME=$(grep -oE "openpli-[a-zA-Z0-9.-]+-${BOXTYPE}-[0-9]+_usb\.zip" "$TMP" | sort -r | head -1)

if [ -z "$FILENAME" ]; then
    # Try broader pattern
    FILENAME=$(grep -oE "openpli-[a-zA-Z0-9.-]+-${BOXTYPE}-[0-9]+\.zip" "$TMP" | sort -r | head -1)
fi

if [ -z "$FILENAME" ]; then
    echo "ERROR: No image found"
    echo ""
    echo "Files in page:"
    grep -oE "[a-zA-Z0-9_.-]+\.zip" "$TMP" | sort -u | head -10
    exit 1
fi

echo "Latest image: $FILENAME"
echo ""

# ---- Build URL and download ----
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
    echo "=========================================="
    echo "  File: $DEST"
    echo "  Size: $SIZE"
    echo "=========================================="
else
    echo "ERROR: Download failed"
fi

rm -f "$TMP"