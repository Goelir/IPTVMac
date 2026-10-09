#!/usr/bin/env python3
"""Checks the generated site in docs/: every internal href/src/srcset exists, in-page anchors and aria-labelledby resolve,
JSON-LD parses, one h1 per page, no skipped heading levels, no duplicate ids, every img has alt.
Run after build:  python3 scripts/site/build.py && python3 scripts/site/check.py   (exit code 1 on any issue)"""
import json, pathlib, re, sys
from html.parser import HTMLParser

DOCS = pathlib.Path(__file__).resolve().parents[2] / "docs"

class Page(HTMLParser):
    def __init__(s):
        super().__init__(); s.refs = []; s.heads = []; s.ids = []; s.ld = []; s.labelled = []; s.noalt = []; s._ld = False; s._h = None
    def handle_starttag(s, t, a):
        a = dict(a)
        for k in ("href", "src", "poster", "data-poster"):
            if a.get(k): s.refs.append((k, a[k]))
        for k in ("srcset", "imagesrcset"):
            if a.get(k): s.refs += [(k, x.split()[0]) for x in a[k].split(",") if x.strip()]
        if "id" in a: s.ids.append(a["id"])
        if "aria-labelledby" in a: s.labelled += a["aria-labelledby"].split()
        if t == "img" and "alt" not in a: s.noalt.append(a.get("src"))
        if t in ("h1", "h2", "h3", "h4"): s._h = [int(t[1]), ""]
        if t == "script" and a.get("type") == "application/ld+json": s._ld = True; s.ld.append("")
    def handle_endtag(s, t):
        if s._h and t in ("h1", "h2", "h3", "h4"): s.heads.append(tuple(s._h)); s._h = None
        if t == "script": s._ld = False
    def handle_data(s, d):
        if s._ld: s.ld[-1] += d
        if s._h is not None: s._h[1] += d

def check(path):
    p = Page(); p.feed(path.read_text()); errs = []
    for k, v in p.refs:
        if re.match(r"^(https?:|mailto:|data:|javascript:)", v): continue
        if v.startswith("#"):
            if len(v) > 1 and v[1:] not in p.ids: errs.append(f"dangling anchor {v}")
            continue
        target = v.split("#")[0].split("?")[0]
        if target and not (path.parent / target).resolve().exists(): errs.append(f"missing file {k}={v}")
    errs += [f"aria-labelledby points nowhere: {i}" for i in p.labelled if i not in p.ids]
    if sum(1 for lv, _ in p.heads if lv == 1) != 1: errs.append("page needs exactly one h1")
    prev = 0
    for lv, txt in p.heads:
        if prev and lv > prev + 1: errs.append(f"heading level jumps h{prev} to h{lv}: {txt.strip()[:40]}")
        prev = lv
    errs += [f"duplicate id {i}" for i in {i for i in p.ids if p.ids.count(i) > 1}]
    for raw in p.ld:
        try: json.loads(raw)
        except ValueError as e: errs.append(f"JSON-LD does not parse: {e}")
    errs += [f"img without alt: {s}" for s in p.noalt]
    return errs

bad = 0
for page in [DOCS / "index.html", DOCS / "he/index.html", *sorted((DOCS / "guides").glob("*.html"))]:
    errs = check(page); bad += len(errs)
    print(("ok     " if not errs else "ISSUES ") + str(page.relative_to(DOCS)))
    for e in errs: print("   ", e)
sys.exit(1 if bad else 0)
