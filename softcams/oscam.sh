#!/bin/sh
# ============================================
# OSCam EMU PCSC Levi45 Installer
# ============================================

echo ""
echo "************************************************************"
echo "**              Installing OSCam EMU                     **"
echo "************************************************************"
echo ""

MY_URL="https://github.com/azroukarim/plugins/raw/refs/heads/main/softcams/enigma2-plugin-softcams-oscam-emu-pcsc-levi45_11968-803_all.ipk"
MY_FILE="/tmp/oscam-emu.ipk"

# حذف أي ملف قديم
rm -f $MY_FILE

# التحميل
echo "Downloading OSCam..."
wget -T 30 "$MY_URL" -O "$MY_FILE"

# التحقق من التحميل
if [ -f "$MY_FILE" ]; then
    echo "Installing OSCam..."
    opkg install "$MY_FILE"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "   >>>>   SUCCESSFULLY INSTALLED   <<<<"
        if [ "$WORD_OF_ENIGMA2_BATCH" = "1" ]; then
            echo "   >>>>  Batch mode: restart skipped (one restart at the end)  <<<<"
        else
            echo "   >>>>       RESTARTING           <<<<"
            sleep 2
            init 4; sleep 3; init 3
        fi
    else
        echo "   >>>>   INSTALLATION FAILED !   <<<<"
    fi
else
    echo "Download failed!"
    exit 1
fi

echo ""
echo "************************************************************"
echo "**              OSCam Installation Finished               **"
echo "************************************************************"