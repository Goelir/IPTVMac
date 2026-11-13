<div dir="rtl">

# פלטפורמות

פירוט על כל פלטפורמה: איפה להשיג את האפליקציה, איך מתקינים ואיך היא נבנית. הגרסה הקצרה ב-[README](../README.he.md#על-אילו-מכשירים-זה-רץ); בנייה מקוד המקור ב-[BUILDING.he.md](BUILDING.he.md). באנגלית: [PLATFORMS.md](PLATFORMS.md).

## Windows, ‏iPhone, ‏Android ו-Android TV

ל-IPTVMac יש אפליקציות ל-Mac, ל-Windows, לטלפונים של Android ול-Android TV שאפשר להוריד כבר היום, ואפליקציה ל-iPhone ול-iPad [ב-App Store](https://apps.apple.com/app/id6821761790). הן חולקות את הנגן והעיצוב, וקוד המקור שלהן במאגר הזה:

- **Windows** (‏`flutter/`, אותה אפליקציית Flutter של Android): מורידים את `IPTVMac-Windows-1.0.6-setup.exe` (בערך 27MB; מתקין למשתמש שלכם, בלי הרשאות מנהל) או את ה-zip הנייד מ[עמוד הגרסה](https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.6). Windows 10 או 11, ‏64 ביט. האפליקציה עוד לא חתומה בתעודה בתשלום, ולכן SmartScreen עשוי להזהיר: בוחרים **More info** ואז **Run anyway**. מקשים: רווח עוצר, חיצים מדלגים, למעלה ולמטה והגלגלת משנים עוצמת קול, F ממלא את המסך, Esc חוזר אחורה. הבנייה רצה ב-GitHub Actions (‏`.github/workflows/windows.yml`: ניתוח, כל הטסטים, בנייה, מתקין ובדיקת הפעלה עם מדידת זיכרון ומעבד בסרק), כי Flutter לא יכול לבנות Windows מ-Mac. הורדות לצפייה בלי רשת נשמרות ב-`Downloads\IPTVMac` ויורדות כל עוד האפליקציה פתוחה.
- **iPhone ו-iPad** (`ios/`): [ב-App Store](https://apps.apple.com/app/id6821761790). לבנייה בעצמכם: `scripts/ios-setup.sh` ואז פותחים את `ios/IPTVPhone.xcodeproj` (ראו [ios/README.md](../ios/README.md)).
- **Android** (`flutter/`): **[הורדת ה-APK](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.10)** (Android 8 ומעלה; בוחרים בקובץ `arm64-v8a` לכמעט כל טלפון, ובהערות הגרסה ההוראות). Flutter ו-libmpv, 31 שפות שנוצרות מאותן מחרוזות. נגן מגע עם מחוות, תמונה בתוך תמונה, קול שממשיך כשהמסך כבוי, כפתור סיבוב מסך, והורדות של סרטים ופרקים לצפייה בלי רשת (אפליקציית ה-Android היא היחידה, לצד ה-Mac, שיש בה הורדות; באייפון אין). בנייה: `cd flutter && flutter pub get && flutter test && flutter build apk` (Flutter 3.47, JDK 17, Android SDK 36; ראו [flutter/PLAN.md](../flutter/PLAN.md)). Android 8 ומעלה. היא מודיעה כשיצא APK חדש (באנר עם קישור לעמוד הגרסה; ההתקנה נשארת ידנית; היא פונה אל github.com לכל היותר אחת לשש שעות, ואפשר לכבות את זה בהגדרות).
- **Android TV, ‏Google TV ו-Fire TV** (אותה אפליקציה; גרסת הטלוויזיה הראשונה): מורידים את **[קובץ ה-32 ביט](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.10/IPTVMac-Android-1.0.10-tv-32bit.apk)** (‏38MB; רץ כמעט על כל טלוויזיה וסטרימר, כולל רוב ה-Fire TV Stick) או, אם הטלוויזיה אומרת שהוא לא תואם, את **[קובץ ה-64 ביט](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.10/IPTVMac-Android-1.0.10-tv-64bit.apk)** (‏41MB). ב-Fire TV או ב-Android TV מתקינים עם האפליקציה Downloader (מקלידים את כתובת הקובץ) או מכונן USB; עדיין אין רישום בחנות. עם השלט: החיצים מזיזים, OK בוחר, Back עולה רמה אחת, **לחיצה ארוכה על Back סוגרת את האפליקציה**; בנגן Left/Right מדלגים, Up/Down מחליפים ערוץ, OK עוצר. אין הורדות בטלוויזיה, והעדכון ידני (מתקינים את הקובץ החדש מעל הישן). מוזמנים לדווח על תקלות.

## App Store או GitHub?

אפליקציית ה-iPhone וה-iPad נמצאת ב-App Store, וקוד המקור המלא שלה כאן ב-GitHub. זו אותה אפליקציה ואותו קוד; אלה ההבדלים:

| | App Store | בנייה מ-GitHub |
|---|---|---|
| **התקנה** | לחיצה אחת ב-App Store. | בונים בעצמכם: Mac עם Xcode, אחר כך `scripts/ios-setup.sh`, ומריצים על ה-iPhone או ה-iPad. |
| **עדכונים** | אוטומטיים דרך ה-App Store, אחרי ש-Apple בדקה כל גרסה. | מתי שתרצו: מורידים את קוד המקור החדש ובונים שוב. ב-GitHub בדרך כלל יש קצת יותר מאשר ב-App Store. |
| **חתימה** | חשבון המפתחים של Apple של הפרויקט. | ה-Apple ID שלכם. עם חשבון Apple חינמי האפליקציה רצה 7 ימים ואז מתקינים שוב; חשבון בתשלום מחזיק שנה. |
| **מה בפנים** | אותו קוד. בלי פרסומות, בלי מעקב ובלי רכישות. | אותו קוד. בלי פרסומות, בלי מעקב ובלי רכישות. |
| **מחיר** | חינם. | חינם (GPL-3.0). |

אפליקציית ה-App Store עובדת גם ב-Mac עם Apple Silicon: מחפשים את IPTVMac ב-App Store של ה-Mac. אפליקציית ה-Mac המלאה, עם צפייה בתוכניות שעברו, הורדות ועדכונים משלה, נמצאת רק ב-[GitHub Releases](https://github.com/Goelir/IPTVMac/releases), וכך גם Windows, Android ו-Android TV. אפליקציות ה-Mac וה-Android מתעדכנות מעצמן מ-GitHub.

## התקנה בטלוויזיה עם האפליקציה Downloader

Android TV, ‏Google TV ו-Fire TV:

1. בטלוויזיה מתקינים את האפליקציה **Downloader** (ב-Fire TV מחפשים "Downloader"; ב-Android TV וב-Google TV ב-Google Play) ופותחים אותה.
2. ב-Downloader מקלידים את כתובת הקובץ: [32 ביט](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.10/IPTVMac-Android-1.0.10-tv-32bit.apk) (מנסים אותו קודם, הוא רץ כמעט על כל טלוויזיה וסטרימר) או [64 ביט](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.10/IPTVMac-Android-1.0.10-tv-64bit.apk) (אם הטלוויזיה אומרת שהאפליקציה לא תואמת). גם כונן USB עם הקובץ עובד.
3. מאשרים ל-Downloader להתקין אפליקציות כשהטלוויזיה שואלת, מתקינים ופותחים את IPTVMac. עם השלט: החיצים מזיזים, OK בוחר, Back עולה רמה אחת, **לחיצה ארוכה על Back סוגרת את האפליקציה**.

</div>
