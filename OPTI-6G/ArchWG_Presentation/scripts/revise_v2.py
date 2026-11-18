"""Second revision of the ArchWG deck, applied on top of the manually edited version.

* 3D metrics recomputed for the 2 m x 2 m target zone (|x|,|y| <= 1 m, K = 9, NLS),
  figures replaced (exp3_*.png from make_exp3_figures.m).
* KPI table: accuracy/coverage "close to target", latency/ISAC "met".
* Wording reviewed slide by slide (plainer titles and bullets, fewer symbols/highlights),
  new speaker notes, slide numbers fixed after the deletion of the old slide 16.
Input : _backup/OPTI-6G_ArchWG_..._user-edit_2026-11-18_1243.pptx (user version, untouched)
Output: OPTI-6G_ArchWG_Beamsteering_Positioning_UVSQ_2026-11-20.pptx
"""
import os, sys, re
from copy import deepcopy
from lxml import etree
sys.path.insert(0, os.path.dirname(__file__))
from pptx_helpers import *

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "_backup", "OPTI-6G_ArchWG_..._user-edit_2026-11-18_1243.pptx")
OUT = os.path.join(ROOT, "OPTI-6G_ArchWG_Beamsteering_Positioning_UVSQ_2026-11-20.pptx")
FIG = os.path.join(ROOT, "figures")
EMU = 914400

prs = Presentation(SRC)
S = list(prs.slides)


# ----------------------------------------------------------------- helpers
def shape(slide, name):
    for sh in slide.shapes:
        if sh.name == name:
            return sh
    raise KeyError(f"{name} not found on slide")


def _template(p):
    """(pPr, rPr) of a paragraph; rPr taken from the first non-bold run if any."""
    pPr = p._p.find(qn("a:pPr"))
    runs = p._p.findall(qn("a:r"))
    pick = None
    for r in runs:
        rp = r.find(qn("a:rPr"))
        if rp is None or rp.get("b") != "1":
            pick = rp
            break
    if pick is None and runs:
        pick = runs[0].find(qn("a:rPr"))
    allbold = bool(runs) and all((r.find(qn("a:rPr")) is not None and r.find(qn("a:rPr")).get("b") == "1") for r in runs)
    return (deepcopy(pPr) if pPr is not None else None,
            deepcopy(pick) if pick is not None else None, allbold)


NB = " "


def nbsp(t):
    """Keep numbers with their units (and 'a x b' dimensions) on the same line."""
    t = re.sub(r"(\d) (?=(cm|mm|ms|m²|m³|m|%|°)(\W|$))", lambda m: m.group(1) + NB, t)
    t = t.replace(" × ", NB + "×" + NB)
    return t


def _set_color(rPr, rgb):
    for e in rPr.findall(qn("a:solidFill")):
        rPr.remove(e)
    sf = etree.Element(qn("a:solidFill"))
    etree.SubElement(sf, qn("a:srgbClr")).set("val", str(rgb))
    # schema order inside rPr: ln, fill, effect, highlight, uLnTx.., latin, ea, cs, sym, hlinkClick...
    anchor = None
    for tag in ("a:effectLst", "a:highlight", "a:latin", "a:ea", "a:cs", "a:sym", "a:hlinkClick"):
        anchor = rPr.find(qn(tag))
        if anchor is not None:
            break
    if anchor is not None:
        anchor.addprevious(sf)
    else:
        ln = rPr.find(qn("a:ln"))
        if ln is not None:
            ln.addnext(sf)
        else:
            rPr.insert(0, sf)


def set_paras(tf, paras, accent=BLUE):
    """Replace the paragraphs of a text frame, re-using the old paragraph/run formatting.
    paras: list of str or (str, dict(tpl=index, color=RGB, bold=bool, size=pt, accent=RGB)).
    Markup: **bold accent**, _{sub}, ^{sup}."""
    old = list(tf.paragraphs)
    tpls = [_template(p) for p in old] or [(None, None, False)]
    txBody = tf._txBody
    for p in old:
        txBody.remove(p._p)
    for i, item in enumerate(paras):
        txt, opt = (item if isinstance(item, tuple) else (item, {}))
        pPr, rPr, allbold = tpls[min(opt.get("tpl", i), len(tpls) - 1)]
        txt = nbsp(txt)
        p = etree.SubElement(txBody, qn("a:p"))
        if pPr is not None:
            p.append(deepcopy(pPr))
        for tok in TOKEN.split(txt):
            if not tok:
                continue
            r = etree.SubElement(p, qn("a:r"))
            rp = deepcopy(rPr) if rPr is not None else etree.Element(qn("a:rPr"))
            r.append(rp)
            for a in ("b", "baseline"):
                if a in rp.attrib:
                    del rp.attrib[a]
            if opt.get("bold", allbold):
                rp.set("b", "1")
            if "size" in opt:
                rp.set("sz", str(int(opt["size"] * 100)))
            if "color" in opt:
                _set_color(rp, opt["color"])
            if tok.startswith("**") and tok.endswith("**"):
                tok = tok[2:-2]
                rp.set("b", "1")
                _set_color(rp, opt.get("accent", accent))
            elif tok.startswith("_{"):
                tok = tok[2:-1]
                rp.set("baseline", "-25000")
            elif tok.startswith("^{"):
                tok = tok[2:-1]
                rp.set("baseline", "30000")
            etree.SubElement(r, qn("a:t")).text = tok


