#!/usr/bin/env python3
"""Build the 20-slide presentation copy of the AWS deck (Part 1 only).

Reuses build_aws_deck.py / deck_diagrams.py unchanged: only the per-section config
(CFG) and the section-id → diagram mapping are swapped, because the 20-slide script
renumbers every section (01–20).

Usage:
  python3 docs/presentations/build_deck20.py [--md ...] [--template ...] [--out ...]

Hard rule: one `##` section = exactly one slide → 20 slides. Any "split into N slides"
warning means a section must be shortened, not split.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_aws_deck as B          # noqa: E402
import deck_diagrams as D           # noqa: E402
import deck_style as S              # noqa: E402

# ── real text measurement ───────────────────────────────────────────────────
# deck_style.text_lines() estimates line counts from a per-character em table,
# which under-counts Korean and bold runs: measured against real glyph extents,
# several tables needed up to 1.7x their allotted height, so PowerPoint grew the
# rows and pushed later blocks off the slide. Here the line count is measured
# with the fonts PowerPoint actually falls back to on macOS (Apple SD Gothic Neo
# for Hangul, Helvetica for Latin), plus a small pad for Amazon Ember being a bit
# wider than Helvetica. Only this 20-slide build is affected.
from PIL import ImageFont  # noqa: E402

FONT_KOR = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
FONT_LAT = "/System/Library/Fonts/Helvetica.ttc"
FONT_MONO = "/System/Library/Fonts/Menlo.ttc"
PAD = 1.05
_fonts = {}


def _font(size_pt, kind):
    key = (round(size_pt * 2), kind)
    if key not in _fonts:
        path = {"kor": FONT_KOR, "lat": FONT_LAT, "mono": FONT_MONO}[kind]
        _fonts[key] = ImageFont.truetype(path, max(6, int(round(size_pt * 96 / 72))))
    return _fonts[key]


def _width_in(text, size_pt, mono):
    if not text:
        return 0.0
    kind = "kor" if any(ord(c) >= 0x2E80 for c in text) else ("mono" if mono else "lat")
    return _font(size_pt, kind).getlength(text) / 96.0 * PAD


def text_lines_real(text, size_pt, width_in, mono=False):
    """Greedy word wrap on measured token widths. CJK breaks per character."""
    if not text:
        return 1
    box = max(width_in, 0.3)
    tokens, buf = [], ""
    for ch in text:
        if ch == " " or ord(ch) >= 0x2E80:
            if buf:
                tokens.append(buf)
                buf = ""
            tokens.append(ch)
        else:
            buf += ch
    if buf:
        tokens.append(buf)
    lines, cur = 1, 0.0
    for t in tokens:
        w = _width_in(t, size_pt, mono)
        if cur + w > box and cur > 0:
            lines += 1
            cur = 0.0 if t == " " else w
        else:
            cur += w
    return lines


if all(os.path.exists(f) for f in (FONT_KOR, FONT_LAT, FONT_MONO)):
    S.text_lines = text_lines_real
    B.text_lines = text_lines_real
else:                                      # non-macOS: keep the em-table estimate
    print("WARN system fonts not found — falling back to deck_style.text_lines")

DEFAULT_MD = os.path.join(HERE, "2026-09-aws-deck-20p.md")
DEFAULT_OUT = os.path.join(HERE, "2026-09-aws-deck-20p.pptx")

# ── per-slide overrides for the new numbering ───────────────────────────────
CFG20 = {
    "01": dict(kind="cover"),
    "09": dict(cards=True),
    "19": dict(kind="quote", cards=True),
    "20": dict(kind="thanks"),
}


def augment20(sec):
    """Attach the existing native-shape diagrams to the new section ids."""
    bl, sid = sec.blocks, sec.id
    if sid == "03":
        D._replace_first(bl, "table", D.diagram(D.d03_layers, 5.2))
    elif sid == "04":
        D._replace_first(bl, "code", D.diagram(D.d04_pipeline, 3.36))
    elif sid == "05":
        D._insert_after(bl, "table", D.diagram(D.d07_costbar, 0.95))
        bl.insert(0, D.diagram(D.d06_stats, 1.25))
    elif sid == "06":
        D._replace_first(bl, "table", D.diagram(D.d08_funnel, 1.95))
    elif sid == "11":
        D._replace_first(bl, "callout", D.diagram(D.d16_decision, 1.55),
                         lambda b: "결정 규칙" in b["text"])
    elif sid == "12":
        D._replace_first(bl, "code", D.diagram(D.d17_two_paths, 4.37))
    elif sid == "13":
        D._replace_first(bl, "code", dict(type="b03"))
    elif sid == "16":
        D._replace_first(bl, "code", D.diagram(D.d18_paths, 1.55))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--md", default=DEFAULT_MD)
    ap.add_argument("--template", default=B.DEFAULT_TPL)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--debug-json", default=None)
    args = ap.parse_args()

    B.CFG = CFG20
    D.augment = augment20

    with open(args.md, encoding="utf-8") as f:
        sections = B.parse_sections(f.read())
    deck = B.Deck(args.template, os.path.dirname(os.path.abspath(args.md)))
    deck.build(sections)
    for part in deck.prs.part.package.iter_parts():
        if str(part.partname) == "/ppt/viewProps.xml":
            part._blob = part.blob.replace(b'lastView="sldMasterView"', b'lastView="sldView"')
    deck.prs.save(args.out)
    n = len(deck.prs.slides._sldIdLst)
    print(f"saved {args.out}: {n} slides from {len(sections)} sections")
    for w in deck.warnings:
        print("WARN", w)
    if args.debug_json:
        import json
        with open(args.debug_json, "w") as f:
            json.dump(deck.debug, f)
    return 0 if n == 20 and not deck.warnings else 1


if __name__ == "__main__":
    sys.exit(main())
