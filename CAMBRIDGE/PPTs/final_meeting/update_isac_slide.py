"""Updates ONLY the ISAC slide of the final-meeting deck, in place, with the 23/11 session
(isac_20261123-192424_grid5x5x1_K5/analysis/ISAC_single_LED_results.pdf, version of 23/11 22:50).

The deck is edited by hand (links on the software slide, text removed on the ISAC slide): the other slides are not
touched. Back up the deck first (_backup/). Figure: make_isac_link_figure.py (isac_colab venv).
Run from this folder: py -3.14 update_isac_slide.py [--figure-only]
  --figure-only  replaces only the image of the figure (same size and position), nothing else on the slide
"""
import sys
from pathlib import Path

from lxml import etree
from PIL import Image
from pptx import Presentation
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches, Pt

# ---- hyperparameters --------------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
CAM = HERE.parents[1]
A = HERE / "assets"
DECK = CAM / "PPTs/2026-11-24 Final meeting - Visit summary.pptx"
NEW_FIG = A / "isac_link_prediction.png"                         # link SNR at an unvisited orientation
FIG_SLOT = (0.4, 4.2)                                            # top-left of the figure on the slide [in]
FIG_H = 2.3                                                      # figure height [in]
RIGHT = 7.9                                                      # right edge of the text next to the figure [in]
DATA_LABEL = "data (OFDM 64-QAM, 2.27 Mb/s)"
BULLETS = (                                                      # as left by the user on 23/11 (23:31)
    "The pilot RSS predicts the link SNR (±0.5 dB) and ranks the orientations",
    "OFDM training alone gives the same RSS (+0.5 %) and position: without the pilot slot, 1.06 → 2.27 Mb/s",
    "Position + model predict the link SNR at unvisited orientations: 0.31 dB vs ~2 dB",
)
SIZE = 13
# ------------------------------------------------------------------------------------------------


def isac_slide(prs):
    for s in prs.slides:
        for sh in s.shapes:
            if sh.has_text_frame and sh.text_frame.text.strip().startswith("ISAC"):
                return s
    raise RuntimeError("ISAC slide not found")


def figure(slide):
    near = lambda v, ref: abs(Emu(v).inches - ref) < 0.05
    return next(sh for sh in slide.shapes
                if sh.shape_type == 13 and near(sh.left, FIG_SLOT[0]) and near(sh.top, FIG_SLOT[1]))


def replace_figure_image(slide):
    """New image in the existing picture: size, position and everything else unchanged."""
    pic = figure(slide)
    slide.part.related_part(pic._element.blipFill.blip.rEmbed)._blob = NEW_FIG.read_bytes()
    return pic


def update_all(slide):
    old = figure(slide)
    left, top = old.left, old.top
    rid = old._element.blipFill.blip.rEmbed
    old._element.getparent().remove(old._element)
    if not any(b.get(qn("r:embed")) == rid for b in slide.shapes._spTree.iter(qn("a:blip"))):
        slide.part.drop_rel(rid)
    iw, ih = Image.open(NEW_FIG).size
    fig = slide.shapes.add_picture(str(NEW_FIG), left, top, Inches(FIG_H * iw / ih), Inches(FIG_H))
    box = next(sh for sh in slide.shapes if sh.has_text_frame and
               ("One waveform" in sh.text_frame.text or "The pilot RSS predicts" in sh.text_frame.text))
    box.left = fig.left + fig.width + Inches(0.15)
    box.top = top
    box.width = Inches(RIGHT) - box.left
    tf = box.text_frame
    tf.clear()
    first = tf.paragraphs[0]._p
    if first.pPr is not None:                     # clear() keeps the bullet of the old first paragraph
        first.remove(first.pPr)
    for i, t in enumerate(BULLETS):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_after = Pt(5)
        r = p.add_run()
        r.text = t
        r.font.size = Pt(SIZE)
        r.font.name = "Arial"
        ppr = p._p.get_or_add_pPr()
        ppr.set("marL", str(Inches(0.25)))
        ppr.set("indent", str(-Inches(0.25)))
        etree.SubElement(ppr, qn("a:buFont"), typeface="Arial")
        etree.SubElement(ppr, qn("a:buChar"), char="-")
    label = next((sh for sh in slide.shapes if sh.has_text_frame and
                  sh.text_frame.text.strip().startswith("data (OFDM")), None)
    if label is not None:
        label.text_frame.paragraphs[0].runs[0].text = DATA_LABEL
        label.width = Inches(3.4)


def main():
    prs = Presentation(str(DECK))
    s = isac_slide(prs)
    if "--figure-only" in sys.argv:
        replace_figure_image(s)
    else:
        update_all(s)
    prs.save(str(DECK))
    print(f"{DECK.name}: ISAC slide updated ({DECK.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
