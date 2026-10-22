"""Repaints the station's name signs (the model's SIGNS texture says 'Malmberg Platz', line 'U7') with new station names.
Usage: python3 tools/metro_signs.py <original SIGNS png> <out dir>"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

def xf(img):
    """The texture is stored rotated and mirrored: text drawn upright goes through this to look like the original."""
    return img.rotate(90, expand=True).transpose(Image.FLIP_TOP_BOTTOM)

def text_img(text, length, thick, fill, stroke=0, stroke_fill=(0, 0, 0)):
    size = 200
    f = ImageFont.truetype(FONT, size)
    probe = Image.new("RGBA", (4000, 400), (0, 0, 0, 0))
    ImageDraw.Draw(probe).text((10, 10), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)
    bb = probe.getbbox()
    t = probe.crop(bb)
    k = min(length / t.size[0], thick / t.size[1])
    return t.resize((max(1, int(t.size[0] * k)), max(1, int(t.size[1] * k))), Image.LANCZOS)

def clear(arr, box, ref_rows, axis_cols=True):
    """Fill box (x0,y0,x1,y1) from a clean reference row, column by column (keeps the board's shading)."""
    x0, y0, x1, y1 = box
    ref = arr[ref_rows[0]:ref_rows[1], x0:x1].mean(axis=0)
    arr[y0:y1, x0:x1] = ref[None, :, :]

def paste_center(im, t, cx, cy):
    t = xf(t)
    im.paste(t, (int(cx - t.size[0] / 2), int(cy - t.size[1] / 2)), t)

def make(src, name, out):
    im = Image.open(src).convert("RGB")
    arr = np.array(im).astype(np.float32)
    # white boards: the name, the line badge
    for (x0, x1) in [(352, 462), (518, 612)]:
        clear(arr, (x0, 285, x1, 812), (215, 275))
    # blue line badges at the top of both boards
    for (bx0, bx1) in [(298, 384), (464, 548)]:
        blue = arr[60:70, bx0 + 5:bx0 + 10].mean(axis=(0, 1))
        arr[34:108, bx0 + 6:bx1 - 2] = blue
    # green wall strip
    clear(arr, (56, 70, 205, 945), (950, 990), True) if False else None
    g = arr[40:60, 56:205].mean(axis=0)
    arr[70:945, 56:205] = g[None, :, :]
    # the route map and its badge: plain board colour
    board = np.array([236.0, 235.0, 228.0])
    arr[505:1000, 650:848] = board
    im = Image.fromarray(np.clip(arr, 0, 255).astype("uint8"))
    # new text
    black = (0, 0, 0, 255)
    for cx in (407, 570):
        paste_center(im, text_img(name, 485, 66, black), cx, 545)
    for cx in (341, 506):
        paste_center(im, text_img("R1", 70, 52, (255, 255, 255, 255)), cx, 70)
    paste_center(im, text_img(name.upper(), 840, 112, (255, 255, 255, 255), stroke=6, stroke_fill=(40, 50, 20)), 130, 510)
    im.save(out)

if __name__ == "__main__":
    src, outdir = sys.argv[1], sys.argv[2]
    make(src, "Atlanta Court", outdir + "/signs_atlanta_court.png")
    make(src, "Island Plaza", outdir + "/signs_island_plaza.png")
