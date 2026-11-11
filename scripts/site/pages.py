"""Copy for the product pages (Download, Features, What's new), English and Hebrew. Imported by build.py, which renders it.
Facts here come from the release notes and the README; versions, file names and links are filled in by build.py so a release bump changes one place.
Add a release to CHANGES (newest first is not required: build.py sorts by date)."""

MONTHS = {
 "en": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
 "he": ["בינואר", "בפברואר", "במרץ", "באפריל", "במאי", "ביוני", "ביולי", "באוגוסט", "בספטמבר", "באוקטובר", "בנובמבר", "בדצמבר"],
}

UI = {
 "en": dict(crumb="IPTVMac", free="Free · GPL-3.0 · no account", rec="Recommended for your device", more="All releases on GitHub", src="Source code",
            mac="Mac", windows="Windows", android="Android", tv="Android TV", ios="iPhone and iPad", free_word="Free", size="size", platforms="Platforms",
            home_aria="IPTVMac home", on="On"),
 "he": dict(crumb="IPTVMac", free="חינמי · GPL-3.0 · בלי חשבון", rec="מומלץ למכשיר שלך", more="כל הגרסאות ב-GitHub", src="קוד המקור",
            mac="Mac", windows="Windows", android="Android", tv="Android TV", ios="iPhone ו-iPad", free_word="חינם", size="גודל", platforms="פלטפורמות",
            home_aria="IPTVMac, דף הבית", on="ב-"),
}

# ---------- Download ----------
DOWNLOAD = {
 "en": dict(
  title="Download IPTVMac: the free IPTV player for every device",
  desc="Download IPTVMac free: the DMG for Mac, the installer for Windows 10 and 11, the APK for Android phones and TVs, and the iPhone and iPad app.",
  h1="Download IPTVMac", lede="One free player for your Mac, your PC, your phone and your TV. Pick your device; the app contains no ads and no tracking.",
  mac=dict(h="Mac", req="Apple Silicon (M1 or later), macOS 14 or later.", btn="Download the DMG", alt="Or install from Terminal in one line:",
           steps=["Open IPTVMac.dmg and drag the IPTVMac icon onto Applications.", "Open the app and add your Xtream Codes login or M3U link.", "That is all: the app updates itself."],
           note="Signed with an Apple Developer ID and notarized by Apple, so it opens with a normal double-click. The one-line command works for every version and checks the signature and SHA-256 for you."),
  android=dict(h="Android phone and tablet", req="Android 8 or later.", btn="Download the APK (arm64-v8a)", other="Other files:",
               steps=["Download the file on the phone and open it.", "Android asks to allow installs from your browser or Files app: allow it. If Play Protect warns about an app from outside the Play Store, choose Install anyway.", "Add your source. A banner tells you when a new version is out: tap Update now and the app downloads and installs it (Android asks you to confirm), and your data stays."],
               note="Not on the Play Store yet, so the install is a direct file. It is signed with the project's own key."),
  tv=dict(h="Android TV, Google TV, Fire TV", req="Android 8 or later. Works with the remote control; no touch screen needed.", btn32="Download 32-bit", btn64="Download 64-bit",
          steps=["On the TV, install the Downloader app and open it.", "Type the address of the file, or copy the file to a USB stick and open it with a file manager. Try the 32-bit file first; if the TV says it is not compatible, use the 64-bit one.", "Allow Downloader to install apps, then install and open IPTVMac. OK selects, Back goes up one level, and holding Back closes the app."],
          note="Installs directly for now (no store listing yet). Updates are manual: install the new file over the old one. There are no downloads or backup files on the TV version."),
  win=dict(h="Windows", req="Windows 10 or 11, 64-bit.", btn="Download the installer", portable="Or the portable zip (no install, unzip and run):",
           steps=["Open IPTVMac-Windows-setup.exe. It installs for your user only and needs no administrator rights.", "Windows may say it protected your PC: the app is not signed with a paid certificate yet. Choose More info, then Run anyway.", "Open IPTVMac and add your Xtream Codes login or M3U link. Space pauses, the arrows seek, F fills the screen."],
           note="Light by design: about {s} MB to download, and while it just sits open it uses almost no processor. Updates are manual for now: the app tells you when a new version is out, and you run the new installer over the old one."),
  ios=dict(h="iPhone and iPad", req="iOS 17 or later.", soon="On the App Store", body="Completely free: no ads, no subscription, no in-app purchases and no account. 31 languages. Needs iOS 17 or later. The source is also here if you want to build it yourself.", btn="Download on the App Store"),
  files_h="Which Android file?", files_p="Phones and tablets use one of the first three. TVs use the TV files. If unsure, take the one marked as the usual choice.",
  files_cols=("File", "For", "Size"),
  store_h="App Store or GitHub?", store_p="The iPhone and iPad app is on the App Store, and its full source code is on GitHub. It is the same app; these are the differences.",
  store_cols=("", "App Store", "Built from GitHub"),
  store_rows=[
    ("Install", "One tap in the App Store.", "You build it: a Mac with Xcode, then scripts/ios-setup.sh, then run it on your iPhone or iPad (see docs/PLATFORMS.md)."),
    ("Updates", "Automatic, through the App Store, after Apple has reviewed each version.", "When you choose: download the newest source and build again. GitHub is usually a little ahead of the App Store."),
    ("Signing", "The project's own Apple developer account.", "Your own Apple ID. With a free Apple account the app runs for 7 days and you install it again; a paid account lasts a year."),
    ("What is inside", "The same code as on GitHub. No ads, no tracking, no purchases.", "The same code. No ads, no tracking, no purchases."),
    ("Price", "Free.", "Free (GPL-3.0)."),
  ],
  store_note="Mac, Windows, Android and Android TV are not in an app store: the files on GitHub are the only versions. The Mac and Android apps update themselves from GitHub.",
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
  title="הורדת IPTVMac: נגן ה-IPTV החינמי לכל מכשיר",
  desc="הורדה חינמית של IPTVMac: ‏DMG ל-Mac, מתקין ל-Windows 10 ו-11, ‏APK לטלפונים ולטלוויזיות Android, והאפליקציה ל-iPhone ול-iPad.",
  h1="הורדת IPTVMac", lede="נגן חינמי אחד ל-Mac, למחשב Windows, לטלפון ולטלוויזיה. בוחרים מכשיר; באפליקציה אין פרסומות ואין מעקב.",
  mac=dict(h="Mac", req="Apple Silicon (‏M1 ומעלה), ‏macOS 14 ומעלה.", btn="הורדת ה-DMG", alt="או התקנה מהטרמינל בשורה אחת:",
           steps=["פותחים את IPTVMac.dmg וגוררים את סמל IPTVMac אל Applications.", "פותחים את האפליקציה ומוסיפים כניסת Xtream Codes או קישור M3U.", "זהו: האפליקציה מתעדכנת לבד."],
           note="חתום ב-Apple Developer ID ומאושר על ידי Apple (notarized), ולכן נפתח בלחיצה כפולה רגילה. הפקודה בשורה אחת עובדת לכל גרסה ובודקת בשבילך את החתימה ואת ה-SHA-256."),
  android=dict(h="טלפון וטאבלט של Android", req="Android 8 ומעלה.", btn="הורדת ה-APK (‏arm64-v8a)", other="קבצים אחרים:",
               steps=["מורידים את הקובץ בטלפון ופותחים אותו.", "Android שואל אם לאשר התקנה מהדפדפן או מאפליקציית הקבצים: מאשרים. אם Play Protect מזהיר על אפליקציה מחוץ ל-Play Store, בוחרים \"התקן בכל זאת\".", "מוסיפים מקור. באנר מודיע כשיוצאת גרסה חדשה: לוחצים \"עדכן עכשיו\" והאפליקציה מורידה ומתקינה אותה (Android מבקש אישור), והנתונים נשארים."],
               note="עוד לא ב-Play Store, ולכן ההתקנה היא מקובץ ישיר. הוא חתום במפתח של הפרויקט עצמו."),
  tv=dict(h="Android TV, ‏Google TV, ‏Fire TV", req="Android 8 ומעלה. עובד עם השלט; אין צורך במסך מגע.", btn32="הורדת 32 ביט", btn64="הורדת 64 ביט",
          steps=["בטלוויזיה מתקינים את האפליקציה Downloader ופותחים אותה.", "מקלידים את כתובת הקובץ, או מעתיקים את הקובץ לכונן USB ופותחים אותו במנהל קבצים. מנסים קודם את קובץ ה-32 ביט; אם הטלוויזיה אומרת שהוא לא תואם, משתמשים בקובץ ה-64 ביט.", "מאשרים ל-Downloader להתקין אפליקציות, ואז מתקינים ופותחים את IPTVMac. OK בוחר, Back עולה רמה אחת, ולחיצה ארוכה על Back סוגרת את האפליקציה."],
          note="בינתיים מתקינים ישירות (עוד אין רישום בחנות). העדכונים ידניים: מתקינים את הקובץ החדש מעל הישן. בגרסת הטלוויזיה אין הורדות ואין קבצי גיבוי."),
  win=dict(h="Windows", req="Windows 10 או 11, ‏64 ביט.", btn="הורדת המתקין", portable="או קובץ ה-zip הנייד (בלי התקנה, פותחים ומפעילים):",
           steps=["פותחים את IPTVMac-Windows-setup.exe. הוא מתקין למשתמש שלכם בלבד ולא צריך הרשאות מנהל.", "ייתכן ש-Windows יגיד שהגן על המחשב: האפליקציה עוד לא חתומה בתעודה בתשלום. בוחרים More info ואז Run anyway.", "פותחים את IPTVMac ומוסיפים כניסת Xtream Codes או קישור M3U. רווח עוצר, החיצים מדלגים, F ממלא את המסך."],
           note="קלה בכוונה: בערך {s}MB להורדה, ובזמן שהיא רק פתוחה היא כמעט לא צורכת מעבד. העדכונים ידניים בינתיים: האפליקציה מודיעה כשיצאה גרסה חדשה, ומריצים את המתקין החדש מעל הישן."),
  ios=dict(h="iPhone ו-iPad", req="iOS 17 ומעלה.", soon="ב-App Store", body="חינמית לגמרי: בלי פרסומות, בלי מנוי, בלי רכישות בתוך האפליקציה ובלי חשבון. 31 שפות. נדרש iOS 17 ומעלה. קוד המקור גם הוא כאן, למי שרוצה לבנות בעצמו.", btn="הורדה מה-App Store"),
  files_h="איזה קובץ Android?", files_p="טלפונים וטאבלטים משתמשים באחד משלושת הראשונים. טלוויזיות משתמשות בקבצי הטלוויזיה. אם לא בטוחים, לוקחים את הקובץ שמסומן כבחירה הרגילה.",
  files_cols=("קובץ", "למי", "גודל"),
  store_h="App Store או GitHub?", store_p="אפליקציית ה-iPhone וה-iPad נמצאת ב-App Store, וקוד המקור המלא שלה ב-GitHub. זו אותה אפליקציה; אלה ההבדלים.",
  store_cols=("", "App Store", "בנייה מ-GitHub"),
  store_rows=[
    ("התקנה", "לחיצה אחת ב-App Store.", "בונים בעצמכם: Mac עם Xcode, אחר כך scripts/ios-setup.sh, ומריצים על ה-iPhone או ה-iPad (ראו docs/PLATFORMS.md)."),
    ("עדכונים", "אוטומטיים דרך ה-App Store, אחרי ש-Apple בדקה כל גרסה.", "מתי שתרצו: מורידים את קוד המקור החדש ובונים שוב. ב-GitHub בדרך כלל יש קצת יותר מאשר ב-App Store."),
    ("חתימה", "חשבון המפתחים של Apple של הפרויקט.", "ה-Apple ID שלכם. עם חשבון Apple חינמי האפליקציה רצה 7 ימים ואז מתקינים שוב; חשבון בתשלום מחזיק שנה."),
    ("מה בפנים", "אותו קוד כמו ב-GitHub. בלי פרסומות, בלי מעקב ובלי רכישות.", "אותו קוד. בלי פרסומות, בלי מעקב ובלי רכישות."),
    ("מחיר", "חינם.", "חינם (GPL-3.0)."),
  ],
  store_note="Mac, Windows, Android ו-Android TV לא נמצאות בחנות אפליקציות: הקבצים ב-GitHub הם הגרסאות היחידות. אפליקציות ה-Mac וה-Android מתעדכנות מעצמן מ-GitHub.",
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
  title="IPTVMac features: search, player, Picture in Picture",
  desc="Everything IPTVMac does: instant search over 100,000 items, a stable mpv player, Picture in Picture, catch-up, subtitles, several playlists and downloads.",
  h1="What IPTVMac does", lede="A player for your own Xtream Codes and M3U sources, built to be fast, stable and out of your way.",
  pic_alt="The IPTVMac window showing a wall of movie posters",
  groups=[
   ("Find it fast", [
     ("Search that keeps up", "Your library lives in a local SQLite database with full-text search, so results appear as you type, in well under a second for 100,000 items. Search inside a category, inside a section or everywhere; Hebrew, Arabic and Latin text all work.", ()),
     ("Details for movies and series", "Poster, year, rating, duration, genre, plot, director, cast and a trailer link, from your Xtream provider. Open them before you play, or while you watch without stopping the picture.", ()),
     ("Favorites and continue watching", "Favorites, and a continue-watching page that says the episode and the minutes left of each series and resumes it at the minute you stopped. Every category shows its count, and the list remembers where you were when you come back.", ()),
   ]),
   ("Watch the way you like", [
     ("A player that does not give up", "Playback runs on mpv. It plays the broken TS and HLS streams that trip up system players, reconnects when a stream drops and uses hardware decoding.", ()),
     ("Speed, subtitles, audio tracks", "Speed from 0.25x to 4x on movies, episodes and catch-up, embedded and external subtitles, audio track choice, a sleep timer from 15 minutes to 2 hours and a skip step you set.", ()),
     ("Picture in Picture", "On the Mac, IPTVMac's own floating window stays on top of other apps and follows you across Spaces. On Android, the system Picture in Picture window.", ("mac", "android")),
     ("Catch-up and program guide", "Where your Xtream provider supports them: what is on now and next, and watching a program that already aired. A Live button jumps back to the current broadcast.", ()),
     ("Skip the intro and the credits", "Mark where a series' intro ends and where its credits start once, and every episode of it offers Skip intro and Skip credits (the credits button starts the next episode).", ()),
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
     ("Downloads for offline", "Download movies and episodes (whole seasons on Xtream series) to watch without a network. On Windows they go to a folder of their own inside your Downloads folder, and they download while the app is open.", ("mac", "windows", "android")),
     ("Backup and restore", "Playlists without passwords, favorites and history, in one file you can move to another device.", ()),
     ("Keep it tidy", "Hide categories by words and refresh playlists automatically, or when you choose.", ()),
   ]),
   ("Everywhere, and yours", [
     ("31 languages", "The whole interface in 31 languages, including right-to-left Hebrew and Arabic, generated from the same strings on every platform.", ()),
     ("Light and dark", "Follows your system or your choice.", ()),
     ("No account, no ads, no tracking", "Nothing is sent to the developer. The app talks only to the servers you add, and to GitHub to check for updates. The source code is public.", ()),
     ("Written for each platform", "Swift and SwiftUI on Mac and iPhone; Dart with Flutter on Windows, Android and Android TV, with a small C++ shell on Windows and a Kotlin layer on Android. The video on every one is decoded by the same compiled libmpv engine.", ()),
     ("Updates", "The Mac app and the Android phone app update from inside the app (the Mac verifies each update with a signature; Android asks you to confirm and only accepts a file signed with the same key). The Windows and Android TV apps show a banner when a new version is out and you install it yourself.", ("mac", "windows", "android")),
   ]),
  ],
  cta_h="Try it", cta_p="Free, open source and without an account.", cta_btn="Go to downloads",
 ),
 "he": dict(
  title="התכונות של IPTVMac: חיפוש, נגן, תמונה בתוך תמונה",
  desc="כל מה ש-IPTVMac עושה: חיפוש מיידי ב-100,000 פריטים, נגן mpv יציב, תמונה בתוך תמונה, צפייה בהיסטוריה, כתוביות, כמה רשימות והורדות.",
  h1="מה IPTVMac עושה", lede="נגן למקורות Xtream Codes ו-M3U שלכם, שנבנה להיות מהיר, יציב ולא להפריע.",
  pic_alt="חלון IPTVMac עם קיר של פוסטרים של סרטים",
  groups=[
   ("למצוא מהר", [
     ("חיפוש שעומד בקצב", "הספרייה שלכם יושבת במסד נתונים מקומי עם חיפוש טקסט מלא, ולכן התוצאות מופיעות תוך כדי הקלדה, הרבה פחות משנייה על 100,000 פריטים. מחפשים בתוך קטגוריה, בתוך מדור או בכל מקום; עברית, ערבית ולטינית עובדות כולן.", ()),
     ("פרטים על סרטים וסדרות", "כרזה, שנה, דירוג, אורך, ז'אנר, תקציר, במאי, שחקנים וקישור לטריילר, מהספק של Xtream. פותחים אותם לפני ההפעלה, או תוך כדי צפייה בלי לעצור את התמונה.", ()),
     ("מועדפים והמשך צפייה", "מועדפים, ודף המשך צפייה שאומר לכל סדרה את הפרק ואת הדקות שנשארו וממשיך אותה בדקה שבה עצרתם. כל קטגוריה מוצגת עם הספירה שלה, והרשימה זוכרת איפה הייתם כשחוזרים אליה.", ()),
   ]),
   ("לצפות כמו שנוח לכם", [
     ("נגן שלא מוותר", "הניגון רץ על mpv. הוא מנגן את שידורי ה-TS וה-HLS השבורים שמפילים נגנים של המערכת, מתחבר מחדש כששידור נופל ומשתמש בפענוח חומרה.", ()),
     ("מהירות, כתוביות, ערוצי שמע", "מהירות מ-0.25x עד 4x בסרטים, בפרקים ובשידורים מהעבר, כתוביות מובנות וחיצוניות, בחירת ערוץ שמע, טיימר שינה מ-15 דקות עד שעתיים וקפיצה שאתם קובעים.", ()),
     ("תמונה בתוך תמונה", "ב-Mac, חלון צף משלו של IPTVMac נשאר מעל אפליקציות אחרות והולך איתכם בין Spaces. ב-Android, חלון התמונה בתוך תמונה של המערכת.", ("mac", "android")),
     ("צפייה בהיסטוריה ומדריך תוכניות", "איפה שהספק של Xtream תומך בכך: מה משודר עכשיו ומה אחר כך, וצפייה בתוכנית שכבר שודרה. כפתור Live קופץ בחזרה לשידור העכשווי.", ()),
     ("דילוג על הפתיח ועל הקרדיטים", "מסמנים פעם אחת איפה הפתיח של סדרה נגמר ואיפה הקרדיטים מתחילים, ובכל פרק שלה מופיעים \"דלג על הפתיח\" ו\"דלג על הקרדיטים\" (כפתור הקרדיטים מתחיל את הפרק הבא).", ()),
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
     ("הורדות לצפייה בלי רשת", "מורידים סרטים ופרקים (עונות שלמות בסדרות Xtream) כדי לצפות בלי רשת. ב-Windows הם נשמרים בתיקייה משלהם בתוך תיקיית ההורדות, ויורדים כל עוד האפליקציה פתוחה.", ("mac", "windows", "android")),
     ("גיבוי ושחזור", "רשימות בלי סיסמאות, מועדפים והיסטוריה, בקובץ אחד שאפשר להעביר למכשיר אחר.", ()),
     ("לשמור על סדר", "מסתירים קטגוריות לפי מילים ומרעננים רשימות אוטומטית, או כשאתם בוחרים.", ()),
   ]),
   ("בכל מקום, ושלכם", [
     ("31 שפות", "כל הממשק ב-31 שפות, כולל עברית וערבית מימין לשמאל, שנוצרות מאותן מחרוזות בכל פלטפורמה.", ()),
     ("בהיר וכהה", "לפי המערכת או לפי הבחירה שלכם.", ()),
     ("בלי חשבון, בלי פרסומות, בלי מעקב", "שום דבר לא נשלח למפתח. האפליקציה פונה רק לשרתים שהוספתם, ול-GitHub כדי לבדוק עדכונים. קוד המקור פומבי.", ()),
     ("נכתב לכל פלטפורמה", "Swift ו-SwiftUI ב-Mac וב-iPhone; Dart עם Flutter ב-Windows, ב-Android וב-Android TV, עם מעטפת C++ קטנה ב-Windows ושכבת Kotlin ב-Android. את הווידאו בכולן מפענח אותו מנוע libmpv מקומפל.", ()),
     ("עדכונים", "אפליקציית ה-Mac ואפליקציית ה-Android לטלפון מתעדכנות מתוך האפליקציה (ה-Mac מאמת כל עדכון בחתימה; Android מבקש אישור ומקבל רק קובץ שחתום באותו מפתח). אפליקציות ה-Windows וה-Android TV מציגות באנר כשיוצאת גרסה חדשה, ומתקינים אותה בעצמכם.", ("mac", "windows", "android")),
   ]),
  ],
  cta_h="מנסים", cta_p="חינמי, קוד פתוח ובלי חשבון.", cta_btn="לדף ההורדות",
 ),
}

