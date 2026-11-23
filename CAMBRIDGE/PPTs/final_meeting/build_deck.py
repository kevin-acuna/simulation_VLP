"""Final meeting with Iman (24/11/2026): short summary of the visit, 7 slides.

Built on the master of the previous meetings (UVSQ follow-up deck), same title style (Helvetica 24,
accent colour) and Arial labels. Run from this folder after make_assets.py: py -3.14 build_deck.py
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
from pptx.util import Emu, Inches, Pt

# ---- hyperparameters --------------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
CAM = HERE.parents[1]
A = HERE / "assets"
TEMPLATE = CAM / "PPTs/2026-11-03 UVSQ Follow-up Meeting.pptx"
OUTPUT = CAM / "PPTs/2026-11-24 Final meeting - Visit summary.pptx"
TITLE_FONT, BODY_FONT = "Helvetica", "Arial"
RED = RGBColor(0xFF, 0x00, 0x00)
DARK = RGBColor(0x40, 0x40, 0x40)
LINE_GREY = RGBColor(0xBF, 0xBF, 0xBF)
RAY_BLUE = RGBColor(0x2F, 0x66, 0x90)
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
    """paras: list of paragraphs, each a list of runs (text, size, {bold, italic, color, font});
    bullets: indices of the paragraphs drawn as bullet points."""
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
        if i in bullets:
            ppr = p._p.get_or_add_pPr()
            ppr.set("marL", str(Inches(0.2)))
            ppr.set("indent", str(-Inches(0.2)))
            etree.SubElement(ppr, qn("a:buFont"), typeface="Arial")
            etree.SubElement(ppr, qn("a:buChar"), char="•")
    return tb


def title(slide, key, rest=""):
    runs = [(key, 24, {"bold": True, "color": "accent", "font": TITLE_FONT})]
    if rest:
        runs.append(("  " + rest, 24, {"font": TITLE_FONT}))
    text(slide, 0, 0, 13.0, 0.55, [runs])


def picture(slide, path, x, y, w=None, h=None, align="center", valign="center"):
    """Picture fitted inside the (x, y, w, h) box [in], keeping its aspect ratio."""
    iw, ih = Image.open(path).size
    if w and h:
        s = min(w / iw, h / ih)
    else:
        s = (w / iw) if w else (h / ih)
    pw, ph = iw * s, ih * s
    bw, bh = (w or pw), (h or ph)
    px = x + {"left": 0, "center": (bw - pw) / 2, "right": bw - pw}[align]
    py = y + {"top": 0, "center": (bh - ph) / 2, "bottom": bh - ph}[valign]
    return slide.shapes.add_picture(str(path), Inches(px), Inches(py), Inches(pw), Inches(ph))


def outline(shape, rgb=LINE_GREY, width=0.75):
    shape.line.color.rgb = rgb
    shape.line.width = Pt(width)


def shadow(shape, blur=8, dist=3, alpha=30):
    sppr = shape._element.spPr
    eff = etree.SubElement(sppr, qn("a:effectLst"))
    sh = etree.SubElement(eff, qn("a:outerShdw"), blurRad=str(Pt(blur)), dist=str(Pt(dist)),
                          dir="2700000", algn="tl", rotWithShape="0")
    clr = etree.SubElement(sh, qn("a:srgbClr"), val="000000")
    etree.SubElement(clr, qn("a:alpha"), val=str(alpha * 1000))


def arrow(slide, x1, y1, x2, y2, rgb=RED, width=3.0, dash=None, head=True):
    c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    c.line.color.rgb = rgb
    c.line.width = Pt(width)
    ln = c.line._get_or_add_ln()
    if dash:
        etree.SubElement(ln, qn("a:prstDash"), val=dash)
    if head:
        etree.SubElement(ln, qn("a:tailEnd"), type="triangle")
    return c


def box(slide, x, y, w, h, lines, size=14):
    s = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
    s.fill.background()
    outline(s, DARK, 1.0)
    s.shadow.inherit = False
    tf = s.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    for i, (t, bold) in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = PP_ALIGN.CENTER
        r = p.add_run()
        r.text = t
        r.font.size = Pt(size if bold else size - 2)
        r.font.bold = bold
        r.font.name = BODY_FONT
        r.font.color.rgb = RGBColor(0, 0, 0) if bold else DARK
    return s


def label(slide, x, y, w, h, t, size=14):
    """Black label in a white, slightly transparent box (used on photos)."""
    b = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
    b.fill.solid()
    b.fill.fore_color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
    etree.SubElement(b.fill._xPr.find(qn("a:solidFill")).find(qn("a:srgbClr")), qn("a:alpha"), val="88000")
    b.line.fill.background()
    b.shadow.inherit = False
    tf = b.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    for side in ("margin_left", "margin_right", "margin_top", "margin_bottom"):
        setattr(tf, side, Inches(0.04))
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    r = p.add_run()
    r.text = t
    r.font.size = Pt(size)
    r.font.name = BODY_FONT
    r.font.color.rgb = RGBColor(0, 0, 0)
    return b


def two_led_schematic(slide, x, y, h):
    """Room schematic of the paper (LED + reorientable PD) with a second LED and the two LED directions."""
    iw, ih = Image.open(A / "room_schematic.png").size
    s = h / ih                                         # inches per pixel of room_schematic.png
    picture(slide, A / "room_schematic.png", x, y, h=h)
    lw, lh = Image.open(A / "led_icon.png").size
    k = 0.55                                           # second LED drawn smaller (further away)
    disk = (91, 75)                                    # disk centre in led_icon.png
    led2 = (236, 156)                                  # where that centre goes in room_schematic.png
    slide.shapes.add_picture(str(A / "led_icon.png"), Inches(x + (led2[0] - disk[0] * k) * s),
                             Inches(y + (led2[1] - disk[1] * k) * s), Inches(lw * k * s), Inches(lh * k * s))
    pd = (307, 424)
    for tx, ty in ((459, 104), (led2[0], led2[1] + 7)):
        arrow(slide, x + pd[0] * s, y + pd[1] * s, x + tx * s, y + ty * s, RAY_BLUE, 1.75, dash="dash")


def caption(slide, x, y, w, h, s, size=14, align=PP_ALIGN.LEFT):
    return text(slide, x, y, w, h, [[(s, size)]], align=align)


# ---- slides -----------------------------------------------------------------------------------
def slide_title(prs):
    s = prs.slides.add_slide(BLANK)
    picture(s, A / "testbed_cutout.png", 7.55, 0.25, w=5.4, h=7.0)
    text(s, 0.6, 2.0, 7.0, 3.6, [
        [("VISIT SUMMARY", 36, {"bold": True, "color": "accent", "font": TITLE_FONT})],
        [("Single-LED 3-D positioning with a reorientable photodiode", 22, {"font": TITLE_FONT})],
        [(" ", 14)],
        [("Kevin Acuña-Condori", 18)],
        [("LISV, Université Paris-Saclay (UVSQ)", 14, {"color": "grey"})],
        [("Visiting PhD, LiFi R&D Centre, University of Cambridge · Sept – Nov 2026", 14, {"color": "grey"})],
    ], space_after=6)


def slide_paper(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "RESULTS", "Manuscript for IEEE TIM")
    pw, ph = 3.95, 3.95 * 11 / 8.5
    for page, dx, dy, rot in (("paper_p10.png", 1.45, 0.35, 7), ("paper_p07.png", 0.75, 0.2, 3.5),
                              ("paper_p01.png", 0.0, 0.0, 0)):
        p = s.shapes.add_picture(str(A / page), Inches(0.75 + dx), Inches(1.1 + dy), Inches(pw), Inches(ph))
        p.rotation = rot
        outline(p)
        shadow(p)
    text(s, 7.05, 1.0, 5.9, 1.2, [[(
        "3-D Visible Light Positioning With a Single LED and a Single Reorientable Photodiode: "
        "Bounds, Calibration, and Experimental Validation", 16, {"italic": True, "color": DARK})]])
    rows = (("3.7 cm", "mean 3-D error, 125 positions at 5 heights, LED at 3 m"),
            ("4.1 cm", "live, on 131 random positions"),
            ("9 points", "to calibrate the LED, no training data"))
    for i, (num, desc) in enumerate(rows):
        y = 2.65 + i * 1.25
        text(s, 7.05, y, 2.5, 0.8, [[(num, 36, {"bold": True, "color": "accent", "font": TITLE_FONT})]],
             anchor=MSO_ANCHOR.MIDDLE)
        text(s, 9.55, y, 3.45, 0.8, [[(desc, 16)]], anchor=MSO_ANCHOR.MIDDLE)
    caption(s, 7.05, 6.45, 5.9, 0.6,
            "Bounds, estimators and calibration for any photodiode response, validated on the testbed",
            size=14).text_frame.paragraphs[0].runs[0].font.color.rgb = DARK


def slide_other(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "OTHER RESULTS")
    cells = ((0.4, 0.8), (6.9, 0.8), (0.4, 4.05), (6.9, 4.05))
    cw, ih = 6.1, 2.4
    (x, y) = cells[0]
    picture(s, A / "rss_maps.png", x, y, w=cw, h=ih, align="left", valign="bottom")
    caption(s, x, y + ih + 0.1, cw, 0.8, "Database: ~24,000 measurements (position + orientation, 4 LEDs) with "
            "raw waveforms, 15 GB. Zenodo upload in progress.")
    (x, y) = cells[1]
    outline(picture(s, A / "demo_ui.png", x, y, w=cw, h=ih, align="left", valign="bottom"))
    caption(s, x, y + ih + 0.1, cw, 0.8, "Live demo: the gantry takes the receiver to random positions and each "
            "one is located in real time.")
    (x, y) = cells[2]
    two_led_schematic(s, x, y, ih)
    caption(s, x, y + ih + 0.1, cw, 0.8, "Two LEDs, directions only: position and heading with no LED power "
            "calibration (3.6 cm, ~1°).")
    (x, y) = cells[3]
    picture(s, A / "zaxis.png", x, y, w=cw, h=ih, align="left", valign="bottom")
    caption(s, x, y + ih + 0.1, cw, 0.8, "The positioning data exposed faults of the testbed: a gantry Z-axis "
            "scale error (now fixed) and an LED tilted by about 6°.")


def slide_software(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "SOFTWARE", "Database acquisition and digital twin")
    w = 6.15
    shot = picture(s, A / "dbacq_ui.png", 0.35, 0.85, w=w)
    outline(shot)
    vw, vh = w, w * 1072 / 1920
    yb = 0.85 + max(shot.height / 914400, vh) + 0.2
    text(s, 0.35, yb, w, 1.6, [
        [("Database Acquisition Tool", 16, {"bold": True})],
        [("Gantry + MTRS + oscilloscope from one browser interface", 14)],
        [("Unattended campaigns of many hours, with pause / resume", 14)],
        [("Simulation mode; shared with the group on GitHub", 14)],
    ], space_after=3, bullets=(1, 2, 3))
    mv = s.shapes.add_movie(str(A / "digital_twin.mp4"), Inches(6.85), Inches(0.85), Inches(vw), Inches(vh),
                            poster_frame_image=str(A / "digital_twin_poster.png"), mime_type="video/mp4")
    outline(mv)
    text(s, 6.85, yb, w, 1.6, [
        [("Digital twin of the testbed (web)", 16, {"bold": True})],
        [("Same LED and photodiode models and estimator as the paper", 14)],
        [("Drones with a tilted photodiode estimate their own position", 14)],
        [("Runs in the browser, with remote access", 14)],
    ], space_after=3, bullets=(1, 2, 3))


def slide_isac(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "ISAC", "Acquisition program with the AWG (with Rizwana)")
    rw = 7.3
    picture(s, A / "isac_record.png", 0.4, 1.3, w=rw)
    # labels on the record: first pilot window (green) and first OFDM slot (blue), crop pixels 176 / 254
    k = rw / 762
    green, blue = RGBColor(0x2E, 0x7D, 0x32), RGBColor(0x1F, 0x5F, 0x99)
    text(s, 0.7, 0.62, 2.7, 0.35, [[("positioning pilot (500 kHz)", 14, {"color": green})]])
    arrow(s, 1.9, 0.97, 0.4 + 176 * k, 1.3 + 25 * k, green, 2.0)
    text(s, 3.6, 0.62, 2.7, 0.35, [[("data (OFDM, 64-QAM)", 14, {"color": blue})]])
    arrow(s, 3.95, 0.97, 0.4 + 254 * k, 1.3 + 25 * k, blue, 2.0)
    picture(s, A / "isac_constellation.png", 0.4, 4.25, h=1.95, align="left")
    caption(s, 0.4, 6.22, 1.9, 0.35, "64-QAM, one frame", size=11, align=PP_ALIGN.CENTER)
    text(s, 2.55, 4.15, 5.25, 2.6, [
        [("First tests (19 Nov), one position, 5 orientations", 16, {"bold": True})],
        [("2.27 Mb/s in the data slot, BER ≈ 10", 15), ("−5", 15), (", EVM ≈ 4.5 %", 15)],
        [("Pilot RSS measured in every capture, for positioning", 15)],
        [("One program: plan, gantry + MTRS, AWG, capture, demodulation, Excel", 15)],
        [("Documentation in progress", 15, {"color": DARK})],
    ], space_after=4, bullets=(1, 2, 3))
    r = s.shapes[-1].text_frame.paragraphs[1].runs[1]
    r.font._rPr.set("baseline", "30000")
    # set-up photo: LED on the ceiling, AWG on the stool, laptop with the acquisition program
    px, py, ph = 8.15, 0.7, 6.6
    pw = ph * 1536 / 2048
    outline(picture(s, A / "isac_setup.jpg", px, py, h=ph))
    def at(u, v):
        return px + u * pw, py + v * ph
    for (lx, ly, lw, t), (u, v) in (((8.35, 0.9, 0.75, "LED"), (0.39, 0.16)),
                                    ((10.85, 4.95, 2.05, "AWG (M8195A)"), (0.83, 0.79)),
                                    ((8.25, 6.82, 2.45, "acquisition program"), (0.34, 0.83))):
        label(s, lx, ly, lw, 0.36, t)
        tx, ty = at(u, v)
        sx = min(max(tx, lx + 0.15), lx + lw - 0.15)
        sy = ly + 0.36 if ty > ly else ly
        arrow(s, sx, sy, tx, ty, RED, 2.25)


def slide_contacts(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "COLLABORATIONS")
    groups = (("IN THE GROUP", 0.8, (
                ("Rizwana", "", "ISAC with a single LED and a single rotatable photodiode: acquisition program "
                 "ready, first measurements done.", 1.0),
                ("Hossein", "", "First steps on VCSEL-based positioning.", 0.8))),
              ("NEW CONTACTS", 3.2, (
                ("Amanda Prorok", "ProrokLab, Computer Science and Technology",
                 "Visited the lab (Maxence Boels). Two needs: a light, low-power, connected receiver on a PCB, "
                 "and leader-follower robot teams, where optical positioning helps.", 1.55),
                ("Francesca Parmigiani", "Microsoft Research Cambridge",
                 "I made the contact; I will join the upcoming visit.", 1.0))))
    for head, y, rows in groups:
        text(s, 0.45, y, 4.0, 0.32, [[(head, 12, {"bold": True, "color": "grey"})]])
        y += 0.35
        for i, (name, org, desc, rh) in enumerate(rows):
            if i:
                arrow(s, 0.45, y, 8.4, y, LINE_GREY, 0.75, head=False)
            paras = [[(name, 20, {"bold": True, "color": "accent", "font": TITLE_FONT})]]
            if org:
                paras.append([(org, 13, {"color": "grey"})])
            text(s, 0.45, y, 3.4, rh, paras, anchor=MSO_ANCHOR.MIDDLE)
            text(s, 3.9, y, 4.5, rh, [[(desc, 16)]], anchor=MSO_ANCHOR.MIDDLE)
            if name == "Amanda Prorok":
                pic = picture(s, A / "proroklab.png", 8.85, y + 0.05, w=4.15)
                caption(s, 8.85, y + 0.1 + pic.height / 914400, 4.15, 0.3, "ProrokLab arena (from their video)",
                        size=11).text_frame.paragraphs[0].runs[0].font.color.rgb = DARK
            y += rh


def slide_next(prs):
    s = prs.slides.add_slide(BLANK)
    title(s, "NEXT STEPS", "Keeping in touch")
    cols = (("drone.jpg", "Receiver on a PCB",
             "Photodiode, amplifier, MCU and IMU on one light board for robots and drones, as ProrokLab "
             "needs."),
            ("adt_schematic.png", "ADT + ADR",
             "Joint estimation with an angle-diversity transmitter and receiver, and optimisation of both."),
            ("ceiling_leds.png", "Two LEDs",
             "Position and heading with the second LED: a second experimental paper, with data "
             "already recorded."))
    cw, gap, ih = 3.95, 0.35, 2.4
    for i, (img, head, desc) in enumerate(cols):
        x = 0.45 + i * (cw + gap)
        picture(s, A / img, x, 0.9, w=cw, h=ih)
        text(s, x, 3.45, cw, 1.6, [[(head, 20, {"bold": True, "color": "accent", "font": TITLE_FONT})],
                                   [(desc, 16)]], space_after=4)
    text(s, 0.45, 5.55, 9.6, 1.5, [
        [("Keeping in touch", 18, {"bold": True})],
        [("Shared database (Zenodo, in progress) and software · ISAC measurements with Rizwana · "
          "PCB receiver for ProrokLab · return visit with the PCB prototype", 16)],
    ], space_after=4)
    text(s, 10.2, 5.95, 2.8, 0.8, [[("Thank you!", 28, {"bold": True, "color": "accent", "font": TITLE_FONT})]],
         align=PP_ALIGN.RIGHT, anchor=MSO_ANCHOR.MIDDLE)


def main():
    global BLANK
    prs = Presentation(str(TEMPLATE))
    ids = prs.slides._sldIdLst
    for sid in list(ids):
        prs.part.drop_rel(sid.rId)
        ids.remove(sid)
    BLANK = next(l for l in prs.slide_layouts if l.name == "Blank")
    for make in (slide_title, slide_paper, slide_other, slide_software, slide_isac, slide_contacts, slide_next):
        make(prs)
    prs.save(str(OUTPUT))
    print(f"{OUTPUT} ({OUTPUT.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
