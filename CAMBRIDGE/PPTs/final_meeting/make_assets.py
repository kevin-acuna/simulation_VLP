"""Images for the final-meeting deck (24/11/2026), written to assets/.

Run from this folder: py -3.14 make_assets.py   (Pillow; pdftoppm of TeX Live on the PATH)
The digital-twin video and the acquisition-tool screenshot are prepared separately (see the
"Cambridge final-meeting deck" section of the root AGENTS.md).
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
PAPER_PDF = CAM / "manuscript/.latex-build/main.pdf"
PAPER_PAGES = (1, 7, 10)                                # title page, testbed photo, CDF
PAPER_DPI = 120
PAPER_HIDE = {1: (330, 234, 690, 258)}                # page 1: placeholder line of the draft author list
MAPS_PDF = CAM / "manuscript/figures/fig_maps.pdf"      # RSS maps of the four LEDs
MAPS_DPI = 300
ISAC_FIG = CAM / "isac_colab/data/isac_20261119-185716_grid5x5x1_K5/figures/c00002.png"
ISAC_CROPS = {"isac_record.png": (14, 52, 776, 326),    # record with pilot windows / OFDM slots (no title)
              "isac_constellation.png": (816, 146, 1151, 499)}
FROM_DECKS = {                                          # images reused from earlier meetings
    "PPTs/2026-11-03 UVSQ Follow-up Meeting.pptx": {
        "image8.png": "demo_ui.png",                    # live demo, real session
        "image15.png": "proroklab.png",                 # ProrokLab arena (from their video)
        "image19.png": "adt_schematic.png",
        "image14.jpeg": "drone.jpg",
        "image12.png": "testbed_cutout.png",            # testbed photo, background removed
    },
    "PPTs/2026-10-20 Small groups P3.pptx": {
        "image1.png": "room_schematic.png",             # LED + reorientable PD
        "image14.png": "led_icon.png",
    },
}
CEILING_CROP = (110, 0, 1000, 300)                      # the four LED lamps of testbed_cutout.png
COPIES = {
    "analysis/Executive_summary/fig_zaxis.png": "zaxis.png",
    "photos_videos/ISAC.jpeg": "isac_setup.jpg",                 # ISAC set-up with the AWG (user photo)
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
    stem = dst.with_suffix("")
    subprocess.run(["pdftoppm", "-png", "-r", str(dpi), "-f", str(page), "-l", str(page),
                    "-singlefile", str(pdf), str(stem)], check=True)
    return dst


def main():
    OUT.mkdir(exist_ok=True)
    for p in PAPER_PAGES:
        page = pdf_page(PAPER_PDF, p, PAPER_DPI, OUT / f"paper_p{p:02d}.png")
        if p in PAPER_HIDE:
            im = Image.open(page).convert("RGB")
            im.paste("white", PAPER_HIDE[p])
            im.save(page)
    trim(pdf_page(MAPS_PDF, 1, MAPS_DPI, OUT / "rss_maps.png"))
    fig = Image.open(ISAC_FIG).convert("RGB")
    for name, box in ISAC_CROPS.items():
        fig.crop(box).save(OUT / name)
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
