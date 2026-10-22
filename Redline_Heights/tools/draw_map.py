"""Draws the full map and the minimap: terrain relief (hillshade + elevation colours + contour lines), sea depth, beaches,
and the roads / airport / rail / buildings taken from the earlier map layer, outlined like a printed city map.
Inputs (from scripts/export_coast.gd): /tmp/coast_d.bin, coast_h.bin, coast_mask.bin, renowood.json and the old feature layer."""
import numpy as np, json
from PIL import Image, ImageDraw, ImageFilter
Image.MAX_IMAGE_PIXELS = None
N = 701; S = 8192; HALF = 3500.0; ppm = S / (2 * HALF)
def up(path):
    a = np.fromfile(path, dtype=np.float32).reshape(N, N)
    return np.asarray(Image.fromarray(a, mode="F").resize((S, S), Image.BICUBIC))
D = up("/tmp/coast_d.bin"); Hh = up("/tmp/coast_h.bin"); M = up("/tmp/coast_mask.bin")
Dold = up("/tmp/coast_d_old.bin")
rng = np.random.default_rng(5)
def col(*c): return np.array(c, np.float32)
def mix(a, b, t): return a * (1 - t[..., None]) + b * t[..., None]
H, W = D.shape
ones = np.ones((H, W, 1), np.float32)
land = D >= 0
# --- hillshade (light from the north-west), vertical exaggeration so the gentle hills read
def blur(a, r):
    # separable box blurs (a few passes approximate a gaussian) on the float height field
    from numpy.lib.stride_tricks import sliding_window_view
    out = a.astype(np.float32)
    k = int(r)
    for _ in range(3):
        for ax in (0, 1):
            cs = np.cumsum(np.pad(out, [(k, k) if i == ax else (0, 0) for i in range(2)], mode="edge"), axis=ax, dtype=np.float64)
            sl_hi = [slice(None)] * 2; sl_lo = [slice(None)] * 2
            sl_hi[ax] = slice(2 * k, None); sl_lo[ax] = slice(0, -2 * k)
            zero = np.zeros_like(np.take(cs, [0], axis=ax))
            cs = np.concatenate([zero, cs], axis=ax)
            hi = np.take(cs, range(2 * k + 1, cs.shape[ax]), axis=ax)
            lo = np.take(cs, range(0, cs.shape[ax] - 2 * k - 1), axis=ax)
            out = ((hi - lo) / (2 * k + 1)).astype(np.float32)
    return out
