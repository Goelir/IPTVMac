<div dir="rtl">

# בנייה של IPTVMac ופרטים טכניים

איך IPTVMac נבנה בכל פלטפורמה, באיזו שפה הוא כתוב ואילו רכיבים של צד שלישי הוא כולל. מה האפליקציה עושה ואיך מתקינים אותה: ב-[README](../README.he.md). פירוט לכל פלטפורמה: [PLATFORMS.he.md](PLATFORMS.he.md). ההסבר המלא על בניית Android ו-Windows (כולל ה-CI) נמצא באנגלית ב-[BUILDING.md](BUILDING.md).

## באיזו שפה כל פלטפורמה כתובה

| מכשיר | איפה להשיג | מצב | כתוב ב |
|---|---|---|---|
| **Mac** (‏Apple Silicon, ‏macOS 14 ומעלה) | [DMG או התקנה בשורה אחת](../README.he.md#התקנה) | יצא, חתום ומאושר על ידי אפל, מתעדכן לבד | Swift + SwiftUI |
| **Windows** (‏Windows 10 ו-11, ‏64 ביט) | [מתקין או zip נייד](https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.1) (בערך 27MB), לא חתום: SmartScreen מבקש More info ואז Run anyway | נגן למקלדת ולעכבר, הורדות לצפייה בלי רשת, קל בזיכרון ובמעבד | Dart + Flutter, מעטפת C++ קטנה |
| **טלפונים וטאבלטים של Android** (‏Android 8 ומעלה) | [APK ב-GitHub Releases](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.4) (‏`arm64-v8a` לכמעט כל טלפון) | יצא, התקנה ידנית | Dart + Flutter, שכבת Kotlin |
| **Android TV, ‏Google TV, ‏Fire TV** | [APK של 32 או 64 ביט](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.4), מתקינים עם האפליקציה Downloader או מכונן USB | גרסה ראשונה: שלט, בלי מסך מגע | Dart + Flutter, שכבת Kotlin |
| **iPhone ו-iPad** | ממתין לבדיקה ב-App Store; בינתיים אפשר [לבנות מהמקור](PLATFORMS.he.md) | לא יצא | Swift + SwiftUI |

אותו מנוע, 31 שפות ובלי חשבון, בכל מקום. בכל פלטפורמה את הווידאו מפענח אותו מנוע libmpv מקומפל.

## בנייה מקוד המקור (Mac)

<div dir="ltr">

```
brew install mpv pkgconf     # mpv only supplies the C headers to compile against
scripts/swift.sh test        # tests
scripts/swift.sh run IPTVMac # run
scripts/make-dmg.sh          # builds build/IPTVMac.dmg
```

</div>

כשמותקנים רק Command Line Tools, השתמשו ב-`scripts/swift.sh` במקום ב-`swift` (הוא בוחר SDK שה-SwiftUI שלו לא צריך את תוסף המאקרו של Xcode). הערות עיצוב: [docs/superpowers/specs](superpowers/specs/2026-10-05-iptvmac-design.md).

## רכיבים של צד שלישי

הגרסה כוללת libmpv מוכן מראש (mpv 0.36 שנבנה עם `-Dgpl=false` ו-FFmpeg 6 שהוגדר עם `--enable-version3` בלי `--enable-gpl`, ולכן הספריות תחת LGPL) מ-[media-kit/libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build) גרסה v0.7.3 (sha256 `9bb168ec908b4801f4231f411e3278a0aea644a2b03ce375c880d2813ab7f949`). `scripts/make-app.sh` מוריד ומאמת אותו; קוד המקור של הרכיבים האלה זמין בפרויקטים שמקושרים כאן. החיפוש והאחסון משתמשים ב-[GRDB.swift](https://github.com/groue/GRDB.swift) (MIT). קטעי ההדגמה: "Sintel" © Blender Foundation, [CC-BY 3.0](https://durian.blender.org).

</div>
