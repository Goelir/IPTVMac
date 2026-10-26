#!/usr/bin/env python3
"""Checks the Android TV store texts in appstore/android-tv/listing/* and the PNG graphics in appstore/android-tv/graphics.
Limits (Google Play Console, from memory, check in the console): title 30 characters, short description 80, full description 4000, release notes ("What's new") 500 per language.
Amazon keywords: the limit is NOT known to me; the check only warns above 100 characters. Play metadata policy (from memory): no emoji, no ALL CAPS words in the title, no price or ranking words ("free", "best", "#1", "top") in the title or short description, no other stores or competing apps named.
Graphics: Play icon 512x512 PNG (alpha allowed), feature graphic 1024x500 and TV banner 1280x720 must have NO alpha channel, Amazon icons 114x114 and 512x512.
Usage: python3 appstore/android-tv/check-listing.py        exit code 1 on any problem."""
import pathlib, re, struct, sys
ROOT = pathlib.Path(__file__).resolve().parent
LIMITS = {"title": 30, "short-description": 80, "full-description": 4000, "release-notes": 500}
PRICE = ["free", "gratis", "חינם", "חינמית", "best", "#1", "top", "sale", "discount"]          # title and short description only
BRANDS = ["vlc", "kodi", "plex", "netflix", "smarters", "tivimate", "disney", "hbo", "apple", "amazon", "fire tv", "ios", "iphone", "mac"]   # no other stores, devices or apps in the title or short description
EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿⭐✅]")
bad = 0
def err(loc, msg):
    global bad; bad += 1; print(f"  PROBLEM {loc}: {msg}")
def has(word, s): return re.search(r"(?<![\w#])" + re.escape(word) + r"(?![\w])", s.lower()) is not None
for d in sorted((ROOT / "listing").glob("*")):
    loc = d.name; t = {}
    for f in (*LIMITS, "keywords-amazon"):
        p = d / f"{f}.txt"
        if not p.exists(): err(loc, f"{f}.txt missing"); continue
        raw = p.read_text(encoding="utf-8"); t[f] = raw[:-1] if raw.endswith("\n") else raw
        if t[f] != t[f].strip() or "\r" in t[f]: err(loc, f"{f}.txt has stray whitespace or CR")
    if len(t) < 5: continue
    for f, lim in LIMITS.items():
        if len(t[f]) > lim: err(loc, f"{f} is {len(t[f])} > {lim} characters")
    for f in ("title", "short-description"):
        for w in PRICE + BRANDS:
            if has(w, t[f]): err(loc, f"'{w}' in {f}")
        if EMOJI.search(t[f]): err(loc, f"emoji in {f}")
        if re.search(r"\b[A-Z]{5,}\b", t[f]): err(loc, f"ALL CAPS word in {f}")
    if EMOJI.search(t["full-description"]): err(loc, "emoji in the full description")
    fd = t["full-description"]
    if "goelir.github.io/IPTVMac/" not in fd or "privacy" not in fd: err(loc, "full description lacks the privacy policy link")
    if "no channels" not in fd.lower() and loc.startswith("en"): err(loc, "full description must say that the app includes no content")
    if len(t["keywords-amazon"]) > 100: print(f"  note    {loc}: Amazon keywords are {len(t['keywords-amazon'])} characters, the limit is unknown to me, check in the console")
    if len(set(k.lower() for k in t["keywords-amazon"].split(","))) != len(t["keywords-amazon"].split(",")): err(loc, "duplicate Amazon keyword")
    print(f"{loc:6} title {len(t['title']):2}/30  short {len(t['short-description']):2}/80  full {len(fd):4}/4000  notes {len(t['release-notes']):3}/500  amazon keywords {len(t['keywords-amazon']):3}")
# graphics: name -> (width, height, alpha allowed)
GFX = {"play-icon-512.png": (512, 512, True), "play-feature-graphic-1024x500.png": (1024, 500, False), "play-tv-banner-1280x720.png": (1280, 720, False),
       "amazon-icon-512.png": (512, 512, True), "amazon-icon-114.png": (114, 114, True)}
for name, (w, h, alpha) in GFX.items():
    p = ROOT / "graphics" / name
    if not p.exists(): err("graphics", f"{name} missing"); continue
    b = p.read_bytes()
    if b[:8] != b"\x89PNG\r\n\x1a\n": err("graphics", f"{name} is not a PNG"); continue
    pw, ph, depth, ctype = struct.unpack(">IIBB", b[16:26])       # IHDR: colour type 2 = RGB, 6 = RGBA (3 = palette: refused, 4 and 6 have alpha)
    if (pw, ph) != (w, h): err("graphics", f"{name} is {pw}x{ph}, expected {w}x{h}")
    if ctype in (4, 6) and not alpha: err("graphics", f"{name} has an alpha channel, Play rejects that here")
    if len(b) > 1024 * 1024: err("graphics", f"{name} is {len(b)} bytes, over 1 MB")
    print(f"{name:36} {pw}x{ph} colour type {ctype} {len(b) // 1024} KB")
print("PROBLEMS" if bad else "all Android TV listing texts and graphics ok"); sys.exit(1 if bad else 0)
