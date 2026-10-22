class_name GolfClub
extends RefCounted
## Redline Golf Club - the whole of block 3 (x 0..200, z 2200..2450, the south row next to the Burj district).
## Downloaded models (assets/golf/, see CREDITS.md): checkpoint gate (guard house + barrier arm), a Mediterranean clubhouse and a scanned
## golf green. Built here: rolling terrain (a real mesh with collision, flat where the drive, parking, roundabout and clubhouse stand,
## with fairways, greens, bunkers and ponds shaped into it and painted by vertex colours - shaders/golf_ground.gdshader), the stone entrance
## with iron gates and a gold script sign, a fountain roundabout, ONE small car park right inside the gate, perimeter wall / fence,
## cypress / palm planting and golf carts.
## Entrance: north side (z 2200 road), x 93..107. The booth sits beside the drive, the barrier arm closes the inbound (west) lane.

const G := "res://assets/golf/"
const X0 := 6.7
const X1 := 193.3
const Z0 := 2206.7
const Z1 := 2443.3
const CX := 100.0
const Y := 0.22                       # base ground level of the block (same as the Burj district)
const GATE_X0 := 93.0
const GATE_X1 := 107.0
const RB := Vector2(100.0, 2268.0)    # roundabout centre
const HOUSE := Vector3(100.0, 0.0, 2334.0)
const LOT := Rect2(106.5, 2216.0, 44.0, 22.0)   # the one car park, next to the drive just inside the gate
const STEP := 1.6
const HOUSE_SCALE := 0.032
const CART_PADS := [Rect2(46.0, 2322.0, 22.0, 9.0), Rect2(134.0, 2322.0, 22.0, 9.0)]   # flat paved pads for the golf carts

static var _noise: FastNoiseLite
static var _holes: Array = []      # {pts: Array[Vector2] tee..green, w: half width}
static var _greens: Array = []     # {c: Vector2, yaw: float}
static var _bunkers: Array = []    # {c, rx, rz, yaw}
static var _ponds: Array = []      # {c, rx, rz, yaw}

# ------------------------------------------------------------------ course layout and terrain functions

static func _plan() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = 4711
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.017
	_noise.fractal_octaves = 3
	_holes = [
		{"pts": [Vector2(20, 2236), Vector2(36, 2312), Vector2(26, 2392)], "w": 6.0},
		{"pts": [Vector2(64, 2434), Vector2(48, 2376), Vector2(62, 2300)], "w": 5.5},
		{"pts": [Vector2(178, 2250), Vector2(168, 2322), Vector2(176, 2396)], "w": 6.0},
		{"pts": [Vector2(138, 2434), Vector2(152, 2384), Vector2(140, 2306)], "w": 5.5},
		{"pts": [Vector2(100, 2366), Vector2(100, 2398), Vector2(100, 2428)], "w": 5.0},
	]
	_greens.clear()
	_bunkers.clear()
	for h in _holes:
		var pts: Array = h.pts
		var g: Vector2 = pts[2]
		var prev: Vector2 = pts[1]
		var yaw := atan2(g.x - prev.x, g.y - prev.y)
		_greens.append({"c": g, "yaw": yaw})
		for sg in [-1.0, 1.0]:
			_bunkers.append({"c": g + Vector2(sg * 11.0, -5.0).rotated(-yaw), "rx": 4.6, "rz": 2.9, "yaw": yaw})
		var m: Vector2 = pts[1]
		_bunkers.append({"c": m + Vector2(-float(h.w) - 2.5, 4.0), "rx": 3.2, "rz": 2.2, "yaw": yaw})
	# ponds: first candidate spots that keep clear of every fairway and green
	_ponds.clear()
	for cand in [Vector2(84, 2412), Vector2(120, 2414), Vector2(112, 2300), Vector2(60, 2330), Vector2(154, 2340)]:
		var ok := true
		if _dist_fairways(cand) < 17.0: ok = false
		if absf(cand.x - CX) < 22.0 and cand.y > 2300.0 and cand.y < 2356.0: ok = false
		if ok and _ponds.size() < 3:
			_ponds.append({"c": cand, "rx": 10.0, "rz": 6.5, "yaw": 0.35})

static func _dist_poly(p: Vector2, pts: Array) -> float:
	var best := 1e9
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := b - a
		var t := clampf((p - a).dot(d) / d.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + d * t))
	return best

static func _dist_fairways(p: Vector2) -> float:
	var best := 1e9
	for h in _holes:
		best = minf(best, _dist_poly(p, h.pts) - float(h.w))
	for g in _greens:
		best = minf(best, p.distance_to(g.c) - 10.0)
	return best

static func _ell(p: Vector2, e: Dictionary) -> float:
	var l: Vector2 = (p - (e.c as Vector2)).rotated(float(e.yaw))
	return sqrt((l.x / float(e.rx)) * (l.x / float(e.rx)) + (l.y / float(e.rz)) * (l.y / float(e.rz)))

## 1 where the ground must stay flat (edges, drive, roundabout, forecourt + clubhouse, car park, gate).
static func _flat_w(p: Vector2) -> float:
	var f := 0.0
	var de := minf(minf(p.x - X0, X1 - p.x), minf(p.y - Z0, Z1 - p.y))
	f = maxf(f, 1.0 - smoothstep(0.0, 7.0, de))
	if p.y < HOUSE.z - 10.0:
		f = maxf(f, 1.0 - smoothstep(9.0, 16.0, absf(p.x - CX)))
	f = maxf(f, 1.0 - smoothstep(16.0, 24.0, p.distance_to(RB)))
	var hr := Rect2(72.0, 2306.0, 56.0, 46.0)
	var q := maxf(maxf(hr.position.x - p.x, p.x - hr.end.x), maxf(hr.position.y - p.y, p.y - hr.end.y))
	f = maxf(f, 1.0 - smoothstep(0.0, 9.0, q))
	for pad in CART_PADS:
		var pq := maxf(maxf(pad.position.x - p.x, p.x - pad.end.x), maxf(pad.position.y - p.y, p.y - pad.end.y))
		f = maxf(f, 1.0 - smoothstep(0.0, 3.5, pq))
	var lq := maxf(maxf(LOT.position.x - 4.0 - p.x, p.x - LOT.end.x - 4.0), maxf(LOT.position.y - 4.0 - p.y, p.y - LOT.end.y - 4.0))
	f = maxf(f, 1.0 - smoothstep(0.0, 6.0, lq))
	if p.y < Z0 + 40.0:
		f = maxf(f, (1.0 - smoothstep(18.0, 30.0, absf(p.x - CX))) * (1.0 - smoothstep(Z0 + 22.0, Z0 + 40.0, p.y)))
	return clampf(f, 0.0, 1.0)

