"""Repaints the station's departure boards (checker.002 texture) and the ticket machine label into English with this
station's own destination.  Usage: python3 tools/metro_boards.py <checker.002 png> <Ticket png> <out dir>"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

def board(src, dest, out):
    im = Image.open(src).convert("RGB")
    a = np.array(im)
    bg = tuple(int(v) for v in a[5, 140])                     # the board's own dark colour
    pan = tuple(int(v) for v in a[40, 200])                   # the display's dark brown
    d = ImageDraw.Draw(im)
    f_s = ImageFont.truetype(REG, 12)
    f_b = ImageFont.truetype(BOLD, 15)
    for oy in (0, 122):
        d.rectangle([146, 2 + oy, 205, 18 + oy], fill=bg)
        d.text((149, 4 + oy), "Platform 1", font=f_s, fill=(175, 175, 175))
        d.rectangle([150, 27 + oy, 360, 84 + oy], fill=pan)
        d.text((156, 66 + oy), "R1", font=f_b, fill=(232, 160, 40))
        d.text((182, 66 + oy), dest, font=f_b, fill=(232, 160, 40))
        t = "3 min"
        w = d.textlength(t, font=f_b)
        d.text((356 - w, 66 + oy), t, font=f_b, fill=(232, 160, 40))
        d.rectangle([146, 89 + oy, 362, 106 + oy], fill=bg)
        d.text((149, 91 + oy), "Line  Destination", font=f_s, fill=(175, 175, 175))
        t2 = "Departs"
        w2 = d.textlength(t2, font=f_s)
        d.text((360 - w2, 91 + oy), t2, font=f_s, fill=(175, 175, 175))
    im.save(out)

def ticket(src, out):
    im = Image.open(src).convert("RGB")
    d = ImageDraw.Draw(im)
    d.rectangle([826, 496, 945, 536], fill=(252, 252, 250))
    f = ImageFont.truetype(BOLD, 15)
    d.text((830, 512), "Metro Tickets", font=f, fill=(50, 50, 50))
    im.save(out)

if __name__ == "__main__":
    src, tk, outdir = sys.argv[1:4]
    board(src, "Island Plaza", outdir + "/board_atlanta_court.png")
    board(src, "Atlanta Court", outdir + "/board_island_plaza.png")
    ticket(tk, outdir + "/ticket_en.png")