def set_text(slide, name, paras, **kw):
    set_paras(shape(slide, name).text_frame, paras, **kw)


def set_title(slide, text):
    set_paras(slide.shapes.title.text_frame, [text])


def set_card(slide, name, value, label, color=None):
    sh = shape(slide, name)
    tf = sh.text_frame
    vcol = color if color is not None else tf.paragraphs[0].runs[0].font.color.rgb
    set_paras(tf, [(value, {"tpl": 0, "color": vcol, "bold": True}), (label, {"tpl": 1})])
    if color is not None:
        sh.line.color.rgb = color


def set_cell_text(cell, paras, fill=None, color=None, bold=None):
    opts = {}
    if color is not None:
        opts["color"] = color
    if bold is not None:
        opts["bold"] = bold
    set_paras(cell.text_frame, [(p, dict(opts)) if isinstance(p, str) else p for p in paras])
    if fill is not None:
        cell.fill.solid()
        cell.fill.fore_color.rgb = fill


def replace_picture(slide, name, path, width_in=None):
    old = shape(slide, name)
    w = Inches(width_in) if width_in else old.width
    left = int((prs.slide_width - w) / 2) if width_in else old.left
    new = slide.shapes.add_picture(path, left, old.top, width=w)
    old._element.addprevious(new._element)
    old._element.getparent().remove(old._element)
    new.name = name
    return new


def delete(slide, *names):
    for nm in names:
        el = shape(slide, nm)._element
        el.getparent().remove(el)


def notes(slide, text):
    slide.notes_slide.notes_text_frame.text = text


def fix_number(slide, idx):
    for sh in slide.shapes:
        if (sh.has_text_frame and re.fullmatch(r"\d{1,2}", sh.text_frame.text.strip() or "x")
                and abs(sh.left / EMU - 12.35) < 0.05 and sh.top / EMU > 6.9):
            set_paras(sh.text_frame, [str(idx)])


# =========================================================== 1  Title
s = S[0]
set_text(s, "Title 2", ["Location from OWC Beam Steering", "from a Single Access Point",
                        "3D positioning with one steerable LED and one photodiode"])
set_text(s, "Text Placeholder 1", ["Kevin Acuña-Condori, Bastien Béchadergue, Hongyu Guan and Luc Chassagne",
                                   "Université Paris-Saclay, UVSQ, LISV – OPTI-6G WP4, Task 4.2"])
set_text(s, "TextBox 3", ["SNS JU 6G Architecture Working Group, 20 November 2026"])
notes(s, "Good morning, and thank you John and Bastien for the invitation. I am Kevin Acuña-Condori from UVSQ, LISV. "
         "In OPTI-6G Task 4.2 I have been working on positioning with a single optical access point whose beam can be "
         "steered. I will start with the idea and a short summary of the 2D results, then spend most of the time on the "
         "3D part, the theory and the measurements we did this summer, and finish with the KPIs and how this could fit "
         "in the OPTI-6G architecture.")

# =========================================================== 2  Motivation
s = S[1]
set_title(s, "Positioning with a Single Optical Access Point")
set_text(s, "TextBox 2", [
    "In 6G (IMT-2030), positioning is expected as a network service, with cm-level accuracy indoors for robots, AGVs and XR.",
    "In OPTI-6G, each optical AP (O-RU) of the cell-free network can also serve as a positioning anchor.",
    "Optical RSS or TDoA positioning usually needs 3 to 4 APs in line of sight at the same time, identified and calibrated.",
    "Optical cells are small and directional, so a UE often sees only one AP.",
    "Receiver-side solutions (PD arrays, cameras, rotating PDs) increase the cost of every UE.",
])
set_text(s, "Rounded Rectangle 3", [
    "Proposed approach",
    "The AP steers its beam through K known directions and the UE, with a single photodiode, estimates its 3D position from the received powers.",
])
tbl = shape(s, "Table 8").table
for r in range(1, 5):
    c = tbl.cell(r, 2)
    set_cell_text(c, [c.text_frame.text], color=DARK, bold=False)
