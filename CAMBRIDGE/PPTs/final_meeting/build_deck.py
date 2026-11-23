"""Final meeting with Iman (24/11/2026): short summary of the visit.

Same look as the earlier meetings: master of the UVSQ follow-up deck, title and closing slides as in the
17/09 and 01/10 decks (Times New Roman), section titles in Helvetica 24 (accent colour), Arial labels.
Run from this folder after make_assets.py: py -3.14 build_deck.py
"""
from pathlib import Path

from lxml import etree
from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.dml import MSO_THEME_COLOR
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

# ---- hyperparameters --------------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
CAM = HERE.parents[1]
A = HERE / "assets"
TEMPLATE = CAM / "PPTs/2026-11-03 UVSQ Follow-up Meeting.pptx"
OUTPUT = CAM / "PPTs/2026-11-24 Final meeting - Visit summary.pptx"
DATE = "24/11/2026"
AUTHOR = "Kevin Jose ACUNA CONDORI"
TITLE_FONT, BODY_FONT, COVER_FONT = "Helvetica", "Arial", "Times New Roman"
AUTHOR_BLUE = RGBColor(0x29, 0x77, 0xA0)
RED = RGBColor(0xFF, 0x00, 0x00)
DARK = RGBColor(0x40, 0x40, 0x40)
LINE_GREY = RGBColor(0xBF, 0xBF, 0xBF)
# ------------------------------------------------------------------------------------------------


def color(font, c):
    if c == "accent":
        font.color.theme_color = MSO_THEME_COLOR.ACCENT_1
        font.color.brightness = 0.4
    elif c == "grey":
        font.color.theme_color = MSO_THEME_COLOR.TEXT_1
        font.color.brightness = 0.5
    elif isinstance(c, RGBColor):
        font.color.rgb = c


def text(slide, x, y, w, h, paras, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, space_after=0, bullets=()):
    """paras: list of paragraphs, each a list of runs (text, size, {bold, italic, color, font, sup});
    bullets: indices of the paragraphs drawn with a dash."""
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    for i, runs in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        p.space_after = Pt(space_after)
        for t, size, *opt in runs:
            o = opt[0] if opt else {}
            r = p.add_run()
            r.text = t
            f = r.font
            f.size = Pt(size)
            f.name = o.get("font", BODY_FONT)
            f.bold = o.get("bold", False)
            f.italic = o.get("italic", False)
            color(f, o.get("color"))
            if o.get("sup"):
                f._rPr.set("baseline", "30000")
        if i in bullets:
            ppr = p._p.get_or_add_pPr()
            ppr.set("marL", str(Inches(0.25)))
            ppr.set("indent", str(-Inches(0.25)))
            etree.SubElement(ppr, qn("a:buFont"), typeface="Arial")
            etree.SubElement(ppr, qn("a:buChar"), char="-")
    return tb


def title(slide, key, rest=""):
    runs = [(key, 24, {"bold": True, "color": "accent", "font": TITLE_FONT})]
    if rest:
        runs.append(("  " + rest, 24, {"font": TITLE_FONT}))
    text(slide, 0, 0, 13.0, 0.55, [runs])


def picture(slide, path, x, y, w=None, h=None, align="center", valign="center"):
    """Picture fitted inside the (x, y, w, h) box [in], keeping its aspect ratio."""
    iw, ih = Image.open(path).size
    s = min(w / iw, h / ih) if (w and h) else ((w / iw) if w else (h / ih))
    pw, ph = iw * s, ih * s
    bw, bh = (w or pw), (h or ph)
    px = x + {"left": 0, "center": (bw - pw) / 2, "right": bw - pw}[align]
    py = y + {"top": 0, "center": (bh - ph) / 2, "bottom": bh - ph}[valign]
    return slide.shapes.add_picture(str(path), Inches(px), Inches(py), Inches(pw), Inches(ph))


def outline(shape, rgb=LINE_GREY, width=0.75):
    shape.line.color.rgb = rgb
    shape.line.width = Pt(width)


def line(slide, x1, y1, x2, y2, rgb=RED, width=1.5, head=False):
    c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    c.line.color.rgb = rgb
    c.line.width = Pt(width)
    if head:
        etree.SubElement(c.line._get_or_add_ln(), qn("a:tailEnd"), type="triangle")
    return c


def mark(slide, shape, x, y, w, h, rgb=RED, width=1.5):
    """Outline without fill (ellipse or rounded rectangle) around a detail of a photo."""
    s = slide.shapes.add_shape(shape, Inches(x), Inches(y), Inches(w), Inches(h))
    s.fill.background()
    outline(s, rgb, width)
    s.shadow.inherit = False
    return s


def tag(slide, x, y, w, t, h=0.34, size=14):
    """Label of a photo as in the annotated testbed figure of the paper: white box, red border, serif text."""
    s = mark(slide, MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h, RED, 1.25)
    s.fill.solid()
    s.fill.fore_color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    tf = s.text_frame
    tf.word_wrap = False
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    for side in ("margin_left", "margin_right", "margin_top", "margin_bottom"):
        setattr(tf, side, Inches(0.03))
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    r = p.add_run()
    r.text = t
    r.font.size = Pt(size)
    r.font.name = COVER_FONT
    r.font.color.rgb = RGBColor(0, 0, 0)
    return s


