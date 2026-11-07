#!/usr/bin/env python3
"""Извештај за workflow-от „Провери ја апликацијата“.

    python3 .github/scripts/check-report.py sheets    → report/sheets/*.png (сите екрани на еден јазик на една слика)
    python3 .github/scripts/check-report.py summary   → Markdown за GitHub Summary + report/status.txt (ok / fail)

Влез: out/selftest.json, out/missing/<уред>-missing-translations-<јазик>.txt, shots/<уред>/<јазик>/<екран>.png,
build.log, release.log и излезите од чекорите (DEBUG_OUTCOME, RELEASE_OUTCOME, FUNCTIONS_OUTCOME).
"""
import glob
import json
import os
import re
import sys

LANGS = ["en", "mk", "sq", "sr", "bg", "el", "tr", "de", "fr", "es", "it", "pl", "pt"]
NAMES = {
    "en": "English", "mk": "Македонски", "sq": "Shqip", "sr": "Srpski", "bg": "Български",
    "el": "Ελληνικά", "tr": "Türkçe", "de": "Deutsch", "fr": "Français", "es": "Español",
    "it": "Italiano", "pl": "Polski", "pt": "Português",
}
SCREENS = ["language", "name", "home", "trip", "packing", "outfits", "wardrobe", "looks", "settings", "new", "offer"]
SCREEN_NAMES = {
    "language": "Јазик", "name": "Име", "home": "Почетна", "trip": "Патување", "packing": "Листа",
    "outfits": "Аутфити", "wardrobe": "Гардероба", "looks": "Аутфити (гардероба)", "settings": "Профил",
    "new": "Ново патување", "offer": "Premium",
}


