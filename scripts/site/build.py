#!/usr/bin/env python3
"""Generates the static website in docs/ (home EN + HE, three guides, robots.txt, sitemap.xml, llms.txt).
Run: python3 scripts/site/build.py   (no dependencies). Edit the content below, not the generated HTML."""
import json, html, pathlib, re, hashlib, shutil

ROOT = pathlib.Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs"
VERSION = (ROOT / "VERSION").read_text().strip()
BASE = "https://goelir.github.io/IPTVMac/"
REPO = "https://github.com/Goelir/IPTVMac"
DOWNLOAD = REPO + "/releases/latest"
FREE_REPO = "https://github.com/iptv-org/iptv"
FREE_M3U = "https://iptv-org.github.io/iptv/index.m3u"
YT_INSTALL = "https://youtu.be/TgaoFEEMg48"
INSTALL_CMD = "curl -fsSL https://raw.githubusercontent.com/Goelir/IPTVMac/main/install.sh | bash"
UPDATED = "2026-10-06"
e = html.escape

# CSS and JS live next to this script and are copied into docs/assets with a content hash for cache busting.
SRC = pathlib.Path(__file__).resolve().parent
ASSET_V = ""
def publish_assets():
    global ASSET_V
    h = hashlib.sha1()
    for n in ("site.css", "site.js"):
        shutil.copyfile(SRC / n, DOCS / "assets" / n)
        h.update((SRC / n).read_bytes())
    ASSET_V = h.hexdigest()[:8]

# ---------- shared pieces ----------
def head(title, desc, canonical, lang, depth, alternates=(), og_type="website", extra_ld=()):
    up = "../" * depth
    alts = "".join(f'<link rel="alternate" hreflang="{l}" href="{u}">' for l, u in alternates)
    ld = "".join(f'<script type="application/ld+json">{json.dumps(o, ensure_ascii=False)}</script>' for o in extra_ld)
    fonts = "".join(f'<link rel="preload" href="{up}assets/fonts/plex-{f}.woff2" as="font" type="font/woff2" crossorigin>'
                    for f in (["latin-400", "latin-600"] + (["hebrew-400", "hebrew-600"] if lang == "he" else [])))
    return f'''<!doctype html>
<html lang="{lang}" dir="{'rtl' if lang == 'he' else 'ltr'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(title)}</title>
<meta name="description" content="{e(desc)}">
<link rel="canonical" href="{canonical}">
{alts}
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#f4f5f9" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0c0e16" media="(prefers-color-scheme: dark)">
<meta property="og:type" content="{og_type}">
<meta property="og:site_name" content="IPTVMac">
<meta property="og:locale" content="{'he_IL' if lang == 'he' else 'en_US'}">
<meta property="og:title" content="{e(title)}">
<meta property="og:description" content="{e(desc)}">
<meta property="og:url" content="{canonical}">
<meta property="og:image" content="{BASE}social-preview.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{e(title)}">
<meta name="twitter:description" content="{e(desc)}">
<meta name="twitter:image" content="{BASE}social-preview.png">
<link rel="icon" type="image/png" href="{up}assets/favicon.png">
<link rel="apple-touch-icon" href="{up}assets/apple-touch-icon.png">
{fonts}
<link rel="stylesheet" href="{up}assets/site.css?v={ASSET_V}">
<script>document.documentElement.classList.add("js")</script>
{ld}
</head>
<body>
'''

def pic(up, name, alt, attrs="", cls="shot"):
    # WebP (1200 px wide) first, JPEG fallback; regenerate with: cwebp -q 78 -resize 1200 0 NN-x.jpg -o NN-x.webp
    return (f'<picture><source type="image/webp" srcset="{up}screenshots/{name}.webp">'
            f'<img class="{cls}" src="{up}screenshots/{name}.jpg" width="1800" height="1130" alt="{e(alt)}" {attrs}></picture>')

ICON_COPY = '<svg class="cp" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5.5" y="5.5" width="8" height="8" rx="1.8"/><path d="M10.5 5.5V4a1.8 1.8 0 0 0-1.8-1.8H4A1.8 1.8 0 0 0 2.2 4v4.7A1.8 1.8 0 0 0 4 10.5h1.5"/></svg>'
ICON_OK = '<svg class="ok" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 8.5l3.2 3.2L13 4.8"/></svg>'
ICON_CHEV = '<svg class="chev" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3l5 5-5 5"/></svg>'
ICON_DL = '<svg viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 2.5v9m0 0L5.5 8M9 11.5L12.5 8M3 14.5h12"/></svg>'
ICON_GH = '<svg viewBox="0 0 18 18" fill="currentColor" aria-hidden="true"><path d="M9 1.2a7.8 7.8 0 0 0-2.47 15.2c.39.07.53-.17.53-.37v-1.4c-2.17.47-2.63-1.04-2.63-1.04-.35-.9-.87-1.14-.87-1.14-.71-.49.05-.48.05-.48.78.06 1.2.81 1.2.81.7 1.2 1.83.85 2.28.65.07-.51.27-.85.5-1.05-1.73-.2-3.55-.87-3.55-3.86 0-.85.3-1.55.8-2.1-.08-.2-.35-1 .08-2.07 0 0 .65-.21 2.14.8a7.4 7.4 0 0 1 3.9 0c1.49-1.01 2.14-.8 2.14-.8.43 1.07.16 1.87.08 2.07.5.55.8 1.25.8 2.1 0 3-1.82 3.66-3.56 3.85.28.24.53.72.53 1.45v2.15c0 .2.14.45.54.37A7.8 7.8 0 0 0 9 1.2z"/></svg>'
ICON_PLAY = '<svg viewBox="0 0 22 22" aria-hidden="true"><rect width="22" height="22" rx="6" fill="currentColor"/><path d="M8.6 6.8v8.4l7-4.2z" fill="var(--bg)"/></svg>'

def cmd_block(copy, done):
    return (f'<div class="cmd"><span class="prompt" aria-hidden="true">$</span><code>{e(INSTALL_CMD)}</code>'
            f'<button class="copy" type="button" data-done="{e(done)}">{ICON_COPY}{ICON_OK}<span class="lbl">{e(copy)}</span></button>'
            f'<span class="sr" role="status" aria-live="polite"></span></div>')