notes(s, "Why a single access point? Positioning is becoming a network service in 6G, and indoor use cases such as robots "
         "or AGVs need a few centimetres. Classical optical RSS or TDoA needs three or four APs in view at the same time, "
         "which is not obvious with small, directional optical cells, and adding hardware to every UE is not attractive "
         "either. The idea, already written in the OPTI-6G proposal, is to create the angular diversity at the AP by "
         "steering its beam, and to keep a single photodiode in the UE.")

# =========================================================== 3  Principle
s = S[2]
set_title(s, "Positioning Principle")
set_text(s, "TextBox 3", ["The AP at **t** is steered to K known orientations **n**_{t,i}. The UE has a single PD at an unknown position **r**, with an unknown orientation **n**_{r}."])
set_text(s, "Rounded Rectangle 4", ["Only the **average received power** of each beam is used, so the same light can still carry data."], accent=GREEN)
set_text(s, "TextBox 7", ["Beam sweep"])
set_text(s, "TextBox 8", ["The AP points its beam in K known directions (the codebook) and the UE measures the mean received power for each one."])
set_text(s, "TextBox 12", ["Direction estimation"])
set_text(s, "TextBox 13", ["Power ratios cancel η (distance, Tx power, PD gain, receiver tilt) and give linear constraints on **n**_{d}, solved in closed form (GLS/WLS) or by NLS."])
set_text(s, "TextBox 17", ["Distance and 3D position"])
set_text(s, "TextBox 18", ["Cooperative: one extra measurement with the beam on the UE (K+1). Broadcast: closed form from the same K powers, with **n**_{r} from an IMU."])
notes(s, "The principle in three steps. The AP points its beam in K known directions and the UE only measures the mean "
         "received power for each of them. If we take the ratio between two of these powers, everything that is common "
         "cancels: distance, transmit power, PD gain and also the receiver orientation. Each ratio is a linear constraint "
         "on the direction, and with three or more beams the direction comes out in closed form, or from a nonlinear fit. "
         "The distance is then obtained either with one extra measurement where the beam is aligned on the UE, the "
         "cooperative mode, or directly from the same K powers if the UE knows its orientation, the broadcast mode.")

# =========================================================== 4  Timeline
s = S[3]
set_title(s, "Timeline of the Beam-Steering Method")
set_text(s, "Rounded Rectangle 5", ["2025", "Orientation of the source modulated instead of adding anchors (2D, simulation)", "Chassagne et al., Opt. Express 2025"])
set_text(s, "Rounded Rectangle 8", ["2025–26", "SVD ratio estimator on a testbed: 2.66 cm RMSE under random tilts", "IEEE ICC 2026, OPTI-6G D4.2"])
set_text(s, "Rounded Rectangle 11", ["2026", "Error bounds, GLS/WLS/NLS estimators and codebook design; about 2 cm in simulation", "IEEE Trans. Commun. 2026"])
set_text(s, "Rounded Rectangle 14", ["2026", "Distance from the same K powers and an IMU; 1.73 cm RMS in simulation", "Manuscript in preparation"])
set_text(s, "Rounded Rectangle 17", ["2026", "808 positions, 4 receiver orientations each; P90 1.9 cm with ML in the 2 m × 2 m zone", "Journal paper in preparation"])
set_text(s, "Rounded Rectangle 18", ["In this talk: a short 2D summary, then the 3D theory and the 3D experiments"])
notes(s, "A quick timeline. The concept was published in Optics Express in 2025, in 2D and in simulation. We then "
         "validated it in 2D on our test bench; this was presented at ICC this year and is reported in D4.2. The 3D theory, "
         "with bounds and estimators, is in IEEE Transactions on Communications, and the broadcast extension is being "
         "written. The newest part is the 3D measurement campaign, which is the main topic today.")

# =========================================================== 5  2D validation
s = S[4]
set_title(s, "2D Experimental Validation (ICC 2026)")
set_text(s, "TextBox 3", ["LISV test bench: IR LED on a 2-axis motorised gimbal (ceiling), single PD on a UR5 robot arm"])
set_card(s, "Rounded Rectangle 6", "2.66 cm", "RMSE, all positions and tilts")
set_card(s, "Rounded Rectangle 8", "4.32 cm", "P90 error (target: 5 cm)")
set_card(s, "Rounded Rectangle 9", "4.8 mm", "spread of the 10 estimates of a position (WRMS)")
set_text(s, "Rounded Rectangle 10", [
    "Setup",
    "0.8 × 0.8 m² area, K = 3 AP orientations (20° tilt, azimuths 0/120/240°), 18 positions with 10 random receiver tilts each "
    "(up to 20°), 1000 samples per orientation, closed-form SVD estimator, extra latency of a few ms."])
