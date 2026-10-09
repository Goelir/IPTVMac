#!/usr/bin/env python3
"""Generates the static website in docs/ (home EN + HE, three guides, robots.txt, sitemap.xml, llms.txt).
Run: python3 scripts/site/build.py   (no dependencies). Edit the content below, not the generated HTML.

Layout of scripts/site/:
  build.py, site.css, site.js   this generator and the page's own style and script
  poster/, make-posters.mjs     source and renderer of the hero poster (AVIF/WebP/JPEG in docs/assets)
  demo/demo.js, demo/demo.css   optional interactive mock of the app (window.IPTVDemo), copied to docs/assets when present
  fx/fx.js, fx/fx.css           optional motion layer (window.IPTVFX), copied to docs/assets when present
The page is complete without the optional modules: every chapter has a static composition, the modules only replace it."""
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

# ---------- assets ----------
SRC = pathlib.Path(__file__).resolve().parent
OWN = ("site.css", "site.js")
MODULES = {"demo": ("demo.js", "demo.css"), "fx": ("fx.js", "fx.css")}   # scripts/site/<name>/<file> -> docs/assets/<file>
VER = {}        # asset file name -> short content hash, for cache busting
HAS = {}        # module name -> {"js": url, "css": url or None}; only modules whose file exists are wired into the pages
def _copy(src, name):
    shutil.copyfile(src, DOCS / "assets" / name)
    VER[name] = hashlib.sha1(src.read_bytes()).hexdigest()[:8]
def publish_assets():
    (DOCS / "assets").mkdir(exist_ok=True)
    for n in OWN: _copy(SRC / n, n)
    for mod, (js, css) in MODULES.items():
        if (SRC / mod / js).exists():
            _copy(SRC / mod / js, js)
            if (SRC / mod / css).exists(): _copy(SRC / mod / css, css)
            HAS[mod] = {"js": f"assets/{js}?v={VER[js]}", "css": f"assets/{css}?v={VER[css]}" if css in VER else None}
def av(up, name): return f"{up}assets/{name}?v={VER[name]}"

# ---------- icons (one stroke family: 1.7, round) ----------
def svg(path, vb="0 0 20 20", cls="", fill="none"):
    return f'<svg{f" class={chr(34)}{cls}{chr(34)}" if cls else ""} viewBox="{vb}" fill="{fill}" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{path}</svg>'
ICON_COPY = svg('<rect x="7" y="7" width="9.5" height="9.5" rx="2.2"/><path d="M13 7V5.4A2.2 2.2 0 0 0 10.8 3.2H5.4A2.2 2.2 0 0 0 3.2 5.4v5.4A2.2 2.2 0 0 0 5.4 13H7"/>', cls="cp")
ICON_OK = svg('<path d="M4 10.5l4 4 8-9"/>', cls="ok")
ICON_CHEV = svg('<path d="M7.5 4l6 6-6 6"/>', cls="chev")
ICON_DL = svg('<path d="M10 3v10m0 0L6 9m4 4l4-4M4 16.5h12"/>')
ICON_GH = '<svg viewBox="0 0 18 18" fill="currentColor" aria-hidden="true"><path d="M9 1.2a7.8 7.8 0 0 0-2.47 15.2c.39.07.53-.17.53-.37v-1.4c-2.17.47-2.63-1.04-2.63-1.04-.35-.9-.87-1.14-.87-1.14-.71-.49.05-.48.05-.48.78.06 1.2.81 1.2.81.7 1.2 1.83.85 2.28.65.07-.51.27-.85.5-1.05-1.73-.2-3.55-.87-3.55-3.86 0-.85.3-1.55.8-2.1-.08-.2-.35-1 .08-2.07 0 0 .65-.21 2.14.8a7.4 7.4 0 0 1 3.9 0c1.49-1.01 2.14-.8 2.14-.8.43 1.07.16 1.87.08 2.07.5.55.8 1.25.8 2.1 0 3-1.82 3.66-3.56 3.85.28.24.53.72.53 1.45v2.15c0 .2.14.45.54.37A7.8 7.8 0 0 0 9 1.2z"/></svg>'
ICON_PLAY = '<svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M7 4.6v10.8a.6.6 0 0 0 .9.5l8.6-5.4a.6.6 0 0 0 0-1L7.9 4.1a.6.6 0 0 0-.9.5z"/></svg>'
ICON_PAUSE = '<svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><rect x="5" y="4" width="3.6" height="12" rx="1.2"/><rect x="11.4" y="4" width="3.6" height="12" rx="1.2"/></svg>'
ICON_SEARCH = svg('<circle cx="9" cy="9" r="5.5"/><path d="M13.2 13.2L17 17"/>')
ICON_MOON = svg('<path d="M16.5 11.6A6.8 6.8 0 0 1 8.4 3.5a6.8 6.8 0 1 0 8.1 8.1z"/>')
ICON_MOON_T = svg('<path d="M16.5 11.6A6.8 6.8 0 0 1 8.4 3.5a6.8 6.8 0 1 0 8.1 8.1z"/>', cls="moon")
ICON_SUN = svg('<circle cx="10" cy="10" r="3.4"/><path d="M10 2.2v1.6M10 16.2v1.6M2.2 10h1.6M16.2 10h1.6M4.5 4.5l1.1 1.1M14.4 14.4l1.1 1.1M15.5 4.5l-1.1 1.1M5.6 14.4l-1.1 1.1"/>', cls="sun")
ICON_PIP = svg('<rect x="2.5" y="4" width="15" height="12" rx="2.2"/><rect x="9.5" y="9.5" width="6" height="4.2" rx="1" fill="currentColor" stroke="none"/>')
ICON_FS = svg('<path d="M3.5 7.5v-4h4M16.5 7.5v-4h-4M3.5 12.5v4h4M16.5 12.5v4h-4"/>')
ICON_BACK = svg('<path d="M4.2 10a5.8 5.8 0 1 0 1.8-4.2M4 3.2v3.6h3.6"/>')
ICON_FWD = svg('<path d="M15.8 10a5.8 5.8 0 1 1-1.8-4.2M16 3.2v3.6h-3.6"/>')
ICON_X = svg('<path d="M5 5l10 10M15 5L5 15"/>')
ICON_CHECK = svg('<path d="M4 10.5l4 4 8-9"/>')

