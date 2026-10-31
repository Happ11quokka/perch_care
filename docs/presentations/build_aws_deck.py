#!/usr/bin/env python3
"""Build the 2026-09 AWS AI-app architecture deck (PPTX) from the markdown script,
using the AWS Student Builder Group PowerPoint template for layouts/fonts/colors.

Usage:
  python3 docs/presentations/build_aws_deck.py \
      [--md docs/presentations/2026-09-aws-ai-app-architecture-deck.md] \
      [--template "~/Downloads/AWS_StudentBuilderGroups_PPTTemplate_Final 복사본.pptx"] \
      [--out docs/presentations/2026-09-aws-ai-app-architecture-deck.pptx]

Rules: one `##` section = one slide. `**말할 것**` paragraphs and `> 노트` quotes go to
speaker notes. A section that has both dense content and a diagram gets a follow-up
white "구성도" slide (diagram PNGs are dark-on-transparent).
"""
import argparse
import math
import os
import re
import sys

from lxml import etree
from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from deck_style import *  # noqa: E402,F401,F403
import deck_diagrams  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MD = os.path.join(HERE, "2026-09-aws-ai-app-architecture-deck.md")
DEFAULT_OUT = os.path.join(HERE, "2026-09-aws-ai-app-architecture-deck.pptx")
DEFAULT_TPL = os.path.expanduser(
    "~/Downloads/AWS_StudentBuilderGroups_PPTTemplate_Final 복사본.pptx")

# ── layout indexes (slide_master.slide_layouts[i]) ──────────────────────────
L_COVER, L_DIVIDER, L_QUOTE_DARK, L_QUOTE_GREEN = 0, 10, 23, 25
L_WHITE, L_DARK = 29, 30          # One column text A / B
L_ICON_GREY_J = 60                # dark + orange lightning icon (right half)

# per-slide overrides keyed by section id
CFG = {
    "01": dict(kind="cover"),
    "15": dict(cards=True),
    "25": dict(kind="quote", cards=True),
    "26": dict(kind="thanks"),
    "B01": dict(layout=L_ICON_GREY_J, max_w=7.7),
    "B18": dict(kind="quote", cards=True),
}

# size levels: (table, text, code, callout, cards_desc)
LEVELS = [
    (14, 16, 12, 15, 13.5),
    (12.5, 14, 11, 13, 12),
    (11, 12, 10, 11.5, 10.5),
    (10, 11, 9.5, 11, 10),
    (9, 10, 9, 10, 9.5),
    (8.5, 9.5, 8.5, 9.5, 9),
]
SPLIT_LEVEL = 2   # size level (11pt) used when a section must be split across slides
MIN_LEVEL = 2     # never shrink below 11pt on a single slide; split instead  # size level used when a section must be split across slides


# ═════════════════════════════════════════════════════════════════════════════
# Markdown parsing
# ═════════════════════════════════════════════════════════════════════════════
class Section:
    def __init__(self, sid, title):
        self.id, self.title = sid, title
        self.blocks, self.notes = [], []


def parse_table(lines):
    rows = []
    for ln in lines:
        s = ln.strip()
        if re.match(r"^\|\s*:?-{2,}", s):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        rows.append(cells)
    header = rows[0]
    has_header = any(c for c in header)
    body = rows[1:]
    ncol = max(len(r) for r in rows)
    rows = [r + [""] * (ncol - len(r)) for r in rows]
    return dict(type="table", header=rows[0] if has_header else None,
                rows=rows[1:], ncol=ncol)


CALLOUT_RE = re.compile(r"^\*\*(Perch Care에서는|결론|트리거 3개|결정 규칙|반드시 고칠|알람 최소|반전)")


def classify_para(line):
    if line.startswith("# "):
        return dict(type="hero", text=line[2:].strip())
    if line.startswith("!["):
        m = re.match(r"!\[([^\]]*)\]\(([^)]+)\)", line)
        return dict(type="image", alt=m.group(1), path=m.group(2))
    if CALLOUT_RE.match(line):
        return dict(type="callout", text=line)
    if re.fullmatch(r"\*\*[^*]+\*\*", line) and len(plain(line)) <= 45:
        return dict(type="heading", text=plain(line))
    if re.fullmatch(r"(세 줄 요약|참고|오늘 가져갈 것 세 줄:|모델 카탈로그 \(발췌\))", line):
        return dict(type="heading", text=line.rstrip(":"))
    return dict(type="para", text=line)


