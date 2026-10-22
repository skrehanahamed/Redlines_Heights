class_name MiamiFill
extends RefCounted
## Fills Redline Island's free spaces: beach rows of loungers, parasols and volleyball, a seaside pier, a north green with a playground,
## picnic area, skate park and jogging loop, a south football stadium and swimming centre, and a seaplane dock beside the marina.
## Everything is solid, and nothing is placed inside a pond, a canal, a keep-out area or on water.

const NORTH_GREEN := Rect2(-185.0, 1795.0, 150.0, 128.0)        # grass between the street grid and the north beach, west of the marina
const NORTH_GREEN_E := Rect2(330.0, 1795.0, 235.0, 128.0)
const STADIUM := Rect2(100.0, 2528.0, 130.0, 72.0)
const POOL_C := Vector2(330.0, 2562.0)
const PIER := Rect2(405.0, 2598.0, 7.0, 150.0)                   # the pier into the sea (south), deck at 1 m
const SEA_DOCK := Rect2(366.0, 1722.0, 7.0, 70.0)                # the seaplane dock (north)

static func plan() -> void:
	MiamiParks.keepout.append(NORTH_GREEN.grow(2.0))
	MiamiParks.keepout.append(NORTH_GREEN_E.grow(2.0))
	MiamiParks.keepout.append(STADIUM.grow(6.0))
	MiamiParks.keepout.append(Rect2(POOL_C - Vector2(30, 22), Vector2(60, 44)))
	MiamiParks.keepout.append(PIER.grow(14.0))
	MiamiParks.keepout.append(SEA_DOCK.grow(14.0))
	MiamiParks._add_pond(POOL_C, 14.0, 7.0, "south", 0.0, "pool")        # the swimming centre's pool

static func _clear(p: Vector2, r := 3.0) -> bool:
	if Coast.inland(p.x, p.y) < 8.0: return false
	if Coast.near_pool(p.x, p.y, r): return false
	return not Miami._overlaps_reserved(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0))

static func _gy(p: Vector2) -> float:
	return maxf(Coast.height_at(p.x, p.y), 0.0)

# ------------------------------------------------------------------ estates: guest house, tennis court or private helipad

