"""Copy for the privacy policy and the support page (English and Hebrew). Imported by build.py, which renders it in the site's article layout.
Tokens replaced by build.py: @EMAIL@ (a sentence with the CONTACT_EMAIL set in build.py, empty while that is unset), @ISSUES@ (GitHub issues), @REPO@, @PRIVACY@ and @SUPPORT@ (the other page, same language), @DEMO@ (open-licence demo playlist),
@GUIDES@ (the English guides folder), @FAQ@ (the page's faq list as headings and answers).
Facts here are checked against the code. Change the code, change this text."""

EFFECTIVE = "2026-10-25"
EFFECTIVE_LABEL = {"en": "25 October 2026", "he": "25 באוקטובר 2026"}

UI = {
 "en": dict(bc="Breadcrumb", toc="On this page", eff="Effective", side_h="Questions?", side_btn="Open an issue on GitHub", email='You can also write to <a href="mailto:@MAIL@">@MAIL@</a>.'),
 "he": dict(bc="נתיב", toc="בעמוד זה", eff="בתוקף מ", side_h="שאלות?", side_btn="פתיחת פנייה ב-GitHub", email='אפשר גם לכתוב אל <a href="mailto:@MAIL@" dir="ltr">@MAIL@</a>.'),
}

LEGAL = {
 "privacy": {
  "en": dict(
   crumb="Privacy policy",
   title="Privacy policy | IPTVMac",
   h1="IPTVMac privacy policy",
   desc="IPTVMac has no account, no analytics, no ads and no tracking, and sends nothing to its developer. What it stores stays on your Mac. Plain-language privacy policy.",
   answer="IPTVMac does not collect your data. It has no account, no analytics, no ads and no tracking, and it sends nothing to the developer. What it stores stays on your Mac, and it talks only to the servers you add.",
   body="""
<h2>What IPTVMac does not collect</h2>
<ul>
<li><strong>No personal data.</strong> No name, email address, phone number, location, contacts, device identifier or advertising identifier.</li>
<li><strong>No analytics, crash reports or telemetry.</strong> The app does not report how you use it.</li>
<li><strong>No ads and no tracking</strong>, by us or by anyone else. The app contains no advertising or analytics code from third parties. The source code is public, so you can check.</li>
<li><strong>No account.</strong> You never sign up or log in to IPTVMac itself.</li>
<li><strong>Nothing is sent to the developer.</strong> The developer runs no server that the app talks to.</li>
</ul>
<h2>Who the app talks to</h2>
<p>IPTVMac is a player. It has no content of its own, and it connects only to addresses you give it or that your source gives it:</p>
<ul>
<li><strong>The servers you add.</strong> Your IPTV provider (Xtream Codes), or the server behind your M3U link. IPTVMac downloads your lists from it and plays streams, program guides, catch-up, title details and downloads from it. Your provider sees what any server sees: your IP address, the login you entered and what you watch. What it does with that is set by its own policy, not this one.</li>
<li><strong>The picture and stream addresses inside those lists</strong>, for example channel logos and posters. They can be on other servers chosen by your provider. IPTVMac refuses picture addresses that point to your own local network.</li>
<li><strong>Your web browser, if you choose Trailer</strong> on a title for which your provider supplied a YouTube trailer. The link opens in your browser, and the browser, not IPTVMac, then talks to YouTube.</li>
<li><strong>Seek bar thumbnails</strong> are off by default. If you turn them on, IPTVMac opens a second connection to the same provider.</li>
</ul>
<h2>What is stored on your Mac</h2>
<ul>
<li>The sources you add: name, address and username, and the password (see below).</li>
<li>The channel, movie and series lists downloaded from your source, your favorites, your watch history (the resume position of each title) and your settings.</li>
<li>The download folder you chose, the list of finished downloads, and the downloaded files themselves, in the folder you picked.</li>
<li>Saved logos and posters, so they are not downloaded again. Settings, Playlists, <strong>Clear image cache</strong> removes them.</li>
</ul>
<p>All of this lives in IPTVMac's own private folder on your Mac (in the App Store version, inside the app's sandbox container). Nothing is uploaded, and nothing leaves your Mac except the requests described above.</p>
<p><strong>Passwords.</strong> The password of an Xtream Codes source is stored in IPTVMac's local database on your Mac. It is not stored in the macOS Keychain, and the app does not encrypt it. The database file is readable only by your macOS user account. Anyone who can read your account's files, for example from a backup of your Mac or from malware running as you, could read it. The password is sent only to the provider you entered it for.</p>
<h2>Backup files</h2>
<p>Settings, Playlists, <strong>Export backup…</strong> writes a file only when you ask, to the place you choose. It lists your sources (name, address, username), favorites and watch history. It never contains the password of an Xtream Codes source. An M3U link is saved exactly as you typed it, and some providers put a login inside that link, so treat a backup as private. IPTVMac never sends a backup anywhere.</p>
<h2>Updates</h2>
<ul>
<li><strong>App Store version.</strong> IPTVMac does not check for updates by itself. Updates come through the Mac App Store, under Apple's own privacy terms.</li>
<li><strong>Version downloaded from GitHub.</strong> The app checks GitHub Releases for a newer version (requests to github.com and api.github.com) and verifies the download with a checksum and a signature. Like any web server, GitHub sees your IP address. The app sends no identifier. You can turn this off in Settings, General.</li>
<li><strong>Android version.</strong> The app asks github.com now and then (the public releases feed, at most once every six hours) which Android version is the newest. If a newer one exists it shows a banner with a link to that release page. The app downloads and installs nothing by itself. Like any web server, GitHub sees your IP address. The app sends no identifier. You can turn this off in Settings.</li>
</ul>
<h2>This website</h2>
<p>The site is hosted on GitHub Pages, a free service of GitHub. It sets no cookies and loads no analytics, ads, or third-party scripts, fonts or widgets: everything comes from the same address. It stores one value in your browser's local storage, your light or dark choice, and that never leaves your device. GitHub, as the host, may log visits as described in its own <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement" rel="noopener">privacy statement</a>. Links from here to GitHub, YouTube and other sites are plain links, and those sites have their own policies.</p>
<h2>Keeping and deleting your data</h2>
<p>Everything is on your Mac, so you control it. Delete a source in Settings, Playlists to remove its lists, favorites, watch history and saved password. The <strong>Clear data</strong> buttons erase history, favorites and the image cache. Deleting the app and its folder removes the rest. The developer holds no copy, so there is nothing to request from us, and because no personal data is collected there is no consent to withdraw.</p>
<h2>Children</h2>
<p>IPTVMac collects no data from anyone, including children. It contains no content of its own: what appears depends entirely on the source you add. The category-hiding filter in Settings is a plain filter, not a parental lock.</p>
<h2>Changes to this policy</h2>
<p>If the app's behavior changes, this page changes with it and the effective date is updated. The history of this page is public in the project's <a href="@REPO@/commits/main/scripts/site/legal.py" rel="noopener">git repository</a>.</p>
<h2>Contact</h2>
<p>Questions about this policy: <a href="@ISSUES@" rel="noopener">open an issue on GitHub</a>. Please do not post passwords or full playlist links there. The <a href="@SUPPORT@">support page</a> explains how to report a problem safely. @EMAIL@</p>
""",
  ),
  "he": dict(
   crumb="מדיניות פרטיות",
   title="מדיניות פרטיות | IPTVMac",
   h1="מדיניות הפרטיות של IPTVMac",
   desc="ב-IPTVMac אין חשבון, אנליטיקס, פרסומות או מעקב, והיא לא שולחת דבר למפתח. מה שהיא שומרת נשאר ב-Mac שלכם. מדיניות פרטיות בשפה פשוטה.",
   answer="IPTVMac לא אוספת עליכם מידע. אין בה חשבון, אנליטיקס, פרסומות או מעקב, והיא לא שולחת דבר למפתח. מה שהיא שומרת נשאר ב-Mac שלכם, והיא מדברת רק עם השרתים שהוספתם.",
   body="""
<h2>מה IPTVMac לא אוספת</h2>
<ul>
<li><strong>אין מידע אישי.</strong> לא שם, לא כתובת אימייל, לא מספר טלפון, לא מיקום, לא אנשי קשר, לא מזהה מכשיר ולא מזהה פרסום.</li>
<li><strong>אין אנליטיקס, דוחות קריסה או טלמטריה.</strong> האפליקציה לא מדווחת איך אתם משתמשים בה.</li>
<li><strong>אין פרסומות ואין מעקב</strong>, לא מצידנו ולא מצד אחרים. באפליקציה אין קוד פרסום או אנליטיקס של צד שלישי. קוד המקור פומבי, אפשר לבדוק.</li>
<li><strong>אין חשבון.</strong> לא נרשמים ולא מתחברים ל-IPTVMac עצמה.</li>
<li><strong>דבר לא נשלח למפתח.</strong> אין שרת של המפתח שהאפליקציה מדברת איתו.</li>
</ul>
<h2>עם מי האפליקציה מדברת</h2>
<p>IPTVMac היא נגן. אין בה תוכן משלה, והיא מתחברת רק לכתובות שמסרתם לה או שהמקור שלכם מסר לה:</p>
<ul>
<li><strong>השרתים שהוספתם.</strong> ספק ה-IPTV שלכם (Xtream Codes), או השרת שמאחורי קישור ה-M3U. IPTVMac מורידה ממנו את הרשימות, ומנגנת ממנו סטרימים, לוח שידורים, צפייה בהיסטוריה, פרטי כותרים והורדות. הספק רואה את מה שכל שרת רואה: את כתובת ה-IP שלכם, את פרטי ההתחברות שהזנתם ואת מה שאתם צופים בו. מה הוא עושה עם זה נקבע במדיניות שלו, לא במדיניות הזו.</li>
<li><strong>כתובות התמונות והסטרימים שבתוך הרשימות האלה</strong>, למשל לוגואים של ערוצים וכרזות. הן יכולות להיות בשרתים אחרים שהספק בחר. IPTVMac מסרבת לכתובות תמונה שמצביעות אל הרשת המקומית שלכם.</li>
<li><strong>הדפדפן שלכם, אם בחרתם “טריילר”</strong> בכותר שהספק צירף לו טריילר ביוטיוב. הקישור נפתח בדפדפן, והדפדפן, לא IPTVMac, מתחבר אז ליוטיוב.</li>
<li><strong>תצוגה מקדימה בסרגל ההתקדמות</strong> כבויה כברירת מחדל. אם הפעלתם אותה, IPTVMac פותחת חיבור שני לאותו ספק.</li>
</ul>
<h2>מה נשמר ב-Mac שלכם</h2>
<ul>
<li>המקורות שהוספתם: שם, כתובת ושם משתמש, והסיסמה (ראו בהמשך).</li>
<li>רשימות הערוצים, הסרטים והסדרות שהורדו מהמקור שלכם, המועדפים, היסטוריית הצפייה (נקודת ההמשך בכל כותר) וההגדרות.</li>
<li>תיקיית ההורדות שבחרתם, רשימת ההורדות שהסתיימו, והקבצים שהורדו, בתיקייה שבחרתם.</li>
<li>לוגואים וכרזות שמורים, כדי שלא יורדו שוב. “נקה מטמון תמונות” בהגדרות, בלשונית רשימות, מסיר אותם.</li>
</ul>
<p>כל זה נשמר בתיקייה הפרטית של IPTVMac ב-Mac שלכם (בגרסת ה-App Store, בתוך מכל ה-sandbox של האפליקציה). דבר לא מועלה לשום מקום, ודבר לא יוצא מה-Mac מלבד הבקשות שתוארו למעלה.</p>
<p><strong>סיסמאות.</strong> הסיסמה של מקור Xtream Codes נשמרת במסד הנתונים המקומי של IPTVMac ב-Mac שלכם. היא לא נשמרת ב-Keychain של macOS והאפליקציה לא מצפינה אותה. קובץ מסד הנתונים נקרא רק על ידי חשבון המשתמש שלכם ב-macOS. מי שיכול לקרוא את קבצי החשבון שלכם, למשל מגיבוי של ה-Mac או מתוכנה זדונית שרצה בשמכם, יוכל לקרוא אותה. הסיסמה נשלחת רק לספק שעבורו הזנתם אותה.</p>
<h2>קובצי גיבוי</h2>
<p>“ייצוא גיבוי…” בהגדרות, בלשונית רשימות, יוצר קובץ רק כשאתם מבקשים, במקום שבחרתם. הוא מכיל את המקורות שלכם (שם, כתובת, שם משתמש), מועדפים והיסטוריית צפייה. הוא אף פעם לא מכיל את הסיסמה של מקור Xtream Codes. קישור M3U נשמר בדיוק כפי שהקלדתם, וחלק מהספקים שמים פרטי התחברות בתוך הקישור, ולכן התייחסו לגיבוי כאל קובץ פרטי. IPTVMac לא שולחת גיבוי לשום מקום.</p>
<h2>עדכונים</h2>
<ul>
<li><strong>גרסת ה-App Store.</strong> IPTVMac לא בודקת עדכונים בעצמה. העדכונים מגיעים דרך ה-Mac App Store, לפי תנאי הפרטיות של Apple.</li>
<li><strong>גרסה שהורדה מ-GitHub.</strong> האפליקציה בודקת ב-GitHub Releases אם יש גרסה חדשה (בקשות אל github.com ו-api.github.com) ובודקת את ההורדה מול סכום ביקורת וחתימה. כמו כל שרת אינטרנט, GitHub רואה את כתובת ה-IP שלכם. האפליקציה לא שולחת שום מזהה. אפשר לכבות את הבדיקה בהגדרות, בלשונית כללי.</li>
<li><strong>גרסת Android.</strong> האפליקציה פונה מדי פעם אל github.com (הפיד הציבורי של הגרסאות, לכל היותר אחת לשש שעות) ושואלת מהי גרסת ה-Android החדשה ביותר. אם יש חדשה יותר מוצג באנר עם קישור לעמוד הגרסה. האפליקציה לא מורידה ולא מתקינה כלום בעצמה. כמו כל שרת אינטרנט, GitHub רואה את כתובת ה-IP שלכם. האפליקציה לא שולחת שום מזהה. אפשר לכבות את זה בהגדרות.</li>
</ul>
<h2>האתר הזה</h2>
<p>האתר מתארח ב-GitHub Pages, שירות חינמי של GitHub. הוא לא יוצר עוגיות ולא טוען אנליטיקס, פרסומות, או סקריפטים, גופנים ווידג׳טים של צד שלישי: הכול נטען מאותה כתובת. הוא שומר ערך אחד באחסון המקומי של הדפדפן, את בחירת המראה הבהיר או הכהה, והערך הזה לא עוזב את המכשיר שלכם. GitHub, כמארח, עשוי לתעד ביקורים כמתואר ב<a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement" rel="noopener">הצהרת הפרטיות שלו</a> (באנגלית). קישורים מכאן אל GitHub, יוטיוב ואתרים אחרים הם קישורים רגילים, ולאתרים האלה יש מדיניות משלהם.</p>
<h2>שמירה ומחיקה של הנתונים</h2>
<p>הכול נמצא ב-Mac שלכם, ולכן אתם שולטים בזה. מחיקת מקור בהגדרות, בלשונית רשימות, מסירה את הרשימות, המועדפים, היסטוריית הצפייה והסיסמה השמורה שלו. הכפתורים תחת “מחיקת נתונים” מוחקים היסטוריה, מועדפים ומטמון תמונות. מחיקת האפליקציה והתיקייה שלה מסירה את השאר. למפתח אין עותק, ולכן אין מה לבקש ממנו, ומכיוון שלא נאסף מידע אישי אין הסכמה לבטל.</p>
<h2>ילדים</h2>
<p>IPTVMac לא אוספת מידע משום אדם, כולל ילדים. אין בה תוכן משלה: מה שמופיע תלוי כולו במקור שהוספתם. מסנן הסתרת הקטגוריות בהגדרות הוא מסנן פשוט, לא נעילת הורים.</p>
<h2>שינויים במדיניות</h2>
<p>אם התנהגות האפליקציה משתנה, העמוד הזה משתנה איתה ותאריך התוקף מתעדכן. ההיסטוריה של העמוד פומבית ב<a href="@REPO@/commits/main/scripts/site/legal.py" rel="noopener">מאגר ה-git של הפרויקט</a>.</p>
<h2>יצירת קשר</h2>
<p>שאלות על המדיניות: <a href="@ISSUES@" rel="noopener">פתחו פנייה ב-GitHub</a> (באנגלית עדיף, עברית מתקבלת). בבקשה לא לפרסם שם סיסמאות או קישורי רשימה מלאים. <a href="@SUPPORT@">עמוד התמיכה</a> מסביר איך לדווח על בעיה בצורה בטוחה. @EMAIL@</p>
""",
  ),
 },
 "support": {
  "en": dict(
   crumb="Support",
   title="Support | IPTVMac",
   h1="IPTVMac support",
   desc="How to add a source to IPTVMac, what to check when nothing plays, and how to report a bug on GitHub without sharing your login.",
   answer="IPTVMac is a free player for Mac. It has no content of its own, so you first add a source from your IPTV provider. Most problems are a wrong password, a second connection, or an expired playlist link. For anything else, open an issue on GitHub, and leave your login out of it.",
   faq=[
    ("Does IPTVMac include channels, movies or a subscription?", "No. IPTVMac is only a player. It does not include, host or sell any content. You add a source from a provider you are authorized to use."),
    ("Which Macs are supported?", "Apple Silicon Macs (M1 or later) with macOS 14 or later."),
    ("Does it work with Xtream Codes and M3U?", "Yes. Xtream Codes needs the server address, username and password from your provider. M3U needs the playlist link. A local .m3u file is not supported yet."),
    ("Can I download movies?", "Yes, from your own source. Download saves a movie or episode that your provider streams to you into a folder you choose. IPTVMac does not download from any other service. Use it only for what your provider allows."),
    ("Does IPTVMac remove copy protection?", "No. IPTVMac contains no code to bypass copy protection. It plays the streams your provider serves for normal playback, and streams protected by DRM (FairPlay, Widevine, PlayReady) do not play."),
    ("Is my data private?", "Yes. IPTVMac has no account, no analytics and no ads, and it sends nothing to the developer. Everything stays on your Mac. The privacy policy has the details."),
    ("Which languages does it speak?", "31. IPTVMac follows your Mac's language, or you choose one in Settings, General, Interface language (it applies after a restart)."),
   ],
   body="""
<h2>Add your first source</h2>
<p>IPTVMac has no channels of its own. You add a source from your IPTV provider (Xtream Codes) or a link to an M3U playlist.</p>
<ol>
<li>Open IPTVMac. On the first launch the welcome guide opens: click <strong>Next</strong>. Later, open <strong>Settings</strong> (IPTVMac menu, or Command-comma), the <strong>Playlists</strong> tab, then <strong>Add source…</strong></li>
<li>Choose <strong>Xtream Codes</strong> or <strong>M3U</strong>. For Xtream Codes fill in <strong>Name</strong>, <strong>Server address</strong> (for example <code>http://host:8080</code>), <strong>Username</strong> and <strong>Password</strong>. For M3U fill in <strong>Name</strong> and <strong>Playlist link</strong>. Click <strong>Next</strong>.</li>
<li>Click <strong>Test connection</strong>. When it says “Connected successfully”, click <strong>Save and sync</strong>. Your channels appear under <strong>Live</strong>, <strong>Movies</strong> and <strong>Series</strong>.</li>
</ol>
<p>Step by step with more detail: <a href="@GUIDES@xtream-codes-on-mac.html">Xtream Codes on a Mac</a> and <a href="@GUIDES@m3u-playlist-on-mac.html">an M3U playlist on a Mac</a>.</p>
<h2>Try it without a provider</h2>
<p>This playlist holds only open-licence films by the Blender Foundation (Creative Commons Attribution), served by public hosts:</p>
<p><code>@DEMO@</code></p>
<p>Choose <strong>M3U</strong>, paste it as the <strong>Playlist link</strong>, and you get a few entries each under Live, Movies and Series. It is also a quick way to tell whether a problem is in IPTVMac or in your provider's source.</p>
<h2>If something does not work</h2>
<ul>
<li><strong>Nothing plays, or “Playback failed”.</strong> Click <strong>Retry</strong>. Then check the password: Settings, Playlists, <strong>Change password…</strong> Providers answer wrong credentials in different ways, so a wrong password can look like a network error.</li>
<li><strong>It plays once, then fails.</strong> Many accounts allow one connection at a time. Close other players and devices that use the account, and wait for downloads to finish. Turn off <strong>Preview thumbnails on the seek bar</strong> in Settings, Player: it opens a second connection.</li>
<li><strong>The video stutters.</strong> In Settings, Player, set <strong>Network buffer</strong> to Large.</li>
<li><strong>“Sync failed”, or the lists are old.</strong> IPTVMac shows saved data when your provider cannot be reached. Click the refresh button in the toolbar to try again.</li>
<li><strong>The playlist link stopped working.</strong> Providers change or expire links. Get a new one from your provider and add it again.</li>
</ul>
<p>IPTVMac cannot fix problems on the provider's side, such as an expired subscription, missing channels or billing. Those go to your provider.</p>
<h2>Report a problem without sharing your login</h2>
<p>Open an issue on GitHub: <a href="@ISSUES@" rel="noopener">@ISSUES@</a>, then <strong>New issue</strong>. GitHub issues are public, so everyone can read what you write.</p>
<div class="warn"><p><strong>Never post these:</strong></p>
<ul>
<li>Your password or username.</li>
<li>A full M3U link. Many contain a login. Write <code>http://example.com/list.m3u</code> instead.</li>
<li>Your provider's server address, if it identifies your account. Write <code>http://host:8080</code> instead.</li>
<li>Screenshots or recordings that show Settings, Playlists or any address, and backup files (they list your sources).</li>
</ul>
<p>If you posted a login by mistake, change the password with your provider first, then edit or delete the comment.</p></div>
<p>Do include:</p>
<ul>
<li>Your Mac model, the macOS version, and the IPTVMac version (IPTVMac menu, About IPTVMac).</li>
<li>Whether the source is Xtream Codes or M3U, and whether the problem is in Live, Movies or Series.</li>
<li>What you did, what you expected, what happened, and the text of any error message.</li>
<li>Whether the same thing happens with the demo playlist above.</li>
</ul>
<h2>Your data</h2>
<p>Back up with Settings, Playlists, <strong>Export backup…</strong> and restore with <strong>Import backup…</strong>. A backup holds your sources, favorites and watch history. It does not hold Xtream Codes passwords (IPTVMac asks for them again), and it holds M3U links as you typed them, so keep the file private. Remove a source with <strong>Delete</strong>, and erase history, favorites or the image cache under <strong>Clear data</strong>. Everything stays on your Mac: see the <a href="@PRIVACY@">privacy policy</a>.</p>
<h2>Questions</h2>
@FAQ@
<h2>Contact</h2>
<p>Bugs, questions and feature requests all go to <a href="@ISSUES@" rel="noopener">GitHub issues</a>. IPTVMac is maintained by one developer, so replies are best effort. The source code is public at <a href="@REPO@" rel="noopener">@REPO@</a>. @EMAIL@</p>
<h2>Support the project</h2>
<p>IPTVMac is free on every platform, with no ads and nothing locked, and it stays that way. If it is useful to you and you want to help its development, you can <a href="@COFFEE@" rel="noopener">buy me a coffee</a>. It is entirely voluntary.</p>
""",
  ),
  "he": dict(
   crumb="תמיכה",
   title="תמיכה | IPTVMac",
   h1="תמיכה ב-IPTVMac",
   desc="איך מוסיפים מקור ל-IPTVMac, מה לבדוק כששום דבר לא מתנגן או כשהשידור נתקע, ואיך מדווחים על באג ב-GitHub בלי לחשוף את פרטי ההתחברות שלכם.",
   answer="IPTVMac היא נגן חינמי ל-Mac. אין בה תוכן משלה, ולכן קודם מוסיפים מקור מספק ה-IPTV שלכם. רוב הבעיות הן סיסמה שגויה, חיבור שני במקביל או קישור רשימה שפג תוקפו. לכל דבר אחר, פתחו פנייה ב-GitHub, ובלי פרטי ההתחברות שלכם.",
   faq=[
    ("האם IPTVMac כוללת ערוצים, סרטים או מנוי?", "לא. IPTVMac היא נגן בלבד. היא לא כוללת, לא מארחת ולא מוכרת תוכן. מוסיפים מקור מספק שמותר לכם להשתמש בו."),
    ("אילו מחשבי Mac נתמכים?", "מחשבי Mac עם Apple Silicon (M1 ומעלה) ו-macOS 14 ומעלה."),
    ("האם זה עובד עם Xtream Codes ו-M3U?", "כן. ב-Xtream Codes צריך כתובת שרת, שם משתמש וסיסמה מהספק. ב-M3U צריך את הקישור לרשימה. קובץ m3u מקומי עדיין לא נתמך."),
    ("אפשר להוריד סרטים?", "כן, מהמקור שלכם. “הורד” שומר סרט או פרק שהספק שלכם משדר אליכם, בתיקייה שבחרתם. IPTVMac לא מורידה משום שירות אחר. השתמשו בזה רק במה שהספק שלכם מתיר."),
    ("האם IPTVMac מסירה הגנת העתקה?", "לא. אין ב-IPTVMac קוד שעוקף הגנת העתקה. היא מנגנת את הסטרימים שהספק שלכם משדר להשמעה רגילה, וסטרימים שמוגנים ב-DRM (FairPlay, Widevine, PlayReady) לא מתנגנים."),
    ("האם המידע שלי פרטי?", "כן. ב-IPTVMac אין חשבון, אנליטיקס או פרסומות, והיא לא שולחת דבר למפתח. הכול נשאר ב-Mac שלכם. הפרטים במדיניות הפרטיות."),
    ("באילו שפות היא זמינה?", "31. IPTVMac פועלת בשפת ה-Mac שלכם, או שבוחרים שפה בהגדרות, בלשונית כללי, תחת שפת הממשק (נכנס לתוקף אחרי הפעלה מחדש)."),
   ],
   body="""
<h2>הוספת המקור הראשון</h2>
<p>ל-IPTVMac אין ערוצים משלה. מוסיפים מקור מספק ה-IPTV שלכם (Xtream Codes) או קישור לרשימת M3U.</p>
<ol>
<li>פותחים את IPTVMac. בהפעלה הראשונה נפתח מדריך הפתיחה: לוחצים <strong>הבא</strong>. אחר כך אפשר לפתוח <strong>הגדרות</strong> (תפריט IPTVMac, או Command ופסיק), את הלשונית <strong>רשימות</strong> ואז <strong>הוסף מקור…</strong></li>
<li>בוחרים <strong>Xtream Codes</strong> או <strong>M3U</strong>. ב-Xtream Codes ממלאים <strong>שם</strong>, <strong>כתובת שרת</strong> (למשל <code dir="ltr">http://host:8080</code>), <strong>שם משתמש</strong> ו<strong>סיסמה</strong>. ב-M3U ממלאים <strong>שם</strong> ו<strong>קישור לרשימה</strong>. לוחצים <strong>הבא</strong>.</li>
<li>לוחצים <strong>בדוק חיבור</strong>. כשמופיע “החיבור הצליח”, לוחצים <strong>שמור וסנכרן</strong>. הערוצים מופיעים תחת <strong>שידור חי</strong>, <strong>סרטים</strong> ו<strong>סדרות</strong>.</li>
</ol>
<p>בפירוט רב יותר, באנגלית: <a href="@GUIDES@xtream-codes-on-mac.html">Xtream Codes ב-Mac</a> ו<a href="@GUIDES@m3u-playlist-on-mac.html">רשימת M3U ב-Mac</a>.</p>
<h2>לנסות בלי ספק</h2>
<p>הרשימה הזו כוללת רק סרטים ברישיון פתוח של Blender Foundation (Creative Commons Attribution), שמשודרים משרתים ציבוריים:</p>
<p><code dir="ltr">@DEMO@</code></p>
<p>בוחרים <strong>M3U</strong>, מדביקים אותה בשדה <strong>קישור לרשימה</strong>, ומקבלים כמה פריטים בכל אחד מהחלקים שידור חי, סרטים וסדרות. זו גם דרך מהירה לברר אם הבעיה ב-IPTVMac או במקור של הספק שלכם.</p>
<h2>כשמשהו לא עובד</h2>
<ul>
<li><strong>לא מנגן כלום, או “ההשמעה נכשלה”.</strong> לוחצים <strong>נסה שוב</strong>. אחר כך בודקים את הסיסמה: הגדרות, רשימות, <strong>שנה סיסמה…</strong> ספקים מגיבים לפרטי התחברות שגויים בדרכים שונות, ולכן סיסמה שגויה יכולה להיראות כמו תקלת רשת.</li>
<li><strong>מנגן פעם אחת ואז נכשל.</strong> בהרבה חשבונות מותר חיבור אחד בכל פעם. סוגרים נגנים ומכשירים אחרים שמשתמשים בחשבון, ומחכים שההורדות יסתיימו. מכבים את <strong>תצוגה מקדימה בסרגל ההתקדמות</strong> בהגדרות, בלשונית נגן: היא פותחת חיבור שני.</li>
<li><strong>הווידאו מגמגם.</strong> בהגדרות, בלשונית נגן, מגדירים <strong>מאגר רשת</strong> לגדול.</li>
<li><strong>“הסנכרון נכשל”, או שהרשימות ישנות.</strong> IPTVMac מציגה נתונים שמורים כשאי אפשר להגיע לספק. לוחצים על כפתור הרענון בסרגל הכלים כדי לנסות שוב.</li>
<li><strong>קישור הרשימה הפסיק לעבוד.</strong> ספקים משנים קישורים או מבטלים אותם. מבקשים קישור חדש מהספק ומוסיפים אותו מחדש.</li>
</ul>
<p>IPTVMac לא יכולה לתקן בעיות בצד של הספק, כמו מנוי שפג תוקפו, ערוצים חסרים או חיוב. את אלה מפנים לספק.</p>
<h2>דיווח על בעיה בלי לחשוף את פרטי ההתחברות</h2>
<p>פותחים פנייה ב-GitHub: <a href="@ISSUES@" rel="noopener" dir="ltr">@ISSUES@</a>, ואז <strong>New issue</strong>. הפניות ב-GitHub פומביות, ולכן כל אחד יכול לקרוא מה שכתבתם.</p>
<div class="warn"><p><strong>לעולם לא לפרסם:</strong></p>
<ul>
<li>את הסיסמה או את שם המשתמש.</li>
<li>קישור M3U מלא. בהרבה מהם יש פרטי התחברות. כתבו במקומו <code dir="ltr">http://example.com/list.m3u</code>.</li>
<li>את כתובת השרת של הספק, אם היא מזהה את החשבון שלכם. כתבו במקומה <code dir="ltr">http://host:8080</code>.</li>
<li>צילומי מסך או הקלטות שמראים את ההגדרות, את לשונית רשימות או כתובת כלשהי, וקובצי גיבוי (הם מפרטים את המקורות שלכם).</li>
</ul>
<p>אם פרסמתם פרטי התחברות בטעות, קודם מחליפים את הסיסמה אצל הספק, ואז עורכים או מוחקים את התגובה.</p></div>
<p>כדאי לצרף:</p>
<ul>
<li>את דגם ה-Mac, את גרסת macOS ואת גרסת IPTVMac (תפריט IPTVMac, אודות IPTVMac).</li>
<li>אם המקור הוא Xtream Codes או M3U, ואם הבעיה בשידור חי, בסרטים או בסדרות.</li>
<li>מה עשיתם, מה ציפיתם שיקרה, מה קרה, ואת הטקסט של כל הודעת שגיאה.</li>
<li>אם אותו דבר קורה גם ברשימת ההדגמה שלמעלה.</li>
</ul>
<h2>הנתונים שלכם</h2>
<p>מגבים ב”הגדרות, רשימות, <strong>ייצוא גיבוי…</strong>” ומשחזרים ב<strong>ייבוא גיבוי…</strong>. הגיבוי מכיל את המקורות, המועדפים והיסטוריית הצפייה. הוא לא מכיל סיסמאות של Xtream Codes (IPTVMac מבקשת אותן שוב), והוא מכיל קישורי M3U כפי שהקלדתם אותם, ולכן שמרו את הקובץ פרטי. מסירים מקור ב<strong>מחק</strong>, ומוחקים היסטוריה, מועדפים או מטמון תמונות תחת <strong>מחיקת נתונים</strong>. הכול נשאר ב-Mac שלכם: ראו את <a href="@PRIVACY@">מדיניות הפרטיות</a>.</p>
<h2>שאלות נפוצות</h2>
@FAQ@
<h2>יצירת קשר</h2>
<p>באגים, שאלות ובקשות לתכונות מופנים אל <a href="@ISSUES@" rel="noopener">הפניות ב-GitHub</a>. IPTVMac מתוחזקת על ידי מפתח אחד, ולכן מענה ניתן במאמץ סביר. קוד המקור פומבי ב-<a href="@REPO@" rel="noopener">@REPO@</a>. @EMAIL@</p>
<h2>תמיכה בפרויקט</h2>
<p>IPTVMac חינמית בכל הפלטפורמות, בלי פרסומות ובלי שום דבר נעול, וכך היא תישאר. אם היא מועילה לכם ואתם רוצים לעזור לפיתוח שלה, אפשר <a href="@COFFEE@" rel="noopener">לקנות לי קפה</a>. זה לגמרי מרצון.</p>
""",
  ),
 },
}
