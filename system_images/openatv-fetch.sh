#!/bin/sh
# OpenATV Image Downloader
# Downloads and extracts an OpenATV image for the current box

echo "Fetching latest image from OpenATV server..."
echo "This may take a few minutes..."

# Fetch image list
cd /tmp
wget -q --no-check-certificate -O openatv_list.json "https://images.mynonpublic.com/openatv/json/openatv-8.0.json" 2>/dev/null

if [ ! -f openatv_list.json ]; then
    echo "Failed to fetch image list"
    exit 1
fi

echo "Image list downloaded successfully"
cat openatv_list.json | head -20

rm -f openatv_list.json