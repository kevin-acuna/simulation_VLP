import sys, glob, os
from PIL import Image, ImageDraw

src = sys.argv[1]
out = sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 2
start = int(sys.argv[4]) if len(sys.argv) > 4 else 1
count = int(sys.argv[5]) if len(sys.argv) > 5 else 999
files = sorted(glob.glob(os.path.join(src, "slide_*.png")))[start - 1:start - 1 + count]
ims = [Image.open(f) for f in files]
w, h = ims[0].size
tw = 800
th = int(h * tw / w)
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * tw + (cols + 1) * 10, rows * th + (rows + 1) * 10), "gray")
d = ImageDraw.Draw(sheet)
for i, im in enumerate(ims):
    r, c = divmod(i, cols)
    x, y = 10 + c * (tw + 10), 10 + r * (th + 10)
    sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, y))
    d.rectangle([x, y, x + 60, y + 28], fill="black")
    d.text((x + 6, y + 6), os.path.basename(files[i])[6:8], fill="yellow")
sheet.save(out)
print(out, sheet.size)
