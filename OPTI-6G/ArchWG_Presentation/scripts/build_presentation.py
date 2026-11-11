"""Builds the SNS JU ArchWG presentation (20 Nov 2026) on the OPTI-6G template."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pptx_helpers import *

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FIG = os.path.join(ROOT, "figures")
TPL = os.path.join(ROOT, "..", "Material", "OPTI-6G RSSwithML Main Results- v2.pptx")
OUT = os.path.join(ROOT, "OPTI-6G_ArchWG_Beamsteering_Positioning_UVSQ_2026-11-20.pptx")

L_TITLE, L_SECTION, L_THANKS = 0, 1, 7
f = lambda name: os.path.join(FIG, name)
SRC_EXP = "Experimental campaign UVSQ-LISV, Jul.-Sep. 2026 (journal paper in preparation). GLS/NLS: generalized / nonlinear least squares."

prs = Presentation(TPL)
clear_slides(prs)
n = 0


def content_slide(title, size=30):
    global n
    n += 1
    s = prs.slides.add_slide(prs.slide_layouts[L_TITLE])
    remove_placeholder(s, 1)
    set_title(s, title, size=size)
    return s


# =====================================================================  1. TITLE
n += 1
s = prs.slides.add_slide(prs.slide_layouts[L_SECTION])
t = s.shapes.title
t.text = ""
p = t.text_frame.paragraphs[0]
rich_runs(p, "Location from OWC Beam Steering", 40, DARK)
p = t.text_frame.add_paragraph()
rich_runs(p, "from a Single Access Point", 40, DARK)
p = t.text_frame.add_paragraph()
p.space_before = Pt(10)
rich_runs(p, "3D positioning with one beam-steered LED and one photodiode", 22, BLUE)
body = [ph for ph in s.placeholders if ph.placeholder_format.idx == 1][0]
body.left, body.top, body.width, body.height = Emu(831850), Inches(5.12), Emu(10515600), Inches(0.75)
body.text = ""
p = body.text_frame.paragraphs[0]
rich_runs(p, "Kevin Acuña-Condori, Bastien Béchadergue, Hongyu Guan and Luc Chassagne", 18, DARK)
p = body.text_frame.add_paragraph()
rich_runs(p, "Université Paris-Saclay, UVSQ, LISV  |  OPTI-6G WP4 – Task 4.2", 14, GRAY)
add_text(s, 2.4, 5.95, 8.5, 0.35, ["SNS JU 6G Architecture Working Group  ·  20 November 2026"],
         size=14, color=BLUE, align=PP_ALIGN.CENTER, bold=True)
add_notes(s, "Title. Thank John and Bastien. I am Kevin Acuna-Condori (UVSQ-LISV), main developer of the "
             "beam-steering-based positioning method in OPTI-6G Task 4.2. Topic requested by the WG: location from "
             "optical wireless beam steering using a single access point. Structure: motivation and principle, a brief "
             "2D proof of concept, then the focus: 3D theory and the new 3D experimental results, KPIs and how this "
             "fits a 6G architecture.")

# =====================================================================  2. MOTIVATION
s = content_slide("Why Positioning from a Single Optical Access Point?")
add_text(s, 0.5, 1.95, 6.9, 3.6, [
    ("6G (IMT-2030): positioning becomes a **native network service** – cm-level indoor accuracy for robots, AGVs, XR.", {"bullet": True}),
    ("OPTI-6G: near-IR **optical cell-free access** integrated with 5G – every optical AP (O-RU) can be a positioning anchor.", {"bullet": True}),
    ("Classical optical RSS / TDoA needs **≥ 3–4 APs in line of sight** at once, identified and calibrated.", {"bullet": True}),
    ("Optical cells are small and directional: a UE often sees **only one AP**.", {"bullet": True}),
    ("PD arrays, cameras or rotating PDs add cost to **every** UE.", {"bullet": True}),
], size=15, space_after=6)
add_box(s, 0.5, 5.35, 6.9, 1.3, fill=LBLUE, line=MBLUE, line_w=1.5, text=[
    ("Our approach", {"bold": True, "color": BLUE, "size": 14, "align": PP_ALIGN.LEFT}),
    ("Move the spatial diversity to the infrastructure: **one AP steers its beam through K known directions**; a "
     "**single-photodiode UE** localises itself in 3D.", {"size": 14, "align": PP_ALIGN.LEFT}),
], anchor=MSO_ANCHOR.MIDDLE, margins=(0.15, 0.05, 0.15, 0.05))
add_image(s, f("concept_MFL.png"), 7.7, 1.95, w=2.45)
add_image(s, f("concept_SBL.png"), 10.4, 1.95, w=2.45)
add_text(s, 7.55, 4.33, 2.75, 0.35, ["Classical: 4 fixed APs"], size=12, bold=True, color=GRAY, align=PP_ALIGN.CENTER)
add_text(s, 10.25, 4.33, 2.75, 0.35, ["Proposed: 1 steerable AP"], size=12, bold=True, color=BLUE, align=PP_ALIGN.CENTER)
add_table(s, 7.7, 4.78, 5.15, 2.05, [
    ["", "Conventional RSS", "Single steered AP"],
    ["APs in line of sight", "≥ 3–4", "**1**"],
    ["UE hardware", "1 PD (assumed vertical) or PD array / camera", "**1 PD**"],
    ["Receiver orientation", "must be known or vertical", "**not needed** for direction"],
    ["Source of diversity", "more anchors / Rx hardware", "**beam steering at the AP**"],
], col_w=[1.45, 1.85, 1.85], size=11, header_size=11.5, row_h=[0.34, 0.34, 0.5, 0.45, 0.42])
add_footer(s, "OPTI-6G proposal §1.1.2.3: “modulate the angle of emission of the source and, thus, simplify the receiver”.", n)
add_notes(s, "Architecture problem first. 6G positions localisation as a native service. In OPTI-6G each optical AP is "
             "an O-RU of a cell-free network. Classical optical positioning (RSS/TDoA) needs 3-4 APs visible at the same "
             "time with known geometry; with small directional optical cells this is often not the case. Instead of "
             "adding anchors or receiver hardware we let the AP steer its beam: the angular diversity is created at the "
             "infrastructure and the UE keeps a single photodiode. This is exactly the UVSQ idea written in the proposal.")

# =====================================================================  3. PRINCIPLE
s = content_slide("Principle: Beam Sweep → RSS → 3D Position")
add_image(s, f("tcom_geometry.png"), 0.45, 2.0, w=5.5)
add_text(s, 0.45, 5.55, 5.5, 0.5, ["AP at **t** steered through K known orientations **n**_{t,i}; single-PD UE at unknown **r** with unknown orientation **n**_{r}."],
         size=12, color=GRAY)
add_box(s, 0.45, 6.12, 5.5, 0.72, fill=LGREEN, line=GREEN, line_w=1.25, text=[
    ("Only the **average received power** per beam is used → transparent to the data waveform (ISAC-ready).", {"size": 13, "accent": GREEN})],
    margins=(0.12, 0.03, 0.12, 0.03))
steps = [
    ("Beam sweep at the AP", "The AP points its beam along K known directions (codebook); the UE averages the received power for each one.", "eq_rss.png", 0.62),
    ("Direction finding (AoD-like)", "Power ratios cancel η (distance, Tx power, PD gain, receiver tilt) → linear constraints on **n**_{d}; closed-form eigenvector (GLS/WLS) or NLS.", "eq_ratio.png", 0.6),
    ("Range and 3D position", "Cooperative: one extra beam-aligned measurement (K+1).  Broadcast: closed form from the same K powers, using **n**_{r} from an IMU.", "eq_range.png", 0.66),
]
y0 = 1.95
for i, (ttl, txt, eq, eqh) in enumerate(steps):
    add_box(s, 6.2, y0, 6.65, 1.58, fill=WHITE, line=MBLUE, line_w=1.0)
    add_number_badge(s, 6.3, y0 + 0.1, 0.42, i + 1)
    add_text(s, 6.82, y0 + 0.06, 5.95, 0.34, [ttl], size=15, bold=True, color=BLUE)
    add_text(s, 6.82, y0 + 0.38, 5.95, 0.55, [txt], size=12)
    add_image(s, f(os.path.join("eq", eq)), 6.82, y0 + 0.9, w=5.9, h=eqh, align="center")
    y0 += 1.66
add_footer(s, "Chassagne et al., Opt. Express 2025 (concept); Acuña-Condori et al., IEEE ICC 2026 (SVD estimator), IEEE Trans. Commun. 2026 (3D, GLS/WLS/NLS).", n)
add_notes(s, "Three steps. (1) The AP sweeps K known orientations; for each the UE only needs the mean received power, "
             "so any communication waveform can be used. (2) Taking ratios between two orientations cancels everything "
             "that is common: distance, transmit power, PD gain and the receiver incidence angle. Each ratio gives a "
             "linear constraint on the direction vector; with K>=3 we get the direction as the eigenvector of a 3x3 "
             "matrix (GLS/WLS) or with a nonlinear fit (NLS). This direction finding is independent of the receiver "
             "orientation. (3) The range comes either from one extra beam-aligned measurement (cooperative) or in closed "
             "form from the same K powers if the UE knows its own orientation from an IMU (broadcast).")

# =====================================================================  4. ROADMAP
s = content_slide("Roadmap: From Concept to 3D Experiments")
miles = [
    ("Concept", "2025", "Steer the source orientation instead of adding anchors (2D, simulation)", "Chassagne et al., Opt. Express 2025", RGBColor(0x7F, 0x8C, 0x9D)),
    ("2D experiment", "2025–26", "SVD ratio estimator on a robot testbed: 2.66 cm RMSE under random tilts", "IEEE ICC 2026 · OPTI-6G D4.2", MBLUE),
    ("3D theory", "2026", "DEB/PEB bounds, GLS/WLS/NLS, GA codebook: ≈ 2 cm (sim.)", "IEEE Trans. Commun. 2026", PURPLE),
    ("Broadcast multi-UE", "2026", "Range from the same K powers + IMU: 1.73 cm RMS (sim.)", "Letter, 2026", PURPLE),
    ("3D experiment", "2026", "808 positions × 4 Rx orientations: P90 4.8 cm in the AP half-power cone", "Journal paper in preparation", GREEN),
]
bw, gap, x0 = 2.3, 0.2125, 0.5
add_line(s, 0.5, 2.18, 12.85, 2.18, color=RGBColor(0xB0, 0xB8, 0xC4), width=3, arrow_end=True)
for i, (ttl, yr, res, ven, col) in enumerate(miles):
    x = x0 + i * (bw + gap)
    add_number_badge(s, x + bw / 2 - 0.2, 1.98, 0.4, i + 1, fill=col, size=14)
    add_box(s, x, 2.55, bw, 0.5, fill=col, line=col, text=[(ttl, {"bold": True, "color": WHITE, "size": 15})], radius=0.15)
    add_box(s, x, 3.1, bw, 2.05, fill=WHITE, line=col, line_w=1.25, anchor=MSO_ANCHOR.TOP, text=[
        (yr, {"bold": True, "color": col, "size": 13}),
        (res, {"size": 12.5, "space_after": 6}),
        (ven, {"size": 11, "color": GRAY, "italic": True}),
    ], margins=(0.1, 0.08, 0.1, 0.05))
add_box(s, x0 + 1 * (bw + gap) - 0.05, 5.22, 4 * bw + 3 * gap + 0.1, 0.36, fill=None, line=None,
        text=[("◄  focus of this talk: 2D briefly, then 3D theory and 3D experiments  ►", {"bold": True, "color": BLUE, "size": 13})])
chain = [("Task 4.2", "OWC RSS & AoA localisation (UVSQ lead)"), ("D4.1", "system design"), ("D2.3", "test method & KPIs"),
         ("D4.2", "construction & 2D tests"), ("D4.3", "integration & KPI validation (Sec. 5)")]
cw, cg = 2.25, 0.275
for i, (a, b) in enumerate(chain):
    x = 0.5 + i * (cw + cg)
    add_box(s, x, 5.85, cw, 0.9, fill=LBLUE, line=MBLUE, line_w=1.0, text=[
        (a, {"bold": True, "color": BLUE, "size": 14}), (b, {"size": 11.5})])
    if i < len(chain) - 1:
        add_line(s, x + cw + 0.03, 6.3, x + cw + cg - 0.03, 6.3, color=MBLUE, width=2)
add_text(s, 0.5, 5.6, 4, 0.28, ["OPTI-6G work-plan links"], size=11, color=GRAY, bold=True)
add_footer(s, "D4.3 (in preparation) – this material is intended as the basis of Section 5 “Beamsteered AoA localisation over wireless OWC”.", n)
add_notes(s, "Maturity path. Concept published in Optics Express in 2025 (2D, simulation). Then a 2D experimental proof "
             "(ICC 2026, also reported in D4.2). Then the 3D theory in IEEE TCOM: bounds, estimators and codebook design, "
             "and a broadcast extension for multiple users. The newest piece is the 3D experimental validation done this "
             "summer. In OPTI-6G this is Task 4.2 led by UVSQ, linked to D4.1, D2.3 (KPIs), D4.2 and the upcoming D4.3.")

# =====================================================================  5. 2D EXPERIMENT
s = content_slide("2D Experimental Proof of Concept (IEEE ICC 2026)")
add_image(s, f("testbed_2D_photo.png"), 0.5, 1.95, w=3.45)
add_text(s, 0.5, 5.07, 3.45, 0.45, ["LISV testbed: IR LED on a 2-axis motorized gimbal (ceiling), single PD on a UR5 robot arm"],
         size=11, color=GRAY)
add_image(s, f("exp2D_results.png"), 4.15, 1.95, w=5.05)
add_text(s, 4.15, 5.3, 5.05, 0.3, ["Ground truth (blue) vs. estimates (green), 10 random tilts each"],
         size=11, color=GRAY, align=PP_ALIGN.CENTER)
cards = [("2.66 cm", "RMSE (all positions & tilts)"), ("2.35 cm", "mean error"),
         ("4.32 cm", "P90 error  (OPTI-6G target ≤ 5 cm)"), ("4.8 mm", "repeatability under tilt (WRMS)")]
for i, (v, l) in enumerate(cards):
    add_card(s, 9.45, 1.95 + i * 0.86, 3.4, 0.78, v, l, color=BLUE if i != 2 else GREEN, vsize=22, lsize=11.5)
add_box(s, 0.5, 5.65, 6.05, 1.2, fill=WHITE, line=MBLUE, anchor=MSO_ANCHOR.TOP, text=[
    ("Setup", {"bold": True, "color": BLUE, "size": 13, "align": PP_ALIGN.LEFT}),
    ("0.8 × 0.8 m² · K = 3 AP orientations (20° tilt; 0/120/240°) · 18 positions × 10 random receiver tilts (≤ 20°, any azimuth) · "
     "1000 samples per orientation · closed-form SVD ratio estimator · extra latency of a few ms", {"size": 12, "align": PP_ALIGN.LEFT}),
], margins=(0.12, 0.05, 0.12, 0.05))
add_box(s, 6.75, 5.65, 6.1, 1.2, fill=LGREEN, line=GREEN, anchor=MSO_ANCHOR.TOP, text=[
    ("Why steering?", {"bold": True, "color": GREEN, "size": 13, "align": PP_ALIGN.LEFT}),
    ("Simulation, 3 × 3 m², random receiver tilt ≤ 20°: P90 = **3.16 cm** with one steered LED vs **34.45 cm** with four "
     "fixed LEDs (classical RSS). ML-assisted variant (OPTI-6G D2.3): P90 = 2.8 cm over 1.8 × 1.8 m².", {"size": 12, "align": PP_ALIGN.LEFT, "accent": GREEN}),
], margins=(0.12, 0.05, 0.12, 0.05))
add_footer(s, "K. Acuña-Condori et al., “Robust optical wireless positioning with beam steering: pose estimation and tilt robustness,” IEEE ICC 2026; OPTI-6G D4.2.", n)
add_notes(s, "Brief 2D part. Same lab: IR LED on a two-axis gimbal on the ceiling, a single photodiode on a UR5 robot. "
             "Three AP orientations, 18 positions, and at each position 10 random receiver tilts up to 20 degrees. "
             "RMSE 2.66 cm, mean 2.35 cm, P90 4.32 cm, i.e. inside the OPTI-6G 5 cm target, and the repeatability "
             "across tilts is 4.8 mm: the estimate barely moves when the receiver is tilted. In simulation, under the "
             "same random tilt, a classical 4-LED RSS system degrades to 34 cm P90 while the steered LED stays at 3 cm. "
             "These results are in D4.2 and were presented at ICC 2026.")

# =====================================================================  6. 3D THEORY
s = content_slide("3D Theory: Bounds, Estimators, Codebook")
add_image(s, f("tcom_bounds_vs_K.png"), 0.5, 1.95, w=4.55)
add_image(s, f("tcom_cdf_3D_K9.png"), 5.2, 2.05, w=4.6)
add_text(s, 0.5, 5.3, 4.55, 0.3, ["(a) RMS direction / position bounds vs. number of beams K"], size=11, color=GRAY, align=PP_ALIGN.CENTER)
add_text(s, 5.2, 5.3, 4.6, 0.3, ["(b) CDF of the 3D error: estimators vs. PEB (K = 5, 9)"], size=11, color=GRAY, align=PP_ALIGN.CENTER)
cards = [("0.52°", "RMS direction bound (K = 5)"), ("−49 to −72 %", "median DEB: GA vs random codebooks"),
         ("1.9–2.3 cm", "mean 3D error (sim., K = 5)"), ("< 3 %", "DF degradation, random Rx tilt"),
         ("0.02–0.65 ms", "computation per fix (GLS→NLS)")]
for i, (v, l) in enumerate(cards):
    add_card(s, 10.0, 1.95 + i * 0.79, 2.85, 0.72, v, l, color=PURPLE, vsize=18, lsize=10.5)
add_text(s, 0.5, 5.68, 9.35, 1.2, [
    ("Cramér–Rao **direction (DEB)** and **position (PEB)** bounds; estimators **GLS** (closed form, efficient), **WLS** (lightweight), **NLS** (iterative) – all provably **independent of the receiver orientation**.", {"bullet": True}),
    ("Codebook optimised offline by a **genetic algorithm**: one universal orientation set per room; K trades accuracy against scan time.", {"bullet": True}),
    ("Simulated 3 × 3 × 2 m³ room, 1,792 positions × 1,000 noise trials.", {"bullet": True}),
], size=13, space_after=3)
add_footer(s, "K. Acuña-Condori et al., “Model-based beam-steered optical wireless positioning with single-LED single-photodiode for 3D localization,” IEEE Trans. Commun., 2026.", n)
add_notes(s, "3D theory (IEEE Transactions on Communications). We derived Cramer-Rao bounds for the direction and for "
             "the 3D position, and three estimators: GLS is closed form and statistically efficient, WLS is lighter, NLS "
             "is iterative and closest to the bound. All three are mathematically independent of the receiver orientation. "
             "The set of K orientations is optimised offline with a genetic algorithm: it halves the median direction bound "
             "compared with random sets. With K=5, simulation gives about half a degree in direction and about 2 cm 3D "
             "mean error, less than 3% degradation under random receiver tilt, and sub-millisecond computation.")

# =====================================================================  7. BROADCAST
s = content_slide("Broadcast Mode: One Sweep Serves All UEs")
add_image(s, f("bcast_multiuser_3D.png"), 0.45, 1.95, w=5.65)
add_text(s, 0.45, 6.5, 5.65, 0.4, ["Simulated simultaneous 3D tracking of a robot vacuum, a pedestrian and an AGV from the same sweeps (K = 9, NLS)"],
         size=11, color=GRAY, align=PP_ALIGN.CENTER)
add_image(s, f("bcast_PEB_vs_K.png"), 6.35, 1.95, w=3.45)
cards = [("1.73 cm", "RMS 3D error (K = 9, sim.)"), ("× 1.3–1.5", "RMS bound vs. cooperative (K ≥ 5)"),
         ("any number", "of UEs per sweep, no uplink needed for the fix")]
for i, (v, l) in enumerate(cards):
    add_card(s, 9.95, 1.95 + i * 0.95, 2.9, 0.86, v, l, color=PURPLE, vsize=20, lsize=11)
add_text(s, 6.35, 4.9, 6.5, 1.95, [
    ("**Cooperative** mode: one beam-aligned (K+1) exchange per UE – best accuracy, but does not scale.", {"bullet": True}),
    ("**Broadcast** mode: the AP periodically sweeps a common codebook; each UE gets its range in closed form from the same K powers and its own orientation (IMU).", {"bullet": True}),
    ("Optical analogue of an **SSB-like beam sweep** with UE-based positioning.", {"bullet": True}),
    ("The 3D experiments that follow use the **broadcast** pipeline.", {"bullet": True}),
], size=13.5, space_after=4)
add_footer(s, "K. Acuña-Condori et al., “Broadcast 3D indoor positioning with a single beam-steered LED,” 2026.  PEB_B / PEB_C: broadcast / cooperative position error bounds.", n)
add_notes(s, "Architecture-relevant extension. The cooperative mode needs one extra aligned measurement per user, so it "
             "does not scale. In broadcast mode the AP just keeps sweeping a common codebook, like an SSB beam sweep, and "
             "every UE computes its own position from the same K powers using its orientation from an IMU. The price is "
             "a factor 1.3 to 1.5 on the RMS bound for K>=5, but any number of UEs can be served, without uplink for the fix itself. "
             "Example: three different mobile users tracked from the same sweeps. The experiments use this mode.")

# =====================================================================  8. 3D TESTBED
s = content_slide("3D Experimental Testbed (UVSQ–LISV)")
add_image(s, f("testbed_3D_photo.png"), 0.5, 1.95, h=4.85)
add_table(s, 4.45, 1.95, 8.4, 4.6, [
    ["Element", "Implementation"],
    ["AP transmitter", "940 nm IR LED (OSRAM SFH 4725S), 500 mA, ceiling-mounted at 2.0 m"],
    ["Beam steering", "2-axis motorized gimbal, 2 × Thorlabs PRM1Z8 (0.1° resolution)"],
    ["Measured beam", "Φ_{1/2} = 36.7°  →  Lambertian order m = 3.13"],
    ["Codebook", "12 orientations recorded; **K = 9** used (3 at 16° + 6 at 60–64°), optimised for this beam"],
    ["UE receiver", "single Si PIN photodiode (OSRAM BPX61) + transimpedance amplifier"],
    ["Acquisition", "DAQ at 1 kHz; 1000 samples (1 s) averaged per orientation"],
    ["Ground truth", "UR5 robot arm (sub-mm repeatability), relocated to 15 base positions"],
    ["Receiver attitude", "per point: vertical + 3 random tilts (0–15°, uniform azimuth)"],
    ["Processing", "GLS / WLS / NLS direction + broadcast range; **one** calibration constant C (measured under the AP); no training data"],
], col_w=[1.9, 6.5], size=12.5, header_size=13, row_h=[0.4] + [0.46] * 9)
add_footer(s, SRC_EXP, n)
add_notes(s, "The 3D testbed. A 940 nm IR LED on the motorised gimbal at 2 m height plays the role of the steerable "
             "optical AP. The UE is a single BPX61 photodiode with a transimpedance amplifier on a UR5 robot arm, which "
             "gives sub-millimetre ground truth; we moved the robot to 15 base positions to cover the room. Twelve "
             "orientations were recorded at each point and nine are used. Each point is measured with the PD vertical and "
             "with three random tilts. Processing is purely model-based: one calibration constant, no training data.")

# =====================================================================  9. CHANNEL + CODEBOOK
s = content_slide("Optical Channel and Beam Codebook")
add_image(s, f("led_pattern_fit.png"), 0.45, 1.95, w=5.3)
add_image(s, f("exp3_codebook_footprints.png"), 5.85, 1.95, h=4.1)
add_text(s, 0.45, 6.1, 5.3, 0.5, ["(a) Measured LED profile vs. Lambertian model (Φ_{1/2} = 36.7°)"], size=11, color=GRAY, align=PP_ALIGN.CENTER)
add_text(s, 5.65, 6.1, 4.4, 0.5, ["(b) Half-power footprints of the K = 9 beams at z = 0.75 m; dots: measured (x, y) positions"],
         size=11, color=GRAY, align=PP_ALIGN.CENTER)
add_text(s, 10.15, 1.95, 2.75, 4.9, [
    ("Measured radiation profile follows a **Lambertian law** cos^{m} (m = 3.13) up to ≈ 60° → ideal model kept.", {"bullet": True}),
    ("**9 beams** (3 inner, 6 outer) tile ≈ 3 × 3 m at UE height.", {"bullet": True}),
    ("**One** radiometric calibration: C from measurements directly under the AP.", {"bullet": True}),
    ("Only the **mean power** per beam is exploited.", {"bullet": True}),
], size=13.5, space_after=8)
add_footer(s, SRC_EXP, n)
add_notes(s, "Before positioning we characterised the optical channel: the measured LED profile is very close to a "
             "Lambertian law with m=3.13 (half-power angle 36.7 degrees), so the ideal model is kept in the estimators. "
             "On the right, the half-power footprints of the nine beams at UE height: three inner beams and six outer "
             "ones tile about 3 by 3 metres; the dots are the measured positions. Only one constant C is calibrated, "
             "from the measurements taken directly under the AP.")

# =====================================================================  10. CAMPAIGN + 3D MAP
s = content_slide("3D Measurement Campaign and Localisation Map")
add_image(s, f("exp3_3D_error_map.png"), 0.35, 1.95, h=4.75)
cards = [("808", "3D ground-truth positions"), ("8 heights", "z = 0.4–1.1 m (0.9–1.6 m below the AP)"),
         ("3,232", "3D fixes (1 vertical + 3 tilted Rx per point)"), ("38,784", "beam-RSS measurements, 22 sessions")]
for i, (v, l) in enumerate(cards):
    r, c = divmod(i, 2)
    add_card(s, 7.45 + c * 2.75, 1.95 + r * 1.07, 2.6, 0.97, v, l, color=GREEN, vsize=22, lsize=11)
add_text(s, 7.45, 4.2, 5.4, 2.65, [
    ("0.2 m grid; up to **2.0 m** horizontal offset (64° from the AP nadir).", {"bullet": True}),
    ("Same data processed by GLS / WLS / NLS + broadcast range – **no training, no fingerprinting**.", {"bullet": True}),
    ("Colour = 3D error (NLS, vertical PD): **cm-level inside the AP footprint**, degrading towards the periphery.", {"bullet": True}),
], size=14, space_after=8)
add_footer(s, SRC_EXP, n)
add_notes(s, "The 3D campaign: 808 ground-truth positions on a 0.2 m grid at 8 heights, i.e. 0.9 to 1.6 m below the "
             "AP, and up to 2 m horizontal offset. Each position is measured four times with different receiver "
             "attitudes, giving 3,232 3D fixes from almost 39,000 beam power measurements over 22 sessions. The colour "
             "is the 3D error: blue/cyan, i.e. 1-4 cm, under the AP, and growing at the periphery.")

# =====================================================================  11. CDFs
s = content_slide("3D Results: Direction and Position Accuracy")
add_image(s, f("exp3_cdf_direction_position.png"), 0.9, 1.95, w=11.0)
cards = [("≈ 1.0°", "mean direction error, all positions"), ("3.7 cm", "median 3D error, all 808 positions"),
         ("2.3 | 4.8 cm", "median | P90 inside the AP half-power cone"), ("8.2 cm", "P90 over the whole sampled region")]
for i, (v, l) in enumerate(cards):
    add_card(s, 0.55 + i * 3.1, 6.14, 2.95, 0.76, v, l, color=GREEN if i == 2 else BLUE, vsize=17, lsize=10.5)
add_footer(s, "UVSQ-LISV campaign, Jul.-Sep. 2026. Half-power cone: positions within 36.7° of the AP nadir (n = 368 of 808).", n)
add_notes(s, "Main result. Left: direction finding, about 1 degree mean error, and the curves for vertical and tilted "
             "receivers almost overlap. Right: 3D error in broadcast mode. Over all 808 positions the median is 3.7 cm "
             "and the P90 8.2 cm. Inside the half-power cone of the AP (368 positions) the median is 2.3 cm and the P90 "
             "4.8 cm, which meets the OPTI-6G 5 cm target. NLS is consistently the best estimator, GLS close behind, as "
             "predicted by the theory.")

# =====================================================================  12. ERROR SOURCES
s = content_slide("Where Does the Error Come From?")
add_image(s, f("exp3_topview_median_error.png"), 0.4, 1.95, w=5.0)
add_text(s, 0.4, 6.05, 5.0, 0.6, ["Median 3D error per (x, y) over the 8 heights; dashed: AP half-power footprint at z = 1.1 / 0.75 / 0.4 m"],
         size=11, color=GRAY, align=PP_ALIGN.CENTER)
add_image(s, f("exp3_error_vs_offaxis.png"), 5.6, 1.95, w=7.25)
add_text(s, 5.6, 4.9, 7.25, 1.95, [
    ("Direction error stays **≈ 1° at all angles** → lateral error 1.5–3 cm.", {"bullet": True}),
    ("Beyond ≈ 45° the 3D error is dominated by the **range** term (12 cm median at 55–70°).", {"bullet": True}),
    ("Causes: lower SNR and radiometric model mismatch at large angles (pattern tails, PD field of view, single C).", {"bullet": True}),
    ("Remedies: measured-pattern model, more outer beams, hand-over to neighbouring APs (cell-free).", {"bullet": True}),
], size=13.5, space_after=4)
add_footer(s, SRC_EXP, n)
add_notes(s, "Where does the error come from? The map shows a clear centre-to-periphery trend. Splitting the error, "
             "the direction error stays around 1 degree everywhere, which gives a lateral error of 1.5 to 3 cm. What grows "
             "is the range error: beyond about 45 degrees from the nadir it dominates. This is the amplitude model: lower "
             "SNR, deviation from the ideal pattern at large angles, the PD field of view and a single calibration constant. "
             "So the direction-finding part is robust, and the range part is where calibration and codebook design, or a "
             "neighbouring AP in a cell-free deployment, can help.")

# =====================================================================  13. TILT ROBUSTNESS
s = content_slide("Robustness to Receiver Orientation")
add_image(s, f("exp3_tilt_robustness.png"), 1.4, 1.95, w=10.5)
cards = [("0.28°", "direction spread over 4 receiver orientations at the same point (≈ 0.9 cm)"),
         ("1.03° → 1.08°", "mean direction error, vertical → randomly tilted PD (NLS)"),
         ("4.7 cm", "P90 3D error with random tilts, inside the half-power cone")]
for i, (v, l) in enumerate(cards):
    add_card(s, 0.55 + i * 4.13, 6.2, 4.0, 0.7, v, l, color=GREEN, vsize=17, lsize=10.5)
add_footer(s, "UVSQ-LISV campaign, Jul.-Sep. 2026. Tilts uniform in 0–15° (mean 7.6°), uniform azimuth; receiver orientation used only for the range.", n)
add_notes(s, "Receiver orientation. Each point was measured with the PD vertical and with three random tilts. Left: the "
             "direction error with a tilted PD versus vertical, point by point: they lie on the diagonal, the mean goes "
             "from 1.03 to 1.08 degrees, and the four estimates at the same point are within 0.28 degrees of each other. "
             "This experimentally confirms the orientation independence proven in theory. Right: the 3D error degrades "
             "slightly with tilt because the range uses the receiver orientation, but inside the half-power cone P90 is "
             "still 4.7 cm.")

# =====================================================================  14. KPI TABLE
s = content_slide("KPI Assessment against OPTI-6G Targets (D2.3)")
tb = add_table(s, 0.5, 1.95, 12.35, 4.1, [
    ["KPI", "Target (D2.3)", "2D experiment", "3D experiment (this work)", "Status"],
    ["Accuracy (P90 error)", "≤ 5 cm", "4.32 cm\n0.8 × 0.8 m², tilts ≤ 20°",
     ["**4.8 cm** inside the AP half-power cone (4.7 cm with tilts ≤ 15°)", "8.2 cm over the whole sampled region (up to 64° off-nadir)"], "Met in 2D and in the 3D core zone"],
    ["Coverage (single AP)", "2 × 2 × 2 m³", "0.64 m²",
     ["**≈ 2 m³** at P90 ≤ 5 cm (half-power cone, z = 0.4–1.1 m; sampled on one side, symmetric setup)", "positions up to 2 m off-axis located with P90 ≈ 8 cm"], "Partially met"],
    ["Extra latency (excl. steering)", "≤ 20 ms", "a few ms",
     ["**0.02 ms** (GLS) – **0.65 ms** (NLS) computation per fix", "mechanical gimbal: seconds per beam (not optimised)"], "Met (estimator)"],
    ["ISAC compatibility", "yes", "–",
     ["only the **mean power per beam** is used → transparent to the data waveform", "joint data + positioning demo pending integration"], "By design; demo pending"],
], col_w=[2.0, 1.55, 2.2, 4.75, 1.85], size=12, header_size=13, row_h=[0.42, 0.95, 0.95, 0.9, 0.88])
status_fill = [LGREEN, LORANGE, LGREEN, LORANGE]
status_col = [GREEN, ORANGE, GREEN, ORANGE]
for i in range(4):
    c = tb.table.cell(i + 1, 4)
    set_cell(c, tb.table.cell(i + 1, 4).text_frame.text, 12, status_col[i], True, status_fill[i], PP_ALIGN.CENTER)
add_text(s, 0.5, 6.15, 12.35, 0.75, [
    ("Scope: laboratory LED + mechanical gimbal demonstrator; integration with the OPTI-6G optical antennas is the next step (D4.3). "
     "The proposal's sub-cm ambition (RSS + AoA + ToA fusion) is not reached by RSS beam steering alone; the 5 cm target follows the revised KPIs of D2.3.", {"italic": True}),
], size=11.5, color=GRAY)
add_footer(s, "Targets: OPTI-6G D2.3, “Beam-steered based localisation KPIs”. 3D values: NLS estimator, broadcast range. Latency: IEEE Trans. Commun. 2026 (PC implementation).", n)
add_notes(s, "KPIs as defined in D2.3 for the beam-steered method. Accuracy: met in 2D and in 3D inside the AP "
             "half-power cone, 4.8 cm P90; over the whole sampled region it is 8.2 cm. Coverage: about 2 cubic metres at "
             "P90 below 5 cm with a single AP (truncated half-power cone between 0.9 and 1.6 m below the AP; the robot "
             "sampled mainly one side of it, the setup being rotationally symmetric), against 8 cubic metres targeted, "
             "so partially met. Latency: the estimator is "
             "below a millisecond; the mechanical steering is not part of the KPI and is slow in the lab. ISAC: by design, "
             "since only the mean power is used, but the joint demonstration requires the integration with the OPTI-6G "
             "antennas. I want to be explicit that the sub-centimetre ambition of the proposal is not reached by RSS beam "
             "steering alone.")

# =====================================================================  15. ARCHITECTURE
s = content_slide("Integration into the OPTI-6G / 6G Architecture")
add_box(s, 0.5, 1.95, 3.2, 2.3, fill=WHITE, line=MBLUE, line_w=1.5, anchor=MSO_ANCHOR.TOP, text=[
    ("Optical AP (O-RU)", {"bold": True, "color": BLUE, "size": 15}),
    ("optical antenna (Tx/Rx)", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
    ("beam steering: gimbal → MEMS / LC / OPA", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
    ("codebook scheduler: periodic K-beam sweep", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
    ("data downlink continues during the sweep", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
], margins=(0.12, 0.08, 0.1, 0.05))
for dy in (-0.45, 0.0, 0.45):
    add_line(s, 3.75, 3.15, 5.08, 3.15 + dy, color=PURPLE, width=2.25)
add_text(s, 3.68, 1.98, 1.5, 0.6, ["beam sweep **n**_{t,1…K}"], size=11, color=PURPLE, align=PP_ALIGN.CENTER, accent=PURPLE)
add_text(s, 3.68, 3.72, 1.5, 0.5, ["mean power only"], size=11, color=PURPLE, align=PP_ALIGN.CENTER)
add_box(s, 5.13, 1.95, 3.3, 2.3, fill=WHITE, line=MBLUE, line_w=1.5, anchor=MSO_ANCHOR.TOP, text=[
    ("UE (robot, AGV, XR …)", {"bold": True, "color": BLUE, "size": 15}),
    ("single photodiode", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
    ("RSS per beam (e.g. TruPwr™ port of the OPTI-6G antenna)", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
    ("IMU (broadcast mode)", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
    ("estimator GLS / WLS / NLS (< 1 ms)", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
], margins=(0.12, 0.08, 0.1, 0.05))
add_box(s, 9.95, 1.95, 2.9, 1.05, fill=LBLUE, line=MBLUE, line_w=1.5, text=[
    ("Localisation server (NIB / edge)", {"bold": True, "color": BLUE, "size": 13}),
    ("collects positions; fusion with RSS / TDoA", {"size": 11}),
])
add_box(s, 9.95, 3.2, 2.9, 1.05, fill=LBLUE, line=MBLUE, line_w=1.5, text=[
    ("5G core & applications", {"bold": True, "color": BLUE, "size": 13}),
    ("robot / AGV control, XR, digital twin", {"size": 11}),
])
add_line(s, 8.48, 2.45, 9.9, 2.45, color=MBLUE, width=2.25)
add_text(s, 8.45, 2.55, 1.48, 0.6, ["position report", "(OWC uplink)"], size=10, color=GRAY, align=PP_ALIGN.CENTER, space_after=0)
add_line(s, 11.4, 3.02, 11.4, 3.18, color=MBLUE, width=2.25)
add_box(s, 0.5, 4.42, 6.05, 1.75, fill=LPURPLE, line=PURPLE, line_w=1.25, anchor=MSO_ANCHOR.TOP, text=[
    ("UE-based  –  broadcast mode", {"bold": True, "color": PURPLE, "size": 14, "align": PP_ALIGN.LEFT}),
    ("AP announces codebook + beam timing (system information)", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT, "bullet_color": PURPLE}),
    ("each UE computes its own 3D position (needs its orientation)", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT, "bullet_color": PURPLE}),
    ("scales to any number of UEs; uplink only to report", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT, "bullet_color": PURPLE}),
    ("privacy-friendly: the position stays in the UE unless reported", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT, "bullet_color": PURPLE}),
], margins=(0.15, 0.08, 0.12, 0.05))
add_box(s, 6.8, 4.42, 6.05, 1.75, fill=LBLUE, line=MBLUE, line_w=1.25, anchor=MSO_ANCHOR.TOP, text=[
    ("Network-assisted  –  cooperative mode", {"bold": True, "color": BLUE, "size": 14, "align": PP_ALIGN.LEFT}),
    ("UE reports per-beam RSS; server/AP estimates the direction", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
    ("one beam-aligned (K+1) measurement gives the range **and** the beam for the data link (beam management)", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
    ("highest accuracy; per-UE signalling; no IMU needed", {"bullet": True, "size": 12, "align": PP_ALIGN.LEFT}),
], margins=(0.15, 0.08, 0.12, 0.05))
add_box(s, 0.5, 6.28, 12.35, 0.6, fill=WHITE, line=GRAY, line_w=0.75, text=[
    ("**Architecture needs:** codebook & beam-timing signalling · AP pose calibration · RSS / position reporting over the OWC uplink · position exposure to applications",
     {"size": 12.5})], margins=(0.12, 0.02, 0.12, 0.02))
add_footer(s, "Planned OPTI-6G integration: OLEDCOMM optical antenna with up/down-converters and AD8361 TruPwr™ RSS output (D3.2/D4.2); Brunel 5G/6G Autonomous IoT Lab.", n)
add_notes(s, "How it fits the architecture. Positioning becomes a function of the optical RU itself: the AP periodically "
             "sweeps a codebook while data keeps flowing, because only the mean power matters. The UE needs a single "
             "photodiode and an RSS readout; in OPTI-6G this is the TruPwr output of the optical antenna. Two modes: "
             "UE-based broadcast, scalable to any number of UEs, where the codebook and beam timing are announced like "
             "system information; and network-assisted cooperative, where the direction estimate is reused for beam "
             "alignment of the data link. What the architecture must provide: codebook and beam-timing signalling, AP "
             "pose calibration, reporting over the OWC uplink and exposure of the position to applications.")

# =====================================================================  16. TRADE-OFFS / NEXT STEPS
s = content_slide("Trade-offs, Limitations and Next Steps")
def tb(text, col):
    return (text, {"bullet": True, "size": 15, "align": PP_ALIGN.LEFT, "space_after": 10, "bullet_color": col, "accent": col})


add_box(s, 0.5, 1.95, 6.05, 4.9, fill=WHITE, line=ORANGE, line_w=1.5, anchor=MSO_ANCHOR.TOP, text=[
    ("Trade-offs and current limitations", {"bold": True, "color": ORANGE, "size": 17, "align": PP_ALIGN.LEFT, "space_after": 10}),
    tb("**Scan time:** K sequential beams; the lab gimbal needs seconds per orientation (the estimator itself < 1 ms).", ORANGE),
    tb("**Accuracy vs. coverage:** best inside the AP half-power cone; range errors grow beyond ≈ 45° off-nadir.", ORANGE),
    tb("**Mode trade-off:** broadcast needs the UE orientation (IMU); cooperative needs one aligned exchange per UE.", ORANGE),
    tb("**Calibration:** one radiometric constant C per AP / receiver type; ideal Lambertian model assumed.", ORANGE),
    tb("**Line of sight** to the AP is required (as for any optical link).", ORANGE),
], margins=(0.2, 0.15, 0.2, 0.1))
add_box(s, 6.8, 1.95, 6.05, 4.9, fill=WHITE, line=GREEN, line_w=1.5, anchor=MSO_ANCHOR.TOP, text=[
    ("Next steps", {"bold": True, "color": GREEN, "size": 17, "align": PP_ALIGN.LEFT, "space_after": 10}),
    tb("**Solid-state steering** (MEMS, liquid crystal, OPA, switched VCSEL/LED segments) → ms-level fixes and tracking.", GREEN),
    tb("**Pattern-aware / physics-informed calibration** and codebooks optimised for the measured beam.", GREEN),
    tb("**Integration** with the OPTI-6G optical antennas (TruPwr™ RSS, positions over the OWC uplink) at Brunel → D4.3.", GREEN),
    tb("**Multi-AP fusion** in the cell-free network; moving UEs (tracking) and cooperative mode on the testbed.", GREEN),
    tb("**Joint communication + positioning** (ISAC) demonstration; beam-sweep signalling as input to the ArchWG.", GREEN),
], margins=(0.2, 0.15, 0.2, 0.1))
add_footer(s, "", n)
add_notes(s, "Honest trade-offs. The scan is sequential, and our lab gimbal is slow, although the estimator is "
             "sub-millisecond: solid-state steering is the key enabler for real-time tracking. Accuracy is best inside the "
             "AP cone; periphery range errors call for pattern-aware calibration or neighbouring APs. Broadcast needs the "
             "UE orientation, cooperative needs one exchange per UE. Line of sight is required as for any optical link. "
             "Next steps: solid-state steering, physics-informed calibration, integration with the OPTI-6G antennas at "
             "Brunel for D4.3, multi-AP fusion and a joint ISAC demonstration.")

# =====================================================================  17. TAKEAWAYS
s = content_slide("Key Takeaways")
take = [
    ("One AP is enough", "Beam steering at a single optical AP + a single-PD UE yields a 3D position: no anchor constellation, no camera, no PD array."),
    ("Validated in 2D", "2.66 cm RMSE, P90 4.32 cm and 4.8 mm repeatability under random receiver tilts up to 20° (IEEE ICC 2026)."),
    ("Theory for 3D", "Bounds (DEB/PEB), orientation-independent GLS/WLS/NLS estimators, GA codebook; broadcast mode serves any number of UEs from one sweep."),
    ("Demonstrated in 3D", "808 positions, 3,232 fixes: ≈ 1° direction error; median 2.3 cm and P90 4.8 cm inside the AP half-power cone (≈ 2 m³); robust to receiver tilt."),
    ("Architecture-ready", "Positioning as a native, ISAC-compatible function of optical RUs; next: solid-state steering and integration with the OPTI-6G antennas (D4.3)."),
]
cols = [MBLUE, MBLUE, PURPLE, GREEN, BLUE]
for i, (h, t) in enumerate(take):
    y = 1.98 + i * 0.97
    add_box(s, 0.5, y, 12.35, 0.85, fill=WHITE, line=cols[i], line_w=1.0)
    add_number_badge(s, 0.65, y + 0.19, 0.48, i + 1, fill=cols[i], size=16)
    add_text(s, 1.3, y + 0.05, 2.75, 0.75, [h], size=16, bold=True, color=cols[i], anchor=MSO_ANCHOR.MIDDLE)
    add_text(s, 4.05, y + 0.05, 8.7, 0.75, [t], size=14, anchor=MSO_ANCHOR.MIDDLE)
add_footer(s, "This work is part of the EC Horizon Europe project OPTI-6G, Grant Agreement No. 101139292.", n)
add_notes(s, "To conclude: a single steerable optical AP and a single-photodiode UE are enough for 3D positioning. "
             "Validated in 2D, theory for 3D with bounds and efficient estimators, a broadcast mode for many users, and now "
             "a 3D experimental demonstration with about 1 degree direction error and 2.3 cm median / 4.8 cm P90 inside "
             "the AP cone, robust to receiver tilt. For the architecture, positioning becomes a native and ISAC-compatible "
             "function of optical RUs. Thank you.")

# =====================================================================  18. THANK YOU
n += 1
s = prs.slides.add_slide(prs.slide_layouts[L_THANKS])
t = s.shapes.title
t.text = ""
rich_runs(t.text_frame.paragraphs[0], "Thank you for your attention!", 36, RGBColor(0x1F, 0x5F, 0xD6), italic=True)
s.shapes.add_picture(f("opti6g_qr.png"), Emu(10354766), Emu(156794), Emu(1172567), Emu(1143733))
add_text(s, 2.0, 4.55, 9.33, 0.35, ["kevin-jose.acuna-condori@uvsq.fr   ·   bastien.bechadergue@uvsq.fr"],
         size=13, color=GRAY, align=PP_ALIGN.CENTER)
add_notes(s, "Questions.")

prs.save(OUT)
print("saved", OUT, "slides:", len(prs.slides))
