#!/usr/bin/env python3
"""Re-styles the baked map art (assets/map/city_map.png + city_minimap.png) to a premium cartographic look:
saturated sea with a bright shallow ring, clean land palette, crisp road casings, rail dashes, bridges,
piers, and (on the labelled copy) name plates, compass rose, vignette and a double frame.
Reads the existing zones.png, city.json and zones data - no game rebuild needed.

Run:  python3 -I tools/remap_art.py
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw
import scipy.ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "map"))
FONT = os.path.normpath(os.path.join(HERE, "..", "assets", "ui", "fonts", "BebasNeue-Regular.ttf"))

# ---- geometry constants shared with gen_world.py / the game
D = 1254.0                       # design square
K = 2400.0 / D                  # metres per design unit
HALF_W = 1200.0                 # half-extent of the design world in metres (what zones.png covers)
HALF = 3500.0                   # half-extent of the game map in metres (MAP_HALF in world.gd)
S = 4096                        # working resolution (minimap source)
ppm = S / (HALF * 2.0)         # pixels per metre
zimg = np.array(Image.open(os.path.join(OUT, "zones.png")))
city = json.load(open(os.path.join(OUT, "city.json")))
pois = city.get("pois", [])
edges = city.get("edges", [])
nodes = city.get("nodes", [])
features = city.get("features", {})
Z = dict(SEA=0, BEACH=1, URBAN=2, DOWNTOWN=3, PARK=4, DESERT=5, MOUNTAIN=6, AIRPORT=7, INDUSTRIAL=8, LAKE=9, STADIUM=10)

# zones.png covers the design world 2400 m, placed in game space centred on the origin
# (gen_world bakes it to game space; both maps are centred the same way).
Sd = int(HALF_W * 2 * ppm)      # ~2696 px at the game's pixels-per-metre
ZS = np.zeros((S, S), np.uint8)
o = (S - Sd) // 2
ZS[o:o + Sd, o:o + Sd] = np.array(Image.fromarray(zimg, mode="L").resize((Sd, Sd), Image.NEAREST))

def P(x, z):                    # game metres -> pixels
    return ((x + HALF) * ppm, (z + HALF) * ppm)

def c(*v): return np.array(v, np.float32)
def mix(a, b, t): return a * (1 - t[..., None]) + b * t[..., None]

land = np.zeros((S, S), bool)
for vid in range(1, 11):
    land |= ZS == vid

img = np.zeros((S, S, 3), np.float32)
ONE = np.ones((S, S, 1), np.float32)
rng = np.random.default_rng(1312)

# --- sea: bright shallows near the shore, deep blue beyond, faint ripples
dw = ndi.distance_transform_edt(~land)
sea = mix(c(16, 76, 138) * ONE, c(24, 124, 170) * ONE, np.clip(1.0 - dw / 900, 0, 1))
sea = mix(sea, c(60, 180, 196) * ONE, np.clip(dw / 140, 0, 1))
yy, xx = np.mgrid[0:S, 0:S]
cx, cy = S * 0.44, S * 0.50
band = np.sin(np.sqrt(((xx - cx) / 260.0) ** 2 + ((yy - cy) / 260.0) ** 2) * 2.6) * 2.5
sea = np.where(land[..., None], c(0, 0, 0), sea + band[..., None])

# --- land palette
pal = {
    Z["BEACH"]: c(238, 216, 160),
    Z["URBAN"]: c(198, 174, 126),
    Z["DOWNTOWN"]: c(186, 156, 102),
    Z["PARK"]: c(112, 160, 86),
    Z["DESERT"]: c(218, 170, 98),
    Z["MOUNTAIN"]: c(158, 130, 102),
    Z["AIRPORT"]: c(206, 202, 184),
    Z["INDUSTRIAL"]: c(182, 162, 126),
    Z["LAKE"]: c(58, 150, 172),
    Z["STADIUM"]: c(188, 176, 146),
}
for vid, col in pal.items():
    m = ZS == vid
    img[m] = col
img = np.where(land[..., None], img, sea)
# large-soft mottling so flat zones are not sterile
mm2 = ndi.gaussian_filter(rng.standard_normal((S // 8, S // 8)), 30)
mm2 = (mm2 - mm2.min()) / (mm2.max() - mm2.min() + 1e-9)
mm2 = np.array(Image.fromarray(mm2, mode="F").resize((S, S)))
img = img * (0.92 + 0.09 * mm2[..., None])

# --- lakes on top
img[ZS == Z["LAKE"]] = c(58, 150, 172)

art = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
dr = ImageDraw.Draw(art, "RGBA")

# --- park trees, desert specks, mountain hachure
for vid, col, n, r in ((Z["PARK"], (44, 102, 50, 170), 6000, 4), (Z["DESERT"], (170, 114, 58, 120), 3000, 3)):
    ys, xs = np.nonzero(ZS == vid)
    if len(ys):
        sel = rng.integers(0, len(ys), min(n, len(ys)))
        for i in sel:
            x, y = int(xs[i]), int(ys[i])
            dr.ellipse([x - r, y - r, x + r, y + r], fill=col)
ys, xs = np.nonzero(ZS == Z["MOUNTAIN"])
sel = rng.integers(0, len(ys), min(2600, len(ys)))
for i in sel:
    x, y = int(xs[i]), int(ys[i])
    dr.line([(x, y), (x + 16, y - 13), (x + 30, y + 5)], fill=(118, 90, 64, 130), width=3)
    dr.line([(x + 16, y - 13), (x + 17, y + 8)], fill=(232, 188, 130, 110), width=2)

# --- roads: dark casing + light fill (kind 0 street, 2 lane, 3 avenue, 1 rail)
ROAD_W = 16.0
def road(a, b, w, fill):
    ax, az = P(*a); bx, bz = P(*b)
    dr.line([(ax, az), (bx, bz)], fill=fill, width=max(1, int(w * ppm)))
for pass_i in range(2):
    for a, b, kind in edges:
        pa, pb = nodes[a], nodes[b]
        if kind == 0:
            road(pa, pb, ROAD_W + 6 if pass_i == 0 else ROAD_W - 3,
                 (32, 28, 24, 255) if pass_i == 0 else (248, 238, 206, 255))
        elif kind == 3:
            road(pa, pb, ROAD_W + 14 if pass_i == 0 else ROAD_W + 4,
                 (56, 38, 22, 255) if pass_i == 0 else (255, 214, 124, 255))
        elif kind == 2:
            road(pa, pb, ROAD_W - 9 if pass_i == 0 else ROAD_W - 13,
                 (38, 36, 32, 255) if pass_i == 0 else (230, 222, 198, 255))
        elif kind == 1:
            road(pa, pb, 24 if pass_i == 0 else 15,
                 (26, 28, 34, 255) if pass_i == 0 else (90, 94, 100, 255))
# rail dashes on top
for a, b, kind in edges:
    if kind != 1:
        continue
    pa, pb = P(*nodes[a]), P(*nodes[b])
    L = math.hypot(pb[0] - pa[0], pb[1] - pa[1])
    n = max(1, int(L / 48))
    dx, dz = pb[0] - pa[0], pb[1] - pa[1]
    for i in range(n):
        t0, t1 = i / n + 0.06, i / n + 0.26
        dr.line([(pa[0] + dx * t0, pa[1] + dz * t0), (pa[0] + dx * t1, pa[1] + dz * t1)], fill=(238, 236, 224, 255), width=2)

# --- bridges (game-metre polylines in features.bridge: name -> [[x, z], ...])
bpts = features.get("bridge") or []
if len(bpts) >= 2:
    pts = [P(*p) for p in bpts]
    dr.line(pts, fill=(22, 20, 18, 255), width=int(22 * ppm / 4) + 4)
    dr.line(pts, fill=(216, 198, 164, 255), width=int(14 * ppm / 4) + 3)
    dr.line(pts, fill=(120, 98, 74, 255), width=2)
    for q in (pts[0], pts[-1]):
        r = int(9 * ppm / 4)
        dr.ellipse([q[0] - r - 2, q[1] - r - 2, q[0] + r + 2, q[1] + r + 2], fill=(216, 198, 164, 255), outline=(22, 20, 18, 255), width=3)

# --- piers (features.piers: [[start, end], ...] in game metres)
for p0, p1 in features.get("piers", []):
    a, b = P(*p0), P(*p1)
    dr.line([a, b], fill=(58, 42, 28, 255), width=max(3, int(8 * ppm / 4)))
    dr.line([a, b], fill=(188, 150, 98, 255), width=max(2, int(5 * ppm / 4)))

# --- stadium (features.stadium: cx, cz, r in game metres)
st = features.get("stadium")
if st:
    cx_, cz_, r_ = st[0], st[1], st[2]
    px, pz = P(cx_, cz_)
    rr = r_ * ppm
    dr.ellipse([px - rr - 3, pz - rr * 0.8 - 3, px + rr + 3, pz + rr * 0.8 + 3], fill=(180, 170, 150, 255), outline=(52, 48, 42, 255), width=max(2, int(3 * ppm / 4)))
    dr.ellipse([px - rr * 0.85, pz - rr * 0.62, px + rr * 0.85, pz + rr * 0.62], fill=(196, 58, 48, 255))
    dr.ellipse([px - rr * 0.6, pz - rr * 0.42, px + rr * 0.6, pz + rr * 0.42], fill=(96, 160, 78, 255), outline=(238, 238, 228, 255), width=2)

def save(out_name, labels, size):
    a = art.resize((size, size), Image.LANCZOS)
    s_ = size / S
    if labels:
        from PIL import ImageFont
        fnt = lambda sz: ImageFont.truetype(FONT, int(sz * s_))
        dd = ImageDraw.Draw(a, "RGBA")
        def plate(text, gx, gz, sz=44, dy=0):
            ft = fnt(sz)
            px, pz = P(gx, gz)
            px, pz = px * s_, (pz + dy * ppm * s_) * 1.0
            bb = dd.textbbox((0, 0), text, font=ft)
            w = bb[2] - bb[0] + int(28 * s_)
            h = bb[3] - bb[1] + int(16 * s_)
            dd.rounded_rectangle([px - w / 2 + 3 * s_, pz - h / 2 + 3 * s_, px + w / 2 + 3 * s_, pz + h / 2 + 3 * s_],
                                 radius=int(10 * s_), fill=(16, 12, 8, 130))
            dd.rounded_rectangle([px - w / 2, pz - h / 2, px + w / 2, pz + h / 2], radius=int(10 * s_),
                                 fill=(246, 230, 192, 252), outline=(76, 54, 30, 255), width=max(2, int(3 * s_)))
            dd.text((px - (bb[2] - bb[0]) / 2 - bb[0], pz - (bb[3] - bb[1]) / 2 - bb[1]), text, font=ft,
                    fill=(52, 32, 14, 255))
        for poi in pois:
            if poi["kind"] in ("mountain", "desert", "island", "airport", "harbour", "park", "beach", "stadium", "pier"):
                plate(poi["name"], poi["pos"][0], poi["pos"][1], dy=(40 if poi["kind"] in ("stadium", "beach") else 0))
        plate("DOWNTOWN", 40, -10, 50)
        plate("REDLINE ISLAND", -760, 850, 44)
        plate("PACIFIC OCEAN", 700, 1150, 54)
        # compass rose, bottom-right of the frame
        cx0, cy0 = int((S - 200) * s_), int((S - 200) * s_)
        r0 = int(62 * s_)
        dd.ellipse([cx0 - r0, cy0 - r0, cx0 + r0, cy0 + r0], fill=(242, 226, 188, 235), outline=(76, 54, 30, 255), width=max(3, int(4 * s_)))
        dd.polygon([(cx0, cy0 - r0 * 0.82), (cx0 - r0 * 0.2, cy0), (cx0 + r0 * 0.2, cy0)], fill=(186, 42, 32, 255))
        dd.polygon([(cx0, cy0 + r0 * 0.82), (cx0 - r0 * 0.2, cy0), (cx0 + r0 * 0.2, cy0)], fill=(52, 32, 14, 255))
        dd.text((cx0 - int(9 * s_), cy0 - r0 - int(42 * s_)), "N", font=fnt(42), fill=(52, 32, 14, 255))
        # vignette
        arr = np.array(a.convert("RGB")).astype(np.float32)
        y2, x2 = np.mgrid[0:size, 0:size]
        fall = np.clip(((x2 - size / 2) ** 2 + (y2 - size / 2) ** 2) ** 0.5 / (size * 0.74), 0, 1) ** 2.4
        arr = arr * (1 - fall[..., None] * 0.4) + c(36, 26, 14)[None, None, :] * (fall[..., None] * 0.16)
        a = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
        dd = ImageDraw.Draw(a, "RGBA")
        dd.rounded_rectangle([5, 5, size - 6, size - 6], radius=int(30 * s_), outline=(22, 18, 14, 255), width=int(11 * s_))
        dd.rounded_rectangle([20, 20, size - 21, size - 21], radius=int(22 * s_), outline=(206, 178, 124, 255), width=max(3, int(4 * s_)))
    a.save(os.path.join(OUT, out_name))
    print("wrote", out_name)

save("city_map.png", True, 2048)
save("city_minimap.png", False, 4096)