# ---------- shared pieces ----------
def head(title, desc, canonical, lang, depth, alternates=(), og_type="website", extra_ld=(), preload=""):
    up = "../" * depth
    alts = "".join(f'<link rel="alternate" hreflang="{l}" href="{u}">' for l, u in alternates)
    ld = "".join(f'<script type="application/ld+json">{json.dumps(o, ensure_ascii=False)}</script>' for o in extra_ld)
    fonts = "".join(f'<link rel="preload" href="{up}assets/fonts/{f}.woff2" as="font" type="font/woff2" crossorigin>'
                    for f in ["instrument-latin", "jetbrainsmono-latin"] + (["heebo-hebrew"] if lang == "he" else []))
    return f'''<!doctype html>
<html lang="{lang}" dir="{'rtl' if lang == 'he' else 'ltr'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(title)}</title>
<meta name="description" content="{e(desc)}">
<link rel="canonical" href="{canonical}">
{alts}
<meta name="color-scheme" content="dark light">
<meta name="theme-color" content="#f6f5fb" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0a0912" media="(prefers-color-scheme: dark)">
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
{fonts}{preload}
<link rel="stylesheet" href="{av(up, 'site.css')}">
<script>document.documentElement.classList.add("js");try{{var t=localStorage.getItem("iptvmac-theme");if(t==="light"||t==="dark")document.documentElement.dataset.theme=t}}catch(e){{}}</script>
{ld}
</head>
<body>
'''

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

# Interface languages, each written in its own language (lang code, name, RTL flag). Same 31 as the app's picker.
LANGS = [("he", "עברית", 1), ("en", "English", 0), ("ar", "العربية", 1), ("es", "Español", 0), ("fr", "Français", 0), ("de", "Deutsch", 0),
         ("pt", "Português", 0), ("it", "Italiano", 0), ("ru", "Русский", 0), ("uk", "Українська", 0), ("pl", "Polski", 0), ("ro", "Română", 0),
         ("bg", "Български", 0), ("nl", "Nederlands", 0), ("sv", "Svenska", 0), ("cs", "Čeština", 0), ("hu", "Magyar", 0), ("el", "Ελληνικά", 0),
         ("sq", "Shqip", 0), ("tr", "Türkçe", 0), ("fa", "فارسی", 1), ("ur", "اردو", 1), ("hi", "हिन्दी", 0), ("bn", "বাংলা", 0),
         ("id", "Bahasa Indonesia", 0), ("vi", "Tiếng Việt", 0), ("th", "ไทย", 0), ("zh-Hans", "简体中文", 0), ("zh-Hant", "繁體中文", 0),
         ("ja", "日本語", 0), ("ko", "한국어", 0)]
assert len(LANGS) == 31
# The word "native" in each interface language: the headline cycles through them when the fx module is present.
NATIVE = {"he": "מקורי", "en": "native", "ar": "أصلي", "es": "nativo", "fr": "natif", "de": "nativ", "pt": "nativo", "it": "nativo", "ru": "нативный",
          "uk": "нативний", "pl": "natywny", "ro": "nativ", "bg": "нативен", "nl": "native", "sv": "nativ", "cs": "nativní", "hu": "natív", "el": "εγγενής",
          "sq": "nativ", "tr": "yerel", "fa": "بومی", "ur": "مقامی", "hi": "नेटिव", "bn": "নেটিভ", "id": "asli", "vi": "gốc", "th": "เนทีฟ",
          "zh-Hans": "原生", "zh-Hant": "原生", "ja": "ネイティブ", "ko": "네이티브"}
def native_words(first):
    out = [NATIVE[first]]
    for l, _, _ in LANGS:
        if NATIVE[l] not in out: out.append(NATIVE[l])
    return out

# Real UI strings from the app, for the right-to-left comparison (read from the app's own translation files).
def app_strings(code):
    t = (ROOT / "Sources/IPTVMac/Resources" / f"{code}.lproj/Localizable.strings").read_text()
    g = lambda k: re.search(r'^"%s"\s*=\s*"(.*)";' % re.escape(k), t, re.M).group(1)
    return {k: g(f"tab.{k}") for k in ("live", "movies", "series")} | {"search": g("search.prompt")}

