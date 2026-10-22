class_name MiamiParks
extends RefCounted
## Redline Island's big open spaces, inside the two half-circle boulevards and on the sand:
##  west  - an 8-hole golf course with a club house and a driving range
##  east  - a park cut by a square ring canal (boats cruise round it, footbridges cross it) with an island plaza, a lake, a football
##          pitch and gazebos
##  beach - a boardwalk fair with a giant Ferris wheel, a pirate ship, stalls and bumper cars
## Ponds, lakes and canals are real holes in the ground (Coast.holes) with a bowl, a seabed and water, and Coast.water_shapes makes
## them swimmable.

const GOLF_C := Vector2(-224.0, 2200.0)
const GOLF_R := 226.0
const EAST_C := Vector2(624.0, 2200.0)
const FAIR := Rect2(-575.0, 2090.0, 63.0, 220.0)
const RING_OUT := Rect2(640.0, 2110.0, 170.0, 180.0)
const RING_IN := Rect2(660.0, 2130.0, 130.0, 140.0)
const CANAL_BED := -3.2
static var CH_EAST := Rect2(810.0, 2190.0, 360.0, 20.0)       # shortened in plan() to end at the shoreline
static var CH_NORTH := Rect2(190.0, 1700.0, 20.0, 150.0)
const BASIN := Rect2(100.0, 1850.0, 200.0, 50.0)
const WATER_Y := -0.55
const PZ := "res://assets/plaza/"

static var ponds: Array = []          # {c, rx, rz, rect}
static var strips: Array = []         # the four canal strips (Rect2)
static var channels: Array = []       # the sea channel (east), the north channel and the marina basin
static var keepout: Array = []        # Rect2s the beachfront rows and street furniture leave clear
static var boats: Array = []
static var bridge: DrawBridge
static var fence_root: Node3D

# ------------------------------------------------------------------ plan (before the terrain is built)

static func _snap(v: float, up: bool) -> float:
	return (ceilf(v / 5.0) if up else floorf(v / 5.0)) * 5.0

static func _golf_holes() -> Array:
	var out: Array = []
	var bs := [-176.0, -132.0, -88.0, -44.0, 44.0, 88.0, 132.0, 176.0]
	var near := GOLF_C.x - 14.0
	for i in range(bs.size()):
		var b: float = bs[i]
		var far := GOLF_C.x - sqrt(maxf(GOLF_R * GOLF_R - b * b, 1.0)) + 20.0
		var fwd := i % 2 == 0
		out.append({"i": i, "b": b, "tee": Vector2(near if fwd else far, GOLF_C.y + b), "green": Vector2(far if fwd else near, GOLF_C.y + b)})
	return out

static func _add_pond(c: Vector2, rx: float, rz: float, area := "park", top := 0.0, kind := "pond") -> void:
	var rect := Rect2(_snap(c.x - rx - 3.0, false), _snap(c.y - rz - 3.0, false), 0.0, 0.0)
	rect.end = Vector2(_snap(c.x + rx + 3.0, true), _snap(c.y + rz + 3.0, true))
	ponds.append({"c": c, "rx": rx, "rz": rz, "rect": rect, "area": area, "top": top, "kind": kind})
	Coast.holes.append(rect)
	if top > 0.0: CityBuild.holes.append(rect)            # the paved slab of a block is cut open over the pond too
	Coast.water_shapes.append([0, c.x, c.y, rx, rz])

static func plan() -> void:
	ponds.clear()
	strips.clear()
	Coast.water_shapes.clear()
	keepout.clear()
	Miami._reserve_metro()
	for h in _golf_holes():
		if h.i in [1, 4, 6]:
			var mid: Vector2 = (h.tee as Vector2).lerp(h.green as Vector2, 0.5)
			_add_pond(Vector2(mid.x + (20.0 if h.i == 4 else 0.0), mid.y + 19.5), 13.0, 8.0, "golf")
	_add_pond(Vector2(725.0, 2162.0), 22.0, 15.0, "east")        # the island's pond
	_add_pond(Vector2(700.0, 2368.0), 40.0, 22.0, "east")        # the lake in the south
	_add_pond(Vector2(768.0, 2035.0), 12.0, 7.0, "east")         # a small pond beside the football pitch
	# the ponds of the courtyards and the pools and ponds of the estates: real holes in the ground, not boxes on top of it
	var lay := Miami.layout()
	for r in lay.courts:
		for pnd in Miami.courtyard_ponds(r):
			var pcn: Vector2 = pnd.c
			var rr := Rect2(pcn - Vector2(pnd.rx, pnd.rz) - Vector2(4, 4), (Vector2(pnd.rx, pnd.rz) + Vector2(4, 4)) * 2.0)
			if not Miami._overlaps_reserved(rr):
				_add_pond(pcn, pnd.rx, pnd.rz, "block", Miami.PY + 0.03, "pond")
	for e in lay.estates:
		var inf := Miami.estate_info(e.front, e.yaw, e.w, e.d)
		_add_pond(inf.pool_c, inf.pool_r.x, inf.pool_r.y, "block", Miami.PY + 0.03, "pool")

	for r in [Rect2(640, 2110, 170, 20), Rect2(640, 2270, 170, 20), Rect2(640, 2130, 20, 140), Rect2(790, 2130, 20, 140)]:
		strips.append(r)
		Coast.holes.append(r)
		Coast.water_shapes.append([1, r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, r.size.x * 0.5, r.size.y * 0.5])
	Coast.flat_rects.append(FAIR.grow(30.0))
	# the channel from the ring canal to the open sea (east), and the north marina with its own channel to the sea
	channels.clear()
	keepout.clear()
	# each channel extends past the beach and surf line into the deep open sea
	var xe := 810.0
	while xe < 1500.0 and (xe < 1090.0 or Coast.inland(xe, 2200.0) > -50.0): xe += 5.0
	CH_EAST = Rect2(810.0, 2190.0, snappedf(xe, 5.0) - 810.0, 20.0)
	var zn := 1850.0
	while zn > 1400.0 and (zn > 1660.0 or Coast.inland(200.0, zn) > -50.0): zn -= 5.0
	CH_NORTH = Rect2(190.0, snappedf(zn, 5.0), 20.0, 1850.0 - snappedf(zn, 5.0))
	for r in [CH_EAST, CH_NORTH, BASIN]:
		channels.append(r)
		Coast.holes.append(r)
		Coast.water_shapes.append([1, r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, r.size.x * 0.5, r.size.y * 0.5])
	keepout.append(CH_EAST.grow(4.0))
	keepout.append(FAIR.grow(12.0))                       # nothing else (beach bars, loungers, palms) stands against the fair's fence
	keepout.append(Rect2(180.0, CH_NORTH.position.y, 40.0, 1860.0 - CH_NORTH.position.y))
	keepout.append(BASIN.grow(12.0))
	MiamiFill.plan()

# ------------------------------------------------------------------ small geometry helpers

static func _tri(mb: Dictionary, mat: Material, a: Vector3, b: Vector3, c3: Vector3, n := Vector3.UP, uv_scale := 0.2) -> void:
	var s: Dictionary = Miami._surf(mb, mat)
	var base: int = (s.v as Array).size()
	for p in [a, b, c3]:
		(s.v as Array).append(p)
		(s.n as Array).append(n)
		(s.u as Array).append(Vector2(p.x, p.z) * uv_scale)
	(s.i as Array).append_array([base, base + 2, base + 1])           # Godot's front faces are clockwise

## A flat ellipse (fan) at height y, facing up.
static func _ellipse(mb: Dictionary, mat: Material, c: Vector2, rx: float, rz: float, y: float, seg := 36) -> void:
	for k in range(seg):
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		_tri(mb, mat, Vector3(c.x, y, c.y), Vector3(c.x + cos(a1) * rx, y, c.y + sin(a1) * rz), Vector3(c.x + cos(a0) * rx, y, c.y + sin(a0) * rz))

## Axis-aligned flat rectangle facing up.
static func _rect(mb: Dictionary, mat: Material, r: Rect2, y: float, uv := 0.2) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var b := Vector3(r.end.x, y, r.position.y)
	var c3 := Vector3(r.end.x, y, r.end.y)
	var d := Vector3(r.position.x, y, r.end.y)
	_tri(mb, mat, a, d, c3, Vector3.UP, uv)
	_tri(mb, mat, a, c3, b, Vector3.UP, uv)