set_text(s, "Rounded Rectangle 11", [
    "Comparison with fixed LEDs",
    "In simulation (3 × 3 m², random receiver tilt up to 20°) the P90 error is **3.16 cm** with one steered LED and "
    "**34.45 cm** with four fixed LEDs (classical RSS). An ML-assisted version reached 2.8 cm over 1.8 × 1.8 m² (D2.3)."],
    accent=GREEN)
notes(s, "The 2D validation, briefly. It is the same bench as in 3D: an IR LED on a two-axis gimbal at the ceiling and "
         "one photodiode on a UR5 arm. Three AP orientations, 18 positions, and ten random receiver tilts up to 20 degrees "
         "at each position. We get 2.66 cm RMSE and a P90 of 4.3 cm, so within the 5 cm target, and the ten estimates of a "
         "position stay within about 5 mm of each other despite the tilts. In simulation, four fixed LEDs degrade to 34 cm "
         "under the same tilts, while the steered LED stays around 3 cm.")

# =========================================================== 6  3D theory
s = S[5]
set_title(s, "3D Extension: Bounds and Estimators")
set_card(s, "Rounded Rectangle 7", "−49 to −72 %", "median DEB with a GA codebook vs. random sets")
set_card(s, "Rounded Rectangle 9", "< 3 %", "loss of direction accuracy with random receiver tilt")
set_card(s, "Rounded Rectangle 10", "0.02–0.65 ms", "computation time per fix (GLS to NLS)")
set_text(s, "TextBox 11", [
    "Cramér–Rao bounds for the direction (DEB) and 3D position (PEB); GLS (closed form), WLS (simplified) and NLS (iterative) estimators, all independent of the receiver orientation.",
    "The codebook (set of K orientations) is optimised offline with a genetic algorithm. More beams improve accuracy but lengthen the scan.",
    "Simulation: 3 × 3 × 2 m³ room, 1,792 positions, 1,000 noise realisations each.",
])
notes(s, "For 3D we first worked on the theory. We derived Cramér–Rao bounds for the direction and for the position, and "
         "three estimators: GLS in closed form, a lighter WLS, and an iterative NLS which is the closest to the bound. None "
         "of them needs the receiver orientation to find the direction. The orientations are chosen offline with a genetic "
         "algorithm, which halves the median direction bound compared with random sets. With five beams the simulation "
         "gives about half a degree in direction and 2 cm in position, and the computation stays below one millisecond.")

# =========================================================== 7  Broadcast
s = S[6]
set_title(s, "Broadcast Mode for Several UEs")
set_text(s, "TextBox 3", ["Simulation: three UEs (robot vacuum, pedestrian, AGV) tracked at the same time from the same sweeps (K = 9, NLS)"])
set_card(s, "Rounded Rectangle 6", "× 1.3–1.5", "RMS bound compared with the cooperative mode (K ≥ 5)")
set_card(s, "Rounded Rectangle 7", "No limit", "on the number of UEs served by one sweep; no uplink needed")
set_text(s, "TextBox 8", [
    "**Cooperative mode:** one extra aligned measurement per UE (K+1). Best accuracy, but the cost grows with the number of UEs.",
    "**Broadcast mode:** the AP repeats the same sweep for everybody and each UE computes its distance from the K powers and its own orientation (IMU).",
    "Similar in spirit to the SSB beam sweep of 5G NR, with UE-based positioning.",
    "The 3D experiments shown next use the broadcast mode.",
])
notes(s, "One limitation of the cooperative mode is that each UE needs its own aligned measurement. In broadcast mode the "
         "AP simply repeats the same sweep, a bit like the SSB beam sweep in 5G, and every UE computes its own position "
         "using its orientation from an IMU. The bound is 30 to 50 percent higher, but the number of UEs is not limited. "
         "Here three different users are tracked at the same time in simulation. The experiments use this broadcast mode.")