def software_ld(desc, lang):
    return {
        "@context": "https://schema.org", "@type": "SoftwareApplication", "name": "IPTVMac",
        "applicationCategory": "MultimediaApplication", "operatingSystem": "macOS 14 or later (Apple Silicon)",
        "softwareVersion": VERSION, "description": desc, "url": BASE, "inLanguage": ["en", "he", "ar", "es", "fr", "de", "pt", "it", "ru", "uk", "pl", "ro", "bg", "nl", "sv", "cs", "hu", "el", "sq", "tr", "fa", "ur", "hi", "bn", "id", "vi", "th", "zh-Hans", "zh-Hant", "ja", "ko"],
        "downloadUrl": DOWNLOAD, "license": "https://www.gnu.org/licenses/gpl-3.0.html", "isAccessibleForFree": True,
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
        "image": BASE + "social-preview.png",
        "screenshot": [BASE + f"screenshots/{n}.jpg" for n in ("01-live", "02-search", "05-player", "06-pip")],
        "author": {"@type": "Person", "name": "Goelir", "url": "https://github.com/Goelir"},
        "sameAs": [REPO],
        "featureList": ["Xtream Codes and M3U sources", "Instant full-text search", "Built-in mpv player with subtitles",
                        "Picture in Picture", "Catch-up TV", "Downloads", "Several playlists", "Playback speed 0.25x to 4x", "Sleep timer",
                        "Backup and restore", "Interface in 31 languages"],
    }

