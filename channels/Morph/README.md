# Morph883 E2 Settings 12.10.2026

قوائم قنوات **Morpheus883** (إصدار 12.10.2026) لصور Enigma2، داخل مجلد `channels/Morph`.

- 23 نسخة قنوات بصيغة `tar.gz` (كل نسخة جاهزة للفك على `/` وتحتوي `etc/enigma2/` و`etc/tuxbox/satellites.xml`)
- `satellites.xml` لكل الأقمار الـ88 (Ku Band)
- سكريبت تثبيت مستقل لكل نسخة: `morph883-<name>.sh`
- سكريبت تحديث ملف الأقمار: `morph883-satellites.sh`

## التثبيت من المتجر

اختر **CHANNELS ← Morph883 channel-list** ثم النسخة المناسبة.

## التثبيت من Terminal

```sh
wget -q --no-check-certificate https://raw.githubusercontent.com/azroukarim/OurStore/main/channels/Morph/morph883-13E.sh -O /tmp/morph.sh
sh /tmp/morph.sh
```

السكريبت يقوم بالتنزيل والتحقق، ويأخذ نسخة احتياطية في مجلد مؤقت (`$TMPDIR/morph.<pid>/morph-bak`)،
ثم يوقف Enigma2 (`init 4` أو `systemctl`)، يثبّت القائمة، يحذف `lamedb5`، ويعيد التشغيل.

## المصدر

إعدادات Morpheus883 الأصلية: <https://morpheus883.altervista.org/>
نسخة الأرشيفات العامة: <https://github.com/azroukarim/plugins/tree/main/channels/Morph>
