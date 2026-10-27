"""Copy for the product pages (Download, Features, What's new), English and Hebrew. Imported by build.py, which renders it.
Facts here come from the release notes and the README; versions, file names and links are filled in by build.py so a release bump changes one place.
Add a release to CHANGES (newest first is not required: build.py sorts by date)."""

MONTHS = {
 "en": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
 "he": ["בינואר", "בפברואר", "במרץ", "באפריל", "במאי", "ביוני", "ביולי", "באוגוסט", "בספטמבר", "באוקטובר", "בנובמבר", "בדצמבר"],
}

UI = {
 "en": dict(crumb="IPTVMac", free="Free · GPL-3.0 · no account", rec="Recommended for your device", more="All releases on GitHub", src="Source code",
            mac="Mac", windows="Windows", android="Android", tv="Android TV", ios="iPhone and iPad", size="size", platforms="Platforms",
            home_aria="IPTVMac home", on="On"),
 "he": dict(crumb="IPTVMac", free="חינמי · GPL-3.0 · בלי חשבון", rec="מומלץ למכשיר שלך", more="כל הגרסאות ב-GitHub", src="קוד המקור",
            mac="Mac", windows="Windows", android="Android", tv="Android TV", ios="iPhone ו-iPad", size="גודל", platforms="פלטפורמות",
            home_aria="IPTVMac, דף הבית", on="ב-"),
}