static func estate_extras(c: Dictionary, front: Vector2, yaw: float, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var w: World = c.w
	# a guest house beside the main house, with its own door
	var gh: Vector2 = info.guest
	var f := Vector2(sin(yaw), cos(yaw))
	Miami._building(c, gh, yaw, 13.0, 10.0, 1, "living", rng, "", "modern")
	if bool(info.court):
		# a private tennis court: coloured surface, lines, net, chain-link fence all round with a gate gap
		var cc: Vector2 = info.court_c
		var r := Rect2(cc - Vector2(18.0, 12.0), Vector2(36.0, 24.0))
		var mb := {}
		MiamiParks._rect(mb, Miami._flat(Color("#2d8a57"), 0.9), r, Miami.PY + 0.05)
		var pl := Rect2(r.position + Vector2(6.0, 3.5), Vector2(24.0, 17.0))
		MiamiParks._rect(mb, Miami._flat(Color("#2f6fb5"), 0.9), pl, Miami.PY + 0.06)
		MiamiParks._line_rect(mb, pl, Miami.PY + 0.07)
		var mid := pl.get_center().x
		MiamiParks._rect(mb, Miami._flat(Color("#f4f4ee"), 0.8), Rect2(mid - 0.06, pl.position.y, 0.12, pl.size.y), Miami.PY + 0.07)
		Miami._box(mb, Miami._flat(Color("#e8e8e0"), 0.9), Vector3(mid - 0.03, Miami.PY + 0.06, pl.position.y), Vector3(mid + 0.03, Miami.PY + 1.0, pl.end.y), 1.0)
		MiamiParks._solid(c, mb, false)
		CoastProps._box(body, Vector3(0.1, 1.0, pl.size.y), Vector3(mid, Miami.PY + 0.5, pl.get_center().y))
		MiamiParks.fence_root = w.static_root
		var a := r.position - Vector2(1.5, 1.5)
		var b := r.end + Vector2(1.5, 1.5)
		MiamiParks._fence_line(Vector2(a.x, a.y), Vector2(b.x, a.y), Rect2(), Miami.PY)
		MiamiParks._fence_line(Vector2(a.x, b.y), Vector2(b.x - 10.0, b.y), Rect2(), Miami.PY)
		MiamiParks._fence_line(Vector2(a.x, a.y), Vector2(a.x, b.y), Rect2(), Miami.PY)
		MiamiParks._fence_line(Vector2(b.x, a.y), Vector2(b.x, b.y), Rect2(), Miami.PY)
	else:
		# a private helipad: a round pad with the yellow ring and a white H, edge lights that glow at night
		var pc: Vector2 = info.pad_c
		var mb2 := {}
		MiamiParks._ellipse(mb2, Miami._flat(Color("#3a3d42"), 0.9), pc, 9.0, 9.0, Miami.PY + 0.05)
		MiamiParks._ring(mb2, Miami._flat(Color("#f2c230"), 0.8), pc, 7.6, 7.6, 0.45, Miami.PY + 0.07)
		var wh := Miami._flat(Color("#f4f4ee"), 0.8)
		var yh := Miami.PY + 0.08
		MiamiParks._rect(mb2, wh, Rect2(pc.x - 2.2, pc.y - 2.6, 0.7, 5.2), yh)
		MiamiParks._rect(mb2, wh, Rect2(pc.x + 1.5, pc.y - 2.6, 0.7, 5.2), yh)
		MiamiParks._rect(mb2, wh, Rect2(pc.x - 1.5, pc.y - 0.35, 3.0, 0.7), yh)
		for k in range(12):
			var an := TAU * k / 12.0
			var lp := pc + Vector2(cos(an), sin(an)) * 8.4
			Miami._box(mb2, Miami._lamp_mat, Vector3(lp.x - 0.2, Miami.PY + 0.05, lp.y - 0.2), Vector3(lp.x + 0.2, Miami.PY + 0.2, lp.y + 0.2), 1.0)
		MiamiParks._solid(c, mb2, false)
	if false: print(front, f)

# ------------------------------------------------------------------ beach rows

## Loungers in pairs, parasols and surfboards on the sand, set out along the two beach arcs and the north and south beaches.
static func _beach_rows(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var lines: Array = []
	# west and east arcs: same circle as the boulevards, further out on the sand
	for side in [-1.0, 1.0]:
		var ctr := Vector2(0.0, 2200.0)
		var a: Vector2 = Vector2(Miami.XS[0] - CityData.ARC_STUB, Miami.ZS[0]) if side < 0.0 else Vector2(Miami.XS[4] + CityData.ARC_STUB, Miami.ZS[0])
		var b: Vector2 = Vector2(a.x, Miami.ZS[2])
		var chord := a.distance_to(b)
		var sag := 250.0
		var R := (chord * chord * 0.25 + sag * sag) / (2.0 * sag)
		var mid := (a + b) * 0.5
		var cc := mid - Vector2(side, 0.0) * (sag - R)
		lines.append({"ctr": cc, "R": R + 5.9 + 6.0 + 4.0 + 16.0 + 18.0, "a0": (a - cc).angle(), "a1": (b - cc).angle(), "bulge": side})
	var k := 0
	for ln in lines:
		var cc: Vector2 = ln.ctr
		var R: float = ln.R
		var bulge: float = ln.bulge
		var t0 := -asin(110.0 / R)
		var t1 := asin(110.0 / R)
		# the arc runs through the bulge: angle 0 for the east arc, PI for the west arc
		var base := 0.0 if bulge > 0.0 else PI
		var n := int((t1 - t0) * R / 10.0)
		for i in range(n):
			var t := base + (t0 + (t1 - t0) * (i + 0.5) / n) * (1.0 if bulge > 0.0 else -1.0)
			var dir := Vector2(cos(t), sin(t))
			var p := cc + dir * R
			var face := atan2(-dir.x, -dir.y)
			if not _clear(p, 4.0): continue
			if p.distance_to(Vector2(-543.0, 2200.0)) < 70.0: continue        # the fair has its own beach
			var gy := _gy(p)
			match k % 4:
				0, 1:
					Miami._put("lounger", Vector3(p.x, gy, p.y), face + PI * 0.5, 1.0)
					var q := p + Vector2(-dir.y, dir.x) * 1.6
					Miami._put("lounger", Vector3(q.x, gy, q.y), face + PI * 0.5, 1.0)
				2:
					Miami._put("umbrella", Vector3(p.x, gy, p.y), rng.randf() * TAU, 1.0)
					CoastProps._box(body, Vector3(0.4, 2.2, 0.4), Vector3(p.x, gy + 1.1, p.y))
				3:
					Miami._put("sunchair", Vector3(p.x, gy, p.y), face, 1.0)
					Miami._put("surfboard", Vector3(p.x + 1.4, gy, p.y), rng.randf() * TAU, 1.0)
			k += 1
	# the long beaches north and south
	for row in [[1763.0, -170.0, 60.0], [1763.0, 320.0, 560.0], [2618.0, -90.0, 360.0], [2618.0, 440.0, 520.0]]:
		var z: float = row[0]
		var x := float(row[1])
		while x < float(row[2]):
			var p := Vector2(x, z)
			if _clear(p, 4.0) and Coast.inland(p.x, p.y) < 70.0:
				var gy := _gy(p)
				var face := 0.0 if z > 2200.0 else PI
				if int(x / 12.0) % 3 == 0:
					Miami._put("umbrella", Vector3(p.x, gy, p.y), rng.randf() * TAU, 1.0)
					CoastProps._box(body, Vector3(0.4, 2.2, 0.4), Vector3(p.x, gy + 1.1, p.y))
				else:
					Miami._put("lounger", Vector3(p.x, gy, p.y), face + PI * 0.5, 1.0)
					Miami._put("lounger", Vector3(p.x + 1.6, gy, p.y), face + PI * 0.5, 1.0)
			x += 12.0

# ------------------------------------------------------------------ the pier

static func _pier(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var w: World = c.w
	var wood := Miami._stripes(Color("#8a6a45"), Color("#765a39"))
	var rail := Miami._flat(Color("#f2efe6"), 0.6)
	var post := Miami._flat(Color("#4a3a2a"), 0.9)
	var mb := {}
	var deck := 1.0
	# the pier starts on the sand and runs into the sea; a ramp-like start, 1 m deck
	var z_end := PIER.end.y
	var x0 := PIER.position.x
	var x1 := PIER.end.x
	Miami._box(mb, wood, Vector3(x0, deck - 0.25, PIER.position.y), Vector3(x1, deck, z_end), 0.4)
	Miami._cb(body, Vector3(x0, deck - 0.6, PIER.position.y), Vector3(x1, deck, z_end))
	var head := Rect2(x0 - 12.0, z_end - 28.0, 31.0, 28.0)             # a wider platform at the end
	Miami._box(mb, wood, Vector3(head.position.x, deck - 0.25, head.position.y), Vector3(head.end.x, deck, head.end.y), 0.4)
	Miami._cb(body, Vector3(head.position.x, deck - 0.6, head.position.y), Vector3(head.end.x, deck, head.end.y))
	# the beach end: a gentle step up
	Miami._box(mb, wood, Vector3(x0, 0.0, PIER.position.y - 3.0), Vector3(x1, deck - 0.25, PIER.position.y), 0.4)
	Miami._cb(body, Vector3(x0, -1.0, PIER.position.y - 3.0), Vector3(x1, 0.5, PIER.position.y))
	# rails along both sides and round the head, with a gap at the beach end
	for sx in [x0, x1 - 0.12]:
		Miami._box(mb, rail, Vector3(sx, deck, PIER.position.y), Vector3(sx + 0.12, deck + 1.0, z_end - 28.0), 0.5)
		Miami._cb(body, Vector3(sx, deck, PIER.position.y), Vector3(sx + 0.12, deck + 1.0, z_end - 28.0))
	for rr in [[Vector3(head.position.x, deck, head.end.y - 0.12), Vector3(head.end.x, deck + 1.0, head.end.y)], [Vector3(head.position.x, deck, head.position.y), Vector3(head.position.x + 0.12, deck + 1.0, head.end.y)],
			[Vector3(head.end.x - 0.12, deck, head.position.y), Vector3(head.end.x, deck + 1.0, head.end.y)], [Vector3(head.position.x, deck, head.position.y), Vector3(x0, deck + 1.0, head.position.y + 0.12)],
			[Vector3(x1, deck, head.position.y), Vector3(head.end.x, deck + 1.0, head.position.y + 0.12)]]:
		Miami._box(mb, rail, rr[0], rr[1], 0.5)
		Miami._cb(body, rr[0], rr[1])
	# piles every 6 m under the deck
	var pz := PIER.position.y + 4.0
	while pz < z_end:
		for sx in [x0 + 0.4, x1 - 0.4]:
			Miami._box(mb, post, Vector3(sx - 0.18, -3.0, pz - 0.18), Vector3(sx + 0.18, deck - 0.25, pz + 0.18), 1.0)
		pz += 6.0
	var mi := MeshInstance3D.new()
	mi.mesh = Miami._finish(mb)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)
	var cx := x0 + (x1 - x0) * 0.5
	# lamps with a warm glow, benches, a gazebo at the end, and string lights over the head
	var zz := PIER.position.y + 8.0
	var k := 0
	while zz < z_end - 30.0:
		var lm := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.14, 3.2, 0.14)
		lm.mesh = lb
		lm.material_override = Miami._flat(Color("#2b2f36"), 0.5, 0.5)
		lm.position = Vector3(x0 + 0.3 if k % 2 == 0 else x1 - 0.3, deck + 1.6, zz)
		w.static_root.add_child(lm)
		var hd := MeshInstance3D.new()
		var hb := SphereMesh.new()
		hb.radius = 0.25
		hb.height = 0.5
		hd.mesh = hb
		hd.material_override = Miami._lamp_mat
		hd.position = lm.position + Vector3(0, 1.7, 0)
		hd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(hd)
		Miami._put("bench", Vector3(cx, deck, zz + 4.0), PI * 0.5 if k % 2 == 0 else -PI * 0.5, 1.0)
		k += 1
		zz += 14.0
	Miami._put("gazebo", Vector3(cx, deck, z_end - 14.0), 0.0, 2.0)
	CoastProps._box(body, Vector3(8.0, 3.8, 8.0), Vector3(cx, deck + 1.9, z_end - 14.0))
	for sx in [-1.0, 1.0]:
		Miami._put("stringlights", Vector3(cx + sx * 6.0, deck + 2.6, z_end - 9.0), PI * 0.5, 1.4)
		Miami._put("picnic", Vector3(cx + sx * 9.5, deck, z_end - 20.0), 0.0, 1.0)
		CoastProps._box(body, Vector3(2.4, 0.9, 1.6), Vector3(cx + sx * 9.5, deck + 0.45, z_end - 20.0))
	for fx in [-1.0, 1.0]:
		Miami._put("lifebuoy", Vector3(cx + fx * 13.0, deck + 0.4, z_end - 1.0), 0.0, 1.0)
	var lt := OmniLight3D.new()
	lt.position = Vector3(cx, deck + 4.5, z_end - 14.0)
	lt.omni_range = 26.0
	lt.light_color = Color(1.0, 0.85, 0.55)
	w.static_root.add_child(lt)
	CityLights.register_light(lt, 2.2)

# ------------------------------------------------------------------ north greens: playground, picnic, skate park, jogging loop

static func _green(c: Dictionary, g: Rect2, east: bool, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var w: World = c.w
	var cx := g.get_center().x
	var gz0 := g.position.y
	var gz1 := g.end.y
	var lawn := (w as World)._mat("res://assets/textures/y2k_grass.png", 0.2, Color(0.7, 1.0, 0.55))
	var rub := Miami._flat(Color("#b4543d"), 0.95)
	var mb := {}
	# the jogging loop: a rounded track, 3 m wide
	var tc := Vector2(cx, (gz0 + gz1) * 0.5)
	var trx := g.size.x * 0.5 - 14.0
	var trz := g.size.y * 0.5 - 12.0
	MiamiParks._ring(mb, rub, tc, trx, trz, 3.0, 0.07, 56)
	MiamiParks._solid(c, mb, false)
	# palms and benches round the track
	for i in range(28):
		var a := TAU * i / 28.0
		var o := tc + Vector2(cos(a) * (trx + 6.0), sin(a) * (trz + 6.0))
		if _clear(o, 2.0):
			if i % 2 == 0: Miami._palm(body, o, rng, "t")
			else: Miami._put("bush", Vector3(o.x, 0.0, o.y), rng.randf() * TAU, rng.randf_range(1.0, 1.5))
	for i in range(8):
		var a2 := TAU * (i + 0.5) / 8.0
		var o2 := tc + Vector2(cos(a2) * (trx - 3.0), sin(a2) * (trz - 3.0))
		Miami._put("bench", Vector3(o2.x, 0.0, o2.y), atan2(-cos(a2), -sin(a2)) + PI * 0.5, 1.0)
	# inside the loop: playground, picnic area, skate ramps
	if not east:
		Miami._put("playground", Vector3(cx - 22.0, 0.0, tc.y), 0.0, 1.4)
		CoastProps._box(body, Vector3(12.0, 3.0, 14.0), Vector3(cx - 22.0, 1.5, tc.y))
		var pk := Rect2(cx + 4.0, tc.y - 16.0, 30.0, 32.0)
		for r in range(2):
			for q in range(3):
				var px := pk.position.x + 6.0 + q * 9.0
				var pz := pk.position.y + 8.0 + r * 16.0
				Miami._put("picnic", Vector3(px, 0.0, pz), 0.0, 1.0)
				CoastProps._box(body, Vector3(2.4, 0.9, 1.6), Vector3(px, 0.45, pz))
	else:
		# skate park: ramps round a concrete pad
		var pad := Rect2(cx - 22.0, tc.y - 16.0, 44.0, 32.0)
		var sk := {}
		MiamiParks._rect(sk, Miami._flat(Color("#bdb9b0"), 0.9), pad, 0.08)
		MiamiParks._solid(c, sk, false)
		for i in range(5):
			var rp := Vector3(pad.position.x + 8.0 + (i % 3) * 14.0, 0.08, pad.position.y + 8.0 + (i / 3) * 16.0)
			Miami._put("ramp", rp, float(i) * 0.9, 1.0)
			CoastProps._box(body, Vector3(5.0, 1.6, 5.0), rp + Vector3(0, 0.8, 0), float(i) * 0.9)
		for i in range(4):
			Miami._put("rower", Vector3(pad.end.x + 8.0, 0.0, pad.position.y + 4.0 + i * 7.0), PI * 0.5, 1.0)
			Miami._put("pullup", Vector3(pad.position.x - 8.0, 0.0, pad.position.y + 4.0 + i * 7.0), PI * 0.5, 1.0)

# ------------------------------------------------------------------ the south stadium and swimming centre

static func _stadium(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var w: World = c.w
	var cx := STADIUM.get_center().x
	var cz := STADIUM.get_center().y
	# the pitch on a paved apron, long side along x, with a fence and two rows of bleachers
	var apron := Rect2(cx - 62.0, cz - 33.0, 124.0, 66.0)
	var mb := {}
	MiamiParks._rect(mb, Miami._surface_mat("walk", "PavingStones136", 0.5, Color(1.15, 1.1, 1.0), 0.85), apron, 0.09)
	MiamiParks._solid(c, mb, false)
	Miami._put("soccer", Vector3(cx, 0.1, cz), PI * 0.5, 1.0)
	CoastProps._box(body, Vector3(48.0, 0.15, 39.0), Vector3(cx, 0.17, cz))
	MiamiParks.fence_root = w.static_root
	var fa := apron.position + Vector2(2.0, 2.0)
	var fb := apron.end - Vector2(2.0, 2.0)
	MiamiParks._fence_line(Vector2(fa.x, fa.y), Vector2(fb.x, fa.y), Rect2(), 0.09)
	MiamiParks._fence_line(Vector2(fa.x, fb.y), Vector2(fb.x, fb.y), Rect2(), 0.09)
	MiamiParks._fence_line(Vector2(fa.x, fa.y), Vector2(fa.x, fb.y), Rect2(), 0.09)
	MiamiParks._fence_line(Vector2(fb.x, fa.y), Vector2(fb.x, cz - 7.0), Rect2(), 0.09)
	MiamiParks._fence_line(Vector2(fb.x, cz + 7.0), Vector2(fb.x, fb.y), Rect2(), 0.09)
	# bleachers: a long run of the supplied bleacher on each touchline, climbing away from the pitch
	var pr: Dictionary = Miami._props.get("bleacher", {})
	if not pr.is_empty():
		var sz: Vector3 = pr.size
		var run := 6
		for side in [-1.0, 1.0]:
			for k in range(run):
				var bx := cx - 3.0 * (run - 1) * (sz.x if sz.x > 6.0 else 6.0) * 0.5 + k * (sz.x if sz.x > 6.0 else 6.0) * 1.0
				Miami._put("bleacher", Vector3(bx, 0.09, cz + side * 25.0), 0.0 if side > 0.0 else PI, 1.0)
				CoastProps._box(body, Vector3(sz.x, sz.y, sz.z), Vector3(bx, 0.09 + sz.y * 0.5, cz + side * 25.0 + side * sz.z * 0.5))
	# floodlights at the four corners and a neon sign over the entrance
	for cn in [Vector2(apron.position.x + 3.0, apron.position.y + 3.0), Vector2(apron.end.x - 3.0, apron.position.y + 3.0), Vector2(apron.position.x + 3.0, apron.end.y - 3.0), Vector2(apron.end.x - 3.0, apron.end.y - 3.0)]:
		CityBuild.floodlight(w, body, 0.09, cn, Vector2(cx, cz), 2.0)
	var gate := Node3D.new()
	gate.position = Vector3(apron.end.x + 0.5, 0.0, cz)
	gate.rotation.y = PI * 0.5
	w.static_root.add_child(gate)
	Miami._neon_label(gate, "REDLINE STADIUM", Vector3(0.0, 6.5, 0.0), Color("#25e6e0"), 0.022, "monoton")
	Miami._neon_label(gate, "REDLINE STADIUM", Vector3(0.0, 6.5, -0.1), Color("#25e6e0"), 0.022, "monoton", PI)
	var gm := {}
	var pole := Miami._flat(Color("#2b2f36"), 0.5, 0.6)
	for sx in [-8.0, 8.0]:
		Miami._box(gm, pole, Vector3(sx - 0.3, 0.0, -0.3), Vector3(sx + 0.3, 7.5, 0.3), 1.0)
		CoastProps._box(body, Vector3(0.6, 7.5, 0.6), Vector3(apron.end.x + 0.5, 3.75, cz + sx))
	Miami._box(gm, pole, Vector3(-8.3, 7.5, -0.3), Vector3(8.3, 8.0, 0.3), 1.0)
	var gmi := MeshInstance3D.new()
	gmi.mesh = Miami._finish(gm)
	gate.add_child(gmi)
	# the swimming centre: its pool (carved in plan()), loungers and a changing-rooms building
	Miami._building(c, Vector2(POOL_C.x, POOL_C.y + 28.0), PI, 26.0, 10.0, 1, "lobby", rng, "AQUA CENTRE", "modern", 0.1)
	for k in range(4):
		Miami._put("lounger", Vector3(POOL_C.x - 9.0 + k * 6.0, 0.1, POOL_C.y - 16.0), 0.0, 1.0)
		Miami._put("umbrella", Vector3(POOL_C.x - 6.0 + k * 6.0, 0.1, POOL_C.y - 20.0), 0.0, 1.0)

# ------------------------------------------------------------------ the seaplane dock

static func _seaplane_dock(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var w: World = c.w
	var wood := Miami._stripes(Color("#8a6a45"), Color("#765a39"))
	var rail := Miami._flat(Color("#f2efe6"), 0.6)
	var mb := {}
	var x0 := SEA_DOCK.position.x
	var x1 := SEA_DOCK.end.x
	var z0 := SEA_DOCK.position.y
	var z1 := SEA_DOCK.end.y
	var deck := 0.9
	Miami._box(mb, wood, Vector3(x0, deck - 0.25, z0), Vector3(x1, deck, z1 + 3.0), 0.4)
	Miami._cb(body, Vector3(x0, deck - 0.6, z0), Vector3(x1, deck, z1 + 3.0))
	# a landing leg crossing the water to each side: two finger piers
	for side in [-1.0, 1.0]:
		var fx0 := x0 - 12.0 if side < 0.0 else x1
		Miami._box(mb, wood, Vector3(fx0, deck - 0.25, z0 + 6.0), Vector3(fx0 + 12.0, deck, z0 + 9.0), 0.4)
		Miami._cb(body, Vector3(fx0, deck - 0.6, z0 + 6.0), Vector3(fx0 + 12.0, deck, z0 + 9.0))
	for sx in [x0, x1 - 0.12]:
		Miami._box(mb, rail, Vector3(sx, deck, z0), Vector3(sx + 0.12, deck + 1.0, z1 - 2.0), 0.5)
		Miami._cb(body, Vector3(sx, deck, z0), Vector3(sx + 0.12, deck + 1.0, z1 - 2.0))
	var mi := MeshInstance3D.new()
	mi.mesh = Miami._finish(mb)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)
	# two seaplanes moored either side, nose to the sea
	var pr: Dictionary = Miami._props.get("seaplane", {})
	if not pr.is_empty():
		for side in [-1.0, 1.0]:
			var b := Boat.new()
			w.static_root.add_child(b)
			var pth: Array[Vector2] = [Vector2((x0 + x1) * 0.5 + side * 15.0, z0 + 2.0)]
			var sz: Vector3 = pr.size
			b.setup(pr.mesh, pth, 0.0, 0.0, 0.05, 0.0, 0.0 if sz.x >= sz.z else PI * 0.5)
			b.scale = Vector3.ONE * (11.0 / maxf(sz.x, sz.z))
			b.yaw = 0.0
	Miami._put("lifebuoy", Vector3(x0 + 0.5, deck, z1 - 4.0), 0.0, 1.0)
	var cz := z1 - 4.0
	Miami._put("bench", Vector3((x0 + x1) * 0.5, deck, cz), 0.0, 1.0)
	CoastProps._box(body, Vector3(1.8, 0.8, 0.7), Vector3((x0 + x1) * 0.5, deck + 0.4, cz))

static func build(c: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_beach_rows(c, rng)
	_pier(c, rng)
	_green(c, NORTH_GREEN, false, rng)
	_green(c, NORTH_GREEN_E, true, rng)
	_stadium(c, rng)
	_seaplane_dock(c, rng)
	print("miami fill: beach, pier, greens, stadium and seaplane dock built")
