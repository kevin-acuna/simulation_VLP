"""Small helper layer on top of python-pptx for the OPTI-6G template."""
import re, os
from copy import deepcopy
from lxml import etree
from PIL import Image
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from pptx.oxml.ns import qn

DARK = RGBColor(0x26, 0x26, 0x26)
BLUE = RGBColor(0x1F, 0x4E, 0x9A)
MBLUE = RGBColor(0x2F, 0x6F, 0xDB)
LBLUE = RGBColor(0xEA, 0xF1, 0xFB)
PURPLE = RGBColor(0x7B, 0x3F, 0xBF)
LPURPLE = RGBColor(0xF3, 0xEC, 0xFB)
GREEN = RGBColor(0x1E, 0x84, 0x49)
LGREEN = RGBColor(0xE6, 0xF4, 0xEA)
ORANGE = RGBColor(0xD9, 0x6C, 0x10)
LORANGE = RGBColor(0xFD, 0xF0, 0xE3)
RED = RGBColor(0xC0, 0x39, 0x2B)
GRAY = RGBColor(0x60, 0x60, 0x60)
LGRAY = RGBColor(0xF4, 0xF5, 0xF7)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

FONT = "+mj-lt"  # theme major font of the OPTI-6G template (Open Sans)
TOKEN = re.compile(r"(\*\*.+?\*\*|_\{.+?\}|\^\{.+?\})")


def rich_runs(p, text, size, color=DARK, bold=False, accent=BLUE, italic=False):
    """Add runs to paragraph p. Markup: **bold accent**, _{sub}, ^{sup}."""
    for tok in TOKEN.split(text):
        if not tok:
            continue
        r = p.add_run()
        f = r.font
        f.name = FONT
        f.size = Pt(size)
        f.bold = bold
        f.italic = italic
        f.color.rgb = color
        if tok.startswith("**") and tok.endswith("**"):
            r.text = tok[2:-2]
            f.bold = True
            f.color.rgb = accent
        elif tok.startswith("_{"):
            r.text = tok[2:-1]
            r.font._element.set("baseline", "-25000")
        elif tok.startswith("^{"):
            r.text = tok[2:-1]
            r.font._element.set("baseline", "30000")
        else:
            r.text = tok


def set_bullet(p, level=0, char="\u2022", color=BLUE, size_pct=100):
    pPr = p._p.get_or_add_pPr()
    marL = Inches(0.22 + 0.25 * level)
    pPr.set("marL", str(int(marL)))
    pPr.set("indent", str(-int(Inches(0.2))))
    for tag in ("a:buClr", "a:buSzPct", "a:buFont", "a:buNone", "a:buChar", "a:buAutoNum"):
        for e in pPr.findall(qn(tag)):
            pPr.remove(e)
    buClr = etree.SubElement(pPr, qn("a:buClr"))
    etree.SubElement(buClr, qn("a:srgbClr")).set("val", str(color))
    etree.SubElement(pPr, qn("a:buSzPct")).set("val", str(int(size_pct * 1000)))
    etree.SubElement(pPr, qn("a:buFont")).set("typeface", "Arial")
    etree.SubElement(pPr, qn("a:buChar")).set("char", char)


def no_bullet(p):
    pPr = p._p.get_or_add_pPr()
    pPr.set("marL", "0")
    pPr.set("indent", "0")
    for e in pPr.findall(qn("a:buNone")):
        pPr.remove(e)
    etree.SubElement(pPr, qn("a:buNone"))


def add_text(slide, x, y, w, h, paras, size=16, color=DARK, align=PP_ALIGN.LEFT,
             anchor=MSO_ANCHOR.TOP, space_after=4, line_spacing=1.0, bullets=False,
             margins=(0.05, 0.03, 0.05, 0.03), bold=False, italic=False, accent=BLUE, name=None):
    """paras: list of str or (str, dict) with keys level, size, color, bold, bullet, align, space_before."""
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    if name:
        tb.name = name
    tf = tb.text_frame
    tf.word_wrap = True
    tf.auto_size = None
    tf.margin_left, tf.margin_top, tf.margin_right, tf.margin_bottom = [Inches(m) for m in margins]
    tf.vertical_anchor = anchor
    first = True
    for item in paras:
        if isinstance(item, tuple):
            txt, opt = item
        else:
            txt, opt = item, {}
        p = tf.paragraphs[0] if first else tf.add_paragraph()
        first = False
        p.alignment = opt.get("align", align)
        p.space_after = Pt(opt.get("space_after", space_after))
        if "space_before" in opt:
            p.space_before = Pt(opt["space_before"])
        p.line_spacing = opt.get("line_spacing", line_spacing)
        lvl = opt.get("level", 0)
        if opt.get("bullet", bullets):
            set_bullet(p, lvl, char=opt.get("char", "\u2022" if lvl == 0 else "\u2013"),
                       color=opt.get("bullet_color", BLUE))
        else:
            no_bullet(p)
        rich_runs(p, txt, opt.get("size", size), opt.get("color", color), opt.get("bold", bold),
                  accent=opt.get("accent", accent), italic=opt.get("italic", italic))
    return tb


