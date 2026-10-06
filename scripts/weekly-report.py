#!/usr/bin/env python3
"""Weekly performance check for IPTVMac. No logins needed: GitHub API (gh), public pages, DuckDuckGo, YouTube watch page.
Writes a Markdown report plus a history file (for week-over-week changes) and shows a macOS notification.
Run by hand: python3 scripts/weekly-report.py     (launchd runs it every Monday, see scripts/install-weekly.sh)"""
import json, re, subprocess, sys, time, urllib.parse, urllib.request, datetime, pathlib, os

REPO = "Goelir/IPTVMac"
SITE = "https://goelir.github.io/IPTVMac/"
PAGES = ["", "he/", "guides/xtream-codes-on-mac.html", "guides/m3u-playlist-on-mac.html", "guides/picture-in-picture-iptv-mac.html", "sitemap.xml", "llms.txt"]
YT_ID = "TgaoFEEMg48"
PR = ("jaywcjlove/awesome-mac", 3208)
WEB_QUERIES = ["IPTVMac", "iptv player for mac"]   # DuckDuckGo blocks bots after a few requests, so only two, best effort
GH_QUERIES = ["iptv player mac", "iptv macos", "xtream codes", "m3u player", "topic:iptv topic:macos", "iptv swiftui"]
OUT = pathlib.Path.home() / "Movies" / "IPTVMac-demo" / "weekly"
HIST = pathlib.Path.home() / "Library" / "Application Support" / "IPTVMac-weekly" / "history.json"
GH = next((p for p in ("/opt/homebrew/bin/gh", "/usr/local/bin/gh") if os.path.exists(p)), "gh")
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

def get(url, timeout=25):
    """curl uses the system certificates (the python.org build has none installed)."""
    try:
        r = subprocess.run(["curl", "-sL", "-m", str(timeout), "-A", UA, "-w", "\n%{http_code}", url], capture_output=True, text=True, timeout=timeout + 5)
        body, _, code = r.stdout.rpartition("\n")
        return int(code or 0), body
    except Exception: return 0, ""

def gh(*args):
    try: return json.loads(subprocess.run([GH, "api", *args], capture_output=True, text=True, timeout=60, check=True).stdout)
    except Exception: return None

def delta(now, prev):
    if prev is None or now is None: return ""
    d = now - prev
    return f" ({'+' if d > 0 else ''}{d} vs last week)" if d else " (no change)"

def search_rank(q):
    st, html = get("https://html.duckduckgo.com/html/?q=" + urllib.parse.quote(q))
    if st != 200: return None, []
    urls = [urllib.parse.unquote(m.group(1)) for m in re.finditer(r'uddg=([^&"]+)', html)]
    if not urls: return None, []   # bot check page, no results
    ours = [i + 1 for i, u in enumerate(urls) if "goelir.github.io/IPTVMac" in u or "github.com/Goelir/IPTVMac" in u]
    return (ours[0] if ours else 0), urls[:3]

def github_rank(q):
    d = gh("search/repositories?q=" + urllib.parse.quote(q) + "&per_page=100")
    if not d or "items" not in d: return None
    names = [i["full_name"] for i in d["items"]]
    return names.index(REPO) + 1 if REPO in names else 0