def cover(prs, heading, sub=None, size=20):
    """Title / closing slide of the 17/09 and 01/10 decks."""
    s = prs.slides.add_slide(BLANK)
    paras = [[(heading, size, {"bold": True, "font": COVER_FONT})]]
    if sub:
        paras.append([(sub, 18, {"font": COVER_FONT})])
    bottom = 4.55 if size > 30 else 4.15             # bottom of the title box in those decks
    text(s, 1.0, bottom - 1.3, 11.33, 1.3, paras, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.BOTTOM,
         space_after=6)
    text(s, 1.0, 4.82, 11.33, 0.37, [[(AUTHOR, 16, {"font": COVER_FONT, "color": AUTHOR_BLUE})]],
         align=PP_ALIGN.CENTER)
    text(s, 1.0, 5.1, 11.33, 0.37, [[(DATE, 16, {"font": COVER_FONT})]], align=PP_ALIGN.CENTER)


# ---- slides -----------------------------------------------------------------------------------
def slide_title(prs):
    cover(prs, "Single-Source Single-PD 3D Optical Wireless Positioning", "Summary of the visit")


def slide_paper(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "MANUSCRIPT", "IEEE TIM")
    picture(s, A / "testbed_annotated.png", 0.4, 0.7, h=6.6)
    text(s, 5.2, 0.75, 7.8, 0.95, [[(
        "3-D Visible Light Positioning With a Single LED and a Single Reorientable Photodiode: "
        "Bounds, Calibration, and Experimental Validation", 16, {"italic": True, "color": DARK})]])
    picture(s, A / "paper_cdf.png", 5.2, 1.85, w=5.6)
    text(s, 5.2, 5.85, 7.8, 1.5, [
        [("3-D position, height included, from one LED and one reoriented PD", 16)],
        [("Mean error 3.7 cm on the grid (D2) and 4.1 cm live (D3)", 16)],
        [("LED model calibrated with 9 points, no training data", 16)],
    ], space_after=4, bullets=(0, 1, 2))


def slide_database(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "DATABASE", "D1, D2, D3 to be published on Zenodo (in progress)")
    cols = (("d1_heatmaps.png", "D1", "Flat PD, 141 × 141 grid (10 mm)", "19,881 records", False),
            ("d2_grid.png", "D2", "5 × 5 grid at 5 heights, K = 10", "1,250 records", False),
            ("demo_ui.png", "D3", "131 random positions, K = 5", "655 records (live demo)", True))
    for i, (img, name, desc, n, framed) in enumerate(cols):
        x = 0.4 + i * 4.32
        p = picture(s, A / img, x, 0.85, w=4.0, h=3.75, valign="bottom")
        if framed:
            outline(p)
        text(s, x, 4.75, 4.0, 0.9, [[(name + "  ", 16, {"bold": True}), (desc, 16)], [(n, 16)]],
             space_after=2)
    text(s, 0.4, 6.05, 12.5, 1.0, [
        [("Every record holds the four LEDs (300 / 500 / 700 / 900 kHz) and the raw waveform.", 14,
          {"color": DARK})],
        [("The data also revealed a gantry Z-axis fault (now fixed) and an LED tilted by about 6°.", 14,
          {"color": DARK})],
    ], space_after=2)


def slide_software(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "SOFTWARE", "Database acquisition and digital twin")
    w = 6.15
    shot = picture(s, A / "dbacq_ui.png", 0.35, 0.85, w=w)
    outline(shot)
    vh = w * 1072 / 1920
    mv = s.shapes.add_movie(str(A / "digital_twin.mp4"), Inches(6.85), Inches(0.85), Inches(w), Inches(vh),
                            poster_frame_image=str(A / "digital_twin_poster.png"), mime_type="video/mp4")
    outline(mv)
    yb = 0.85 + max(shot.height / 914400, vh) + 0.2
    text(s, 0.35, yb, w, 1.3, [
        [("Database acquisition tool", 16, {"bold": True})],
        [("Gantry + MTRS + oscilloscope from the browser", 14)],
        [("Simulation mode; on GitHub for the group", 14)],
    ], space_after=3, bullets=(1, 2))
    text(s, 6.85, yb, w, 1.3, [
        [("Digital twin of the testbed (web)", 16, {"bold": True})],
        [("Same models and estimator as the paper", 14)],
        [("Drones with a tilted PD", 14)],
    ], space_after=3, bullets=(1, 2))


