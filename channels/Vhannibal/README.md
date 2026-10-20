# Vhannibal Motor 70E–45W

حزمة **Vhannibal** الرسمية للموتور (Motor 70E ... 45W) لصور Enigma2.

- التحديث: **18/10/2026** (الرابط الرسمي `id=5` يعطي أحدث إصدار)
- الصيغة: ZIP
- المحتوى: `lamedb`، `bouquets.tv/radio`، 150 باقة TV، 35 باقة راديو، `satellites.xml`
- المصدر الرسمي: <https://www.vhannibal.net/>
- رابط التحميل: <https://www.vhannibal.net/download_setting.php?id=5&action=download>

## مهم

**لا يتم استضافة ملفات Vhannibal في هذا المستودع.** السكريبت `vhannibal-motor.sh`
ينزّل ZIP مباشرة من خادم Vhannibal الرسمي وقت التثبيت، ثم ينسخ الملفات إلى
`/etc/enigma2` و`/etc/tuxbox/satellites.xml`. جميع الحقوق محفوظة لـ Vhannibal.

الموقع يمنع إعادة نشر الإعدادات على مواقع أو منتديات أو إضافات أخرى؛ لذلك هذا
المستودع يكتفي برابط التحميل الرسمي.

## التثبيت

من المتجر: **CHANNELS ← Vhannibal channel-list ← Motor 70E-45W**

أو من Terminal:

```sh
wget -q --no-check-certificate https://raw.githubusercontent.com/azroukarim/OurStore/main/channels/Vhannibal/vhannibal-motor.sh -O /tmp/vhannibal.sh
sh /tmp/vhannibal.sh
```

السكريبت يتحقق من الأرشيف قبل لمس القائمة الحالية، ويأخذ نسخة احتياطية في
`$TMPDIR/vhannibal.<pid>/vhannibal-bak`، ويوقف Enigma2 ثم يثبّت ويعيد التشغيل.