# =========================================================== 8  3D test bench
s = S[7]
set_title(s, "3D Experimental Test Bench at UVSQ-LISV")
tbl = shape(s, "Table 3").table
set_cell_text(tbl.cell(2, 1), ["2-axis motorised gimbal, 2 × Thorlabs PRM1Z8 (0.1° resolution)"])
set_cell_text(tbl.cell(3, 1), ["Φ_{1/2} = 36.7°, i.e. Lambertian order m = 3.13"])
set_cell_text(tbl.cell(4, 1), ["12 orientations recorded, 9 used (3 at 16°, 6 at 60–64°), optimised for this beam"])
set_cell_text(tbl.cell(9, 1), ["GLS, WLS or NLS for the direction, broadcast mode for the distance; one calibration constant C (measured under the AP), no training data"])
notes(s, "This is the 3D bench. The AP is a 940 nm LED on the motorised gimbal at 2 m. The UE is a BPX61 photodiode with "
         "a transimpedance amplifier, held by the UR5 arm, which gives us the ground truth. We moved the robot to 15 base "
         "positions to cover the room. At each position we recorded 12 orientations and used 9 of them, first with the PD "
         "vertical and then with three random tilts. The processing is model-based only, with a single calibration constant.")

# =========================================================== 9  LED pattern and codebook
s = S[8]
set_title(s, "LED Radiation Pattern and Beam Codebook")
set_text(s, "TextBox 6", [
    "The measured profile follows a Lambertian law (m = 3.13) up to about 60°, so the ideal model is kept.",
    "The 9 beams (3 inner, 6 outer) cover about 3 × 3 m at UE height.",
    "A single calibration constant C, measured directly under the AP.",
    "Only the mean power of each beam is used.",
])
notes(s, "Before positioning we measured the LED pattern. It follows a Lambertian law quite well up to about 60 degrees, so "
         "we kept the ideal model in the estimators. On the right are the half-power footprints of the nine beams at UE "
         "height: three inner and six outer beams covering about three by three metres. The dots are the measured positions.")

# =========================================================== 10 Campaign
s = S[9]
set_title(s, "3D Measurement Campaign")
replace_picture(s, "Picture 2", os.path.join(FIG, "exp3_3D_error_map.png"))
set_card(s, "Rounded Rectangle 5", "3,232", "3D fixes (vertical PD + 3 random tilts per position)")
set_card(s, "Rounded Rectangle 6", "38,784", "beam power measurements in 22 sessions")
set_text(s, "TextBox 7", [
    "0.2 m grid, up to 2 m from the AP axis (64° from nadir); 577 positions are inside the 2 m × 2 m target zone (dashed box).",
    "All estimators run on the same data, without training or fingerprinting.",
    "Colour: 3D error (NLS, vertical PD). A few cm under the AP, larger towards the edges.",
])
notes(s, "The campaign: 808 positions on a 0.2 m grid at eight heights, between 0.9 and 1.6 m below the AP, and up to 2 m "
         "away from its axis. 577 of them are inside the 2 m by 2 m target zone, shown by the dashed box. With the four "
         "receiver orientations this gives 3,232 fixes. The colour is the 3D error: a few centimetres under the AP, larger "
         "at the edges.")

# =========================================================== 11 Results
s = S[10]
set_title(s, "3D Localisation Results")
replace_picture(s, "Picture 2", os.path.join(FIG, "exp3_cdf_direction_position.png"), width_in=10.55)
set_card(s, "Rounded Rectangle 3", "1.0°", "mean direction error (all 808 positions)")
set_card(s, "Rounded Rectangle 4", "3.7 cm", "median 3D error (all 808 positions)")
set_card(s, "Rounded Rectangle 5", "2.9 / 5.5 cm", "median / P90 in the 2 m × 2 m target zone", color=BLUE)
set_card(s, "Rounded Rectangle 6", "8.2 cm", "P90 including the positions outside the target zone")
set_text(s, "TextBox 7", ["UVSQ-LISV campaign, Jul.–Sep. 2026. Target zone: |x|, |y| ≤ 1 m under the AP (577 of 808 positions)."])
notes(s, "The main numbers. On the left, the direction error is about one degree, and the vertical and tilted receivers "
         "give almost the same curves. On the right, the 3D error. Over all positions the median is 3.7 cm and the P90 "
         "8.2 cm, but this includes points well outside the target zone. Inside the 2 m by 2 m zone the median is 2.9 cm and "
         "the P90 is 5.5 cm, so just above the 5 cm target; 84 percent of the positions are below 5 cm. NLS is the best "
         "estimator, with GLS close behind. On the next slide I show what a simple machine-learning correction adds.")

