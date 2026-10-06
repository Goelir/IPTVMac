<div dir="rtl">

<div align="center">

<img src="docs/logo.png" alt="IPTVMac" width="120">

# IPTVMac

**נגן IPTV מקורי ל-Mac.** Xtream Codes ו-M3U, חיפוש מיידי, נגן מובנה עם כתוביות, תמונה בתוך תמונה, צפייה בהיסטוריה (catch-up) והורדות.

[![Release](https://img.shields.io/github/v/release/Goelir/IPTVMac?color=5b6cf2)](https://github.com/Goelir/IPTVMac/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Goelir/IPTVMac/total?color=2ea44f)](https://github.com/Goelir/IPTVMac/releases)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-lightgrey)

[**הורדה**](https://github.com/Goelir/IPTVMac/releases/latest) &nbsp;·&nbsp; [אתר](https://goelir.github.io/IPTVMac/he/) &nbsp;·&nbsp; [התקנה](#התקנה) &nbsp;·&nbsp; [יכולות](#יכולות) &nbsp;·&nbsp; [שאלות נפוצות](#שאלות-נפוצות) &nbsp;·&nbsp; [English](README.md)

<br>

[![IPTVMac](docs/screenshots/03-movies.jpg)](https://github.com/Goelir/IPTVMac/releases/download/v0.3.4/IPTVMac-demo-he.mp4)

▶ [סרטון הדגמה של 80 שניות](https://github.com/Goelir/IPTVMac/releases/download/v0.3.4/IPTVMac-demo-he.mp4)

</div>

## למה IPTVMac

- **מהיר.** כל הספרייה שלך נשמרת במסד נתונים מקומי עם חיפוש טקסט מלא: חיפוש ערוץ מתוך 100,000 פריטים לוקח הרבה פחות משנייה, בתוך קטגוריה, בתוך חלק, או בכל מקום.
- **יציב.** הניגון רץ על [mpv](https://mpv.io) (libmpv, מובנה): הוא מנגן סטרימים פגומים שנגנים של המערכת נכשלים בהם, מתחבר מחדש כשהסטרים נופל, ומשתמש בפענוח חומרה.
- **מקורי.** SwiftUI, בלי Electron ובלי דפדפן מובנה. אין מה להתקין בנוסף: הנגן בתוך האפליקציה.
- **פתוח.** GPL-3.0, בלי חשבונות ובלי איסוף נתונים. האפליקציה פונה רק לשרתים שהוספת.

## יכולות

| | |
|---|---|
| **ערוצים, סרטים, סדרות** | שלושה חלקים עם קטגוריות, כרזות, לוגואים של ערוצים, רשימת "המשך צפייה" ומועדפים. |
| **חיפוש** | חיפוש בתוך הקטגוריה, בתוך החלק, או בכל מקום (התוצאות מקובצות לפי חלק). עברית, ערבית ולטינית. |
| **נגן** | נפתח במסך מלא, והבקרים נעלמים עד שמזיזים את העכבר. רווח, חצים (דילוג 10 שניות), `F` מסך מלא, `2` מהירות כפולה, `Esc` חזרה. |
| **כתוביות ואודיו** | רצועות מובנות, קבצי `.srt` / `.ass` חיצוניים (תפריט או גרירה), גודל והזזה, שפות מועדפות. |
| **תמונה בתוך תמונה** | נגן קטן צף שתמיד למעלה ועוקב אחריך בין שולחנות עבודה; אפשר לחזור לגלוש והסרט ממשיך. |
| **צפייה בהיסטוריה (catch-up)** | צפייה בתוכניות מהעבר בערוצים שהספק תומך בהם (Xtream `tv_archive`), לפי לוח השידורים. |
| **לוח שידורים (EPG)** | התוכנית הנוכחית והבאה ברשימת הערוצים ובנגן (Xtream). |
| **הורדות** | שמירת סרטים ופרקים (בסדרות Xtream, עונה שלמה בלחיצה) לתיקייה שבחרת, וניגון ממסך ההורדות. |
| **מקורות** | Xtream Codes (שרת, שם משתמש, סיסמה) ו-M3U (שם וקישור). כמה חשבונות. |
| **המשך ופרק הבא** | סרטים ופרקים ממשיכים מהמקום שבו עצרת; כשפרק נגמר, הפרק הבא מתחיל אחרי ספירה לאחור של 5 שניות (אפשר לבטל או לכבות בהגדרות). |
| **שפות** | ממשק בעברית, אנגלית וערבית, כולל פריסה מימין לשמאל. קל להוסיף שפות. |
| **עדכונים** | האפליקציה בודקת את GitHub Releases, מאמתת SHA-256 ומתעדכנת לבד. |

<details>
<summary><b>עוד צילומי מסך</b></summary>
<br>

| ערוצים | חיפוש כללי |
|---|---|
| ![Live](docs/screenshots/01-live.jpg) | ![Search](docs/screenshots/02-search.jpg) |
| **סדרות** | **נגן** |
| ![Series](docs/screenshots/04-series.jpg) | ![Player](docs/screenshots/05-player.jpg) |
| **תמונה בתוך תמונה** | **הורדות** |
| ![PiP](docs/screenshots/06-pip.jpg) | ![Downloads](docs/screenshots/07-downloads.jpg) |

צילומי המסך משתמשים ברשימת הדגמה בדויה; הסרטון הוא הטריילר "Sintel" של Blender Foundation (CC-BY 3.0).

</details>

## התקנה

נדרש Mac עם Apple Silicon (M1 ומעלה) ו-macOS 14 ומעלה.

**הדרך הקלה, בלי אזהרה של macOS.** הדבק שורה זו בטרמינל:

```
curl -fsSL https://raw.githubusercontent.com/Goelir/IPTVMac/main/install.sh | bash
```

השורה מורידה את הגרסה האחרונה, בודקת את ה-SHA-256 שמופיע בהערות הגרסה, מעתיקה את IPTVMac ל-`/Applications` ופותחת אותה. למה זה עובד: IPTVMac לא עברה אימות (notarization) של Apple, שדורש חשבון מפתחים בתשלום, ו-macOS חוסמת אפליקציות שהדפדפן סימן כ"הורדו מהאינטרנט". קובץ שמורידים עם `curl` לא מסומן, ולכן אין מה לעקוף. [install.sh](install.sh) קצר, ואפשר לקרוא אותו קודם. אחרי ההתקנה האפליקציה מתעדכנת לבד.

**או ידנית.** הורד את `IPTVMac.dmg` מ[הגרסה האחרונה](https://github.com/Goelir/IPTVMac/releases/latest), פתח אותו וגרור את אייקון **IPTVMac** על אייקון **Applications** שבחלון (לא את קובץ ה-dmg עצמו). בהפעלה הראשונה macOS חוסמת, ולכן:

- macOS 15 ומעלה: נסה לפתוח את האפליקציה פעם אחת, אחר כך **הגדרות המערכת > פרטיות ואבטחה**, גלול למטה ולחץ **Open Anyway** ליד IPTVMac.
- או בטרמינל: `xattr -dr com.apple.quarantine /Applications/IPTVMac.app`

## הפעלה ראשונה

האפליקציה פותחת מדריך קצר בשלושה שלבים.

- **Xtream Codes:** כתובת שרת (למשל `http://host:8080`), שם משתמש וסיסמה. את אלה נותן הספק שלך.
- **M3U:** שם וקישור לרשימה.

IPTVMac היא נגן בלבד. היא לא כוללת, לא מארחת ולא מקשרת לערוצים, סרטים או סדרות: צריך מקור שמותר לך להשתמש בו.

## שאלות נפוצות

<details>
<summary><b>macOS אומרת שאי אפשר לפתוח את האפליקציה.</b></summary>

האפליקציה לא עברה אימות של Apple. השתמש בפקודת ההתקנה למעלה, או פתח **הגדרות המערכת > פרטיות ואבטחה** ולחץ **Open Anyway**, או הרץ `xattr -dr com.apple.quarantine /Applications/IPTVMac.app`.
</details>

<details>
<summary><b>שום דבר לא מתנגן, או שאני רואה "HTTP 4xx/5xx".</b></summary>

בדוק שם משתמש וסיסמה בהגדרות (**שנה סיסמה**). ספקים מסוימים עונים על סיסמה שגויה או חיבור חסום בקודי HTTP לא רגילים במקום הודעה ברורה. הנגן מציג גם את הסיבה ש-mpv מדווח עליה.
</details>

<details>
<summary><b>הניגון נכשל כשהורדה רצה.</b></summary>

ספקים רבים מאפשרים חיבור אחד בלבד לחשבון (`max_connections`). ההורדות רצות אחת בכל פעם; אל תצפה במשהו אחר בזמן שהורדה רצה. ריבוי חיבורים גם לא יאיץ: המהירות מוגבלת בקו של הספק.
</details>

<details>
<summary><b>למה אין מהירות כפולה בשידור חי?</b></summary>

שידור חי לא יכול לרוץ מהר מזמן אמת. המהירות הכפולה עובדת בסרטים, בפרקים ובצפייה בהיסטוריה.
</details>

<details>
<summary><b>Mac עם Intel או macOS ישן?</b></summary>

לא נתמך: הנגן המובנה בנוי ל-Apple Silicon (arm64) והאפליקציה דורשת macOS 14 ומעלה.
</details>

<details>
<summary><b>איפה הנתונים שלי?</b></summary>

ב-`~/Library/Application Support/IPTVMac/` (התיקייה ומסד הנתונים נגישים רק למשתמש שלך). ראה [פרטיות](#פרטיות).
</details>

## פרטיות

המקורות שלך נשמרים ב-`~/Library/Application Support/IPTVMac/`. סיסמאות החשבונות נשמרות במסד הנתונים הזה כטקסט רגיל, ולא ב-Keychain (ה-Keychain ביקש הרשאה מחדש בכל גרסה). האפליקציה פונה רק לשרתים שהוספת, ול-GitHub לבדיקת עדכונים. בלי איסוף נתונים.

## תרומה לפרויקט

דיווחי באגים ו-pull requests יתקבלו בברכה: ראה [CONTRIBUTING.md](CONTRIBUTING.md). לעולם אל תדביק בדיווח כתובת שרת, שם משתמש או סיסמה.

## רישיון

[GPL-3.0](LICENSE). IPTVMac היא נגן ואינה מספקת תוכן; האחריות לשימוש במקורות מורשים בלבד היא עליך. פרטים על הרכיבים של צד שלישי ועל בנייה מקוד המקור: ב-[README באנגלית](README.md).

</div>