static func ground_h(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var base := (_noise.get_noise_2d(x, z) * 1.9 + _noise.get_noise_2d(x * 2.7 + 90.0, z * 2.7) * 0.45) * 1.7
	var h := base * (1.0 - _flat_w(p))
	for g in _greens:
		var w := 1.0 - smoothstep(10.0, 14.0, p.distance_to(g.c))
		h = lerpf(h, 0.3 + base * 0.12, w)
	for b in _bunkers:
		var e := _ell(p, b)
		h -= 0.62 * (1.0 - smoothstep(0.7, 1.05, e))
	for pd in _ponds:
		var e2 := _ell(p, pd)
		h = lerpf(h, -1.5, 1.0 - smoothstep(0.85, 1.3, e2))
	return h

static func zone_color(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	var fw := 0.0
	var pathw := 0.0
	for h in _holes:
		var d := _dist_poly(p, h.pts)
		fw = maxf(fw, 1.0 - smoothstep(float(h.w), float(h.w) + 2.2, d))
		var tee: Vector2 = (h.pts as Array)[0]
		fw = maxf(fw, 1.0 - smoothstep(3.0, 4.2, maxf(absf(p.x - tee.x), absf(p.y - tee.y))))
		pathw = 0.0
	var gw := 0.0
	for g in _greens:
		gw = maxf(gw, 1.0 - smoothstep(8.3, 9.8, p.distance_to(g.c)))
	var bw := 0.0
	for b in _bunkers:
		bw = maxf(bw, 1.0 - smoothstep(0.78, 0.95, _ell(p, b)))
	for pd in _ponds:
		bw = maxf(bw, (1.0 - smoothstep(1.0, 1.25, _ell(p, pd))) * 0.9)
	var fl := _flat_w(p)
	# near the entrance / clubhouse the ground is lawn (fairway cut), not rough
	if p.y < HOUSE.z + 20.0 and fl > 0.2: fw = maxf(fw, fl * 0.85)
	return Color(fw, gw, bw, pathw * (1.0 - gw))

static func _build_terrain(w: World, body: StaticBody3D) -> void:
	var nx := int((X1 - X0) / STEP)
	var nz := int((Z1 - Z0) / STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(nz + 1):
		for i in range(nx + 1):
			var x := X0 + float(i) * (X1 - X0) / nx
			var z := Z0 + float(j) * (Z1 - Z0) / nz
			var hv := ground_h(x, z)
			var e := 0.8
			var nrm := Vector3(ground_h(x - e, z) - ground_h(x + e, z), 2.0 * e, ground_h(x, z - e) - ground_h(x, z + e)).normalized()
			st.set_color(zone_color(x, z))
			st.set_normal(nrm)
			st.set_uv(Vector2(x * 0.1, z * 0.1))
			st.add_vertex(Vector3(x, Y + hv, z))
	for j in range(nz):
		for i in range(nx):
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + (nx + 1)
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	var mesh := st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/golf_ground.gdshader") as Shader
	var T := "res://assets/golf/tex/"
	for kv in [["fair", "Grass001"], ["rough", "Grass008"], ["sand", "Ground093A"]]:
		sm.set_shader_parameter(kv[0] + "_c", load(T + kv[1] + "_Color.jpg"))
		sm.set_shader_parameter(kv[0] + "_n", load(T + kv[1] + "_NormalGL.jpg"))
		sm.set_shader_parameter(kv[0] + "_r", load(T + kv[1] + "_Roughness.jpg"))
	mesh.surface_set_material(0, sm)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "GolfTerrain"
	w.static_root.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)

# ------------------------------------------------------------------ build

static func build(w: World) -> void:
	print("GolfClub: building block 3...")
	Miami._prep_props()
	if not Miami._props.has("cypress"):
		Miami._props["cypress"] = Miami._bake("res://assets/hills/cypress_tree.glb", "", 9.5)
	_plan()
	var body := StaticBody3D.new()
	body.name = "GolfClubBody"
	body.collision_layer = 1
	w.static_root.add_child(body)
	Miami.solid_body = body
	var mb := {}
	var mb_stone := {}
	var asphalt := IslandSkyscrapers._flat(Color(0.20, 0.21, 0.23), 0.9)
	var white := IslandSkyscrapers._flat(Color(0.93, 0.93, 0.9), 0.8)
	var terrazzo := IslandSkyscrapers._surface_mat("Terrazzo003", 0.4, Color(1.08, 1.04, 0.96), 0.5)

	_build_terrain(w, body)

	# ---- drive and roundabout (all on the flat zone)
	var dy := Y + 0.02
	Miami._box(mb, asphalt, Vector3(GATE_X0, Y, Z0), Vector3(GATE_X1, dy, RB.y - 9.0))
	Miami._box(mb, asphalt, Vector3(GATE_X0, Y, RB.y + 9.0), Vector3(GATE_X1, dy, HOUSE.z - 14.0))
	Miami._box(mb, IslandSkyscrapers._flat(Color(0.95, 0.8, 0.2), 0.8), Vector3(CX - 0.12, dy, Z0), Vector3(CX + 0.12, dy + 0.01, RB.y - 15.5))
	_disc(w, asphalt, RB, 15.0, Y - 0.03)
	_disc(w, terrazzo, RB, 9.5, Y + 0.05)
	_disc(w, IslandSkyscrapers._flat(Color(0.30, 0.58, 0.22), 0.95), RB, 8.2, Y + 0.12)
	Miami._box(mb, terrazzo, Vector3(CX - 26.0, Y, HOUSE.z - 21.0), Vector3(CX + 26.0, Y + 0.03, HOUSE.z - 12.0))

	# ---- fountain on the roundabout: clover-shaped stone fountain with a bowl and water jets
	var fb: Dictionary = Miami._bake(G + "props/fountain_clover.glb", "", 0.0, 2.1)
	if not fb.is_empty():
		var fmi := MeshInstance3D.new()
		fmi.mesh = fb.mesh
		fmi.position = Vector3(RB.x, Y + 0.12, RB.y)
		w.static_root.add_child(fmi)
		CoastProps._box(body, Vector3(fb.size.x * 0.92, fb.size.y * 0.5, fb.size.z * 0.92), Vector3(RB.x, Y + 0.12 + fb.size.y * 0.25, RB.y))
		_fountain_jets(w, Vector3(RB.x, Y + 0.12, RB.y), float(fb.size.y))
	var cs2 := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 9.5
	cyl.height = 0.5
	cs2.shape = cyl
	cs2.position = Vector3(RB.x, Y + 0.25, RB.y)
	body.add_child(cs2)

	# ---- the one car park, right inside the gate
	_parking(w, body, mb, LOT, asphalt, white)

	# ---- clubhouse
	var hb: Dictionary = Miami._bake(G + "clubhouse_mediterranean.glb", "", 0.0, HOUSE_SCALE)
	if not hb.is_empty():
		var hmi := MeshInstance3D.new()
		var src0 := hb.mesh as ArrayMesh
		var vis := ArrayMesh.new()
		var door_mesh := ArrayMesh.new()
		for si0 in range(src0.get_surface_count()):
			var is_door := String(src0.surface_get_material(si0).resource_name) in ["material_3", "material_4"]
			var tgt: ArrayMesh = door_mesh if is_door else vis
			tgt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src0.surface_get_arrays(si0))
			tgt.surface_set_material(tgt.get_surface_count() - 1, src0.surface_get_material(si0))
		hmi.mesh = vis
		hmi.name = "GolfHouse"
		hmi.position = Vector3(HOUSE.x, Y, HOUSE.z)
		hmi.rotation.y = PI
		w.static_root.add_child(hmi)
		# exact collision from the model itself (walls, floors, stairs), without the door leaves so the hall can be entered
		var src := hb.mesh as ArrayMesh
		var cm := ArrayMesh.new()
		for si in range(src.get_surface_count()):
			var mname := String(src.surface_get_material(si).resource_name)
			if mname in ["material_3", "material_4", "material_5"]: continue
			cm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(si))
		var ccs := CollisionShape3D.new()
		var ts := cm.create_trimesh_shape()
		ts.backface_collision = true
		ccs.shape = ts
		ccs.position = hmi.position
		ccs.rotation.y = PI
		body.add_child(ccs)
		GolfInterior.build(w, body, mb, Y)
		_clubhouse_door(w, door_mesh, hmi.position)
		_staff(w)

	_course(w, body, mb)
	_stadium_lights(w, body)
	_entrance(w, body, mb, mb_stone)

	# ---- perimeter: iron fence with gold tips and stone pillars, open between the entrance wings
	IslandSkyscrapers._build_fence(body, mb, mb_stone, Vector2(X0 + 0.6, Z0 + 0.6), Vector2(X1 - 0.6, Z1 - 0.6),
		{"n": [Vector2(GATE_X0 - 16.0, GATE_X1 + 16.0)]}, Y)

	# ---- planting round the entrance, clubhouse and the lot
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for k in range(0, 8):
		var zz: float = Z0 + 16.0 + k * 5.4
		if zz > RB.y - 17.0: break
		Miami._put("cypress", Vector3(GATE_X0 - 2.4, Y, zz), rng.randf() * TAU, rng.randf_range(0.9, 1.15))
		if zz > LOT.end.y + 3.0 or zz < LOT.position.y - 3.0:
			Miami._put("cypress", Vector3(GATE_X1 + 2.4, Y, zz), rng.randf() * TAU, rng.randf_range(0.9, 1.15))
	for k in range(0, 5):
		var zz2: float = RB.y + 17.0 + k * 5.4
		Miami._put("cypress", Vector3(GATE_X0 - 2.4, Y, zz2), rng.randf() * TAU, rng.randf_range(0.9, 1.15))
		Miami._put("cypress", Vector3(GATE_X1 + 2.4, Y, zz2), rng.randf() * TAU, rng.randf_range(0.9, 1.15))
	for fb2 in [Vector2(CX - 15.0, HOUSE.z - 11.0), Vector2(CX + 15.0, HOUSE.z - 11.0), Vector2(CX - 7.0, HOUSE.z - 11.0), Vector2(CX + 7.0, HOUSE.z - 11.0)]:
		Miami._put("flowerbed", Vector3(fb2.x, Y, fb2.y), 0.0, 0.25)
	for bs in [Vector2(CX - 21.0, HOUSE.z - 14.0), Vector2(CX + 21.0, HOUSE.z - 14.0)]:
		Miami._put("bench", Vector3(bs.x, Y, bs.y), PI, 1.5)
	for pp in [Vector2(CX - 26.0, HOUSE.z - 12.0), Vector2(CX + 26.0, HOUSE.z - 12.0), Vector2(CX - 24.0, HOUSE.z + 20.0), Vector2(CX + 24.0, HOUSE.z + 20.0)]:
		_tree(w, body, pp, rng, true)
	_cart_pads(w, body, mb)

	var mi_a := MeshInstance3D.new()
	mi_a.mesh = Miami._finish(mb)
	w.static_root.add_child(mi_a)
	var mi_b := MeshInstance3D.new()
	mi_b.mesh = Miami._finish(mb_stone)
	w.static_root.add_child(mi_b)
	Miami._flush(w)
	w.add_poi("golf", "REDLINE GOLF CLUB", Vector3(CX, Y + 1.0, 2250.0))
	print("GolfClub: done.")