Hs = blur(Hh, 6)
gy, gx = np.gradient(Hs, 1.0 / ppm)
ex = 1.7
nx, ny, nz = -gx * ex, -gy * ex, np.ones_like(gx)
nl = np.sqrt(nx * nx + ny * ny + nz * nz)
lx, ly, lz = -0.55, -0.6, 0.58
shade = np.clip((nx * lx + ny * ly + nz * lz) / nl, 0, 1)
shade = (shade - shade[Hh < 0.3].mean() if (Hh < 0.3).any() else shade) + 0.0
sh = 1.0 + np.clip(shade, -0.5, 0.5) * 0.75
slope = np.sqrt(gx * gx + gy * gy)
# --- land colours by elevation
low = col(112, 160, 92); mid = col(150, 160, 88); high = col(176, 150, 98); rock = col(140, 126, 110)
sand = col(232, 214, 166); wet = col(200, 180, 138)
e = np.clip(Hh / 85.0, 0, 1)
c = mix(low * ones, mid * ones, np.clip(e * 2.0, 0, 1))
c = mix(c, high * ones, np.clip((e - 0.45) * 2.2, 0, 1))
c = mix(c, rock * ones, np.clip((slope - 0.30) * 3.0, 0, 1) * 0.7)
t_sand = np.clip((D - 55) / 30, 0, 1)
c = mix(sand * ones, c, t_sand)
c = mix(c, wet * ones, np.clip(1 - D / 12, 0, 1) * 0.7)
c = c * sh[..., None]
patch = np.asarray(Image.fromarray(rng.random((64, 64)).astype(np.float32), mode="F").resize((S, S), Image.BICUBIC))
c = c * (0.94 + 0.12 * patch[..., None])
# contour lines every 8 m of elevation on the hills
lvl = Hh / 8.0
fr = np.abs(lvl - np.round(lvl))
cont = (fr < 0.02) & (Hh > 4) & (Hh < 120)
c = np.where(cont[..., None], c * 0.8, c)
# --- sea
sea_shallow = col(108, 204, 214); sea_mid = col(52, 140, 188); sea_deep = col(24, 70, 138)
ts = np.clip(-D / 55, 0, 1)
cs = mix(sea_shallow * ones, sea_mid * ones, ts)
cs = mix(cs, sea_deep * ones, np.clip((-D - 55) / 320, 0, 1))
wave = np.sin(np.arange(W)[None, :] * 0.05 + np.arange(H)[:, None] * 0.02)[..., None] * 1.6
cs = cs + wave
img = np.where(land[..., None], c, cs) + rng.normal(0, 1.4, (H, W, 1)).astype(np.float32)
base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
# --- map features (roads, airport, rail, stations, buildings) from the previous layer, outlined
v3 = Image.open("/tmp/map_backup/city_minimap_v3.png").convert("RGB")
# the old layer was drawn on the old base: anything that differs from the old base is a feature
def old_base():
    d = np.fromfile("/tmp/coast_d_old.bin", dtype=np.float32).reshape(N, N)
    Dd = np.asarray(Image.fromarray(d, mode="F").resize((S, S), Image.BICUBIC))
    rg = np.random.default_rng(3)
    g = col(96, 150, 78); sa = col(226, 208, 160); we = col(190, 170, 128)
    sh1 = col(88, 190, 200); mi = col(40, 120, 170); de = col(18, 56, 118)
    lnd = Dd >= 0
    cl = mix(sa * ones, g * ones, np.clip((Dd - 62) / 28, 0, 1))
    cl = mix(cl, we * ones, np.clip(1 - Dd / 14, 0, 1) * 0.7)
    cs2 = mix(sh1 * ones, mi * ones, np.clip(-Dd / 40, 0, 1))
    cs2 = mix(cs2, de * ones, np.clip((-Dd - 40) / 260, 0, 1))
    im = np.where(lnd[..., None], cl, cs2) + rg.normal(0, 1.6, (H, W, 1)).astype(np.float32)
    return np.clip(im, 0, 255).astype(np.int32)
ob = old_base()
feat = np.abs(np.asarray(v3).astype(np.int32) - ob).sum(2) > 34
fm = Image.fromarray((feat * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
# dark outline around every feature, then the feature itself
outline = fm.filter(ImageFilter.MaxFilter(7))
dark = Image.new("RGB", base.size, (38, 40, 46))
base.paste(dark, (0, 0), outline)
base.paste(v3, (0, 0), fm)
# --- Renowood: hill road, driveways, houses, sign
dr = ImageDraw.Draw(base)
info = json.load(open("/tmp/renowood.json"))
def P(x, z): return (S / 2 + x * ppm, S / 2 + z * ppm)
def line(pts, w, colr): dr.line([P(*p) for p in pts], fill=colr, width=max(2, int(w * ppm)), joint="curve")
road = info["road"]
line(road, 17, (36, 38, 44)); line(road, 13, (226, 226, 220)); line(road, 10.5, (88, 90, 96))
for d in info["drives"]:
    line(d, 9, (36, 38, 44)); line(d, 6, (88, 90, 96))
for p in info["pads"]:
    x, y = P(*p); r = 15 * ppm
    dr.rectangle((x - r - 3, y - r - 3, x + r + 3, y + r + 3), fill=(36, 38, 44))
    dr.rectangle((x - r, y - r, x + r, y + r), fill=(236, 232, 224))
# the road from the airport's loop road up to the foot of the hill, and the museum forecourt at the top
line([(840.0, -1110.0), (840.0, -1292.0)], 17, (36, 38, 44)); line([(840.0, -1110.0), (840.0, -1292.0)], 13, (226, 226, 220)); line([(840.0, -1110.0), (840.0, -1292.0)], 10.5, (88, 90, 96))
mx, my = P(*info["museum"]); mr = 34 * ppm
dr.ellipse((mx - mr - 3, my - mr - 3, mx + mr + 3, my + mr + 3), fill=(36, 38, 44))
dr.ellipse((mx - mr, my - mr, mx + mr, my + mr), fill=(200, 196, 188))
sx, sy = P(*info["sign"])
dr.rectangle((sx - 98 * ppm, sy - 7 * ppm, sx + 98 * ppm, sy + 7 * ppm), fill=(36, 38, 44))
dr.rectangle((sx - 96 * ppm, sy - 5 * ppm, sx + 96 * ppm, sy + 5 * ppm), fill=(250, 250, 250))
# --- the town: block lots, lanes, courtyards, parking, buildings, plaza (from the layout the game dumps with --dumpcity)
city = json.load(open("/tmp/city_layout.json"))
EDGE = 89.6; LH = 4.0
def R(x0, z0, x1, z1):
    a = P(x0, z0); b = P(x1, z1)
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1]))
for bl in city["blocks"]:
    x, z = bl["x"], bl["z"]
    dr.rectangle(R(x - EDGE, z - EDGE, x + EDGE, z + EDGE), fill=(206, 200, 188), outline=(150, 146, 138), width=2)
    if bl["mode"] != "none":
        dr.rectangle(R(x - EDGE, z - LH, x + EDGE, z + LH), fill=(96, 98, 104))
        dr.line([P(x - EDGE, z), P(x + EDGE, z)], fill=(225, 225, 215), width=1)
    if bl["mode"] == "cross":
        dr.rectangle(R(x - LH, z - EDGE, x + LH, z + EDGE), fill=(96, 98, 104))
        dr.line([P(x, z - EDGE), P(x, z + EDGE)], fill=(225, 225, 215), width=1)
