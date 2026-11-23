"""Images for the final-meeting deck (24/11/2026), written to assets/.

Run from this folder: py -3.14 make_assets.py   (Pillow; pdftoppm of TeX Live on the PATH)
The D2 figure (make_d2_figure.m), the digital-twin video and the acquisition-tool screenshot are prepared
separately (see the "Cambridge final-meeting deck" section of the root AGENTS.md).
"""
import shutil
import subprocess
import zipfile
from pathlib import Path

from PIL import Image, ImageChops

# ---- hyperparameters --------------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
CAM = HERE.parents[1]                                   # CAMBRIDGE/
OUT = HERE / "assets"
CDF_PDF = CAM / "manuscript/figures/fig_cdf.pdf"        # error CDF of the paper (D2, D3)
ISAC_RECORD = CAM / "isac_colab/data/isac_20261119-185716_grid5x5x1_K5/figures/c00002.png"
ISAC_RECORD_CROP = (14, 52, 776, 326)                   # record with pilot windows / OFDM slots, no title
ISAC_REPORT = CAM / "isac_colab/data/isac_20261123-192424_grid5x5x1_K5/analysis/ISAC_single_LED_results.pdf"
ISAC_SNR_CROP = (220, 220, 875, 862)                    # Fig. 2(a) of page 3 at 300 dpi: link SNR vs pilot RSS
FROM_DECKS = {                                          # images reused from earlier meetings
    "PPTs/2026-11-03 UVSQ Follow-up Meeting.pptx": {
        "image8.png": "demo_ui.png",                    # live demo, real session (D3)
        "image15.png": "proroklab.png",                 # ProrokLab arena (from their video)
        "image19.png": "adt_schematic.png",
        "image14.jpeg": "drone.jpg",
        "image12.png": "testbed_cutout.png",            # testbed photo, background removed
    },
}
CEILING_CROP = (110, 0, 1000, 300)                      # the four LED lamps of testbed_cutout.png
COPIES = {
    "manuscript/fig_inkscape/fig3_testbed_annotated.png": "testbed_annotated.png",
    "analysis/RSS_Distribution/figures/rss_heatmaps_fft_linear.png": "d1_heatmaps.png",
    "photos_videos/ISAC.jpeg": "isac_setup.jpg",        # ISAC set-up with the AWG (user photo)
}
# -------------------------------------------------------------------------------------------------


def trim(path, pad=8):
    """Removes the white margin of an image (keeps `pad` pixels)."""
    im = Image.open(path).convert("RGB")
    box = ImageChops.difference(im, Image.new("RGB", im.size, "white")).convert("L").point(
        lambda v: 255 if v > 12 else 0).getbbox()
    if box:
        im = im.crop((max(box[0] - pad, 0), max(box[1] - pad, 0),
                      min(box[2] + pad, im.width), min(box[3] + pad, im.height)))
    im.save(path)


def pdf_page(pdf, page, dpi, dst):
    subprocess.run(["pdftoppm", "-png", "-r", str(dpi), "-f", str(page), "-l", str(page),
                    "-singlefile", str(pdf), str(dst.with_suffix(""))], check=True)
    return dst


def main():
    OUT.mkdir(exist_ok=True)
    trim(pdf_page(CDF_PDF, 1, 300, OUT / "paper_cdf.png"))
    Image.open(ISAC_RECORD).convert("RGB").crop(ISAC_RECORD_CROP).save(OUT / "isac_record.png")
    page = pdf_page(ISAC_REPORT, 3, 300, OUT / "_isac_report_p3.png")
    Image.open(page).convert("RGB").crop(ISAC_SNR_CROP).save(OUT / "isac_snr_pilot.png")
    page.unlink()
    trim(OUT / "isac_snr_pilot.png")
    for deck, names in FROM_DECKS.items():
        with zipfile.ZipFile(CAM / deck) as z:
            for src, dst in names.items():
                (OUT / dst).write_bytes(z.read(f"ppt/media/{src}"))
    Image.open(OUT / "testbed_cutout.png").crop(CEILING_CROP).save(OUT / "ceiling_leds.png")
    for src, dst in COPIES.items():
        shutil.copyfile(CAM / src, OUT / dst)
    for f in sorted(OUT.iterdir()):
        if f.suffix in (".png", ".jpg"):
            print(f"{f.name:28s} {Image.open(f).size}")


if __name__ == "__main__":
    main()
