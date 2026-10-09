#!/bin/sh
# OpenATV Images Fetcher
# Displays all available OpenATV versions for the current box

echo "=========================================="
echo "  OpenATV Images - All Versions"
echo "=========================================="
echo ""

# Supported versions
VERSIONS="7.6 8.0 8.1"

for VER in $VERSIONS; do
    echo "-------------------------------------------"
    echo "OpenATV $VER:"
    echo "-------------------------------------------"
    
    URL="https://images.mynonpublic.com/openatv/$VER/json/openatv-$VER.json"
    TMP="/tmp/openatv_$VER.json"
    
    wget -q --no-check-certificate -O "$TMP" "$URL" 2>/dev/null
    
    if [ -s "$TMP" ]; then
        SIZE=$(wc -c < "$TMP")
        COUNT=$(grep -o '"name"' "$TMP" 2>/dev/null | wc -l)
        echo "  [OK] Available ($SIZE bytes, ~$COUNT images)"
        echo ""
        echo "  First 5 images:"
        grep -o '"name":"[^"]*"' "$TMP" 2>/dev/null | head -5 | sed 's/"name":"/    - /;s/"$//'
        echo ""
    else
        echo "  [--] Not available for this version"
        echo ""
    fi
    
    rm -f "$TMP"
done

echo "=========================================="
echo "Note: To install an image, use:"
echo "  Menu > Setup > Software Management > Flash Online"
echo "=========================================="
echo ""
read -p "Press Enter to return to AllStore..."