# ---------- copy ----------
# SEO fields (title, desc, faq, guides) are carried over unchanged from the previous site.
HOME = {
 "en": dict(
  lang="en", prefix="", up="",
  title="IPTVMac: IPTV Player for Mac (Xtream Codes and M3U)",
  desc="IPTVMac is a free, open source IPTV player for Mac. Xtream Codes and M3U, instant search, Picture in Picture, catch-up, downloads and subtitles. Apple Silicon, macOS 14+.",
  skip="Skip to content", nav_aria="Main", home_aria="IPTVMac home",
  nav=[("#search", "Search"), ("#player", "Player"), ("#pip", "Picture in Picture"), ("#languages", "Languages"), ("#install", "Install"), ("#faq", "FAQ")],
  gh="GitHub", theme="Switch between light and dark", other_lang=("he/", "עברית", "he"),
  h1='<span class="l">A {m}</span> <span class="l">IPTV player</span> <span class="l">for Mac.</span>',
  lede="Xtream Codes and M3U sources, instant search, Picture in Picture, catch-up and downloads. Free and open source, with no account.",
  cmd_b="Install in one line.", cmd_t="Paste it in Terminal. macOS shows no warning, and the app updates itself afterwards.",
  copy="Copy", copied="Copied", copy_aria="Copy the install command",
  dl="Download the DMG", src="View the source", tour="Watch the 80-second tour",
  meta=f"Version {VERSION}. Apple Silicon, macOS 14 or later. GPL-3.0.",
  cue="Scroll to see it work", rail_aria="Chapters",
  hero_alt="The IPTVMac window showing a wall of movie posters, with a small Picture in Picture window floating in front of it",
  # chapters
  search_h="Search that keeps up with 100,000 items.",
  search_p="Your library lives in a local SQLite database with full-text search, so results appear as you type. Search inside a category, inside a section or everywhere. Results come back grouped into live channels, movies and series.",
  search_f=["Hebrew, Arabic and Latin text.", "Search runs on your Mac, in a local database."],
  search_count="items in our test library, searched in well under a second",
  search_alt="IPTVMac search results for the letters na, grouped into live channels, movies and series",
  loupe_n="4",
  player_h="Every speed from 0.25x to 4x.",
  player_p="Playback runs on mpv. It plays the broken TS and HLS streams that trip up system players and reconnects when a stream drops. Speed works on movies, episodes and catch-up; a live stream cannot run faster than real time.",
  player_f=["Sleep timer from 15 minutes to 2 hours.", "Skip step from 5 to 60 seconds.", "Fit, fill or stretch the picture."],
  player_alt="The IPTVMac player in full screen: a character in a snowstorm, with the controls fading in at the bottom",
  dial="Playback speed", keys=[("[", "slower"), ("]", "faster"), ("2", "double speed"), ("A", "fit, fill, stretch")],
  pip_h="Keep watching while you browse.",
  pip_p="Picture in Picture is IPTVMac's own floating window. It stays on top of other apps and follows you across Spaces, including over full screen apps. Pick another channel or movie in the main window and the video keeps playing.",
  pip_f=["Works on live channels, movies and episodes.", "Drag it anywhere and resize it.", "Hover for pause, close and a button back to the main window."],
  pip_hint="Drag the floating window to move it.", pip_label="Picture in Picture window. Drag it, or use the arrow keys.",
  pip_alt="The IPTVMac movie list with the Picture in Picture window floating over it",
  pip_win_alt="A small floating window playing a film scene, with pause in the middle",
  pl_h="Several playlists, one library.",
  pl_p="Add as many Xtream Codes and M3U sources as you like and switch between them from the toolbar. Choose All playlists to search, favorite and continue watching across every one, with the playlist name on each item.",
  pl_f=["Xtream Codes: server address, username and password.", "M3U: a name and the playlist link."],
  pl_alt="IPTVMac poster wall with the name of the playlist shown on each item",
  pl_all="All playlists", pl_names=[("Cinema Club", "Xtream Codes", "#a496ff"), ("Weekend Box", "M3U", "#ffb347"), ("Kids Corner", "M3U", "#3dd6c0")],
  langs_h="31 languages, each in its own script.",
  langs_p="IPTVMac follows your Mac's language, or you pick one in Settings. Hebrew, Arabic, Persian and Urdu get a layout that mirrors the whole interface.",
  langs_note="Apart from Hebrew, English and Arabic, the translations were written with AI help and no native speaker has reviewed them yet. Corrections are welcome.",
  langs_link="How to contribute a translation", langs_href=REPO + "#contributing-translations",
  trio_h="The same toolbar in three languages, as the app draws it:",
  install_h="Install in one line.",
  install_p="Paste it in Terminal. The script downloads the latest release, checks its signature and SHA-256, copies IPTVMac to Applications and opens it. After that the app updates itself.",
  reqs="Needs an Apple Silicon Mac (M1 or later) and macOS 14 or later.",
  term="Terminal", opens="IPTVMac opens", opens_s="First launch shows a three-step guide.",
  why_h="Why a command?",
  why="IPTVMac is not notarized by Apple, which needs a paid developer account, and macOS blocks apps that a browser marked as downloaded from the internet. A file fetched with curl is not marked, so there is nothing to bypass. The script is short and public: install.sh.",
  video="Watch the 95-second install video on YouTube",
  dmg_h="Or download the DMG",
  dmg_steps=["Open IPTVMac.dmg and drag the app onto the Applications icon.", "The first launch is blocked: open System Settings, Privacy &amp; Security, and choose Open Anyway next to IPTVMac.", "Or run <code>xattr -dr com.apple.quarantine /Applications/IPTVMac.app</code> in Terminal."],
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
  guides_h="Guides", guide_go="Read the guide",
  guides=[("guides/xtream-codes-on-mac.html", "How to watch Xtream Codes IPTV on a Mac", "What you need from your provider and how to set it up."),
          ("guides/m3u-playlist-on-mac.html", "How to play an M3U playlist on a Mac", "Add a playlist link and get Live, Movies and Series."),
          ("guides/picture-in-picture-iptv-mac.html", "Picture in Picture for IPTV on a Mac", "Keep a stream in a floating window while you do something else.")],
  cta_l=["Free.", "Open source."], cta_p="GPL-3.0. No account, no ads, no tracking.", cta_dl="Download for Mac", cta_src="Source on GitHub",
  foot="IPTVMac is a media player. It does not include or host any content; use only sources you are authorized to access. IPTVMac is not affiliated with iptv-org.",
  foot_about="A free, open source IPTV player for Mac.",
  foot_cols=[("Explore", [("#search", "Search"), ("#player", "Player"), ("#pip", "Picture in Picture"), ("#playlists", "Playlists"), ("#languages", "Languages"), ("#install", "Install")]),
             ("Learn", [("#faq", "Questions"), ("#free", "Free playlists")]),
             ("Project", [(REPO, "GitHub"), (DOWNLOAD, "Releases"), ("https://www.gnu.org/licenses/gpl-3.0.html", "GPL-3.0 license"), (REPO + "#contributing-translations", "Translate IPTVMac")])],
  alt_h="Other IPTV players for Mac.", alt_p="IPTVMac is Mac only. If you need something different:",
  alt=["IPTVnator is free and open source and also runs on Windows and Linux.", "VLC can open an M3U playlist directly.", "IPTV Smarters Pro has a desktop app for macOS."],
  credit='Demo footage: "Sintel" by the Blender Foundation, <a href="https://durian.blender.org" rel="noopener">CC BY 3.0</a>. All titles and channels on this page are invented.',
  tour_close="Close the video", tour_note='80 seconds: live channels, search, favorites, the player, 2x speed, Picture in Picture and downloads. The channels and posters are invented for the demo; the footage is the Blender Foundation film "Sintel" (CC BY 3.0).',
  lic="Open source under GPL-3.0."),
 "he": dict(
  lang="he", prefix="he/", up="../",
  title="IPTVMac: נגן IPTV ל-Mac (Xtream Codes ו-M3U)",
  desc="IPTVMac הוא נגן IPTV חינמי בקוד פתוח ל-Mac. Xtream Codes ו-M3U, חיפוש מיידי, תמונה בתוך תמונה, צפייה בהיסטוריה, הורדות וכתוביות. Apple Silicon, macOS 14 ומעלה.",
  skip="דלג לתוכן", nav_aria="ראשי", home_aria="IPTVMac, דף הבית",
  nav=[("#search", "חיפוש"), ("#player", "נגן"), ("#pip", "תמונה בתוך תמונה"), ("#languages", "שפות"), ("#install", "התקנה"), ("#faq", "שאלות")],
  gh="GitHub", theme="מעבר בין מראה בהיר לכהה", other_lang=("../", "English", "en"),
  h1='<span class="l">נגן IPTV</span> <span class="l">{m}</span> <span class="l">ל-Mac.</span>',
  lede="מקורות Xtream Codes ו-M3U, חיפוש מיידי, תמונה בתוך תמונה, צפייה בהיסטוריה והורדות. חינם ובקוד פתוח, בלי חשבון.",
  cmd_b="התקנה בשורה אחת.", cmd_t="מדביקים בטרמינל. macOS לא מציגה אזהרה, ואחר כך האפליקציה מתעדכנת לבד.",
  copy="העתק", copied="הועתק", copy_aria="העתקת פקודת ההתקנה",
  dl="הורדת ה-DMG", src="קוד המקור", tour="לצפות בסיור של 80 שניות",
  meta=f"גרסה {VERSION}. Apple Silicon, macOS 14 ומעלה. GPL-3.0.",
  cue="גוללים כדי לראות איך זה עובד", rail_aria="פרקים",
  hero_alt="חלון IPTVMac עם קיר כרזות של סרטים, ולפניו חלון קטן של תמונה בתוך תמונה",
  search_h="חיפוש שעומד בקצב של 100,000 פריטים.",
  search_p="הספרייה שלכם נשמרת במסד SQLite מקומי עם חיפוש טקסט מלא, ולכן התוצאות מופיעות תוך כדי הקלדה. מחפשים בתוך קטגוריה, בתוך חלק או בכל מקום. התוצאות חוזרות מקובצות לערוצים, סרטים וסדרות.",
  search_f=["עברית, ערבית ולטינית.", "החיפוש רץ על ה-Mac שלכם, במסד נתונים מקומי."],
  search_count="פריטים בספריית הבדיקה, והחיפוש לוקח פחות משנייה",
  search_alt="תוצאות חיפוש ב-IPTVMac עבור האותיות na, מקובצות לערוצים, סרטים וסדרות",
  loupe_n="4",
  player_h="כל מהירות מ-0.25× עד 4×.",
  player_p="הניגון רץ על mpv. הוא מנגן סטרימים פגומים מסוג TS ו-HLS שנגני מערכת נתקעים בהם, ומתחבר מחדש כשהסטרים נופל. המהירות פועלת בסרטים, בפרקים ובצפייה בהיסטוריה; שידור חי לא יכול לרוץ מהר מזמן אמת.",
  player_f=["טיימר שינה מ-15 דקות עד שעתיים.", "צעד דילוג מ-5 עד 60 שניות.", "התאמה, מילוי או מתיחה של התמונה."],
  player_alt="הנגן של IPTVMac במסך מלא: דמות בסופת שלגים, והבקרים מופיעים בתחתית",
  dial="מהירות ניגון", keys=[("[", "איטי יותר"), ("]", "מהיר יותר"), ("2", "מהירות כפולה"), ("A", "התאמה, מילוי, מתיחה")],
  pip_h="ממשיכים לצפות ומחפשים הלאה.",
  pip_p="תמונה בתוך תמונה היא חלון צף של IPTVMac עצמה. הוא נשאר מעל אפליקציות אחרות ומלווה אתכם בין שולחנות עבודה, גם מעל אפליקציות במסך מלא. בוחרים ערוץ או סרט אחר בחלון הראשי, והסרט ממשיך לרוץ.",
  pip_f=["עובד בערוצים, בסרטים ובפרקים.", "אפשר לגרור לכל מקום ולשנות גודל.", "מעבירים עכבר לקבלת השהיה, סגירה וחזרה לחלון הראשי."],
  pip_hint="גוררים את החלון הצף כדי להזיז אותו.", pip_label="חלון תמונה בתוך תמונה. גוררים אותו, או משתמשים בחצים.",
  pip_alt="רשימת הסרטים ב-IPTVMac, ומעליה חלון תמונה בתוך תמונה צף",
  pip_win_alt="חלון צף קטן שמנגן סצנה מסרט, עם כפתור השהיה באמצע",
  pl_h="כמה רשימות, ספרייה אחת.",
  pl_p="מוסיפים כמה מקורות Xtream Codes ו-M3U שרוצים ועוברים ביניהם מסרגל הכלים. בוחרים All playlists כדי לחפש, לסמן מועדפים ולהמשיך לצפות בכולם יחד, עם שם הרשימה על כל פריט.",
  pl_f=["Xtream Codes: כתובת שרת, שם משתמש וסיסמה.", "M3U: שם וקישור לרשימה."],
  pl_alt="קיר כרזות ב-IPTVMac, עם שם הרשימה על כל פריט",
  pl_all="All playlists", pl_names=[("Cinema Club", "Xtream Codes", "#a496ff"), ("Weekend Box", "M3U", "#ffb347"), ("Kids Corner", "M3U", "#3dd6c0")],
  langs_h="31 שפות, כל אחת בכתב שלה.",
  langs_p="האפליקציה פועלת בשפת ה-Mac שלכם, או שבוחרים שפה בהגדרות. עברית, ערבית, פרסית ואורדו מקבלות פריסה שמשקפת את כל הממשק.",
  langs_note="מלבד עברית, אנגלית וערבית, התרגומים נכתבו בעזרת AI ועדיין לא נבדקו על ידי דובר שפת אם. תיקונים יתקבלו בברכה.",
  langs_link="איך לתרום תרגום (באנגלית)", langs_href=REPO + "#contributing-translations",
  trio_h="אותו סרגל כלים בשלוש שפות, כפי שהאפליקציה מציירת אותו:",
  install_h="התקנה בשורה אחת.",
  install_p="מדביקים בטרמינל. הסקריפט מוריד את הגרסה האחרונה, בודק חתימה ו-SHA-256, מעתיק את IPTVMac ל-Applications ופותח אותה. מאותו רגע האפליקציה מתעדכנת לבד.",
  reqs="נדרש Mac עם Apple Silicon (M1 ומעלה) ו-macOS 14 ומעלה.",
  term="Terminal", opens="IPTVMac נפתחת", opens_s="בהפעלה הראשונה מוצג מדריך של שלושה שלבים.",
  why_h="למה פקודה?",
  why="IPTVMac לא עברה אימות (notarization) של Apple, שדורש חשבון מפתחים בתשלום, ו-macOS חוסמת אפליקציות שהדפדפן סימן כ״הורדו מהאינטרנט״. קובץ שמורידים עם curl לא מסומן, ולכן אין מה לעקוף. הסקריפט קצר וגלוי: install.sh.",
  video="צפו בסרטון ההתקנה של 95 שניות ביוטיוב (באנגלית)",
  dmg_h="או הורדת ה-DMG",
  dmg_steps=["פותחים את IPTVMac.dmg וגוררים את האפליקציה על אייקון Applications.", "ההפעלה הראשונה נחסמת: בהגדרות המערכת, פרטיות ואבטחה, לוחצים Open Anyway ליד IPTVMac.", "או מריצים בטרמינל <code>xattr -dr com.apple.quarantine /Applications/IPTVMac.app</code>"],
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
  guides_h="מדריכים (באנגלית)", guide_go="לקריאת המדריך",
  guides=[("../guides/xtream-codes-on-mac.html", "How to watch Xtream Codes IPTV on a Mac", "מה צריך מהספק ואיך מגדירים."),
          ("../guides/m3u-playlist-on-mac.html", "How to play an M3U playlist on a Mac", "מוסיפים קישור לרשימה ומקבלים ערוצים, סרטים וסדרות."),
          ("../guides/picture-in-picture-iptv-mac.html", "Picture in Picture for IPTV on a Mac", "משאירים סטרים בחלון צף ועושים משהו אחר.")],
  cta_l=["חינם.", "קוד פתוח."], cta_p="GPL-3.0. בלי חשבון, בלי פרסומות ובלי מעקב.", cta_dl="הורדה ל-Mac", cta_src="קוד המקור ב-GitHub",
  foot="IPTVMac הוא נגן. הוא לא כולל ולא מארח תוכן כלשהו; השתמשו רק במקורות שמותר לכם לגשת אליהם. IPTVMac אינו קשור ל-iptv-org.",
  foot_about="נגן IPTV חינמי ובקוד פתוח ל-Mac.",
  foot_cols=[("בעמוד", [("#search", "חיפוש"), ("#player", "נגן"), ("#pip", "תמונה בתוך תמונה"), ("#playlists", "רשימות"), ("#languages", "שפות"), ("#install", "התקנה")]),
             ("מידע", [("#faq", "שאלות נפוצות"), ("#free", "רשימות חינמיות")]),
             ("הפרויקט", [(REPO, "GitHub"), (DOWNLOAD, "גרסאות"), ("https://www.gnu.org/licenses/gpl-3.0.html", "רישיון GPL-3.0"), (REPO + "#contributing-translations", "תרגום IPTVMac")])],
  alt_h="נגני IPTV אחרים ל-Mac.", alt_p="IPTVMac הוא ל-Mac בלבד. אם אתם צריכים משהו אחר:",
  alt=["IPTVnator חינמי ובקוד פתוח ופועל גם ב-Windows וב-Linux.", "VLC יכול לפתוח רשימת M3U ישירות.", "ל-IPTV Smarters Pro יש אפליקציית שולחן עבודה ל-macOS."],
  credit='קטעי הדגמה: "Sintel" של Blender Foundation, <a href="https://durian.blender.org" rel="noopener">CC BY 3.0</a>. כל הכותרים והערוצים בעמוד בדויים.',
  tour_close="סגירת הסרטון", tour_note='80 שניות: ערוצים, חיפוש, מועדפים, הנגן, מהירות כפולה, תמונה בתוך תמונה והורדות. הערוצים והכרזות בדויים לצורך ההדגמה; הקטע המנוגן הוא הסרט Sintel של Blender Foundation (CC BY 3.0).',
  lic="קוד פתוח ברישיון GPL-3.0."),
}

