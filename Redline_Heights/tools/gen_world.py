#!/usr/bin/env python3
"""Generates the Redline Heights island: zones mask, road graph, features and the parchment map art.

Design coordinates are 0..1254 (the layout was drawn at that size); 1 design unit = 2400/1254 m, the map centre is the origin.
Outputs (into assets/map): zones.png (class ids), city_map.png (map art), city.json (roads, features, pois).
Run:  python3 -I tools/gen_world.py
"""
import json, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage as ndi

D = 1254.0
HALF = 1200.0                 # metres from the centre to the map edge
K = HALF * 2.0 / D            # metres per design unit
PITCH = 76.0                  # lattice spacing (= block 60 + road 16), matches the in-game blocks
ROAD_W = 16.0
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "map")
os.makedirs(OUT, exist_ok=True)
FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui", "fonts", "BebasNeue-Regular.ttf")

ZONE = dict(SEA=0, BEACH=1, URBAN=2, DOWNTOWN=3, PARK=4, DESERT=5, MOUNTAIN=6, AIRPORT=7, INDUSTRIAL=8, LAKE=9, STADIUM=10)

def m(px):  # design -> metres
    return (px - D / 2.0) * K

def to_design(xm):
    return xm / K + D / 2.0

rng = np.random.default_rng(1312)
pyrng = random.Random(1312)

# ------------------------------------------------------------------ shapes (design coordinates)
L1 = [(0,0),(1254,0),(1254,690),(1220,715),(1195,760),(1190,830),(1200,885),(1170,945),(1128,990),(1118,1040),(1132,1092),(1095,1138),
      (1040,1162),(985,1166),(940,1132),(955,1082),(946,1030),(896,1002),(840,988),(800,958),(765,942),(722,965),(668,985),(622,975),
      (592,987),(570,1002),(546,962),(520,935),(470,926),(430,952),(410,990),(396,952),(366,936),(336,906),(311,846),(306,780),(326,722),
      (321,640),(335,582),(350,522),(396,482),(386,422),(331,372),(252,302),(182,252),(122,232),(72,246),(42,292),(0,305)]
L2 = [(52,456),(300,456),(321,532),(331,642),(316,702),(192,702),(150,652),(60,642),(52,562)]            # industrial peninsula
L3 = [(100,702),(262,702),(252,802),(242,902),(212,928),(152,862),(97,782)]                              # south-west peninsula
L4 = [(40,1025),(150,985),(262,1006),(392,1062),(432,1136),(386,1190),(266,1180),(156,1216),(70,1150),(40,1090)]  # the island
INLETS = [[(396,430),(468,452),(520,528),(498,606),(446,598),(425,520)],
          [(335,600),(420,590),(500,605),(520,650),(440,700),(340,690)]]
LAKES = [[(532,232),(602,202),(682,232),(692,302),(652,332),(582,322),(547,282)],
         [(915,702),(968,692),(1002,762),(986,832),(932,842),(915,782)],
         [(906,407),(1012,392),(1062,442),(1042,522),(962,542),(906,492)]]
MOUNT = [[(0,0),(312,0),(334,62),(282,132),(202,192),(102,177),(42,212),(0,232)],
         [(1130,300),(1254,260),(1254,560),(1190,520),(1140,420)],
         [(120,1040),(300,1030),(380,1090),(360,1150),(220,1150),(120,1120)]]
DESERT = [(760,0),(1254,0),(1254,700),(1130,650),(1090,540),(1100,382),(1000,332),(930,252),(842,182),(782,100)]
PARKS = [[(482,162),(722,152),(752,262),(702,352),(602,372),(502,332),(472,242)],
         [(852,382),(1092,372),(1102,542),(982,562),(872,502)],
         [(562,742),(742,742),(782,822),(682,852),(582,822)]]
DOWNTOWN = [(560,480),(900,520),(930,720),(780,780),(620,720),(540,600)]
AIRPORT = [(912,42),(1212,42),(1212,244),(912,244)]   # a clean rectangle: metres x 540..1115, z -1120..-735
STADIUM = (490, 805, 58)   # design x, y, radius

# highways (design coordinates), smoothed later
HIGHWAYS = {
    "mountain_road": [(372,60),(300,110),(200,150),(110,140)],
    "island_bridge": [(352,850),(300,925),(240,992)],
    "harbour_bridge": [(322,640),(260,640),(190,646)],
    "peninsula_bridge": [(324,742),(280,760),(230,790)],
    "island_ring": [(150,1010),(262,1030),(350,1080),(380,1140),(300,1160),(180,1150),(110,1100),(80,1060),(150,1010)],
}
BRIDGE_NAMES = ["island_bridge", "harbour_bridge", "peninsula_bridge"]