def faq_ld(items):
    return {"@context": "https://schema.org", "@type": "FAQPage",
            "mainEntity": [{"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in items]}

def video_ld(name, desc):
    return {"@context": "https://schema.org", "@type": "VideoObject", "name": name, "description": desc, "embedUrl": "https://www.youtube.com/embed/TgaoFEEMg48", "url": YT_INSTALL,
            "thumbnailUrl": BASE + "assets/demo-poster.jpg", "uploadDate": UPDATED, "contentUrl": BASE + "assets/demo.mp4"}

# ---------- home pages ----------
HOME = {
 "en": dict(
  lang="en", prefix="", up="",
  title="IPTVMac: IPTV Player for Mac (Xtream Codes and M3U)",
  desc="IPTVMac is a free, open source IPTV player for Mac. Xtream Codes and M3U, instant search, Picture in Picture, catch-up, downloads and subtitles. Apple Silicon, macOS 14+.",
  nav=[("#features", "Features"), ("#install", "Install"), ("#faq", "FAQ"), ("#guides", "Guides"), (REPO, "GitHub"), ("he/", "עברית")],
  h1="IPTV player for Mac, built natively",
  lede="Xtream Codes and M3U sources, instant search, Picture in Picture, catch-up and downloads. Free and open source.",
  dl="Download for Mac", src="View source on GitHub",
  meta=f"Version {VERSION}. Apple Silicon, macOS 14 or later.",
  alt_movies="IPTVMac movies screen with poster grid and category sidebar",
  alt_player="IPTVMac full screen player showing a film scene",
  demo_h="Watch it work", demo_p="An 80 second tour: live channels, search, favorites, the player, 2x speed, Picture in Picture and downloads. The channels and posters are invented for the demo; the footage is the Blender Foundation film Sintel.",
  feats_h="What you get",
  feats=[
   ("02-search", "Search that keeps up with 100,000 items", "Type to search inside a category, inside a section, or everywhere. Results appear as you type and are grouped into live, movies and series.", "IPTVMac global search results grouped by live, movies and series"),
   ("05-player", "A player that copes with bad streams", "Built on mpv. It plays the broken TS and HLS streams that system players give up on, reconnects when a stream drops, and hides its controls so the picture fills the screen.", "IPTVMac player in full screen"),
   ("06-pip", "Keep watching while you browse", "A floating Picture in Picture window stays on top, across Spaces. Pick another channel or movie and the video keeps playing.", "IPTVMac Picture in Picture window floating over the movie list"),
   ("07-downloads", "Save movies and whole seasons", "Download movies and episodes, or a whole season on Xtream series, to a folder you choose. Play them from the Downloads screen.", "IPTVMac Downloads screen"),
  ],
  small=[("Subtitles and audio", "Embedded tracks, .srt and .ass files by menu or drag and drop, size and delay, preferred languages."),
         ("Catch-up and guide", "Watch past programs on channels that support it, and see what is on now and next."),
         ("Next episode", "When an episode ends, the next one starts after a 5 second countdown. You can cancel it."),
         ("Favorites and resume", "Star channels and movies. Movies and episodes continue where you stopped."),
         ("Several playlists", "Switch between playlists from the toolbar, or show all of them together with the playlist name on each item."),
         ("Speed, skip and sleep timer", "Play from 0.25x to 4x, choose the skip step, and set a sleep timer."),
         ("Backup and settings", "Export playlists (without passwords), favorites and history; light or dark appearance; hide categories by words."),
         ("31 languages", "Hebrew, English, Arabic, Spanish, French, German, Russian, Chinese, Japanese, Hindi and more, with right-to-left layout. Pick one in Settings."),
         ("Updates itself", "Checks GitHub Releases, verifies a SHA-256 checksum and installs the new version.")],
  install_h="Install in one line", install_p="Paste this in Terminal. It downloads the latest release, checks its SHA-256, copies IPTVMac to Applications and opens it.",
  copy="Copy", copied="Copied", video="Watch the 95-second install video on YouTube",
  why="Why a command? IPTVMac is not notarized by Apple, which needs a paid developer account, and macOS blocks apps that a browser marked as downloaded from the internet. A file fetched with curl is not marked, so there is nothing to bypass. The script is short and public: install.sh.",
  dmg_h="Or download the DMG", dmg_steps=["Open IPTVMac.dmg and drag the app onto the Applications icon.", "The first launch is blocked: open System Settings, Privacy &amp; Security, and choose Open Anyway next to IPTVMac.", "Or run xattr -dr com.apple.quarantine /Applications/IPTVMac.app in Terminal."],
  free_h="No playlist yet?",
  free_p="IPTVMac is only a player, so it needs a playlist. If you do not have a provider, iptv-org is a free, independent open source project that publishes M3U playlists of publicly available channels from around the world. In IPTVMac choose M3U, give it a name and paste the link below.",
  free_note="IPTVMac is not affiliated with iptv-org. Whether a stream is available, and whether you may watch it, depends on the channel and on your country: use only what you are allowed to.",
  free_btn="Open iptv-org on GitHub",
  faq_h="Questions",
  faq=[
   ("What is IPTVMac?", "IPTVMac is a free, open source IPTV player for Mac. It plays Xtream Codes and M3U sources with a built-in mpv player, instant search, subtitles, Picture in Picture, catch-up, downloads and an interface in 31 languages."),
   ("Does IPTVMac include channels or a subscription?", "No. IPTVMac is only a player. It does not include or host any channels, movies or series. You add a source from a provider you are authorized to use. If you have none, the independent open source project iptv-org publishes free playlists of publicly available channels; see the link on this page."),
   ("Does it work with Xtream Codes and M3U?", "Yes. For Xtream Codes you enter the server address, username and password from your provider. For M3U you enter a name and the playlist link."),
   ("Which Macs are supported?", "Apple Silicon Macs (M1 or later) with macOS 14 or later. Intel Macs are not supported."),
   ("Is IPTVMac free?", "Yes. It is free and open source under the GPL-3.0 license, with no ads and no tracking."),
   ("Why does macOS block the app, and how do I open it?", "IPTVMac is not notarized by Apple, which requires a paid developer account. Install with the one-line command above, which avoids the warning, or open System Settings, Privacy and Security, and choose Open Anyway."),
   ("Does IPTVMac have Picture in Picture?", "Yes. A floating window stays on top of other apps and across Spaces while you browse for something else."),
   ("Can I watch past programs (catch-up)?", "Yes, on channels where your provider supports catch-up. Pick a program from the guide."),
   ("Is it safe to use?", "The source code is public. Updates come from GitHub Releases and are checked against a SHA-256 checksum. Account passwords are stored in the app's local database, readable only by your user."),
  ],
  guides_h="Guides",
  guides=[("guides/xtream-codes-on-mac.html", "How to watch Xtream Codes IPTV on a Mac", "What you need from your provider and how to set it up."),
          ("guides/m3u-playlist-on-mac.html", "How to play an M3U playlist on a Mac", "Add a playlist link and get Live, Movies and Series."),
          ("guides/picture-in-picture-iptv-mac.html", "Picture in Picture for IPTV on a Mac", "Keep a stream in a floating window while you do something else.")],
  alt_h="Other IPTV players for Mac",
  alt_p="IPTVMac is Mac only. If you need something different:",
  alt=["IPTVnator is free and open source and also runs on Windows and Linux.", "VLC can open an M3U playlist directly.", "IPTV Smarters Pro has a desktop app for macOS."],
  foot="IPTVMac is a media player. It does not include or host any content; use only sources you are authorized to access. IPTVMac is not affiliated with iptv-org.",
  lic="Open source under GPL-3.0.", other_lang=("he/", "עברית")),
 "he": dict(
  lang="he", prefix="he/", up="../",
  title="IPTVMac: נגן IPTV ל-Mac (Xtream Codes ו-M3U)",
  desc="IPTVMac הוא נגן IPTV חינמי בקוד פתוח ל-Mac. Xtream Codes ו-M3U, חיפוש מיידי, תמונה בתוך תמונה, צפייה בהיסטוריה, הורדות וכתוביות. Apple Silicon, macOS 14 ומעלה.",
  nav=[("#features", "יכולות"), ("#install", "התקנה"), ("#faq", "שאלות נפוצות"), ("#guides", "מדריכים"), (REPO, "GitHub"), ("../", "English")],
  h1="נגן IPTV ל-Mac, בנוי במקור",
  lede="מקורות Xtream Codes ו-M3U, חיפוש מיידי, תמונה בתוך תמונה, צפייה בהיסטוריה והורדות. חינם ובקוד פתוח.",
  dl="הורדה ל-Mac", src="קוד המקור ב-GitHub",
  meta=f"גרסה {VERSION}. Apple Silicon, macOS 14 ומעלה.",
  alt_movies="מסך הסרטים ב-IPTVMac עם רשת כרזות וסרגל קטגוריות",
  alt_player="הנגן של IPTVMac במסך מלא",
  demo_h="ראו איך זה עובד", demo_p="סיור של 80 שניות: ערוצים, חיפוש, מועדפים, הנגן, מהירות כפולה, תמונה בתוך תמונה והורדות. הערוצים והכרזות בדויים לצורך ההדגמה; הקטע המנוגן הוא הסרט Sintel של Blender Foundation.",
  feats_h="מה מקבלים",
  feats=[
   ("02-search", "חיפוש שעומד בקצב של 100,000 פריטים", "מקלידים ומחפשים בתוך קטגוריה, בתוך חלק או בכל מקום. התוצאות מופיעות תוך כדי הקלדה ומקובצות לערוצים, סרטים וסדרות.", "תוצאות חיפוש כללי ב-IPTVMac מקובצות לפי ערוצים, סרטים וסדרות"),
   ("05-player", "נגן שמתמודד עם סטרימים בעייתיים", "מבוסס על mpv. הוא מנגן סטרימים פגומים שנגני מערכת מוותרים עליהם, מתחבר מחדש כשהסטרים נופל, ומסתיר את הבקרים כדי שהתמונה תמלא את המסך.", "הנגן של IPTVMac במסך מלא"),
   ("06-pip", "ממשיכים לצפות ומחפשים הלאה", "חלון צף של תמונה בתוך תמונה נשאר מעל הכול, בכל שולחן עבודה. בוחרים ערוץ או סרט אחר, והסרט ממשיך לרוץ.", "חלון תמונה בתוך תמונה של IPTVMac צף מעל רשימת הסרטים"),
   ("07-downloads", "שומרים סרטים ועונות שלמות", "מורידים סרטים ופרקים, ובסדרות Xtream גם עונה שלמה, לתיקייה שבחרתם. מנגנים ממסך ההורדות.", "מסך ההורדות של IPTVMac"),
  ],
  small=[("כתוביות ואודיו", "רצועות מובנות, קבצי srt ו-ass בתפריט או בגרירה, גודל והזזה, שפות מועדפות."),
         ("צפייה בהיסטוריה ולוח שידורים", "צפייה בתוכניות מהעבר בערוצים שתומכים, ומה משודר עכשיו ואחר כך."),
         ("הפרק הבא", "כשפרק נגמר, הפרק הבא מתחיל אחרי ספירה של 5 שניות. אפשר לבטל."),
         ("מועדפים והמשך צפייה", "מסמנים ערוצים וסרטים בכוכב. סרטים ופרקים ממשיכים מהמקום שעצרתם."),
         ("כמה רשימות", "עוברים בין רשימות מסרגל הכלים, או מציגים את כולן יחד עם שם הרשימה על כל פריט."),
         ("מהירות, דילוג וטיימר שינה", "ניגון מ-0.25× עד 4×, בחירת צעד הדילוג, וטיימר שינה."),
         ("גיבוי והגדרות", "ייצוא של הרשימות (בלי סיסמאות), המועדפים וההיסטוריה; מראה בהיר או כהה; הסתרת קטגוריות לפי מילים."),
         ("31 שפות", "עברית, אנגלית, ערבית, ספרדית, צרפתית, גרמנית, רוסית, סינית, יפנית, הינדי ועוד, עם פריסה מימין לשמאל. בוחרים בהגדרות."),
         ("מתעדכן לבד", "בודק את GitHub Releases, מאמת SHA-256 ומתקין את הגרסה החדשה.")],
  install_h="התקנה בשורה אחת", install_p="מדביקים בטרמינל. השורה מורידה את הגרסה האחרונה, בודקת SHA-256, מעתיקה את IPTVMac ל-Applications ופותחת אותה.",
  copy="העתק", copied="הועתק", video="צפו בסרטון ההתקנה של 95 שניות ביוטיוב (באנגלית)",
  why="למה פקודה? IPTVMac לא עברה אימות (notarization) של Apple, שדורש חשבון מפתחים בתשלום, ו-macOS חוסמת אפליקציות שהדפדפן סימן כ״הורדו מהאינטרנט״. קובץ שמורידים עם curl לא מסומן, ולכן אין מה לעקוף. הסקריפט קצר וגלוי: install.sh.",
  dmg_h="או הורדת ה-DMG", dmg_steps=["פותחים את IPTVMac.dmg וגוררים את האפליקציה על אייקון Applications.", "ההפעלה הראשונה נחסמת: בהגדרות המערכת, פרטיות ואבטחה, לוחצים Open Anyway ליד IPTVMac.", "או מריצים בטרמינל xattr -dr com.apple.quarantine /Applications/IPTVMac.app"],
  free_h="אין לכם רשימה?",
  free_p="IPTVMac הוא נגן בלבד, ולכן צריך רשימת ערוצים. אם אין לכם ספק, iptv-org הוא פרויקט עצמאי בקוד פתוח וחינמי שמפרסם רשימות M3U של ערוצים זמינים לציבור מכל העולם. ב-IPTVMac בוחרים M3U, נותנים שם ומדביקים את הקישור שלמטה.",
  free_note="IPTVMac אינו קשור ל-iptv-org. אם סטרים זמין, ואם מותר לכם לצפות בו, תלוי בערוץ ובמדינה שלכם: השתמשו רק במה שמותר לכם.",
  free_btn="פתחו את iptv-org ב-GitHub",
  faq_h="שאלות נפוצות",
  faq=[
   ("מה זה IPTVMac?", "IPTVMac הוא נגן IPTV חינמי בקוד פתוח ל-Mac. הוא מנגן מקורות Xtream Codes ו-M3U עם נגן mpv מובנה, חיפוש מיידי, כתוביות, תמונה בתוך תמונה, צפייה בהיסטוריה, הורדות וממשק ב-31 שפות."),
   ("האם IPTVMac כולל ערוצים או מנוי?", "לא. IPTVMac הוא נגן בלבד. הוא לא כולל ולא מארח ערוצים, סרטים או סדרות. מוסיפים מקור מספק שמותר לכם להשתמש בו. אם אין לכם, הפרויקט העצמאי בקוד פתוח iptv-org מפרסם רשימות חינמיות של ערוצים זמינים לציבור; הקישור בעמוד."),
   ("האם זה עובד עם Xtream Codes ו-M3U?", "כן. ב-Xtream Codes מזינים כתובת שרת, שם משתמש וסיסמה מהספק. ב-M3U מזינים שם וקישור לרשימה."),
   ("אילו מחשבי Mac נתמכים?", "מחשבי Mac עם Apple Silicon (M1 ומעלה) ו-macOS 14 ומעלה. מחשבי Intel לא נתמכים."),
   ("האם IPTVMac חינמי?", "כן. הוא חינמי ובקוד פתוח ברישיון GPL-3.0, בלי פרסומות ובלי מעקב."),
   ("למה macOS חוסמת את האפליקציה, ואיך פותחים אותה?", "IPTVMac לא עברה אימות של Apple, שדורש חשבון מפתחים בתשלום. מתקינים בפקודה שלמעלה, שמונעת את האזהרה, או פותחים הגדרות מערכת, פרטיות ואבטחה, ובוחרים Open Anyway."),
   ("האם יש תמונה בתוך תמונה?", "כן. חלון צף נשאר מעל אפליקציות אחרות ובכל שולחן עבודה בזמן שמחפשים משהו אחר."),
   ("אפשר לצפות בתוכניות מהעבר?", "כן, בערוצים שהספק תומך בהם. בוחרים תוכנית מלוח השידורים."),
   ("האם זה בטוח?", "קוד המקור פומבי. העדכונים מגיעים מ-GitHub Releases ונבדקים מול SHA-256. סיסמאות החשבונות נשמרות במסד הנתונים המקומי של האפליקציה, נגיש רק למשתמש שלכם."),
  ],
  guides_h="מדריכים (באנגלית)",
  guides=[("../guides/xtream-codes-on-mac.html", "How to watch Xtream Codes IPTV on a Mac", "מה צריך מהספק ואיך מגדירים."),
          ("../guides/m3u-playlist-on-mac.html", "How to play an M3U playlist on a Mac", "מוסיפים קישור לרשימה ומקבלים ערוצים, סרטים וסדרות."),
          ("../guides/picture-in-picture-iptv-mac.html", "Picture in Picture for IPTV on a Mac", "משאירים סטרים בחלון צף ועושים משהו אחר.")],
  alt_h="נגני IPTV אחרים ל-Mac",
  alt_p="IPTVMac הוא ל-Mac בלבד. אם אתם צריכים משהו אחר:",
  alt=["IPTVnator חינמי ובקוד פתוח ופועל גם ב-Windows וב-Linux.", "VLC יכול לפתוח רשימת M3U ישירות.", "ל-IPTV Smarters Pro יש אפליקציית שולחן עבודה ל-macOS."],
  foot="IPTVMac הוא נגן. הוא לא כולל ולא מארח תוכן כלשהו; השתמשו רק במקורות שמותר לכם לגשת אליהם. IPTVMac אינו קשור ל-iptv-org.",
  lic="קוד פתוח ברישיון GPL-3.0.", other_lang=("../", "English")),
}

# Interface languages, each written in its own language (lang code, name, RTL flag). Same 31 as the app's picker.
LANGS = [("he", "עברית", 1), ("en", "English", 0), ("ar", "العربية", 1), ("es", "Español", 0), ("fr", "Français", 0), ("de", "Deutsch", 0),
         ("pt", "Português", 0), ("it", "Italiano", 0), ("ru", "Русский", 0), ("uk", "Українська", 0), ("pl", "Polski", 0), ("ro", "Română", 0),
         ("bg", "Български", 0), ("nl", "Nederlands", 0), ("sv", "Svenska", 0), ("cs", "Čeština", 0), ("hu", "Magyar", 0), ("el", "Ελληνικά", 0),
         ("sq", "Shqip", 0), ("tr", "Türkçe", 0), ("fa", "فارسی", 1), ("ur", "اردو", 1), ("hi", "हिन्दी", 0), ("bn", "বাংলা", 0),
         ("id", "Bahasa Indonesia", 0), ("vi", "Tiếng Việt", 0), ("th", "ไทย", 0), ("zh-Hans", "简体中文", 0), ("zh-Hant", "繁體中文", 0),
         ("ja", "日本語", 0), ("ko", "한국어", 0)]
assert len(LANGS) == 31

# Strings added or reworded in the redesign (merged over HOME below).
HOME_NEW = {
 "en": dict(
  skip="Skip to content", nav_aria="Main",
  h1="A native IPTV player for Mac.",
  lede="Xtream Codes and M3U sources, instant search, Picture in Picture, catch-up and downloads. Free and open source, with no account.",
  dl="Download the DMG",
  cmd_label_b="Install in one line.", cmd_label="Paste it in Terminal. macOS shows no warning, and the app updates itself afterwards.",
  stage_alt="IPTVMac movies screen with a poster grid and category sidebar", pip_alt="The Picture in Picture window floating over the movie list",
  why_h="Why IPTVMac",
  facts=[("Fast", "Your library lives in a local SQLite database with full-text search. Typing finds a channel among 100,000 items in well under a second."),
       ("Stable", "Playback runs on mpv, bundled in the app. It plays the broken TS and HLS streams that trip up system players, and reconnects when a stream drops."),
       ("Native", "SwiftUI, with no Electron and no web view. There is nothing else to install: the player is inside the app."),
       ("Open", "GPL-3.0, no accounts, no analytics. The app talks only to the servers you add, and to GitHub for updates.")],
  small=[("Subtitles and audio", "Embedded tracks, .srt and .ass files by menu or drag and drop, size and delay, preferred languages."),
         ("Catch-up and guide", "Watch past programs on channels that support it, and see what is on now and next."),
         ("Next episode", "When an episode ends, the next one starts after a 5 second countdown. You can cancel it."),
         ("Favorites and resume", "Star channels and movies. Movies and episodes continue where you stopped."),
         ("Several playlists", "Switch between playlists from the toolbar, or choose All playlists to search and browse them together, with the playlist name on each item."),
         ("Speed, skip and sleep timer", "Play from 0.25x to 4x, choose the skip step, and set a sleep timer."),
         ("Backup and settings", "Export playlists (without passwords), favorites and history; light or dark appearance; hide categories by words."),
         ("Updates itself", "Checks GitHub Releases, verifies the release signature and SHA-256 checksum, and installs the new version.")],
  langs_h="31 interface languages",
  langs_p="The app follows your Mac's language, or you pick one in Settings. Hebrew, Arabic, Persian and Urdu get a right-to-left layout.",
  langs_note="Apart from Hebrew, English and Arabic, the translations were written with AI help and no native speaker has reviewed them yet. Corrections are welcome.",
  langs_link="How to contribute a translation", langs_href=REPO + "#contributing-translations",
  guide_go="Read the guide",
  ),
 "he": dict(
  skip="דלג לתוכן", nav_aria="ראשי",
  h1="נגן IPTV מקורי ל-Mac.",
  lede="מקורות Xtream Codes ו-M3U, חיפוש מיידי, תמונה בתוך תמונה, צפייה בהיסטוריה והורדות. חינם ובקוד פתוח, בלי חשבון.",
  dl="הורדת ה-DMG",
  cmd_label_b="התקנה בשורה אחת.", cmd_label="מדביקים בטרמינל. macOS לא מציגה אזהרה, ואחר כך האפליקציה מתעדכנת לבד.",
  stage_alt="מסך הסרטים ב-IPTVMac עם רשת כרזות וסרגל קטגוריות", pip_alt="חלון תמונה בתוך תמונה צף מעל רשימת הסרטים",
  why_h="למה IPTVMac",
  facts=[("מהיר", "הספרייה שלכם נשמרת במסד SQLite מקומי עם חיפוש טקסט מלא. הקלדה מוצאת ערוץ מתוך 100,000 פריטים בפחות משנייה."),
       ("יציב", "הניגון רץ על mpv שמובנה באפליקציה. הוא מנגן סטרימים פגומים שנגני מערכת נתקעים בהם, ומתחבר מחדש כשהסטרים נופל."),
       ("מקורי", "SwiftUI, בלי Electron ובלי web view. אין מה להתקין בנוסף: הנגן נמצא בתוך האפליקציה."),
       ("פתוח", "GPL-3.0, בלי חשבונות ובלי אנליטיקס. האפליקציה פונה רק לשרתים שהוספתם, ול-GitHub לעדכונים.")],
  small=[("כתוביות ואודיו", "רצועות מובנות, קבצי srt ו-ass בתפריט או בגרירה, גודל והזזה, שפות מועדפות."),
         ("צפייה בהיסטוריה ולוח שידורים", "צפייה בתוכניות מהעבר בערוצים שתומכים, ומה משודר עכשיו ואחר כך."),
         ("הפרק הבא", "כשפרק נגמר, הפרק הבא מתחיל אחרי ספירה של 5 שניות. אפשר לבטל."),
         ("מועדפים והמשך צפייה", "מסמנים ערוצים וסרטים בכוכב. סרטים ופרקים ממשיכים מהמקום שעצרתם."),
         ("כמה רשימות", "עוברים בין רשימות מסרגל הכלים, או בוחרים All playlists כדי לחפש ולעיין בכולן יחד, עם שם הרשימה על כל פריט."),
         ("מהירות, דילוג וטיימר שינה", "ניגון מ-0.25× עד 4×, בחירת צעד הדילוג, וטיימר שינה."),
         ("גיבוי והגדרות", "ייצוא של הרשימות (בלי סיסמאות), המועדפים וההיסטוריה; מראה בהיר או כהה; הסתרת קטגוריות לפי מילים."),
         ("מתעדכן לבד", "בודק את GitHub Releases, מאמת את חתימת הגרסה ואת ה-SHA-256, ומתקין את הגרסה החדשה.")],
  langs_h="31 שפות ממשק",
  langs_p="האפליקציה פועלת בשפת ה-Mac שלכם, או שבוחרים שפה בהגדרות. עברית, ערבית, פרסית ואורדו מקבלות פריסה מימין לשמאל.",
  langs_note="מלבד עברית, אנגלית וערבית, התרגומים נכתבו בעזרת AI ועדיין לא נבדקו על ידי דובר שפת אם. תיקונים יתקבלו בברכה.",
  langs_link="איך לתרום תרגום (באנגלית)", langs_href=REPO + "#contributing-translations",
  guide_go="לקריאת המדריך",
  ),
}
for _k, _v in HOME_NEW.items():
    HOME[_k].update(_v)


def lang_wall():
    return '<ul class="wall">' + "".join(
        f'<li><span lang="{l}"{" dir=\"rtl\" class=\"rtl\"" if r else ""}>{e(n)}</span></li>' for l, n, r in LANGS) + '</ul>'

def home(code):
    c = HOME[code]; up = c["up"]; he = code == "he"
    canon = BASE + c["prefix"]
    alts = [("en", BASE), ("he", BASE + "he/"), ("x-default", BASE)]
    faq = c["faq"]
    ld = [software_ld(c["desc"], c["lang"]), faq_ld(faq), video_ld("IPTVMac demo", c["demo_p"])]
    out = head(c["title"], c["desc"], canon, c["lang"], 1 if he else 0, alts, extra_ld=ld)
    nav = "".join(
        (f'<a class="lang" href="{u}" hreflang="{"en" if he else "he"}" lang="{"en" if he else "he"}">{e(t)}</a>' if u == c["other_lang"][0] else
         f'<a{" class=keep" if u == "#install" else ""} href="{u}">{e(t)}</a>') for u, t in c["nav"])
    shot = (f'<picture><source type="image/webp" srcset="{up}screenshots/03-movies.webp 1200w, {up}screenshots/03-movies-1800.webp 1800w" sizes="(min-width: 1280px) 1240px, 100vw">'
            f'<img src="{up}screenshots/03-movies.jpg" width="1800" height="1130" alt="{e(c["stage_alt"])}" fetchpriority="high"></picture>')
    pip = (f'<picture class="pipwin"><source type="image/webp" srcset="{up}assets/pip-window.webp">'
           f'<img src="{up}assets/pip-window.jpg" width="588" height="330" alt="{e(c["pip_alt"])}" decoding="async"></picture>')
    out += f'''<a class="skip" href="#main">{e(c["skip"])}</a>
<div class="wrap"><header class="top"><a class="brand" href="./"><img src="{up}logo.png" width="34" height="34" alt="">IPTVMac</a><nav aria-label="{e(c["nav_aria"])}">{nav}</nav></header></div>
<main id="main">
<div class="hero"><div class="wrap">
 <div class="hero-grid">
  <h1>{e(c["h1"])}</h1>
  <div class="hero-side">
   <p class="lede">{e(c["lede"])}</p>
   <div class="actions"><a class="btn" href="{DOWNLOAD}">{ICON_DL}{e(c["dl"])}</a><a class="btn" href="{REPO}">{ICON_GH}{e(c["src"])}</a></div>
   <p class="meta">{e(c["meta"])}</p>
  </div>
 </div>
 <div class="cmd-wrap"><p class="cmd-label"><strong>{e(c["cmd_label_b"])}</strong> {e(c["cmd_label"])}</p>{cmd_block(c["copy"], c["copied"])}</div>
</div>
<div class="stage-top"><div class="window"><div class="frame">{shot}</div>{pip}</div></div></div>
<section class="stage" id="demo"><div class="wrap stage-body"><div class="stage-grid"><div><h2>{e(c["demo_h"])}</h2><p>{e(c["demo_p"])}</p></div>
<video controls preload="none" poster="{up}assets/demo-poster.webp" width="1280" height="720"><source src="{up}assets/demo.mp4" type="video/mp4"></video></div></div></section>
<section id="why"><div class="wrap"><h2>{e(c["why_h"])}</h2><div class="why-grid">{"".join(f"<div><h3>{e(h)}</h3><p>{e(p)}</p></div>" for h, p in c["facts"])}</div></div></section>
<section id="features" style="padding-top:0"><div class="wrap"><h2>{e(c["feats_h"])}</h2>
<div class="feats">
'''
    for i, (img, h, p, alt) in enumerate(c["feats"]):
        out += (f'<div class="feat"{" data-on" if i == 0 else ""}><div class="feat-text"><h3>{e(h)}</h3><p>{e(p)}</p></div>'
                f'<figure><div class="frame">{pic(up, img, alt, "loading=\"lazy\" decoding=\"async\"", "")}</div></figure></div>\n')
    out += '</div>\n<div class="small-feats">' + "".join(f'<div><h3>{e(h)}</h3><p>{e(p)}</p></div>' for h, p in c["small"]) + '</div>\n</div></section>\n'
    out += f'''<section class="langs" id="languages"><div class="wrap langs-grid"><div><h2>{e(c["langs_h"])}</h2><p>{e(c["langs_p"])}</p><p class="note">{e(c["langs_note"])} <a href="{c["langs_href"]}">{e(c["langs_link"])}</a></p></div>{lang_wall()}</div></section>
<section id="install"><div class="wrap install"><div class="install-main"><h2>{e(c["install_h"])}</h2><p class="lead">{e(c["install_p"])}</p>{cmd_block(c["copy"], c["copied"])}</div>
<div class="install-why"><p class="why">{e(c["why"])}</p><p class="why"><a class="yt" href="{YT_INSTALL}">{ICON_PLAY}{e(c["video"])}</a></p></div>
<div class="dmg"><h3>{e(c["dmg_h"])}</h3><ol class="steps">{"".join(f"<li>{s}</li>" for s in c["dmg_steps"])}</ol><p style="margin-top:24px"><a class="btn primary" href="{DOWNLOAD}">{ICON_DL}{e(c["dl"])}</a></p></div></div></section>
<section id="free"><div class="wrap qa-grid"><h2>{e(c["free_h"])}</h2><div><p class="lead">{e(c["free_p"])}</p><p><code dir="ltr">{FREE_M3U}</code></p><p class="why">{e(c["free_note"])}</p><p style="margin-top:20px"><a class="btn" href="{FREE_REPO}" rel="noopener">{e(c["free_btn"])}</a></p></div></div></section>
<section id="faq" style="padding-top:0"><div class="wrap qa-grid"><h2>{e(c["faq_h"])}</h2><div class="faq">{"".join(f"<details><summary>{e(q)}</summary><p>{e(a)}</p></details>" for q, a in faq)}</div></div></section>
<section id="guides" class="guides"><div class="wrap"><h2>{e(c["guides_h"])}</h2><div class="glist">{"".join(f'<a href="{u}"><strong>{e(t)}</strong><span>{e(s)}</span><span class="go">{e(c["guide_go"])}{ICON_CHEV}</span></a>' for u, t, s in c["guides"])}</div></div></section>
<section class="alt"><div class="wrap"><h2>{e(c["alt_h"])}</h2><p>{e(c["alt_p"])}</p><ul>{"".join(f"<li>{e(x)}</li>" for x in c["alt"])}</ul></div></section>
</main>
<footer><div class="wrap"><p>{e(c["foot"])}</p><p>{e(c["lic"])} <a href="{REPO}">GitHub</a> · <a href="{c["other_lang"][0]}">{e(c["other_lang"][1])}</a></p></div></footer>
<script src="{up}assets/site.js?v={ASSET_V}" defer></script>
</body></html>
'''
    path = DOCS / (c["prefix"] + "index.html"); path.parent.mkdir(parents=True, exist_ok=True); path.write_text(out)


# ---------- guides ----------
GUIDES = [
 dict(slug="xtream-codes-on-mac", title="How to watch Xtream Codes IPTV on a Mac | IPTVMac",
  h1="How to watch Xtream Codes IPTV on a Mac",
  desc="Step by step: what an Xtream Codes login contains, and how to add it to IPTVMac, a free native IPTV player for Mac, to get live TV, movies and series.",
  answer="Install IPTVMac, choose Xtream Codes, and enter the server address, username and password your provider gave you. IPTVMac downloads the channel list once and then searches it instantly.",
  body=f"""
<h2>What you need from your provider</h2>
<p>An Xtream Codes login has three parts: the server address (for example <code>http://example.com:8080</code>), a username and a password. Your provider shows them in your account or in the welcome message. IPTVMac does not provide any channels; it plays the source you add.</p>
<h2>Set it up in IPTVMac</h2>
<ol>
<li><a href="{DOWNLOAD}">Install IPTVMac</a> (Apple Silicon Mac, macOS 14 or later). The one-line install command is on the <a href="../">home page</a>.</li>
<li>On first launch the guide opens. Choose <strong>Xtream Codes</strong> and fill in a name, the server address, the username and the password.</li>
<li>Save. IPTVMac downloads the live channels, movies and series once, stores them locally and shows them under the Live, Movies and Series tabs.</li>
<li>Type in the search field to find a title. Choose <em>in category</em>, <em>in section</em> or <em>everywhere</em>.</li>
</ol>
<h2>If nothing plays</h2>
<ul>
<li><strong>Check the password.</strong> Open Settings and use Change password. Some providers answer wrong credentials with unusual HTTP codes instead of a clear message.</li>
<li><strong>Check the number of connections.</strong> Many accounts allow one connection at a time (<code>max_connections</code>). Close other players, and avoid watching while a download runs.</li>
<li><strong>Update the list.</strong> The refresh button in the toolbar downloads the lists again.</li>
</ul>
<h2>Good to know</h2>
<p>Catch-up (watching past programs) works on channels where your provider supports it. The password is stored in IPTVMac's local database, readable only by your user.</p>
""", faq=[("What is an Xtream Codes login?", "It is a server address, a username and a password that your IPTV provider gives you. A player uses them to download your channel, movie and series lists."),
          ("Does IPTVMac include Xtream Codes channels?", "No. IPTVMac is only a player. You add the login from a provider you are authorized to use.")]),
 dict(slug="m3u-playlist-on-mac", title="How to play an M3U playlist on a Mac | IPTVMac",
  h1="How to play an M3U playlist on a Mac",
  desc="How to open an M3U or M3U8 playlist link on a Mac with IPTVMac, a free native IPTV player: add the link, browse Live, Movies and Series, and search instantly.",
  answer="Install IPTVMac, choose M3U, and enter a name and the playlist link. IPTVMac reads the playlist and sorts it into Live, Movies and Series.",
  body=f"""
<h2>What you need</h2>
<p>The link (URL) of an M3U or M3U8 playlist from a source you are authorized to use. IPTVMac takes the link; opening a local .m3u file is not supported yet.</p>
<h2>No playlist yet?</h2>
<p>The independent open source project <a href="https://github.com/iptv-org/iptv" rel="noopener">iptv-org</a> publishes M3U playlists of publicly available channels from around the world, for example <code>https://iptv-org.github.io/iptv/index.m3u</code> (about 11,000 entries). IPTVMac is not affiliated with it, and whether a stream is available or allowed in your country depends on the channel: use only what you are allowed to.</p>
<h2>Add it in IPTVMac</h2>
<ol>
<li><a href="{DOWNLOAD}">Install IPTVMac</a> (Apple Silicon Mac, macOS 14 or later).</li>
<li>In the first-run guide, or in Settings, choose <strong>M3U</strong>. Enter a name and paste the playlist link.</li>
<li>Save. IPTVMac downloads the playlist and builds the lists. The <code>group-title</code> of each entry becomes its category and <code>tvg-logo</code> becomes its icon.</li>
</ol>
<h2>How entries are sorted</h2>
<p>An M3U file does not say whether an entry is a channel, a movie or a series, so IPTVMac decides: a URL containing <code>/movie/</code> or <code>/series/</code> is a movie or series, then the group name is checked, and files ending in .mp4, .mkv or .avi are treated as movies. Everything else is live. Catch-up and the program guide work only when the playlist carries that information.</p>
<h2>Tips</h2>
<ul>
<li>Search works inside a category, inside a section or everywhere, and finds titles as you type.</li>
<li>Star channels to keep them under Favorites.</li>
<li>VLC can also open an M3U playlist; IPTVMac adds the browsing, search, favorites, Picture in Picture and downloads on top.</li>
</ul>
""", faq=[("Can IPTVMac open a local .m3u file?", "Not yet. IPTVMac takes the playlist link (URL)."),
          ("How does IPTVMac decide what is a movie or a series?", "By the URL path (/movie/ or /series/), then by the group name, then by the file ending. Everything else is treated as live.")]),
 dict(slug="picture-in-picture-iptv-mac", title="Picture in Picture for IPTV on a Mac | IPTVMac",
  h1="Picture in Picture for IPTV on a Mac",
  desc="How to keep an IPTV stream in a floating window on a Mac while you browse or work, using the Picture in Picture button in IPTVMac.",
  answer="Start any channel or movie in IPTVMac and click the Picture in Picture button in the player. The video moves to a small floating window that stays on top of other apps and across Spaces.",
  body=f"""
<h2>Turn it on</h2>
<ol>
<li>Play a channel, movie or episode in <a href="{DOWNLOAD}">IPTVMac</a>.</li>
<li>Click the Picture in Picture button in the player controls.</li>
<li>The video moves to a floating window in the corner of your screen. The IPTVMac window goes back to the lists, so you can pick something else.</li>
</ol>
<h2>What the floating window does</h2>
<ul>
<li>It stays on top of other apps and on every Space, including over full screen apps.</li>
<li>Hover over it for pause, close and a button that returns the video to the main window.</li>
<li>You can drag it anywhere and resize it.</li>
</ul>
<h2>Also useful</h2>
<p>Choosing a tab, a category or the search field while a video is playing full screen sends the video to the floating window automatically. The IPTVMac window opens full screen by default when you start a video; you can change that in Settings.</p>
<h2>Note</h2>
<p>This is IPTVMac's own floating window, not the system Picture in Picture of Safari or QuickTime. It works with every source IPTVMac can play.</p>
""", faq=[("Does Picture in Picture work on live channels?", "Yes. It works for live channels, movies and episodes."),
          ("Is it the system Picture in Picture?", "No. It is IPTVMac's own always-on-top floating window, which also appears over full screen apps.")]),
]

def guide(g):
    canon = BASE + f"guides/{g['slug']}.html"
    ld = [{"@context": "https://schema.org", "@type": "Article", "headline": g["h1"], "description": g["desc"],
           "datePublished": UPDATED, "dateModified": UPDATED, "inLanguage": "en", "mainEntityOfPage": canon,
           "author": {"@type": "Person", "name": "Goelir", "url": "https://github.com/Goelir"},
           "publisher": {"@type": "Person", "name": "Goelir"}, "image": BASE + "social-preview.png"},
          faq_ld(g["faq"]), {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
              {"@type": "ListItem", "position": 1, "name": "IPTVMac", "item": BASE},
              {"@type": "ListItem", "position": 2, "name": g["h1"], "item": canon}]}]
    out = head(g["title"], g["desc"], canon, "en", 1, og_type="article", extra_ld=ld)
    related = "".join(f'<li><a href="{o["slug"]}.html">{e(o["h1"])}</a></li>' for o in GUIDES if o is not g)
    out += f'''<a class="skip" href="#main">Skip to content</a>
<div class="wrap"><header class="top"><a class="brand" href="../"><img src="../logo.png" width="34" height="34" alt="">IPTVMac</a><nav aria-label="Main"><a href="../#features">Features</a><a class="keep" href="../#install">Install</a><a href="../#faq">FAQ</a><a href="{REPO}">GitHub</a></nav></header></div>
<main id="main"><div class="wrap"><article class="guide">
<p class="crumbs"><a href="../">IPTVMac</a> / Guides</p>
<h1>{e(g["h1"])}</h1>
<p class="answer">{e(g["answer"])}</p>
{g["body"]}
<p style="margin-top:36px"><a class="btn primary" href="{DOWNLOAD}">{ICON_DL}Download IPTVMac for Mac</a></p>
<div class="related"><h2>More guides</h2><ul>{related}</ul></div>
<p class="fine">Updated {UPDATED}. IPTVMac is a media player; it does not include or host any content.</p>
</article></div></main>
<footer><div class="wrap"><p>Open source under GPL-3.0. <a href="{REPO}">GitHub</a> · <a href="../">Home</a></p></div></footer>
</body></html>
'''
    (DOCS / "guides" / f"{g['slug']}.html").write_text(out)

# ---------- crawler files ----------
def crawler_files():
    urls = [BASE, BASE + "he/"] + [BASE + f"guides/{g['slug']}.html" for g in GUIDES]
    sm = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
    for u in urls:
        sm += f"<url><loc>{u}</loc><lastmod>{UPDATED}</lastmod>"
        if u in (BASE, BASE + "he/"):
            sm += f'<xhtml:link rel="alternate" hreflang="en" href="{BASE}"/><xhtml:link rel="alternate" hreflang="he" href="{BASE}he/"/>'
        sm += "</url>\n"
    (DOCS / "sitemap.xml").write_text(sm + "</urlset>\n")
    (DOCS / "robots.txt").write_text(f"""# Everyone is welcome, including search and AI crawlers: the goal is to be found.
User-agent: *
Allow: /
Disallow: /superpowers/

Sitemap: {BASE}sitemap.xml
""")
    (DOCS / ".nojekyll").write_text("")
    d = HOME["en"]
    facts = f"""# IPTVMac

> IPTVMac is a free, open source IPTV player for Mac. It plays Xtream Codes and M3U sources with a built-in mpv player, instant search, subtitles, Picture in Picture, catch-up, downloads and an interface in 31 languages. Apple Silicon, macOS 14 or later. GPL-3.0. It is a player only and includes no channels or content.

Latest version: {VERSION}. Download: {DOWNLOAD}
Install in Terminal: `{INSTALL_CMD}`
Install video (95 seconds, English): {YT_INSTALL}
Source code: {REPO}

## Guides
""" + "".join(f"- [{g['h1']}]({BASE}guides/{g['slug']}.html): {g['answer']}\n" for g in GUIDES) + f"""
## Facts
- Requirements: Apple Silicon Mac (M1 or later), macOS 14 or later. Intel Macs are not supported.
- Free playlists: the independent project iptv-org (github.com/iptv-org/iptv) publishes M3U playlists of publicly available channels, e.g. https://iptv-org.github.io/iptv/index.m3u ; IPTVMac is not affiliated with it.
- Sources: Xtream Codes (server address, username, password) and M3U (playlist link). A local .m3u file is not supported yet.
- Player: mpv (libmpv, bundled). Hardware decoding, automatic reconnect, embedded and external subtitles, playback speed from 0.25x to 4x for movies and episodes, configurable skip step, fit/fill/stretch, sleep timer.
- Several playlists: switch between them or show all playlists together (search, favorites and continue watching across all).
- Settings: light/dark appearance, interface language, automatic playlist refresh, hiding categories by words, backup and restore (playlists without passwords, favorites, history).
- Search: local SQLite full-text search, inside a category, inside a section or everywhere.
- Picture in Picture: IPTVMac's own always-on-top floating window, across Spaces.
- Catch-up and program guide on channels whose provider supports them (Xtream).
- Downloads of movies and episodes (whole seasons on Xtream series) to a folder the user chooses.
- Next episode starts automatically after a 5 second countdown (can be turned off).
- Free, no ads, no tracking. Passwords are stored in the app's local database, readable only by the user.
- Not notarized by Apple (no paid developer account): install with the Terminal command above, or choose Open Anyway in System Settings, Privacy and Security.

## FAQ
""" + "".join(f"- {q} {a}\n" for q, a in d["faq"]) + """
## Not to be confused with
IPTVMac is not an IPTV provider and does not sell subscriptions or channels.
"""
    (DOCS / "llms.txt").write_text(facts)
    # the social preview is referenced by og:image at the site root
    sp = DOCS / "social-preview.png"
    assert sp.exists(), "docs/social-preview.png is missing"

if __name__ == "__main__":
    publish_assets()
    home("en"); home("he")
    for g in GUIDES: guide(g)
    crawler_files()
    print("site built:", ", ".join(sorted(p.name for p in DOCS.rglob("*.html"))))