# ---------- building blocks ----------
def wbr_cmd(cmd):
    # soft break opportunities so the command wraps at slashes and before the pipe; textContent (what Copy uses) is unchanged
    parts = re.split(r'(?<=/)(?=[A-Za-z])|(?= \|)', cmd)
    return "<wbr>".join(e(p) for p in parts)

def cmd_block(c, cls=""):
    return (f'<div class="cmd {cls}"><span class="prompt" aria-hidden="true">$</span><code>{wbr_cmd(INSTALL_CMD)}</code>'
            f'<button class="copy" type="button" data-done="{e(c["copied"])}" aria-label="{e(c["copy_aria"])}">{ICON_COPY}{ICON_OK}<span class="lbl">{e(c["copy"])}</span></button>'
            f'<span class="sr" role="status" aria-live="polite"></span></div>')

def pic(up, name, alt, cls="", sizes="(min-width: 1000px) 60vw, 100vw", eager=False, widths=(1200, 1800), fmt="jpg"):
    # screenshots are published as WebP (1200 px, and 1800 px where present) with a JPEG fallback
    sets = {1200: f"{up}screenshots/{name}.webp 1200w", 1800: f"{up}screenshots/{name}-1800.webp 1800w"}
    ss = ", ".join(sets[w] for w in widths)
    return (f'<picture{f" class={chr(34)}{cls}{chr(34)}" if cls else ""}><source type="image/webp" srcset="{ss}" sizes="{sizes}">'
            f'<img src="{up}screenshots/{name}.jpg" width="1800" height="1130" alt="{e(alt)}" {"fetchpriority=high" if eager else "loading=lazy"} decoding="async"></picture>')