# ------------------------------------------------------------------ helpers

static func _disc(w: World, mat: Material, c: Vector2, r: float, y: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.1
	cm.radial_segments = 48
	cm.rings = 1
	cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = Vector3(c.x, y, c.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

static func _ellipse(w: World, mat: Material, c: Vector2, rx: float, rz: float, y: float, yaw: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.04
	cm.radial_segments = 40
	cm.rings = 1
	cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = Vector3(c.x, y, c.y)
	mi.scale = Vector3(rx, 1.0, rz)
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

## A tree or palm standing on the terrain (solid trunk box).
static func _tree(w: World, body: StaticBody3D, p: Vector2, rng: RandomNumberGenerator, palm: bool) -> void:
	var y := Y + ground_h(p.x, p.y)
	if palm:
		var keys := ["palm_t1", "palm_t2", "palm_t3", "palm_t4", "palm_m6", "palm_m7"]
		Miami._put(keys[rng.randi() % keys.size()], Vector3(p.x, y, p.y), rng.randf() * TAU, rng.randf_range(0.85, 1.1))
		CoastProps._box(body, Vector3(0.8, 6.0, 0.8), Vector3(p.x, y + 3.0, p.y))
	else:
		Miami._put("cypress", Vector3(p.x, y, p.y), rng.randf() * TAU, rng.randf_range(0.85, 1.2))
		CoastProps._box(body, Vector3(0.8, 5.0, 0.8), Vector3(p.x, y + 2.5, p.y))

static func _parking(w: World, body: StaticBody3D, mb: Dictionary, r: Rect2, asphalt: Material, line: Material) -> void:
	var y := Y + 0.02
	Miami._box(mb, asphalt, Vector3(r.position.x, Y, r.position.y), Vector3(r.end.x, y, r.end.y))
	var bay_w := 3.0
	var bay_d := 6.0
	var n := int(r.size.x / bay_w)
	var zr: float = r.position.y + 2.0
	for k in range(n + 1):
		var bx: float = r.position.x + k * bay_w
		Miami._box(mb, line, Vector3(bx - 0.06, y, zr), Vector3(bx + 0.06, y + 0.01, zr + bay_d))
	Miami._box(mb, line, Vector3(r.position.x, y, zr), Vector3(r.end.x, y + 0.01, zr + 0.12))
	for k in range(2):
		var lx: float = r.position.x + 10.0 + k * 22.0
		IslandSkyscrapers._add_parking_floodlight(w, body, Vector2(lx, r.end.y - 4.0), Vector2(lx, r.end.y - 2.0))

## The golf course on the terrain: tee markers, scanned greens with flags, ponds, planted trees.
static func _course(w: World, body: StaticBody3D, mb: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var white := IslandSkyscrapers._flat(Color("#f4f4ee"))
	var red := IslandSkyscrapers._flat(Color("#e0262d"))
	for i in range(_holes.size()):
		var h: Dictionary = _holes[i]
		var tee: Vector2 = (h.pts as Array)[0]
		var th := Y + ground_h(tee.x, tee.y)
		for sz in [-1.6, 1.6]:
			Miami._box(mb, white, Vector3(tee.x + sz - 0.1, th, tee.y - 0.1), Vector3(tee.x + sz + 0.1, th + 0.3, tee.y + 0.1))
		var g: Dictionary = _greens[i]
		var gc: Vector2 = g.c
		var gh := Y + ground_h(gc.x, gc.y)
		_hole_and_flag(w, body, mb, Vector3(gc.x, gh, gc.y), i)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.07, 0.34, 0.46)
	water.metallic = 0.2
	water.roughness = 0.03
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	for pd in _ponds:
		var pc: Vector2 = pd.c
		_ellipse(w, water, pc, float(pd.rx) * 1.02, float(pd.rz) * 1.02, Y - 0.38, -float(pd.yaw))
	var placed := 0
	var tries := 0
	while placed < 85 and tries < 900:
		tries += 1
		var p := Vector2(rng.randf_range(X0 + 6.0, X1 - 6.0), rng.randf_range(Z0 + 30.0, Z1 - 6.0))
		if _flat_w(p) > 0.15: continue
		if _dist_fairways(p) < 6.0: continue
		var in_pond := false
		for pd in _ponds:
			if _ell(p, pd) < 1.5: in_pond = true
		if in_pond: continue
		_tree(w, body, p, rng, rng.randf() < 0.28)
		placed += 1

## Entrance: stone pillars with gold finials and lanterns, plastered wing walls with a gold script name sign, open black iron
## gates with gold spears, a guard booth beside the drive and the barrier arm on the inbound lane.
static func _entrance(w: World, body: StaticBody3D, mb: Dictionary, mb_stone: Dictionary) -> void:
	var stone := IslandSkyscrapers._surface_mat("PavingStones130", 0.5, Color(1.0, 0.96, 0.88), 0.55)
	var plaster := IslandSkyscrapers._surface_mat("Plaster002", 0.35, Color(1.1, 1.04, 0.92), 0.7)
	var gold := IslandSkyscrapers._flat(Color(0.88, 0.70, 0.28), 0.22, 0.95)
	var iron := IslandSkyscrapers._flat(Color(0.03, 0.03, 0.04), 0.35, 0.8)
	var plate := IslandSkyscrapers._flat(Color(0.04, 0.17, 0.11), 0.4, 0.2)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.95, 0.8)
	CityLights.register_material(lamp, Color(1.0, 0.85, 0.5), 3.0)
	var zf := Z0
	for side in [-1.0, 1.0]:
		var px: float = GATE_X0 - 1.2 if side < 0.0 else GATE_X1 + 1.2
		Miami._box(mb_stone, stone, Vector3(px - 1.35, Y, zf - 1.35), Vector3(px + 1.35, Y + 1.0, zf + 1.35))
		Miami._box(mb_stone, stone, Vector3(px - 1.05, Y + 1.0, zf - 1.05), Vector3(px + 1.05, Y + 5.0, zf + 1.05))
		Miami._box(mb, gold, Vector3(px - 1.3, Y + 5.0, zf - 1.3), Vector3(px + 1.3, Y + 5.2, zf + 1.3))
		Miami._box(mb_stone, stone, Vector3(px - 1.15, Y + 5.2, zf - 1.15), Vector3(px + 1.15, Y + 5.5, zf + 1.15))
		Miami._box(mb, lamp, Vector3(px - 0.4, Y + 5.5, zf - 0.4), Vector3(px + 0.4, Y + 6.2, zf + 0.4))
		Miami._box(mb, gold, Vector3(px - 0.5, Y + 6.2, zf - 0.5), Vector3(px + 0.5, Y + 6.35, zf + 0.5))
		Miami._box(mb, gold, Vector3(px - 0.12, Y + 6.35, zf - 0.12), Vector3(px + 0.12, Y + 7.0, zf + 0.12))
		CoastProps._box(body, Vector3(2.7, 6.0, 2.7), Vector3(px, Y + 3.0, zf))
		var ol := OmniLight3D.new()
		ol.position = Vector3(px, Y + 5.9, zf + 1.2)
		ol.omni_range = 14.0
		ol.light_color = Color(1.0, 0.85, 0.55)
		w.static_root.add_child(ol)
		CityLights.register_light(ol, 1.6)
		# wing wall (15 m): stone course, plastered panel, gold coping, end pillar
		var sx0: float = px - 16.2 if side < 0.0 else px + 1.35
		var sx1: float = sx0 + 14.85
		Miami._box(mb_stone, stone, Vector3(sx0, Y, zf - 0.45), Vector3(sx1, Y + 0.9, zf + 0.45))
		Miami._box(mb_stone, plaster, Vector3(sx0, Y + 0.9, zf - 0.35), Vector3(sx1, Y + 2.7, zf + 0.35))
		Miami._box(mb, gold, Vector3(sx0 - 0.05, Y + 2.7, zf - 0.5), Vector3(sx1 + 0.05, Y + 2.85, zf + 0.5))
		CoastProps._box(body, Vector3(sx1 - sx0, 2.8, 0.9), Vector3((sx0 + sx1) * 0.5, Y + 1.4, zf))
		var ex: float = sx0 + 0.6 if side < 0.0 else sx1 - 0.6
		Miami._box(mb_stone, stone, Vector3(ex - 0.6, Y, zf - 0.6), Vector3(ex + 0.6, Y + 3.2, zf + 0.6))
		Miami._box(mb, gold, Vector3(ex - 0.72, Y + 3.2, zf - 0.72), Vector3(ex + 0.72, Y + 3.38, zf + 0.72))
		CoastProps._box(body, Vector3(1.2, 3.2, 1.2), Vector3(ex, Y + 1.6, zf))
	# name sign: dark green plate with a gold frame on each wing wall (road side), gold script lettering
	var font := load("res://assets/fonts/Pacifico-Regular.ttf") as Font
	var font2 := load("res://assets/fonts/Oswald.ttf") as Font
	for side in [-1.0, 1.0]:
		var px2: float = GATE_X0 - 1.2 if side < 0.0 else GATE_X1 + 1.2
		var cx: float = px2 + side * 8.9
		Miami._box(mb, gold, Vector3(cx - 5.9, Y + 0.95, zf - 0.47), Vector3(cx + 5.9, Y + 2.65, zf - 0.34))
		Miami._box(mb, plate, Vector3(cx - 5.75, Y + 1.05, zf - 0.5), Vector3(cx + 5.75, Y + 2.55, zf - 0.36))
		Miami._box(mb, gold, Vector3(cx - 4.4, Y + 1.62, zf - 0.52), Vector3(cx + 4.4, Y + 1.66, zf - 0.5))
		var t1 := Label3D.new()
		t1.text = "Redline Golf Club"
		t1.font = font
		t1.font_size = 120
		t1.pixel_size = 0.0058
		t1.modulate = Color(0.98, 0.82, 0.38)
		t1.outline_size = 6
		t1.outline_modulate = Color(0.2, 0.13, 0.02, 0.8)
		t1.rotation.y = PI
		t1.position = Vector3(cx, Y + 2.14, zf - 0.53)
		w.static_root.add_child(t1)
		var t2 := Label3D.new()
		t2.text = "PRIVATE MEMBERS CLUB  -  EST. 2026"
		t2.font = font2
		t2.font_size = 64
		t2.pixel_size = 0.0042
		t2.modulate = Color(0.95, 0.9, 0.78)
		t2.outline_size = 4
		t2.outline_modulate = Color(0.04, 0.1, 0.06)
		t2.rotation.y = PI
		t2.position = Vector3(cx, Y + 1.33, zf - 0.53)
		w.static_root.add_child(t2)
	_sliding_gate(w, body, mb, iron, gold, stone)
	_checkin(w, body, mb, mb_stone, plaster, stone, gold, plate)

## A sliding gate: one long leaf of bars on a track that rolls sideways behind the west wing wall (shown open), with a guide rail
## across the opening, support posts and the drive motor housing.
static func _sliding_gate(w: World, body: StaticBody3D, mb: Dictionary, iron: Material, gold: Material, stone: Material) -> void:
	var zl := Z0 + 1.45
	var x1 := GATE_X0 - 2.6          # leaf's right end sits just behind the west pillar
	var ln := 15.0
	var x0 := x1 - ln
	var h := 2.7
	var y0 := Y + 0.18
	var lm := {}
	Miami._box(lm, iron, Vector3(x0, y0, zl - 0.06), Vector3(x1, y0 + 0.14, zl + 0.06))
	Miami._box(lm, iron, Vector3(x0, y0 + h - 0.14, zl - 0.06), Vector3(x1, y0 + h, zl + 0.06))
	Miami._box(lm, gold, Vector3(x0, y0 + h * 0.55, zl - 0.05), Vector3(x1, y0 + h * 0.55 + 0.09, zl + 0.05))
	Miami._box(lm, iron, Vector3(x0, y0, zl - 0.08), Vector3(x0 + 0.12, y0 + h, zl + 0.08))
	Miami._box(lm, iron, Vector3(x1 - 0.12, y0, zl - 0.08), Vector3(x1, y0 + h, zl + 0.08))
	var n := int(ln / 0.16)
	for i in range(1, n):
		var x := x0 + float(i) * ln / n
		Miami._box(lm, iron, Vector3(x - 0.02, y0 + 0.14, zl - 0.025), Vector3(x + 0.02, y0 + h - 0.14, zl + 0.025))
		if i % 2 == 0:
			Miami._box(lm, gold, Vector3(x - 0.03, y0 + h, zl - 0.03), Vector3(x + 0.03, y0 + h + 0.2, zl + 0.03))
	var mi := MeshInstance3D.new()
	mi.mesh = Miami._finish(lm)
	w.static_root.add_child(mi)
	CoastProps._box(body, Vector3(ln, h, 0.2), Vector3((x0 + x1) * 0.5, y0 + h * 0.5, zl))
	# track across the whole opening, wheel carriers and posts
	Miami._box(mb, iron, Vector3(x0 - 0.5, Y, zl - 0.05), Vector3(GATE_X1 + 1.0, Y + 0.06, zl + 0.05))
	for px in [x0 + 0.6, x0 + 7.0, x1 - 0.6]:
		Miami._box(mb, stone, Vector3(px - 0.22, Y, zl - 0.22), Vector3(px + 0.22, Y + 0.12, zl + 0.22))
		Miami._box(mb, iron, Vector3(px - 0.1, Y, zl + 0.6), Vector3(px + 0.1, y0 + h + 0.15, zl + 0.8))
		Miami._box(mb, iron, Vector3(px - 0.1, y0 + h + 0.05, zl), Vector3(px + 0.1, y0 + h + 0.15, zl + 0.8))
	# receiver post at the east pillar and the motor housing
	Miami._box(mb, iron, Vector3(GATE_X1 - 0.3, Y, zl - 0.12), Vector3(GATE_X1 - 0.1, y0 + h, zl + 0.12))
	Miami._box(mb, iron, Vector3(x1 + 0.2, Y, zl + 0.15), Vector3(x1 + 1.1, Y + 1.0, zl + 0.9))
	Miami._box(mb, gold, Vector3(x1 + 0.2, Y + 1.0, zl + 0.15), Vector3(x1 + 1.1, Y + 1.08, zl + 0.9))
	CoastProps._box(body, Vector3(0.9, 1.0, 0.75), Vector3(x1 + 0.65, Y + 0.5, zl + 0.52))

## The check-in gate: a wide plastered canopy over both lanes on stone columns with a CHECK-IN sign, the guard booth beside the drive
## and the barrier arm across the inbound lane.
static func _checkin(w: World, body: StaticBody3D, mb: Dictionary, mb_stone: Dictionary, plaster: Material, stone: Material, gold: Material, plate: Material) -> void:
	var zc0 := Z0 + 8.0
	var zc1 := Z0 + 20.0
	var xc0 := GATE_X0 - 9.0
	var xc1 := GATE_X1 + 9.0
	var ty := Y + 6.2
	Miami._box(mb_stone, plaster, Vector3(xc0, ty, zc0), Vector3(xc1, ty + 0.7, zc1))
	Miami._box(mb, gold, Vector3(xc0 - 0.1, ty - 0.12, zc0 - 0.1), Vector3(xc1 + 0.1, ty + 0.0, zc1 + 0.1))
	Miami._box(mb, gold, Vector3(xc0 - 0.1, ty + 0.7, zc0 - 0.1), Vector3(xc1 + 0.1, ty + 0.85, zc1 + 0.1))
	for cx in [xc0 + 1.0, xc1 - 1.0]:
		for cz in [zc0 + 1.0, zc1 - 1.0]:
			Miami._box(mb_stone, stone, Vector3(cx - 0.55, Y, cz - 0.55), Vector3(cx + 0.55, ty, cz + 0.55))
			Miami._box(mb, gold, Vector3(cx - 0.7, Y, cz - 0.7), Vector3(cx + 0.7, Y + 0.25, cz + 0.7))
			Miami._box(mb, gold, Vector3(cx - 0.65, ty - 0.2, cz - 0.65), Vector3(cx + 0.65, ty, cz + 0.65))
			CoastProps._box(body, Vector3(1.1, ty - Y, 1.1), Vector3(cx, Y + (ty - Y) * 0.5, cz))
	# sign on the fascia facing the road
	Miami._box(mb, plate, Vector3(CX - 6.0, ty + 0.1, zc0 - 0.12), Vector3(CX + 6.0, ty + 0.62, zc0 - 0.02))
	var t := Label3D.new()
	t.text = "CHECK-IN  -  MEMBERS & GUESTS"
	t.font = load("res://assets/fonts/Oswald.ttf") as Font
	t.font_size = 80
	t.pixel_size = 0.0062
	t.modulate = Color(0.98, 0.84, 0.42)
	t.outline_size = 5
	t.outline_modulate = Color(0.04, 0.1, 0.06)
	t.rotation.y = PI
	t.position = Vector3(CX, ty + 0.36, zc0 - 0.14)
	w.static_root.add_child(t)
	# canopy lights
	for lx in [GATE_X0 + 3.0, GATE_X1 - 3.0]:
		var ol := OmniLight3D.new()
		ol.position = Vector3(lx, ty - 0.4, (zc0 + zc1) * 0.5)
		ol.omni_range = 16.0
		ol.light_color = Color(1.0, 0.9, 0.7)
		w.static_root.add_child(ol)
		CityLights.register_light(ol, 2.0)
	# booth on a raised island between the lanes (the model keeps only its guard house), a long barrier arm across the inbound lane
	# (closed) and one across the outbound lane (raised)
	var zm := (zc0 + zc1) * 0.5
	var isl := IslandSkyscrapers._flat(Color(0.62, 0.60, 0.55), 0.8)
	Miami._box(mb, isl, Vector3(CX - 1.9, Y, zc0 + 1.0), Vector3(CX + 1.9, Y + 0.16, zc1 - 1.0))
	CoastProps._box(body, Vector3(3.8, 0.16, zc1 - zc0 - 2.0), Vector3(CX, Y + 0.08, zm))
	var gbk: Dictionary = Miami._bake(G + "checkpoint_gate.glb", "Guard House", 0.0, 0.6, "")
	if gbk.is_empty(): gbk = Miami._bake(G + "checkpoint_gate.glb", "", 0.0, 0.6)
	if not gbk.is_empty():
		var gmi := MeshInstance3D.new()
		gmi.mesh = gbk.mesh
		gmi.position = Vector3(CX, Y + 0.16, zm)
		gmi.rotation.y = PI
		w.static_root.add_child(gmi)
		CoastProps._box(body, Vector3(minf(gbk.size.x, 3.4), gbk.size.y, minf(gbk.size.z, 3.4)), gmi.position + Vector3(0.0, gbk.size.y * 0.5, 0.0))
		print("GolfClub: booth size ", gbk.size)
	_barrier(w, body, mb, Vector3(CX - 2.0, Y, zm - 4.2), -1.0, false)
	_barrier(w, body, mb, Vector3(CX + 2.0, Y, zm - 4.2), 1.0, true)

## A boom barrier: red housing on a base with a light, and an arm 5 m long with red / white stripes. open = the arm stands upright.
static func _barrier(w: World, body: StaticBody3D, mb: Dictionary, base: Vector3, side: float, open: bool) -> void:
	var red := IslandSkyscrapers._flat(Color(0.80, 0.08, 0.10), 0.45, 0.2)
	var white := IslandSkyscrapers._flat(Color(0.96, 0.96, 0.94), 0.5)
	var dark := IslandSkyscrapers._flat(Color(0.12, 0.12, 0.14), 0.5, 0.5)
	Miami._box(mb, dark, Vector3(base.x - 0.55, base.y, base.z - 0.55), Vector3(base.x + 0.55, base.y + 0.18, base.z + 0.55))
	Miami._box(mb, red, Vector3(base.x - 0.42, base.y + 0.18, base.z - 0.42), Vector3(base.x + 0.42, base.y + 1.35, base.z + 0.42))
	Miami._box(mb, dark, Vector3(base.x - 0.46, base.y + 1.35, base.z - 0.46), Vector3(base.x + 0.46, base.y + 1.42, base.z + 0.46))
	Miami._box(mb, IslandSkyscrapers._flat(Color(1.0, 0.7, 0.1), 0.3), Vector3(base.x - 0.12, base.y + 1.42, base.z - 0.12), Vector3(base.x + 0.12, base.y + 1.6, base.z + 0.12))
	CoastProps._box(body, Vector3(1.1, 1.6, 1.1), base + Vector3(0.0, 0.8, 0.0))
	var armlen := 5.2
	var seg := 0.65
	var n := int(armlen / seg)
	if open:
		for k in range(n):
			var y0: float = base.y + 1.2 + k * seg
			Miami._box(mb, red if k % 2 == 0 else white, Vector3(base.x - 0.1, y0, base.z - 0.06), Vector3(base.x + 0.1, y0 + seg, base.z + 0.06))
	else:
		for k in range(n):
			var x0: float = base.x + side * (0.45 + k * seg)
			var x1: float = x0 + side * seg
			Miami._box(mb, red if k % 2 == 0 else white, Vector3(minf(x0, x1), base.y + 1.12, base.z - 0.06), Vector3(maxf(x0, x1), base.y + 1.34, base.z + 0.06))
		var cx: float = base.x + side * (0.45 + armlen * 0.5)
		CoastProps._box(body, Vector3(armlen, 0.22, 0.14), Vector3(cx, base.y + 1.23, base.z))
## A cup (dark hole with a white rim) in the middle of the green and a flagstick with a red flag that waves in the wind.
static func _hole_and_flag(w: World, body: StaticBody3D, mb: Dictionary, p: Vector3, idx: int) -> void:
	_disc3(w, IslandSkyscrapers._flat(Color(0.93, 0.93, 0.9), 0.6), Vector3(p.x, p.y + 0.012, p.z), 0.16, 0.012)
	_disc3(w, IslandSkyscrapers._flat(Color(0.02, 0.02, 0.02), 1.0), Vector3(p.x, p.y + 0.022, p.z), 0.11, 0.012)
	var pole := IslandSkyscrapers._flat(Color(0.97, 0.97, 0.95), 0.4, 0.3)
	Miami._box(mb, pole, Vector3(p.x - 0.022, p.y, p.z - 0.022), Vector3(p.x + 0.022, p.y + 2.5, p.z + 0.022))
	Miami._box(mb, IslandSkyscrapers._flat(Color(0.85, 0.7, 0.25), 0.3, 0.9), Vector3(p.x - 0.045, p.y + 2.5, p.z - 0.045), Vector3(p.x + 0.045, p.y + 2.56, p.z + 0.045))
	CoastProps._box(body, Vector3(0.12, 2.5, 0.12), Vector3(p.x, p.y + 1.25, p.z))
	# the cloth: 14 x 6 grid, UV.x from the pole (0) to the free end (1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 14
	var ny := 6
	var fw := 0.95
	var fh := 0.6
	for j in range(ny + 1):
		for i in range(nx + 1):
			var u := float(i) / nx
			var v := float(j) / ny
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(Vector3(u * fw, -v * fh, 0.0))
	for j in range(ny):
		for i in range(nx):
			var a := j * (nx + 1) + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + nx + 1)
			st.add_index(a + 1)
			st.add_index(a + nx + 2)
			st.add_index(a + nx + 1)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/flag_wave.gdshader") as Shader
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = sm
	mi.position = Vector3(p.x + 0.025, p.y + 2.48, p.z)
	mi.rotation.y = -PI * 0.5 + 0.35 * float(idx)          # streams away from the pole; each flag a little different
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

static func _disc3(w: World, mat: Material, c: Vector3, r: float, h: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	cm.rings = 1
	cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = c
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

## Two flat paved pads beside the clubhouse with the golf carts parked in a neat row, wheels on the slab, each one solid.
static func _cart_pads(w: World, body: StaticBody3D, mb: Dictionary) -> void:
	var slab := IslandSkyscrapers._surface_mat("PavingStones136", 0.45, Color(1.05, 1.0, 0.92), 0.85)
	var line := IslandSkyscrapers._flat(Color(0.95, 0.95, 0.9), 0.8)
	for pad in CART_PADS:
		var r: Rect2 = pad
		Miami._box(mb, slab, Vector3(r.position.x, Y, r.position.y), Vector3(r.end.x, Y + 0.04, r.end.y))
		CoastProps._box(body, Vector3(r.size.x, 0.06, r.size.y), Vector3(r.position.x + r.size.x * 0.5, Y + 0.02, r.position.y + r.size.y * 0.5))
		var n := 5
		for k in range(n):
			var cx: float = r.position.x + (k + 0.5) * r.size.x / n
			Miami._box(mb, line, Vector3(cx - 1.55, Y + 0.04, r.position.y + 1.0), Vector3(cx - 1.5, Y + 0.05, r.end.y - 1.0))
			LazyCars.add(w, "golfcart", Vector3(cx, Y + 0.04 + Car.RIDE + 0.12, r.position.y + r.size.y * 0.5), 0.0)
		Miami._box(mb, line, Vector3(r.end.x - 0.05 - r.size.x / n * 0.0, Y + 0.04, r.position.y + 1.0), Vector3(r.end.x, Y + 0.05, r.end.y - 1.0))


## Water jets above the clover fountain: a tall centre jet from the top bowl and a ring of low arcs over the lower basin.
static func _fountain_jets(w: World, base: Vector3, fh: float) -> void:
	var tex := load("res://assets/vfx/circle_05.png") as Texture2D
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.vertex_color_use_as_albedo = true
	pm.albedo_texture = tex
	pm.albedo_color = Color(0.9, 0.97, 1.0, 0.6)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = pm
	var jets := [[Vector3(0.0, fh * 0.92, 0.0), 6.5, 2.0, 160]]
	for k in range(6):
		var a := TAU * k / 6.0
		jets.append([Vector3(cos(a) * 3.0, fh * 0.45, sin(a) * 3.0), 3.6, 14.0, 70])
	for j in jets:
		var pr := ParticleProcessMaterial.new()
		pr.direction = Vector3(0.0, 1.0, 0.0)
		pr.spread = float(j[2])
		pr.initial_velocity_min = float(j[1])
		pr.initial_velocity_max = float(j[1]) * 1.2
		pr.gravity = Vector3(0.0, -9.8, 0.0)
		pr.scale_min = 0.7
		pr.scale_max = 1.3
		var pt := GPUParticles3D.new()
		pt.process_material = pr
		pt.draw_pass_1 = quad
		pt.amount = int(j[3])
		pt.lifetime = 1.8
		pt.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 12, 12))
		pt.position = base + (j[0] as Vector3)
		w.static_root.add_child(pt)

