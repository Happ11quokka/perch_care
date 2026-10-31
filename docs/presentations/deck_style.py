"""Shared palette, fonts, canvas constants, measurement and drawing primitives for the
AWS deck builder (build_aws_deck.py) and its diagram module (deck_diagrams.py)."""
import math
import re

from lxml import etree
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

# ── template palette / fonts ────────────────────────────────────────────────
NAVY, WHITE = "151D25", "FFFFFF"
PINK, GREEN, PURPLE, BLUE, ORANGE = "FF57E9", "00E582", "AC5BFF", "41B3FF", "FF9900"
ACCENTS = [PINK, GREEN, PURPLE, BLUE, ORANGE]
TBL_HEAD, TBL_ROW_A, TBL_ROW_B, TBL_LINE = "2B3542", "1B252E", "151D25", "3A4550"
CODE_BG, CARD_BG, MUTED = "0E141A", "1B252E", "B8C2CC"
TITLE_FONT = "Amazon Ember Duospace"
BODY_FONT = "Amazon Ember Display"

# ── canvas (inches) ──────────────────────────────────────────────────────────
X0, X1 = 0.37, 12.96
Y0, Y1 = 1.40, 6.75
GAP = 0.12


INLINE_RE = re.compile(r"(\*\*.+?\*\*|`[^`]+`|~~.+?~~|\[[^\]]+\]\([^)]+\))")


def parse_inline(text):
    """-> list of (text, {'bold','code','strike'})"""
    out = []
    for tok in INLINE_RE.split(text):
        if not tok:
            continue
        if tok.startswith("**") and tok.endswith("**") and len(tok) > 4:
            for t, s in parse_inline(tok[2:-2]):
                out.append((t, dict(s, bold=True)))
        elif tok.startswith("`") and tok.endswith("`"):
            out.append((tok[1:-1], dict(code=True)))
        elif tok.startswith("~~") and tok.endswith("~~"):
            out.append((tok[2:-2], dict(strike=True)))
        elif tok.startswith("[") and "](" in tok:
            out.append((tok[1:tok.index("](")], {}))
        else:
            out.append((tok, {}))
    return out


def plain(text):
    return "".join(t for t, _ in parse_inline(text))


# ═════════════════════════════════════════════════════════════════════════════
# Measurement helpers (inches)
# ═════════════════════════════════════════════════════════════════════════════
def em_len(text, mono=False):
    n = 0.0
    for ch in text:
        o = ord(ch)
        if o >= 0x2E80:          # CJK / fullwidth / box drawing → ~1em
            n += 1.0
        elif ch == " ":
            n += 0.6 if mono else 0.32
        else:
            n += 0.6 if mono else 0.58
    return n * 1.08   # word-wrap inefficiency


def text_lines(text, size_pt, width_in, mono=False):
    if not text:
        return 1
    return max(1, math.ceil(em_len(text, mono) * size_pt / 72 / max(width_in, 0.3)))


def para_height(text, size_pt, width_in, mono=False, lh=1.22, after_pt=4):
    return text_lines(text, size_pt, width_in, mono) * size_pt * lh / 72 + after_pt / 72


def col_widths(block, total_w, override=None):
    ncol = block["ncol"]
    rows = ([block["header"]] if block["header"] else []) + block["rows"]
    if override:
        s = sum(override)
        return [total_w * o / s for o in override]
    weights = []
    for j in range(ncol):
        mx = max(em_len(plain(r[j])) for r in rows)
        weights.append(min(max(mx, 6), 48) ** 0.85)
    s = sum(weights)
    w = [total_w * x / s for x in weights]
    minw = 0.9
    for j in range(ncol):
        if w[j] < minw:
            deficit = minw - w[j]
            w[j] = minw
            others = [k for k in range(ncol) if w[k] > minw + 0.2]
            for k in others:
                w[k] -= deficit / len(others)
    return w