def win(inner, bar=True):
    # the static composition of one app window (the demo module draws its own window in the slot next to it)
    return (f'<div class="win static-win">{"<div class=win-bar><i></i><i></i><i></i></div>" if bar else ""}'
            f'<div class="win-body">{inner}</div></div>')

def slot(scene):
    return f'<div class="demo-slot" data-iptvdemo-mount data-scene="{scene}"></div>'

def header_html(c, depth, home=True):
    up = "../" * depth
    prefix = "" if home else up
    links = "".join(f'<a{" class=keep" if h == "#install" else ""} href="{prefix}{h}">{e(t)}</a>' for h, t in c["nav"])
    ol = c["other_lang"]
    href = ol[0] if home else (up + ("he/" if ol[2] == "he" else ""))
    return f'''<a class="skip" href="#main">{e(c["skip"])}</a>
<div class="prog" aria-hidden="true"></div>
<header class="top" id="top"><a class="brand" href="{up or './'}" aria-label="{e(c["home_aria"])}"><img src="{up}logo.png" width="30" height="30" alt=""><span class="brand-t">IPTVMac</span></a>
<nav class="nav" aria-label="{e(c["nav_aria"])}">{links}</nav>
<div class="tools"><a class="ibtn" href="{REPO}" aria-label="{e(c["gh"])}" rel="noopener">{ICON_GH}</a>
<button class="ibtn theme" type="button" aria-label="{e(c["theme"])}">{ICON_SUN}{ICON_MOON_T}</button>
<a class="pill" href="{href}" hreflang="{ol[2]}" lang="{ol[2]}">{e(ol[1])}</a></div></header>
'''