## Floodlights around the course: the same tower the fair uses (CityBuild.floodlight, low_poly_reflector), two real spot lights each,
## aimed at the middle of the course; the lamp discs and beams switch on with the night clock.
static func _stadium_lights(w: World, body: StaticBody3D) -> void:
	var spots := [Vector2(15.0, 2262.0), Vector2(15.0, 2340.0), Vector2(15.0, 2416.0), Vector2(185.0, 2262.0), Vector2(185.0, 2340.0), Vector2(185.0, 2416.0)]
	for sp in spots:
		CityBuild.floodlight(w, body, Y + ground_h(sp.x, sp.y), sp, Vector2(CX, 2335.0), 2.0, 2)

## The clubhouse entrance door (see GolfDoor): hinge on the west jamb, swings into the hall.
static func _clubhouse_door(w: World, door_mesh: ArrayMesh, house_pos: Vector3) -> void:
	if door_mesh.get_surface_count() == 0: return
	var hinge := Vector3(1.8502, 0.0, 6.3107)               # in the clubhouse model's own space (before its half turn)
	var d := GolfDoor.new()
	d.base_yaw = PI
	d.position = house_pos + Basis(Vector3.UP, PI) * hinge
	d.rotation.y = PI
	var mi := MeshInstance3D.new()
	mi.mesh = door_mesh
	mi.position = -hinge
	d.add_child(mi)
	# the leaf is solid whatever its angle: it blocks the doorway while shut and stands against the jamb when open
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.87, 4.45, 0.16)
	cs.shape = bx
	cs.position = Vector3(1.435, 2.22, 0.0)
	sb.add_child(cs)
	d.add_child(sb)
	w.static_root.add_child(d)