def table_height(block, size_pt, widths):
    rows = ([block["header"]] if block["header"] else []) + block["rows"]
    h = 0.0
    for r in rows:
        lines = max(text_lines(plain(c), size_pt, widths[j] - 0.18) for j, c in enumerate(r))
        h += lines * size_pt * 1.22 / 72 + 0.1
    return h


def split_card(item_text):
    """'**title** — desc' / '**title**: desc' -> (title, desc)"""
    m = re.match(r"^\*\*(.+?)\*\*\s*(?:[—:\-–]\s*)?(.*)$", item_text)
    if m:
        return m.group(1), m.group(2)
    return plain(item_text), ""


# ═════════════════════════════════════════════════════════════════════════════
# Drawing helpers
# ═════════════════════════════════════════════════════════════════════════════
def rgb(hexstr):
    return RGBColor.from_string(hexstr)


def add_runs(paragraph, spans, size, color=WHITE, font=BODY_FONT, bold_color=ORANGE,
             base_bold=False, italic=False):
    for text, st in spans:
        r = paragraph.add_run()
        r.text = text
        f = r.font
        f.size = Pt(size)
        f.name = TITLE_FONT if st.get("code") else font
        f.bold = base_bold or bool(st.get("bold"))
        f.italic = italic
        if st.get("code"):
            f.color.rgb = rgb(BLUE)
        elif st.get("bold") and bold_color:
            f.color.rgb = rgb(bold_color)
        else:
            f.color.rgb = rgb(color)
        if st.get("strike"):
            r._r.get_or_add_rPr().set("strike", "sngStrike")


def set_bullet(paragraph, level=0, char="•"):
    pPr = paragraph._p.get_or_add_pPr()
    ind = 0.2 if char == "•" else 0.3
    pPr.set("marL", str(int(Inches(ind + 0.28 * level))))
    pPr.set("indent", str(int(-Inches(ind))))
    bf = etree.SubElement(pPr, qn("a:buFont"))
    bf.set("typeface", "Arial")
    bc = etree.SubElement(pPr, qn("a:buChar"))
    bc.set("char", char)


def textbox(slide, x, y, w, h, anchor=MSO_ANCHOR.TOP):
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    return tb, tf


def rect(slide, x, y, w, h, fill, line=None, shape=MSO_SHAPE.RECTANGLE, radius=None):
    s = slide.shapes.add_shape(shape, Inches(x), Inches(y), Inches(w), Inches(h))
    s.fill.solid()
    s.fill.fore_color.rgb = rgb(fill)
    if line:
        s.line.color.rgb = rgb(line)
        s.line.width = Pt(0.75)
    else:
        s.line.fill.background()
    s.shadow.inherit = False
    if radius is not None and shape == MSO_SHAPE.ROUNDED_RECTANGLE:
        s.adjustments[0] = radius
    tf = s.text_frame
    tf.margin_left = tf.margin_right = Inches(0.12)
    tf.margin_top = tf.margin_bottom = Inches(0.08)
    tf.word_wrap = True
    return s


def set_cell_border(cell, color=TBL_LINE, width_pt=0.5):
    tcPr = cell._tc.get_or_add_tcPr()
    for tag in ("a:lnL", "a:lnR", "a:lnT", "a:lnB"):
        old = tcPr.find(qn(tag))
        if old is not None:
            tcPr.remove(old)
    for tag in ("a:lnL", "a:lnR", "a:lnT", "a:lnB"):
        ln = etree.SubElement(tcPr, qn(tag))
        ln.set("w", str(int(width_pt * 12700)))
        ln.set("cap", "flat")
        ln.set("cmpd", "sng")
        ln.set("algn", "ctr")
        sf = etree.SubElement(ln, qn("a:solidFill"))
        etree.SubElement(sf, qn("a:srgbClr")).set("val", color)
        etree.SubElement(ln, qn("a:prstDash")).set("val", "solid")


def remove_shape(shape):
    el = shape._element
    el.getparent().remove(el)


def strip_placeholders(slide, keep=(0,)):
    for ph in list(slide.placeholders):
        if ph.placeholder_format.idx not in keep:
            remove_shape(ph)