## Ground between an ellipse and the rectangle round it, at height y (so a pond hole is closed up to the pond's edge).
static func _annulus(mb: Dictionary, mat: Material, c: Vector2, rx: float, rz: float, rect: Rect2, y: float) -> void:
	var thetas: Array = []
	for k in range(72): thetas.append(TAU * k / 72.0)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var d: Vector2 = corner - c
		thetas.append(fposmod(atan2(d.y / rz, d.x / rx), TAU))
	thetas.sort()
	var inner: Array = []
	var outer: Array = []
	for th in thetas:
		var pi_ := Vector2(c.x + cos(th) * rx, c.y + sin(th) * rz)
		var dir := (pi_ - c).normalized()
		var tx := INF
		var tz := INF
		if absf(dir.x) > 1e-5: tx = ((rect.end.x if dir.x > 0.0 else rect.position.x) - c.x) / dir.x
		if absf(dir.y) > 1e-5: tz = ((rect.end.y if dir.y > 0.0 else rect.position.y) - c.y) / dir.y
		var t := minf(tx, tz)
		inner.append(pi_)
		outer.append(c + dir * t)
	var n := inner.size()
	for k in range(n):
		var k2 := (k + 1) % n
		var a := Vector3(inner[k].x, y, inner[k].y)
		var b := Vector3(inner[k2].x, y, inner[k2].y)
		var c2 := Vector3(outer[k2].x, y, outer[k2].y)
		var d := Vector3(outer[k].x, y, outer[k].y)
		_tri(mb, mat, a, b, c2)
		_tri(mb, mat, a, c2, d)

## A bowl: the ellipse edge at y0 sloping down to a smaller ellipse at the pond bed.
static func _bowl(mb: Dictionary, mat: Material, c: Vector2, rx: float, rz: float, y0: float, y1: float, seg := 36) -> void:
	var rx2 := maxf(rx - 4.0, 1.0)
	var rz2 := maxf(rz - 3.0, 1.0)
	for k in range(seg):
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var o0 := Vector3(c.x + cos(a0) * rx, y0, c.y + sin(a0) * rz)
		var o1 := Vector3(c.x + cos(a1) * rx, y0, c.y + sin(a1) * rz)
		var i0 := Vector3(c.x + cos(a0) * rx2, y1, c.y + sin(a0) * rz2)
		var i1 := Vector3(c.x + cos(a1) * rx2, y1, c.y + sin(a1) * rz2)
		var n := Vector3(0.0, 0.8, 0.0)
		_tri(mb, mat, i0, i1, o1, n)
		_tri(mb, mat, i0, o1, o0, n)
		_tri(mb, mat, Vector3(c.x, y1, c.y), i1, i0)