# ---------- Download ----------
DOWNLOAD = {
 "en": dict(
  title="Download IPTVMac: Mac, Windows, Android and Android TV | Free IPTV player",
  desc="Download IPTVMac for free: the DMG for Mac (Apple Silicon, macOS 14+), the installer for Windows 10 and 11, the APK for Android phones and tablets, and the TV files for Android TV, Google TV and Fire TV. Checksummed, no account.",
  h1="Download IPTVMac", lede="One free player for your Mac, your PC, your phone and your TV. Pick your device; the app contains no ads and no tracking.",
  mac=dict(h="Mac", req="Apple Silicon (M1 or later), macOS 14 or later.", btn="Download the DMG", alt="Or install from Terminal in one line:",
           steps=["Open IPTVMac.dmg and drag the IPTVMac icon onto Applications.", "Open the app and add your Xtream Codes login or M3U link.", "That is all: the app updates itself."],
           note="Signed with an Apple Developer ID and notarized by Apple, so it opens with a normal double-click. The one-line command works for every version and checks the signature and SHA-256 for you."),
  android=dict(h="Android phone and tablet", req="Android 8 or later.", btn="Download the APK (arm64-v8a)", other="Other files:",
               steps=["Download the file on the phone and open it.", "Android asks to allow installs from your browser or Files app: allow it. If Play Protect warns about an app from outside the Play Store, choose Install anyway.", "Add your source. A banner tells you when a new version is out; install the new file over the old one and your data stays."],
               note="Not on the Play Store yet, so the install is a direct file. It is signed with the project's own key."),
  tv=dict(h="Android TV, Google TV, Fire TV", req="Android 8 or later. Works with the remote control; no touch screen needed.", btn32="Download 32-bit", btn64="Download 64-bit",
          steps=["On the TV, install the Downloader app and open it.", "Type the address of the file, or copy the file to a USB stick and open it with a file manager. Try the 32-bit file first; if the TV says it is not compatible, use the 64-bit one.", "Allow Downloader to install apps, then install and open IPTVMac. OK selects, Back goes up one level, and holding Back closes the app."],
          note="Installs directly for now (no store listing yet). Updates are manual: install the new file over the old one. There are no downloads or backup files on the TV version."),
  win=dict(h="Windows", req="Windows 10 or 11, 64-bit.", btn="Download the installer", portable="Or the portable zip (no install, unzip and run):",
           steps=["Open IPTVMac-Windows-setup.exe. It installs for your user only and needs no administrator rights.", "Windows may say it protected your PC: the app is not signed with a paid certificate yet. Choose More info, then Run anyway.", "Open IPTVMac and add your Xtream Codes login or M3U link. Space pauses, the arrows seek, F fills the screen."],
           note="Light by design: about {s} MB to download, and while it just sits open it uses almost no processor. Updates are manual for now: the app tells you when a new version is out, and you run the new installer over the old one."),
  ios=dict(h="iPhone and iPad", req="iOS 17 or later.", soon="Coming soon", body="The iPhone and iPad app is built and waiting for App Store review. You can build it from the source in the meantime.", btn="Build from source"),
  files_h="Which Android file?", files_p="Phones and tablets use one of the first three. TVs use the TV files. If unsure, take the one marked as the usual choice.",
  files_cols=("File", "For", "Size"),
  files=[("arm64-v8a", "Almost every phone and tablet made since 2017. The usual choice.", "arm64-v8a"), ("armeabi-v7a", "Older 32-bit phones and tablets.", "armeabi-v7a"),
         ("x86_64", "Emulators and some Chromebooks.", "x86_64"), ("tv-32bit", "TVs and boxes: runs on almost all of them, including most Fire TV sticks.", "tv-32bit"),
         ("tv-64bit", "TVs and boxes that need a 64-bit app (try it if 32-bit is refused).", "tv-64bit")],
  verify_h="Check what you downloaded",
  verify_p=["Every Android release lists the SHA-256 of each file in SHA256SUMS.txt, and the Mac release lists the SHA-256 of IPTVMac.dmg in its notes. Compare them with `shasum -a 256 <file>` on a Mac or Linux, or `certutil -hashfile <file> SHA256` on Windows.",
            "The Mac app is notarized by Apple (an automated malware scan, not a review of the app). In-app updates on the Mac are verified with a signature before they are installed."],
  older_h="Older versions and source", older_p="Every release stays on GitHub. IPTVMac is open source under GPL-3.0, so you can read the code or build it yourself.",
  disclaimer="IPTVMac is only a player. It includes no channels or content: use it with a source you are authorized to access.",
  mac_ver="Version", changelog="What is new in this version", sums="Checksums (SHA256SUMS.txt)",
  js_rec="Recommended for your device",
 ),
 "he": dict(
  title="הורדת IPTVMac: Mac, ‏Windows, ‏Android ו-Android TV | נגן IPTV חינמי",
  desc="הורדה חינמית של IPTVMac: קובץ DMG ל-Mac (‏Apple Silicon, ‏macOS 14 ומעלה), מתקין ל-Windows 10 ו-11, קובץ APK לטלפונים וטאבלטים של Android, וקבצי טלוויזיה ל-Android TV, ל-Google TV ול-Fire TV. עם סכומי בדיקה, בלי חשבון.",
  h1="הורדת IPTVMac", lede="נגן חינמי אחד ל-Mac, למחשב Windows, לטלפון ולטלוויזיה. בוחרים מכשיר; באפליקציה אין פרסומות ואין מעקב.",
  mac=dict(h="Mac", req="Apple Silicon (‏M1 ומעלה), ‏macOS 14 ומעלה.", btn="הורדת ה-DMG", alt="או התקנה מהטרמינל בשורה אחת:",
           steps=["פותחים את IPTVMac.dmg וגוררים את סמל IPTVMac אל Applications.", "פותחים את האפליקציה ומוסיפים כניסת Xtream Codes או קישור M3U.", "זהו: האפליקציה מתעדכנת לבד."],
           note="חתום ב-Apple Developer ID ומאושר על ידי Apple (notarized), ולכן נפתח בלחיצה כפולה רגילה. הפקודה בשורה אחת עובדת לכל גרסה ובודקת בשבילך את החתימה ואת ה-SHA-256."),
  android=dict(h="טלפון וטאבלט של Android", req="Android 8 ומעלה.", btn="הורדת ה-APK (‏arm64-v8a)", other="קבצים אחרים:",
               steps=["מורידים את הקובץ בטלפון ופותחים אותו.", "Android שואל אם לאשר התקנה מהדפדפן או מאפליקציית הקבצים: מאשרים. אם Play Protect מזהיר על אפליקציה מחוץ ל-Play Store, בוחרים \"התקן בכל זאת\".", "מוסיפים מקור. באנר מודיע כשיוצאת גרסה חדשה; מתקינים את הקובץ החדש מעל הישן והנתונים נשארים."],
               note="עוד לא ב-Play Store, ולכן ההתקנה היא מקובץ ישיר. הוא חתום במפתח של הפרויקט עצמו."),
  tv=dict(h="Android TV, ‏Google TV, ‏Fire TV", req="Android 8 ומעלה. עובד עם השלט; אין צורך במסך מגע.", btn32="הורדת 32 ביט", btn64="הורדת 64 ביט",
          steps=["בטלוויזיה מתקינים את האפליקציה Downloader ופותחים אותה.", "מקלידים את כתובת הקובץ, או מעתיקים את הקובץ לכונן USB ופותחים אותו במנהל קבצים. מנסים קודם את קובץ ה-32 ביט; אם הטלוויזיה אומרת שהוא לא תואם, משתמשים בקובץ ה-64 ביט.", "מאשרים ל-Downloader להתקין אפליקציות, ואז מתקינים ופותחים את IPTVMac. OK בוחר, Back עולה רמה אחת, ולחיצה ארוכה על Back סוגרת את האפליקציה."],
          note="בינתיים מתקינים ישירות (עוד אין רישום בחנות). העדכונים ידניים: מתקינים את הקובץ החדש מעל הישן. בגרסת הטלוויזיה אין הורדות ואין קבצי גיבוי."),
  win=dict(h="Windows", req="Windows 10 או 11, ‏64 ביט.", btn="הורדת המתקין", portable="או קובץ ה-zip הנייד (בלי התקנה, פותחים ומפעילים):",
           steps=["פותחים את IPTVMac-Windows-setup.exe. הוא מתקין למשתמש שלכם בלבד ולא צריך הרשאות מנהל.", "ייתכן ש-Windows יגיד שהגן על המחשב: האפליקציה עוד לא חתומה בתעודה בתשלום. בוחרים More info ואז Run anyway.", "פותחים את IPTVMac ומוסיפים כניסת Xtream Codes או קישור M3U. רווח עוצר, החיצים מדלגים, F ממלא את המסך."],
           note="קלה בכוונה: בערך {s}MB להורדה, ובזמן שהיא רק פתוחה היא כמעט לא צורכת מעבד. העדכונים ידניים בינתיים: האפליקציה מודיעה כשיצאה גרסה חדשה, ומריצים את המתקין החדש מעל הישן."),
  ios=dict(h="iPhone ו-iPad", req="iOS 17 ומעלה.", soon="בקרוב", body="אפליקציית ה-iPhone וה-iPad בנויה וממתינה לבדיקה ב-App Store. בינתיים אפשר לבנות אותה מקוד המקור.", btn="בנייה מקוד המקור"),
  files_h="איזה קובץ Android?", files_p="טלפונים וטאבלטים משתמשים באחד משלושת הראשונים. טלוויזיות משתמשות בקבצי הטלוויזיה. אם לא בטוחים, לוקחים את הקובץ שמסומן כבחירה הרגילה.",
  files_cols=("קובץ", "למי", "גודל"),
  files=[("arm64-v8a", "כמעט כל טלפון וטאבלט מ-2017 ואילך. הבחירה הרגילה.", "arm64-v8a"), ("armeabi-v7a", "טלפונים וטאבלטים ישנים של 32 ביט.", "armeabi-v7a"),
         ("x86_64", "אמולטורים וחלק מה-Chromebook.", "x86_64"), ("tv-32bit", "טלוויזיות וסטרימרים: רץ כמעט בכולם, כולל רוב ה-Fire TV Stick.", "tv-32bit"),
         ("tv-64bit", "טלוויזיות וסטרימרים שצריכים אפליקציית 64 ביט (מנסים אותו אם 32 ביט נדחה).", "tv-64bit")],
  verify_h="בדיקת הקובץ שהורדתם",
  verify_p=["בכל גרסה של Android מופיע ה-SHA-256 של כל קובץ ב-SHA256SUMS.txt, ובגרסת ה-Mac מופיע ה-SHA-256 של IPTVMac.dmg בהערות הגרסה. משווים אותו עם `shasum -a 256 <file>` ב-Mac או ב-Linux, או עם `certutil -hashfile <file> SHA256` ב-Windows.",
            "אפליקציית ה-Mac מאושרת על ידי Apple (notarized; סריקת תוכנות זדוניות אוטומטית, לא בדיקה של האפליקציה). עדכונים מתוך האפליקציה ב-Mac מאומתים בחתימה לפני ההתקנה."],
  older_h="גרסאות ישנות וקוד מקור", older_p="כל גרסה נשארת ב-GitHub. IPTVMac הוא קוד פתוח ברישיון GPL-3.0, ולכן אפשר לקרוא את הקוד או לבנות אותו בעצמכם.",
  disclaimer="IPTVMac הוא נגן בלבד. הוא לא כולל ערוצים או תוכן: משתמשים בו עם מקור שמותר לכם לגשת אליו.",
  mac_ver="גרסה", changelog="מה חדש בגרסה הזו", sums="סכומי בדיקה (SHA256SUMS.txt)",
  js_rec="מומלץ למכשיר שלך",
 ),
}