# ---------- What's new ----------
# (date, platform, version, link-tag, {en: [bullets], he: [bullets]}); platform is "mac" or "android"; the tag is the GitHub release tag
CHANGES = [
 ("2026-11-07", "mac", "0.9.8", "v0.9.8", {
   "en": ["**Full screen in Light Mode, second fix:** a panel could flash on and off during full-screen playback. The window is now set up for full-screen video once, when full screen starts, instead of on every window update."],
   "he": ["**מסך מלא ב-Light Mode, תיקון שני:** פאנל יכול היה להבהב בזמן ניגון במסך מלא. עכשיו החלון מוכן לווידאו במסך מלא פעם אחת, כשהמסך המלא מתחיל, ולא בכל עדכון של החלון."]}),
 ("2026-11-06", "mac", "0.9.7", "v0.9.7", {
   "en": ["**Sort favorites by name:** Settings > General > \"Sort favorites by name (A–Z)\". Case does not matter and numbers count by value; it is off by default.",
          "**Full screen in Light Mode:** the window is dark while a video plays in full screen, so a thin white line no longer shows above the picture."],
   "he": ["**מיון המועדפים לפי שם:** הגדרות > כללי > \"מיון המועדפים לפי שם (א–ת)\". לא משנה אות גדולה או קטנה, ומספרים נספרים לפי ערכם; כבוי כברירת מחדל.",
          "**מסך מלא ב-Light Mode:** החלון כהה בזמן ניגון במסך מלא, ולכן קו לבן דק כבר לא נחשף מעל התמונה."]}),
 ("2026-11-06", "windows", "1.0.4", "windows-v1.0.4", {
   "en": ["**Sort favorites by name:** Settings > \"Sort favorites by name (A–Z)\". It is off by default."],
   "he": ["**מיון המועדפים לפי שם:** הגדרות > \"מיון המועדפים לפי שם (א–ת)\". כבוי כברירת מחדל."]}),
 ("2026-11-06", "android", "1.0.7", "android-v1.0.7", {
   "en": ["**Sort favorites by name:** Settings > \"Sort favorites by name (A–Z)\". It is off by default.",
          "Phones and tablets with 1.0.6 update to this version from inside the app (Update now)."],
   "he": ["**מיון המועדפים לפי שם:** הגדרות > \"מיון המועדפים לפי שם (א–ת)\". כבוי כברירת מחדל.",
          "טלפונים וטאבלטים עם 1.0.6 מתעדכנים לגרסה הזאת מתוך האפליקציה (עדכן עכשיו)."]}),
 ("2026-11-01", "mac", "0.9.6", "v0.9.6", {
   "en": ["**Remove a title from Continue watching:** right-click it and choose \"Remove from Continue watching\". Nothing is deleted; it comes back if you watch it again.",
          "**Episode lists show what you watched:** a check mark, a bar with \"N min left\" on the one you stopped halfway, and \"Up next\" on the following episode.",
          "**Speed and subtitles are kept per series:** the next episode starts with the speed and the subtitle language you chose."],
   "he": ["**הסרת כותר מ\"המשך לצפות\":** קליק ימני ובחירה ב\"הסר מהמשך צפייה\". שום דבר לא נמחק; הכותר חוזר אם תצפו בו שוב.",
          "**רשימת הפרקים מראה מה ראיתם:** וי, פס עם \"N min left\" על הפרק שעצרתם באמצעו, ו\"הבא בתור\" על הפרק שאחריו.",
          "**מהירות וכתוביות נשמרות לכל סדרה:** הפרק הבא מתחיל במהירות ובשפת הכתוביות שבחרתם."]}),
 ("2026-11-01", "windows", "1.0.3", "windows-v1.0.3", {
   "en": ["**Remove a title from Continue watching:** right-click it and choose \"Remove from Continue watching\". It comes back if you watch it again.",
          "**Speed and subtitles are kept per series**, a small speed menu over the speed button, and minutes left on the episode list."],
   "he": ["**הסרת כותר מ\"המשך לצפות\":** קליק ימני ובחירה ב\"הסר מהמשך צפייה\". הכותר חוזר אם תצפו בו שוב.",
          "**מהירות וכתוביות נשמרות לכל סדרה**, תפריט מהירות קטן מעל כפתור המהירות, ודקות שנשארו ברשימת הפרקים."]}),
 ("2026-11-01", "android", "1.0.6", "android-v1.0.6", {
   "en": ["**The app updates itself (phones and tablets).** \"Update now\" downloads the right file for your phone and starts the Android installer, which asks you to confirm. The next version is the first to update this way; TVs still use the release page.",
          "**Remove a title from Continue watching:** long-press it and choose \"Remove from Continue watching\". It comes back if you watch it again.",
          "**Speed and subtitles are kept per series**, a small speed menu instead of a tall list, and minutes left on the episode list."],
   "he": ["**האפליקציה מתעדכנת מתוך עצמה (טלפונים וטאבלטים).** \"עדכן עכשיו\" מוריד את הקובץ המתאים לטלפון ומפעיל את מתקין Android, שמבקש אישור. הגרסה הבאה היא הראשונה שמתעדכנת כך; בטלוויזיות עדיין משתמשים בעמוד הגרסה.",
          "**הסרת כותר מ\"המשך לצפות\":** לחיצה ארוכה ובחירה ב\"הסר מהמשך צפייה\". הכותר חוזר אם תצפו בו שוב.",
          "**מהירות וכתוביות נשמרות לכל סדרה**, תפריט מהירות קטן במקום רשימה גבוהה, ודקות שנשארו ברשימת הפרקים."]}),
 ("2026-11-01", "mac", "0.9.5", "v0.9.5", {
   "en": ["**Continue watching shows where you are in a series:** the episode and the minutes left, for example \"S2 E5 · 23 min left\", with a progress bar, and one click resumes that episode at the minute you stopped.",
          "**Skip intro and skip credits.** You mark the intro and the credits once per series, from the new \"Intro and credits\" menu in the player; every episode of the series then shows the buttons. The S key takes the button."],
   "he": ["**\"המשך לצפות\" מראה איפה אתם בסדרה:** הפרק והדקות שנשארו, למשל \"S2 E5 · 23 min left\", עם פס התקדמות, ולחיצה אחת ממשיכה את אותו פרק בדקה שבה עצרתם.",
          "**דילוג על הפתיח ועל הקרדיטים.** מסמנים פעם אחת לכל סדרה את הפתיח ואת הקרדיטים, מהתפריט החדש \"פתיח וקרדיטים\" בנגן; מכאן בכל פרק של הסדרה מופיעים הכפתורים. המקש S לוחץ על הכפתור."]}),
 ("2026-11-01", "windows", "1.0.2", "windows-v1.0.2", {
   "en": ["**Continue watching shows where you are in a series**, and a click resumes that episode at the minute you stopped.",
          "**Skip intro and skip credits**, marked once per series from the \"Intro and credits\" menu in the player. The S key takes the button."],
   "he": ["**\"המשך לצפות\" מראה איפה אתם בסדרה**, ולחיצה ממשיכה את אותו פרק בדקה שבה עצרתם.",
          "**דילוג על הפתיח ועל הקרדיטים**, מסמנים פעם אחת לכל סדרה מהתפריט \"פתיח וקרדיטים\" בנגן. המקש S לוחץ על הכפתור."]}),
 ("2026-11-01", "android", "1.0.5", "android-v1.0.5", {
   "en": ["**Continue watching shows where you are in a series:** the episode and the minutes left, with a progress bar, and a tap resumes that episode at the minute you stopped.",
          "**Skip intro and skip credits**, marked once per series from the \"Intro and credits\" menu in the player. On a TV, OK takes the button while it is on the screen."],
   "he": ["**\"המשך לצפות\" מראה איפה אתם בסדרה:** הפרק והדקות שנשארו, עם פס התקדמות, ונגיעה ממשיכה את אותו פרק בדקה שבה עצרתם.",
          "**דילוג על הפתיח ועל הקרדיטים**, מסמנים פעם אחת לכל סדרה מהתפריט \"פתיח וקרדיטים\" בנגן. בטלוויזיה OK לוחץ על הכפתור כשהוא על המסך."]}),
 ("2026-10-29", "mac", "0.9.4", "v0.9.4", {
   "en": ["**Sync progress in percent.** While a playlist syncs, the status line shows how far it is.",
          "**Every toolbar button is also in the View menu**, with shortcuts: Live, Movies and Series with ⌘1, ⌘2 and ⌘3, Refresh with ⌘R, Downloads with ⌥⌘L.",
          "**Smaller fixes to the window:** the section control follows the width of its labels in every language, the sidebar categories have a title, a channel's star stays next to its name on a wide window, the Downloads window fits what it holds, and its buttons have names for VoiceOver.",
          "The welcome screen says to use only sources you are authorized to access."],
   "he": ["**התקדמות הסנכרון באחוזים.** בזמן סנכרון של רשימה, שורת הסטטוס מראה כמה כבר הושלם.",
          "**כל כפתור בסרגל הכלים נמצא גם בתפריט View**, עם קיצורים: Live, ‏Movies ו-Series ב-⌘1, ‏⌘2 ו-⌘3, רענון ב-⌘R, והורדות ב-⌥⌘L.",
          "**תיקונים קטנים בחלון:** בורר הסעיפים מתאים את רוחבו לתוויות בכל שפה, לקטגוריות ב-sidebar יש כותרת, הכוכב של ערוץ נשאר ליד השם בחלון רחב, חלון ההורדות מתאים לתוכן שלו, ולכפתורים שלו יש שמות ל-VoiceOver.",
          "מסך הפתיחה אומר להשתמש רק במקורות שמותר לך לגשת אליהם."]}),
 ("2026-10-28", "windows", "1.0.1", "windows-v1.0.1", {
   "en": ["**Downloads for offline viewing.** Download movies and episodes (whole seasons on Xtream series) from the details sheet, and watch them without a network. The files go to `Downloads\\IPTVMac` in your user folder, so they are easy to find, copy and keep. A download goes on while the app is open and picks up again the next time you start it.",
          "The download engine is tested on a real Windows machine: a file is fetched from a local server, saved to disk and checked for size."],
   "he": ["**הורדות לצפייה בלי רשת.** מורידים סרטים ופרקים (עונות שלמות בסדרות Xtream) מגיליון הפרטים, וצופים בלי רשת. הקבצים נשמרים ב-`Downloads\\IPTVMac` בתיקיית המשתמש, כך שקל למצוא אותם, להעתיק ולשמור. הורדה נמשכת כל עוד האפליקציה פתוחה וממשיכה כשמפעילים אותה שוב.",
          "מנוע ההורדה נבדק על מחשב Windows אמיתי: קובץ נמשך משרת מקומי, נשמר בדיסק וגודלו נבדק."]}),
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
 "en": dict(title="What's new in IPTVMac: release notes for Mac and Android", desc="Release notes for every IPTVMac version on Mac, Windows and Android, newest first: the new features, the fixes and the changes, with the date of each release.",
            h1="What's new", lede="Release notes for every version, newest first. The Mac and Android apps have their own version numbers.",
            filter=("All", "Mac", "Windows", "Android"), notes="Release notes on GitHub", older="Earlier releases (0.1 to 0.7) are listed on GitHub."),
 "he": dict(title="מה חדש ב-IPTVMac: הערות גרסה ל-Mac ול-Android", desc="הערות הגרסה של כל גרסת IPTVMac ב-Mac, ב-Windows וב-Android, מהחדשה לישנה: התכונות החדשות, התיקונים והשינויים, עם התאריך של כל גרסה.",
            h1="מה חדש", lede="הערות גרסה לכל גרסה, מהחדשה לישנה. לאפליקציות ה-Mac וה-Android יש מספרי גרסה משלהן.",
            filter=("הכול", "Mac", "Windows", "Android"), notes="הערות הגרסה ב-GitHub", older="גרסאות מוקדמות (0.1 עד 0.7) מופיעות ב-GitHub."),
}

