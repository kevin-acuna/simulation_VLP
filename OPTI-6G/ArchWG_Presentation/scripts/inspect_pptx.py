"""Dump text/shapes/images of a pptx (for reviewing manual edits)."""
import sys, hashlib
from pptx import Presentation
from pptx.util import Emu

path = sys.argv[1]
prs = Presentation(path)
E = 914400
for si, s in enumerate(prs.slides, 1):
    print(f"\n=== Slide {si}  layout={s.slide_layout.name}  shapes={len(s.shapes)}")
    for sh in s.shapes:
        try:
            st = sh.shape_type
        except NotImplementedError:
            st = "?"
        pos = f"({sh.left/E:.2f},{sh.top/E:.2f}) {sh.width/E:.2f}x{sh.height/E:.2f}" if sh.width is not None else ""
        line = f"  [{st}] {sh.name!r} {pos}"
        if st == 13:
            line += f" img={hashlib.md5(sh.image.blob).hexdigest()[:8]} {sh.image.size}"
        print(line)
        if sh.has_text_frame:
            for p in sh.text_frame.paragraphs:
                t = "".join(r.text for r in p.runs)
                if t.strip():
                    print(f"      | {t}")
        if getattr(sh, "has_table", False) and sh.has_table:
            for r in sh.table.rows:
                print("      || " + " | ".join(c.text.replace("\n", " / ") for c in r.cells))
    if s.has_notes_slide:
        n = s.notes_slide.notes_text_frame.text.strip()
        if n:
            print("  NOTES:", n)