# ---------- Features ----------
# groups of (title, text, platforms); platforms is a tuple of keys from UI ("mac", "android", "tv") shown as small tags, or () when it holds everywhere
FEATURES = {
 "en": dict(
  title="IPTVMac features: search, player, Picture in Picture, catch-up and more",
  desc="Everything IPTVMac does: instant search over 100,000 items, a stable mpv player, Picture in Picture, catch-up, subtitles, several playlists, downloads, 31 languages. Mac, Windows, Android and Android TV.",
  h1="What IPTVMac does", lede="A player for your own Xtream Codes and M3U sources, built to be fast, stable and out of your way.",
  pic_alt="The IPTVMac window showing a wall of movie posters",
  groups=[
   ("Find it fast", [
     ("Search that keeps up", "Your library lives in a local SQLite database with full-text search, so results appear as you type, in well under a second for 100,000 items. Search inside a category, inside a section or everywhere; Hebrew, Arabic and Latin text all work.", ()),
     ("Details for movies and series", "Poster, year, rating, duration, genre, plot, director, cast and a trailer link, from your Xtream provider. Open them before you play, or while you watch without stopping the picture.", ()),
     ("Favorites and continue watching", "Favorites, a continue-watching row and every category with its count. The list remembers where you were when you come back.", ()),
   ]),
   ("Watch the way you like", [
     ("A player that does not give up", "Playback runs on mpv. It plays the broken TS and HLS streams that trip up system players, reconnects when a stream drops and uses hardware decoding.", ()),
     ("Speed, subtitles, audio tracks", "Speed from 0.25x to 4x on movies, episodes and catch-up, embedded and external subtitles, audio track choice, a sleep timer from 15 minutes to 2 hours and a skip step you set.", ()),
     ("Picture in Picture", "On the Mac, IPTVMac's own floating window stays on top of other apps and follows you across Spaces. On Android, the system Picture in Picture window.", ("mac", "android")),
     ("Catch-up and program guide", "Where your Xtream provider supports them: what is on now and next, and watching a program that already aired. A Live button jumps back to the current broadcast.", ()),
     ("A quality tag", "A small 4K, FHD, HD or SD tag next to the title, taken from the real size of the picture being played.", ()),
     ("Next episode, automatically", "When an episode ends, the next one starts after a 5-second countdown. You can turn it off.", ()),
     ("Seek preview", "Hover the progress bar and a small window shows the picture at that moment. It is always on for downloaded files and optional for streams.", ("mac",)),
     ("Touch gestures", "Double-tap to skip, swipe for volume and brightness, long-press for 2x, and a button to rotate the screen.", ("android",)),
     ("Made for the remote", "Arrows move, OK selects, Back goes up one level and holding Back closes the app. Up and Down change the channel in the player, and the media keys work.", ("tv",)),
     ("Made for the keyboard and mouse", "Space pauses, the arrows seek, Up and Down and the wheel change the volume, F fills the screen, Esc steps back, Page Up and Page Down change the channel. A click pauses, a double click fills the screen, and the pointer hides while you watch.", ("windows",)),
   ]),
   ("Your library", [
     ("Several playlists, one library", "Add as many Xtream Codes and M3U sources as you like, switch between them, or choose All playlists to search, favorite and continue watching across every one.", ()),
     ("Subscription expiry", "Settings shows when each Xtream subscription ends and how many days are left, when your provider shares it: orange in the last week, red once it ended.", ()),
     ("Sync progress", "While a playlist syncs, the status line shows how far it is, in percent.", ("android",)),
     ("Downloads for offline", "Download movies and episodes (whole seasons on Xtream series) to watch without a network.", ("mac", "android")),
     ("Backup and restore", "Playlists without passwords, favorites and history, in one file you can move to another device.", ()),
     ("Keep it tidy", "Hide categories by words and refresh playlists automatically, or when you choose.", ()),
   ]),
   ("Everywhere, and yours", [
     ("31 languages", "The whole interface in 31 languages, including right-to-left Hebrew and Arabic, generated from the same strings on every platform.", ()),
     ("Light and dark", "Follows your system or your choice.", ()),
     ("No account, no ads, no tracking", "Nothing is sent to the developer. The app talks only to the servers you add, and to GitHub to check for updates. The source code is public.", ()),
     ("Written for each platform", "Swift and SwiftUI on Mac and iPhone; Dart with Flutter on Windows, Android and Android TV, with a small C++ shell on Windows and a Kotlin layer on Android. The video on every one is decoded by the same compiled libmpv engine.", ()),
     ("Updates", "The Mac app updates itself, verifying each update with a signature. The Windows and Android apps show a banner when a new version is out and you install it yourself.", ("mac", "windows", "android")),
   ]),
  ],
  cta_h="Try it", cta_p="Free, open source and without an account.", cta_btn="Go to downloads",
 ),
 "he": dict(
  title="התכונות של IPTVMac: חיפוש, נגן, תמונה בתוך תמונה, צפייה בהיסטוריה ועוד",
  desc="כל מה ש-IPTVMac עושה: חיפוש מיידי על פני 100,000 פריטים, נגן mpv יציב, תמונה בתוך תמונה, צפייה בהיסטוריה, כתוביות, כמה רשימות, הורדות ו-31 שפות. Mac, ‏Windows, ‏Android ו-Android TV.",
  h1="מה IPTVMac עושה", lede="נגן למקורות Xtream Codes ו-M3U שלכם, שנבנה להיות מהיר, יציב ולא להפריע.",
  pic_alt="חלון IPTVMac עם קיר של פוסטרים של סרטים",
  groups=[
   ("למצוא מהר", [
     ("חיפוש שעומד בקצב", "הספרייה שלכם יושבת במסד נתונים מקומי עם חיפוש טקסט מלא, ולכן התוצאות מופיעות תוך כדי הקלדה, הרבה פחות משנייה על 100,000 פריטים. מחפשים בתוך קטגוריה, בתוך מדור או בכל מקום; עברית, ערבית ולטינית עובדות כולן.", ()),
     ("פרטים על סרטים וסדרות", "כרזה, שנה, דירוג, אורך, ז'אנר, תקציר, במאי, שחקנים וקישור לטריילר, מהספק של Xtream. פותחים אותם לפני ההפעלה, או תוך כדי צפייה בלי לעצור את התמונה.", ()),
     ("מועדפים והמשך צפייה", "מועדפים, שורה של המשך צפייה וכל קטגוריה עם הספירה שלה. הרשימה זוכרת איפה הייתם כשחוזרים אליה.", ()),
   ]),
   ("לצפות כמו שנוח לכם", [
     ("נגן שלא מוותר", "הניגון רץ על mpv. הוא מנגן את שידורי ה-TS וה-HLS השבורים שמפילים נגנים של המערכת, מתחבר מחדש כששידור נופל ומשתמש בפענוח חומרה.", ()),
     ("מהירות, כתוביות, ערוצי שמע", "מהירות מ-0.25x עד 4x בסרטים, בפרקים ובשידורים מהעבר, כתוביות מובנות וחיצוניות, בחירת ערוץ שמע, טיימר שינה מ-15 דקות עד שעתיים וקפיצה שאתם קובעים.", ()),
     ("תמונה בתוך תמונה", "ב-Mac, חלון צף משלו של IPTVMac נשאר מעל אפליקציות אחרות והולך איתכם בין Spaces. ב-Android, חלון התמונה בתוך תמונה של המערכת.", ("mac", "android")),
     ("צפייה בהיסטוריה ומדריך תוכניות", "איפה שהספק של Xtream תומך בכך: מה משודר עכשיו ומה אחר כך, וצפייה בתוכנית שכבר שודרה. כפתור Live קופץ בחזרה לשידור העכשווי.", ()),
     ("תג איכות", "תג קטן 4K, ‏FHD, ‏HD או SD ליד הכותרת, לפי הגודל האמיתי של התמונה שמתנגנת.", ()),
     ("הפרק הבא, אוטומטית", "כשפרק נגמר, הפרק הבא מתחיל אחרי ספירה לאחור של 5 שניות. אפשר לכבות את זה.", ()),
     ("תצוגה מקדימה בציר הזמן", "מעבירים את העכבר על פס ההתקדמות וחלון קטן מראה את התמונה באותו רגע. תמיד פועל בקבצים שהורדו, ואופציונלי בשידורים.", ("mac",)),
     ("מחוות מגע", "לחיצה כפולה לדילוג, החלקה לעוצמת קול ולבהירות, לחיצה ארוכה ל-2x וכפתור לסיבוב המסך.", ("android",)),
     ("נבנה לשלט", "החיצים מזיזים, OK בוחר, Back עולה רמה אחת ולחיצה ארוכה על Back סוגרת את האפליקציה. למעלה ולמטה מחליפים ערוץ בנגן, ומקשי המדיה עובדים.", ("tv",)),
     ("נבנה למקלדת ולעכבר", "רווח עוצר, החיצים מדלגים, למעלה ולמטה והגלגלת משנים עוצמת קול, F ממלא את המסך, Esc חוזר אחורה, ו-Page Up ו-Page Down מחליפים ערוץ. קליק עוצר, דאבל-קליק ממלא את המסך, והמצביע נעלם בזמן הצפייה.", ("windows",)),
   ]),
   ("הספרייה שלכם", [
     ("כמה רשימות, ספרייה אחת", "מוסיפים כמה מקורות Xtream Codes ו-M3U שרוצים, עוברים ביניהם, או בוחרים All playlists כדי לחפש, להוסיף למועדפים ולהמשיך לצפות בכולם יחד.", ()),
     ("תוקף המנוי", "בהגדרות מוצג מתי כל מנוי Xtream מסתיים וכמה ימים נשארו, כשהספק מספק את הנתון: כתום בשבוע האחרון, אדום אחרי שפג.", ()),
     ("התקדמות הסנכרון", "בזמן סנכרון של רשימה, שורת הסטטוס מראה כמה כבר הושלם, באחוזים.", ("android",)),
     ("הורדות לצפייה בלי רשת", "מורידים סרטים ופרקים (עונות שלמות בסדרות Xtream) כדי לצפות בלי רשת.", ("mac", "android")),
     ("גיבוי ושחזור", "רשימות בלי סיסמאות, מועדפים והיסטוריה, בקובץ אחד שאפשר להעביר למכשיר אחר.", ()),
     ("לשמור על סדר", "מסתירים קטגוריות לפי מילים ומרעננים רשימות אוטומטית, או כשאתם בוחרים.", ()),
   ]),
   ("בכל מקום, ושלכם", [
     ("31 שפות", "כל הממשק ב-31 שפות, כולל עברית וערבית מימין לשמאל, שנוצרות מאותן מחרוזות בכל פלטפורמה.", ()),
     ("בהיר וכהה", "לפי המערכת או לפי הבחירה שלכם.", ()),
     ("בלי חשבון, בלי פרסומות, בלי מעקב", "שום דבר לא נשלח למפתח. האפליקציה פונה רק לשרתים שהוספתם, ול-GitHub כדי לבדוק עדכונים. קוד המקור פומבי.", ()),
     ("נכתב לכל פלטפורמה", "Swift ו-SwiftUI ב-Mac וב-iPhone; Dart עם Flutter ב-Windows, ב-Android וב-Android TV, עם מעטפת C++ קטנה ב-Windows ושכבת Kotlin ב-Android. את הווידאו בכולן מפענח אותו מנוע libmpv מקומפל.", ()),
     ("עדכונים", "אפליקציית ה-Mac מתעדכנת לבד ומאמתת כל עדכון בחתימה. אפליקציות ה-Windows וה-Android מציגות באנר כשיוצאת גרסה חדשה, ומתקינים אותה בעצמכם.", ("mac", "windows", "android")),
   ]),
  ],
  cta_h="מנסים", cta_p="חינמי, קוד פתוח ובלי חשבון.", cta_btn="לדף ההורדות",
 ),
}