def sheets():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Pillow не е инсталиран — без прегледни листови")
        return
    os.makedirs("report/sheets", exist_ok=True)
    try:
        font = ImageFont.load_default(size=26)
    except TypeError:
        font = ImageFont.load_default()

    def tile(path, width):
        image = Image.open(path).convert("RGB")
        height = int(image.height * width / image.width)
        return image.resize((width, height), Image.LANCZOS)

    def compose(entries, title, out, width=300, per_row=6):
        # entries: [(label, path)]
        if not entries:
            return
        tiles = [(label, tile(path, width)) for label, path in entries]
        cell_h = max(t.height for _, t in tiles) + 40
        rows = (len(tiles) + per_row - 1) // per_row
        cols = min(per_row, len(tiles))
        gap = 16
        sheet = Image.new("RGB", (cols * (width + gap) + gap, rows * (cell_h + gap) + gap + 56), "white")
        draw = ImageDraw.Draw(sheet)
        draw.text((gap, 14), title, fill=(20, 30, 60), font=font)
        for index, (label, image) in enumerate(tiles):
            x = gap + (index % per_row) * (width + gap)
            y = 56 + gap + (index // per_row) * (cell_h + gap)
            draw.text((x, y), label, fill=(90, 90, 90), font=font)
            sheet.paste(image, (x, y + 36))
            draw.rectangle([x - 1, y + 35, x + image.width, y + 36 + image.height], outline=(200, 200, 200))
        sheet.save(out, optimize=True)
        print("✓", out)

    for device in sorted(os.listdir("shots")) if os.path.isdir("shots") else []:
        for lang in LANGS:
            entries = [(screen, f"shots/{device}/{lang}/{screen}.png") for screen in SCREENS
                       if os.path.isfile(f"shots/{device}/{lang}/{screen}.png")]
            compose(entries, f"{device} - {lang}", f"report/sheets/{device}-{lang}.png")
        # Ист екран на сите јазици (најбрзо се гледа исечен текст)
        for screen in SCREENS:
            entries = [(lang, f"shots/{device}/{lang}/{screen}.png") for lang in LANGS
                       if os.path.isfile(f"shots/{device}/{lang}/{screen}.png")]
            if len(entries) > 1:
                compose(entries, f"{device} - {screen} - all languages", f"report/sheets/{device}-screen-{screen}.png",
                        width=240, per_row=7)


def build_errors(path):
    if not os.path.isfile(path):
        return []
    errors = []
    for line in open(path, encoding="utf-8", errors="replace"):
        if re.search(r"\berror:", line) and line.strip() not in errors:
            errors.append(line.strip())
    return errors[:40]


def summary():
    lines = []
    problems = []

    def mark(ok):
        return "✅" if ok else "❌"

    debug = os.environ.get("DEBUG_OUTCOME", "")
    release = os.environ.get("RELEASE_OUTCOME", "")
    functions = os.environ.get("FUNCTIONS_OUTCOME", "")

    results = []
    if os.path.isfile("out/selftest.json"):
        try:
            results = json.load(open("out/selftest.json", encoding="utf-8"))
        except ValueError:
            results = []
    passed = [r for r in results if r.get("passed")]
    failed = [r for r in results if not r.get("passed")]
    crashes = glob.glob("report/crashes/*")

    missing = {}
    for path in glob.glob("out/missing/*missing-translations-*.txt"):
        lang = path.rsplit("-", 1)[-1].replace(".txt", "")
        for raw in open(path, encoding="utf-8", errors="replace"):
            text = raw.rstrip("\n")
            if text:
                missing.setdefault(lang, set()).add(text)

    shots = glob.glob("shots/*/*/*.png")

    lines.append("## Проверка на апликацијата")
    lines.append("")
    lines.append("| Проверка | Резултат |")
    lines.append("|---|---|")
    lines.append(f"| Изградба за симулатор (Debug) | {mark(debug == 'success')} |")
    if release:
        lines.append(f"| Изградба како за TestFlight (Release) | {mark(release == 'success')} |")
    else:
        lines.append("| Изградба како за TestFlight (Release) | — не стигна |")
    if results:
        lines.append(f"| Самопроверка на логиката | {mark(not failed)} {len(passed)}/{len(results)} |")
    elif debug == "success":
        lines.append("| Самопроверка на логиката | ❌ нема резултат (апликацијата падна или не се отвори) |")
    lines.append(f"| Push-известувања (functions) | {mark(functions == 'success') if functions else '—'} |")
    count = sum(len(v) for v in missing.values())
    lines.append(f"| Непреведени текстови на екраните | {'✅ 0' if not missing else f'⚠️ {count}'} |")
    lines.append(f"| Слики (сите јазици) | {len(shots)} |")
    if crashes:
        lines.append(f"| Падови на апликацијата | ❌ {len(crashes)} (во Artifacts → crashes) |")
    lines.append("")

    if debug != "success":
        problems.append("debug")
        errors = build_errors("build.log")
        lines.append("### Грешки при изградба (Debug)")
        lines.append("```")
        lines.extend(errors or ["(види го логот на чекорот „Изгради за симулатор“)"])
        lines.append("```")
    if release and release != "success":
        problems.append("release")
        lines.append("### Грешки при изградба (Release)")
        lines.append("```")
        lines.extend(build_errors("release.log") or ["(види го логот на чекорот „Изгради Release“)"])
        lines.append("```")
    if functions and functions != "success":
        problems.append("functions")
    if failed or (debug == "success" and not results):
        problems.append("selftest")
    if crashes:
        problems.append("crash")

    if results:
        lines.append("### Самопроверка")
        for result in results:
            lines.append(f"- {mark(result.get('passed'))} {result.get('name')}")
            if not result.get("passed") and result.get("detail"):
                lines.append(f"  - `{result['detail'][:900]}`")
        lines.append("")

    if missing:
        lines.append("### Непреведени текстови (се прикажуваат на англиски)")
        for lang in LANGS:
            texts = sorted(missing.get(lang, []))
            if not texts:
                continue
            lines.append(f"<details><summary>{NAMES.get(lang, lang)} — {len(texts)}</summary>")
            lines.append("")
            for text in texts[:60]:
                lines.append(f"- `{text[:160]}`")
            lines.append("</details>")
        lines.append("")

    lines.append("Сликите: **Artifacts → Tripdrobe-check → sheets** — `pro-de.png` = сите екрани на германски, "
                 "`pro-screen-home.png` = почетната на сите јазици, `small-…` = мал екран (iPhone SE).")

    print("\n".join(lines))
    os.makedirs("report", exist_ok=True)
    with open("report/status.txt", "w") as status:
        status.write("ok\n" if not problems else "fail: " + ", ".join(problems) + "\n")
    with open("report/summary.md", "w", encoding="utf-8") as out:
        out.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "summary"
    if command == "sheets":
        sheets()
    else:
        summary()