# =========================================================== 12 Error analysis
s = S[11]
set_title(s, "Error Analysis")
replace_picture(s, "Picture 2", os.path.join(FIG, "exp3_topview_median_error.png"))
set_text(s, "TextBox 3", ["Median 3D error per (x, y) over the 8 heights. Black square: 2 m × 2 m target zone; dashed circles: AP half-power footprint at z = 1.1, 0.75 and 0.4 m."])
set_text(s, "TextBox 5", [
    "The direction error stays around 1° at all angles, i.e. a lateral error of 1.5–3 cm.",
    "Above about 45° from nadir the distance error dominates (12 cm median between 55 and 70°).",
    "Likely causes: lower SNR and model mismatch at large angles (tails of the LED pattern, PD angular response, single C).",
    "Possible fixes: use the measured LED pattern, add outer beams, or rely on a neighbouring AP at the edges.",
])
# user annotation: keep the label and the arrow; the square itself is now drawn in the figure
delete(s, "Rectangle 8")
lab = shape(s, "TextBox 9")
set_paras(lab.text_frame, [("2 m × 2 m target zone", {"bold": True})])
for r in lab.text_frame.paragraphs[0].runs:
    r.font.name = FONT
    r.font.size = Pt(14)
    r.font.color.rgb = DARK
pic = shape(s, "Picture 2")
sq_top = (pic.top + 0.1771 * pic.height) / EMU      # square top edge, located on the probe export
arrow = shape(s, "Straight Arrow Connector 13")
arrow.begin_x, arrow.begin_y = Inches(3.30), Inches(1.80)
arrow.end_x, arrow.end_y = Inches(3.12), Inches(sq_top - 0.01)
notes(s, "Where does the error come from? The map shows the median error per position, and the black square is the target "
         "zone. If we split the error, the direction part stays around one degree everywhere, which is 1.5 to 3 cm "
         "laterally. What grows beyond 45 degrees from nadir is the distance part, so mainly at the corners of the zone and "
         "outside it. We think it comes from the model at large angles: weaker signal, the tails of the LED pattern, the PD "
         "angular response and the single calibration constant. Using the measured pattern, adding outer beams or using a "
         "neighbouring AP are the obvious ways to improve it.")

# =========================================================== 13 Receiver orientation
s = S[12]
set_title(s, "Sensitivity to Receiver Orientation")
replace_picture(s, "Picture 2", os.path.join(FIG, "exp3_tilt_robustness.png"), width_in=10.0)
set_card(s, "Rounded Rectangle 3", "0.28°", "spread of the direction over the 4 receiver orientations of a position (about 0.9 cm)")
set_card(s, "Rounded Rectangle 4", "1.03° / 1.08°", "mean direction error, vertical / tilted PD (NLS)")
set_card(s, "Rounded Rectangle 5", "2.9 / 3.0 cm", "median 3D error in the target zone, vertical / tilted PD (P90 5.5 / 6.3 cm)")
set_text(s, "TextBox 6", ["UVSQ-LISV campaign, Jul.–Sep. 2026. Tilts drawn uniformly in 0–15° (mean 7.6°) with random azimuth; the receiver orientation is used only for the distance."])
notes(s, "Receiver orientation. Each position was measured with the PD vertical and with three random tilts. On the left, "
         "point by point, the direction error with tilt versus without: the points sit on the diagonal, and the four "
         "estimates of a position are within 0.28 degrees of each other. So the direction does not depend on the receiver "
         "orientation, as the theory says. The distance does use the orientation, so the 3D error degrades a little with "
         "tilt: in the target zone the median goes from 2.9 to 3.0 cm and the P90 from 5.5 to 6.3 cm.")

# =========================================================== 14 KPI table
s = S[13]
set_title(s, "KPI Assessment (OPTI-6G D2.3)")
tbl = shape(s, "Table 2").table
set_cell_text(tbl.cell(1, 2), ["**1.9 cm** (Extra-Trees) and **2.6 cm** (neural network) in the 2 m × 2 m target zone, on locations not used for training",
                               "model only: 5.5 cm (median 2.9 cm); 4.8 cm inside the AP half-power cone"])
set_cell_text(tbl.cell(2, 2), ["whole 2 m × 2 m footprint tested at 8 heights, 0.9–1.6 m below the AP (0.7 m of the 2 m height)",
                               "P90 below 5 cm over the whole footprint with the ML correction"])
set_cell_text(tbl.cell(3, 2), ["**0.65 ms** (NLS) + **0.1 ms** (neural network) or **8.5 ms** (Extra‑Trees) per fix",
                               "mechanical gimbal: seconds per beam (not optimised)"])