def footer_html(c, depth, home=True):
    # on the home page the closing section already carries the "no content" disclaimer right above the footer
    up = "../" * depth
    cols = ""
    for h, items in c["foot_cols"]:
        cols += f'<div><h3>{e(h)}</h3><ul>' + "".join(
            f'<li><a href="{(href if href.startswith("http") else (up if not home and href.startswith("#") else "") + href)}"{" rel=noopener" if href.startswith("http") else ""}>{e(t)}</a></li>' for href, t in items) + '</ul></div>'
    alts = "".join(f"<li>{e(x)}</li>" for x in c["alt"])
    return f'''<footer class="site"><div class="wrap">
<div class="foot"><div class="about"><a class="brand" href="{up or './'}"><img src="{up}logo.png" width="30" height="30" alt="">IPTVMac</a><p>{e(c["foot_about"])}</p></div>{cols}</div>
<div class="fine-print">{"" if home else f"<p>{e(c['foot'])}</p>"}
<p><b>{e(c["alt_h"])}</b> {e(c["alt_p"])} {" ".join(e(x) for x in c["alt"])}</p>
<p>{c["credit"]}</p><p>{e(c["lic"])} <a href="{REPO}">GitHub</a></p></div></div></footer>
'''

def script_tag(up, c, mods=True):
    attrs = ""
    for mod in ("fx", "demo"):
        if mods and mod in HAS:
            attrs += f' data-{mod}-js="{up}{HAS[mod]["js"]}"' + (f' data-{mod}-css="{up}{HAS[mod]["css"]}"' if HAS[mod]["css"] else "")
    return f'<script src="{av(up, "site.js")}" defer id="site-js" data-lang="{c["lang"]}"{attrs}></script>\n'

# ---------- home page ----------
def chapter(cid, c, flip, text, stage, length=230):
    return (f'<section class="chap{" rev" if flip else ""}" id="{cid}" data-fx-scene data-chapter="{cid}" aria-labelledby="{cid}-h" style="--len:{length}svh">'
            f'<div class="chap-pin"><div class="chap-text">{text}</div>{stage}<div class="chap-line" aria-hidden="true"><i></i></div></div></section>\n')

def ctext(cid, h, p, facts, extra=""):
    fl = "".join(f"<li>{f}</li>" for f in facts)
    return f'<h2 id="{cid}-h" data-fx-split>{e(h)}</h2><p>{e(p)}</p><ul class="facts">{fl}</ul>{extra}'

