#!/usr/bin/env python3
"""Checks every Resources/<lang>.lproj/Localizable.strings against en.lproj.
Usage: python3 scripts/check-strings.py [lang ...]   (no arguments = all languages)
A translation must have exactly the keys of English, the same %@ / %d specifiers in the same order, no empty values,
and must not be an untouched copy of the English text. Exit status 1 when something is wrong."""
import json, re, subprocess, sys, pathlib

RES = pathlib.Path(__file__).resolve().parent.parent / "Sources/IPTVMac/Resources"

def load(lang):
    out = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(RES / f"{lang}.lproj/Localizable.strings")],
                         capture_output=True, text=True)
    if out.returncode: raise SystemExit(f"{lang}: not a valid .strings file: {out.stderr.strip()}")
    return json.loads(out.stdout)

def specs(s): return re.findall(r"%(?:\d+\$)?[@dsfl]+", s)

en = load("en")
langs = sys.argv[1:] or sorted(p.name[:-6] for p in RES.glob("*.lproj") if p.name not in ("en.lproj", "Base.lproj"))
bad = 0
for lang in langs:
    t = load(lang); problems = []
    problems += [f"missing key {k}" for k in en if k not in t]
    problems += [f"extra key {k}" for k in t if k not in en]
    for k, v in en.items():
        if k not in t: continue
        if not t[k].strip(): problems.append(f"empty value {k}")
        if specs(t[k]) != specs(v): problems.append(f"format specifiers differ in {k}: {specs(v)} vs {specs(t[k])}")
    same = [k for k in en if k in t and t[k] == en[k] and re.search(r"[A-Za-z]{4,}", en[k]) and k != "app.name"]
    if len(same) > 25: problems.append(f"{len(same)} values are identical to English (untranslated?): {same[:6]}")
    print(f"{lang}: {'OK' if not problems else 'PROBLEMS'} ({len(t)} keys)")
    for p in problems: print("   -", p)
    bad += bool(problems)
sys.exit(1 if bad else 0)
