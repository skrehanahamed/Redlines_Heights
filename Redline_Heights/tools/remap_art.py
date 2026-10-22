#!/usr/bin/env python3
"""Re-styles the baked map art (assets/map/city_map.png + city_minimap.png) to a premium cartographic look:
saturated sea with subtle depth bands, clean land palette, crisp road casing, brighter feature blocks,
a soft vignette and a double frame. Reads the existing zones.png, height.bin and city.json - no game rebuild.

Run:  python3 -I tools/remap_art.py
Output: assets/map/city_map.png (2048, labelled) and assets/map/city_minimap.png (4096, minimap source).
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import scipy.ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "map"))
FONT = os.path.normpath(os.path.join(HERE, "..", "assets", "ui", "fonts", "BebasNeue-Regular.ttf"))

# design-world constants matching gen_world.py
D = 1254.0
HALF_W = 1200.0             # half-extent of the world the zones image covers (metres, design world)
HALF = 3500.0              # half-extent the game map covers (metres, game world) - game bakes the same art at MAP_HALF
K = 2400.0 / D             # metres per design unit
rng = np.random.default_rng(1312)

zones = np.array(Image.open(os.path.join(OUT, "zones.png")))            # 600x600, ids 0..10
city = json.load(open(os.path.join(OUT, "city.json")))
pois = city.get("pois", [])
edges = city.get("edges", [])
nodes = city.get("nodes", [])

Z = dict(SEA=0, BEACH=1, URBAN=2, DOWNTOWN=3, PARK=4, DESERT=5, MOUNTAIN=6, AIRPORT=7, INDUSTRIAL=8, LAKE=9, STADIUM=10)

# design->game meter offset: gen_world bakes the 2400m design square to game space with m(px) = (px-627)*K,
# and the game map spans +/-3500 m around the origin, so design origin (627,627) -> game (0,0).
def dm2g(dx, dz):            # design coords -> game metres
    return ((dx - D / 2.0) * K, (dz - D / 2.0) * K)

S = 4096                    # work at the minimap resolution
# resample zones onto the same pixels-per-metre as the game (4096 / 7000 m)
ppm = S / (HALF * 2.0)
Sd = int(HALF_W * 2 * ppm)   # 4096*1200/3500 ~ 1406
zbig = np.array(Image.fromarray(zones, mode="L").resize((Sd, Sd), Image.NEAREST))
# pad/crop into the SxS game-frame layout: design (0,0) sits at pixel ((HALF - HALF_W)*ppm)
o = int((HALF - HALF_W) * ppm)
ZS = np.zeros((S, S), np.uint8)
ZS[o:o + Sd, o:o + Sd] = zbig

def P(x, z):               # game metres -> pixels
    return ((x + HALF) * ppm, (z + HALF) * ppm)

land = np.zeros((S, S), bool)
for vid in range(1, 11):
    land |= ZS == vid

img = np.zeros((S, S, 3), np.float32)
ONE = np.ones((S, S, 1), np.float32)
def c(*v): return np.array(v, np.float32)
def mix(a, b, t): return a * (1 - t[..., None]) + b * t[..., None]

# --- sea: deep teal, bright shallow ring, faint ripple bands
sea_c, mid_c, deep_c = c(46, 168, 186), c(24, 122, 168), c(14, 74, 132)
dw = ndi.distance_transform_edt(~land)
sea = mix(mid_c * ONE, deep_c * ONE, np.clip(dw / 900, 0, 1))
sea = mix(sea_c * ONE, sea, np.clip(dw / 130, 0, 1))          # bright band near shore
# faint concenttic ripples (subtle, so it reads as water on the minimap)
yy, xx = np.mgrid[0:S, 0:S]
cx, cy = S * 0.46, S * 0.52
band = np.sin(np.sqrt(((xx - cx) / 240.0) ** 2 + ((yy - cy) / 240.0) ** 2) * 2.4) * 3.0
sea = np.where(land[..., None], img, sea + band[..., None])

# --- land palette by zone
pal = {
    Z["BEACH"]: c(238, 214, 158),
    Z["URBAN"]: c(196, 172, 122),
    Z["DOWNTOWN"]: c(188, 158, 104),
    Z["PARK"]: c(110, 158, 84),
    Z["DESERT"]: c(216, 168, 96),
    Z["MOUNTAIN"]: c(156, 128, 100),
    Z["AIRPORT"]: c(206, 202, 182),
    Z["INDUSTRIAL"]: c(184, 164, 128),
    Z["LAKE"]: c(60, 150, 170),
    Z["STADIUM"]: c(190, 178, 148),
}
for vid, col in pal.items():
    m = ZS == vid
    img[m] = col
img = np.where(land[..., None], img, sea)

# gentle per-zone mottling (large, soft) so surfaces are not flat
mottle = ndi.gaussian_filter(rng.standard_normal((S // 8, S // 8)), 30)
mottle = np.array(Image.fromarray(mottle - mottle.min(), mode="F").resize((S, S), Image.BICUBIC))
img = img * (0.93 + 0.07 * mottle[..., None])

# park trees, desert specks, mountain hachure (sparse, subtle)
dr = ImageDraw.Draw(Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)), "RGBA")
art = dr.im
for vid, col, n, r in ((Z["PARK"], (46, 104, 50, 170), 5500, 4), (Z["DESERT"], (168, 112, 58, 120), 3200, 3)):
    m = ZS == vid
    ys, xs = np.nonzero(m)
    if len(ys):
        sel = rng.integers(0, len(ys), n)
        for i in sel:
            x, y = xs[i], ys[i]
            dr.ellipse([x - r, y - r, x + r, y + r], fill=col)
mz = np.nonzero(ZS == Z["MOUNTAIN"])
if len(mz[0]):
    sel = rng.integers(0, len(mz[0]), 2500)
    for i in sel:
        x, y = mz[1][i], mz[0][i]
        dr.line([(x, y), (x + 16, y - 13), (x + 30, y + 5)], fill=(120, 92, 66, 130), width=3)
        dr.line([(x + 16, y - 13), (x + 17, y + 8)], fill=(235, 190, 130, 110), width=2)

# lakes back on top of any dots
img2 = np.clip(np.array(art.convert("RGB")).astype(np.float32), 0, 255)
img2[ZS == Z["LAKE"]] = c(60, 150, 170)
art = Image.fromarray(img2.astype(np.uint8))
dr = ImageDraw.Draw(art, "RGBA")

# --- roads (from city.json): crisp dark casing + light fill; avenues slightly wider
ROAD_W = 16.0
def road_poly(a, b, w, fill):
    ax, az = P(*a); bx, bz = P(*b)
    dr.line([(ax, az), (bx, bz)], fill=fill, width=max(1, int(w * ppm)))
for pass_i in range(2):
    for a, b, kind in edges:
        pa, pb = nodes[a], nodes[b]
        if kind == 0:   # street
            road_poly(pa, pb, ROAD_W + 6 if pass_i == 0 else ROAD_W - 2,
                      (34, 30, 26, 255) if pass_i == 0 else (246, 236, 204, 255))
        elif kind == 3:  # avenue / highway
            road_poly(pa, pb, ROAD_W + 14 if pass_i == 0 else ROAD_W + 5,
                      (58, 40, 24, 255) if pass_i == 0 else (255, 216, 128, 255))
        elif kind == 2:  # lane
            road_poly(pa, pb, ROAD_W - 10 if pass_i == 0 else ROAD_W - 14,
                      (40, 38, 34, 255) if pass_i == 0 else (232, 224, 200, 255))
        else:            # rail
            road_poly(pa, pb, 26 if pass_i == 0 else 16,
                      (28, 30, 34, 255) if pass_i == 0 else (92, 96, 100, 255))
# rail dashes
for a, b, kind in edges:
    if kind == 1:
        pa, pb = P(*nodes[a]), P(*nodes[b])
        L = math.hypot(pb[0] - pa[0], pb[1] - pa[1])
        n = int(L / 46)
        for i in range(n):
            t0, t1 = i / n + 0.08, i / n + 0.22
            dr.line([pa + (pb - pa) * t0, pa + (pb - pa) * t1], fill=(236, 234, 222, 255), width=2)

# --- bridges over water (from features)
f = city.get("features", {})
for bn, bpts in f.get("bridge", {}).items() if isinstance(f.get("bridge"), dict) else []:
    pts = [P(*p) for p in bpts]
    if len(pts) >= 2:
        dr.line(pts, fill=(24, 22, 20, 255), width=int(26 * ppm / 4) + 3)
        dr.line(pts, fill=(218, 202, 168, 255), width=int(16 * ppm / 4) + 3)
# piers
for p0, p1 in f.get("piers", []):
    a, b = P(*dm2g_inv(p0)), P(*dm2g_inv(p1))
    dr.line([a, b], fill=(60, 44, 30, 255), width=5)
    dr.line([a, b], fill=(186, 148, 96, 255), width=3)

def save(out_name, labels, size=2048):
    a = art.resize((size, size), Image.LANCZOS)
    if labels:
        fnt = lambda sz: ImageFont.truetype(FONT, sz)
        dd = ImageDraw.Draw(a, "RGBA")
        s_ = size / S
        def plate(text, gm_x, gm_z, sz=44):
            ft = fnt(int(sz * s_))
            px, pz = P(gm_x, gm_z)
            px, pz = px * s_, pz * s_
            bb = dd.textbbox((0, 0), text, font=ft)
            w, h = bb[2] - bb[0] + int(30 * s_), bb[3] - bb[1] + int(18 * s_)
            dd.rounded_rectangle([px - w / 2 + 3 * s_, pz - h / 2 + 3 * s_, px + w / 2 + 3 * s_, pz + h / 2 + 3 * s_],
                                 radius=int(12 * s_), fill=(18, 14, 10, 120))
            dd.rounded_rectangle([px - w / 2, pz - h / 2, px + w / 2, pz + h / 2], radius=int(12 * s_),
                                 fill=(244, 228, 190, 250), outline=(80, 58, 32, 255), width=max(2, int(3 * s_)))
            dd.text((px - (bb[2] - bb[0]) / 2 - bb[0], pz - (bb[3] - bb[1]) / 2 - bb[1]), text, font=ft,
                    fill=(54, 34, 16, 255))
        for poi in pois:
            if poi["kind"] in ("mountain", "desert", "island", "airport", "harbour", "park", "beach", "stadium", "pier"):
                plate(poi["name"], poi["pos"][0], poi["pos"][1] - (40 if poi["kind"] in ("stadium", "beach") else 0))
        plate("DOWNTOWN", 40, -10, 50)
        plate("REDLINE ISLAND", -760, 850, 46)
        plate("PACIFIC OCEAN", 700, 1150, 54)
        # compass rose bottom-right
        cx0, cy0 = int((S - 190) * s_), int((S - 190) * s_)
        r0 = int(64 * s_)
        dd.ellipse([cx0 - r0, cy0 - r0, cx0 + r0, cy0 + r0], fill=(240, 224, 184, 225), outline=(80, 58, 32, 255), width=max(3, int(4 * s_)))
        dd.polygon([(cx0, cy0 - r0 * 0.85), (cx0 - r0 * 0.22, cy0), (cx0 + r0 * 0.22, cy0)], fill=(190, 44, 34, 255))
        dd.polygon([(cx0, cy0 + r0 * 0.85), (cx0 - r0 * 0.22, cy0), (cx0 + r0 * 0.22, cy0)], fill=(54, 34, 16, 255))
        dd.text((cx0 - int(10 * s_), cy0 - r0 - int(46 * s_)), "N", font=fnt(int(44 * s_)), fill=(54, 34, 16, 255))
        # soft vignette
        yy, xx = np.mgrid[0:size, 0:size]
        fall = np.clip(((xx - size / 2) ** 2 + (yy - size / 2) ** 2) ** 0.5 / (size * 0.75), 0, 1) ** 2.4
        arr = np.array(a.convert("RGB")).astype(np.float32)
        arr = arr * (1 - fall[..., None] * 0.38) + c(40, 30, 18)[None, None, :] * (fall[..., None] * 0.16)
        a = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
        dd = ImageDraw.Draw(a, "RGBA")
        dd.rounded_rectangle([4, 4, size - 5, size - 5], radius=int(30 * s_), outline=(24, 20, 16, 255), width=int(10 * s_))
        dd.rounded_rectangle([18, 18, size - 19, size - 19], radius=int(22 * s_), outline=(204, 176, 122, 255), width=max(3, int(4 * s_)))
    a.save(os.path.join(OUT, out_name))
    print("wrote", out_name)

def dm2g_inv(px, py):
    return dm2g(px, py)

save("city_map.png", True, 2048)
save("city_minimap.png", False, 4096)