def img_size(path):
    with Image.open(path) as im:
        return im.size


def add_image(slide, path, x, y, w=None, h=None, align="center", valign="top"):
    """Fit image inside box (x,y,w,h) preserving aspect ratio."""
    iw, ih = img_size(path)
    ar = ih / iw
    if w is not None and h is not None:
        if w * ar <= h:
            W, H = w, w * ar
        else:
            W, H = h / ar, h
    elif w is not None:
        W, H = w, w * ar
    else:
        W, H = h / ar, h
    ox = x + {"left": 0, "center": ((w or W) - W) / 2, "right": (w or W) - W}[align]
    oy = y + {"top": 0, "middle": ((h or H) - H) / 2, "bottom": (h or H) - H}[valign]
    pic = slide.shapes.add_picture(path, Inches(ox), Inches(oy), Inches(W), Inches(H))
    return pic, (ox, oy, W, H)


def add_box(slide, x, y, w, h, fill=WHITE, line=MBLUE, line_w=1.0, shape=MSO_SHAPE.ROUNDED_RECTANGLE,
            radius=0.08, shadow=False, text=None, size=14, color=DARK, bold=False, align=PP_ALIGN.CENTER,
            anchor=MSO_ANCHOR.MIDDLE, margins=(0.08, 0.04, 0.08, 0.04), alpha=None):
    shp = slide.shapes.add_shape(shape, Inches(x), Inches(y), Inches(w), Inches(h))
    if shape == MSO_SHAPE.ROUNDED_RECTANGLE:
        shp.adjustments[0] = radius
    if fill is None:
        shp.fill.background()
    else:
        shp.fill.solid()
        shp.fill.fore_color.rgb = fill
        if alpha is not None:
            srgb = shp.fill._xPr.find(qn("a:solidFill")).find(qn("a:srgbClr"))
            etree.SubElement(srgb, qn("a:alpha")).set("val", str(int(alpha * 100000)))
    if line is None:
        shp.line.fill.background()
    else:
        shp.line.color.rgb = line
        shp.line.width = Pt(line_w)
    if not shadow:
        spPr = shp._element.spPr
        el = etree.SubElement(spPr, qn("a:effectLst"))
    tf = shp.text_frame
    tf.word_wrap = True
    tf.margin_left, tf.margin_top, tf.margin_right, tf.margin_bottom = [Inches(m) for m in margins]
    tf.vertical_anchor = anchor
    if text is not None:
        paras = text if isinstance(text, list) else [text]
        for i, item in enumerate(paras):
            txt, opt = (item if isinstance(item, tuple) else (item, {}))
            p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
            p.alignment = opt.get("align", align)
            p.space_after = Pt(opt.get("space_after", 2))
            if opt.get("bullet"):
                set_bullet(p, opt.get("level", 0), color=opt.get("bullet_color", BLUE))
            rich_runs(p, txt, opt.get("size", size), opt.get("color", color), opt.get("bold", bold),
                      accent=opt.get("accent", BLUE), italic=opt.get("italic", False))
    return shp


def add_line(slide, x1, y1, x2, y2, color=MBLUE, width=2.0, arrow_end=True, arrow_start=False, dash=None):
    ln = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    ln.line.color.rgb = color
    ln.line.width = Pt(width)
    lnxml = ln.line._get_or_add_ln()
    if dash:
        etree.SubElement(lnxml, qn("a:prstDash")).set("val", dash)
    if arrow_start:
        e = etree.SubElement(lnxml, qn("a:headEnd"))
        e.set("type", "triangle"); e.set("w", "med"); e.set("len", "med")
    if arrow_end:
        e = etree.SubElement(lnxml, qn("a:tailEnd"))
        e.set("type", "triangle"); e.set("w", "med"); e.set("len", "med")
    return ln