# ---------- second pass: hero, marquee, tabs, stats, chapters (used by the redesigned pages) ----------
DOWNLOAD["en"].update(
  hero=["Download", "IPTVMac", "for free."],
  main=dict(mac=("Download for Mac", "Version {v} · {s} MB · Apple Silicon, macOS 14+"), windows=("Download for Windows", "Version {v} · {s} MB installer · Windows 10 and 11, 64-bit"), android=("Download for Android", "Version {v} · {s} MB · Android 8+"),
            tv=("Download for Android TV", "32-bit file · {s} MB · Android 8+ · remote control"), ios=("Download on the App Store", "Free · iOS 17 or later · iPhone and iPad")),
  cue="Every device",
  marquee=["Free", "Open source, GPL-3.0", "No account", "No ads", "No tracking", "31 languages", "Xtream Codes and M3U", "Mac, Windows, Android, Android TV", "Powered by mpv", "Picture in Picture"],
  pick_h="Choose your screen.", pick_p="The file, three steps and what to expect, for each device.",
  tabs=[("mac", "Mac", "Apple Silicon"), ("windows", "Windows", "Windows 10 and 11"), ("android", "Phone and tablet", "Android 8+"), ("tv", "TV", "Android TV, Google TV, Fire TV"), ("ios", "iPhone and iPad", "App Store")],
  alt_mac="IPTVMac on a Mac: a wall of movie posters", alt_win="IPTVMac on Windows 11: the welcome screen", alt_phone="IPTVMac on an Android phone: live channels with the program now and next", alt_tv="IPTVMac on Android TV: live channels with the remote-control focus ring",
  help_h="Need a hand?", help_p="Step-by-step guides, and a support page that never asks for your login.", help_links=[("Read the guides", "#guides"), ("Support", "support/")],
)
DOWNLOAD["he"].update(
  hero=["הורדת", "IPTVMac", "בחינם."],
  main=dict(mac=("הורדה ל-Mac", "גרסה {v} · {s}MB · Apple Silicon, ‏macOS 14 ומעלה"), windows=("הורדה ל-Windows", "גרסה {v} · מתקין {s}MB · Windows 10 ו-11, ‏64 ביט"), android=("הורדה ל-Android", "גרסה {v} · {s}MB · Android 8 ומעלה"),
            tv=("הורדה ל-Android TV", "קובץ 32 ביט · {s}MB · Android 8 ומעלה · שלט"), ios=("הורדה מ-App Store", "חינמית · iOS 17 ומעלה · iPhone ו-iPad")),
  cue="כל המכשירים",
  marquee=["חינמי", "קוד פתוח, GPL-3.0", "בלי חשבון", "בלי פרסומות", "בלי מעקב", "31 שפות", "Xtream Codes ו-M3U", "Mac, ‏Windows, ‏Android, ‏Android TV", "מבוסס על mpv", "תמונה בתוך תמונה"],
  pick_h="בוחרים מסך.", pick_p="הקובץ, שלושה שלבים ומה לצפות לו, לכל מכשיר.",
  tabs=[("mac", "Mac", "Apple Silicon"), ("windows", "Windows", "Windows 10 ו-11"), ("android", "טלפון וטאבלט", "Android 8+"), ("tv", "טלוויזיה", "Android TV, ‏Google TV, ‏Fire TV"), ("ios", "iPhone ו-iPad", "App Store")],
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


# ---- home page, "On air" redesign (phase 2): the zapping hero, the programme guide of reasons, the ON AIR sign ----
# Every claim below has a row in scripts/site/claims.md.
ONAIR = {
 "en": dict(
  channels=[("1", "Movies"), ("2", "Live"), ("3", "Series"), ("4", "Search")],
  on_air="On air",
  alt_live="IPTVMac on a Mac: the live channel list with the program now and next",
  alt_series="IPTVMac on a Mac: a series with its seasons and episodes",
  zap_hint="Scroll to change the channel",
  guide_h="Tonight on IPTVMac.",
  guide_p="Seven reasons it beats the player you have now. Each one is something you can check.",
  guide_now="Now",
  guide=[
   ("20:00", "Free. Really.", "No ads, no subscription, no in-app purchases and no account. Open source under the GPL-3.0."),
   ("20:30", "Nothing phones home.", "No analytics. The app talks only to the servers you add, and to GitHub for updates. Your passwords stay on your device."),
   ("21:00", "Found as you type.", "Each search stays under a quarter of a second on a library of 100,000 titles, in our own tests."),
   ("21:30", "Plays the streams others drop.", "The mpv engine plays broken TS and HLS streams, reconnects when a live channel drops, and decodes video in hardware."),
   ("22:00", "Made for each screen.", "Swift on Mac, iPhone and iPad. Flutter and Kotlin on Android, Android TV and Windows. No Electron, no web view."),
   ("22:30", "Everything a viewer needs.", "Continue watching at the right episode and minute, skip intro and credits, Picture in Picture. Catch-up on the Mac; downloads on Mac, Windows and Android."),
   ("23:00", "In your language.", "31 languages, each in its own script, right to left included."),
  ],
  guide_more="Every feature",
  guide_why="Each reason, with the proof",
  sign="IPTVMac",
 ),
 "he": dict(
  channels=[("1", "סרטים"), ("2", "שידור חי"), ("3", "סדרות"), ("4", "חיפוש")],
  on_air="משדר",
  alt_live="IPTVMac ב-Mac: רשימת הערוצים החיים עם התוכנית עכשיו והבאה",
  alt_series="IPTVMac ב-Mac: סדרה עם העונות והפרקים שלה",
  zap_hint="גוללים כדי להחליף ערוץ",
  guide_h="הערב ב-IPTVMac.",
  guide_p="שבע סיבות שבגללן הוא עדיף על הנגן שיש לכם עכשיו. כל אחת מהן אפשר לבדוק.",
  guide_now="עכשיו",
  guide=[
   ("20:00", "חינם. באמת.", "בלי פרסומות, בלי מנוי, בלי רכישות בתוך האפליקציה ובלי חשבון. קוד פתוח ברישיון GPL‑3.0."),
   ("20:30", "שום דבר לא מדווח הביתה.", "בלי מעקב ובלי אנליטיקה. האפליקציה מדברת רק עם השרתים שהוספתם, ועם GitHub לעדכונים. הסיסמאות נשארות במכשיר."),
   ("21:00", "נמצא תוך כדי הקלדה.", "כל חיפוש לוקח פחות מרבע שנייה בספרייה של 100,000 כותרים, בבדיקות שלנו."),
   ("21:30", "מנגן את מה שנגנים אחרים מפילים.", "מנוע mpv מנגן שידורי TS ו-HLS שבורים, מתחבר מחדש כשערוץ חי נופל, ומפענח וידאו בחומרה."),
   ("22:00", "נבנה לכל מסך.", "Swift ב-Mac, ב-iPhone וב-iPad. ‏Flutter ו-Kotlin ב-Android, ב-Android TV וב-Windows. בלי Electron ובלי דפדפן מוסתר."),
   ("22:30", "כל מה שצופה צריך.", "המשך צפייה בפרק ובדקה הנכונים, דילוג על הפתיח והכתוביות, תמונה בתוך תמונה. צפייה בהיסטוריה ב-Mac; הורדות ב-Mac, ב-Windows וב-Android."),
   ("23:00", "בשפה שלכם.", "31 שפות, כל אחת בכתב שלה, כולל מימין לשמאל."),
  ],
  guide_more="כל התכונות",
  guide_why="כל סיבה, עם ההוכחה",
  sign="IPTVMac",
 ),
}


# ---- platform pages (phase 3): one page per device, each with its own title, description, H1, install steps and questions ----
# Install steps, requirements and notes come from DOWNLOAD[code][<platform>]; sizes and versions from build.py. Claims: scripts/site/claims.md.
PLATFORMS = {
 "en": dict(
  install_h="Install", features_h="What you get", faq_h="Questions", next_h="Read next", why="Why IPTVMac beats the player you have now", all="All downloads", crumb="Platforms",
  mac=dict(title="IPTV Player for Mac: Xtream Codes and M3U | IPTVMac",
    desc="A native IPTV player for Apple Silicon Macs: Xtream Codes and M3U, instant search, Picture in Picture and catch-up. Free, no ads, signed and notarized.",
    h1=["IPTV on your Mac,", "the native way."], name="IPTVMac for Mac",
    lede="Written in Swift and SwiftUI for Apple Silicon. It plays what your provider sends, finds any title as you type, and updates itself.",
    feats=[("A window that stays on top.", "Picture in Picture keeps a channel in a floating window over every app and every Space while you browse for something else.", "06-pip", "IPTVMac on a Mac: a channel playing in the floating Picture in Picture window"),
           ("Speed, subtitles and a sleep timer.", "Movies and episodes play from 0.25x to 4x. Embedded and external subtitles, audio tracks, fit, fill or stretch, and a sleep timer from 15 minutes to 2 hours.", "05-player", "IPTVMac on a Mac: the player with its controls"),
           ("Downloads for the road.", "Save movies and whole seasons to a folder you choose and watch them without a connection.", "07-downloads", "IPTVMac on a Mac: the downloads list")],
    faq=[("Which Macs does it run on?", "Apple Silicon Macs (M1 or later) with macOS 14 or later. Intel Macs are not supported."),
         ("Does macOS open it without a warning?", "Yes. Releases are signed with an Apple Developer ID and notarized by Apple, so the DMG opens with a normal double-click."),
         ("How does it update?", "By itself. It checks GitHub for a new release, verifies the signed checksum, and replaces itself in place.")],
    guides=["xtream-codes-on-mac", "m3u-playlist-on-mac", "picture-in-picture-iptv-mac"]),
  windows=dict(title="Free IPTV Player for Windows 10 and 11 | IPTVMac",
    desc="A light IPTV player for Windows 10 and 11: Xtream Codes and M3U, instant search, keyboard shortcuts and downloads. Free, with no ads and no account.",
    h1=["IPTV on Windows,", "without the bloat."], name="IPTVMac for Windows",
    lede="Built with Flutter and a small C++ shell. About {size} MB, made for the keyboard and mouse, and almost no processor use while it sits open.",
    feats=[("Keyboard first.", "Space pauses, the arrows seek, F fills the screen. Every control is also one click away.", "", ""),
           ("Your whole library, searched as you type.", "Live, Movies and Series from Xtream Codes or M3U, with search inside a category, a section or everywhere.", "", ""),
           ("Downloads for offline viewing.", "Save movies and episodes and play them without a connection.", "", "")],
    faq=[("Why does Windows SmartScreen warn about it?", "The app is not signed with a paid code-signing certificate yet. Choose More info, then Run anyway. The source code is public on GitHub."),
         ("Do I need administrator rights?", "No. The installer installs for your user only. There is also a portable zip that runs without installing."),
         ("How does it update?", "The app tells you when a new version is out. Run the new installer over the old one; your playlists and settings stay.")],
    guides=[]),
  iphone=dict(title="Free IPTV App for iPhone and iPad | IPTVMac",
    desc="IPTVMac for iPhone and iPad on the App Store: Xtream Codes and M3U, instant search, Picture in Picture and continue watching. Free, no ads, no account.",
    h1=["IPTV on iPhone", "and iPad. Free."], name="IPTVMac for iPhone and iPad",
    lede="The same player and search as on the Mac, made for touch. On the App Store, with no ads, no subscription and no in-app purchases.",
    feats=[("Movies and series as posters.", "Browse the whole library by category, or search it as you type.", "ios-movies", "IPTVMac on an iPhone: a grid of movie posters"),
           ("Live, with what is on now.", "Each channel shows the program that is on now, where your provider sends a guide.", "ios-live", "IPTVMac on an iPhone: the live channel list"),
           ("Pick up where you stopped.", "Continue watching keeps the episode and the minute. Picture in Picture keeps playing while you use other apps.", "ios-details", "IPTVMac on an iPhone: the details of a title")],
    faq=[("Is it really free?", "Yes. No ads, no subscription, no in-app purchases and no account."),
         ("Which devices does it run on?", "iPhone and iPad with iOS 17 or later."),
         ("Is the App Store version different from the one on GitHub?", "It is the same app and the same code. The App Store version installs with one tap and updates itself after Apple has reviewed each version.")],
    guides=[]),
  android=dict(title="Free IPTV Player for Android (APK) | IPTVMac",
    desc="IPTVMac for Android phones and tablets: Xtream Codes and M3U, a touch player with gestures, Picture in Picture and downloads. Free APK, no ads, no account.",
    h1=["IPTV on Android,", "in your pocket."], name="IPTVMac for Android",
    lede="A touch player with gestures, sound that keeps playing with the screen off, Picture in Picture and downloads for offline viewing. One free APK, no account.",
    feats=[("A player made for your thumbs.", "Double-tap to skip, swipe for volume and brightness, hold for 2x. Subtitles, audio tracks and a sleep timer are one tap away.", "android-live", "IPTVMac on an Android phone: live channels with the program now and next"),
           ("Keeps playing.", "Sound goes on with the screen off, with controls in the notification, and Picture in Picture keeps the picture while you use other apps.", "android-movies", "IPTVMac on an Android phone: a grid of movie posters"),
           ("Series, season by season.", "Continue watching at the right episode and minute, skip the intro and the credits, and download episodes for later.", "android-series", "IPTVMac on an Android phone: a series with its episodes")],
    faq=[("Why is it not on the Play Store?", "It is installed from a direct file for now, signed with the project's own key. Android asks you to allow the install once."),
         ("Which file do I need?", "The arm64-v8a file suits almost every phone and tablet made since 2017. The download page lists the others."),
         ("How does it update?", "A banner tells you when a new version is out. Tap Update now: the app downloads and installs it, and your data stays.")],
    guides=[]),
  tv=dict(title="IPTV App for Android TV, Google TV and Fire TV | IPTVMac",
    desc="IPTVMac for Android TV, Google TV and Fire TV: browse Live, Movies and Series with the remote, from Xtream Codes or M3U. Free, no ads, installed with Downloader.",
    h1=["IPTV on your TV,", "with the remote."], name="IPTVMac for Android TV",
    lede="The Android app with a layout built for the remote control. It runs on Android TV, Google TV and Fire TV boxes and sticks.",
    feats=[("Made for the remote.", "A clear focus ring, OK to select, Back to go up one level. No touch screen needed.", "tv-live", "IPTVMac on Android TV: the channel list with the remote-control focus ring"),
           ("The whole library on the big screen.", "Live, Movies and Series, with categories and search.", "tv-movies", "IPTVMac on Android TV: a row of movie posters"),
           ("Details before you press play.", "Plot, year and rating where your provider sends them.", "tv-details", "IPTVMac on Android TV: the details of a movie")],
    faq=[("How do I install it on a Fire TV?", "Install the Downloader app from the Amazon store, type the address of the file, allow Downloader to install apps, then open IPTVMac."),
         ("32-bit or 64-bit?", "Try the 32-bit file first: it runs on almost every TV and box. If the TV says it is not compatible, use the 64-bit one."),
         ("How does it update?", "Manually for now: install the new file over the old one.")],
    guides=[]),
 ),
 "he": dict(
  install_h="התקנה", features_h="מה מקבלים", faq_h="שאלות", next_h="להמשך קריאה", why="למה IPTVMac עדיף על הנגן שיש לכם עכשיו", all="כל ההורדות", crumb="פלטפורמות",
  mac=dict(title="נגן IPTV ל-Mac: ‏Xtream Codes ו-M3U | IPTVMac",
    desc="נגן IPTV מקורי למחשבי Mac עם Apple Silicon: ‏Xtream Codes ו-M3U, חיפוש מיידי, תמונה בתוך תמונה וצפייה בהיסטוריה. חינם, בלי פרסומות, חתום ומאושר על ידי Apple.",
    h1=["IPTV ב-Mac,", "בדרך המקורית."], name="IPTVMac ל-Mac",
    lede="כתוב ב-Swift וב-SwiftUI למחשבי Apple Silicon. מנגן את מה שהספק שולח, מוצא כל כותר תוך כדי הקלדה, ומתעדכן לבד.",
    feats=[("חלון שנשאר למעלה.", "תמונה בתוך תמונה משאירה ערוץ בחלון צף מעל כל אפליקציה ובכל Space, בזמן שמחפשים משהו אחר.", "06-pip", "IPTVMac ב-Mac: ערוץ מתנגן בחלון הצף של תמונה בתוך תמונה"),
           ("מהירות, כתוביות וטיימר שינה.", "סרטים ופרקים מתנגנים במהירות מ-0.25x עד 4x. כתוביות מוטמעות וחיצוניות, רצועות שמע, התאמה, מילוי או מתיחה, וטיימר שינה מ-15 דקות עד שעתיים.", "05-player", "IPTVMac ב-Mac: הנגן עם הפקדים שלו"),
           ("הורדות לדרך.", "שומרים סרטים ועונות שלמות לתיקייה שבוחרים, וצופים בהם בלי חיבור.", "07-downloads", "IPTVMac ב-Mac: רשימת ההורדות")],
    faq=[("על אילו מחשבי Mac זה עובד?", "מחשבי Mac עם Apple Silicon ‏(M1 ומעלה) ו-macOS 14 ומעלה. מחשבי Intel לא נתמכים."),
         ("האם macOS פותחת את האפליקציה בלי אזהרה?", "כן. הגרסאות חתומות ב-Developer ID של Apple ומאושרות על ידי Apple, כך שה-DMG נפתח בלחיצה כפולה רגילה."),
         ("איך היא מתעדכנת?", "לבד. היא בודקת ב-GitHub אם יצאה גרסה חדשה, מאמתת את סכום הבדיקה החתום, ומחליפה את עצמה במקום.")],
    guides=["xtream-codes-on-mac", "m3u-playlist-on-mac", "picture-in-picture-iptv-mac"]),
  windows=dict(title="נגן IPTV חינמי ל-Windows 10 ו-11 | IPTVMac",
    desc="נגן IPTV קל ל-Windows 10 ו-11: ‏Xtream Codes ו-M3U, חיפוש מיידי, קיצורי מקלדת והורדות. חינם, בלי פרסומות ובלי חשבון, ומשקל של עשרות מגה-בייט בלבד.",
    h1=["IPTV ב-Windows,", "בלי משקל מיותר."], name="IPTVMac ל-Windows",
    lede="בנוי ב-Flutter עם מעטפת C++ קטנה. בערך {size}MB, נוח למקלדת ולעכבר, וכמעט לא צורך מעבד בזמן שהוא פתוח.",
    feats=[("קודם כל מקלדת.", "רווח עוצר, החיצים מדלגים, F ממלא את המסך. וכל פקד נמצא גם במרחק לחיצה.", "", ""),
           ("כל הספרייה, בחיפוש תוך כדי הקלדה.", "שידור חי, סרטים וסדרות מ-Xtream Codes או M3U, עם חיפוש בקטגוריה, בחלק או בכל מקום.", "", ""),
           ("הורדות לצפייה בלי רשת.", "שומרים סרטים ופרקים ומנגנים אותם בלי חיבור.", "", "")],
    faq=[("למה Windows SmartScreen מזהיר?", "האפליקציה עוד לא חתומה בתעודת חתימת קוד בתשלום. בוחרים More info ואז Run anyway. קוד המקור פתוח ב-GitHub."),
         ("צריך הרשאות מנהל?", "לא. המתקין מתקין למשתמש שלכם בלבד. יש גם zip נייד שרץ בלי התקנה."),
         ("איך מתעדכנים?", "האפליקציה מודיעה כשיוצאת גרסה חדשה. מריצים את המתקין החדש מעל הישן, והרשימות וההגדרות נשארות.")],
    guides=[]),
  iphone=dict(title="אפליקציית IPTV חינמית ל-iPhone ול-iPad | IPTVMac",
    desc="IPTVMac ל-iPhone ול-iPad ב-App Store: ‏Xtream Codes ו-M3U, חיפוש מיידי, תמונה בתוך תמונה והמשך צפייה. חינם לגמרי, בלי פרסומות ובלי חשבון.",
    h1=["IPTV ב-iPhone", "וב-iPad. חינם."], name="IPTVMac ל-iPhone ול-iPad",
    lede="אותו נגן ואותו חיפוש כמו ב-Mac, מותאמים למגע. ב-App Store, בלי פרסומות, בלי מנוי ובלי רכישות בתוך האפליקציה.",
    feats=[("סרטים וסדרות כפוסטרים.", "מדפדפים בכל הספרייה לפי קטגוריה, או מחפשים תוך כדי הקלדה.", "ios-movies", "IPTVMac ב-iPhone: רשת של פוסטרים של סרטים"),
           ("שידור חי, עם מה שמשודר עכשיו.", "כל ערוץ מציג את התוכנית שמשודרת עכשיו, כשהספק שולח לוח שידורים.", "ios-live", "IPTVMac ב-iPhone: רשימת הערוצים החיים"),
           ("ממשיכים מאיפה שעצרתם.", "המשך צפייה זוכר את הפרק ואת הדקה. תמונה בתוך תמונה ממשיכה לנגן בזמן שמשתמשים באפליקציות אחרות.", "ios-details", "IPTVMac ב-iPhone: פרטי כותר")],
    faq=[("זה באמת חינם?", "כן. בלי פרסומות, בלי מנוי, בלי רכישות בתוך האפליקציה ובלי חשבון."),
         ("על אילו מכשירים זה עובד?", "iPhone ו-iPad עם iOS 17 ומעלה."),
         ("האם גרסת ה-App Store שונה מזו שב-GitHub?", "זו אותה אפליקציה ואותו קוד. גרסת ה-App Store מותקנת בלחיצה אחת ומתעדכנת מעצמה אחרי ש-Apple בדקה כל גרסה.")],
    guides=[]),
  android=dict(title="נגן IPTV חינמי ל-Android ‏(APK) | IPTVMac",
    desc="IPTVMac לטלפונים וטאבלטים של Android: ‏Xtream Codes ו-M3U, נגן מגע עם מחוות, תמונה בתוך תמונה והורדות. קובץ APK חינמי, בלי פרסומות ובלי חשבון.",
    h1=["IPTV ב-Android,", "בכיס."], name="IPTVMac ל-Android",
    lede="נגן מגע עם מחוות, קול שממשיך כשהמסך כבוי, תמונה בתוך תמונה והורדות לצפייה בלי רשת. קובץ APK אחד, חינמי, בלי חשבון.",
    feats=[("נגן שנבנה לאגודלים.", "הקשה כפולה לדילוג, החלקה לווליום ולבהירות, לחיצה ארוכה ל-2x. כתוביות, רצועות שמע וטיימר שינה במרחק נגיעה.", "android-live", "IPTVMac בטלפון Android: ערוצים חיים עם התוכנית עכשיו והבאה"),
           ("ממשיך לנגן.", "הקול ממשיך כשהמסך כבוי, עם פקדים בהתראה, ותמונה בתוך תמונה שומרת על התמונה בזמן שמשתמשים באפליקציות אחרות.", "android-movies", "IPTVMac בטלפון Android: רשת של פוסטרים של סרטים"),
           ("סדרות, עונה אחרי עונה.", "המשך צפייה בפרק ובדקה הנכונים, דילוג על הפתיח והכתוביות, והורדת פרקים למועד מאוחר יותר.", "android-series", "IPTVMac בטלפון Android: סדרה עם הפרקים שלה")],
    faq=[("למה זה לא ב-Play Store?", "בינתיים מתקינים מקובץ ישיר, חתום במפתח של הפרויקט. Android מבקש לאשר את ההתקנה פעם אחת."),
         ("איזה קובץ צריך?", "הקובץ arm64-v8a מתאים לכמעט כל טלפון וטאבלט מ-2017 ואילך. בעמוד ההורדות יש את השאר."),
         ("איך מתעדכנים?", "באנר מודיע כשיוצאת גרסה חדשה. לוחצים \"עדכן עכשיו\": האפליקציה מורידה ומתקינה אותה, והנתונים נשארים.")],
    guides=[]),
  tv=dict(title="אפליקציית IPTV ל-Android TV ול-Fire TV | IPTVMac",
    desc="IPTVMac ל-Android TV, ‏Google TV ו-Fire TV: שידור חי, סרטים וסדרות עם השלט, מ-Xtream Codes או M3U. חינם, בלי פרסומות, ומותקן עם האפליקציה Downloader.",
    h1=["IPTV בטלוויזיה,", "עם השלט."], name="IPTVMac ל-Android TV",
    lede="אפליקציית ה-Android עם פריסה שנבנתה לשלט. רצה על ממירים וסטיקים של Android TV, ‏Google TV ו-Fire TV.",
    feats=[("נבנתה לשלט.", "מסגרת פוקוס ברורה, OK לבחירה, Back לעלייה שלב אחד. לא צריך מסך מגע.", "tv-live", "IPTVMac ב-Android TV: רשימת הערוצים עם מסגרת הפוקוס של השלט"),
           ("כל הספרייה על המסך הגדול.", "שידור חי, סרטים וסדרות, עם קטגוריות וחיפוש.", "tv-movies", "IPTVMac ב-Android TV: שורה של פוסטרים של סרטים"),
           ("פרטים לפני שלוחצים נגן.", "עלילה, שנה ודירוג, כשהספק שולח אותם.", "tv-details", "IPTVMac ב-Android TV: פרטי סרט")],
    faq=[("איך מתקינים ב-Fire TV?", "מתקינים את Downloader מחנות Amazon, מקלידים את כתובת הקובץ, מאשרים ל-Downloader להתקין אפליקציות, ופותחים את IPTVMac."),
         ("32 ביט או 64 ביט?", "מנסים קודם את קובץ ה-32 ביט: הוא רץ כמעט על כל טלוויזיה וממיר. אם הטלוויזיה אומרת שהוא לא תואם, משתמשים בקובץ ה-64 ביט."),
         ("איך מתעדכנים?", "בינתיים ידנית: מתקינים את הקובץ החדש מעל הישן.")],
    guides=[]),
 ),
}


# ---- /why/ (phase 4): the full argument, each reason with the place to check it, and an honest list of what it does not do ----
WHY = {
 "en": dict(
  title="Why IPTVMac: a free IPTV player with no ads or tracking",
  desc="Why IPTVMac is a better IPTV player: free with no ads, no account and no tracking, fast search on huge playlists, the mpv engine, native apps on every platform.",
  h1=["Why IPTVMac."], crumb="Why IPTVMac",
  lede="Seven reasons, each with the place where you can check it yourself. And, just as plainly, what it does not do yet.",
  check="How to check",
  reasons=[
   ("Free. Really.", "There is nothing to buy: no subscription, no premium tier, no in-app purchases, no ads. You do not create an account with us; you only add the login your provider gave you. The code is open source under the GPL-3.0, so anyone can read it and build it.", "LICENSE", "The license in the repository"),
   ("Nothing phones home.", "There are no analytics and no tracking libraries. The app talks to the servers you add and to GitHub, to check for updates. Passwords are stored on your device, never sent anywhere else.", "PRIVACY", "The privacy policy"),
   ("Found as you type.", "Your library lives in a local SQLite database with full-text search. Our automated tests fill it with 100,000 titles and check that each search returns in under a quarter of a second.", "Tests/IPTVCoreTests/SearchTests.swift", "The search speed test"),
   ("Plays the streams others drop.", "Playback runs on mpv, the engine behind many video players. It plays broken TS and HLS streams, reconnects by itself when a live channel drops, and decodes video in hardware.", "Sources/IPTVPlayer/PlaybackWatch.swift", "The live reconnect logic"),
   ("Made for each screen.", "Swift and SwiftUI on Mac, iPhone and iPad. Flutter with a Kotlin layer on Android and Android TV, and with a small C++ shell on Windows. No Electron and no web view, so it starts fast and stays light.", "", ""),
   ("Everything a viewer needs.", "Continue watching at the right episode and minute, skip intro and credits, Picture in Picture and several playlists in one library. On the Mac also catch-up on channels whose provider supports it; on Mac, Windows and Android also downloads for offline viewing.", "FEATURES", "The full feature list"),
   ("In your language.", "31 languages, each in its own script, including Hebrew, Arabic, Persian and Urdu from right to left.", "Sources/IPTVMac/Resources", "The 31 translations"),
  ],
  limits_h="What it does not do (yet)",
  limits=["It does not import XMLTV guide files: the program guide comes from Xtream Codes logins.",
          "On the Mac it needs Apple Silicon (M1 or later); Intel Macs are not supported. A local .m3u file cannot be opened yet, only a playlist link.",
          "The Windows app is not signed with a paid certificate yet, so SmartScreen asks once before it runs.",
          "The Android and TV apps are not on the Play Store yet; the TV app updates by installing the new file.",
          "Downloads are for movies and episodes that are direct files; live channels cannot be recorded.",
          "There is no Apple TV app."],
  compare_h="Compared with other players", compare_p="Fact-by-fact comparisons, with the sources and the date they were checked.",
 ),
 "he": dict(
  title="למה IPTVMac: נגן IPTV חינמי בלי פרסומות ובלי מעקב",
  desc="למה IPTVMac הוא נגן IPTV טוב יותר: חינם, בלי פרסומות, בלי חשבון ובלי מעקב, חיפוש מהיר ברשימות ענקיות, מנוע mpv, ואפליקציות מקוריות לכל פלטפורמה.",
  h1=["למה IPTVMac."], crumb="למה IPTVMac",
  lede="שבע סיבות, כל אחת עם המקום שבו אפשר לבדוק אותה בעצמכם. ובאותה פשטות, מה הוא עוד לא עושה.",
  check="איך בודקים",
  reasons=[
   ("חינם. באמת.", "אין מה לקנות: בלי מנוי, בלי גרסת פרימיום, בלי רכישות בתוך האפליקציה ובלי פרסומות. לא פותחים אצלנו חשבון; רק מוסיפים את פרטי הכניסה שקיבלתם מהספק. הקוד פתוח ברישיון GPL‑3.0, כך שכל אחד יכול לקרוא ולבנות אותו.", "LICENSE", "הרישיון במאגר"),
   ("שום דבר לא מדווח הביתה.", "אין אנליטיקה ואין ספריות מעקב. האפליקציה מדברת עם השרתים שהוספתם ועם GitHub, כדי לבדוק עדכונים. הסיסמאות נשמרות במכשיר ולא נשלחות לשום מקום אחר.", "PRIVACY", "מדיניות הפרטיות"),
   ("נמצא תוך כדי הקלדה.", "הספרייה שלכם שמורה במסד SQLite מקומי עם חיפוש טקסט מלא. הבדיקות האוטומטיות שלנו ממלאות אותו ב-100,000 כותרים ובודקות שכל חיפוש חוזר בפחות מרבע שנייה.", "Tests/IPTVCoreTests/SearchTests.swift", "בדיקת מהירות החיפוש"),
   ("מנגן את מה שנגנים אחרים מפילים.", "הניגון רץ על mpv, המנוע שמאחורי נגני וידאו רבים. הוא מנגן שידורי TS ו-HLS שבורים, מתחבר מחדש לבד כשערוץ חי נופל, ומפענח וידאו בחומרה.", "Sources/IPTVPlayer/PlaybackWatch.swift", "לוגיקת החיבור מחדש"),
   ("נבנה לכל מסך.", "Swift ו-SwiftUI ב-Mac, ב-iPhone וב-iPad. ‏Flutter עם שכבת Kotlin ב-Android וב-Android TV, ועם מעטפת C++ קטנה ב-Windows. בלי Electron ובלי דפדפן מוסתר, ולכן הוא נפתח מהר ונשאר קל.", "", ""),
   ("כל מה שצופה צריך.", "המשך צפייה בפרק ובדקה הנכונים, דילוג על הפתיח והכתוביות, תמונה בתוך תמונה וכמה רשימות בספרייה אחת. ב-Mac גם צפייה בהיסטוריה בערוצים שהספק תומך בהם; ב-Mac, ב-Windows וב-Android גם הורדות לצפייה בלי רשת.", "FEATURES", "רשימת התכונות המלאה"),
   ("בשפה שלכם.", "31 שפות, כל אחת בכתב שלה, כולל עברית, ערבית, פרסית ואורדו מימין לשמאל.", "Sources/IPTVMac/Resources", "31 התרגומים"),
  ],
  limits_h="מה הוא עוד לא עושה",
  limits=["הוא לא מייבא קובצי לוח שידורים XMLTV: לוח השידורים מגיע מחשבונות Xtream Codes.",
          "ב-Mac נדרש Apple Silicon ‏(M1 ומעלה); מחשבי Intel לא נתמכים. עדיין אי אפשר לפתוח קובץ .m3u מקומי, רק קישור לרשימה.",
          "אפליקציית Windows עוד לא חתומה בתעודה בתשלום, ולכן SmartScreen שואל פעם אחת לפני שהיא רצה.",
          "אפליקציות ה-Android והטלוויזיה עוד לא ב-Play Store; אפליקציית הטלוויזיה מתעדכנת בהתקנת הקובץ החדש.",
          "ההורדות הן לסרטים ופרקים שהם קבצים ישירים; אי אפשר להקליט ערוצים חיים.",
          "אין אפליקציה ל-Apple TV."],
  compare_h="בהשוואה לנגנים אחרים", compare_p="השוואות עובדה מול עובדה, עם המקורות והתאריך שבו נבדקו.",
 ),
}


# ---- Hebrew guides (phase 5): same slugs as the English ones under he/guides/; %DL% %PLATFORM% %SUPPORT% %HOME% are filled in by build.py ----
GUIDE_UI = {
 "en": dict(crumb="Guides", more="More guides", toc="On this page", cmd="Install in one line", updated="Updated", disc="IPTVMac is a media player; it does not include or host any content.", dl="Download IPTVMac"),
 "he": dict(crumb="מדריכים", more="עוד מדריכים", toc="בעמוד הזה", cmd="התקנה בשורה אחת", updated="עודכן", disc="IPTVMac הוא נגן מדיה; הוא לא כולל ולא מארח שום תוכן.", dl="הורדת IPTVMac"),
}
GUIDES_HE = {
 "xtream-codes-on-mac": dict(title="איך צופים ב-IPTV של Xtream Codes ב-Mac | IPTVMac", h1="איך צופים ב-IPTV של Xtream Codes ב-Mac", short="מה צריך מהספק ואיך מגדירים.",
  desc="שלב אחר שלב: מה כוללת כניסת Xtream Codes ואיך מוסיפים אותה ל-IPTVMac, נגן IPTV חינמי ומקורי ל-Mac, כדי לקבל שידורים חיים, סרטים וסדרות.",
  answer="מתקינים את IPTVMac, בוחרים Xtream Codes ומזינים את כתובת השרת, שם המשתמש והסיסמה שקיבלתם מהספק. IPTVMac מוריד את רשימת הערוצים פעם אחת ואז מחפש בה מיד.",
  body="""
<h2>מה צריך מהספק</h2>
<p>לכניסת Xtream Codes יש שלושה חלקים: כתובת שרת (למשל <code>http://example.com:8080</code>), שם משתמש וסיסמה. הספק מציג אותם בחשבון שלכם או בהודעת הפתיחה. IPTVMac לא מספק ערוצים; הוא מנגן את המקור שאתם מוסיפים.</p>
<h2>הגדרה ב-IPTVMac</h2>
<ol>
<li><a href="%DL%">מתקינים את IPTVMac</a> ‏(Mac עם Apple Silicon, ‏macOS 14 ומעלה).</li>
<li>בהפעלה הראשונה נפתח המדריך. בוחרים <strong>Xtream Codes</strong> וממלאים שם, כתובת שרת, שם משתמש וסיסמה.</li>
<li>לוחצים <strong>בדוק חיבור</strong> ואז <strong>שמור וסנכרן</strong>. IPTVMac מוריד את הערוצים החיים, הסרטים והסדרות פעם אחת, שומר אותם במחשב ומציג אותם בלשוניות.</li>
<li>מקלידים בשדה החיפוש כדי למצוא כותר: בקטגוריה, בחלק או בכל מקום.</li>
</ol>
<h2>אם שום דבר לא מתנגן</h2>
<ul>
<li><strong>בודקים את הסיסמה.</strong> בהגדרות יש "שינוי סיסמה". יש ספקים שעונים על פרטים שגויים בקודי HTTP לא רגילים במקום הודעה ברורה.</li>
<li><strong>בודקים את מספר החיבורים.</strong> חשבונות רבים מאפשרים חיבור אחד בכל פעם. סוגרים נגנים אחרים ולא צופים בזמן שהורדה רצה.</li>
<li><strong>מרעננים את הרשימה.</strong> כפתור הרענון בסרגל מוריד את הרשימות מחדש.</li>
</ul>
<h2>כדאי לדעת</h2>
<p>צפייה בהיסטוריה עובדת בערוצים שהספק שומר להם ארכיון. הסיסמה נשמרת במסד הנתונים המקומי של IPTVMac, וקריאה רק למשתמש שלכם.</p>
""", faq=[("מה זו כניסת Xtream Codes?", "כתובת שרת, שם משתמש וסיסמה שספק ה-IPTV נותן לכם. הנגן משתמש בהם כדי להוריד את רשימות הערוצים, הסרטים והסדרות."),
          ("האם IPTVMac כולל ערוצים?", "לא. IPTVMac הוא נגן בלבד. מוסיפים את פרטי הכניסה מספק שמותר לכם להשתמש בו.")]),
 "m3u-playlist-on-mac": dict(title="איך מנגנים רשימת M3U ב-Mac | IPTVMac", h1="איך מנגנים רשימת M3U ב-Mac", short="מוסיפים קישור לרשימה ומקבלים שידור חי, סרטים וסדרות.",
  desc="איך פותחים קישור לרשימת M3U או M3U8 ב-Mac עם IPTVMac, נגן IPTV חינמי ומקורי: מוסיפים את הקישור, מדפדפים בשידור חי, בסרטים ובסדרות, ומחפשים מיד.",
  answer="מתקינים את IPTVMac, בוחרים M3U ומזינים שם ואת הקישור לרשימה. IPTVMac קורא את הרשימה וממיין אותה לשידור חי, סרטים וסדרות.",
  body="""
<h2>מה צריך</h2>
<p>את הקישור (URL) לרשימת M3U או M3U8 ממקור שמותר לכם להשתמש בו. IPTVMac מקבל קישור; פתיחת קובץ .m3u מקומי עוד לא נתמכת.</p>
<h2>אין לכם רשימה?</h2>
<p>הפרויקט העצמאי בקוד פתוח <a href="https://github.com/iptv-org/iptv" rel="noopener">iptv-org</a> מפרסם רשימות M3U של ערוצים זמינים לציבור מכל העולם, למשל <code>https://iptv-org.github.io/iptv/index.m3u</code>. ‏IPTVMac לא קשור אליו, והאם שידור זמין או מותר במדינה שלכם תלוי בערוץ: משתמשים רק במה שמותר.</p>
<h2>מוסיפים ב-IPTVMac</h2>
<ol>
<li><a href="%DL%">מתקינים את IPTVMac</a> ‏(Mac עם Apple Silicon, ‏macOS 14 ומעלה).</li>
<li>במדריך ההפעלה הראשונה, או בהגדרות, בוחרים <strong>M3U</strong>, מזינים שם ומדביקים את הקישור.</li>
<li>לוחצים <strong>שמור וסנכרן</strong>. IPTVMac מוריד את הרשימה ובונה את הרשימות. ה-<code>group-title</code> של כל רשומה הופך לקטגוריה שלה, וה-<code>tvg-logo</code> לסמל שלה.</li>
</ol>
<h2>איך הרשומות ממוינות</h2>
<p>קובץ M3U לא אומר אם רשומה היא ערוץ, סרט או סדרה, ולכן IPTVMac מחליט: קישור שמכיל <code>/movie/</code> או <code>/series/</code> הוא סרט או סדרה, אחר כך נבדק שם הקבוצה, וקבצים שמסתיימים ב-.mp4, ‏.mkv או .avi נחשבים לסרטים. כל השאר שידור חי.</p>
""", faq=[("אפשר לפתוח קובץ .m3u מקומי?", "עוד לא. IPTVMac מקבל את הקישור (URL) לרשימה."),
          ("איך IPTVMac מחליט מה סרט ומה סדרה?", "לפי נתיב הקישור (/movie/ או /series/), אחר כך לפי שם הקבוצה, ואחר כך לפי סיומת הקובץ. כל השאר נחשב שידור חי.")]),
 "picture-in-picture-iptv-mac": dict(title="תמונה בתוך תמונה ל-IPTV ב-Mac | IPTVMac", h1="תמונה בתוך תמונה ל-IPTV ב-Mac", short="משאירים שידור בחלון צף בזמן שעושים משהו אחר.",
  desc="איך משאירים שידור IPTV בחלון צף ב-Mac בזמן שגולשים או עובדים, עם כפתור תמונה בתוך תמונה בנגן של IPTVMac. חלון שנשאר מעל כל האפליקציות ובכל Space.",
  answer="מפעילים ערוץ או סרט ב-IPTVMac ולוחצים על כפתור תמונה בתוך תמונה בנגן. הווידאו עובר לחלון צף קטן שנשאר מעל אפליקציות אחרות ובכל Space.",
  body="""
<h2>מפעילים</h2>
<ol>
<li>מנגנים ערוץ, סרט או פרק ב-<a href="%DL%">IPTVMac</a>.</li>
<li>לוחצים על כפתור תמונה בתוך תמונה בפקדי הנגן.</li>
<li>הווידאו עובר לחלון צף בפינת המסך, וחלון IPTVMac חוזר לרשימות כדי שתבחרו משהו אחר.</li>
</ol>
<h2>מה החלון הצף עושה</h2>
<ul>
<li>הוא נשאר מעל אפליקציות אחרות ובכל Space, גם מעל אפליקציות במסך מלא.</li>
<li>כשהעכבר מעליו מופיעים עצירה, סגירה וכפתור שמחזיר את הווידאו לחלון הראשי.</li>
<li>אפשר לגרור אותו לכל מקום ולשנות את גודלו.</li>
</ul>
<h2>לתשומת לב</h2>
<p>זה החלון הצף של IPTVMac עצמו, לא תמונה בתוך תמונה של Safari או QuickTime. הוא עובד עם כל מקור ש-IPTVMac יכול לנגן.</p>
""", faq=[("זה עובד בערוצים חיים?", "כן. זה עובד בערוצים חיים, בסרטים ובפרקים."),
          ("זו תמונה בתוך תמונה של המערכת?", "לא. זה החלון הצף של IPTVMac, שנשאר תמיד למעלה ומופיע גם מעל אפליקציות במסך מלא.")]),
 "xtream-codes-on-fire-tv": dict(title="איך מוסיפים Xtream Codes ב-Fire TV | IPTVMac", h1="איך מוסיפים IPTV של Xtream Codes ב-Fire TV", short="מתקינים עם Downloader ומוסיפים את הכניסה עם השלט.",
  desc="מתקינים את IPTVMac ב-Fire TV, ב-Android TV או ב-Google TV עם האפליקציה Downloader, מוסיפים את כניסת ה-Xtream Codes ומדפדפים בשידור חי, סרטים וסדרות.",
  answer="מתקינים את Downloader בטלוויזיה, משתמשים בו כדי להתקין את IPTVMac, ואז פותחים את IPTVMac ומזינים את כתובת השרת, שם המשתמש והסיסמה מהספק.",
  body="""
<h2>מה צריך</h2>
<p>מכשיר Fire TV, ‏Android TV או Google TV עם Android 8 ומעלה (ב-Fire TV זה Fire OS 7 ומעלה), ואת כניסת ה-Xtream Codes מהספק: כתובת שרת, שם משתמש וסיסמה. ‏IPTVMac לא מספק ערוצים.</p>
<h2>מתקינים את IPTVMac</h2>
<ol>
<li>בטלוויזיה מתקינים את <strong>Downloader</strong> (ב-Fire TV מחנות Amazon, ב-Android TV וב-Google TV מ-Google Play) ופותחים אותו.</li>
<li>מקלידים את הכתובת של קובץ הטלוויזיה 32 ביט מ<a href="%PLATFORM%">עמוד ה-Android TV</a>. אם הטלוויזיה אומרת שהקובץ לא תואם, משתמשים בקובץ ה-64 ביט.</li>
<li>מאשרים ל-Downloader להתקין אפליקציות כשהטלוויזיה שואלת, ואז מתקינים ופותחים את IPTVMac.</li>
</ol>
<h2>מוסיפים את הכניסה</h2>
<ol>
<li>בוחרים <strong>Xtream Codes</strong> וממלאים עם השלט שם, כתובת שרת, שם משתמש וסיסמה.</li>
<li>בוחרים <strong>בדוק חיבור</strong> ואז <strong>שמור וסנכרן</strong>. IPTVMac מוריד את הערוצים, הסרטים והסדרות פעם אחת ושומר אותם בטלוויזיה.</li>
</ol>
<h2>עם השלט</h2>
<ul><li>OK בוחר, Back עולה שלב אחד, ולחיצה ארוכה על Back סוגרת את האפליקציה.</li><li>העדכונים בינתיים ידניים: מתקינים את קובץ הטלוויזיה החדש מעל הישן, והמקורות נשארים.</li></ul>
""", faq=[("זה עובד על כל Fire TV?", "צריך Android 8 ומעלה, שב-Fire TV פירושו Fire OS 7 ומעלה. מנסים קודם את קובץ ה-32 ביט; הוא רץ כמעט על כל מכשיר."),
          ("IPTVMac חינמי ב-Fire TV?", "כן. חינמי ובקוד פתוח, בלי פרסומות ובלי חשבון.")]),
 "m3u-playlist-on-iphone": dict(title="איך מנגנים רשימת M3U ב-iPhone וב-iPad | IPTVMac", h1="איך מנגנים רשימת M3U ב-iPhone וב-iPad", short="חינם ב-App Store: מדביקים את הקישור ומדפדפים.",
  desc="מוסיפים קישור לרשימת M3U או M3U8 ל-IPTVMac ב-iPhone או ב-iPad: חינם ב-App Store, בלי פרסומות, ממוין לשידור חי, סרטים וסדרות, עם חיפוש תוך כדי הקלדה.",
  answer="מתקינים את IPTVMac מה-App Store, בוחרים M3U, נותנים למקור שם ומדביקים את הקישור לרשימה. האפליקציה ממיינת אותה לשידור חי, סרטים וסדרות.",
  body="""
<h2>מה צריך</h2>
<p>iPhone או iPad עם iOS 17 ומעלה, ואת הקישור (URL) לרשימת M3U או M3U8 ממקור שמותר לכם להשתמש בו.</p>
<h2>מוסיפים את הרשימה</h2>
<ol>
<li>מורידים את IPTVMac מה-<a href="%DL%">App Store</a>. חינם, בלי פרסומות ובלי רכישות בתוך האפליקציה.</li>
<li>פותחים, בוחרים <strong>M3U</strong>, מקלידים שם ומדביקים את הקישור.</li>
<li>לוחצים <strong>בדוק חיבור</strong> ואז <strong>שמור וסנכרן</strong>.</li>
</ol>
<h2>איך הרשומות ממוינות</h2>
<p>קובץ M3U לא אומר אם רשומה היא ערוץ, סרט או סדרה, ולכן IPTVMac מחליט לפי הקישור ושם הקבוצה, וקבצים כמו .mp4 או .mkv נחשבים לסרטים. כל השאר שידור חי. ה-<code>group-title</code> של רשומה הופך לקטגוריה שלה.</p>
<h2>טיפים</h2>
<ul><li>החיפוש מוצא כותרים תוך כדי הקלדה, בקטגוריה, בחלק או בכל מקום.</li><li>מסמנים ערוצים בכוכב כדי לשמור אותם במועדפים; המשך הצפייה זוכר את הפרק ואת הדקה.</li></ul>
""", faq=[("IPTVMac חינמי ב-iPhone?", "כן. בלי פרסומות, בלי מנוי, בלי רכישות בתוך האפליקציה ובלי חשבון."),
          ("הוא כולל ערוצים?", "לא. IPTVMac הוא נגן בלבד; מוסיפים את הקישור לרשימה ממקור שמותר לכם להשתמש בו.")]),
 "iptv-player-windows": dict(title="איך צופים ב-IPTV ב-Windows 10 ו-11 | IPTVMac", h1="איך צופים ב-IPTV ב-Windows 10 ו-11", short="מתקינים בלי הרשאות מנהל, מוסיפים מקור ומשתמשים בקיצורים.",
  desc="מגדירים נגן IPTV חינמי ב-Windows 10 או 11: מתקינים את IPTVMac בלי הרשאות מנהל, מוסיפים כניסת Xtream Codes או קישור M3U, ומשתמשים בקיצורי המקלדת.",
  answer="מורידים את המתקין של IPTVMac, מריצים אותו (בלי הרשאות מנהל), ומוסיפים כניסת Xtream Codes או קישור M3U.",
  body="""
<h2>התקנה</h2>
<ol>
<li>מורידים את <a href="%DL%">המתקין של IPTVMac</a> ‏(Windows 10 או 11, ‏64 ביט). הוא מתקין למשתמש שלכם בלבד.</li>
<li>אם Windows SmartScreen אומר שהוא הגן על המחשב, בוחרים <strong>More info</strong> ואז <strong>Run anyway</strong>. האפליקציה עוד לא חתומה בתעודה בתשלום; קוד המקור פתוח.</li>
<li>לא רוצים להתקין? ב<a href="%PLATFORM%">עמוד ה-Windows</a> יש גם zip נייד.</li>
</ol>
<h2>מוסיפים מקור</h2>
<p>בוחרים <strong>Xtream Codes</strong> (כתובת שרת, שם משתמש וסיסמה) או <strong>M3U</strong> (שם וקישור לרשימה), ואז <strong>בדוק חיבור</strong> ואז <strong>שמור וסנכרן</strong>.</p>
<h2>קיצורי מקלדת</h2>
<ul><li><kbd>רווח</kbd> עוצר, החיצים מדלגים, <kbd>F</kbd> ממלא את המסך.</li><li>ההורדות שומרות סרטים ופרקים לצפייה בלי חיבור.</li></ul>
<h2>עדכונים</h2>
<p>האפליקציה מודיעה כשיוצאת גרסה חדשה. מריצים את המתקין החדש מעל הישן, והמקורות וההגדרות נשארים.</p>
""", faq=[("צריך הרשאות מנהל?", "לא. המתקין מתקין למשתמש שלכם בלבד, וה-zip הנייד רץ בלי התקנה."),
          ("למה SmartScreen מזהיר?", "האפליקציה עוד לא חתומה בתעודת חתימת קוד בתשלום. בוחרים More info ואז Run anyway.")]),
 "iptv-on-android": dict(title="איך מגדירים IPTV בטלפון Android | IPTVMac", h1="איך מגדירים IPTV בטלפון Android", short="מתקינים את ה-APK פעם אחת ומוסיפים כניסה או רשימה.",
  desc="מתקינים את ה-APK החינמי של IPTVMac בטלפון או בטאבלט Android, מאשרים את ההתקנה פעם אחת, ומוסיפים כניסת Xtream Codes או קישור M3U. בלי חשבון ובלי פרסומות.",
  answer="מורידים את ה-APK‏ arm64-v8a, פותחים ומאשרים את ההתקנה, ואז מוסיפים ב-IPTVMac כניסת Xtream Codes או קישור M3U.",
  body="""
<h2>איזה קובץ</h2>
<p>ה-APK‏ <code>arm64-v8a</code> מתאים לכמעט כל טלפון וטאבלט מ-2017 ואילך. ב<a href="%PLATFORM%">עמוד ה-Android</a> יש קישורים לאחרים.</p>
<h2>התקנה</h2>
<ol>
<li>מורידים את <a href="%DL%">ה-APK</a> בטלפון ופותחים אותו.</li>
<li>Android מבקש לאשר התקנות מהדפדפן או מאפליקציית הקבצים: מאשרים. אם Play Protect מזהיר על אפליקציה מחוץ ל-Play Store, בוחרים "התקן בכל זאת".</li>
<li>פותחים את IPTVMac, בוחרים <strong>Xtream Codes</strong> או <strong>M3U</strong>, ממלאים את הפרטים, ואז <strong>בדוק חיבור</strong> ואז <strong>שמור וסנכרן</strong>.</li>
</ol>
<h2>בנגן</h2>
<ul><li>הקשה כפולה לדילוג, החלקה לווליום ולבהירות, לחיצה ארוכה ל-2x.</li><li>הקול ממשיך כשהמסך כבוי, ותמונה בתוך תמונה שומרת על התמונה בזמן שמשתמשים באפליקציות אחרות.</li></ul>
<h2>עדכונים</h2>
<p>באנר מודיע כשיוצאת גרסה חדשה. לוחצים "עדכן עכשיו", והנתונים נשארים.</p>
""", faq=[("ה-APK בטוח?", "הוא חתום במפתח של הפרויקט, ובעמוד הגרסה מופיע סכום ה-SHA-256 שלו. קוד המקור פתוח."),
          ("למה הוא לא ב-Play Store?", "בינתיים מתקינים מקובץ ישיר. Android מבקש לאשר את זה פעם אחת.")]),
 "catch-up-iptv-mac": dict(title="איך צופים בתוכניות שעברו (Catch-up) ב-Mac | IPTVMac", h1="איך צופים בתוכניות שכבר שודרו ב-Mac", short="צופים בתוכנית שכבר שודרה, כשהספק שומר ארכיון.",
  desc="צופים ב-Mac בתוכניות IPTV שכבר שודרו: איך צפייה בהיסטוריה עובדת עם Xtream Codes, באילו ערוצים יש אותה, ואיך מפעילים תוכנית שעברה ב-IPTVMac.",
  answer="מנגנים ערוץ חי שתומך בזה, לוחצים בנגן על \"צפייה בהיסטוריה\" ובוחרים תוכנית מהרשימה. הספק צריך לשמור ארכיון לאותו ערוץ.",
  body="""
<h2>מה זה</h2>
<p>יש ספקים שמקליטים את הערוצים שלהם לכמה ימים. הנגן יכול אז לבקש תוכנית שכבר שודרה. ב-IPTVMac זה עובד עם כניסות Xtream Codes ב-Mac.</p>
<h2>באילו ערוצים יש את זה</h2>
<p>ליד ערוצים עם ארכיון מופיע ברשימה סמל שעון קטן. כמה אפשר לחזור אחורה תלוי בספק.</p>
<h2>צופים בתוכנית שעברה</h2>
<ol>
<li>מנגנים את הערוץ ב-<a href="%DL%">IPTVMac</a>.</li>
<li>לוחצים בפקדי הנגן על כפתור השעון, <strong>צפייה בהיסטוריה</strong>.</li>
<li>בוחרים תוכנית מהרשימה. אם אין לערוץ לוח שידורים, בוחרים ידנית שעת התחלה ואורך.</li>
<li>כפתור <strong>Live</strong> מחזיר לשידור הנוכחי של הערוץ.</li>
</ol>
""", faq=[("למה אין כפתור צפייה בהיסטוריה?", "לערוץ אין ארכיון אצל הספק, או שהמקור הוא רשימת M3U. צפייה בהיסטוריה דורשת כניסת Xtream Codes."),
          ("כמה אחורה אפשר לחזור?", "כמה שהספק שומר את הארכיון לאותו ערוץ, בדרך כלל כמה ימים.")]),
 "iptv-buffering": dict(title="ה-IPTV נתקע? מה לבדוק | IPTVMac", h1="ה-IPTV ממשיך להיתקע? מה לבדוק", short="חיבורים, הרשת, הספק והגדרות הנגן.",
  desc="שידור IPTV שנתקע או קופא? בודקים את מספר החיבורים, את הרשת, את הספק ואת הגדרות הנגן. צעדים מעשיים למשתמשי IPTVMac בכל מכשיר.",
  answer="רוב התקיעות מגיעות מהספק או מהרשת, לא מהנגן. סוגרים נגנים אחרים שמשתמשים באותה כניסה, מנסים חיבור בכבל, משווים כמה ערוצים, וב-Mac מגדילים את מאגר הרשת בהגדרות.",
  body="""
<h2>חיבור אחד בכל פעם</h2>
<p>הרבה חשבונות IPTV מאפשרים חיבור יחיד (<code>max_connections</code>). נגן נוסף, מכשיר אחר או הורדה שרצה על אותה כניסה יכולים לגרום לשידור להיתקע. סוגרים את האחרים ומנסים שוב.</p>
<h2>הרשת</h2>
<p>חיבור יציב חשוב יותר מחיבור מהיר. אם אפשר, מנסים כבל במקום Wi-Fi, או מתקרבים לנתב, ובודקים אם התקיעות נעלמות.</p>
<h2>הספק</h2>
<p>אם כל הערוצים נתקעים, או רק בשעות הערב העמוסות, הבעיה היא בדרך כלל השרת של הספק. אם ערוץ אחד נתקע ב-IPTVMac וגם בנגן אחר, זו הבעיה של אותו שידור.</p>
<h2>הגדרות הנגן</h2>
<ul><li>ב-Mac יש בהגדרות <strong>מאגר רשת</strong>: קטן, רגיל או גדול. מאגר גדול יותר עוזר בחיבור איטי או לא יציב.</li><li>IPTVMac מתחבר מחדש לבד כששידור חי נופל, כך שנפילה קצרה לא דורשת הפעלה מחדש.</li></ul>
<h2>עדיין תקוע?</h2>
<p><a href="%SUPPORT%">עמוד התמיכה</a> מסביר איך מדווחים על בעיה בלי לשתף את פרטי הכניסה.</p>
""", faq=[("זה IPTVMac או הספק?", "אם אותו ערוץ נתקע גם בנגן אחר, זה הספק או הרשת. אם הוא נתקע רק ב-IPTVMac, מדווחים בעמוד התמיכה."),
          ("מאגר גדול יותר עוזר?", "בחיבור איטי או לא יציב, כן. ב-Mac הוא בהגדרות, תחת מאגר רשת.")]),
}


# ---- /compare/ (phase 4): honest, fact-by-fact comparisons. Every cell about another app comes from the sources listed with it
# (read on CHECKED); rows are in scripts/site/claims.md. Recheck every 6 months. ----
CHECKED = "2026-11-11"
SRC = {
 "smarters": [("App Store: Smarters Player Lite (WHMCS Smarters)", "https://apps.apple.com/us/app/smarters-player-lite/id1628995509"),
              ("IPTV Smarters: download page", "https://getiptvsmarters.com/download"), ("IPTV Smarters: features", "https://getiptvsmarters.com/features"),
              ("IPTV Smarters: terms", "https://getiptvsmarters.com/terms")],
 "tivimate": [("Google Play: TiviMate IPTV Player", "https://play.google.com/store/apps/details?id=ar.tvplayer.tv"),
              ("Google Play: TiviMate data safety", "https://play.google.com/store/apps/datasafety?id=ar.tvplayer.tv"),
              ("TiviMate: terms of use", "https://tivimate.com/terms-of-use"), ("TiviMate: website", "https://tivimate.com")],
 "vlc": [("VideoLAN: VLC media player", "https://www.videolan.org/vlc/"), ("VideoLAN wiki: playlist modules", "https://wiki.videolan.org/Documentation:Modules/playlist"),
         ("Google Play: VLC for Android", "https://play.google.com/store/apps/details?id=org.videolan.vlc"), ("VideoLAN: news (releases)", "https://www.videolan.org/news.html")],
}
COMPARE = {
 "en": dict(
  hub_title="IPTV player comparison: IPTVMac vs the others | IPTVMac",
  hub_desc="Honest, fact-by-fact comparisons of IPTVMac with IPTV Smarters Pro, TiviMate and VLC: price, ads, accounts, platforms, Xtream Codes, catch-up and more.",
  hub_h1=["Compared,", "honestly."], hub_crumb="Compare",
  hub_lede="Each comparison lists facts, not adjectives, with the sources and the date we read them. Where another app does something IPTVMac does not, the table says so.",
  col_feature="", col_us="IPTVMac", sources_h="Sources", checked="Checked on 11 November 2026. Apps change: if something here is out of date, tell us on GitHub.",
  tm="IPTV Smarters, TiviMate and VLC are trademarks of their owners. IPTVMac is not affiliated with them.",
  short_h="In short", stronger="Where it is stronger", ours="Where IPTVMac is different",
  pages=[
   ("iptv-smarters", dict(title="IPTVMac vs IPTV Smarters Pro: an honest comparison",
     desc="IPTVMac and IPTV Smarters Pro compared fact by fact: price, ads, tracking, platforms, Xtream Codes, M3U, catch-up and Picture in Picture, with sources.",
     h1=["IPTVMac vs", "IPTV Smarters Pro"], name="IPTV Smarters Pro",
     lede="Both play Xtream Codes and M3U sources on many devices. The differences are in price, ads, tracking and who can read the code.",
     ours=["Nothing to buy, no ads and no tracking on any platform.", "Open source (GPL-3.0); a native Mac app, not an iPad app running on the Mac.", "Downloads for offline viewing on Mac, Windows and Android."],
     theirs=["More devices: Apple TV and LG and Samsung smart TVs.", "Its own extras: multi-view, parental controls and external EPG sources (some in its premium version)."],
     rows=[("Price", "Free, nothing to buy", "Free download; App Store premium in-app purchase $1.99; its terms describe a recurring premium plan"),
           ("Ads", "None", "App Store listing: “Contains Advertising”"),
           ("Tracking", "No analytics", "App Store privacy label: usage data used to track you"),
           ("Account with the app", "None", "None for basic use, per its privacy page"),
           ("Open source", "Yes, GPL-3.0", "No, proprietary"),
           ("Platforms", "Mac, Windows, iPhone, iPad, Android, Android TV", "Android, Android TV, iPhone, iPad, Apple TV, Mac, Windows, LG and Samsung TVs"),
           ("On the Mac", "Native Apple Silicon app (Swift)", "App Store build is “Designed for iPad”; a separate Mac download on its site"),
           ("Xtream Codes and M3U", "Both", "Both"),
           ("Catch-up", "Mac, with Xtream Codes", "Listed, when the source supports it"),
           ("Picture in Picture", "Mac, iPhone, iPad, Android", "Listed; a premium feature in its terms"),
           ("Downloads for offline viewing", "Mac, Windows, Android", "Not listed"),
           ("Google Play", "Not on Google Play (direct APK)", "Its Google Play listing was not available on 11 November 2026")]))
   , ("tivimate", dict(title="IPTVMac vs TiviMate: free IPTV player comparison",
     desc="IPTVMac and TiviMate compared fact by fact: price, account, platforms, Xtream Codes, M3U, program guide, recording and catch-up, with sources and dates.",
     h1=["IPTVMac vs", "TiviMate"], name="TiviMate",
     lede="TiviMate is a polished player for Android TV. IPTVMac is free everywhere and also runs on Mac, Windows, iPhone, iPad and phones.",
     ours=["Free with nothing to buy; no account and no analytics.", "Runs on Mac, Windows, iPhone, iPad and Android phones, not only on TVs.", "Open source (GPL-3.0)."],
     theirs=["A full TV guide grid, recording, multi-view and Stalker portals.", "Built for Android TV first, with years of polish there."],
     rows=[("Price", "Free, nothing to buy", "Free download with in-app purchases ($0.99 to $33.99 per item on Google Play); a lifetime purchase and subscriptions"),
           ("Account", "None", "An account (email) for Premium"),
           ("Ads", "None", "No “Contains ads” label on Google Play"),
           ("Analytics", "None", "Google Play data safety: device IDs and app interactions collected for analytics"),
           ("Open source", "Yes, GPL-3.0", "No, proprietary"),
           ("Platforms", "Mac, Windows, iPhone, iPad, Android, Android TV", "Android TV; “not optimized for touch devices such as phones or tablets”"),
           ("Xtream Codes and M3U", "Both", "Both, plus Stalker portals"),
           ("Program guide", "From Xtream Codes logins (no XMLTV import)", "A full guide grid"),
           ("Catch-up", "Mac, with Xtream Codes", "Yes"),
           ("Recording live TV", "No", "Yes"),
           ("Downloads of movies and episodes", "Mac, Windows, Android", "Not listed"),
           ("Last update", "Mac 0.9.8, 7 November 2026", "Google Play: 22 June 2026")]))
   , ("vlc", dict(title="IPTVMac vs VLC for IPTV: what each one does",
     desc="IPTVMac and VLC compared for IPTV: both free and open source. What each does with M3U playlists, Xtream Codes logins, program guides, catch-up and libraries.",
     h1=["IPTVMac vs", "VLC for IPTV"], name="VLC",
     lede="VLC is the free, open source player that opens almost anything. IPTVMac is built only for IPTV: it turns a provider login into a library you can search.",
     ours=["Logs in to Xtream Codes and builds Live, Movies and Series from it.", "Searches 100,000 titles as you type, with favorites and continue watching.", "Catch-up on the Mac and a program guide from Xtream Codes logins."],
     theirs=["Plays almost any file or stream format, far beyond IPTV.", "More platforms: Linux, Intel Macs, Apple TV."],
     rows=[("Price, ads, account", "Free, no ads, no account", "Free, no ads (“no spyware, no ads and no user tracking”)"),
           ("Open source", "Yes, GPL-3.0", "Yes, GPL-2.0 (iOS: MPL-2.0 or GPL)"),
           ("Platforms", "Mac (Apple Silicon), Windows, iPhone, iPad, Android, Android TV", "Windows, Mac (Intel and Apple Silicon), Linux, Android, Android TV, iPhone, iPad, Apple TV"),
           ("M3U playlists", "Yes, sorted into Live, Movies and Series", "Yes, opened as a playlist"),
           ("Xtream Codes login", "Yes", "No official support"),
           ("Program guide for IPTV channels", "From Xtream Codes logins", "No official guide for M3U channel lists"),
           ("Catch-up", "Mac, with Xtream Codes", "No official support"),
           ("Search across the library", "Instant, 100,000 titles", "Not an IPTV library"),
           ("Picture in Picture", "Mac, iPhone, iPad, Android", "Android"),
           ("Latest version", "Mac 0.9.8, 7 November 2026", "Desktop 3.0.24, 22 September 2026")]))
  ],
 ),
 "he": dict(
  hub_title="השוואת נגני IPTV: ‏IPTVMac מול האחרים | IPTVMac",
  hub_desc="השוואות כנות, עובדה מול עובדה, של IPTVMac מול IPTV Smarters Pro, ‏TiviMate ו-VLC: מחיר, פרסומות, חשבון, פלטפורמות, Xtream Codes, צפייה בהיסטוריה ועוד.",
  hub_h1=["בהשוואה,", "בכנות."], hub_crumb="השוואה",
  hub_lede="כל השוואה מציגה עובדות, לא תארים, עם המקורות והתאריך שבו קראנו אותם. כשאפליקציה אחרת עושה משהו ש-IPTVMac לא עושה, הטבלה אומרת את זה.",
  col_feature="", col_us="IPTVMac", sources_h="מקורות", checked="נבדק ב-11 בנובמבר 2026. אפליקציות משתנות: אם משהו כאן לא מעודכן, ספרו לנו ב-GitHub.",
  tm="IPTV Smarters, ‏TiviMate ו-VLC הם סימנים מסחריים של בעליהם. ‏IPTVMac לא קשור אליהם.",
  short_h="בקצרה", stronger="איפה הוא חזק יותר", ours="במה IPTVMac שונה",
  pages=[
   ("iptv-smarters", dict(title="IPTVMac מול IPTV Smarters Pro: השוואה כנה",
     desc="IPTVMac ו-IPTV Smarters Pro בהשוואה עובדה מול עובדה: מחיר, פרסומות, מעקב, פלטפורמות, Xtream Codes, ‏M3U, צפייה בהיסטוריה ותמונה בתוך תמונה, עם מקורות.",
     h1=["IPTVMac מול", "IPTV Smarters Pro"], name="IPTV Smarters Pro",
     lede="שניהם מנגנים מקורות Xtream Codes ו-M3U על הרבה מכשירים. ההבדלים הם במחיר, בפרסומות, במעקב, ובשאלה מי יכול לקרוא את הקוד.",
     ours=["אין מה לקנות, בלי פרסומות ובלי מעקב בכל פלטפורמה.", "קוד פתוח (GPL‑3.0); אפליקציה מקורית ל-Mac, לא אפליקציית iPad שרצה על Mac.", "הורדות לצפייה בלי רשת ב-Mac, ב-Windows וב-Android."],
     theirs=["יותר מכשירים: Apple TV וטלוויזיות חכמות של LG ו-Samsung.", "תוספות משלו: צפייה בכמה ערוצים יחד, בקרת הורים ומקורות EPG חיצוניים (חלקן בגרסת הפרימיום)."],
     rows=[("מחיר", "חינם, אין מה לקנות", "הורדה חינם; ב-App Store רכישת פרימיום ב-1.99$; התנאים שלו מתארים תוכנית פרימיום מתחדשת"),
           ("פרסומות", "אין", "ב-App Store: ‏“Contains Advertising”"),
           ("מעקב", "בלי אנליטיקה", "תווית הפרטיות ב-App Store: נתוני שימוש שמשמשים למעקב"),
           ("חשבון באפליקציה", "אין", "אין לשימוש בסיסי, לפי דף הפרטיות שלו"),
           ("קוד פתוח", "כן, GPL‑3.0", "לא, קנייני"),
           ("פלטפורמות", "Mac, ‏Windows, ‏iPhone, ‏iPad, ‏Android, ‏Android TV", "Android, ‏Android TV, ‏iPhone, ‏iPad, ‏Apple TV, ‏Mac, ‏Windows, טלוויזיות LG ו-Samsung"),
           ("ב-Mac", "אפליקציה מקורית ל-Apple Silicon ‏(Swift)", "הגרסה ב-App Store היא “Designed for iPad”; הורדה נפרדת ל-Mac באתר שלו"),
           ("Xtream Codes ו-M3U", "שניהם", "שניהם"),
           ("צפייה בהיסטוריה", "ב-Mac, עם Xtream Codes", "מופיע, כשהמקור תומך"),
           ("תמונה בתוך תמונה", "Mac, ‏iPhone, ‏iPad, ‏Android", "מופיע; תכונת פרימיום לפי התנאים שלו"),
           ("הורדות לצפייה בלי רשת", "Mac, ‏Windows, ‏Android", "לא מופיע"),
           ("Google Play", "לא ב-Google Play ‏(APK ישיר)", "הדף שלו ב-Google Play לא היה זמין ב-11 בנובמבר 2026")]))
   , ("tivimate", dict(title="IPTVMac מול TiviMate: השוואת נגני IPTV",
     desc="IPTVMac ו-TiviMate בהשוואה עובדה מול עובדה: מחיר, חשבון, פלטפורמות, Xtream Codes, ‏M3U, לוח שידורים, הקלטה וצפייה בהיסטוריה, עם מקורות ותאריכים.",
     h1=["IPTVMac מול", "TiviMate"], name="TiviMate",
     lede="TiviMate הוא נגן מלוטש ל-Android TV. ‏IPTVMac חינמי בכל מקום, ורץ גם ב-Mac, ב-Windows, ב-iPhone, ב-iPad ובטלפונים.",
     ours=["חינם בלי שום רכישה; בלי חשבון ובלי אנליטיקה.", "רץ ב-Mac, ב-Windows, ב-iPhone, ב-iPad ובטלפוני Android, לא רק בטלוויזיות.", "קוד פתוח (GPL‑3.0)."],
     theirs=["לוח שידורים מלא, הקלטה, צפייה בכמה ערוצים יחד ופורטלי Stalker.", "נבנה קודם כול ל-Android TV, עם שנים של ליטוש שם."],
     rows=[("מחיר", "חינם, אין מה לקנות", "הורדה חינם עם רכישות בתוך האפליקציה (0.99$ עד 33.99$ לפריט ב-Google Play); רכישה לכל החיים ומנויים"),
           ("חשבון", "אין", "חשבון (אימייל) לפרימיום"),
           ("פרסומות", "אין", "אין תווית “Contains ads” ב-Google Play"),
           ("אנליטיקה", "אין", "בטיחות הנתונים ב-Google Play: מזהי מכשיר ואינטראקציות נאספים לאנליטיקה"),
           ("קוד פתוח", "כן, GPL‑3.0", "לא, קנייני"),
           ("פלטפורמות", "Mac, ‏Windows, ‏iPhone, ‏iPad, ‏Android, ‏Android TV", "Android TV; ‏“not optimized for touch devices such as phones or tablets”"),
           ("Xtream Codes ו-M3U", "שניהם", "שניהם, וגם פורטלי Stalker"),
           ("לוח שידורים", "מכניסות Xtream Codes (בלי ייבוא XMLTV)", "רשת לוח שידורים מלאה"),
           ("צפייה בהיסטוריה", "ב-Mac, עם Xtream Codes", "כן"),
           ("הקלטת שידור חי", "לא", "כן"),
           ("הורדות של סרטים ופרקים", "Mac, ‏Windows, ‏Android", "לא מופיע"),
           ("עדכון אחרון", "Mac 0.9.8, ‏7 בנובמבר 2026", "Google Play: ‏22 ביוני 2026")]))
   , ("vlc", dict(title="IPTVMac מול VLC ל-IPTV: מה כל אחד עושה",
     desc="IPTVMac ו-VLC בהשוואה ל-IPTV: שניהם חינמיים ובקוד פתוח. מה כל אחד עושה עם רשימות M3U, כניסות Xtream Codes, לוח שידורים, צפייה בהיסטוריה וספרייה.",
     h1=["IPTVMac מול", "VLC ל-IPTV"], name="VLC",
     lede="VLC הוא הנגן החינמי בקוד פתוח שפותח כמעט כל דבר. ‏IPTVMac נבנה רק ל-IPTV: הוא הופך כניסה של ספק לספרייה שאפשר לחפש בה.",
     ours=["מתחבר ל-Xtream Codes ובונה ממנו שידור חי, סרטים וסדרות.", "מחפש ב-100,000 כותרים תוך כדי הקלדה, עם מועדפים והמשך צפייה.", "צפייה בהיסטוריה ב-Mac ולוח שידורים מכניסות Xtream Codes."],
     theirs=["מנגן כמעט כל פורמט של קובץ או שידור, הרבה מעבר ל-IPTV.", "יותר פלטפורמות: Linux, מחשבי Mac עם Intel, ‏Apple TV."],
     rows=[("מחיר, פרסומות, חשבון", "חינם, בלי פרסומות, בלי חשבון", "חינם, בלי פרסומות (“no spyware, no ads and no user tracking”)"),
           ("קוד פתוח", "כן, GPL‑3.0", "כן, GPL‑2.0 ‏(iOS: ‏MPL‑2.0 או GPL)"),
           ("פלטפורמות", "Mac ‏(Apple Silicon), ‏Windows, ‏iPhone, ‏iPad, ‏Android, ‏Android TV", "Windows, ‏Mac ‏(Intel ו-Apple Silicon), ‏Linux, ‏Android, ‏Android TV, ‏iPhone, ‏iPad, ‏Apple TV"),
           ("רשימות M3U", "כן, ממוינות לשידור חי, סרטים וסדרות", "כן, נפתחות כרשימת השמעה"),
           ("כניסת Xtream Codes", "כן", "אין תמיכה רשמית"),
           ("לוח שידורים לערוצי IPTV", "מכניסות Xtream Codes", "אין לוח רשמי לרשימות ערוצי M3U"),
           ("צפייה בהיסטוריה", "ב-Mac, עם Xtream Codes", "אין תמיכה רשמית"),
           ("חיפוש בכל הספרייה", "מיידי, 100,000 כותרים", "לא ספריית IPTV"),
           ("תמונה בתוך תמונה", "Mac, ‏iPhone, ‏iPad, ‏Android", "Android"),
           ("גרסה אחרונה", "Mac 0.9.8, ‏7 בנובמבר 2026", "גרסת מחשב 3.0.24, ‏22 בספטמבר 2026")]))
  ],
 ),
}