## Club staff and members: a guard patrolling the check-in, the gate attendant, the receptionist, bartender and people in the lounge.
static func _staff(w: World) -> void:
	var fy := Y + 0.03
	# gate: the attendant at the check-in booth and one guard walking the drive inside the barrier
	LazyCars.add_npc(w, "npc_luiz", Vector3(CX, Y + 0.16, Z0 + 9.9), PI, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_guard", Vector3(104.5, Y + 0.02, Z0 + 16.0), 0.0, "Idle", [Vector3(104.5, Y + 0.02, Z0 + 17.0), Vector3(104.5, Y + 0.02, Z0 + 32.0)])
	# clubhouse: receptionist behind the desk, a bartender, two golfers talking, two more chatting on the lounge rug
	LazyCars.add_npc(w, "npc_ch21", Vector3(102.2, fy, 2334.6), PI, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_luiz", Vector3(103.2, fy, 2340.6), PI * 0.5, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_luiz", Vector3(91.2, fy, 2331.6), PI * 0.5, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_ch21", Vector3(92.5, fy, 2331.6), -PI * 0.5, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_ch21", Vector3(90.9, fy, 2336.6), -PI * 0.5, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_luiz", Vector3(87.2, fy, 2336.6), PI * 0.5, "UAL_Idle_Talking")