static func _water_surface(c: Dictionary, mb: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Miami._finish(mb)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(c.w as World).static_root.add_child(mi)

static func _solid(c: Dictionary, mb: Dictionary, collide := true) -> void:
	var mesh := Miami._finish(mb)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(c.w as World).static_root.add_child(mi)
	if collide and mesh.get_surface_count() > 0:
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		(c.body as StaticBody3D).add_child(cs)

static func _lawn_mat(c: Dictionary, tint := Color(0.8, 1.0, 0.65)) -> StandardMaterial3D:
	return (c.w as World)._mat("res://assets/textures/y2k_grass.png", 0.2, tint)

static func _two_tone(c1: Color, c2: Color) -> StandardMaterial3D:
	var k := "mow|%s|%s" % [c1.to_html(), c2.to_html()]
	if Miami._mats.has(k): return Miami._mats[k]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			img.set_pixel(x, y, c1 if x < 32 else c2)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.95
	Miami._mats[k] = m
	return m

# ------------------------------------------------------------------ ponds

## Vertical-walled pit (swimming pool): walls from y_top down to a flat bed.
static func _pit(mb: Dictionary, wall: Material, bed: Material, c: Vector2, rx: float, rz: float, y_top: float, y_bed: float, seg := 40) -> void:
	for k in range(seg):
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var t0 := Vector3(c.x + cos(a0) * rx, y_top, c.y + sin(a0) * rz)
		var t1 := Vector3(c.x + cos(a1) * rx, y_top, c.y + sin(a1) * rz)
		var b0 := Vector3(t0.x, y_bed, t0.z)
		var b1 := Vector3(t1.x, y_bed, t1.z)
		Miami._quad(mb, wall, b1, b0, t0, t1, 0.4)          # faces the middle of the pit
		_tri(mb, bed, Vector3(c.x, y_bed, c.y), b1, b0)

## A flat ring of width w round an ellipse (stone coping).
static func _ring(mb: Dictionary, mat: Material, c: Vector2, rx: float, rz: float, w: float, y: float, seg := 40) -> void:
	for k in range(seg):
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var i0 := Vector3(c.x + cos(a0) * rx, y, c.y + sin(a0) * rz)
		var i1 := Vector3(c.x + cos(a1) * rx, y, c.y + sin(a1) * rz)
		var o0 := Vector3(c.x + cos(a0) * (rx + w), y, c.y + sin(a0) * (rz + w))
		var o1 := Vector3(c.x + cos(a1) * (rx + w), y, c.y + sin(a1) * (rz + w))
		_tri(mb, mat, i0, i1, o1)
		_tri(mb, mat, i0, o1, o0)

static func _pond_build(c: Dictionary, pd: Dictionary, rng: RandomNumberGenerator, grass: Material) -> void:
	var ctr: Vector2 = pd.c
	var rx: float = pd.rx
	var rz: float = pd.rz
	var top: float = pd.top
	var pool: bool = String(pd.kind) == "pool"
	var mb := {}
	if pool:
		# a swimming pool: tiled deck, white stone coping, vertical tiled walls, a light bed and bright water
		var tile := Miami._surface_mat("pooldeck", "PavingStones130", 0.45, Color(1.15, 1.05, 0.95), 0.8)
		_annulus(mb, tile, ctr, rx, rz, pd.rect, top)
		var wall := Miami._flat(Color(0.55, 0.83, 0.88), 0.4)
		_pit(mb, wall, Miami._flat(Color(0.4, 0.74, 0.82), 0.5), ctr, rx, rz, top, -1.6)
		_ring(mb, Miami._flat(Color("#fbfaf4"), 0.6), ctr, rx, rz, 0.7, top + 0.06)
		_solid(c, mb)
		var wp := {}
		_ellipse(wp, Miami._water_mat(true), ctr, rx + 0.05, rz + 0.05, top - 0.28)
		_water_surface(c, wp)
		var body: StaticBody3D = c.body
		# loungers and parasols along the long sides, palms at the corners
		var lm := {}
		for k in range(3):
			var lx := ctr.x - 3.0 + k * 3.0
			for sgn in [-1.0, 1.0]:
				var lz: float = ctr.y + sgn * (rz + 2.4)
				Miami._box(lm, Miami._flat(Color("#ffffff"), 0.6), Vector3(lx - 0.35, top, lz - 1.0), Vector3(lx + 0.35, top + 0.32, lz + 1.0), 1.0)
				Miami._box(lm, Miami._flat(Color("#ff7aa8"), 0.8), Vector3(lx - 0.3, top + 0.32, lz - 0.95), Vector3(lx + 0.3, top + 0.38, lz + 0.3), 1.0)
				CoastProps._box(body, Vector3(0.8, 0.4, 2.0), Vector3(lx, top + 0.2, lz))
		_solid(c, lm, false)
		Miami._put("btable", Vector3(ctr.x + rx + 2.2, top, ctr.y), 0.0, 1.0)
		CoastProps._box(body, Vector3(1.6, 2.4, 1.6), Vector3(ctr.x + rx + 2.2, top + 1.2, ctr.y))
		for sx in [-1.0, 1.0]:
			Miami._palm(body, Vector2(ctr.x + sx * (rx + 3.5), ctr.y - rz - 3.0), rng, "m")
		return
	_annulus(mb, grass, ctr, rx, rz, pd.rect, top)
	var bed := Miami._flat(Color(0.55, 0.5, 0.38), 0.95)
	_bowl(mb, bed, ctr, rx, rz, top, Coast.POOL_DEPTH)
	if top > 0.0:
		_ring(mb, Miami._surface_mat("rim", "PavingStones136", 0.5, Color(0.85, 0.82, 0.75), 0.9), ctr, rx, rz, 0.8, top + 0.05)
	_solid(c, mb)
	var wb := {}
	_ellipse(wb, Miami._water_mat(false), ctr, rx + 0.4, rz + 0.4, WATER_Y)
	_water_surface(c, wb)
	var body2: StaticBody3D = c.body
	var n := int((rx + rz) * 1.1)
	for k in range(n):
		var a := TAU * k / n + rng.randf() * 0.2
		var p := ctr + Vector2(cos(a) * (rx + 2.2 + rng.randf() * 1.5), sin(a) * (rz + 2.2 + rng.randf() * 1.5))
		match k % 5:
			0: Miami._put("fern", Vector3(p.x, top, p.y), rng.randf() * TAU, rng.randf_range(0.9, 1.4))
			1: Miami._put("bush", Vector3(p.x, top, p.y), rng.randf() * TAU, rng.randf_range(0.9, 1.5))
			2: Miami._put("monstera", Vector3(p.x, top, p.y), rng.randf() * TAU, rng.randf_range(0.9, 1.3))
			3: Miami._put("bush", Vector3(p.x, top, p.y), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
			4:
				Miami._put("banana", Vector3(p.x, top, p.y), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
				CoastProps._box(body2, Vector3(0.5, 3.0, 0.5), Vector3(p.x, top + 1.5, p.y))
	var lily := Miami._flat(Color("#2f9e4a"), 0.8)
	var bloom := Miami._flat(Color("#ff8fb8"), 0.7)
	var lm2 := {}
	for k in range(int(rx * rz * 0.12)):
		var a2 := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.8
		var lp := Vector2(ctr.x + cos(a2) * rx * r, ctr.y + sin(a2) * rz * r)
		_ellipse(lm2, lily, lp, rng.randf_range(0.35, 0.6), rng.randf_range(0.35, 0.6), WATER_Y + 0.03, 8)
		if rng.randf() < 0.3:
			_ellipse(lm2, bloom, lp + Vector2(0.1, 0.0), 0.14, 0.14, WATER_Y + 0.06, 6)
	_water_surface(c, lm2)

## The ponds and pools carved into the blocks (courtyards and estates).
static func _block_waters(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var grass := _lawn_mat(c, Color(0.65, 0.95, 0.5))
	for pd in ponds:
		if String(pd.area) == "block" or String(pd.area) == "south": _pond_build(c, pd, rng, grass)

# ------------------------------------------------------------------ golf

static func _flag(c: Dictionary, p: Vector2) -> void:
	var mb := {}
	Miami._box(mb, Miami._flat(Color("#f4f4ee")), Vector3(p.x - 0.03, 0.06, p.y - 0.03), Vector3(p.x + 0.03, 2.4, p.y + 0.03), 1.0)
	var red := Miami._flat(Color("#e0262d"))
	Miami._quad(mb, red, Vector3(p.x, 2.4, p.y), Vector3(p.x, 2.4, p.y + 0.7), Vector3(p.x, 1.9, p.y + 0.35), Vector3(p.x, 1.9, p.y), 1.0)
	Miami._quad(mb, red, Vector3(p.x, 1.9, p.y), Vector3(p.x, 1.9, p.y + 0.35), Vector3(p.x, 2.4, p.y + 0.7), Vector3(p.x, 2.4, p.y), 1.0)
	_solid(c, mb, false)

static func _golf(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var fair := _two_tone(Color(0.33, 0.62, 0.22), Color(0.4, 0.7, 0.27))
	var green_m := Miami._flat(Color(0.2, 0.55, 0.2), 0.95)
	var fringe := Miami._flat(Color(0.27, 0.6, 0.23), 0.95)
	var tee_m := Miami._flat(Color(0.24, 0.5, 0.2), 0.95)
	var sand := Miami._flat(Color(0.93, 0.86, 0.66), 0.98)
	var mb := {}
	var holes := _golf_holes()
	for h in holes:
		var tee: Vector2 = h.tee
		var green: Vector2 = h.green
		var dir := signf(green.x - tee.x)
		var x0 := minf(tee.x, green.x) - 4.0
		var x1 := maxf(tee.x, green.x) + 4.0
		_rect(mb, fair, Rect2(x0, tee.y - 11.0, x1 - x0, 22.0), 0.04, 0.1)
		_ellipse(mb, fringe, green, 12.0, 12.0, 0.05)
		_ellipse(mb, green_m, green, 9.5, 9.5, 0.06)
		_rect(mb, tee_m, Rect2(tee.x - 4.0, tee.y - 3.5, 8.0, 7.0), 0.06)
		for sgn in [-1.0, 1.0]:
			var bp := Vector2(green.x - dir * 12.0, green.y + sgn * 9.0)
			_ellipse(mb, sand, bp, 5.0, 3.6, 0.07)
		_flag_pos_add(h)
		# tee markers
		for sz in [-2.2, 2.2]:
			Miami._box(mb, Miami._flat(Color("#f2f2ee")), Vector3(tee.x - 0.12, 0.06, tee.y + sz - 0.12), Vector3(tee.x + 0.12, 0.35, tee.y + sz + 0.12), 1.0)
	# the driving range: a wide strip down the middle with distance boards
	_rect(mb, fair, Rect2(GOLF_C.x - 190.0, GOLF_C.y - 18.0, 180.0, 36.0), 0.04, 0.1)
	for dist in [60.0, 100.0, 140.0, 180.0]:
		var bx: float = GOLF_C.x - 8.0 - dist
		Miami._box(mb, Miami._flat(Color("#f2f2ee")), Vector3(bx - 0.1, 0.05, GOLF_C.y - 18.0), Vector3(bx + 0.1, 1.6, GOLF_C.y - 17.7), 1.0)
		Miami._box(mb, Miami._flat(Color("#e0262d")), Vector3(bx - 0.1, 0.05, GOLF_C.y + 17.7), Vector3(bx + 0.1, 1.6, GOLF_C.y + 18.0), 1.0)
		_ellipse(mb, sand, Vector2(bx, GOLF_C.y), 6.0, 6.0, 0.07)
	_solid(c, mb, false)
	for h in holes:
		_flag(c, h.green)
	# the cart path along the road side, and a path to each tee
	var path := Miami._surface_mat("walk", "PavingStones136", 0.5, Color(0.95, 0.92, 0.85), 0.9)
	Miami._slab(c, Rect2(-224.0, 1982.0, 7.0, 190.0), 0.0, 0.1, path, false)
	Miami._slab(c, Rect2(-224.0, 2228.0, 7.0, 190.0), 0.0, 0.1, path, false)
	# the club house
	Miami._building(c, Vector2(-216.0, GOLF_C.y), PI * 0.5, 34.0, 16.0, 2, "lobby", rng, "REDLINE GOLF")
	# trees: a tree line down the middle of each rough, palms and tropical plants, kept off the fairways
	var kinds := ["t", "m", "trop", "t", "banana", "m"]
	var b_lines := [-198.0, -154.0, -110.0, -66.0, -22.0, 22.0, 66.0, 110.0, 154.0, 198.0]
	for bl in b_lines:
		var x := GOLF_C.x - 22.0 - rng.randf() * 8.0
		var k := 0
		while x > GOLF_C.x - GOLF_R:
			var p := Vector2(x, GOLF_C.y + bl + rng.randf_range(-2.5, 2.5))
			var inside := p.distance_to(GOLF_C) < GOLF_R - 6.0
			var on_range := absf(p.y - GOLF_C.y) < 30.0 and p.x < GOLF_C.x - 6.0
			var near_club := p.x > GOLF_C.x - 6.0 and absf(p.y - GOLF_C.y) < 24.0
			var in_pond := false
			for pdx in ponds:
				if (pdx.rect as Rect2).grow(3.0).has_point(p): in_pond = true
			if inside and not on_range and not near_club and not in_pond:
				var kind: String = kinds[k % kinds.size()]
				if kind == "t" or kind == "m":
					Miami._palm(body, p, rng, kind)
				elif kind == "banana":
					Miami._put("banana", Vector3(p.x, 0.0, p.y), rng.randf() * TAU, rng.randf_range(1.0, 1.4))
					CoastProps._box(body, Vector3(0.5, 3.0, 0.5), Vector3(p.x, 1.5, p.y))
				else:
					Miami._put("trop_palm%d" % (1 + rng.randi() % 3), Vector3(p.x, 0.0, p.y), rng.randf() * TAU, rng.randf_range(0.9, 1.3))
					CoastProps._box(body, Vector3(0.5, 4.0, 0.5), Vector3(p.x, 2.0, p.y))
			x -= rng.randf_range(11.0, 16.0)
			k += 1
	var grass := _lawn_mat(c, Color(0.55, 0.85, 0.45))
	for pd in ponds:
		if String(pd.area) == "golf": _pond_build(c, pd, rng, grass)

static func _flag_pos_add(_h: Dictionary) -> void:
	pass

# ------------------------------------------------------------------ canal, bridges, boats

static func _canal(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var seawall := Miami._surface_mat("rim", "PavingStones136", 0.5, Color(0.85, 0.82, 0.75), 0.9)
	var bedm := Miami._flat(Color(0.5, 0.45, 0.34), 0.95)
	var wall_h := 0.45
	var mb := {}
	var wb := {}
	for r in strips:
		var rr: Rect2 = r
		Miami._box(mb, bedm, Vector3(rr.position.x, CANAL_BED - 0.5, rr.position.y), Vector3(rr.end.x, CANAL_BED, rr.end.y), 0.2)
		_rect(wb, Miami._water_mat(false), rr, WATER_Y)
	_solid(c, mb)
	_water_surface(c, wb)
	# seawalls: round the outside of the ring and round the island, from the bed up to just above the grass; the top is paved
	var wm := {}
	for ring in [RING_OUT, RING_IN]:
		var q: Rect2 = ring
		for side in range(4):
			var p0: Vector3
			var p1: Vector3
			match side:
				0: p0 = Vector3(q.position.x - 0.5, CANAL_BED, q.position.y - 0.5); p1 = Vector3(q.end.x + 0.5, wall_h, q.position.y)
				1: p0 = Vector3(q.position.x - 0.5, CANAL_BED, q.end.y); p1 = Vector3(q.end.x + 0.5, wall_h, q.end.y + 0.5)
				2: p0 = Vector3(q.position.x - 0.5, CANAL_BED, q.position.y); p1 = Vector3(q.position.x, wall_h, q.end.y)
				_: p0 = Vector3(q.end.x, CANAL_BED, q.position.y); p1 = Vector3(q.end.x + 0.5, wall_h, q.end.y)
			if side == 3 and ring == RING_OUT:
				# the east quay wall stops either side of the sea channel
				for seg in [[q.position.y, CH_EAST.position.y], [CH_EAST.end.y, q.end.y]]:
					Miami._box(wm, seawall, Vector3(p0.x, CANAL_BED, seg[0]), Vector3(p1.x, wall_h, seg[1]), 0.5, true)
					Miami._cb(c.body, Vector3(p0.x, CANAL_BED, seg[0]), Vector3(p1.x, wall_h, seg[1]))
				continue
			Miami._box(wm, seawall, p0, p1, 0.5, true)
			Miami._cb(c.body, p0, p1)
	_solid(c, wm, false)
	# Footbridges: 0 (west), 2 (north), 3 (south). Footbridge 1 (east) is omitted because the east canal opens directly into the sea channel and is already crossed by the road bridge overhead.
	for k in [0, 2, 3]:
		_footbridge(c, k)
	_channels(c, rng)

## Footbridges over the ring canal: a flat deck over the water (3.3 m clear) with a ramp each side.
static func _footbridge(c: Dictionary, which: int) -> void:
	var wood := Miami._flat(Color("#9a7447"), 0.8)
	var rail := Miami._flat(Color("#f4f1ea"), 0.6)
	# [start, end, direction] along the axis the bridge crosses the canal on: west, east, north, south
	var cx := RING_OUT.position.x + RING_OUT.size.x * 0.5
	var cz := RING_OUT.position.y + RING_OUT.size.y * 0.5
	var start: Vector2
	var dirv: Vector2
	match which:
		0: start = Vector2(RING_OUT.position.x - 20.0, cz); dirv = Vector2(1, 0)
		1: start = Vector2(RING_OUT.end.x + 20.0, cz); dirv = Vector2(-1, 0)
		2: start = Vector2(cx, RING_OUT.position.y - 20.0); dirv = Vector2(0, 1)
		_: start = Vector2(cx, RING_OUT.end.y + 20.0); dirv = Vector2(0, -1)
	var ramp := 16.0
	var span := 20.0 + 6.0
	var total := ramp * 2.0 + span + 2.0 * 0.0
	var yaw := atan2(dirv.x, dirv.y)
	var root := Node3D.new()
	root.position = Vector3(start.x, 0.0, start.y)
	root.rotation.y = yaw
	(c.w as World).static_root.add_child(root)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	root.add_child(sb)
	var rise := 3.3
	var width := 4.0
	# local +z runs along the bridge
	var deck_z0 := ramp + 0.0
	var parts: Array = [[Vector3(width, 0.3, span), Vector3(0.0, rise - 0.15, deck_z0 + span * 0.5), 0.0],
		[Vector3(width, 0.3, sqrt(ramp * ramp + rise * rise)), Vector3(0.0, rise * 0.5 - 0.15, ramp * 0.5), -atan2(rise, ramp)],
		[Vector3(width, 0.3, sqrt(ramp * ramp + rise * rise)), Vector3(0.0, rise * 0.5 - 0.15, ramp + span + ramp * 0.5), atan2(rise, ramp)]]
	for pt in parts:
		var sz: Vector3 = pt[0]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = wood
		mi.position = pt[1]
		mi.rotation.x = float(pt[2])
		root.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position = pt[1]
		cs.rotation.x = float(pt[2])
		sb.add_child(cs)
		for side in [-1.0, 1.0]:
			var rl := MeshInstance3D.new()
			var rb := BoxMesh.new()
			rb.size = Vector3(0.08, 0.9, sz.z)
			rl.mesh = rb
			rl.material_override = rail
			rl.position = pt[1] + Vector3(side * (width * 0.5 - 0.04), 0.5, 0.0).rotated(Vector3.RIGHT, float(pt[2]))
			rl.rotation.x = float(pt[2])
			root.add_child(rl)

static func _boats(c: Dictionary, rng: RandomNumberGenerator) -> void:
	# the ring canal's centre line: clockwise seen from above, boats keep to their right-hand lane and are spread round the loop
	var loop: Array[Vector2] = [Vector2(660.0, 2120.0), Vector2(790.0, 2120.0), Vector2(800.0, 2130.0), Vector2(800.0, 2270.0), Vector2(790.0, 2280.0),
		Vector2(660.0, 2280.0), Vector2(650.0, 2270.0), Vector2(650.0, 2130.0)]
	var specs := [["speedboat", 6.0, 0.0, 0.5, 0.9], ["boat2", 4.5, 0.27, 0.4, 0.75], ["speedboat", 5.0, 0.52, 0.5, 0.9], ["jetski", 7.0, 0.77, 0.1, 1.0]]
	for sp in specs:
		var pr: Dictionary = Miami._props.get(String(sp[0]), {})
		if pr.is_empty(): continue
		var b := Boat.new()
		(c.w as World).static_root.add_child(b)
		b.setup(pr.mesh, loop, float(sp[1]), float(sp[2]), float(sp[3]), 3.2)
		b.scale = Vector3.ONE * float(sp[4])
		boats.append(b)

# ------------------------------------------------------------------ the east park

static func _east(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var walk := Miami._surface_mat("walk", "PavingStones136", 0.5, Color(1.15, 1.1, 1.0), 0.85)
	var hexm := Miami._surface_mat("hex", "PavingStones130", 0.45, Color(1.1, 1.0, 1.0), 0.85)
	# the island plaza
	Miami._slab(c, Rect2(705.0, 2180.0, 40.0, 40.0), 0.0, 0.08, hexm, false)
	for sx in [-1.0, 1.0]:
		Miami._put("gazebo", Vector3(725.0 + sx * 17.0, 0.08, 2200.0), 0.0, 1.8)
		CoastProps._box(body, Vector3(7.0, 3.5, 7.0), Vector3(725.0 + sx * 17.0, 1.75, 2200.0))
	for k in range(4):
		var a := PI * 0.25 + k * PI * 0.5
		Miami._put("flowerbed", Vector3(725.0 + cos(a) * 11.0, 0.0, 2200.0 + sin(a) * 11.0), rng.randf() * TAU, 1.0)
	for k in range(6):
		var bp := Vector2(725.0 + cos(k * TAU / 6.0) * 7.0, 2200.0 + sin(k * TAU / 6.0) * 7.0)
		Miami._put("bench", Vector3(bp.x, 0.08, bp.y), atan2(-cos(k * TAU / 6.0), -sin(k * TAU / 6.0)) + PI * 0.5, 1.0)
	# palms, tropical plants and bushes on the island
	for k in range(26):
		var p := Vector2(rng.randf_range(668.0, 782.0), rng.randf_range(2138.0, 2262.0))
		if Rect2(700.0, 2176.0, 50.0, 48.0).has_point(p) or Rect2(700.0, 2143.0, 50.0, 40.0).has_point(p): continue
		match k % 4:
			0: Miami._palm(body, p, rng, "t")
			1: Miami._palm(body, p, rng, "m")
			2:
				Miami._put("trop_palm%d" % (1 + rng.randi() % 3), Vector3(p.x, 0.0, p.y), rng.randf() * TAU, rng.randf_range(0.9, 1.3))
				CoastProps._box(body, Vector3(0.5, 4.0, 0.5), Vector3(p.x, 2.0, p.y))
			3: Miami._put("bush", Vector3(p.x, 0.0, p.y), rng.randf() * TAU, rng.randf_range(1.0, 1.6))
	# the football pitch on the north lawn, with palms and benches along its sides
	Miami._put("soccer", Vector3(700.0, 0.0, 2035.0), 0.0, 1.0)
	CoastProps._box(body, Vector3(39.0, 0.15, 48.0), Vector3(700.0, 0.075, 2035.0))
	for k in range(10):
		var sx := 666.0 if k % 2 == 0 else 736.0
		Miami._palm(body, Vector2(sx, 2000.0 + k * 11.0), rng, "t" if k % 3 else "m")
	# gazebos by the lake and the lake's park paths and benches
	Miami._put("gazebo", Vector3(660.0, 0.0, 2345.0), 0.4, 1.8)
	CoastProps._box(body, Vector3(7.0, 3.5, 7.0), Vector3(660.0, 1.75, 2345.0))
	Miami._put("gazebo", Vector3(745.0, 0.0, 2395.0), 2.7, 1.8)
	CoastProps._box(body, Vector3(7.0, 3.5, 7.0), Vector3(745.0, 1.75, 2395.0))
	for k in range(7):
		var bp2 := Vector2(700.0 + cos(k * 0.9 + 0.4) * 52.0, 2368.0 + sin(k * 0.9 + 0.4) * 32.0)
		Miami._put("bench", Vector3(bp2.x, 0.0, bp2.y), atan2(bp2.x - 700.0, bp2.y - 2368.0), 1.0)
	# promenade paths: along the flat side, from the west bridge to the pitch and to the lake
	Miami._slab(c, Rect2(612.0, 2185.0, 28.0, 30.0), 0.0, 0.1, walk, false)
	Miami._slab(c, Rect2(612.0, 1985.0, 6.0, 400.0), 0.0, 0.1, walk, false)
	Miami._slab(c, Rect2(660.0, 2212.0, 130.0, 0.0), 0.0, 0.0, walk, false)
	var grass := _lawn_mat(c, Color(0.65, 0.95, 0.5))
	for pd in ponds:
		if String(pd.area) == "east": _pond_build(c, pd, rng, grass)
	_canal(c, rng)
	_boats(c, rng)

# ------------------------------------------------------------------ the beach fair

static func _fair(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var w: World = c.w
	var body: StaticBody3D = c.body
	var deck_top := CityBuild.BASE_H
	var planks := Miami._stripes(Color("#8a6a45"), Color("#765a39"))
	var mb := {}
	Miami._box(mb, planks, Vector3(FAIR.position.x, deck_top - 1.6, FAIR.position.y), Vector3(FAIR.end.x, deck_top, FAIR.end.y), 0.5)
	Miami._cb(body, Vector3(FAIR.position.x, deck_top - 1.6, FAIR.position.y), Vector3(FAIR.end.x, deck_top, FAIR.end.y))
	_solid(c, mb, false)
	var c2 := {"w": w, "body": body}
	for it in [["hotdog", "new_york_hot_dog_cart", 1.0], ["icecream_c", "ice_cream_cart", 0.0085], ["mexice", "mexican_ice_cream_cart", 0.5],
			["kiosk", "simple_90s_kiosk", 0.9], ["lemon", "updated_lemonade_stand", 1.4], ["bench_f", "park_bench", 0.0135],
			["bumper", "lunapark_-_bumper_cars", 1.0], ["balloons", "air_balloons", 1.2]]:
		CityBuild._spec(it[0], PZ + String(it[1]) + ".glb", float(it[2]))
	var cx := FAIR.position.x + FAIR.size.x * 0.5
	# the giant wheel: its disc stands in the north-south plane (the model's own orientation), so it fits the narrow deck
	CityBuild._ferris_wheel(c2, Vector2(cx, 2165.0), 1.55, deck_top)
	CityBuild._pirate_ship(c2, Vector2(cx, 2235.0))
	CityBuild._put(c2, "bumper", Vector2(cx, 2275.0), PI * 0.5, true, true)
	var stalls := [["hotdog", Vector2(FAIR.end.x - 7.0, 2110.0)], ["icecream_c", Vector2(FAIR.end.x - 7.0, 2125.0)], ["lemon", Vector2(FAIR.end.x - 7.0, 2195.0)],
		["mexice", Vector2(FAIR.end.x - 7.0, 2210.0)], ["kiosk", Vector2(FAIR.end.x - 7.0, 2300.0)]]
	for st in stalls:
		CityBuild._put(c2, st[0], st[1], -PI * 0.5, true, true)
	for bp in [Vector2(cx + 18.0, 2120.0), Vector2(cx + 18.0, 2190.0), Vector2(cx + 18.0, 2250.0)]:
		CityBuild._put(c2, "balloons", bp, 0.0, false, true)
	for k in range(6):
		CityBuild._put(c2, "bench_f", Vector2(FAIR.position.x + 6.0, 2105.0 + k * 40.0), PI * 0.5, true, true)
	# stadium floodlights at the corners, and a neon gate
	for cn in [Vector2(FAIR.position.x + 5.0, 2098.0), Vector2(FAIR.end.x - 5.0, 2098.0), Vector2(FAIR.position.x + 5.0, 2302.0), Vector2(FAIR.end.x - 5.0, 2302.0)]:
		CityBuild.floodlight(w, body, deck_top, cn, Vector2(cx, 2200.0), 2.0)
	var gate := Node3D.new()
	gate.position = Vector3(FAIR.end.x + 0.5, deck_top, 2200.0)
	gate.rotation.y = PI * 0.5
	w.static_root.add_child(gate)
	Miami._neon_label(gate, "OCEAN FAIR", Vector3(0.0, 7.0, 0.0), Color("#ff4fa3"), 0.03, "monoton")
	Miami._neon_label(gate, "OCEAN FAIR", Vector3(0.0, 7.0, -0.1), Color("#ff4fa3"), 0.03, "monoton", PI)
	var pole_m := Miami._flat(Color("#2b2f36"), 0.5, 0.6)
	var gm := {}
	for sx in [-9.0, 9.0]:
		Miami._box(gm, pole_m, Vector3(sx - 0.3, 0.0, -0.3), Vector3(sx + 0.3, 8.0, 0.3), 1.0)
	Miami._box(gm, pole_m, Vector3(-9.3, 8.0, -0.3), Vector3(9.3, 8.5, 0.3), 1.0)
	var gmi := MeshInstance3D.new()
	gmi.mesh = Miami._finish(gm)
	gate.add_child(gmi)
	for sx in [-9.0, 9.0]:
		CoastProps._box(body, Vector3(0.6, 8.0, 0.6), Vector3(FAIR.end.x + 0.5, deck_top + 4.0, 2200.0 + sx))
	# a proper fence all round the fair (chain link on dark posts), one 16 m entrance on the boulevard side where the neon gate stands
	fence_root = w.static_root
	var fa := FAIR.position + Vector2(0.8, 0.8)
	var fb := FAIR.end - Vector2(0.8, 0.8)
	var gate_z0 := 2200.0 - 8.0
	var gate_z1 := 2200.0 + 8.0
	_fence_line(Vector2(fa.x, fa.y), Vector2(fb.x, fa.y), Rect2(), deck_top)
	_fence_line(Vector2(fa.x, fb.y), Vector2(fb.x, fb.y), Rect2(), deck_top)
	_fence_line(Vector2(fa.x, fa.y), Vector2(fa.x, fb.y), Rect2(), deck_top)
	_fence_line(Vector2(fb.x, fa.y), Vector2(fb.x, gate_z0), Rect2(), deck_top)
	_fence_line(Vector2(fb.x, gate_z1), Vector2(fb.x, fb.y), Rect2(), deck_top)
	# lifeguard towers on the sand either side of the fair
	for lz in [2060.0, 2340.0]:
		Miami._put("tower", Vector3(FAIR.position.x - 8.0, 0.0, lz), PI * 0.5, 1.0)
		CoastProps._box(body, Vector3(3.0, 4.0, 3.0), Vector3(FAIR.position.x - 8.0, 2.0, lz))

static func build(c: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	boats.clear()
	_golf(c, rng)
	_block_waters(c, rng)
	_golf_fence(c, rng)
	_sports(c, rng)
	_east(c, rng)
	_fair(c, rng)
	print("miami parks: %d ponds, %d canal strips, %d boats" % [ponds.size(), strips.size(), boats.size()])


# ------------------------------------------------------------------ the sea channels, marina, bridge, lighthouse

static func _put_len(key: String, pos: Vector3, yaw: float, length: float) -> void:
	var pr: Dictionary = Miami._props.get(key, {})
	if pr.is_empty(): return
	var sz: Vector3 = pr.size
	Miami._put(key, pos, yaw, length / maxf(maxf(sz.x, sz.z), 0.01))

## A channel from the island out to the open sea. Its bed slopes up to follow the real seabed, so it ends in the sea itself with no
## step; quay walls follow the bed along both banks. along_x: the channel runs along x (east), otherwise along z (north).
static func _channel(c: Dictionary, r: Rect2, along_x: bool) -> void:
	var seawall := Miami._surface_mat("rim", "PavingStones136", 0.5, Color(0.85, 0.82, 0.75), 0.9)
	var bedm := Miami._flat(Color(0.62, 0.56, 0.42), 0.95)
	var mb := {}
	var wm := {}
	var wb := {}
	var step := 5.0
	var p0: float = r.position.x if along_x else r.position.y
	var p1: float = r.end.x if along_x else r.end.y
	var lc: float = (r.position.y + r.end.y) * 0.5 if along_x else (r.position.x + r.end.x) * 0.5
	var hw: float = (r.size.y if along_x else r.size.x) * 0.5
	var sea_end_first := not along_x                        # the north channel's sea end is its low-z end
	var n := int(ceil((p1 - p0) / step))
	var ys := PackedFloat32Array()
	for k in range(n + 2):
		var p := p0 + k * step
		var pos := Vector2(p, lc) if along_x else Vector2(lc, p)
		var d := Coast.inland(pos.x, pos.y)
		var prof := Coast.profile(d, pos.x, pos.y)
		# Deep navigable canal bed (CANAL_BED = -3.2 m) through the island and smoothly deepens into the seabed at sea
		ys.append(minf(CANAL_BED, prof) if d < -30.0 else CANAL_BED)
	var wl := WATER_Y
	for k in range(n + 1):
		var a := p0 + k * step
		var b := a + step
		var ya := ys[k]
		var yb := ys[k + 1]
		var v := func(pp: float, lat: float, y: float) -> Vector3: return Vector3(pp, y, lat) if along_x else Vector3(lat, y, pp)
		# bed (faces up)
		var q00: Vector3 = v.call(a, lc - hw, ya)
		var q01: Vector3 = v.call(a, lc + hw, ya)
		var q10: Vector3 = v.call(b, lc - hw, yb)
		var q11: Vector3 = v.call(b, lc + hw, yb)
		if along_x:
			_tri(mb, bedm, q00, q10, q11)
			_tri(mb, bedm, q00, q11, q01)
		else:
			_tri(mb, bedm, q00, q11, q10)
			_tri(mb, bedm, q00, q01, q11)
		# banks: stone quay boxes from below the bed up to above water, extending as breakwater jetties into the sea
		if p1 - a > 0.0 and b <= p1 + 0.01:
			for side in [-1.0, 1.0]:
				var lat0: float = lc + side * hw
				var lo := minf(ya, yb) - 0.3
				var is_sea_tip := (along_x and b > p1 - 25.0) or ((not along_x) and a < p0 + 25.0)
				var wall_top := 0.28 if is_sea_tip else 0.45
				var bmin: Vector3 = v.call(a, lat0 - (0.6 if side < 0.0 else 0.0), lo)
				var bmax: Vector3 = v.call(b, lat0 + (0.6 if side > 0.0 else 0.0), wall_top)
				Miami._box(wm, seawall, bmin, bmax, 0.5, true)
				Miami._cb(c.body, bmin, bmax)

	# Marine navigation beacon posts at the outer ocean tip of the jetties
	var tip_p := p1 if along_x else p0
	var tip_v := func(pp: float, lat: float, y: float) -> Vector3: return Vector3(pp, y, lat) if along_x else Vector3(lat, y, pp)
	for s_idx in range(2):
		var side: float = [-1.0, 1.0][s_idx]
		var col: Color = Color(1.0, 0.15, 0.15) if s_idx == 0 else Color(0.15, 1.0, 0.3)
		var b_pos: Vector3 = tip_v.call(tip_p, lc + side * (hw + 0.3), 0.28)
		# Stone beacon base pedestal
		Miami._box(wm, seawall, b_pos - Vector3(0.6, 0.6, 0.6), b_pos + Vector3(0.6, 0.4, 0.6), 0.5, true)
		Miami._cb(c.body, b_pos - Vector3(0.6, 0.6, 0.6), b_pos + Vector3(0.6, 0.4, 0.6))
		# Illuminated navigation lantern
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = col
		b_mat.emission_enabled = true
		b_mat.emission = col
		b_mat.emission_energy_multiplier = 3.0
		CityLights.register_material(b_mat, col, 3.0)
		Miami._box(wm, b_mat, b_pos + Vector3(-0.25, 0.4, -0.25), b_pos + Vector3(0.25, 1.4, 0.25), 0.5, false)
		var bl := OmniLight3D.new()
		bl.position = b_pos + Vector3(0, 1.2, 0)
		bl.omni_range = 14.0
		bl.light_energy = 1.8
		bl.light_color = col
		bl.shadow_enabled = false
		CityLights.register_light(bl, 1.8)
		(c.w as World).add_child(bl)

	# water over the carved part (seamlessly joining the open sea)
	_rect(wb, Miami._water_mat(false), r, wl)
	_solid(c, mb)
	_water_surface(c, wb)
	_solid(c, wm, false)

static func _channels(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var seawall := Miami._surface_mat("rim", "PavingStones136", 0.5, Color(0.85, 0.82, 0.75), 0.9)
	var bedm := Miami._flat(Color(0.5, 0.45, 0.34), 0.95)
	var body: StaticBody3D = c.body
	_channel(c, CH_EAST, true)
	_channel(c, CH_NORTH, false)
	# the marina basin: flat bed, quay walls on three sides (the channel mouth is left open on the sea side)
	var mb := {}
	var wb := {}
	var wm := {}
	Miami._box(mb, bedm, Vector3(BASIN.position.x, CANAL_BED - 0.5, BASIN.position.y), Vector3(BASIN.end.x, CANAL_BED, BASIN.end.y), 0.2)
	_rect(wb, Miami._water_mat(false), BASIN, WATER_Y)
	_solid(c, mb)
	_water_surface(c, wb)
	var wh := 0.45
	var walls: Array = [
		[BASIN.position.x - 0.5, BASIN.position.y, BASIN.position.x, BASIN.end.y], [BASIN.end.x, BASIN.position.y, BASIN.end.x + 0.5, BASIN.end.y],
		[BASIN.position.x, BASIN.end.y, BASIN.end.x, BASIN.end.y + 0.5],
		[BASIN.position.x, BASIN.position.y - 0.5, CH_NORTH.position.x, BASIN.position.y], [CH_NORTH.end.x, BASIN.position.y - 0.5, BASIN.end.x, BASIN.position.y]]
	for wl in walls:
		var a := Vector3(wl[0], CANAL_BED, wl[1])
		var b := Vector3(wl[2], wh, wl[3])
		Miami._box(wm, seawall, a, b, 0.5, true)
		Miami._cb(body, a, b)
	_solid(c, wm, false)
	_marina(c, rng)
	_sea_boats(c, rng)
	var lit: Array = [CH_EAST, CH_NORTH]
	for r in strips: lit.append(r)
	CanalLights.build(c.w, lit)

## The marina: piers into the basin with yachts and speedboats alongside, a boardwalk and shops on its south side, the harbour lighthouse.
static func _marina(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var deck_m := Miami._stripes(Color("#8a6a45"), Color("#765a39"))
	# a wide boardwalk round the basin: south side and the two ends
	var mb := {}
	var bw := [Rect2(BASIN.position.x - 6.0, BASIN.end.y, BASIN.size.x + 12.0, 18.0), Rect2(BASIN.position.x - 6.0, BASIN.position.y - 4.0, 6.0, BASIN.size.y + 4.0),
		Rect2(BASIN.end.x, BASIN.position.y - 4.0, 6.0, BASIN.size.y + 4.0)]
	for r in bw:
		var rr: Rect2 = r
		_rect(mb, deck_m, rr, 0.35, 0.5)
		Miami._cb(body, Vector3(rr.position.x, 0.0, rr.position.y), Vector3(rr.end.x, 0.35, rr.end.y))
	_solid(c, mb, false)
	# piers (the wooden pier model, 11.5 x 16.5 m) reaching into the basin from the boardwalk
	var pier_x := [112.0, 150.0, 235.0, 270.0]
	for px in pier_x:
		Miami._put("pier", Vector3(px, 0.3, BASIN.end.y - 1.0), 0.0, 1.0)
		Miami._cb(body, Vector3(px - 5.7, -0.3, BASIN.end.y - 17.0), Vector3(px + 5.7, 0.3, BASIN.end.y))
	# lifebuoys on the quay, lamps and palms along the boardwalk
	for k in range(9):
		var lx := BASIN.position.x + 8.0 + k * 22.0
		Miami._put("lifebuoy", Vector3(lx, 0.35, BASIN.end.y + 1.0), PI, 1.0)
		Miami._palm(body, Vector2(lx + 11.0, BASIN.end.y + 7.0), rng, "t")
		Miami._put("bench", Vector3(lx + 4.0, 0.35, BASIN.end.y + 3.4), PI, 1.0)
	# the boats at their moorings
	var moors := [["yacht", Vector2(130.0, 1872.0), 0.0, 24.0], ["boat1", Vector2(170.0, 1878.0), 0.0, 9.0], ["boat2", Vector2(215.0, 1884.0), 0.0, 9.0],
		["speedboat", Vector2(253.0, 1878.0), 0.0, 9.0], ["yacht", Vector2(290.0, 1868.0), 0.0, 22.0], ["boat3", Vector2(252.0, 1862.0), PI, 8.0], ["jetski", Vector2(116.0, 1890.0), 0.7, 3.0]]
	for m in moors:
		var pr: Dictionary = Miami._props.get(String(m[0]), {})
		if pr.is_empty(): continue
		var sz: Vector3 = pr.size
		var bt := Boat.new()
		(c.w as World).static_root.add_child(bt)
		var pth: Array[Vector2] = [m[1]]
		bt.setup(pr.mesh, pth, 0.0, 0.0, 0.1)
		var k := float(m[3]) / maxf(maxf(sz.x, sz.z), 0.01)
		bt.scale = Vector3.ONE * k
		bt.yaw = float(m[2])
		boats.append(bt)
	# the lighthouse at the mouth of the channel, on the west bank, and a row of shops and cafes facing the boardwalk
	Miami._put("lighthouse", Vector3(168.0, 0.0, 1792.0), 0.0, 1.0)
	CoastProps._box(body, Vector3(7.0, 12.0, 7.0), Vector3(168.0, 6.0, 1792.0))
	var n := Miami._row(c, Vector2(BASIN.position.x - 20.0, BASIN.end.y + 25.0), Vector2(BASIN.end.x + 20.0, BASIN.end.y + 25.0), PI, 16.0, rng, -1.0, 0.3)
	print("miami parks: %d marina shops" % n)

## Boats going out through the east channel (under the lift bridge) and back, and ships cruising well out to sea.
static func _sea_boats(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var xs := CH_EAST.end.x
	# out along the south lane of the channel, a wide turn at sea, back along the north lane, and a U-turn inside the ring canal
	var out_loop: Array[Vector2] = [Vector2(800.0, 2204.0), Vector2(xs + 60.0, 2204.0), Vector2(xs + 160.0, 2260.0), Vector2(xs + 220.0, 2330.0),
		Vector2(xs + 160.0, 2400.0), Vector2(xs + 80.0, 2340.0), Vector2(xs + 60.0, 2196.0), Vector2(800.0, 2196.0)]
	for sp in [["boat3", 0.0, 7.0, 8.0, 0.3], ["speedboat", 0.5, 9.0, 9.0, 0.3]]:
		var pr: Dictionary = Miami._props.get(String(sp[0]), {})
		if pr.is_empty(): continue
		var sz: Vector3 = pr.size
		var bt := Boat.new()
		(c.w as World).static_root.add_child(bt)
		bt.setup(pr.mesh, out_loop, float(sp[3]), float(sp[1]), float(sp[4]), 0.0)
		bt.scale = Vector3.ONE * (float(sp[2]) / maxf(maxf(sz.x, sz.z), 0.01))
		boats.append(bt)
	var sea: Array[Vector2] = [Vector2(xs + 400.0, 1950.0), Vector2(xs + 500.0, 2150.0), Vector2(xs + 450.0, 2400.0), Vector2(xs + 350.0, 2500.0), Vector2(xs + 280.0, 2300.0), Vector2(xs + 300.0, 2100.0)]
	for sp2 in [["ship", 0.0, 34.0, 4.0, 0.5], ["yacht", 0.5, 26.0, 5.0, 0.5], ["fishing", 0.8, 9.0, 4.0, 0.2]]:
		var pr2: Dictionary = Miami._props.get(String(sp2[0]), {})
		if pr2.is_empty(): continue
		var sz2: Vector3 = pr2.size
		var bt2 := Boat.new()
		(c.w as World).static_root.add_child(bt2)
		bt2.setup(pr2.mesh, sea, float(sp2[3]), float(sp2[1]), float(sp2[4]), 5.0)
		bt2.scale = Vector3.ONE * (float(sp2[2]) / maxf(maxf(sz2.x, sz2.z), 0.01))
		boats.append(bt2)

# ------------------------------------------------------------------ golf club fence and entrance, golf carts

## Chain-link fence along a line of points (world x, z), segment by segment, on dark posts with a top rail.
static func _fence_line(a: Vector2, b: Vector2, skip := Rect2(), y0 := 0.0) -> void:
	var pr: Dictionary = Miami._props.get("fence", {})
	if pr.is_empty(): return
	var seg: float = (pr.size as Vector3).z * 0.98
	var d := b - a
	var n := maxi(1, int(round(d.length() / seg)))
	var yaw := atan2(d.x, d.y)
	var fm := {}
	var post := Miami._flat(Color("#23272d"), 0.5, 0.5)
	for k in range(n + 1):
		var m0 := a + d * (float(k) / n)
		Miami._box(fm, post, Vector3(m0.x - 0.07, y0, m0.y - 0.07), Vector3(m0.x + 0.07, y0 + 2.5, m0.y + 0.07), 1.0)
	for k in range(n):
		var m1 := a + d * ((float(k) + 0.5) / n)
		if skip.size != Vector2.ZERO and skip.has_point(m1): continue
		var q0 := a + d * (float(k) / n)
		var q1 := a + d * (float(k + 1) / n)
		var v0 := Vector3(q0.x, y0 + 2.38, q0.y)
		var v1 := Vector3(q1.x, y0 + 2.38, q1.y)
		Miami._quad(fm, post, v0, v1, v1 + Vector3(0, 0.12, 0), v0 + Vector3(0, 0.12, 0), 1.0)
		Miami._quad(fm, post, v1, v0, v0 + Vector3(0, 0.12, 0), v1 + Vector3(0, 0.12, 0), 1.0)
	var fmi := MeshInstance3D.new()
	fmi.mesh = Miami._finish(fm)
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fence_root.add_child(fmi)
	for k in range(n):
		var m := a + d * ((float(k) + 0.5) / n)
		if skip.size != Vector2.ZERO and skip.has_point(m): continue
		Miami._put("fence", Vector3(m.x, y0, m.y), yaw, d.length() / n / (pr.size as Vector3).z)

static func _golf_fence(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	fence_root = (c.w as World).static_root
	var rf := GOLF_R + 10.0
	var gate_ang := PI
	var a_prev := Vector2.ZERO
	var steps := 72
	var ang_gap := 7.0 / rf                      # the gate opening (14 m)
	for k in range(steps + 1):
		var th := PI * 0.5 + PI * float(k) / steps
		var p := GOLF_C + Vector2(cos(th), sin(th)) * rf
		if k > 0 and absf(wrapf(th - gate_ang, -PI, PI)) > ang_gap + PI / steps:
			_fence_line(a_prev, p)
		a_prev = p
	# the straight side along the road, open where the club house stands
	_fence_line(Vector2(-228.0, GOLF_C.y - 240.0), Vector2(-228.0, 2182.0))
	_fence_line(Vector2(-228.0, 2218.0), Vector2(-228.0, GOLF_C.y + 240.0))
	# the entrance: two stone piers, a high neon arch, a paved drive and a car park
	var gate_c := GOLF_C + Vector2(cos(gate_ang), sin(gate_ang)) * rf
	var gate := Node3D.new()
	gate.position = Vector3(gate_c.x, 0.0, gate_c.y)
	gate.rotation.y = PI * 0.5
	(c.w as World).static_root.add_child(gate)
	var stone := Miami._plaster(Color("#f1ece0"))
	var cap := Miami._flat(Color("#2b2f36"), 0.5, 0.5)
	var gm := {}
	for sx in [-8.0, 8.0]:
		Miami._box(gm, stone, Vector3(sx - 0.9, 0.0, -0.9), Vector3(sx + 0.9, 5.2, 0.9), 0.4)
		Miami._box(gm, cap, Vector3(sx - 1.15, 5.2, -1.15), Vector3(sx + 1.15, 5.5, 1.15), 1.0)
		Miami._box(gm, Miami._lamp_mat, Vector3(sx - 0.3, 5.5, -0.3), Vector3(sx + 0.3, 6.1, 0.3), 1.0)
	Miami._box(gm, stone, Vector3(-8.0, 5.2, -0.6), Vector3(8.0, 6.4, 0.6), 0.4)
	var gmi := MeshInstance3D.new()
	gmi.mesh = Miami._finish(gm)
	gate.add_child(gmi)
	Miami._neon_label(gate, "REDLINE GOLF CLUB", Vector3(0.0, 5.8, 0.65), Color("#ffd23f"), 0.02, "monoton")
	Miami._neon_label(gate, "REDLINE GOLF CLUB", Vector3(0.0, 5.8, -0.65), Color("#ffd23f"), 0.02, "monoton", PI)
	var rot := Basis(Vector3.UP, PI * 0.5)
	for sx in [-8.0, 8.0]:
		var off := rot * Vector3(sx, 0.0, 0.0)
		CoastProps._box(body, Vector3(2.3, 6.0, 2.3), Vector3(gate_c.x + off.x, 3.0, gate_c.y + off.z))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 4.5, 2.5)
	lamp.omni_range = 16.0
	lamp.light_color = Color(1.0, 0.85, 0.5)
	gate.add_child(lamp)
	CityLights.register_light(lamp, 2.2)
	var path := Miami._surface_mat("walk", "PavingStones136", 0.5, Color(0.95, 0.92, 0.85), 0.9)
	Miami._slab(c, Rect2(gate_c.x, 2221.0, -216.0 - gate_c.x - 18.0, 8.0), 0.0, 0.1, path, false)
	var asphalt: Material = RoadKit._plain_mat if RoadKit._plain_mat != null else Miami._flat(Color("#3a3d42"), 0.9)
	Miami._slab(c, Rect2(gate_c.x + 6.0, 2268.0, 60.0, 22.0), 0.0, 0.08, asphalt, false)
	var mbk := {}
	for k in range(10):
		Miami._box(mbk, Miami._flat(Color("#f4f4ee"), 0.8), Vector3(gate_c.x + 12.0 + k * 5.2, 0.08, 2269.0), Vector3(gate_c.x + 12.2 + k * 5.2, 0.1, 2277.0), 1.0)
	_solid(c, mbk, false)
	for k in range(6):
		Miami._put("cart", Vector3(-221.0, 0.1, 1992.0 + k * 6.5), PI * 0.5, 1.0)
	for k in range(4):
		Miami._put("cart", Vector3(-221.0, 0.1, 2240.0 + k * 6.5), PI * 0.5, 1.0)

# ------------------------------------------------------------------ the south sports district

static func _line_rect(mb: Dictionary, r: Rect2, y: float, t := 0.12) -> void:
	var white := Miami._flat(Color("#f4f4ee"), 0.8)
	_rect(mb, white, Rect2(r.position.x, r.position.y, r.size.x, t), y)
	_rect(mb, white, Rect2(r.position.x, r.end.y - t, r.size.x, t), y)
	_rect(mb, white, Rect2(r.position.x, r.position.y, t, r.size.y), y)
	_rect(mb, white, Rect2(r.end.x - t, r.position.y, t, r.size.y), y)

static func _sports(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	fence_root = (c.w as World).static_root
	var z0 := 2480.0
	var walk := Miami._surface_mat("walk", "PavingStones136", 0.5, Color(1.15, 1.1, 1.0), 0.85)
	Miami._slab(c, Rect2(-100.0, 2456.0, 600.0, 8.0), 0.0, 0.2, walk, false)
	var mb := {}
	var clay := Miami._flat(Color("#c8573a"), 0.95)
	var blue := Miami._flat(Color("#2f6fb5"), 0.9)
	var green := Miami._flat(Color("#2d8a57"), 0.9)
	var black := Miami._flat(Color("#2b2f36"), 0.6, 0.4)
	var white := Miami._flat(Color("#f4f4ee"), 0.8)
	var bc := Rect2(30.0, z0 + 14.0, 28.0, 15.0)
	_rect(mb, clay, bc, 0.06)
	_line_rect(mb, bc, 0.07)
	_rect(mb, white, Rect2(bc.position.x + bc.size.x * 0.5 - 0.06, bc.position.y, 0.12, bc.size.y), 0.07)
	_ellipse(mb, white, bc.get_center(), 2.0, 2.0, 0.065)
	_ellipse(mb, clay, bc.get_center(), 1.85, 1.85, 0.07)
	for sx in [-1.0, 1.0]:
		var hx: float = bc.get_center().x + sx * (bc.size.x * 0.5 + 0.3)
		Miami._box(mb, black, Vector3(hx - 0.07, 0.0, bc.get_center().y - 0.07), Vector3(hx + 0.07, 3.8, bc.get_center().y + 0.07), 1.0)
		Miami._box(mb, white, Vector3(hx - sx * 0.12 - 0.04, 2.9, bc.get_center().y - 0.9), Vector3(hx - sx * 0.12 + 0.04, 3.9, bc.get_center().y + 0.9), 1.0)
		Miami._box(mb, Miami._flat(Color("#e0262d"), 0.6), Vector3(hx - sx * 0.7 - 0.25, 3.0, bc.get_center().y - 0.25), Vector3(hx - sx * 0.7 + 0.25, 3.06, bc.get_center().y + 0.25), 1.0)
		CoastProps._box(body, Vector3(0.3, 3.8, 0.3), Vector3(hx, 1.9, bc.get_center().y))
	for k in range(2):
		var tc := Rect2(100.0 + k * 42.0, z0 + 10.0, 36.0, 22.0)
		_rect(mb, green, tc, 0.06)
		var pl := Rect2(tc.position.x + 6.0, tc.position.y + 3.0, 24.0, 16.0)
		_rect(mb, blue, pl, 0.07)
		_line_rect(mb, pl, 0.08)
		var cx := pl.get_center().x
		_rect(mb, white, Rect2(cx - 0.06, pl.position.y, 0.12, pl.size.y), 0.08)
		Miami._box(mb, Miami._flat(Color("#e8e8e0"), 0.9), Vector3(cx - 0.03, 0.07, pl.position.y), Vector3(cx + 0.03, 1.0, pl.end.y), 1.0)
		CoastProps._box(body, Vector3(0.1, 1.0, pl.size.y), Vector3(cx, 0.5, pl.get_center().y))
		_fence_line(Vector2(tc.position.x, tc.position.y), Vector2(tc.end.x, tc.position.y))
		_fence_line(Vector2(tc.position.x, tc.end.y), Vector2(tc.end.x - 10.0, tc.end.y))
		_fence_line(Vector2(tc.position.x, tc.position.y), Vector2(tc.position.x, tc.end.y))
		_fence_line(Vector2(tc.end.x, tc.position.y), Vector2(tc.end.x, tc.end.y))
	_solid(c, mb, false)
	var gym := Rect2(240.0, z0 + 8.0, 40.0, 24.0)
	var gm2 := {}
	_rect(gm2, Miami._flat(Color("#9b3b34"), 0.95), gym, 0.06)
	_line_rect(gm2, gym, 0.07, 0.2)
	_solid(c, gm2, false)
	for k in range(5):
		Miami._put("rower", Vector3(gym.position.x + 5.0 + k * 7.0, 0.08, gym.position.y + 6.0), 0.0, 1.0)
		Miami._put("pullup", Vector3(gym.position.x + 5.0 + k * 7.0, 0.08, gym.position.y + 17.0), 0.0, 1.0)
	for k in range(9):
		Miami._put("btable", Vector3(330.0 + (k % 3) * 8.0, 0.2, z0 + 6.0 + (k / 3) * 8.0), rng.randf() * TAU, 1.0)
		CoastProps._box(body, Vector3(1.6, 2.4, 1.6), Vector3(330.0 + (k % 3) * 8.0, 1.2, z0 + 6.0 + (k / 3) * 8.0))
	for k in range(14):
		var px := -80.0 + k * 42.0
		Miami._palm(body, Vector2(px, 2468.0), rng, "t")
		Miami._put("bench", Vector3(px + 12.0, 0.2, 2470.0), PI, 1.0)
	for k in range(30):
		var p := Vector2(rng.randf_range(-90.0, 490.0), rng.randf_range(z0 + 40.0, z0 + 90.0))
		if Coast.inland(p.x, p.y) < 40.0: continue
		match k % 3:
			0: Miami._palm(body, p, rng, "m")
			1: Miami._put("bush", Vector3(p.x, 0.0, p.y), rng.randf() * TAU, rng.randf_range(1.0, 1.6))
			2:
				Miami._put("trop_palm%d" % (1 + rng.randi() % 3), Vector3(p.x, 0.0, p.y), rng.randf() * TAU, rng.randf_range(0.9, 1.3))
				CoastProps._box(body, Vector3(0.5, 4.0, 0.5), Vector3(p.x, 2.0, p.y))