def add_card(slide, x, y, w, h, value, label, color=BLUE, fill=WHITE, vsize=26, lsize=12, line=None):
    shp = add_box(slide, x, y, w, h, fill=fill, line=line or color, line_w=1.25)
    tf = shp.text_frame
    tf.margin_top = Inches(0.02)
    tf.margin_bottom = Inches(0.02)
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    p.space_after = Pt(0)
    rich_runs(p, value, vsize, color, True)
    p2 = tf.add_paragraph()
    p2.alignment = PP_ALIGN.CENTER
    p2.space_after = Pt(0)
    p2.line_spacing = 0.95
    rich_runs(p2, label, lsize, DARK, False)
    return shp


def add_number_badge(slide, x, y, d, num, fill=MBLUE, size=16):
    shp = slide.shapes.add_shape(MSO_SHAPE.OVAL, Inches(x), Inches(y), Inches(d), Inches(d))
    shp.fill.solid(); shp.fill.fore_color.rgb = fill
    shp.line.fill.background()
    etree.SubElement(shp._element.spPr, qn("a:effectLst"))
    tf = shp.text_frame
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = Inches(0)
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    p = tf.paragraphs[0]; p.alignment = PP_ALIGN.CENTER
    r = p.add_run(); r.text = str(num); r.font.name = FONT; r.font.size = Pt(size); r.font.bold = True; r.font.color.rgb = WHITE
    return shp


def set_cell(cell, text, size=12, color=DARK, bold=False, fill=None, align=PP_ALIGN.LEFT,
             anchor=MSO_ANCHOR.MIDDLE, accent=BLUE, margins=(0.06, 0.03, 0.06, 0.03)):
    cell.text = ""
    tf = cell.text_frame
    tf.word_wrap = True
    cell.margin_left, cell.margin_top, cell.margin_right, cell.margin_bottom = [Inches(m) for m in margins]
    cell.vertical_anchor = anchor
    lines = text if isinstance(text, list) else [text]
    for i, t in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        p.space_after = Pt(1)
        rich_runs(p, t, size, color, bold, accent=accent)
    if fill is not None:
        cell.fill.solid()
        cell.fill.fore_color.rgb = fill


def add_table(slide, x, y, w, h, data, col_w=None, header_fill=BLUE, header_color=WHITE, size=12,
              header_size=13, zebra=(WHITE, LGRAY), first_col_bold=True, row_h=None, aligns=None):
    rows, cols = len(data), len(data[0])
    gt = slide.shapes.add_table(rows, cols, Inches(x), Inches(y), Inches(w), Inches(h))
    tbl = gt.table
    tblPr = tbl._tbl.tblPr
    for attr in ("bandRow", "firstRow"):
        tblPr.set(attr, "0")
    style = tblPr.find(qn("a:tableStyleId"))
    if style is not None:
        style.text = "{2D5ABB26-0587-4C30-8999-92F81FD0307C}"  # No Style, No Grid
    if col_w:
        for j, cw in enumerate(col_w):
            tbl.columns[j].width = Inches(cw)
    if row_h:
        for i, rh in enumerate(row_h):
            tbl.rows[i].height = Inches(rh)
    for i, row in enumerate(data):
        for j, val in enumerate(row):
            al = aligns[j] if aligns else PP_ALIGN.LEFT
            if i == 0:
                set_cell(tbl.cell(i, j), val, header_size, header_color, True, header_fill, al)
            else:
                set_cell(tbl.cell(i, j), val, size, DARK, first_col_bold and j == 0, zebra[(i - 1) % 2], al)
    return gt


def set_title(slide, text, size=30, top=None, height=None, left=None, width=None):
    t = slide.shapes.title
    t.text = ""
    tf = t.text_frame
    lines = text.split("\n")
    for i, line in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        rich_runs(p, line, size, DARK)
    if top is not None:
        t.top = Inches(top)
    if height is not None:
        t.height = Inches(height)
    if left is not None:
        t.left = Inches(left)
    if width is not None:
        t.width = Inches(width)
    return t


def remove_placeholder(slide, idx):
    for ph in list(slide.placeholders):
        if ph.placeholder_format.idx == idx:
            ph._element.getparent().remove(ph._element)


def add_footer(slide, text, num=None, y=7.03):
    if text:
        add_text(slide, 0.5, y, 10.6, 0.32, [text], size=9, color=GRAY, italic=True,
                 margins=(0.02, 0, 0.02, 0))
    if num is not None:
        add_text(slide, 12.35, y, 0.6, 0.32, [str(num)], size=10, color=GRAY, align=PP_ALIGN.RIGHT,
                 margins=(0, 0, 0.02, 0))


def add_notes(slide, text):
    slide.notes_slide.notes_text_frame.text = text


def clear_slides(prs):
    sldIdLst = prs.slides._sldIdLst
    for sldId in list(sldIdLst):
        prs.part.drop_rel(sldId.rId)
        sldIdLst.remove(sldId)