# ---------- What's new ----------
# (date, platform, version, link-tag, {en: [bullets], he: [bullets]}); platform is "mac" or "android"; the tag is the GitHub release tag
CHANGES = [
 ("2026-10-27", "windows", "1.0.0", "windows-v1.0.0", {
   "en": ["**The first version for Windows 10 and 11.** A light installer (it installs for your user, no administrator rights) or a portable zip. The same player, search and 31 languages as everywhere else.",
          "**Built for the keyboard and mouse:** Space pauses, the arrows seek, Up and Down and the wheel change the volume, F or F11 fills the screen, Esc steps back, a click pauses and a double click fills the screen.",
          "**Easy on the machine:** the display stays awake while a picture plays, video decoding is set to use the graphics card when the driver supports it, and an open app that you are not touching uses almost no processor.",
          "The app is not signed with a paid certificate yet, so Windows SmartScreen may ask you to choose More info and Run anyway."],
   "he": ["**הגרסה הראשונה ל-Windows 10 ו-11.** מתקין קל (מתקין למשתמש שלכם, בלי הרשאות מנהל) או קובץ zip נייד. אותו נגן, אותו חיפוש ואותן 31 שפות כמו בכל מקום.",
          "**נבנתה למקלדת ולעכבר:** רווח עוצר, החיצים מדלגים, למעלה ולמטה והגלגלת משנים עוצמת קול, F או F11 ממלא את המסך, Esc חוזר אחורה, קליק עוצר ודאבל-קליק ממלא את המסך.",
          "**עדינה למחשב:** המסך נשאר דולק בזמן שמתנגנת תמונה, פענוח הווידאו מוגדר להשתמש בכרטיס המסך כשהדרייבר תומך בכך, ואפליקציה פתוחה שאתם לא נוגעים בה כמעט לא צורכת מעבד.",
          "האפליקציה עוד לא חתומה בתעודה בתשלום, ולכן Windows SmartScreen עשוי לבקש לבחור More info ואז Run anyway."]}),
 ("2026-10-26", "android", "1.0.4", "android-v1.0.4", {
   "en": ["**The first version for Android TV, Google TV and Fire TV.** It works with a TV remote: arrows move, OK selects, Back goes up, and holding Back closes the app. A clear focus ring shows where you are.",
          "**In the player:** Left and Right seek, Up and Down change the channel, OK pauses and shows the controls, Menu or Info opens the details, and the media keys work.",
          "Separate 32-bit and 64-bit files for TVs, so each download is smaller.",
          "The welcome screen now says to use only sources you are authorized to access."],
   "he": ["**הגרסה הראשונה ל-Android TV, ל-Google TV ול-Fire TV.** היא עובדת עם שלט: החיצים מזיזים, OK בוחר, Back עולה, ולחיצה ארוכה על Back סוגרת את האפליקציה. מסגרת פוקוס ברורה מראה איפה אתם.",
          "**בנגן:** ימינה ושמאלה מדלגים, למעלה ולמטה מחליפים ערוץ, OK עוצר ומציג את הפקדים, Menu או Info פותח את הפרטים, ומקשי המדיה עובדים.",
          "קבצים נפרדים של 32 ביט ו-64 ביט לטלוויזיות, כדי שכל הורדה תהיה קטנה יותר.",
          "מסך הפתיחה אומר עכשיו להשתמש רק במקורות שמותר לכם לגשת אליהם."]}),
 ("2026-10-25", "mac", "0.9.3", "v0.9.3", {
   "en": ["**Quality tag in the player:** a small 4K, FHD, HD or SD tag next to the title, from the real size of the picture.",
          "**Details while you watch:** an info button in the player opens the movie or series details without stopping playback.",
          "**Subscription expiry:** Settings shows when each Xtream subscription ends and how many days are left, when the provider shares it."],
   "he": ["**תג איכות בנגן:** תג קטן 4K, ‏FHD, ‏HD או SD ליד הכותרת, לפי הגודל האמיתי של התמונה.",
          "**פרטים בזמן צפייה:** כפתור מידע בנגן פותח את פרטי הסרט או הסדרה בלי לעצור את הניגון.",
          "**תוקף המנוי:** בהגדרות מוצג מתי כל מנוי Xtream מסתיים וכמה ימים נשארו, כשהספק מספק את הנתון."]}),
 ("2026-10-25", "android", "1.0.3", "android-v1.0.3", {
   "en": ["**The app tells you when a new version is out.** A banner with a button to the release page; Settings has a switch and a Check for updates button. The install stays manual, and the check asks github.com at most every six hours.",
          "**Sync progress in percent** while a playlist syncs."],
   "he": ["**האפליקציה מודיעה כשיצאה גרסה חדשה.** באנר עם כפתור לעמוד הגרסה; בהגדרות יש מתג וכפתור \"בדוק עדכונים\". ההתקנה נשארת ידנית, והבדיקה פונה אל github.com לכל היותר אחת לשש שעות.",
          "**התקדמות הסנכרון באחוזים** בזמן סנכרון של רשימה."]}),
 ("2026-10-25", "android", "1.0.2", "android-v1.0.2", {
   "en": ["**Quality tag** in the player, next to the title.", "**Details while you watch:** the info button opens the details without stopping playback.", "**Subscription expiry** in Settings: orange within a week, red once it ended."],
   "he": ["**תג איכות** בנגן, ליד הכותרת.", "**פרטים בזמן צפייה:** כפתור המידע פותח את הפרטים בלי לעצור את הניגון.", "**תוקף המנוי** בהגדרות: כתום בשבוע האחרון, אדום אחרי שפג."]}),
 ("2026-10-14", "android", "1.0.1", "android-v1.0.1", {
   "en": ["**The list remembers where you were** after you leave a movie, a series or a channel, per section and category.", "**Time left for downloads:** each running download shows an estimate."],
   "he": ["**הרשימה זוכרת איפה הייתם** אחרי שיוצאים מסרט, מסדרה או מערוץ, לפי מדור וקטגוריה.", "**זמן שנותר להורדות:** כל הורדה פעילה מציגה הערכה."]}),
 ("2026-10-13", "mac", "0.9.2", "v0.9.2", {
   "en": ["**Live button in the player:** on a live channel it jumps back to the current broadcast; while watching a catch-up program, the same button returns to the channel."],
   "he": ["**כפתור Live בנגן:** בערוץ חי הוא קופץ לשידור העכשווי; בצפייה בשידור מהעבר אותו כפתור מחזיר לערוץ."]}),
 ("2026-10-13", "android", "1.0.0", "android-v1.0.0", {
   "en": ["**The first stable Android release.** Live, Movies and Series from M3U or Xtream; instant search; a touch player with gestures, speed, subtitles, a sleep timer and a Live button; Picture in Picture; sound that keeps playing with the screen off; downloads for offline viewing; backup and restore; 31 languages."],
   "he": ["**גרסת ה-Android היציבה הראשונה.** Live, סרטים וסדרות מ-M3U או Xtream; חיפוש מיידי; נגן מגע עם מחוות, מהירות, כתוביות, טיימר שינה וכפתור Live; תמונה בתוך תמונה; קול שממשיך כשהמסך כבוי; הורדות לצפייה בלי רשת; גיבוי ושחזור; 31 שפות."]}),
 ("2026-10-11", "mac", "0.9.1", "v0.9.1", {
   "en": ["**The first notarized release.** Signed with an Apple Developer ID and notarized by Apple, so the DMG opens with a normal double-click. Notarization is an automated malware scan, not a review of the app. Versions before 0.9.1 are not notarized.",
          "The one-line Terminal installer still works for every version, and in-app updates are unchanged."],
   "he": ["**הגרסה הראשונה המאושרת (notarized).** חתומה ב-Apple Developer ID ומאושרת על ידי Apple, ולכן ה-DMG נפתח בלחיצה כפולה רגילה. האישור הוא סריקת תוכנות זדוניות אוטומטית, לא בדיקה של האפליקציה. גרסאות לפני 0.9.1 לא מאושרות.",
          "ההתקנה בשורה אחת בטרמינל עדיין עובדת לכל גרסה, והעדכונים מתוך האפליקציה לא השתנו."]}),
 ("2026-10-08", "mac", "0.9.0", "v0.9.0", {
   "en": ["**Details for movies and series:** poster, year, rating, duration, genre, plot, director, cast and a trailer link, with Play, Favorite and Download buttons. They come from your Xtream provider and are cached for 14 days.",
          "**Preview on the seek bar:** hover the progress bar to see the picture at that moment. Always on for downloaded files; off by default for streams because it opens a second connection to your provider."],
   "he": ["**פרטים על סרטים וסדרות:** כרזה, שנה, דירוג, אורך, ז'אנר, תקציר, במאי, שחקנים וקישור לטריילר, עם כפתורי Play, מועדף והורדה. הם מגיעים מהספק של Xtream ונשמרים 14 יום.",
          "**תצוגה מקדימה בציר הזמן:** מעבירים את העכבר על פס ההתקדמות ורואים את התמונה באותו רגע. תמיד פועל בקבצים שהורדו; כבוי כברירת מחדל בשידורים כי הוא פותח חיבור שני לספק."]}),
 ("2026-10-07", "mac", "0.8.0", "v0.8.0", {
   "en": ["**A more polished look:** hover highlights, a calm loading skeleton during the first sync, clearer empty states, smoother download progress and a redesigned floating control bar in the player. Everything respects Reduce Motion."],
   "he": ["**מראה מלוטש יותר:** הדגשה במעבר עכבר, שלד טעינה רגוע בסנכרון הראשון, מצבי ריק ברורים יותר, התקדמות הורדה חלקה יותר ושורת פקדים צפה מעוצבת מחדש בנגן. הכול מכבד את ההגדרה Reduce Motion."]}),
]

