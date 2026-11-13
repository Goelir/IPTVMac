<div dir="rtl">

<div align="center">

<img src="docs/logo.png" alt="הלוגו של IPTVMac" width="112">

# IPTVMac

**נגן IPTV מקורי ל-Mac, ל-Windows, ל-iPhone ול-iPad, לטלפונים של Android ול-Android TV.**<br>
Xtream Codes ו-M3U, חיפוש מיידי, נגן מובנה עם כתוביות, תמונה בתוך תמונה, צפייה בהיסטוריה (catch-up) והורדות.<br>
חינמי לגמרי ובקוד פתוח. בלי חשבונות, בלי פרסומות ובלי איסוף נתונים.

<a href="https://apps.apple.com/app/id6821761790"><img src="docs/assets/app-store-badge-he.svg" alt="הורדה מה-App Store" height="56"></a><br>
**iPhone ו-iPad: ב-App Store, חינמיות לגמרי.** בלי פרסומות, בלי מנוי ובלי רכישות בתוך האפליקציה.

<br>

<div dir="ltr">

[![Latest release](https://img.shields.io/github/v/release/Goelir/IPTVMac?style=flat-square&color=5b6cf2&label=release)](https://github.com/Goelir/IPTVMac/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Goelir/IPTVMac/total?style=flat-square&color=2ea44f)](https://github.com/Goelir/IPTVMac/releases)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-lightgrey?style=flat-square)
![Windows 10+](https://img.shields.io/badge/Windows-10%2B-0078d4?style=flat-square&logo=windows&logoColor=white)
![Android 8+](https://img.shields.io/badge/Android-8%2B-3ddc84?style=flat-square&logo=android&logoColor=white)
![Android TV](https://img.shields.io/badge/Android%20TV-Google%20TV%20%7C%20Fire%20TV-3ddc84?style=flat-square&logo=androidtv&logoColor=white)
[![Stars](https://img.shields.io/github/stars/Goelir/IPTVMac?style=flat-square&logo=github&color=eac54f)](https://github.com/Goelir/IPTVMac/stargazers)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-ffdd00?style=flat-square&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/elijr)

</div>

[**הורדה ל-Mac**](https://github.com/Goelir/IPTVMac/releases/latest) &nbsp;|&nbsp; [**הורדה ל-Windows**](https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.6) &nbsp;|&nbsp; [**iPhone ו-iPad (App Store)**](https://apps.apple.com/app/id6821761790) &nbsp;|&nbsp; [**Android ו-Android TV (APK)**](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.10) &nbsp;|&nbsp; [**כל ההורדות**](https://goelir.github.io/IPTVMac/he/download/)

אם IPTVMac מועיל לכם, ⭐ ב-GitHub עוזר לאחרים למצוא אותו, ואפשר [לקנות לי קפה](https://buymeacoffee.com/elijr) כדי לתמוך בפיתוח.

<sub>[אתר](https://goelir.github.io/IPTVMac/he/) · [מה חדש](https://goelir.github.io/IPTVMac/he/changelog/) · [התקנה](#התקנה) · [יכולות](#יכולות) · [שאלות נפוצות](#שאלות-נפוצות) · [English](README.md)</sub>

<br>

[![IPTVMac ב-macOS: ספריית סרטים עם נגן תמונה בתוך תמונה, ערוצים חיים והנגן במסך מלא](docs/screenshots/hero-windows.png)](https://github.com/Goelir/IPTVMac/releases/download/v0.3.4/IPTVMac-demo-he.mp4)

<sub>רשימת הדגמה עם שמות בדויים, וידאו מתוך "Sintel" של Blender Foundation (CC-BY 3.0). [סרטון הדגמה של 80 שניות](https://github.com/Goelir/IPTVMac/releases/download/v0.3.4/IPTVMac-demo-he.mp4).</sub>

<img src="docs/images/demo.gif" alt="IPTVMac: חיפוש מיידי ואז תמונה בתוך תמונה" width="720">

</div>

## על אילו מכשירים זה רץ

| מכשיר | הורדה | מצב |
|---|---|---|
| **Mac** (‏Apple Silicon, ‏macOS 14 ומעלה) | [DMG או התקנה בשורה אחת](#התקנה) | יצא, חתום ומאושר על ידי אפל, מתעדכן לבד |
| **Windows** (‏Windows 10 ו-11, ‏64 ביט) | [מתקין או zip נייד](https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.6) (בערך 27MB), לא חתום: SmartScreen מבקש More info ואז Run anyway | נגן למקלדת ולעכבר, הורדות לצפייה בלי רשת, קל בזיכרון ובמעבד |
| **טלפונים וטאבלטים של Android** (‏Android 8 ומעלה) | [APK ב-GitHub Releases](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.10) (‏`arm64-v8a` לכמעט כל טלפון) | יצאה; מתעדכנת מתוך האפליקציה |
| **Android TV, ‏Google TV, ‏Fire TV** | [APK של 32 או 64 ביט](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.10), מתקינים עם האפליקציה Downloader או מכונן USB | גרסה ראשונה: שלט, בלי מסך מגע |
| **iPhone ו-iPad** (iOS 17+) | [App Store](https://apps.apple.com/app/id6821761790), או [בנייה מהמקור](#פלטפורמות-נוספות) | יצאה (גרסה 1.0.1) |

אותו מנוע, 31 שפות ובלי חשבון, בכל מקום.

## App Store או GitHub?

אפליקציית ה-iPhone וה-iPad נמצאת ב-App Store, וקוד המקור המלא שלה כאן ב-GitHub. זו אותה אפליקציה ואותו קוד; אלה ההבדלים:

| | App Store | בנייה מ-GitHub |
|---|---|---|
| **התקנה** | לחיצה אחת ב-App Store. | בונים בעצמכם: Mac עם Xcode, אחר כך `scripts/ios-setup.sh`, ומריצים על ה-iPhone או ה-iPad (ראו [docs/PLATFORMS.he.md](docs/PLATFORMS.he.md)). |
| **עדכונים** | אוטומטיים דרך ה-App Store, אחרי ש-Apple בדקה כל גרסה. | מתי שתרצו: מורידים את קוד המקור החדש ובונים שוב. ב-GitHub בדרך כלל יש קצת יותר מאשר ב-App Store. |
| **חתימה** | חשבון המפתחים של Apple של הפרויקט. | ה-Apple ID שלכם. עם חשבון Apple חינמי האפליקציה רצה 7 ימים ואז מתקינים שוב; חשבון בתשלום מחזיק שנה. |
| **מה בפנים** | אותו קוד. בלי פרסומות, בלי מעקב ובלי רכישות. | אותו קוד. בלי פרסומות, בלי מעקב ובלי רכישות. |
| **מחיר** | חינם. | חינם (GPL-3.0). |

אפליקציית ה-App Store מותקנת גם ב-Mac עם Apple Silicon: מחפשים את IPTVMac ב-App Store של ה-Mac, והיא רצה כאפליקציית ה-iPad. אפליקציית ה-Mac המלאה, עם צפייה בתוכניות שעברו, הורדות ועדכונים משלה, נמצאת רק ב-[GitHub Releases](https://github.com/Goelir/IPTVMac/releases), וכך גם Windows, Android ו-Android TV. אפליקציות ה-Mac וה-Android מתעדכנות מעצמן מ-GitHub.

## למה IPTVMac

- **מהיר.** כל הספרייה שלך נשמרת במסד נתונים מקומי עם חיפוש טקסט מלא. מציאת ערוץ מתוך 100,000 פריטים לוקחת הרבה פחות משנייה, בתוך קטגוריה, בתוך חלק, או בכל מקום.
- **יציב.** הניגון רץ על [mpv](https://mpv.io) (libmpv, מובנה). הוא מנגן סטרימים פגומים שנגנים של המערכת נכשלים בהם, מתחבר מחדש כשהסטרים נופל, ומשתמש בפענוח חומרה.
- **מקורי, בשפה המתאימה לכל פלטפורמה.** Swift ו-SwiftUI ב-Mac וב-iPhone; Dart עם Flutter ושכבת Kotlin ב-Android וב-Android TV. כל אפליקציה כתובה לפלטפורמה שלה ולא בתוך מעטפת אחת משותפת, ובכולן הווידאו מפוענח באותו מנוע libmpv מקומפל; בלי Electron ובלי דפדפן מובנה. אין מה להתקין בנוסף: הנגן בתוך האפליקציה.
- **פתוח.** GPL-3.0, בלי חשבונות ובלי איסוף נתונים. האפליקציה פונה רק לשרתים שהוספת, ול-GitHub לעדכונים.

## התקנה

**ב-Mac.** (‏Android ו-Android TV: ראו [פלטפורמות נוספות](#פלטפורמות-נוספות).) נדרש Mac עם Apple Silicon (M1 ומעלה) ו-macOS 14 ומעלה.

**התקנה בשורה אחת.** הדביקו בטרמינל:

<div dir="ltr">

```
curl -fsSL https://raw.githubusercontent.com/Goelir/IPTVMac/main/install.sh | bash
```

</div>

השורה מורידה את הגרסה האחרונה, בודקת את החתימה ואת ה-SHA-256, מעתיקה את IPTVMac ל-`/Applications` ופותחת אותה. [install.sh](install.sh) קצר, ואפשר לקרוא אותו קודם. היא עובדת עם כל הגרסאות, ומכיוון שדבר לא יורד בדפדפן, אין ל-macOS מה לסמן. אחרי ההתקנה האפליקציה מתעדכנת לבד.

**או להוריד את ה-DMG.** הורידו את `IPTVMac.dmg` מ[הגרסה האחרונה](https://github.com/Goelir/IPTVMac/releases/latest), פתחו אותו וגררו את האייקון **IPTVMac** על האייקון **Applications** שבחלון (לא את קובץ ה-dmg עצמו). מגרסה 0.9.1 ואילך הגרסאות חתומות ב-Apple Developer ID ועברו notarization (בדיקה אוטומטית של Apple לאיתור תוכנות זדוניות, לא סקירה של האפליקציה), ולכן האפליקציה נפתחת בלחיצה כפולה רגילה. ייתכן ש-macOS תבקש פעם אחת לאשר שהיא הורדה מהאינטרנט.

גרסאות ישנות יותר לא עברו notarization, ו-macOS חוסמת עותק שהורד בדפדפן בהפעלה הראשונה. בגרסאות האלה:

- macOS 15 ומעלה: נסו לפתוח את האפליקציה פעם אחת, ואז **הגדרות המערכת > פרטיות ואבטחה**, גללו למטה ולחצו **Open Anyway** ליד IPTVMac.
- או בטרמינל: `xattr -dr com.apple.quarantine /Applications/IPTVMac.app`

רוצים לראות קודם? [סרטון התקנה של 95 שניות (באנגלית)](https://youtu.be/TgaoFEEMg48).

## הפעלה ראשונה

האפליקציה פותחת מדריך קצר בשלושה שלבים. מוסיפים רשימה מהספק:

- **Xtream Codes:** כתובת שרת (למשל `http://host:8080`), שם משתמש וסיסמה. את אלה נותן הספק שלכם.
- **M3U:** שם וקישור לרשימה.

IPTVMac היא נגן בלבד. היא לא כוללת ולא מארחת ערוצים, סרטים או סדרות: צריך מקור שמותר לכם להשתמש בו.

### אין לכם רשימה?

אם אין לכם ספק, [iptv-org/iptv](https://github.com/iptv-org/iptv) הוא פרויקט עצמאי בקוד פתוח וחינמי שמפרסם רשימות M3U של ערוצים זמינים לציבור מכל העולם. ב-IPTVMac בוחרים **M3U**, נותנים שם ומדביקים:

<div dir="ltr">

```
https://iptv-org.github.io/iptv/index.m3u
```

</div>

יש בה כ-11,000 פריטים (הטעינה לוקחת רגע); ב-README של הפרויקט יש גם רשימות לפי מדינה, שפה וקטגוריה. IPTVMac אינה קשורה ל-iptv-org. אם סטרים זמין, ואם מותר לכם לצפות בו, תלוי בערוץ ובמדינה שלכם: השתמשו רק במה שמותר לכם.

## צילומי מסך

<div align="center">

![סרטים](docs/screenshots/03-movies.jpg)

| | |
|:---:|:---:|
| ![ערוצים](docs/screenshots/01-live.jpg)<br>**ערוצים חיים** | ![חיפוש כללי](docs/screenshots/02-search.jpg)<br>**חיפוש בכל מקום** |
| ![סדרות](docs/screenshots/04-series.jpg)<br>**סדרות** | ![נגן](docs/screenshots/05-player.jpg)<br>**נגן** |
| ![תמונה בתוך תמונה](docs/screenshots/06-pip.jpg)<br>**תמונה בתוך תמונה** | ![הורדות](docs/screenshots/07-downloads.jpg)<br>**הורדות** |

<sub>צילומי המסך משתמשים ברשימת הדגמה בדויה; הסרטון הוא הטריילר "Sintel" של Blender Foundation (CC-BY 3.0).</sub>

</div>

## Android ו-Android TV

<p align="center">
<img src="docs/screenshots/android-live.webp" width="190" alt="IPTVMac בטלפון Android: ערוצים חיים עם התוכנית עכשיו והבאה">
<img src="docs/screenshots/android-series.webp" width="190" alt="IPTVMac בטלפון Android: עמוד סדרה עם עונות ופרקים">
<img src="docs/screenshots/tv-live.webp" width="330" alt="IPTVMac ב-Android TV: רשימת הערוצים עם מסגרת הפוקוס של השלט">
<img src="docs/screenshots/tv-details.webp" width="330" alt="IPTVMac ב-Android TV: פרטי סרט כשכפתור הניגון בפוקוס">
</p>

<sub>רשימת הדגמה עם שמות בדויים. שתי תמונות הטלוויזיה הן מאמולטור.</sub>

**טלפון או טאבלט (Android 8 ומעלה).**

1. מורידים את [IPTVMac-Android-1.0.10-arm64-v8a.apk](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.10/IPTVMac-Android-1.0.10-arm64-v8a.apk) (מתאים לכמעט כל טלפון; ב[עמוד הגרסה](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.10) יש את שאר הקבצים).
2. פותחים אותו ומאשרים התקנה מהדפדפן או מאפליקציית הקבצים כש-Android שואל.
3. מוסיפים מקור. באנר מודיע כשיוצאת גרסה חדשה; בטלפון "עדכן עכשיו" מוריד ומתקין אותה מתוך האפליקציה (Android מבקש אישור). בטלוויזיה ההתקנה נשארת ידנית.

**Android TV, ‏Google TV ו-Fire TV.**

1. בטלוויזיה מתקינים את האפליקציה **Downloader** (ב-Fire TV מחפשים "Downloader"; ב-Android TV וב-Google TV ב-Google Play) ופותחים אותה.
2. ב-Downloader מקלידים את כתובת הקובץ: [32 ביט](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.10/IPTVMac-Android-1.0.10-tv-32bit.apk) (מנסים אותו קודם, הוא רץ כמעט על כל טלוויזיה וסטרימר) או [64 ביט](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.10/IPTVMac-Android-1.0.10-tv-64bit.apk) (אם הטלוויזיה אומרת שהאפליקציה לא תואמת). גם כונן USB עם הקובץ עובד.
3. מאשרים ל-Downloader להתקין אפליקציות כשהטלוויזיה שואלת, מתקינים ופותחים את IPTVMac. עם השלט: החיצים מזיזים, OK בוחר, Back עולה רמה אחת, **לחיצה ארוכה על Back סוגרת את האפליקציה**.

עוד על כל פלטפורמה: [docs/PLATFORMS.he.md](docs/PLATFORMS.he.md).

## יכולות

| | |
|---|---|
| **ערוצים, סרטים, סדרות** | שלושה חלקים עם קטגוריות, כרזות, לוגואים של ערוצים, "המשך צפייה" ומועדפים. |
| **חיפוש** | חיפוש בתוך הקטגוריה, בתוך החלק, או בכל מקום, והתוצאות מקובצות לפי חלק. עברית, ערבית ולטינית. |
| **נגן** | נפתח במסך מלא, והבקרים נעלמים עד שמזיזים את העכבר. רווח, חצים לדילוג (10 שניות כברירת מחדל, 5 עד 60 בהגדרות), `F` מסך מלא, `2` מהירות כפולה, `[` ו-`]` איטי ומהיר יותר, בורר מהירות מ-0.25x עד 4x (סרטים ופרקים), `A` התאמה, מילוי או מתיחה, **טיימר שינה** (אייקון ירח), שעון אופציונלי, `Esc` חזרה. |
| **כתוביות ואודיו** | רצועות מובנות, קבצי `.srt` ו-`.ass` חיצוניים (תפריט או גרירה), גודל והזזה, שפות מועדפות. |
| **תמונה בתוך תמונה** | נגן קטן צף שתמיד למעלה ועוקב אחריכם בין שולחנות עבודה, ואפשר להמשיך לגלוש. |
| **צפייה בהיסטוריה (catch-up)** | צפייה בתוכניות מהעבר בערוצים שהספק תומך בהם (Xtream `tv_archive`), לפי לוח השידורים. |
| **לוח שידורים (EPG)** | התוכנית הנוכחית והבאה ברשימת הערוצים ובנגן (Xtream). |
| **הורדות** | שמירת סרטים ופרקים (בסדרות Xtream, עונה שלמה בלחיצה) לתיקייה שבחרתם, וניגון ממסך ההורדות. |
| **רשימות** | Xtream Codes ו-M3U. עם כמה רשימות אפשר לעבור ביניהן מסרגל הכלים, או לבחור **כל הרשימות** ולחפש, לסמן מועדפים ולהמשיך לצפות מכולן, עם שם הרשימה על כל פריט. |
| **המשך ופרק הבא** | סרטים ופרקים ממשיכים מהמקום שבו עצרתם; דף "המשך לצפות" אומר לכל סדרה את הפרק ואת הדקות שנשארו ("S2 E5 · 23 min left") ולחיצה ממשיכה אותה. כשפרק נגמר, הפרק הבא מתחיל אחרי ספירה לאחור של 5 שניות (אפשר לבטל או לכבות). |
| **דילוג על פתיח וקרדיטים** | ספקים לא מפרסמים איפה הפתיח נגמר, ולכן מסמנים פעם אחת לכל סדרה (בתפריט הנגן "פתיח וקרדיטים": הפתיח מתחיל כאן, הפתיח נגמר כאן, הקרדיטים מתחילים כאן). בכל פרק של הסדרה מופיעים **דלג על הפתיח** ו**דלג על הקרדיטים** (הפרק הבא מתחיל); המקש `S` לוחץ על הכפתור. |
| **הגדרות** | מראה (מערכת, בהיר, כהה), שפת ממשק, רענון אוטומטי של הרשימות, הסתרת קטגוריות לפי מילים, גודל מטמון הרשת, **גיבוי ושחזור** של הרשימות (בלי סיסמאות), המועדפים והיסטוריית הצפייה, וניקוי היסטוריה, מועדפים או מטמון תמונות. |
| **31 שפות** | כולל פריסה מימין לשמאל בעברית, ערבית, פרסית ואורדו. ראו [שפות](#שפות). |
| **עדכונים חתומים** | האפליקציה בודקת גרסאות חדשות, מאמתת חתימה ו-SHA-256 ומתעדכנת לבד. ראו [עדכונים](#עדכונים). |

## שאלות נפוצות

<details>
<summary><b>macOS אומרת שאי אפשר לפתוח את האפליקציה, או שהיא "פגומה".</b></summary>

זה קורה בגרסאות ישנות, שלא עברו notarization (ראו [התקנה](#התקנה)). התקינו את הגרסה האחרונה: מה-DMG, או בפקודת ההתקנה שלמעלה, שעובדת בכל הגרסאות. כדי לפתוח עותק ישן בכל זאת, פתחו **הגדרות המערכת > פרטיות ואבטחה** ולחצו **Open Anyway**, או הריצו `xattr -dr com.apple.quarantine /Applications/IPTVMac.app`. אם ההודעה מופיעה בגרסה האחרונה, פתחו בבקשה issue.
</details>

<details>
<summary><b>שום דבר לא מתנגן, או שאני רואה "HTTP 4xx/5xx" (למשל 403 או 413).</b></summary>

בדקו שם משתמש וסיסמה בהגדרות (**שנה סיסמה**). ספקים מסוימים עונים על סיסמה שגויה או חיבור חסום בקודי HTTP לא רגילים, כמו 403 או 413, במקום הודעה ברורה. טעות בהקלדת הסיסמה היא הסיבה הנפוצה ביותר. הנגן מציג גם את הסיבה ש-mpv מדווח עליה.
</details>

<details>
<summary><b>העדכון נכשל עם הודעה ש-GitHub מגביל בקשות, או עם "HTTP 403".</b></summary>

גרסאות שלפני 0.7.2 שאלו את ה-API של GitHub מהי הגרסה האחרונה, ו-GitHub מאפשר רק 60 בקשות כאלה בשעה לכל כתובת IP, כך שברשת משותפת אפשר להגיע למגבלה. גרסה 0.7.2 קוראת במקום זה קובץ `release.txt` חתום מ-github.com, בלי המגבלה הזו, ומודיעה בבירור כש-GitHub מגביל רשת. אם גרסה ישנה לא מצליחה להתעדכן, הורידו את `IPTVMac.dmg` מ[הגרסה האחרונה](https://github.com/Goelir/IPTVMac/releases/latest) והחליפו את האפליקציה ב-`/Applications`, או הריצו את פקודת ההתקנה למעלה. מכאן והלאה היא מתעדכנת לבד.
</details>

<details>
<summary><b>הניגון נכשל כשהורדה רצה.</b></summary>

ספקים רבים מאפשרים חיבור אחד בלבד לחשבון (`max_connections`). ההורדות רצות אחת בכל פעם; אל תצפו במשהו אחר בזמן שהורדה רצה. ריבוי חיבורים גם לא יאיץ: המהירות מוגבלת בקו של הספק.
</details>

<details>
<summary><b>למה אין מהירות כפולה בשידור חי?</b></summary>

שידור חי לא יכול לרוץ מהר מזמן אמת. שינוי מהירות עובד בסרטים, בפרקים ובצפייה בהיסטוריה.
</details>

<details>
<summary><b>Mac עם Intel או macOS ישן?</b></summary>

לא נתמך: הנגן המובנה בנוי ל-Apple Silicon (arm64) והאפליקציה דורשת macOS 14 ומעלה.
</details>

<details>
<summary><b>איפה הנתונים שלי?</b></summary>

ב-`~/Library/Application Support/IPTVMac/` (התיקייה ומסד הנתונים נגישים רק למשתמש שלכם). ראו [פרטיות](#פרטיות).
</details>

## שפות

31 שפות בממשק: עברית, אנגלית, ערבית, ספרדית, צרפתית, גרמנית, פורטוגזית, איטלקית, רוסית, אוקראינית, פולנית, רומנית, בולגרית, הולנדית, שוודית, צ'כית, הונגרית, יוונית, אלבנית, טורקית, פרסית, אורדו, הינדי, בנגלית, אינדונזית, וייטנאמית, תאית, סינית (מפושטת ומסורתית), יפנית וקוריאנית, כולל פריסה מימין לשמאל בעברית, ערבית, פרסית ואורדו. האפליקציה פועלת בשפת ה-Mac שלכם, או שבוחרים שפה בהגדרות.

חוץ מעברית, אנגלית וערבית, התרגומים נכתבו בעזרת בינה מלאכותית ועדיין לא נבדקו על ידי דוברי שפת אם. תיקונים יתקבלו בברכה.

### תרגום לשפה נוספת או תיקון תרגום

1. העתיקו את `Sources/IPTVMac/Resources/en.lproj/Localizable.strings` אל `<lang>.lproj/` (קוד שפה של Apple, למשל `pt` או `zh-Hans`) ותרגמו את הערכים. שמרו על כל מפתח ועל כל סימון מקום `%@` / `%d`, באותו סדר.
2. הוסיפו את השפה, כתובה בשפה עצמה, ל-`InterfaceLanguage.all` בקובץ `Sources/IPTVMac/AppPrefs.swift` (כך היא מופיעה בבורר השפות בהגדרות).
3. הריצו `python3 scripts/check-strings.py <lang>`. הפלט חייב להיות `OK`.

## עדכונים

האפליקציה המותקנת בודקת את GitHub Releases בהפעלה ואחת ל-6 שעות. כשיש גרסה חדשה היא מורידה אותה ומאמתת את **החתימה** של הגרסה (מפתח Ed25519 שאינו שמור ב-GitHub ומוטמע באפליקציה) ואת ה-SHA-256 שמופיע בהערות הגרסה. אחר כך מופיע באנר: **Restart to update** (או שהעדכון מותקן ביציאה הבאה). אפשר לכבות בהגדרות את הבדיקה האוטומטית ואת ההורדה האוטומטית, כל אחת לחוד.

## פלטפורמות נוספות

פירוט על Windows, ‏iPhone ו-iPad, ‏Android ו-Android TV (הורדות, שלבי התקנה, איך כל אפליקציה נבנית) נמצא ב-[docs/PLATFORMS.he.md](docs/PLATFORMS.he.md) (באנגלית: [docs/PLATFORMS.md](docs/PLATFORMS.md)); בנייה מקוד המקור ופרטים טכניים ב-[docs/BUILDING.he.md](docs/BUILDING.he.md) (באנגלית: [docs/BUILDING.md](docs/BUILDING.md)).

- **Windows:** [מתקין או zip נייד](https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.6) (‏Windows 10 או 11, ‏64 ביט). עוד לא חתום בתעודה בתשלום, ולכן SmartScreen עשוי להזהיר: בוחרים **More info** ואז **Run anyway**.
- **iPhone ו-iPad:** [ב-App Store](https://apps.apple.com/app/id6821761790). לבנייה בעצמכם ראו [docs/PLATFORMS.he.md](docs/PLATFORMS.he.md).
- **Android ו-Android TV:** ראו [הסעיף למעלה](#android-ו-android-tv).

## מדריכים

אתר הפרויקט כולל מדריכים באנגלית:

- [How to watch Xtream Codes IPTV on a Mac](https://goelir.github.io/IPTVMac/guides/xtream-codes-on-mac.html)
- [How to play an M3U playlist on a Mac](https://goelir.github.io/IPTVMac/guides/m3u-playlist-on-mac.html)
- [Picture in Picture for IPTV on a Mac](https://goelir.github.io/IPTVMac/guides/picture-in-picture-iptv-mac.html)

## פרטיות

המקורות שלכם נשמרים ב-`~/Library/Application Support/IPTVMac/` (נגישים רק למשתמש שלכם). כברירת מחדל, סיסמאות החשבונות נשמרות במסד הנתונים הזה כטקסט רגיל. כדי לשמור אותן ב-Keychain של המשתמש, מפעילים בהגדרות > רשימות את "שמור סיסמאות ב-Keychain" (מגרסה 0.9.9; כיבוי מחזיר אותן). האפליקציה פונה רק לשרתים שהוספתם, ול-GitHub לבדיקת עדכונים. בלי איסוף נתונים ובלי טלמטריה.

## אבטחה

ב-[SECURITY.md](SECURITY.md) (באנגלית): איך העדכונים מוגנים, המגבלות הידועות, ואיך לדווח על פגיעות באופן פרטי.

## תרומה לפרויקט

דיווחי באגים, תרגומים ו-pull requests יתקבלו בברכה: ראו [CONTRIBUTING.md](CONTRIBUTING.md). לעולם אל תדביקו בדיווח כתובת שרת, שם משתמש או סיסמה.

לבנייה מקוד המקור ראו [docs/BUILDING.he.md](docs/BUILDING.he.md).

## תמיכה בפרויקט

IPTVMac חינמית בכל הפלטפורמות, בלי פרסומות ובלי שום דבר נעול, וכך היא תישאר. אם היא מועילה לכם ואתם רוצים לעזור לפיתוח שלה, אפשר [לקנות לי קפה](https://buymeacoffee.com/elijr). זה לגמרי מרצון.

[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-elijr-ffdd00?style=flat-square&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/elijr)

## רישיון

[GPL-3.0](LICENSE). IPTVMac היא נגן ואינה מספקת תוכן; האחריות לשימוש במקורות מורשים בלבד היא עליכם.

רכיבים של צד שלישי, כולל ה-libmpv שבגרסה: [docs/BUILDING.he.md](docs/BUILDING.he.md#רכיבים-של-צד-שלישי).

</div>
