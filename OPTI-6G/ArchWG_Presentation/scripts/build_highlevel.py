"""Short, high-level version of the ArchWG talk (general architecture audience)."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pptx_helpers import *

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG = os.path.join(ROOT, "figures")
TPL = os.path.join(ROOT, "..", "Material", "OPTI-6G RSSwithML Main Results- v2.pptx")
OUT = os.path.join(ROOT, "OPTI-6G_ArchWG_HighLevel_2026-11-20.pptx")
f = lambda n: os.path.join(FIG, n)

prs = Presentation(TPL)
clear_slides(prs)
n = 0


def slide(title):
    global n
    n += 1
    s = prs.slides.add_slide(prs.slide_layouts[0])
    remove_placeholder(s, 1)
    set_title(s, title, size=30)
    return s


def bullets(s, x, y, w, h, items, size=17, gap=9):
    return add_text(s, x, y, w, h, [(t, {"bullet": True}) for t in items], size=size, space_after=gap)


# 1 ---------------------------------------------------------------- title
n += 1
s = prs.slides.add_slide(prs.slide_layouts[1])
t = s.shapes.title
t.text = ""
rich_runs(t.text_frame.paragraphs[0], "Positioning from a Single", 40, DARK)
rich_runs(t.text_frame.add_paragraph(), "Optical Access Point", 40, DARK)
p = t.text_frame.add_paragraph(); p.space_before = Pt(10)
rich_runs(p, "Location from OWC beam steering in OPTI-6G", 22, BLUE)
body = [ph for ph in s.placeholders if ph.placeholder_format.idx == 1][0]
body.left, body.top, body.width, body.height = Emu(831850), Inches(5.12), Emu(10515600), Inches(0.75)
body.text = ""
rich_runs(body.text_frame.paragraphs[0], "Kevin Acuña-Condori, Bastien Béchadergue, Hongyu Guan and Luc Chassagne", 18, DARK)
rich_runs(body.text_frame.add_paragraph(), "Université Paris-Saclay, UVSQ, LISV – OPTI-6G WP4, Task 4.2", 14, GRAY)
add_text(s, 2.4, 5.95, 8.5, 0.35, ["SNS JU 6G Architecture Working Group, 20 November 2026"], size=14, color=BLUE,
         align=PP_ALIGN.CENTER, bold=True)
add_notes(s, "Good morning, and thank you for the invitation. I am Kevin Acuña-Condori from UVSQ, LISV, working in OPTI-6G "
             "Task 4.2. I will keep this at architecture level: what positioning from a single optical access point is, what it "
             "brings to a 6G network, what we have shown so far, and what it would need from the architecture.")

# 2 ---------------------------------------------------------------- context
s = slide("Why Positioning in Optical Access Networks?")
bullets(s, 0.5, 1.95, 7.2, 4.9, [
    "In 6G, positioning is expected as a network service, with cm-level accuracy indoors: robots, AGVs, XR, digital twins.",
    "Optical wireless (infrared or visible light) offers a large unlicensed spectrum, no radio interference, and light that stays in the room.",
    "The line-of-sight optical channel is stable and well modelled, so the received power carries reliable geometric information.",
    "OPTI-6G builds an optical cell-free access network integrated with 5G: each optical access point can also locate users.",
    "The catch: classical optical positioning needs 3 to 4 access points in view at the same time, or complex receivers (cameras, PD arrays).",
], size=17)
add_box(s, 8.0, 2.2, 4.85, 3.9, fill=LBLUE, line=MBLUE, line_w=1.5, anchor=MSO_ANCHOR.MIDDLE, text=[
    ("Question for the architecture", {"bold": True, "color": BLUE, "size": 18}),
    ("Can every optical access point provide positioning on its own, with a simple UE and without extra infrastructure?",
     {"size": 17, "space_after": 0}),
], margins=(0.25, 0.1, 0.25, 0.1))
add_footer(s, "", n)
add_notes(s, "Positioning is becoming a network service in 6G, and many indoor use cases need a few centimetres. Optical "
             "wireless is attractive for this: lots of spectrum, no interference with radio, and a very predictable line-of-sight "
             "channel. In OPTI-6G the optical access points are part of a cell-free network integrated with 5G, so it is natural "
             "to use them for positioning too. The problem is that classical optical positioning needs several access points "
             "visible at once, or complex receivers. So the question for the architecture is whether a single access point can "
             "do it alone.")

# 3 ---------------------------------------------------------------- idea
s = slide("The Idea: Steer the Beam of One Access Point")
add_image(s, f("concept_MFL.png"), 0.6, 2.0, w=2.7)
add_image(s, f("concept_SBL.png"), 3.6, 2.0, w=2.7)
add_text(s, 0.45, 4.65, 3.0, 0.35, ["Classical: 4 fixed APs"], size=13, bold=True, color=GRAY, align=PP_ALIGN.CENTER)
add_text(s, 3.45, 4.65, 3.0, 0.35, ["Proposed: 1 steerable AP"], size=13, bold=True, color=BLUE, align=PP_ALIGN.CENTER)
add_text(s, 0.6, 5.2, 5.7, 1.6, ["Spatial diversity is created at the infrastructure by beam steering, instead of adding "
                                 "access points or receiver hardware."], size=15, color=GRAY, italic=True)
steps = [("The access point sweeps its beam", "through a few known directions (a codebook), while the downlink keeps carrying data."),
         ("The UE measures one number per beam", "the average received power, with a single photodiode."),
         ("The UE (or the network) computes the position", "direction from the power ratios, then distance: full 3D position in under 1 ms.")]
for i, (h, d) in enumerate(steps):
    y = 1.95 + i * 1.62
    add_box(s, 6.8, y, 6.05, 1.45, fill=WHITE, line=MBLUE)
    add_number_badge(s, 6.95, y + 0.47, 0.5, i + 1)
    add_text(s, 7.6, y + 0.12, 5.15, 1.25, [(h, {"bold": True, "color": BLUE, "size": 16}), (d, {"size": 14})])
add_footer(s, "Chassagne et al., Opt. Express 2025; Acuña-Condori et al., IEEE ICC 2026 and IEEE Trans. Commun. 2026.", n)
add_notes(s, "The idea is simple. Instead of using four fixed access points, we use one access point whose beam can be "
             "steered. It points its beam in a few known directions, the UE measures the average received power for each "
             "direction, and from these few numbers we compute the direction and the distance to the access point, so the 3D "
             "position. The diversity comes from the infrastructure, not from extra access points or a complex receiver.")

# 4 ---------------------------------------------------------------- benefits
s = slide("What It Brings to the Network")
items = [("One access point is enough", "No anchor constellation; works where only one optical cell is visible."),
         ("Simple UE", "A single photodiode and a power reading; an IMU only in broadcast mode."),
         ("Compatible with data (ISAC)", "Only the average received power is used, so any downlink waveform can be kept."),
         ("Scales with the number of UEs", "Broadcast mode: one sweep serves all UEs, each computes its own position."),
         ("Synergy with beam management", "The estimated direction can also be used to point the data beam at the UE.")]
for i, (h, d) in enumerate(items):
    y = 1.95 + i * 0.97
    add_box(s, 0.5, y, 12.35, 0.85, fill=WHITE, line=MBLUE, line_w=1.0)
    add_text(s, 0.75, y + 0.05, 4.2, 0.75, [h], size=17, bold=True, color=BLUE, anchor=MSO_ANCHOR.MIDDLE)
    add_text(s, 5.0, y + 0.05, 7.7, 0.75, [d], size=16, anchor=MSO_ANCHOR.MIDDLE)
add_footer(s, "", n)
add_notes(s, "From an architecture point of view, this brings five things. One access point is enough. The UE stays simple, "
             "a photodiode and a power reading. It is compatible with communication, since we only use the average power. In "
             "broadcast mode it scales with the number of users, because one sweep serves everybody. And the direction we "
             "estimate is exactly what beam management needs to point the data beam.")

# 5 ---------------------------------------------------------------- architecture
s = slide("Where It Sits in the OPTI-6G Architecture")
add_box(s, 0.5, 1.95, 3.3, 2.1, fill=WHITE, line=MBLUE, line_w=1.5, anchor=MSO_ANCHOR.TOP, text=[
    ("Optical access point (O-RU)", {"bold": True, "color": BLUE, "size": 15}),
    ("steerable optical antenna", {"bullet": True, "size": 13, "align": PP_ALIGN.LEFT}),
    ("periodic beam sweep (codebook)", {"bullet": True, "size": 13, "align": PP_ALIGN.LEFT}),
    ("data downlink continues", {"bullet": True, "size": 13, "align": PP_ALIGN.LEFT}),
], margins=(0.12, 0.1, 0.1, 0.05))
for dy in (-0.45, 0.0, 0.45):
    add_line(s, 3.85, 3.0, 5.15, 3.0 + dy, color=PURPLE, width=2.25)
add_text(s, 3.8, 3.55, 1.4, 0.5, ["beam sweep"], size=12, color=PURPLE, align=PP_ALIGN.CENTER)
add_box(s, 5.2, 1.95, 3.3, 2.1, fill=WHITE, line=MBLUE, line_w=1.5, anchor=MSO_ANCHOR.TOP, text=[
    ("UE (robot, AGV, XR…)", {"bold": True, "color": BLUE, "size": 15}),
    ("single photodiode", {"bullet": True, "size": 13, "align": PP_ALIGN.LEFT}),
    ("power reading per beam", {"bullet": True, "size": 13, "align": PP_ALIGN.LEFT}),
    ("position estimate (< 1 ms)", {"bullet": True, "size": 13, "align": PP_ALIGN.LEFT}),
], margins=(0.12, 0.1, 0.1, 0.05))
add_line(s, 8.55, 2.6, 9.85, 2.6, color=MBLUE, width=2.25)
add_text(s, 8.5, 2.7, 1.4, 0.6, ["position report", "(OWC uplink)"], size=11, color=GRAY, align=PP_ALIGN.CENTER, space_after=0)
add_box(s, 9.9, 1.95, 2.95, 0.95, fill=LBLUE, line=MBLUE, line_w=1.5, text=[
    ("Localisation server", {"bold": True, "color": BLUE, "size": 14}), ("NIB / edge", {"size": 12})])
add_line(s, 11.37, 2.92, 11.37, 3.1, color=MBLUE, width=2.25)
add_box(s, 9.9, 3.1, 2.95, 0.95, fill=LBLUE, line=MBLUE, line_w=1.5, text=[
    ("5G core and applications", {"bold": True, "color": BLUE, "size": 14}), ("robots, AGVs, XR, digital twin", {"size": 12})])
add_box(s, 0.5, 4.3, 6.05, 1.65, fill=LPURPLE, line=PURPLE, anchor=MSO_ANCHOR.TOP, text=[
    ("UE-based (broadcast)", {"bold": True, "color": PURPLE, "size": 15, "align": PP_ALIGN.LEFT}),
    ("codebook and beam timing announced by the AP; each UE computes its own position; no limit on the number of UEs",
     {"size": 13, "align": PP_ALIGN.LEFT}),
], margins=(0.18, 0.1, 0.15, 0.05))
add_box(s, 6.8, 4.3, 6.05, 1.65, fill=LBLUE, line=MBLUE, anchor=MSO_ANCHOR.TOP, text=[
    ("Network-assisted (cooperative)", {"bold": True, "color": BLUE, "size": 15, "align": PP_ALIGN.LEFT}),
    ("UE reports the beam powers; the network computes the position and reuses the direction for beam alignment",
     {"size": 13, "align": PP_ALIGN.LEFT}),
], margins=(0.18, 0.1, 0.15, 0.05))
add_box(s, 0.5, 6.1, 12.35, 0.75, fill=WHITE, line=GRAY, line_w=0.75, text=[
    ("Needed from the architecture: signalling of the codebook and beam timing, calibration of the AP pose, "
     "reporting over the uplink, and exposure of the position to applications.", {"size": 13})])
add_footer(s, "", n)
add_notes(s, "This is where it would sit. Positioning becomes a function of the optical radio unit: it sweeps its beam "
             "periodically while data continues. The UE measures the powers and computes its position, or reports them to the "
             "network. Two modes: UE-based broadcast, which scales to any number of users, and network-assisted, where the "
             "network computes the position and can reuse the direction for beam alignment. What we need from the architecture "
             "is mainly signalling of the codebook and timing, AP calibration, reporting and exposure of the position.")

# 6 ---------------------------------------------------------------- evidence
s = slide("What We Have Shown So Far")
add_image(s, f("testbed_3D_photo.png"), 0.5, 1.95, h=4.8)
add_image(s, f("exp3_ml_cdf.png"), 4.3, 1.95, w=4.6, h=3.4)
add_text(s, 4.3, 5.4, 4.6, 0.6, ["3D error in the 2 m × 2 m target zone, on locations not used for training"],
         size=11, color=GRAY, align=PP_ALIGN.CENTER)
cards = [("2D: 4.3 cm", "P90, single steered LED, random receiver tilts (ICC 2026)", MBLUE),
         ("808 positions", "3D campaign, 8 heights, 3,232 fixes", GREEN),
         ("≈ 1°", "direction error, unaffected by receiver tilt", GREEN),
         ("5.5 → 1.9 cm", "P90 in the 2 m × 2 m zone: model only → with ML correction", GREEN)]
for i, (v, l, c) in enumerate(cards):
    add_card(s, 9.15, 1.95 + i * 1.2, 3.7, 1.08, v, l, color=c, vsize=20, lsize=11.5)
add_footer(s, "UVSQ-LISV test bench: IR LED on a motorised gimbal, single photodiode on a UR5 robot arm. 3D campaign Jul.–Sep. 2026.", n)
add_notes(s, "What we have shown so far, on our test bench at UVSQ: an infrared LED on a motorised gimbal plays the access "
             "point, and a single photodiode on a robot arm plays the UE. In 2D we reached 4.3 cm P90 with random receiver "
             "tilts. In 3D we measured 808 positions at eight heights. The direction error is about one degree and does not "
             "depend on the receiver tilt. In the 2 m by 2 m target zone the physical model alone gives 5.5 cm P90, and a simple "
             "machine-learning correction, tested on locations not used for training, brings it to 1.9 cm.")

# 7 ---------------------------------------------------------------- KPIs
s = slide("KPI Status (OPTI-6G D2.3)")
tb = add_table(s, 1.5, 2.0, 10.35, 3.7, [
    ["KPI", "Target", "Result", "Status"],
    ["Accuracy (P90)", "≤ 5 cm", "1.9 cm (Extra-Trees), 2.6 cm (neural network); 5.5 cm with the model alone", "Met with ML"],
    ["Coverage, single AP", "2 × 2 × 2 m³", "2 m × 2 m footprint, 8 heights (0.7 m of the 2 m height tested)", "Met with ML"],
    ["Extra latency", "≤ 20 ms", "< 10 ms per fix, ML included (steering time excluded)", "Met"],
    ["ISAC compatibility", "yes", "only the average power of each beam is used", "Met by design"],
], col_w=[2.3, 1.6, 4.65, 1.8], size=14, header_size=15, row_h=[0.5, 0.85, 0.85, 0.75, 0.75])
for r in range(1, 5):
    set_cell(tb.table.cell(r, 3), tb.table.cell(r, 3).text_frame.text, 14, GREEN, True, LGREEN, PP_ALIGN.CENTER)
add_text(s, 1.5, 5.9, 10.35, 0.8, ["Laboratory demonstrator (IR LED on a mechanical gimbal). Integration with the OPTI-6G "
                                   "optical antennas is planned for D4.3."], size=13, color=GRAY, italic=True)
add_footer(s, "ML: 5-fold cross-validation grouped by location (training and test never share a location).", n)
add_notes(s, "Against the KPIs of the project: accuracy and coverage are met in the 2 m by 2 m zone with the ML correction, "
             "latency is well below 20 ms, and ISAC compatibility is met by design. The height range we could test is 0.7 m, "
             "and this is still a lab demonstrator; the integration with the OPTI-6G antennas is the next step.")

# 8 ---------------------------------------------------------------- open questions
s = slide("Open Points for the Architecture Discussion")
bullets(s, 0.5, 1.95, 12.35, 4.9, [
    "Signalling: how to announce the beam codebook and the sweep timing to the UEs (system information, similar to an NR beam sweep)?",
    "Scheduling: how often to sweep, and how to share the beam between positioning and data without hurting throughput?",
    "Steering hardware: today a mechanical gimbal (seconds per beam); solid-state steering (MEMS, liquid crystal, OPA) is needed for tracking.",
    "Cell-free operation: fusion with neighbouring optical APs and with 5G positioning (TDoA) at the edge of the coverage.",
    "Where the position is computed and exposed: UE, localisation server or edge, and the interface towards applications.",
], size=17, gap=12)
add_footer(s, "", n)
add_notes(s, "To open the discussion, these are the points where we would like input from the architecture side: how to signal "
             "the codebook and timing, how to schedule the sweep together with data, the need for faster steering hardware, the "
             "fusion with neighbouring access points and with 5G positioning, and where the position should be computed and "
             "exposed.")

# 9 ---------------------------------------------------------------- conclusions
s = slide("Conclusions")
bullets(s, 0.55, 2.05, 12.2, 4.75, [
    "A single optical access point with a steerable beam, and a UE with one photodiode, can provide 3D positioning.",
    "It fits naturally in an optical cell-free network: same access points, same light as the data, UE-based or network-assisted.",
    "Lab results: about 1° in direction and P90 below 5 cm in the 2 m × 2 m target zone with a simple ML correction.",
    "Next: faster steering, integration with the OPTI-6G antennas and joint communication and positioning tests.",
], size=19, gap=16)
add_footer(s, "This work is part of the EC Horizon Europe project OPTI-6G, Grant Agreement No. 101139292.", n)
add_notes(s, "To conclude: one steerable optical access point and a simple UE are enough for 3D positioning, it fits the "
             "optical cell-free architecture, and the lab results reach the project targets with a simple ML correction. The "
             "next steps are faster steering and the integration with the OPTI-6G antennas. Thank you.")

# 10 --------------------------------------------------------------- thank you
s = prs.slides.add_slide(prs.slide_layouts[7])
t = s.shapes.title
t.text = ""
rich_runs(t.text_frame.paragraphs[0], "Thank you for your attention!", 36, RGBColor(0x1F, 0x5F, 0xD6), italic=True)
s.shapes.add_picture(f("opti6g_qr.png"), Emu(10354766), Emu(156794), Emu(1172567), Emu(1143733))
add_text(s, 2.0, 4.55, 9.33, 0.35, ["kevin-jose.acuna-condori@uvsq.fr  /  bastien.bechadergue@uvsq.fr"], size=13, color=GRAY,
         align=PP_ALIGN.CENTER)
add_notes(s, "Questions.")

prs.save(OUT)
print("saved", OUT, len(prs.slides))