CHANGELOG = {
 "en": dict(title="What's new in IPTVMac: release notes for Mac and Android", desc="Release notes for every IPTVMac version on Mac and Android, newest first: new features, fixes and changes.",
            h1="What's new", lede="Release notes for every version, newest first. The Mac and Android apps have their own version numbers.",
            filter=("All", "Mac", "Windows", "Android"), notes="Release notes on GitHub", older="Earlier releases (0.1 to 0.7) are listed on GitHub."),
 "he": dict(title="מה חדש ב-IPTVMac: הערות גרסה ל-Mac ול-Android", desc="הערות הגרסה של כל גרסת IPTVMac ב-Mac וב-Android, מהחדשה לישנה: תכונות חדשות, תיקונים ושינויים.",
            h1="מה חדש", lede="הערות גרסה לכל גרסה, מהחדשה לישנה. לאפליקציות ה-Mac וה-Android יש מספרי גרסה משלהן.",
            filter=("הכול", "Mac", "Windows", "Android"), notes="הערות הגרסה ב-GitHub", older="גרסאות מוקדמות (0.1 עד 0.7) מופיעות ב-GitHub."),
}

# ---------- second pass: hero, marquee, tabs, stats, chapters (used by the redesigned pages) ----------
DOWNLOAD["en"].update(
  hero=["Download", "IPTVMac", "for free."],
  main=dict(mac=("Download for Mac", "Version {v} · {s} MB · Apple Silicon, macOS 14+"), windows=("Download for Windows", "Version {v} · {s} MB installer · Windows 10 and 11, 64-bit"), android=("Download for Android", "Version {v} · {s} MB · Android 8+"),
            tv=("Download for Android TV", "32-bit file · {s} MB · Android 8+ · remote control")),
  cue="Every device",
  marquee=["Free", "Open source, GPL-3.0", "No account", "No ads", "No tracking", "31 languages", "Xtream Codes and M3U", "Mac, Windows, Android, Android TV", "Powered by mpv", "Picture in Picture"],
  pick_h="Choose your screen.", pick_p="The file, three steps and what to expect, for each device.",
  tabs=[("mac", "Mac", "Apple Silicon"), ("windows", "Windows", "Windows 10 and 11"), ("android", "Phone and tablet", "Android 8+"), ("tv", "TV", "Android TV, Google TV, Fire TV"), ("ios", "iPhone and iPad", "Coming soon")],
  alt_mac="IPTVMac on a Mac: a wall of movie posters", alt_win="IPTVMac on Windows 11: the welcome screen", alt_phone="IPTVMac on an Android phone: live channels with the program now and next", alt_tv="IPTVMac on Android TV: live channels with the remote-control focus ring",
  help_h="Need a hand?", help_p="Step-by-step guides, and a support page that never asks for your login.", help_links=[("Read the guides", "#guides"), ("Support", "support/")],
)
DOWNLOAD["he"].update(
  hero=["הורדת", "IPTVMac", "בחינם."],
  main=dict(mac=("הורדה ל-Mac", "גרסה {v} · {s}MB · Apple Silicon, ‏macOS 14+"), windows=("הורדה ל-Windows", "גרסה {v} · מתקין {s}MB · Windows 10 ו-11, ‏64 ביט"), android=("הורדה ל-Android", "גרסה {v} · {s}MB · Android 8+"),
            tv=("הורדה ל-Android TV", "קובץ 32 ביט · {s}MB · Android 8+ · שלט")),
  cue="כל המכשירים",
  marquee=["חינמי", "קוד פתוח, GPL-3.0", "בלי חשבון", "בלי פרסומות", "בלי מעקב", "31 שפות", "Xtream Codes ו-M3U", "Mac, ‏Windows, ‏Android, ‏Android TV", "מבוסס על mpv", "תמונה בתוך תמונה"],
  pick_h="בוחרים מסך.", pick_p="הקובץ, שלושה שלבים ומה לצפות לו, לכל מכשיר.",
  tabs=[("mac", "Mac", "Apple Silicon"), ("windows", "Windows", "Windows 10 ו-11"), ("android", "טלפון וטאבלט", "Android 8+"), ("tv", "טלוויזיה", "Android TV, ‏Google TV, ‏Fire TV"), ("ios", "iPhone ו-iPad", "בקרוב")],
  alt_mac="IPTVMac ב-Mac: קיר של פוסטרים של סרטים", alt_win="IPTVMac ב-Windows 11: מסך הפתיחה", alt_phone="IPTVMac בטלפון Android: ערוצים חיים עם התוכנית עכשיו והבאה", alt_tv="IPTVMac ב-Android TV: ערוצים חיים עם מסגרת הפוקוס של השלט",
  help_h="צריכים יד?", help_p="מדריכים צעד אחר צעד, ודף תמיכה שלא מבקש לעולם את פרטי הכניסה שלכם.", help_links=[("למדריכים", "#guides"), ("תמיכה", "support/")],
)

