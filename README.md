<div align="center">

<img src="https://raw.githubusercontent.com/azroukarim/OurStore/main/plugin.png" width="150" alt="Word Of Enigma2 Logo" />

# 🛒 Word Of Enigma2

**متجر شامل لإضافات Enigma2 والسكينات والأدوات**

[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-green?style=flat-square)]()
[![Platform](https://img.shields.io/badge/platform-Enigma2-orange?style=flat-square)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)]()

</div>

---

## 📖 نظرة عامة

**Word Of Enigma2** هو متجر إلكتروني متكامل مصمم لأجهزة **Enigma2**، يوفّر لك واجهة أنيقة وسريعة لتصفح وتثبيت:

- 🧩 الإضافات (Plugins)
- 🎨 السكينات (Skins)
- 🛠️ الأدوات (Tools)
- 📺 القنوات (Channels)
- 🖼️ البيكونات (Picons)
- 💾 صور النظام (System Images)
- ⚙️ حزم Novaler

كل ذلك من مكان واحد، وبضغطة زر.

---

## ✨ الميزات

| الميزة | الوصف |
|--------|-------|
| 🗂️ **تصفح الفئات** | تنقّل سلس بين الإضافات، السكينات، الأدوات وغيرها |
| 📦 **تثبيت الحزم** | تثبيت مباشر بضغطة واحدة |
| 📊 **شريط تقدم التحميل** | متابعة حية لعملية التنزيل |
| 🔄 **دعم التحديث الذاتي** | تحديث تلقائي للإصدارات الجديدة |
| 🎯 **واجهة عربية** | تصميم مريح وسهل الاستخدام |

---

## 🚀 التثبيت

### الطريقة السريعة (سطر واحد)

افتح Terminal على جهاز Enigma2 ونفّذ:

```bash
wget -O - https://raw.githubusercontent.com/azroukarim/OurStore/main/install.sh | sh
```

سيقوم السكريبت بـ:
1. حذف أي نسخة قديمة
2. إنشاء المجلدات المطلوبة
3. تنزيل الملفات الأساسية والصور
4. إعادة تشغيل Enigma2 تلقائيًا

### التثبيت اليدوي

```bash
cd /tmp
wget https://raw.githubusercontent.com/azroukarim/OurStore/main/install.sh
chmod +x install.sh
./install.sh
```

---

## 📂 هيكل المشروع

```
WordOfEnigma2/
├── plugin.py           # الملف الرئيسي
├── plugin.png          # أيقونة الإضافة
├── __init__.py         # تهيئة الحزمة
├── version.json        # رقم الإصدار
├── feed/
│   └── index.json      # فهرس المحتوى
├── images/             # الصور والأيقونات
│   └── Icons/
├── plugins/            # الإضافات
├── skins/              # السكينات
├── tools/              # الأدوات
├── channels/           # القنوات
├── picons/             # البيكونات
├── novaler/            # حزم Novaler
└── system_images/      # صور النظام
```

---

## 🖼️ لقطات الشاشة

<div align="center">

| الواجهة الرئيسية | تصفح الفئات |
|:---:|:---:|
| ![Main](https://raw.githubusercontent.com/azroukarim/OurStore/main/images/background.png) | ![Categories](https://raw.githubusercontent.com/azroukarim/OurStore/main/images/logo.png) |

</div>

---

## 🎮 أزرار التحكم

| الزر | الوظيفة |
|------|---------|
| 🔴 أحمر | خروج / إلغاء |
| 🟢 أخضر | تثبيت / تأكيد |
| 🟡 أصفر | تحديث القائمة |
| 🔵 أزرق | إعدادات |

---

## 🔄 التحديث

Word Of Enigma2 يدعم **التحديث الذاتي**. عند توفّر إصدار جديد:

1. ستظهر رسالة تنبيه داخل الإضافة
2. اختر "تحديث" من القائمة
3. سيتم تنزيل الملفات الجديدة تلقائيًا
4. إعادة تشغيل Enigma2 لإتمام التحديث

---

## 🤝 المساهمة

نرحب بمساهماتكم! لإضافة إضافة أو سكين جديد:

1. Fork المستودع
2. أضف ملفاتك في المجلد المناسب
3. حدّث `feed/index.json`
4. افتح Pull Request

---

## 📄 الترخيص

هذا المشروع مرخّص تحت **MIT License** — راجع ملف [LICENSE](LICENSE) للتفاصيل.

---

## 👤 المؤلف

**Karim Azrou**

[![GitHub](https://img.shields.io/badge/GitHub-azroukarim-181717?logo=github&style=flat-square)](https://github.com/azroukarim)

---

<div align="center">

**⭐ إذا أعجبك المشروع، لا تنسَ إعطاءه نجمة!**

Made with ❤️ for the Enigma2 community

</div>