PIERS = [  # (start design, end design) comb piers and long piers into the sea
    ((250, 300), (215, 318)), ((282, 330), (247, 348)), ((312, 358), (277, 376)), ((338, 388), (303, 406)),
    ((52, 480), (18, 480)), ((52, 520), (14, 520)), ((52, 560), (22, 560)), ((52, 600), (18, 600)),
    ((190, 700), (190, 740)), ((220, 700), (220, 760)),
    ((582, 990), (582, 1050)), ((820, 958), (820, 1010)), ((958, 1110), (930, 1180)),
    ((430, 940), (440, 990)), ((470, 928), (480, 980)),
    ((1190, 700), (1254, 700)),
]

# ------------------------------------------------------------------ organic outlines
def noise_field(size, sigma, seed):
    r = np.random.default_rng(seed)
    f = ndi.gaussian_filter(r.standard_normal((size, size)), sigma)
    f /= np.abs(f).max() + 1e-9
    return f

NF = noise_field(1300, 16, 5)

def organic(poly, step=12.0, amp=5.0):
    out = []
    n = len(poly)
    for i in range(n):
        a = poly[i]
        b = poly[(i + 1) % n]
        dist = math.hypot(b[0] - a[0], b[1] - a[1])
        segs = max(1, int(dist / step))
        for s in range(segs):
            t = s / segs
            x = a[0] + (b[0] - a[0]) * t
            y = a[1] + (b[1] - a[1]) * t
            xi = min(1299, max(0, int(x)))
            yi = min(1299, max(0, int(y)))
            nx = NF[yi, xi] * amp
            ny = NF[xi, yi] * amp
            out.append((x + nx, y + ny))
    return out

# ------------------------------------------------------------------ zones raster (R x R, 2 m cells)
R = 1200
SC = R / D
def raster(polys, value, arr, mask=None):
    img = Image.new("L", (R, R), 0)
    dr = ImageDraw.Draw(img)
    for p in polys:
        dr.polygon([(x * SC, y * SC) for x, y in organic(p)], fill=255)
    sel = np.array(img) > 127
    if mask is not None:
        sel &= mask
    arr[sel] = value
    return sel

Z = np.zeros((R, R), np.uint8)
land = np.zeros((R, R), bool)
for p in [L1, L2, L3, L4]:
    img = Image.new("L", (R, R), 0)
    ImageDraw.Draw(img).polygon([(x * SC, y * SC) for x, y in organic(p)], fill=255)
    land |= np.array(img) > 127
Z[land] = ZONE["URBAN"]
ind = np.zeros((R, R), bool)
for p in [L2, L3]:
    img = Image.new("L", (R, R), 0)
    ImageDraw.Draw(img).polygon([(x * SC, y * SC) for x, y in organic(p)], fill=255)
    ind |= np.array(img) > 127
Z[ind & land] = ZONE["INDUSTRIAL"]
raster([DESERT], ZONE["DESERT"], Z, land)
raster(MOUNT, ZONE["MOUNTAIN"], Z, land)
raster(PARKS, ZONE["PARK"], Z, land)
raster([DOWNTOWN], ZONE["DOWNTOWN"], Z, land)
raster([AIRPORT], ZONE["AIRPORT"], Z, land)
# centre must be a flat city area
yy, xx = np.mgrid[0:R, 0:R]
cen = ((xx - R / 2) ** 2 + (yy - R / 2) ** 2) < (330.0 / 2.0) ** 2   # radius 330 m
Z[cen & land & ~np.isin(Z, [ZONE["DOWNTOWN"]])] = ZONE["URBAN"]
Z[((xx - R / 2) ** 2 + (yy - R / 2) ** 2) < (250.0 / 2.0) ** 2] = ZONE["DOWNTOWN"]
# stadium ring
sx, sy, sr = STADIUM
stad = ((xx - sx * SC) ** 2 + (yy - sy * SC) ** 2) < (sr * K / 2.0 * 1.0) ** 2
Z[stad & land] = ZONE["STADIUM"]
# water bodies cut out of the land
for p in INLETS:
    raster([p], ZONE["SEA"], Z)
for p in LAKES:
    raster([p], ZONE["LAKE"], Z)
# beach band along the sea (not along mountains / airport)
water = np.isin(Z, [ZONE["SEA"], ZONE["LAKE"]])
dist_w = ndi.distance_transform_edt(~water) * 2.0           # metres from water
beach = (dist_w < 16.0) & ~water & np.isin(Z, [ZONE["URBAN"], ZONE["DESERT"], ZONE["INDUSTRIAL"], ZONE["DOWNTOWN"], ZONE["PARK"]])
Z[beach] = ZONE["BEACH"]
Image.fromarray(Z).resize((600, 600), Image.NEAREST).save(os.path.join(OUT, "zones.png"))