FEATURES["en"].update(
  hero=["What", "IPTVMac", "does."], cue="See the details",
  stats=[("100000", "items searched in well under a second", ""), ("31", "languages, including right to left", ""), ("4", "times faster playback, down to a quarter speed", "×"), ("0", "accounts, ads or trackers", "")],
  chapters=[("Search, and details, in a blink.", "02-search-1800", "IPTVMac search results grouped into live channels, movies and series"),
            ("A player that does not give up.", "05-player-1800", "The IPTVMac player in full screen with the controls fading in"),
            ("Your whole library, kept tidy.", "07-downloads", "The IPTVMac downloads screen with progress and time left"),
            ("Everywhere, and yours.", "tv-categories", "IPTVMac on Android TV: the category screen with the focus ring")],
)
FEATURES["he"].update(
  hero=["מה", "IPTVMac", "עושה."], cue="לפרטים",
  stats=[("100000", "פריטים בחיפוש, הרבה פחות משנייה", ""), ("31", "שפות, כולל מימין לשמאל", ""), ("4", "פעמים מהר יותר, ועד רבע מהירות", "×"), ("0", "חשבונות, פרסומות או מעקבים", "")],
  chapters=[("חיפוש ופרטים, בהבזק.", "02-search-1800", "תוצאות חיפוש ב-IPTVMac מקובצות לערוצים חיים, סרטים וסדרות"),
            ("נגן שלא מוותר.", "05-player-1800", "הנגן של IPTVMac במסך מלא, והפקדים מופיעים בהדרגה"),
            ("כל הספרייה, מסודרת.", "07-downloads", "מסך ההורדות של IPTVMac עם התקדמות וזמן שנותר"),
            ("בכל מקום, ושלכם.", "tv-categories", "IPTVMac ב-Android TV: מסך הקטגוריות עם מסגרת הפוקוס")],
)
CHANGELOG["en"].update(hero=["What's", "new."], latest="Latest", cue="All releases", get="Download")
CHANGELOG["he"].update(hero=["מה", "חדש."], latest="העדכנית", cue="כל הגרסאות", get="הורדה")