set_cell_text(tbl.cell(4, 2), ["only the **mean power** of each beam is used, the data waveform is not modified"])
for r, (lines, col, fill) in enumerate([
        (["Met with ML", "(2D: 4.3 cm)"], GREEN, LGREEN),
        (["Met with ML"], GREEN, LGREEN),
        (["Met"], GREEN, LGREEN),
        (["Met by design"], GREEN, LGREEN)], start=1):
    set_cell_text(tbl.cell(r, 3), lines, fill=fill, color=col, bold=True)
set_text(s, "TextBox 3", ["Results from the UVSQ laboratory demonstrator (IR LED on a mechanical gimbal); integration with the OPTI-6G "
                          "optical antennas is planned for D4.3. The sub-cm goal of the proposal (RSS + AoA + ToA fusion) is not reached "
                          "at P90 (1.9 cm with ML); the 5 cm target is the revised KPI of D2.3."])
set_text(s, "TextBox 4", ["Targets: OPTI-6G D2.3 (TP10: at least 4 m² per AP). 3D: broadcast mode, zone |x|, |y| ≤ 1 m; ML: 5-fold CV by location. "
                          "Latency: PC implementation."])
notes(s, "Against the D2.3 KPIs. With the model alone we are at 5.5 cm P90 in the 2 m by 2 m target zone. With the ML "
         "correction, evaluated only on locations that were not used for training, the P90 is 1.9 cm with Extra-Trees and "
         "2.6 cm with the neural network, so accuracy and coverage are met over the whole footprint; we could only test 0.7 m "
         "of the 2 m height. The latency, including the ML step, stays below about 10 ms per fix; the mechanical steering is "
         "excluded by the KPI definition. ISAC compatibility is met by design, since only the mean power is used. These are "
         "results of the laboratory demonstrator; the integration with the OPTI-6G antennas is the next step.")

# =========================================================== 15 Architecture
s = S[14]
set_title(s, "Integration in the OPTI-6G Architecture")
set_text(s, "Rounded Rectangle 2", ["Optical AP (O-RU)", "optical antenna (Tx/Rx)", "beam steering: gimbal now, MEMS, LC or OPA later",
                                    "periodic sweep of the K-beam codebook", "data downlink continues during the sweep"])
set_text(s, "Rounded Rectangle 8", ["UE (robot, AGV, XR…)", "single photodiode", "RSS per beam (e.g. TruPwr™ port of the OPTI-6G antenna)",
                                    "IMU (broadcast mode)", "GLS, WLS or NLS estimator (< 1 ms)"])
set_text(s, "Rounded Rectangle 9", ["Localisation server (NIB / edge)", "collects the positions, fusion with RSS and TDoA"])
set_text(s, "Rounded Rectangle 14", ["UE-based (broadcast mode)",
                                     "the AP announces the codebook and the beam timing (system information)",
                                     "each UE computes its 3D position (it needs its own orientation)",
                                     "no limit on the number of UEs; uplink used only for reporting",
                                     "the position stays in the UE unless it is reported"])
set_text(s, "Rounded Rectangle 15", ["Network-assisted (cooperative mode)",
                                     "the UE reports the RSS of each beam and the server estimates the direction",
                                     "one aligned measurement (K+1) gives the distance and the beam direction for the data link",
                                     "best accuracy and no IMU, but signalling per UE"])
set_text(s, "Rounded Rectangle 16", ["Needed from the architecture: signalling of the codebook and beam timing, calibration of the AP pose, "
                                     "RSS or position reports over the OWC uplink, and access to the position for applications."])
notes(s, "How this could fit in the architecture. Positioning becomes a function of the optical RU: it sweeps a codebook "
         "periodically while the downlink continues. The UE needs one photodiode and an RSS output, which the OPTI-6G antenna "
         "already provides through its TruPwr port. In broadcast mode the codebook and timing are announced and each UE "
         "computes its own position. In cooperative mode the UE reports the powers, and the direction estimate can be reused "
         "to align the beam of the data link. What we need from the architecture is mainly signalling of the codebook and "
         "timing, calibration of the AP, reporting over the uplink and access to the position for applications.")

# =========================================================== 16 Conclusions (rows -> plain bullets)
s = S[15]
set_title(s, "Conclusions")
delete(s, *[f"Rounded Rectangle {i}" for i in (2, 6, 10, 14, 18)],
          *[f"Oval {i}" for i in (3, 7, 11, 15, 19)],
          *[f"TextBox {i}" for i in (4, 5, 8, 9, 12, 13, 16, 17, 20, 21)])