def tag_positions(c):
    # one playlist tag on each poster of the movies screenshot (7 columns x 3 rows, last row has 6); numbers measured on the 1800x1130 image
    out, names = "", c["pl_names"]
    for r in range(3):
        for col in range(7 if r < 2 else 6):
            n, _, color = names[(col * 2 + r * 3 + (col // 3)) % 3]
            left = (310 + col * 213.5 + 9) / 1800 * 100
            top = (64 + r * 336.5 + 290 - 34) / 1130 * 100
            out += f'<b style="left:{left:.2f}%;top:{top:.2f}%;--c:{color}">{e(n)}</b>'
    return out

def stage_search(c, up):
    return (f'<div class="stage stage-search"><div class="win-wrap">'
            + win(pic(up, "02-search", c["search_alt"], "static", widths=(1200, 1800))) + slot("search")
            + f'<div class="loupe fallback-only" aria-hidden="true">{ICON_SEARCH}<span class="q">na</span><small>{c["loupe_n"]}</small></div></div></div>')

def stage_player(c, up):
    ctrl = (f'<div class="ctrl fallback-only" aria-hidden="true">{ICON_PAUSE}{ICON_BACK}{ICON_FWD}<div class="seek"><i></i></div><span class="t">07:21 / 14:48</span>'
            f'<span class="spd" id="spd-pill">1x</span><span class="moon-wrap">{ICON_MOON}</span>{ICON_PIP}{ICON_FS}</div>')
    return (f'<div class="stage stage-player"><div class="win-wrap">'
            + win(pic(up, "05-player", c["player_alt"], "static", widths=(1200, 1800)) + ctrl) + slot("player") + '</div></div>')

def stage_pip(c, up):
    pip = (f'<div class="pip fallback-only" data-drag tabindex="0" role="group" aria-label="{e(c["pip_label"])}"><picture><source type="image/webp" srcset="{up}assets/pip-window.webp">'
           f'<img src="{up}assets/pip-window.jpg" width="588" height="330" alt="{e(c["pip_win_alt"])}" loading="lazy" decoding="async" draggable="false"></picture></div>')
    return (f'<div class="stage stage-pip"><div class="win-wrap">'
            + win(pic(up, "03-movies", c["pip_alt"], "static", widths=(1200, 1800))) + slot("pip") + pip + '</div></div>')

def stage_playlists(c, up):
    items = ""
    for n, kind, color in c["pl_names"]:
        items += f'<li><span class="dot" style="--c:{color}"></span>{e(n)}<small>{e(kind)}</small></li>'
    menu = f'<ul class="menu fallback-only" aria-hidden="true">{items}<hr><li class="all">{ICON_CHECK}{e(c["pl_all"])}</li></ul>'
    return (f'<div class="stage stage-playlists"><div class="win-wrap">'
            + win(pic(up, "03-movies", c["pl_alt"], "static", widths=(1200, 1800)) + f'<div class="tags fallback-only" aria-hidden="true">{tag_positions(c)}</div>' + menu) + slot("playlists")
            + '</div></div>')

def lang_wall(c):
    return '<ul class="wall">' + "".join(
        f'<li><span lang="{l}"{" dir=rtl class=rtl" if r else ""} data-lang="{l}">{e(n)}</span></li>' for l, n, r in LANGS) + '</ul>'

def minis():
    out = ""
    for code, rtl in (("he", 1), ("en", 0), ("ar", 1)):
        s = app_strings(code)
        out += (f'<div class="mini" lang="{code}" dir="{"rtl" if rtl else "ltr"}"><span class="sb">{svg('<rect x="3" y="4.5" width="14" height="11" rx="2.5"/><path d="M8 4.5v11"/>')}</span>'
                f'<span class="seg"><span>{e(s["live"])}</span><span>{e(s["movies"])}</span><span>{e(s["series"])}</span></span><span class="srch">{e(s["search"])}</span></div>')
    return out

def term(c):
    return f'''<div class="term" id="term"><div class="term-bar"><i></i><i></i><i></i><span class="ttl">{e(c["term"])}</span>
<button class="copy" type="button" data-done="{e(c["copied"])}" aria-label="{e(c["copy_aria"])}">{ICON_COPY}{ICON_OK}<span class="lbl">{e(c["copy"])}</span></button><span class="sr" role="status" aria-live="polite"></span></div>
<div class="term-body"><span class="ln t1"><span class="ps">~ %</span> <code>{e(INSTALL_CMD)}</code></span>
<span class="ln t2 dim">Looking up the latest release...</span>
<span class="ln t3 dim">Downloading IPTVMac v{e(VERSION)}...</span>
<span class="bar" aria-hidden="true"><i></i></span>
<span class="ln t5"><span class="ok">Installed:</span> /Applications/IPTVMac.app</span>
<div class="opens"><img src="{c["up"]}logo.png" width="52" height="52" alt="" loading="lazy"><div>{e(c["opens"])}<small>{e(c["opens_s"])}</small></div></div></div></div>'''

def home(code):
    c = HOME[code]; up = c["up"]; he = code == "he"
    canon = BASE + c["prefix"]
    alts = [("en", BASE), ("he", BASE + "he/"), ("x-default", BASE)]
    ld = [software_ld(c["desc"], c["lang"]), faq_ld(c["faq"]), video_ld("IPTVMac demo", c["tour_note"])]
    srcs = lambda ext: ", ".join(f"{up}assets/hero-window-{w}.{ext} {w}w" for w in (900, 1400, 1800))
    sizes = "(min-width: 1001px) 58vw, 100vw"
    preload = f'<link rel="preload" as="image" type="image/avif" imagesrcset="{srcs("avif")}" imagesizes="{sizes}" fetchpriority="high">\n'
    out = head(c["title"], c["desc"], canon, c["lang"], 1 if he else 0, alts, extra_ld=ld, preload=preload)
    out += header_html(c, 1 if he else 0)
    words = json.dumps(native_words(code), ensure_ascii=False)
    morph = f"<span class=\"morph\" data-fx-morph data-words='{words}'>{e(NATIVE[code])}</span>"
    h1 = c["h1"].replace("{m}", morph)
    hero_pic = (f'<picture><source type="image/avif" srcset="{srcs("avif")}" sizes="{sizes}"><source type="image/webp" srcset="{srcs("webp")}" sizes="{sizes}">'
                f'<img src="{up}assets/hero-window-1400.jpg" srcset="{srcs("jpg")}" sizes="{sizes}" width="1800" height="1186" alt="{e(c["hero_alt"])}" fetchpriority="high" decoding="async"></picture>')
    hero_pip = (f'<picture class="pip hero-pip"><source type="image/webp" srcset="{up}assets/pip-window.webp"><img src="{up}assets/pip-window.jpg" width="588" height="330" alt="" decoding="async"></picture>')
    out += f'''<main id="main">
<section class="hero" id="hero" data-fx-scene aria-labelledby="h1"><canvas class="hero-canvas" data-fx-canvas aria-hidden="true"></canvas>
<div class="hero-copy"><h1 id="h1">{h1}</h1>
<p class="lede">{e(c["lede"])}</p>
<div class="install-bar"><p><b>{e(c["cmd_b"])}</b> {e(c["cmd_t"])}</p>{cmd_block(c)}</div>
<div class="actions"><a class="btn" data-fx-magnetic href="{DOWNLOAD}">{ICON_DL}{e(c["dl"])}</a><a class="link" href="{REPO}" rel="noopener">{ICON_GH}{e(c["src"])}</a>
<a class="link tour-link" href="{up}assets/demo.mp4">{ICON_PLAY}{e(c["tour"])}</a></div>
<p class="meta">{e(c["meta"])}</p></div>
<div class="hero-obj" data-fx-tilt><div class="pose"><div class="win hero-win">{hero_pic}</div>{hero_pip}</div></div>
<a class="cue" href="#search">{e(c["cue"])}</a></section>
'''
    # 1 search
    out += chapter("search", c, False,
        ctext("search", c["search_h"], c["search_p"], [e(f) for f in c["search_f"]],
              f'<div class="count"><span class="num" data-count="100000">100,000</span><span>{e(c["search_count"])}</span></div>'),
        stage_search(c, up))
    # 2 player
    dial = (f'<div class="dial fallback-only"><div class="dial-head"><label for="spd">{e(c["dial"])}</label><output id="spd-out" for="spd">1x</output></div>'
            f'<input id="spd" type="range" min="0.25" max="4" step="0.05" value="1"><div class="dial-ticks" aria-hidden="true"><span>0.25x</span><span>1x</span><span>2x</span><span>4x</span></div></div>')
    keys = '<div class="keys">' + "".join(f"<span><kbd>{e(k)}</kbd>{e(t)}</span>" for k, t in c["keys"]) + "</div>"
    out += chapter("player", c, True, ctext("player", c["player_h"], c["player_p"], [e(f) for f in c["player_f"]], dial + keys), stage_player(c, up))
    # 3 pip
    out += chapter("pip", c, False, ctext("pip", c["pip_h"], c["pip_p"], [e(f) for f in c["pip_f"]], f'<p class="hint" hidden>{e(c["pip_hint"])}</p>'), stage_pip(c, up))
    # 4 playlists
    out += chapter("playlists", c, True, ctext("playlists", c["pl_h"], c["pl_p"], [e(f) for f in c["pl_f"]]), stage_playlists(c, up))
    # 5 languages
    out += f'''<section class="langs" id="languages" data-fx-scene aria-labelledby="languages-h"><div class="wrap">
<div class="langs-head"><h2 id="languages-h" data-fx-split>{e(c["langs_h"])}</h2><p>{e(c["langs_p"])}</p></div>
<div class="langs-body">{lang_wall(c)}
<div class="langs-side"><div class="stage"><div class="trio fallback-only"><p class="hint">{e(c["trio_h"])}</p>{minis()}</div>
<div class="win-wrap demo-only">{slot("languages")}</div></div>
<p class="langs-note">{e(c["langs_note"])} <a href="{c["langs_href"]}" rel="noopener">{e(c["langs_link"])}</a></p></div></div></div></section>
'''
    # 6 install
    steps = "".join(f"<li>{s}</li>" for s in c["dmg_steps"])
    out += f'''<section class="install" id="install" data-fx-scene aria-labelledby="install-h"><div class="wrap"><div class="install-grid">
<div class="install-text"><h2 id="install-h" data-fx-split>{e(c["install_h"])}</h2><p>{e(c["install_p"])}</p><p class="reqs">{e(c["reqs"])}</p>
<p style="margin-top:14px"><a class="link" href="{YT_INSTALL}" rel="noopener">{ICON_PLAY}{e(c["video"])}</a></p></div>
{term(c)}</div>
<div class="note"><div><h3>{e(c["why_h"])}</h3><p>{e(c["why"])}</p></div>
<div><h3>{e(c["dmg_h"])}</h3><ol class="steps">{steps}</ol><a class="btn" href="{DOWNLOAD}">{ICON_DL}{e(c["dl"])}</a></div></div></div></section>
'''
    # free playlists, faq, guides
    out += f'''<section class="free" id="free" aria-labelledby="free-h"><div class="wrap free-grid"><h2 id="free-h">{e(c["free_h"])}</h2><div><p>{e(c["free_p"])}</p>
<div class="m3u"><code>{FREE_M3U}</code><button class="copy" type="button" data-done="{e(c["copied"])}" aria-label="{e(c["copy_aria"])}">{ICON_COPY}{ICON_OK}<span class="lbl">{e(c["copy"])}</span></button><span class="sr" role="status" aria-live="polite"></span></div>
<p class="fine">{e(c["free_note"])}</p><a class="btn" href="{FREE_REPO}" rel="noopener">{e(c["free_btn"])}</a></div></div></section>
<section class="faq-sec" id="faq" aria-labelledby="faq-h"><div class="wrap faq-grid"><h2 id="faq-h">{e(c["faq_h"])}</h2>
<div class="faqs">{"".join(f'<details name="faq"><summary>{e(q)}</summary><p>{e(a)}</p></details>' for q, a in c["faq"])}</div></div></section>
<section class="guides" id="guides" aria-labelledby="guides-h"><div class="wrap"><h2 id="guides-h">{e(c["guides_h"])}</h2><div class="glist">{"".join(f'<a href="{u}"><strong lang="en" dir="ltr">{e(t)}</strong><span>{e(s)}</span>{ICON_CHEV}<span class="sr">{e(c["guide_go"])}</span></a>' for u, t, s in c["guides"])}</div></div></section>
'''
    # closing
    out += f'''<section class="finale" id="get" data-fx-scene aria-labelledby="get-h"><div class="wrap"><h2 id="get-h"><span class="l">{e(c["cta_l"][0])}</span> <span class="l">{e(c["cta_l"][1])}</span></h2>
<p>{e(c["cta_p"])}</p><div class="actions"><a class="btn fill big" data-fx-magnetic href="{DOWNLOAD}">{ICON_DL}{e(c["cta_dl"])}</a><a class="btn big" data-fx-magnetic href="{REPO}">{ICON_GH}{e(c["cta_src"])}</a></div>
<p class="disc">{e(c["foot"])}</p></div></section>
</main>
'''
    out += footer_html(c, 1 if he else 0)
    rail = "".join(f'<li><a href="{h}"><span>{e(t)}</span></a></li>' for h, t in c["foot_cols"][0][1])
    out += f'<nav class="rail" aria-label="{e(c["rail_aria"])}"><ul>{rail}</ul></nav>\n'
    out += (f'<dialog class="tour" id="tour" aria-label="{e(c["tour"])}"><button class="x" type="button" aria-label="{e(c["tour_close"])}">{ICON_X}</button>'
            f'<video controls preload="none" playsinline width="1280" height="720" data-poster="{up}assets/demo-poster.webp"><source src="{up}assets/demo.mp4" type="video/mp4"></video><p>{e(c["tour_note"])}</p></dialog>\n')
    out += script_tag(up, c) + '</body></html>\n'
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

def slug(t): return re.sub(r"[^a-z0-9]+", "-", re.sub(r"<[^>]+>", "", t).lower()).strip("-")

def guide(g):
    c = HOME["en"]
    canon = BASE + f"guides/{g['slug']}.html"
    ld = [{"@context": "https://schema.org", "@type": "Article", "headline": g["h1"], "description": g["desc"],
           "datePublished": UPDATED, "dateModified": UPDATED, "inLanguage": "en", "mainEntityOfPage": canon,
           "author": {"@type": "Person", "name": "Goelir", "url": "https://github.com/Goelir"},
           "publisher": {"@type": "Person", "name": "Goelir"}, "image": BASE + "social-preview.png"},
          faq_ld(g["faq"]), {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": [
              {"@type": "ListItem", "position": 1, "name": "IPTVMac", "item": BASE},
              {"@type": "ListItem", "position": 2, "name": g["h1"], "item": canon}]}]
    toc = []
    def ident(m):
        i = slug(m.group(1)); toc.append((i, m.group(1)))
        return f'<h2 id="{i}">{m.group(1)}</h2>'
    body = re.sub(r"<h2>(.*?)</h2>", ident, g["body"])
    out = head(g["title"], g["desc"], canon, "en", 1, og_type="article", extra_ld=ld)
    out += header_html(c, 1, home=False)
    related = "".join(f'<li><a href="{o["slug"]}.html">{e(o["h1"])}</a></li>' for o in GUIDES if o is not g)
    tocs = "".join(f'<a href="#{i}">{t}</a>' for i, t in toc)
    out += f'''<main id="main"><div class="wrap g-wrap"><div class="g-grid">
<article class="g-main"><nav class="crumbs" aria-label="Breadcrumb"><a href="../">IPTVMac</a> / <a href="../#guides">Guides</a></nav>
<h1>{e(g["h1"])}</h1>
<p class="answer">{e(g["answer"])}</p>
<div class="prose">{body}</div>
<p style="margin-top:36px"><a class="btn fill" href="{DOWNLOAD}">{ICON_DL}Download IPTVMac for Mac</a></p>
<div class="g-foot"><h2>More guides</h2><ul>{related}</ul><p class="fine">Updated {UPDATED}. IPTVMac is a media player; it does not include or host any content.</p></div></article>
<aside class="g-side"><nav class="toc" aria-label="On this page"><p class="side-h">On this page</p>{tocs}</nav>
<div class="side-cta"><p class="side-h">Install in one line</p>{cmd_block(c)}</div></aside>
</div></div></main>
'''
    out += footer_html(c, 1, home=False)
    out += script_tag("../", c, mods=False) + '</body></html>\n'
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