def parse_sections(md_text):
    lines = md_text.splitlines()
    sections, cur = [], None
    i = 0
    while i < len(lines):
        ln = lines[i]
        if ln.startswith("# Part 2"):
            cur = Section("P2", ln[2:].strip())
            sections.append(cur)
            i += 1
            continue
        if ln.startswith("## "):
            m = re.match(r"## ((?:B)?\d{2})\. (.+)", ln)
            if m:
                cur = Section(m.group(1), m.group(2).strip())
            else:
                cur = Section("X", ln[3:].strip())
            sections.append(cur)
            i += 1
            continue
        if cur is None or ln.strip() == "---":
            i += 1
            continue
        s = ln.rstrip()
        if s.strip() == "**말할 것**":
            i += 1
            buf = []
            while i < len(lines) and lines[i].strip():
                buf.append(lines[i].strip())
                i += 1
            cur.notes.append("[말할 것] " + " ".join(buf))
            continue
        if s.startswith("```"):
            i += 1
            buf = []
            while i < len(lines) and not lines[i].startswith("```"):
                buf.append(lines[i].rstrip())
                i += 1
            i += 1
            cur.blocks.append(dict(type="code", lines=buf))
            continue
        if s.startswith("|"):
            buf = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                buf.append(lines[i])
                i += 1
            cur.blocks.append(parse_table(buf))
            continue
        if s.startswith(">"):
            buf = []
            while i < len(lines) and lines[i].startswith(">"):
                buf.append(lines[i][1:].strip())
                i += 1
            groups, g = [], []
            for b in buf:
                if b == "":
                    if g:
                        groups.append(" ".join(g))
                        g = []
                else:
                    g.append(b)
            if g:
                groups.append(" ".join(g))
            for gtxt in groups:
                if gtxt.startswith("노트"):
                    cur.notes.append(plain(gtxt))
                elif gtxt.startswith("캡션"):
                    cur.blocks.append(dict(type="caption", text=plain(gtxt.split(":", 1)[1].strip())))
                elif gtxt.startswith("정답"):
                    cur.blocks.append(dict(type="answer", text=gtxt))
                    cur.notes.append(plain(gtxt))
                elif cur.id == "P2":
                    cur.notes.append(plain(gtxt))
                else:
                    cur.blocks.append(dict(type="quote", text=gtxt))
            continue
        m = re.match(r"^(\s*)([-*]|\d+\.) (.+)$", s)
        if m and not s.startswith("- [ ]"):
            items = []
            ordered = m.group(2)[0].isdigit()
            while i < len(lines):
                mm = re.match(r"^(\s*)([-*]|\d+\.) (.+)$", lines[i].rstrip())
                if not mm:
                    break
                items.append((len(mm.group(1)) // 2, mm.group(3).strip()))
                i += 1
            cur.blocks.append(dict(type="list", ordered=ordered, items=items))
            continue
        if s.strip():
            cur.blocks.append(classify_para(s.strip()))
        i += 1
    return [sec for sec in sections if sec.id != "X"]


def block_height(b, lvl, width, cfg):
    tbl, txt, code, call, card = LEVELS[lvl]
    t = b["type"]
    if t == "table":
        return table_height(b, tbl, col_widths(b, width, cfg.get("col_w")))
    if t == "para":
        return para_height(plain(b["text"]), txt, width)
    if t == "heading":
        return 0.34
    if t == "callout":
        return para_height(plain(b["text"]), call, width - 0.45) + 0.2
    if t == "quote":
        return para_height(plain(b["text"]), call + 1, width - 0.45) + 0.2
    if t == "answer":
        return para_height(plain(b["text"]), txt - 1, width - 0.3) + 0.06
    if t == "code":
        n = sum(text_lines(l, code, width - 0.3, mono=True) for l in b["lines"])
        return n * code * 1.25 / 72 + 0.28
    if t == "list":
        if cfg.get("cards") and b["ordered"]:
            n = len(b["items"])
            cw = (width - GAP * (n - 1)) / n
            hmax = 0
            for _, it in b["items"]:
                ti, de = split_card(it)
                hmax = max(hmax, 0.62 + para_height(ti, card + 1.5, cw - 0.3)
                           + para_height(plain(de), card, cw - 0.3) + 0.25)
            return hmax
        h = 0
        for lvl_, it in b["items"]:
            h += para_height(plain(it), txt, width - 0.3 - 0.25 * lvl_, after_pt=3)
        return h
    if t == "caption":
        return 0.3
    if t == "b03":
        return B03_HEIGHT
    if t == "diagram":
        return b["h"]
    return 0.0



# ═════════════════════════════════════════════════════════════════════════════
# Block renderers  (each returns the height consumed)
# ═════════════════════════════════════════════════════════════════════════════
def draw_table(slide, b, x, y, w, size, cfg):
    widths = col_widths(b, w, cfg.get("col_w"))
    rows = ([b["header"]] if b["header"] else []) + b["rows"]
    nrow, ncol = len(rows), b["ncol"]
    h = table_height(b, size, widths)
    gs = slide.shapes.add_table(nrow, ncol, Inches(x), Inches(y), Inches(w), Inches(h))
    tbl = gs.table
    tblPr = tbl._tbl.tblPr
    sid = tblPr.find(qn("a:tableStyleId"))
    if sid is not None:
        tblPr.remove(sid)
    tblPr.set("firstRow", "0")
    tblPr.set("bandRow", "0")
    for j, cw in enumerate(widths):
        tbl.columns[j].width = Inches(cw)
    for i, r in enumerate(rows):
        is_head = b["header"] is not None and i == 0
        tbl.rows[i].height = Inches(size * 1.2 / 72 + 0.1)
        for j, c in enumerate(r):
            cell = tbl.cell(i, j)
            set_cell_border(cell)
            cell.fill.solid()
            cell.fill.fore_color.rgb = rgb(TBL_HEAD if is_head else (TBL_ROW_A if i % 2 else TBL_ROW_B))
            cell.margin_left = cell.margin_right = Inches(0.07)
            cell.margin_top = cell.margin_bottom = Inches(0.04)
            cell.vertical_anchor = MSO_ANCHOR.TOP
            tf = cell.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            first_col_label = (b["header"] is None and j == 0)
            add_runs(p, parse_inline(c), size, base_bold=is_head or first_col_label,
                     bold_color=None if is_head else ORANGE,
                     color=WHITE if not first_col_label else MUTED)
    return h


def draw_para(slide, b, x, y, w, size):
    h = para_height(plain(b["text"]), size, w)
    _, tf = textbox(slide, x, y, w, h)
    add_runs(tf.paragraphs[0], parse_inline(b["text"]), size)
    return h


def draw_heading(slide, b, x, y, w):
    _, tf = textbox(slide, x, y + 0.04, w, 0.3)
    add_runs(tf.paragraphs[0], [(b["text"], {})], 13, color=ORANGE, font=TITLE_FONT)
    return 0.34


def draw_callout(slide, b, x, y, w, size, accent=ORANGE, italic=False):
    h = para_height(plain(b["text"]), size, w - 0.45) + 0.2
    rect(slide, x, y, w, h, CARD_BG)
    rect(slide, x, y, 0.07, h, accent)
    _, tf = textbox(slide, x + 0.25, y + 0.1, w - 0.4, h - 0.2, MSO_ANCHOR.MIDDLE)
    add_runs(tf.paragraphs[0], parse_inline(b["text"]), size, bold_color=accent, italic=italic)
    return h


def draw_answer(slide, b, x, y, w, size):
    h = para_height(plain(b["text"]), size, w - 0.3) + 0.06
    _, tf = textbox(slide, x + 0.3, y, w - 0.3, h)
    add_runs(tf.paragraphs[0], parse_inline(b["text"]), size, color=GREEN, bold_color=GREEN)
    return h


def draw_code(slide, b, x, y, w, size):
    n = sum(text_lines(l, size, w - 0.3, mono=True) for l in b["lines"])
    h = n * size * 1.25 / 72 + 0.28
    s = rect(slide, x, y, w, h, CODE_BG, line=TBL_LINE, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.03)
    tf = s.text_frame
    tf.vertical_anchor = MSO_ANCHOR.TOP
    for k, line in enumerate(b["lines"]):
        p = tf.paragraphs[0] if k == 0 else tf.add_paragraph()
        p.space_after = Pt(0)
        p.alignment = PP_ALIGN.LEFT
        r = p.add_run()
        r.text = line if line else " "
        r.font.name = TITLE_FONT
        r.font.size = Pt(size)
        r.font.color.rgb = rgb(WHITE)
    return h


def draw_list(slide, b, x, y, w, size):
    h_total = 0
    for lvl, it in b["items"]:
        h_total += para_height(plain(it), size, w - 0.3 - 0.25 * lvl, after_pt=3)
    _, tf = textbox(slide, x, y, w, h_total)
    for k, (lvl, it) in enumerate(b["items"]):
        p = tf.paragraphs[0] if k == 0 else tf.add_paragraph()
        p.space_after = Pt(3)
        if b["ordered"]:
            set_bullet(p, lvl, char=f"{k + 1}.")
            # numbered: use autonumber for fidelity
            pPr = p._p.get_or_add_pPr()
            bc = pPr.find(qn("a:buChar"))
            pPr.remove(bc)
            an = etree.SubElement(pPr, qn("a:buAutoNum"))
            an.set("type", "arabicPeriod")
        else:
            set_bullet(p, lvl)
        add_runs(p, parse_inline(it), size)
    return h_total


def draw_cards(slide, b, x, y, w, size):
    n = len(b["items"])
    cw = (w - GAP * (n - 1)) / n
    hmax = 0
    metas = []
    for _, it in b["items"]:
        ti, de = split_card(it)
        h = 0.62 + para_height(ti, size + 1.5, cw - 0.3) + para_height(plain(de), size, cw - 0.3) + 0.25
        metas.append((ti, de))
        hmax = max(hmax, h)
    for k, (ti, de) in enumerate(metas):
        cx = x + k * (cw + GAP)
        rect(slide, cx, y, cw, hmax, CARD_BG)
        tile = rect(slide, cx + 0.15, y + 0.15, 0.42, 0.42, ACCENTS[k % len(ACCENTS)])
        tf = tile.text_frame
        tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
        tf.vertical_anchor = MSO_ANCHOR.MIDDLE
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        r = p.add_run()
        r.text = f"{k + 1:02d}"
        r.font.name = TITLE_FONT
        r.font.size = Pt(11)
        r.font.bold = True
        r.font.color.rgb = rgb(NAVY)
        _, tf2 = textbox(slide, cx + 0.15, y + 0.7, cw - 0.3, hmax - 0.85)
        p = tf2.paragraphs[0]
        p.space_after = Pt(5)
        add_runs(p, [(ti, {})], size + 1.5, base_bold=True)
        if de:
            p2 = tf2.add_paragraph()
            add_runs(p2, parse_inline(de), size, color=MUTED)
    return hmax


B03_LAYERS = [
    ("추론 계층", "모델 카탈로그 (18사 100+) · 추론 프로필 (Geo / Global / 앱) · 서비스 티어 (4단) · 프롬프트 캐싱 · 배치 추론"),
    ("안전 계층", "Guardrails (6 정책) · Data retention mode · 모델 호출 로깅 → CloudWatch / S3 · 남용 탐지"),
    ("지식 계층", "Knowledge Bases (RAG) · 임베딩 모델 · 리랭킹"),
    ("에이전트 계층", "AgentCore (Runtime · Gateway · Memory · Identity · Observability …)"),
    ("커스터마이징", "SFT · RFT · Distillation · Custom Model Import"),
    ("운영 기반", "IAM · CloudTrail · CloudWatch · PrivateLink · KMS · Quotas"),
]
B03_HEIGHT = 3.75


def _label(slide, x, y, w, h, spans, size, color=WHITE, font=BODY_FONT, align=PP_ALIGN.LEFT,
           anchor=MSO_ANCHOR.TOP, bold=False):
    _, tf = textbox(slide, x, y, w, h, anchor)
    p = tf.paragraphs[0]
    p.alignment = align
    add_runs(p, spans, size, color=color, font=font, base_bold=bold)


def draw_b03(slide, x, y, w):
    # app bar
    rect(slide, x, y, w, 0.42, CARD_BG)
    _, tf = textbox(slide, x + 0.2, y, w - 0.4, 0.42, MSO_ANCHOR.MIDDLE)
    add_runs(tf.paragraphs[0], [("내 애플리케이션 (Fargate / Lambda / 노트북)", {}),
                                ("      ↓  SigV4  또는  Bedrock API 키", {})], 12, bold_color=None)
    tf.paragraphs[0].runs[0].font.bold = True
    tf.paragraphs[0].runs[1].font.color.rgb = rgb(MUTED)
    y += 0.42 + 0.1
    # endpoint band
    eh = 1.0
    rect(slide, x, y, w, eh, CODE_BG, line=TBL_LINE)
    rect(slide, x, y, 0.07, eh, ORANGE)
    _label(slide, x + 0.2, y + 0.08, 1.2, 0.3, [("엔드포인트", {})], 11, color=ORANGE, font=TITLE_FONT)
    half = (w - 0.4) / 2
    for k, (ep, apis) in enumerate([
        ("bedrock-runtime.{region}.amazonaws.com  (권장)", "Invoke · Converse · Chat Completions · Responses · Messages"),
        ("bedrock-mantle.{region}.api.aws", "Responses · Chat Completions · Messages  (+ 서버측 툴 · 비동기)"),
    ]):
        cx = x + 0.2 + k * half + (1.3 if k == 0 else 0)
        cw = half - (1.3 if k == 0 else 0)
        _label(slide, cx, y + 0.1, cw, 0.3, [(ep, {})], 11, color=BLUE, font=TITLE_FONT)
        _label(slide, cx, y + 0.5, cw, 0.4, [(apis, {})], 11)
    y += eh + 0.1
    # 3 x 2 layer cards
    cols, rows = 3, 2
    cw = (w - GAP * (cols - 1)) / cols
    ch = 0.9
    for i, (name, desc) in enumerate(B03_LAYERS):
        cx = x + (i % cols) * (cw + GAP)
        cy = y + (i // cols) * (ch + GAP)
        rect(slide, cx, cy, cw, ch, CARD_BG)
        rect(slide, cx, cy, cw, 0.06, ACCENTS[i % len(ACCENTS)])
        _label(slide, cx + 0.15, cy + 0.14, cw - 0.3, 0.3, [(name, {})], 11.5,
               color=ACCENTS[i % len(ACCENTS)], font=TITLE_FONT)
        _label(slide, cx + 0.15, cy + 0.44, cw - 0.3, ch - 0.5, [(desc, {})], 10.5)
    return B03_HEIGHT


def draw_block(slide, b, lvl, x, y, w, cfg):
    tbl, txt, code, call, card = LEVELS[lvl]
    t = b["type"]
    if t == "table":
        return draw_table(slide, b, x, y, w, tbl, cfg)
    if t == "para":
        return draw_para(slide, b, x, y, w, txt)
    if t == "heading":
        return draw_heading(slide, b, x, y, w)
    if t == "callout":
        return draw_callout(slide, b, x, y, w, call)
    if t == "quote":
        return draw_callout(slide, b, x, y, w, call + 1, accent=BLUE, italic=True)
    if t == "answer":
        return draw_answer(slide, b, x, y, w, txt - 1)
    if t == "code":
        return draw_code(slide, b, x, y, w, code)
    if t == "list":
        if cfg.get("cards") and b["ordered"]:
            return draw_cards(slide, b, x, y, w, card)
        return draw_list(slide, b, x, y, w, txt)
    if t == "b03":
        return draw_b03(slide, x, y, w)
    if t == "diagram":
        return b["fn"](slide, x, y, w)
    if t == "caption":
        _, tf = textbox(slide, x, y, w, 0.3)
        add_runs(tf.paragraphs[0], [(b["text"], {})], 10, color=MUTED)
        return 0.3
    return 0


# ═════════════════════════════════════════════════════════════════════════════
# Slide builders
# ═════════════════════════════════════════════════════════════════════════════
class Deck:
    def __init__(self, template, md_dir):
        self.prs = Presentation(template)
        self.md_dir = md_dir
        sld = self.prs.slides._sldIdLst
        for s in list(sld):
            self.prs.part.drop_rel(s.rId)
            sld.remove(s)
        self.layouts = self.prs.slide_masters[0].slide_layouts
        self.warnings = []
        self.debug = []   # (slide_no, section, level, estimated_bottom)

    # -- generic chrome -------------------------------------------------------
    def new_slide(self, layout_idx, sec_id, title, dark=True, title_size=None):
        slide = self.prs.slides.add_slide(self.layouts[layout_idx])
        strip_placeholders(slide, keep=(0,))
        t = slide.shapes.title
        t.left, t.top, t.width, t.height = Inches(X0), Inches(0.42), Inches(12.2), Inches(0.9)
        tf = t.text_frame
        tf.vertical_anchor = MSO_ANCHOR.TOP
        tf.word_wrap = True
        p = tf.paragraphs[0]
        r = p.add_run()
        r.text = title
        size = title_size or (24 if em_len(title, mono=True) * 24 / 72 <= 12.0 else 21)
        r.font.size = Pt(size)
        if sec_id:
            _, tf2 = textbox(slide, X0, 0.16, 3, 0.25)
            add_runs(tf2.paragraphs[0], [(sec_id, {})], 10, color=ORANGE, font=TITLE_FONT)
        return slide

    def set_notes(self, slide, sec, extra=None):
        parts = [f"[{sec.id}] {sec.title}"] + sec.notes + (extra or [])
        slide.notes_slide.notes_text_frame.text = "\n\n".join(parts)

    # -- special slides -------------------------------------------------------
    def cover(self, sec):
        slide = self.prs.slides.add_slide(self.layouts[L_COVER])
        hero = next(b for b in sec.blocks if b["type"] == "hero")
        paras = [b for b in sec.blocks if b["type"] == "para"]
        for ph in slide.placeholders:
            idx = ph.placeholder_format.idx
            if idx == 0:
                ph.left, ph.top, ph.width, ph.height = Inches(0.32), Inches(1.1), Inches(6.8), Inches(1.5)
                ph.text_frame.text = hero["text"].replace("위한 AWS", "위한\nAWS")
                ph.text_frame.paragraphs[0].runs[0].font.size = Pt(30)
            elif idx == 1:
                ph.left, ph.top, ph.width, ph.height = Inches(0.32), Inches(2.75), Inches(6.8), Inches(2.2)
                tf = ph.text_frame
                tf.word_wrap = True
                tf.vertical_anchor = MSO_ANCHOR.TOP
                p = tf.paragraphs[0]
                add_runs(p, [(plain(paras[0]["text"]), {})], 16, color=ORANGE, base_bold=True)
                p.space_after = Pt(14)
                p2 = tf.add_paragraph()
                add_runs(p2, [(plain(paras[1]["text"]), {})], 12, color=WHITE)
            elif idx == 10:
                ph.text_frame.text = "2026-09"
        self.set_notes(slide, sec)

    def divider(self, sec):
        slide = self.prs.slides.add_slide(self.layouts[L_DIVIDER])
        t = slide.shapes.title
        t.left, t.top, t.width, t.height = Inches(1.17), Inches(1.5), Inches(10), Inches(2.2)
        tf = t.text_frame
        tf.text = ""
        p = tf.paragraphs[0]
        add_runs(p, [("Part 2", {})], 20, color=ORANGE, font=TITLE_FONT)
        p2 = tf.add_paragraph()
        add_runs(p2, [("Amazon Bedrock 교육", {})], 36, font=TITLE_FONT)
        _, tf2 = textbox(slide, 1.17, 4.0, 10, 1.4)
        add_runs(tf2.paragraphs[0],
                 [("운영진 교육 세션 · 개요 → 정의 → 구조 → 모델 타입 → 호출 → 추론 옵션 → Guardrails → "
                   "Knowledge Bases → AgentCore → 커스터마이징 → 데이터 보호 → 비용 → 문제 풀이", {})],
                 13, color=MUTED)
        p3 = tf2.add_paragraph()
        p3.space_before = Pt(8)
        add_runs(p3, [("내용은 2026-09-18 AWS 공식 문서 기준 · 각 장 끝 “Perch Care에서는 →” 이 Part 1로 되돌아가는 고리", {})],
                 12, color=WHITE)
        self.set_notes(slide, sec)

    def thanks(self, sec):
        slide = self.prs.slides.add_slide(self.layouts[L_QUOTE_GREEN])
        t = slide.shapes.title
        t.text_frame.text = "감사합니다"
        t.text_frame.paragraphs[0].runs[0].font.size = Pt(48)
        para = next((b for b in sec.blocks if b["type"] == "para"), None)
        if para:
            _, tf = textbox(slide, 0.32, 4.9, 11, 0.6)
            add_runs(tf.paragraphs[0], [(plain(para["text"]), {})], 16, color=NAVY, font=TITLE_FONT)
        self.set_notes(slide, sec)

    def quote_slide(self, sec, cfg):
        slide = self.prs.slides.add_slide(self.layouts[L_QUOTE_DARK])
        _, tf0 = textbox(slide, X0, 0.16, 3, 0.25)
        add_runs(tf0.paragraphs[0], [(sec.id, {})], 10, color=ORANGE, font=TITLE_FONT)
        hero = next((b for b in sec.blocks if b["type"] in ("hero", "quote")), None)
        t = slide.shapes.title
        t.left, t.top, t.width, t.height = Inches(0.32), Inches(0.75), Inches(12.4), Inches(2.1)
        tf = t.text_frame
        tf.word_wrap = True
        tf.vertical_anchor = MSO_ANCHOR.TOP
        p = tf.paragraphs[0]
        size = 28 if hero["type"] == "hero" else 20
        add_runs(p, parse_inline(hero["text"]), size, font=TITLE_FONT, bold_color=ORANGE)
        rest = [b for b in sec.blocks if b is not hero]
        y = 3.05
        for b in rest:
            if b["type"] == "list" and not b["ordered"]:
                # reference links → one muted line
                names = " · ".join(plain(it) for _, it in b["items"])
                h = para_height(names, 9, X1 - X0)
                _, tfr = textbox(slide, X0, y, X1 - X0, h)
                add_runs(tfr.paragraphs[0], [(names, {})], 9, color=MUTED)
                y += h + GAP
                continue
            h = draw_block(slide, b, 1, X0, y, X1 - X0, cfg)
            y += h + GAP
        if y > Y1 + 0.1:
            self.warnings.append(f"{sec.id}: quote slide overflow y={y:.2f}")
        self.set_notes(slide, sec)

    def image_slide(self, sec, title, img, caption, notes_extra=None):
        slide = self.new_slide(L_WHITE, sec.id, title)
        # dark title text on white layout is inherited from the layout (tx1)
        for r in slide.shapes.title.text_frame.paragraphs[0].runs:
            r.font.color.rgb = rgb(NAVY)
        path = os.path.normpath(os.path.join(self.md_dir, img["path"]))
        from PIL import Image
        with Image.open(path) as im:
            iw, ih = im.size
        area_w, area_h = X1 - X0, (6.55 if caption else 6.75) - Y0
        scale = min(area_w / iw, area_h / ih)
        w, h = iw * scale, ih * scale
        x = X0 + (area_w - w) / 2
        slide.shapes.add_picture(path, Inches(x), Inches(Y0), Inches(w), Inches(h))
        if caption:
            _, tf = textbox(slide, X0, 6.55, area_w, 0.3)
            add_runs(tf.paragraphs[0], [(caption, {})], 10, color="555555")
        self.set_notes(slide, sec, notes_extra)

    # -- content slides -------------------------------------------------------
    def content(self, sec, cfg):
        blocks = [b for b in sec.blocks if b["type"] not in ("image", "caption")]
        image = next((b for b in sec.blocks if b["type"] == "image"), None)
        caption = next((b["text"] for b in sec.blocks if b["type"] == "caption"), None)
        if image and not blocks:
            self.image_slide(sec, sec.title, image, caption)
            return
        width = cfg.get("max_w", X1 - X0)
        layout = cfg.get("layout", L_DARK)

        def total(lvl, bl):
            return sum(block_height(b, lvl, width, cfg) for b in bl) + GAP * (len(bl) - 1)

        chosen = None
        has_diagram = any(bk["type"] in ("diagram", "b03") for bk in blocks)
        min_level = MIN_LEVEL + 1 if has_diagram else MIN_LEVEL   # a diagram carries the slide → allow 10pt text
        for lvl in range(min_level + 1):
            if total(lvl, blocks) <= Y1 - Y0:
                chosen = lvl
                break
        if chosen is not None:
            slide = self.new_slide(layout, sec.id, sec.title)
            y = Y0
            for b in blocks:
                y += draw_block(slide, b, chosen, X0, y, width, cfg) + GAP
            self.set_notes(slide, sec)
            self.debug.append((len(self.prs.slides._sldIdLst), sec.id, chosen, round(y - GAP, 2)))
        else:
            self.split_content(sec, cfg, blocks, layout, width, total)
        if image:
            self.image_slide(sec, f"{sec.title} — 구성도", image, caption, ["(앞 슬라이드의 구성도)"])

    def split_content(self, sec, cfg, blocks, layout, width, total):
        """Split a section over several slides. Headings stay with the block after them;
        a quiz answer stays with its question + options. Two-page splits are balanced."""
        units, i = [], 0
        while i < len(blocks):
            b = blocks[i]
            if b["type"] == "heading" and i + 1 < len(blocks):
                units.append([b, blocks[i + 1]])
                i += 2
            else:
                units.append([b])
                i += 1
        merged = []
        for u in units:
            if u[0]["type"] == "answer" and merged:
                take = []
                while merged and len(take) < 2 and merged[-1][-1]["type"] != "answer":
                    take.insert(0, merged.pop())
                merged.append(sum(take, []) + u)
            else:
                merged.append(u)
        units = merged
        cap = Y1 - Y0

        def flat(us):
            return [b for u in us for b in u]

        pages = None
        for lvl in range(len(LEVELS)):
            # balanced two-page cut at the largest size that fits both pages
            best = None
            for cut in range(1, len(units)):
                h1, h2 = total(lvl, flat(units[:cut])), total(lvl, flat(units[cut:]))
                if h1 <= cap and h2 <= cap and (best is None or abs(h1 - h2) < best[0]):
                    best = (abs(h1 - h2), cut)
            if best:
                pages, level = [units[:best[1]], units[best[1]:]], lvl
                break
        if pages is None:
            level = SPLIT_LEVEL
            pages, cur = [], []
            for u in units:
                if cur and total(level, flat(cur + [u])) > cap:
                    pages.append(cur)
                    cur = []
                cur.append(u)
            pages.append(cur)
        self.warnings.append(f"{sec.id}: split into {len(pages)} slides at level {level}")
        for k, page in enumerate(pages):
            title = sec.title if k == 0 else f"{sec.title} (계속)"
            slide = self.new_slide(layout, sec.id, title)
            lvl = level
            if total(lvl, flat(page)) > cap:
                lvl = len(LEVELS) - 1
                if total(lvl, flat(page)) > cap:
                    self.warnings.append(f"{sec.id} p{k + 1}: still overflowing ({total(lvl, flat(page)):.2f}in)")
            y = Y0
            for b in flat(page):
                y += draw_block(slide, b, lvl, X0, y, width, cfg) + GAP
            self.set_notes(slide, sec, None if k == 0 else ["(이어서)"])
            self.debug.append((len(self.prs.slides._sldIdLst), sec.id, lvl, round(y - GAP, 2)))

    def build(self, sections):
        for sec in sections:
            cfg = CFG.get(sec.id, {})
            if sec.id == "B03":
                sec.blocks = [dict(type="b03") if b["type"] == "code" else b for b in sec.blocks]
            deck_diagrams.augment(sec)
            kind = cfg.get("kind")
            if sec.id == "P2":
                self.divider(sec)
            elif kind == "cover":
                self.cover(sec)
            elif kind == "thanks":
                self.thanks(sec)
            elif kind == "quote":
                self.quote_slide(sec, cfg)
            else:
                self.content(sec, cfg)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--md", default=DEFAULT_MD)
    ap.add_argument("--template", default=DEFAULT_TPL)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--debug-json", default=None, help="write per-slide size level / estimated bottom")
    args = ap.parse_args()
    with open(args.md, encoding="utf-8") as f:
        sections = parse_sections(f.read())
    deck = Deck(args.template, os.path.dirname(os.path.abspath(args.md)))
    deck.build(sections)
    # the template was saved in Slide Master view; make the deck open in Normal view
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
    return 0


if __name__ == "__main__":
    sys.exit(main())