add_text(s, 0.55, 2.05, 12.2, 4.75, [
    ("A single steerable optical AP and a single-PD receiver are enough to estimate a 3D position, without anchor constellation, camera or PD array.", {"bullet": True}),
    ("2D validation (ICC 2026): RMSE 2.66 cm and P90 4.32 cm with random receiver tilts up to 20°.", {"bullet": True}),
    ("3D theory (IEEE TCOM): error bounds and GLS/WLS/NLS estimators that do not depend on the receiver orientation; the broadcast mode serves any number of UEs with one sweep.", {"bullet": True}),
    ("3D experiments (808 positions, 3,232 fixes): direction error around 1°; in the 2 m × 2 m target zone the P90 is 5.5 cm with the model alone and 1.9 to 2.6 cm with an ML correction trained on other locations; low sensitivity to receiver tilt.", {"bullet": True}),
    ("Next: faster (non-mechanical) steering, a better model at large angles, and integration with the OPTI-6G optical antennas for D4.3.", {"bullet": True}),
], size=18, space_after=16)
notes(s, "To conclude: one steerable AP and a single photodiode are enough for 3D positioning. It works in 2D within the "
         "target, the 3D theory is published, and the 3D measurements give about one degree in direction. In the target zone "
         "the model alone reaches 5.5 cm P90, and with a simple ML correction we get 1.9 to 2.6 cm, below the 5 cm target. The next steps are faster steering, a better model "
         "at large angles and the integration with the OPTI-6G antennas for D4.3. Thank you.")

# =========================================================== 17 Thank you
s = S[16]
set_text(s, "TextBox 3", ["kevin-jose.acuna-condori@uvsq.fr  /  bastien.bechadergue@uvsq.fr"])

# =========================================================== new slide 12: ML correction
s = prs.slides.add_slide(prs.slide_layouts[0])
remove_placeholder(s, 1)
t = s.shapes.title
t.text = ""
rich_runs(t.text_frame.paragraphs[0], "Machine-Learning Correction of the 3D Estimate", 30, DARK)
add_image(s, os.path.join(FIG, "exp3_ml_cdf.png"), 0.45, 1.95, w=7.1, h=4.85)
add_card(s, 7.8, 1.95, 2.45, 0.95, "1.9 cm", nbsp("P90, Extra-Trees (median 0.8 cm)"), color=GREEN, vsize=22, lsize=11)
add_card(s, 10.4, 1.95, 2.45, 0.95, "2.6 cm", nbsp("P90, neural network (median 1.3 cm)"), color=PURPLE, vsize=22, lsize=11)
add_text(s, 7.8, 3.1, 5.05, 3.8, [
    ("Two standard regressors: Extra-Trees (500 trees) and a neural network (MLP with 128 and 64 neurons).", {"bullet": True}),
    ("Input: NLS estimate, RSS of the 9 beams and receiver orientation (IMU). Output: correction of the NLS position.", {"bullet": True}),
    ("Training and test on different locations: 5-fold cross-validation grouped by location, the 4 fixes of a location stay in the same fold.", {"bullet": True}),
    ("Target zone: P90 from 5.5 cm (model only) to 1.9 and 2.6 cm with a vertical PD, 2.5 and 3.5 cm with a tilted PD.", {"bullet": True}),
    ("Check with whole sessions left out: P90 3.0 and 3.5 cm. Inference: 8.5 and 0.1 ms per fix.", {"bullet": True}),
], size=13, space_after=6)
add_footer(s, "UVSQ-LISV campaign, Jul.–Sep. 2026. Target zone |x|, |y| ≤ 1 m: 577 positions (vertical PD), 1,731 tilted fixes. scikit-learn 1.7.", 12)
notes(s, "To close the gap to the 5 cm target we added a machine-learning step on top of the model. We kept it simple: two "
         "standard regressors, Extra-Trees and a small neural network. They take the NLS estimate, the nine beam powers and "
         "the receiver orientation, and they learn the correction of the NLS position, mainly the distance bias at large "
         "angles. Training and test never share a location: we use five-fold cross-validation grouped by location. In the "
         "target zone the P90 goes from 5.5 cm to 1.9 cm with Extra-Trees and 2.6 cm with the neural network; with a tilted "
         "receiver it is 2.5 and 3.5 cm. If we leave out whole measurement sessions, which is a stricter test, we still get "
         "3.0 and 3.5 cm. The inference takes a few milliseconds at most.")
lst = prs.slides._sldIdLst
new_id = lst[-1]
lst.remove(new_id)
lst.insert(11, new_id)

# ----------------------------------------------------------- slide numbers
final = list(prs.slides)
for i, s in enumerate(final, start=1):
    if 1 < i < len(final):
        fix_number(s, i)

prs.save(OUT)
print("saved", OUT, len(prs.slides), "slides")