def main():
    today = datetime.date.today().isoformat()
    prev = {}
    if HIST.exists():
        h = json.loads(HIST.read_text()); prev = h[-1] if h else {}
    cur = {"date": today}
    L = [f"# IPTVMac weekly report, {today}", ""]

    repo = gh(f"repos/{REPO}") or {}
    cur["stars"], cur["forks"], cur["watchers"] = repo.get("stargazers_count"), repo.get("forks_count"), repo.get("subscribers_count")
    L += ["## GitHub", f"- Stars: {cur['stars']}{delta(cur['stars'], prev.get('stars'))}", f"- Forks: {cur['forks']}{delta(cur['forks'], prev.get('forks'))}",
          f"- Open issues: {repo.get('open_issues_count')}"]
    views = gh(f"repos/{REPO}/traffic/views") or {}
    clones = gh(f"repos/{REPO}/traffic/clones") or {}
    L += [f"- Last 14 days: {views.get('count')} page views ({views.get('uniques')} unique visitors), {clones.get('count')} clones ({clones.get('uniques')} unique)"]
    refs = gh(f"repos/{REPO}/traffic/popular/referrers") or []
    if refs: L.append("- Top referrers: " + ", ".join(f"{r['referrer']} ({r['count']})" for r in refs[:5]))
    rels = gh(f"repos/{REPO}/releases") or []
    dl = sum(a["download_count"] for r in rels for a in r["assets"] if a["name"] == "IPTVMac.dmg")
    cur["downloads"] = dl
    latest = rels[0]["tag_name"] if rels else "?"
    L += [f"- DMG downloads (all versions): {dl}{delta(dl, prev.get('downloads'))}  | latest release: {latest}"]
    vid = sum(a["download_count"] for r in rels for a in r["assets"] if a["name"].endswith(".mp4"))
    L.append(f"- Demo video file downloads: {vid}")
    st = subprocess.run([GH, "pr", "view", str(PR[1]), "--repo", PR[0], "--json", "state,mergedAt,comments", "-q", '"\\(.state) merged=\\(.mergedAt) comments=\\(.comments|length)"'], capture_output=True, text=True).stdout.strip()
    L += [f"- awesome-mac pull request #{PR[1]}: {st or 'unknown'}", ""]

    L.append("## Website")
    bad = []
    for p in PAGES:
        code, _ = get(SITE + p)
        if code != 200: bad.append(f"{p or '/'} -> {code}")
    L.append("- All %d pages and files respond 200" % len(PAGES) if not bad else "- PROBLEM: " + "; ".join(bad))
    code, html = get(f"https://www.youtube.com/watch?v={YT_ID}")
    m = re.search(r'"viewCount":"(\d+)"', html)
    cur["yt_views"] = int(m.group(1)) if m else None
    L += [f"- YouTube install video: {cur['yt_views']} views{delta(cur['yt_views'], prev.get('yt_views'))}" if m else "- YouTube install video: could not read the view count", ""]

    L.append("## Search position (0 = not found)")
    cur["rank"] = {}
    for q in GH_QUERIES:
        r = github_rank(q); cur["rank"]["gh:" + q] = r; time.sleep(2)
        before = prev.get("rank", {}).get("gh:" + q)
        txt = "check failed" if r is None else ("not in the first 100" if r == 0 else f"position {r}")
        L.append(f"- GitHub search \"{q}\": {txt}" + (f" (last week: {before})" if before is not None and before != r else ""))
    for q in WEB_QUERIES:
        r, top = search_rank(q); time.sleep(6); cur["rank"]["web:" + q] = r
        before = prev.get("rank", {}).get("web:" + q)
        txt = "not checked (DuckDuckGo showed a bot check; use Search Console below)" if r is None else ("not on page 1" if r == 0 else f"position {r}")
        L.append(f"- DuckDuckGo \"{q}\": {txt}" + (f" (last week: {before})" if before is not None and before != r else ""))
    L += ["", "## Do by hand (needs your logins)",
          "- Google Search Console performance: https://search.google.com/search-console?resource_id=https%3A%2F%2Fgoelir.github.io%2FIPTVMac%2F (impressions, clicks, pages indexed, sitemap status)",
          "- Bing Webmaster: https://www.bing.com/webmasters/home",
          "- YouTube Studio analytics: https://studio.youtube.com/video/TgaoFEEMg48/analytics",
          "- Ask ChatGPT, Claude, Perplexity and Gemini: \"What is the best free IPTV player for Mac?\" and note whether IPTVMac appears.",
          "- AlternativeTo submission status: https://alternativeto.net/software/iptvmac/"]
    OUT.mkdir(parents=True, exist_ok=True); HIST.parent.mkdir(parents=True, exist_ok=True)
    report = OUT / f"{today}.md"; report.write_text("\n".join(L) + "\n")
    hist = json.loads(HIST.read_text()) if HIST.exists() else []
    hist = [h for h in hist if h["date"] != today] + [cur]; HIST.write_text(json.dumps(hist[-60:], indent=1))
    msg = f"stars {cur['stars']}, downloads {dl}, YouTube views {cur['yt_views']}" + (" | SITE PROBLEM" if bad else "")
    subprocess.run(["osascript", "-e", f'display notification "{msg}" with title "IPTVMac weekly report" subtitle "{report.name}"'], capture_output=True)
    print("\n".join(L)); print("\nSaved:", report)

if __name__ == "__main__":
    main()