for c4 in city["courts"]:
    dr.rectangle(R(*c4), fill=(120, 168, 96))
for lt in city["lots"]:
    dr.rectangle(R(*lt), fill=(110, 112, 118), outline=(240, 240, 235))
for pz in city["plaza"]:
    r = 9.0 * ppm
    cx, cy = P(*pz)
    dr.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(110, 190, 220), outline=(255, 255, 255), width=2)
import math
TOWER = {"wtc", "wtc_s", "boc", "atl", "atl_l"}
COL = {"fire": (205, 62, 52), "police": (62, 96, 210), "hospital": (245, 245, 245)}
for b in city["buildings"]:
    k = b["k"]
    if k in ("oak", "phone", "cart", "ambulance", "fountain"): continue
    yaw = b["yaw"]
    hw, hd = b["w"] * 0.5, b["d"] * 0.5
    c, s_ = math.cos(yaw), math.sin(yaw)
    # local x axis maps to (cos, -sin) in x,z after the yaw about +Y; the footprint is symmetric so only the corners matter
    pts_ = []
    for lx, lz in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)):
        wx = b["x"] + lx * c + lz * s_
        wz = b["z"] - lx * s_ + lz * c
        pts_.append(P(wx, wz))
    fill = COL.get(k, (90, 96, 110) if k in TOWER else ((176, 198, 222) if k == "office" else (232, 226, 214)))
    dr.polygon(pts_, fill=fill, outline=(50, 52, 58))
    if k == "hospital":
        cx = sum(p[0] for p in pts_) / 4; cy = sum(p[1] for p in pts_) / 4
        rr = 6 * ppm
        dr.rectangle((cx - rr, cy - rr * 0.35, cx + rr, cy + rr * 0.35), fill=(210, 40, 40))
        dr.rectangle((cx - rr * 0.35, cy - rr, cx + rr * 0.35, cy + rr), fill=(210, 40, 40))
base.save("assets/map/city_minimap.png")
base.resize((2048, 2048), Image.LANCZOS).save("assets/map/city_map.png")
base.crop((int(S / 2 + 100 * ppm), int(S / 2 - 2300 * ppm), int(S / 2 + 1500 * ppm), int(S / 2 - 1100 * ppm))).resize((1200, 1030)).save("/tmp/rh/mm_hills.png")
base.crop((int(S / 2 - 1700 * ppm), int(S / 2 - 1500 * ppm), int(S / 2 + 1700 * ppm), int(S / 2 + 1000 * ppm))).resize((1360, 1000)).save("/tmp/rh/mm_main.png")
print("ok")