def slide_isac(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "ISAC", "Acquisition program with the AWG (with Rizwana)")
    rw = 7.3
    picture(s, A / "isac_record.png", 0.4, 1.3, w=rw)
    k = rw / 762                                       # first pilot window / OFDM slot at crop x = 176 / 254
    green, blue = RGBColor(0x2E, 0x7D, 0x32), RGBColor(0x1F, 0x5F, 0x99)
    text(s, 0.7, 0.62, 2.7, 0.35, [[("positioning pilot (500 kHz)", 14, {"color": green})]])
    line(s, 1.9, 0.97, 0.4 + 176 * k, 1.3 + 25 * k, green, 2.0, head=True)
    text(s, 3.6, 0.62, 2.7, 0.35, [[("data (OFDM, 64-QAM)", 14, {"color": blue})]])
    line(s, 3.95, 0.97, 0.4 + 254 * k, 1.3 + 25 * k, blue, 2.0, head=True)
    picture(s, A / "isac_snr_pilot.png", 0.4, 4.2, h=2.65, align="left")
    text(s, 3.3, 4.25, 4.5, 2.6, [
        [("One waveform: 500 kHz pilot for positioning + OFDM 64-QAM for data (2.27 Mb/s)", 15)],
        [("The pilot RSS predicts the link SNR and picks the best orientation (23/11, 3 positions × 5 "
          "orientations)", 15)],
        [("Documentation in progress", 15)],
    ], space_after=6, bullets=(0, 1, 2))
    px, py, ph = 8.15, 0.7, 6.6
    pw = ph * 1536 / 2048
    outline(picture(s, A / "isac_setup.jpg", px, py, h=ph))
    X = lambda u: px + u * pw
    Y = lambda v: py + v * ph
    mark(s, MSO_SHAPE.OVAL, X(0.355), Y(0.142), 0.075 * pw, 0.045 * ph)
    tag(s, 8.35, 0.95, 0.65, "LED")
    line(s, 9.0, 1.12, X(0.355), Y(0.162))
    mark(s, MSO_SHAPE.ROUNDED_RECTANGLE, X(0.695), Y(0.765), 0.285 * pw, 0.12 * ph)
    tag(s, 10.45, 4.75, 2.45, "AWG (Keysight M8195A)")
    line(s, 11.7, 5.09, 11.7, Y(0.765))
    tag(s, 8.3, 6.82, 1.95, "Acquisition program")
    line(s, 9.4, 6.82, X(0.35), Y(0.85))


def slide_collaborations(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "COLLABORATIONS")
    text(s, 0.45, 0.9, 8.1, 6.0, [
        [("In the group", 18, {"bold": True})],
        [("Rizwana: ISAC with a single LED and a single rotatable PD", 16)],
        [("Hossein: VCSEL-based positioning, first steps", 16)],
        [(" ", 12)],
        [("New contacts", 18, {"bold": True})],
        [("ProrokLab (Amanda Prorok), visit with Maxence Boels: they need a light, low-power, connected "
          "receiver on a PCB; optical positioning could help their leader-follower robot teams", 16)],
        [("Microsoft Research Cambridge (Francesca Parmigiani): I made the contact and will join the visit", 16)],
    ], space_after=8, bullets=(1, 2, 5, 6))
    pic = picture(s, A / "proroklab.png", 8.85, 2.6, w=4.15)
    text(s, 8.85, 2.65 + pic.height / 914400, 4.15, 0.6, [[
        ("PROROKLAB, ", 12, {"bold": True, "color": "grey", "font": TITLE_FONT}),
        ("Department of Computer Science and Technology, University of Cambridge", 12, {"font": TITLE_FONT})]])


def slide_next(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "NEXT STEPS")
    cols = (("drone.jpg", "PCB receiver (PD, amplifier, MCU, IMU) for robots and drones"),
            ("adt_schematic.png", "ADT + ADR: joint estimation and optimisation"),
            ("ceiling_leds.png", "Two LEDs: position and heading (3.6 cm, ~1°); a second paper with data "
                                 "already recorded"))
    for i, (img, label) in enumerate(cols):
        x = 0.45 + i * 4.3
        picture(s, A / img, x, 0.9, w=3.95, h=2.45)
        text(s, x, 3.5, 3.95, 1.1, [[(label, 16)]], align=PP_ALIGN.CENTER)
    text(s, 0.45, 4.95, 12.4, 2.2, [
        [("Keeping in touch", 18, {"bold": True})],
        [("Database (D1–D3) on Zenodo and software shared with the group", 16)],
        [("ISAC measurements with Rizwana; PCB receiver for ProrokLab", 16)],
        [("Return visit with the PCB prototype", 16)],
    ], space_after=4, bullets=(1, 2, 3))


def slide_thanks(prs):
    cover(prs, "Thank you", size=48)


def main():
    global BLANK
    prs = Presentation(str(TEMPLATE))
    ids = prs.slides._sldIdLst
    for sid in list(ids):
        prs.part.drop_rel(sid.rId)
        ids.remove(sid)
    BLANK = next(l for l in prs.slide_layouts if l.name == "Blank")
    for make in (slide_title, slide_paper, slide_database, slide_software, slide_isac, slide_collaborations,
                 slide_next, slide_thanks):
        make(prs)
    prs.save(str(OUTPUT))
    print(f"{OUTPUT} ({OUTPUT.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