def zone_at(xm, zm):
    px = int((xm + HALF) / (HALF * 2.0) * R)
    py = int((zm + HALF) / (HALF * 2.0) * R)
    if px < 0 or py < 0 or px >= R or py >= R:
        return 0
    return int(Z[py, px])

# ------------------------------------------------------------------ road lattice
CITY = [ZONE["URBAN"], ZONE["DOWNTOWN"], ZONE["INDUSTRIAL"]]
def node_ok(xm, zm):
    if zone_at(xm, zm) not in CITY: return False
    # keep a margin from the water and from other zones' edges
    for dx, dz in [(30, 0), (-30, 0), (0, 30), (0, -30)]:
        if zone_at(xm + dx, zm + dz) in (ZONE["SEA"], ZONE["LAKE"]): return False
    return True

ks = range(int(-HALF // PITCH) - 1, int(HALF // PITCH) + 2)
nodes_lat = {}
for k in ks:
    for mm in ks:
        x, z = k * PITCH, mm * PITCH
        if abs(x) < HALF - 20 and abs(z) < HALF - 20 and node_ok(x, z):
            nodes_lat[(k, mm)] = (x, z)
# edges between lattice neighbours; midpoints must also be fine
def edge_ok(a, b):
    mx, mz = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    return zone_at(mx, mz) in CITY
lat_edges = []
for (k, mm), pa in nodes_lat.items():
    for dk, dm in [(1, 0), (0, 1)]:
        nb = (k + dk, mm + dm)
        if nb in nodes_lat and edge_ok(pa, nodes_lat[nb]):
            lat_edges.append(((k, mm), nb))
# keep the lattice components with a reasonable size (the origin's one plus harbour, south-east town, ...)
adj = {}
for a, b in lat_edges:
    adj.setdefault(a, []).append(b)
    adj.setdefault(b, []).append(a)
seen = set()
for start in list(adj.keys()):
    if start in seen: continue
    comp = set()
    stack = [start]
    while stack:
        n = stack.pop()
        if n in comp: continue
        comp.add(n)
        stack.extend(adj.get(n, []))
    if len(comp) >= 5:
        seen |= comp
nodes_lat = {k: v for k, v in nodes_lat.items() if k in seen}
lat_edges = [(a, b) for a, b in lat_edges if a in seen and b in seen]

# ------------------------------------------------------------------ highways
def chaikin(pts, it=3):
    for _ in range(it):
        out = [pts[0]]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        out.append(pts[-1])
        pts = out
    return pts

def resample(pts, step):
    out = [pts[0]]
    acc = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        pos = step - acc
        while pos <= seg:
            t = pos / seg
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            pos += step
        acc = (acc + seg) % step if seg < step - acc else seg - (pos - step)
    out.append(pts[-1])
    return out

hw_lines = {}
for name, pts in HIGHWAYS.items():
    metres = [(m(x), m(y)) for x, y in pts]
    sm = chaikin(metres, 3)
    hw_lines[name] = resample(sm, 24.0)

# ------------------------------------------------------------------ build the graph
nodes = []        # [x, z]
node_id = {}
def add_node(x, z):
    nodes.append([round(x, 1), round(z, 1)])
    return len(nodes) - 1
for key, (x, z) in nodes_lat.items():
    node_id[key] = add_node(x, z)
edges = []        # [a, b, kind]  kind 0 street, 1 highway
for a, b in lat_edges:
    horiz = a[1] == b[1]
    line = a[1] if horiz else a[0]
    edges.append([node_id[a], node_id[b], 3 if line % 3 == 0 else 0])   # every third street is a faster avenue
hw_ids = {}
for name, pts in hw_lines.items():
    ids = []
    for (x, z) in pts:
        if abs(x) > HALF - 30 or abs(z) > HALF - 30: continue
        ids.append(add_node(x, z))
    hw_ids[name] = ids
    for i in range(len(ids) - 1):
        edges.append([ids[i], ids[i + 1], 1])
# connectors between highways and the lattice (traffic only, not drawn): at most one every ~120 m of highway
lat_pts = np.array([nodes[i] for i in node_id.values()]) if node_id else np.zeros((0, 2))
lat_idx = list(node_id.values())
connected = 0
for name, ids in hw_ids.items():
    last = -999.0
    for n_i, i in enumerate(ids):
        if len(lat_idx) == 0: break
        is_end = n_i == 0 or n_i == len(ids) - 1
        if not is_end and n_i * 24.0 - last < 120.0: continue
        d = np.hypot(lat_pts[:, 0] - nodes[i][0], lat_pts[:, 1] - nodes[i][1])
        j = int(d.argmin())
        if d[j] < (140.0 if is_end else 40.0):
            edges.append([i, lat_idx[j], 2])
            connected += 1
            last = n_i * 24.0
all_hw = [(n, i) for n, ids in hw_ids.items() for i in ids]
hw_pts = np.array([nodes[i] for _, i in all_hw]) if all_hw else np.zeros((0, 2))
for n1, i in all_hw:
    d = np.hypot(hw_pts[:, 0] - nodes[i][0], hw_pts[:, 1] - nodes[i][1])
    for t, (n2, j) in enumerate(all_hw):
        if n2 != n1 and d[t] < 30.0 and j > i:
            edges.append([i, j, 1])

# ------------------------------------------------------------------ airport compound (metres; all coordinates are multiples of 25)
AP = {"rect": [550, -1100, 1125, -750], "gate": [700, -750]}
road_nodes = {}
def road_node(x, z):
    key = (round(x), round(z))
    if key not in road_nodes:
        # reuse an existing graph node at this spot
        for i, (nx, nz) in enumerate(nodes):
            if abs(nx - x) < 1.5 and abs(nz - z) < 1.5:
                road_nodes[key] = i
                break
        else:
            road_nodes[key] = len(nodes)
            nodes.append([float(x), float(z)])
    return road_nodes[key]
def add_path(pts, kind, step=24.0):
    prev = None
    for (x0, z0), (x1, z1) in zip(pts[:-1], pts[1:]):
        dist = math.hypot(x1 - x0, z1 - z0)
        n = max(1, int(math.ceil(dist / step)))
        for k in range(n + 1):
            t = k / n
            nid = road_node(x0 + (x1 - x0) * t, z0 + (z1 - z0) * t)
            if prev is not None and prev != nid:
                edges.append([prev, nid, kind])
            prev = nid
# internal roads
add_path([(700, -750), (700, -850)], 0)                 # entrance road
add_path([(600, -850), (1100, -850)], 0)                # drop-off / service road along the terminal front
add_path([(625, -800), (875, -800)], 0)                 # parking aisle
# approach road from the city: nearest lattice node to the gate, then straight to the gate
gate = (700, -750)
best = None
for k_, (x, z) in nodes_lat.items():
    d_ = math.hypot(x - gate[0], z - gate[1])
    if best is None or d_ < best[0]: best = (d_, x, z)
_, bx0, bz0 = best
corner = (gate[0], bz0) if abs(bz0 - gate[1]) > abs(bx0 - gate[0]) else (bx0, gate[1])
print("airport approach from lattice node", bx0, bz0, "via", corner)
approach = [(bx0, bz0)]
if corner != (bx0, bz0): approach.append(corner)
approach.append(gate)
add_path(approach, 3)
# blocks: lattice cells with all four corners present and no highway through them
blocked = np.zeros((len(list(ks)) + 2, len(list(ks)) + 2), bool)
hw_all_pts = np.array([p for pts in hw_lines.values() for p in pts]) if hw_lines else np.zeros((0, 2))
def hw_near(cx, cz, half):
    if len(hw_all_pts) == 0: return False
    return bool(((np.abs(hw_all_pts[:, 0] - cx) < half) & (np.abs(hw_all_pts[:, 1] - cz) < half)).any())
cells = []
for (k, mm) in nodes_lat:
    c = [(k, mm), (k + 1, mm), (k, mm + 1), (k + 1, mm + 1)]
    if all(x in nodes_lat for x in c):
        cx, cz = (k + 0.5) * PITCH, (mm + 0.5) * PITCH
        if hw_near(cx, cz, PITCH * 0.5 + 6.0):
            kind = "plaza"
        else:
            z = zone_at(cx, cz)
            kind = {ZONE["DOWNTOWN"]: "downtown", ZONE["INDUSTRIAL"]: "industrial"}.get(z, "urban")
        stad_d = math.hypot(cx - m(STADIUM[0]), cz - m(STADIUM[1]))
        if stad_d < STADIUM[2] * K * 1.25: kind = "stadium"
        cells.append([k, mm, kind])

# ------------------------------------------------------------------ features
def mpt(p): return [round(m(p[0]), 1), round(m(p[1]), 1)]
features = {
    "piers": [[mpt(a), mpt(b)] for a, b in PIERS],
    "bridge": [[round(x, 1), round(z, 1)] for x, z in hw_lines["island_bridge"]],
    "stadium": [round(m(STADIUM[0]), 1), round(m(STADIUM[1]), 1), round(STADIUM[2] * K, 1)],
    "airport": {"rect": AP["rect"], "gate": AP["gate"]},
}
pois = [
    {"kind": "stadium", "name": "REDLINE STADIUM", "pos": mpt((STADIUM[0], STADIUM[1]))},
    {"kind": "airport", "name": "REDLINE AIRPORT", "pos": [850.0, -930.0]},
    {"kind": "harbour", "name": "WEST HARBOUR", "pos": mpt((180, 560))},
    {"kind": "pier", "name": "SOUTH PIER", "pos": mpt((582, 1040))},
    {"kind": "beach", "name": "REDLINE BEACH", "pos": mpt((620, 940))},
    {"kind": "island", "name": "SAN ISLA", "pos": mpt((230, 1100))},
    {"kind": "park", "name": "CENTRAL PARK", "pos": mpt((610, 260))},
    {"kind": "park", "name": "EAST PARK", "pos": mpt((980, 460))},
    {"kind": "mountain", "name": "REDLINE RANGE", "pos": mpt((150, 90))},
    {"kind": "desert", "name": "SANDY BASIN", "pos": mpt((1160, 440))},
]
city = {
    "half": HALF, "pitch": PITCH, "road_w": ROAD_W,
    "nodes": nodes, "edges": edges,
    "cells": cells,
    "hw": {k: [[round(x, 1), round(z, 1)] for x, z in v] for k, v in hw_lines.items()},
    "features": features, "pois": pois,
}
with open(os.path.join(OUT, "city.json"), "w") as f:
    json.dump(city, f, separators=(",", ":"))

# ================================================================== terrain heights (8 m grid) and zone grid (4 m)
def fbm(sig_list, weights, seed):
    r = np.random.default_rng(seed)
    acc = np.zeros((R, R))
    for sg, w in zip(sig_list, weights):
        f = ndi.gaussian_filter(r.standard_normal((R, R)), sg)
        f /= np.abs(f).max() + 1e-9
        acc += f * w
    return acc / sum(weights)

water_m = np.isin(Z, [ZONE["SEA"], ZONE["LAKE"]])
dist_land = ndi.distance_transform_edt(water_m) * 2.0          # metres from the shore, inside the water
dist_water = ndi.distance_transform_edt(~water_m) * 2.0        # metres from the water, on land
H = np.zeros((R, R))
ramp = np.clip(1.0 - dist_water / 16.0, 0.0, 1.0) ** 1.5
H = np.where(~water_m, -1.0 * ramp, H)
sea_depth = -1.0 - np.clip(dist_land / 60.0, 0.0, 1.0) * 9.0
lake_depth = -3.0 - np.clip(dist_land / 40.0, 0.0, 1.0) * 3.0
H = np.where(Z == ZONE["SEA"], sea_depth, H)
H = np.where(Z == ZONE["LAKE"], lake_depth, H)
mount_mask = ndi.gaussian_filter((Z == ZONE["MOUNTAIN"]).astype(float), 26)
peaks = (fbm([60, 26, 10], [0.6, 0.3, 0.1], 11) * 0.5 + 0.5) ** 1.3 * 75.0
desert_mask = ndi.gaussian_filter(((Z == ZONE["DESERT"]) | (Z == ZONE["AIRPORT"])).astype(float), 18)
dunes = fbm([35, 14], [0.7, 0.3], 12) * 2.6
park_mask = ndi.gaussian_filter((Z == ZONE["PARK"]).astype(float), 16)
bumps = fbm([30, 12], [0.7, 0.3], 13) * 0.7
land_only = ~water_m
H = H + np.where(land_only, mount_mask * peaks + desert_mask * dunes + park_mask * bumps, 0.0)
# flatten the city and the ground along every road
city_mask = ndi.gaussian_filter(np.isin(Z, [ZONE["URBAN"], ZONE["DOWNTOWN"], ZONE["INDUSTRIAL"], ZONE["STADIUM"], ZONE["BEACH"]]).astype(float), 8)
# the airport stays flat too
air_mask = ndi.gaussian_filter((Z == ZONE["AIRPORT"]).astype(float), 10)
road_img = Image.new("L", (R, R), 0)
rd = ImageDraw.Draw(road_img)
for a, b, kind in edges:
    pa, pb = nodes[a], nodes[b]
    rd.line([((pa[0] + HALF) / 2.0, (pa[1] + HALF) / 2.0), ((pb[0] + HALF) / 2.0, (pb[1] + HALF) / 2.0)], fill=255, width=3)
d_road = ndi.distance_transform_edt(np.array(road_img) < 128) * 2.0
flat = np.clip((d_road - 14.0) / 46.0, 0.0, 1.0)
flat = flat * flat * (3 - 2 * flat)
pos = np.where(H > 0, H, 0.0)
neg = np.where(H <= 0, H, 0.0)
pos = pos * flat * (1.0 - city_mask) * (1.0 - air_mask)
H = np.where(water_m, H, neg + pos)
H = np.where(H > 0, np.maximum(H, 0.0), H)
# 8 m sampling grid (301 x 301 vertices)
NV = 301
hv = np.zeros((NV, NV), np.float32)
for iz in range(NV):
    for ix in range(NV):
        hv[iz, ix] = H[min(R - 1, iz * 4), min(R - 1, ix * 4)]
hv.tofile(os.path.join(OUT, "height.bin"))
Z[::2, ::2].astype(np.uint8).tofile(os.path.join(OUT, "zones.bin"))   # 600 x 600

# ================================================================== map art (parchment style)
def render_map(S, labels, out_name):

    SCALE = S / (HALF * 2.0)        # px per metre
    def P(x, z): return ((x + HALF) * SCALE, (z + HALF) * SCALE)
    def PD(x, y): return P(m(x), m(y))

    def fnt(sz):
        try: return ImageFont.truetype(FONT, sz)
        except Exception: return ImageFont.load_default()

    art = Image.new("RGB", (S, S), (214, 188, 138))
    zimg = np.array(Image.fromarray(Z).resize((S, S), Image.NEAREST))
    rgb = np.zeros((S, S, 3), np.uint8)
    pal = {ZONE["SEA"]: (24, 118, 138), ZONE["BEACH"]: (236, 214, 150), ZONE["URBAN"]: (222, 190, 128), ZONE["DOWNTOWN"]: (214, 182, 122),
           ZONE["PARK"]: (128, 160, 88), ZONE["DESERT"]: (222, 154, 78), ZONE["MOUNTAIN"]: (196, 112, 52), ZONE["AIRPORT"]: (196, 190, 168),
           ZONE["INDUSTRIAL"]: (198, 176, 130), ZONE["LAKE"]: (38, 124, 138), ZONE["STADIUM"]: (200, 188, 150)}
    for k, c in pal.items():
        rgb[zimg == k] = c
    # sea depth shading
    wmask = np.isin(zimg, [ZONE["SEA"], ZONE["LAKE"]])
    dw = ndi.distance_transform_edt(wmask) / 70.0
    dw = np.clip(dw, 0, 1)
    sea_shallow = np.array([62, 168, 172], float)
    sea_deep = np.array([18, 98, 124], float)
    sea_img = (sea_shallow[None, None, :] * (1 - dw[..., None]) + sea_deep[None, None, :] * dw[..., None])
    rgb = np.where(wmask[..., None], sea_img, rgb).astype(np.uint8)
    # shore foam line
    edge = ndi.binary_dilation(~wmask, iterations=3) & wmask
    rgb[edge] = (210, 232, 214)
    # grain and terrain texture
    grain = rng.normal(0, 7, (S, S, 1))
    big = ndi.gaussian_filter(rng.standard_normal((S, S)), 40)[..., None] * 60
    rgb = np.clip(rgb.astype(float) + grain + big * 0.18, 0, 255).astype(np.uint8)
    art = Image.fromarray(rgb)
    dr = ImageDraw.Draw(art, "RGBA")

    # mountains: hachure strokes
    mz = (zimg == ZONE["MOUNTAIN"])
    ys, xs = np.nonzero(mz[::14, ::14])
    for y, x in zip(ys, xs):
        px, py = x * 14 + pyrng.randint(-5, 5), y * 14 + pyrng.randint(-5, 5)
        dr.line([(px, py), (px + 14, py - 12), (px + 26, py + 4)], fill=(120, 62, 28, 150), width=3)
        dr.line([(px + 14, py - 12), (px + 15, py + 8)], fill=(246, 190, 120, 120), width=2)
    # desert specks and park trees
    for zone_id, col, n in [(ZONE["DESERT"], (170, 100, 40, 110), 5000), (ZONE["PARK"], (50, 110, 56, 190), 9000)]:
        ys, xs = np.nonzero(zimg == zone_id)
        if len(ys):
            sel = rng.integers(0, len(ys), n)
            for i in sel:
                r_ = 3 if zone_id == ZONE["PARK"] else 2
                dr.ellipse([xs[i] - r_, ys[i] - r_, xs[i] + r_, ys[i] + r_], fill=col)

    # roads: casing then fill
    def road_poly(a, b, w, fill, outline=None):
        ax, az = P(*a); bx, bz = P(*b)
        dr.line([(ax, az), (bx, bz)], fill=fill, width=max(1, int(w * SCALE)))
    for pass_i in range(2):
        for a, b, kind in edges:
            pa, pb = nodes[a], nodes[b]
            if kind == 0:
                if pass_i == 0: road_poly(pa, pb, ROAD_W + 5, (120, 98, 70, 255))
                else: road_poly(pa, pb, ROAD_W - 2, (244, 232, 196, 255))
            elif kind == 3:
                if pass_i == 0: road_poly(pa, pb, ROAD_W + 12, (74, 52, 30, 255))
                else: road_poly(pa, pb, ROAD_W + 4, (255, 214, 120, 255))
            elif kind == 2:
                if pass_i == 0: road_poly(pa, pb, ROAD_W + 5, (120, 98, 70, 255))
                else: road_poly(pa, pb, ROAD_W - 2, (244, 232, 196, 255))
            else:
                if pass_i == 0: road_poly(pa, pb, 26, (30, 32, 34, 255))
                else: road_poly(pa, pb, 18, (74, 78, 80, 255))
    # city blocks as little buildings
    for k, mm, kind in cells:
        cx, cz = (k + 0.5) * PITCH, (mm + 0.5) * PITCH
        x0, y0 = P(cx - 30, cz - 30)
        x1, y1 = P(cx + 30, cz + 30)
        if kind == "downtown":
            for i in range(2):
                for j in range(2):
                    bx = x0 + (x1 - x0) * (0.06 + i * 0.5); by = y0 + (y1 - y0) * (0.06 + j * 0.5)
                    dr.rectangle([bx + 3, by + 3, bx + (x1 - x0) * 0.42 + 3, by + (y1 - y0) * 0.42 + 3], fill=(40, 36, 30, 110))
                    dr.rectangle([bx, by, bx + (x1 - x0) * 0.42, by + (y1 - y0) * 0.42], fill=(70, 74, 82, 255), outline=(30, 32, 36, 255))
        elif kind == "urban":
            for i in range(3):
                for j in range(2):
                    bx = x0 + (x1 - x0) * (0.08 + i * 0.31); by = y0 + (y1 - y0) * (0.1 + j * 0.46)
                    dr.rectangle([bx, by, bx + (x1 - x0) * 0.26, by + (y1 - y0) * 0.36], fill=(176, 142, 96, 255), outline=(120, 92, 60, 255))
        elif kind == "industrial":
            dr.rectangle([x0 + 4, y0 + 4, x1 - 4, y1 - 4], fill=(160, 150, 128, 255), outline=(100, 94, 80, 255))
            for i in range(3):
                dr.rectangle([x0 + 8 + i * (x1 - x0) * 0.3, y0 + 10, x0 + 8 + i * (x1 - x0) * 0.3 + 18, y0 + 30], fill=(58, 90, 128, 255))
        elif kind == "plaza":
            dr.rectangle([x0 + 4, y0 + 4, x1 - 4, y1 - 4], fill=(132, 168, 92, 255))
        elif kind == "stadium":
            pass
    # piers and bridge
    for a, b in PIERS:
        pa, pb = PD(*a), PD(*b)
        dr.line([pa, pb], fill=(80, 56, 36, 255), width=11)
        dr.line([pa, pb], fill=(176, 138, 90, 255), width=7)
    for bn in ["island_bridge", "harbour_bridge", "peninsula_bridge"]:
        bpts = [P(*p) for p in hw_lines[bn] if zone_at(*p) in (ZONE["SEA"], ZONE["LAKE"])]
        if len(bpts) >= 2:
            dr.line(bpts, fill=(30, 26, 22, 255), width=24)
            dr.line(bpts, fill=(214, 198, 168, 255), width=15)
            dr.line(bpts, fill=(120, 100, 76, 255), width=2)
            for q in (bpts[0], bpts[-1]):
                dr.ellipse([q[0] - 12, q[1] - 12, q[0] + 12, q[1] + 12], fill=(214, 198, 168, 255), outline=(30, 26, 22, 255), width=3)
    # airport
    x0, z0, x1, z1 = features["airport"]["rect"]
    dr.rectangle([P(x0, z0), P(x1, z1)], fill=(176, 174, 156, 255), outline=(70, 66, 54, 255), width=4)
    def rect_m(a_, b_, c_, d_, col, out=None):
        dr.rectangle([P(a_, b_), P(c_, d_)], fill=col, outline=out)
    rect_m(560, -1022, 1115, -992, (34, 34, 38, 255))                    # runway (north side)
    dr.line([P(570, -1007), P(1105, -1007)], fill=(235, 235, 225, 255), width=3)
    rect_m(560, -990, 1050, -905, (96, 98, 104, 255))                     # taxiways and apron
    rect_m(600, -905, 1090, -866, (206, 204, 190, 255), (30, 30, 34, 255))   # terminal and jet bridges
    rect_m(1060, -940, 1112, -880, (150, 150, 146, 255))                  # hangars
    rect_m(620, -835, 880, -765, (120, 122, 128, 255))                    # parking
    dr.ellipse([P(1040, -830)[0] - 14, P(1040, -830)[1] - 14, P(1040, -830)[0] + 14, P(1040, -830)[1] + 14], fill=(62, 64, 72, 255), outline=(240, 240, 232, 255), width=2)
    # stadium
    cx, cz, r_ = features["stadium"]
    sx_, sz_ = P(cx, cz)
    rp = r_ * SCALE
    dr.ellipse([sx_ - rp, sz_ - rp * 0.8, sx_ + rp, sz_ + rp * 0.8], fill=(168, 160, 150, 255), outline=(60, 56, 50, 255), width=4)
    dr.ellipse([sx_ - rp * 0.86, sz_ - rp * 0.68, sx_ + rp * 0.86, sz_ + rp * 0.68], fill=(176, 52, 44, 255))
    dr.ellipse([sx_ - rp * 0.62, sz_ - rp * 0.48, sx_ + rp * 0.62, sz_ + rp * 0.48], fill=(82, 150, 70, 255), outline=(236, 236, 226, 255), width=2)
    # boats in the bays
    for _ in range(26):
        bx, bz = rng.uniform(-HALF + 60, HALF - 60), rng.uniform(-HALF + 60, HALF - 60)
        if zone_at(bx, bz) == ZONE["SEA"] and ndi.distance_transform_edt is not None:
            px, pz = P(bx, bz)
            dr.polygon([(px - 7, pz), (px + 7, pz - 3), (px + 7, pz + 3)], fill=(240, 236, 224, 230))
    # vignette and frame
    vig = Image.new("L", (S, S), 0)
    vd = ImageDraw.Draw(vig)
    vd.rectangle([0, 0, S, S], fill=0)
    vig = ndi.gaussian_filter(np.array(vig, float), 1)
    yy2, xx2 = np.mgrid[0:S, 0:S]
    fall = ((xx2 - S / 2) ** 2 + (yy2 - S / 2) ** 2) ** 0.5 / (S * 0.72)
    fall = np.clip(fall, 0, 1) ** 2.6
    arr = np.array(art).astype(float) * (1 - fall[..., None] * 0.42) + np.array([60, 40, 22], float)[None, None, :] * (fall[..., None] * 0.18)
    art = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    dr = ImageDraw.Draw(art, "RGBA")
    if labels:
        dr.rounded_rectangle([6, 6, S - 7, S - 7], radius=34, outline=(30, 24, 18, 255), width=12)
        dr.rounded_rectangle([22, 22, S - 23, S - 23], radius=26, outline=(196, 168, 112, 255), width=4)

    # name plates
    def plate(text, xm, zm, size=46):
        f = fnt(size)
        bb = dr.textbbox((0, 0), text, font=f)
        w, h = bb[2] - bb[0] + 36, bb[3] - bb[1] + 22
        px, pz = P(xm, zm)
        dr.rounded_rectangle([px - w / 2 + 4, pz - h / 2 + 4, px + w / 2 + 4, pz + h / 2 + 4], radius=14, fill=(30, 20, 10, 110))
        dr.rounded_rectangle([px - w / 2, pz - h / 2, px + w / 2, pz + h / 2], radius=14, fill=(238, 214, 162, 245), outline=(92, 66, 38, 255), width=3)
        dr.text((px - (bb[2] - bb[0]) / 2 - bb[0], pz - (bb[3] - bb[1]) / 2 - bb[1]), text, font=f, fill=(58, 36, 18, 255))
    for poi in (pois if labels else []):
        if poi["kind"] in ("mountain", "desert", "island", "airport", "harbour", "park", "beach", "pier", "stadium"):
            plate(poi["name"], poi["pos"][0], poi["pos"][1] - (60 if poi["kind"] in ("stadium", "beach") else 0))
    if labels:
        plate("DOWNTOWN", 40, -10, 52)
        plate("PACIFIC OCEAN", m(720), m(1130), 56)
    if labels:
        # compass rose
        cx0, cz0 = S - 170, S - 170
        dr.ellipse([cx0 - 70, cz0 - 70, cx0 + 70, cz0 + 70], fill=(238, 214, 162, 220), outline=(92, 66, 38, 255), width=4)
        dr.polygon([(cx0, cz0 - 64), (cx0 - 16, cz0), (cx0 + 16, cz0)], fill=(176, 40, 30, 255))
        dr.polygon([(cx0, cz0 + 64), (cx0 - 16, cz0), (cx0 + 16, cz0)], fill=(58, 36, 18, 255))
        dr.text((cx0 - 11, cz0 - 98), "N", font=fnt(44), fill=(58, 36, 18, 255))
    art.save(os.path.join(OUT, out_name))
    print("nodes", len(nodes), "edges", len(edges), "cells", len(cells), "connectors", connected)
    print("zone counts", {k: int((Z == v).sum()) for k, v in ZONE.items()})


render_map(2048, True, "city_map.png")
render_map(4096, False, "city_minimap.png")
