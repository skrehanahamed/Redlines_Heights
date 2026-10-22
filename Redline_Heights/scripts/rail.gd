class_name Rail
extends RefCounted
## A railway across the whole map: two parallel tracks running east-west, a station (from the supplied model) at each
## end, and a train (also from the model) that shuttles between the two stations.

const MODEL := "res://assets/train/train_ride.glb"
const LIFT := 2.75                    # the model's rails sit 2.75 m below its origin; raised so the rails lie on the ground
const GAP := 15.0                    # length of road replaced by the crossing slab, metres
const TRACK2 := 5.0                   # second track, metres to the side of the first (model x)
const PLATFORM_Z := -20.0             # platform centre along the model's track axis
## The loop: an oval round the town. The city station is on its south side, the airport station on its north side;
## both sit on straight stretches because the station model is straight.
const XL := -250.0
const XR := 1100.0
const Z0 := -560.0
const Z1 := 470.0
const R := 515.0
const ZC := -45.0
const STEP := 1.5
static var loop_len := 0.0
static var pts := PackedVector2Array()
static var station_dir: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]   # world direction from the track towards each station building
static var station_s := [300.0, 0.0]          # path distance of each station's origin (set in _make_path)

const TRAIN_STEMS := ["bacj wheel", "back door", "back door fluff", "back fluff", "back lights", "back panel", "back platform",
	"tow screw", "tow shaft", "car body", "car body bottom", "door 1", "door 2", "finale head lower", "front break",
	"front break attecher", "front break buffer", "front lights", "front window side", "top exhaust 1", "top exhaiust 2",
	"top generator", "top generator 2", "top rails", "tow arm", "tow clip", "train head", "train back gen",
	"train lights front", "train wheel main spring", "wheel main bracket"]

static func _stem(n: Node) -> String:
	return String(n.get_parent().name).get_slice(".", 0).get_slice("_0", 0).to_lower()

static func _rel(n: Node, r: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != r:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

## Station = the model without its train.
static func _station_scene() -> Node3D:
	var inst := (load(MODEL) as PackedScene).instantiate() as Node3D
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if TRAIN_STEMS.has(_stem(mi)):
			mi.get_parent().remove_child(mi)
			mi.free()
		else:
			(mi as MeshInstance3D).visibility_range_end = 900.0
	return inst

## Position and unit direction of travel at path distance s (wraps round the loop).
static func at(s: float) -> Array:
	var f := fposmod(s, loop_len) / STEP
	var i := int(f) % pts.size()
	var j := (i + 1) % pts.size()
	var t := f - floorf(f)
	var p := pts[i].lerp(pts[j], t)
	var d := (pts[j] - pts[i]).normalized()
	return [p, d]

static func _make_path() -> void:
	var raw := PackedVector2Array()
	var line := func(a: Vector2, b: Vector2) -> void:
		var n := maxi(1, int(a.distance_to(b) / 0.5))
		for k in range(n): raw.append(a.lerp(b, float(k) / n))
	var arc := func(c: Vector2, v0: Vector2, v1: Vector2) -> void:
		var n := int(R * PI * 0.5 / 0.5)
		for k in range(n):
			var t := (PI * 0.5) * float(k) / n
			raw.append(c + v0 * cos(t) + v1 * sin(t))
	line.call(Vector2(XL, Z1), Vector2(XR, Z1))
	arc.call(Vector2(XR, ZC), Vector2(0, R), Vector2(R, 0))
	arc.call(Vector2(XR, ZC), Vector2(R, 0), Vector2(0, -R))
	line.call(Vector2(XR, Z0), Vector2(XL, Z0))
	arc.call(Vector2(XL, ZC), Vector2(0, -R), Vector2(-R, 0))
	arc.call(Vector2(XL, ZC), Vector2(-R, 0), Vector2(0, R))
	var cum := PackedFloat32Array()
	cum.resize(raw.size() + 1)
	var acc := 0.0
	for i in range(raw.size()):
		cum[i] = acc
		acc += raw[i].distance_to(raw[(i + 1) % raw.size()])
	cum[raw.size()] = acc
	var n := int(round(acc / STEP))
	loop_len = n * STEP
	pts = PackedVector2Array()
	var k := 0
	for m in range(n):
		var target := acc * float(m) / n
		while k < raw.size() - 1 and cum[k + 1] < target: k += 1
		var seg := cum[k + 1] - cum[k]
		var tt := (target - cum[k]) / maxf(seg, 0.0001)
		pts.append(raw[k].lerp(raw[(k + 1) % raw.size()], tt))
	var bottom := XR - XL
	station_s[0] = 100.0 - XL                              # city station: bottom straight, origin at x = 100
	station_s[1] = bottom + PI * R + (XR - 830.0)         # airport station: top straight, origin at x = 830

static func build(w: World) -> void:
	if not ResourceLoader.exists(MODEL): return
	_make_path()
	_tracks(w)
	var names := ["CITY STATION", "AIRPORT STATION"]
	for i in range(2):
		station_dir[i] = _station(w, station_s[i], names[i])
		var a := at(station_s[i] + PLATFORM_Z)
		var p: Vector2 = a[0]
		w.add_poi("station", names[i], Vector3(p.x, 0, p.y))
	_crossings(w)
	for k in range(2):
		var t := Train.new()
		t.index = k
		w.add_child(t)
	print("rail: loop ", snappedf(loop_len, 1.0), " m, 2 stations, 2 trains")

static func _station(w: World, s: float, title: String) -> Vector2:
	var a := at(s)
	var p: Vector2 = a[0]
	var d: Vector2 = a[1]
	var root := Node3D.new()
	root.name = "TrainStation"
	root.position = Vector3(p.x, LIFT, p.y)
	root.rotation.y = atan2(d.x, d.y)     # model +Z (the track axis) -> direction of travel
	var scene := _station_scene()
	root.add_child(scene)
	w.static_root.add_child(root)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var stem := _stem(m)
		var xf := _rel(m, root)
		if stem == "platform top" or stem == "platform bottom":
			var faces: PackedVector3Array = m.mesh.get_faces()
			var out := PackedVector3Array()
			out.resize(faces.size())
			for i in range(faces.size()): out[i] = xf * faces[i]
			var sh := ConcavePolygonShape3D.new()
			sh.set_faces(out)
			var cs := CollisionShape3D.new()
			cs.shape = sh
			body.add_child(cs)
		elif stem in ["main station", "lower waiting shed", "pillar"]:
			var bb: AABB = xf * m.get_aabb()
			var cs2 := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = bb.size
			cs2.shape = bs
			cs2.position = bb.get_center()
			body.add_child(cs2)
	# live "next train" boards over the model's own timetable panels
	var boards := StationBoards.new()
	boards.station_idx = 0 if title.begins_with("CITY") else 1
	root.add_child(boards)
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m2 := mi as MeshInstance3D
		if _stem(m2) != "train schedule": continue
		for si in range(m2.mesh.get_surface_count()):
			var sm := m2.get_active_material(si) as BaseMaterial3D
			if sm != null and sm.resource_name == "Light_Texture":
				var bb2: AABB = _rel(m2, root) * m2.get_aabb()
				boards.add_panel(root, bb2.get_center(), Vector2(bb2.size.x, bb2.size.y))
				break
	var bd := root.global_transform.basis * Vector3(-1, 0, 0)
	_stairs(w, root, body)
	_forecourt(w, root, title, -1.0 if title.begins_with("CITY") else 1.0)
	# gentle ramps down from the raised platforms (platform top is 1.45 m above the ground)
	for zz in [-61.0 - 7.0, 22.0 + 7.0]:
		for xx in [-12.0, 10.0]:
			var ramp := CollisionShape3D.new()
			var rb := BoxShape3D.new()
			rb.size = Vector3(6.0, 0.3, 14.5)
			ramp.shape = rb
			var dir := -1.0 if zz < 0.0 else 1.0
			var ang := atan2(1.45, 14.0) * dir
			ramp.transform = Transform3D(Basis(Vector3.RIGHT, ang), Vector3(xx, -1.3 - 0.87, zz))
			body.add_child(ramp)
			var rm := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = rb.size
			rm.mesh = bm
			rm.material_override = w._flat(Color("#4a4c50"))
			rm.transform = ramp.transform
			root.add_child(rm)
	return Vector2(bd.x, bd.z)

static func _tracks(w: World) -> void:
	var gravel := w._mat("res://assets/textures/y2k_ground.png", 0.35, Color(0.62, 0.6, 0.57))
	var wood := w._flat(Color("#3b2b22"))
	var steel := w._flat(Color("#8b8f96"))
	var bed_m := BoxMesh.new(); bed_m.size = Vector3(3.8, 0.05, STEP + 0.12)
	var rail_m := BoxMesh.new(); rail_m.size = Vector3(0.09, 0.06, STEP + 0.12)
	var flat_m := BoxMesh.new(); flat_m.size = Vector3(0.16, 0.05, STEP + 0.12)
	var plank_m := BoxMesh.new(); plank_m.size = Vector3(3.0, 0.03, 0.42)
	var sup_m := BoxMesh.new(); sup_m.size = Vector3(0.34, 0.215, STEP + 0.12)
	var supports: Array = []
	var slp_m := BoxMesh.new(); slp_m.size = Vector3(2.7, 0.03, 0.3)
	# where a road crosses the line the track is laid flush with the road, so tyres roll over it cleanly
	var flush := {}
	for c in _find_crossings():
		for k in range(-3, 4):            # a little narrower than the road slab (10.5 m vs 11.7 m), so the track bed ends under the slab edge
			flush[posmod(int(c[0]) + k, pts.size())] = true
	# height of the bed beside a crossing: it climbs to the level of the road slab over ~12 m so the line joins it without a step
	var np := pts.size()
	var near := PackedInt32Array()
	near.resize(np)
	near.fill(99)
	for pass_i in range(2):
		for i in range(np * 2):
			var ii := i % np
			if flush.has(ii): near[ii] = 0
			else: near[ii] = mini(near[ii], near[(ii - 1 + np) % np] + 1)
		for i in range(np * 2):
			var ii2 := np - 1 - (i % np)
			if not flush.has(ii2): near[ii2] = mini(near[ii2], near[(ii2 + 1) % np] + 1)
	var beds: Array = []
	var rails: Array = []
	var flats: Array = []
	var slps: Array = []
	var bed_body := StaticBody3D.new()
	bed_body.name = "TrackBed"
	bed_body.collision_layer = 1
	var bed_shape := BoxShape3D.new()
	bed_shape.size = Vector3(3.8, 0.12, STEP * 4.0 + 0.3)
	for off in [0.0, TRACK2]:
		for i in range(pts.size()):
			var j := (i + 1) % pts.size()
			var d := (pts[j] - pts[i]).normalized()
			var n := Vector2(d.y, -d.x)
			var mid := (pts[i] + pts[j]) * 0.5 + n * float(off)
			var b := Basis(Vector3.UP, atan2(d.x, d.y))
			if flush.has(i):
				for side in [-0.72, 0.72]:
					var qf := mid + n * float(side)
					flats.append(Transform3D(b, Vector3(qf.x, 0.205, qf.y)))     # on top of the road surface (0.186 m)
					supports.append(Transform3D(b, Vector3(qf.x, 0.1, qf.y)))   # solid base down to the ground, so no rail hangs in the air
				continue
			var hb := lerpf(0.17, 0.05, smoothstep(0.0, 8.0, float(near[i] - 1)))
			beds.append(Transform3D(b.scaled(Vector3(1, hb / 0.05, 1)), Vector3(mid.x, hb * 0.5, mid.y)))
			for side in [-0.72, 0.72]:
				var q := mid + n * float(side)
				rails.append(Transform3D(b, Vector3(q.x, hb + 0.03, q.y)))
			for sl in [-0.375, 0.375]:
				var q2 := mid + d * float(sl)
				slps.append(Transform3D(b, Vector3(q2.x, hb + 0.015, q2.y)))
			# one solid block per four segments, so cars and people cannot drive or walk through the track
			if i % 4 == 0:
				var skip := false
				for k in range(4):
					if flush.has((i + k) % pts.size()): skip = true
				if not skip:
					var j4 := (i + 4) % pts.size()
					var d4 := (pts[j4] - pts[i]).normalized()
					var n4 := Vector2(d4.y, -d4.x)
					var c4 := (pts[i] + pts[j4]) * 0.5 + n4 * float(off)
					var cs := CollisionShape3D.new()
					cs.shape = bed_shape
					cs.transform = Transform3D(Basis(Vector3.UP, atan2(d4.x, d4.y)), Vector3(c4.x, 0.06, c4.y))
					cs.free()
	for e in [[bed_m, beds, gravel], [rail_m, rails, steel], [flat_m, flats, steel], [slp_m, slps, wood], [sup_m, supports, gravel]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = e[0]
		var arr: Array = e[1]
		mm.instance_count = arr.size()
		for i in range(arr.size()): mm.set_instance_transform(i, arr[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = e[2]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mmi)


## Level crossings: wherever a road meets the railway, barrier gates on both sides with flashing red lights.
## They drop when a train is within 160 m of the crossing and lift again after it has passed.
static var _cross_cache: Array = []

## World positions (middle of the double track) of every road crossing.
static func crossing_points() -> Array:
	if _cross_cache.is_empty():
		if pts.is_empty(): _make_path()
		for c in _find_crossings():
			var i: int = c[0]
			var j := (i + 1) % pts.size()
			var dd := (pts[j] - pts[i]).normalized()
			var nn := Vector2(dd.y, -dd.x)
			_cross_cache.append((c[1] as Vector2) + nn * (TRACK2 * 0.5))
	return _cross_cache

static func _find_crossings() -> Array:
	var cross_pts: Array = []
	for e in CityData.edges:
		if int(e[2]) == 4: continue
		var ra := CityData.nodes[int(e[0])]
		var rb := CityData.nodes[int(e[1])]
		var last := -1000
		for i in range(pts.size()):
			var j := (i + 1) % pts.size()
			var q = Geometry2D.segment_intersects_segment(ra, rb, pts[i], pts[j])
			if q != null and i - last > 40:
				last = i
				cross_pts.append([i, q as Vector2, rb - ra])
	return cross_pts

## A plain stretch of road with the rails set into it, in place of the road pieces that were cut away.
static func _slab(w: World, body: StaticBody3D, p: Vector2, dir: Vector2, asphalt: Material, pave: Material) -> void:
	var yaw := atan2(dir.x, dir.y)
	var centre := Vector3(p.x, 0.0, p.y)
	var parts := [[Vector3(0, 0.09, 0), Vector3(8.6, 0.18, GAP), asphalt], [Vector3(-5.05, 0.093, 0), Vector3(1.5, 0.186, GAP), pave], [Vector3(5.05, 0.093, 0), Vector3(1.5, 0.186, GAP), pave]]
	for pr in parts:
		var sz: Vector3 = pr[1]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = pr[2]
		mi.position = centre + Basis(Vector3.UP, yaw) * (pr[0] as Vector3)
		mi.rotation.y = yaw
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, yaw), mi.position)
		body.add_child(cs)

static func _crossings(w: World) -> void:
	var cross_pts := _find_crossings()
	RoadKit._mats(w)
	var asphalt := RoadKit._plain_mat
	var pave := w._mat("res://assets/roads/pavement.png", 0.18, Color(1.05, 1.03, 1.0))
	var slab_body := StaticBody3D.new()
	slab_body.collision_layer = 1
	w.static_root.add_child(slab_body)
	var mids := crossing_points()
	for ci in range(cross_pts.size()):
		var c: Array = cross_pts[ci]
		_slab(w, slab_body, mids[ci] as Vector2, (c[2] as Vector2).normalized(), asphalt, pave)
		var g := Crossing.new()
		g.setup(w, float(c[0]) * STEP, c[1], (c[2] as Vector2).normalized(), TRACK2)
		w.add_child(g)
	print("rail: ", cross_pts.size(), " level crossings")


const GROUND := -2.75            # model-local y of the ground the platforms stand on
const PLAT_TOP := -1.3

static func _lbox(w: World, root: Node3D, body: StaticBody3D, c: Vector3, size: Vector3, mat: Material, solid := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = c
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 450.0
	root.add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = c
		body.add_child(cs)

## Concrete stairs up to the platforms (8 steps of 18 cm), with handrails: two on the building side, two on the far side.
static func _stairs(w: World, root: Node3D, body: StaticBody3D) -> void:
	var concrete := w._mat("res://assets/airport/tex/Concrete034.jpg", 0.4, Color(0.85, 0.85, 0.85))
	var steel := w._flat(Color("#c9ccd0"))
	var n := 8
	var rise := (PLAT_TOP - GROUND) / n
	var run := 0.38
	var width := 4.0
	for spec in [[-20.9, -1.0, -48.0], [-20.9, -1.0, 20.0], [17.0, 1.0, -45.0], [17.0, 1.0, 15.0]]:
		var edge: float = spec[0]
		var dir: float = spec[1]
		var z: float = spec[2]
		for i in range(1, n + 1):
			var cx := edge + dir * run * (n - i + 0.5)
			var h := i * rise
			_lbox(w, root, body, Vector3(cx, GROUND + h * 0.5, z), Vector3(run, h, width), concrete)
		for side in [-1.0, 1.0]:
			var len := run * n
			var cx2 := edge + dir * len * 0.5
			_lbox(w, root, body, Vector3(cx2, PLAT_TOP + 0.55 - 0.7, z + side * (width * 0.5 + 0.05)), Vector3(len, 0.06, 0.06), steel, false)
			for k in range(3):
				var px := edge + dir * len * (0.05 + 0.45 * k)
				_lbox(w, root, body, Vector3(px, PLAT_TOP - 0.2 - (k * 0.0), z + side * (width * 0.5 + 0.05)), Vector3(0.06, 1.1, 0.06), steel, false)

## The forecourt on the building side: a paved strip, an asphalt car park with marked bays and parked cars, lamps,
## a station name board and a bus-stop style shelter.
static func _forecourt(w: World, root: Node3D, title: String, f := 1.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	var asphalt := w._mat("res://assets/airport/tex/Asphalt025C.jpg", 0.25, Color(0.85, 0.85, 0.9))
	var pave := w._mat("res://assets/roads/pavement.png", 0.18, Color(1.05, 1.03, 1.0))
	var kerb := w._mat("res://assets/airport/tex/Concrete034.jpg", 0.3, Color(0.9, 0.9, 0.9))
	var line := w._flat(Color("#ecebe0"))
	var z0 := -55.0
	var z1 := 15.0
	var zc := (z0 + z1) * 0.5
	var tex_y := GROUND + 0.06
	# paved walk from the stairs to the car park
	_lbox(w, root, body, Vector3(f * -24.0, tex_y, zc), Vector3(5.6, 0.12, z1 - z0), pave)
	# car park: driveway strip, two rows of bays
	_lbox(w, root, body, Vector3(f * -38.5, tex_y, zc), Vector3(17.0, 0.12, z1 - z0), asphalt)
	_lbox(w, root, body, Vector3(f * -47.4, GROUND + 0.1, zc), Vector3(0.6, 0.2, z1 - z0), kerb, false)
	for zz in [z0 - 0.3, z1 + 0.3]:
		_lbox(w, root, body, Vector3(f * -38.5, GROUND + 0.1, zz), Vector3(17.6, 0.2, 0.6), kerb, false)
	var bays := int((z1 - z0) / 2.6)
	for row in [[-37.4, -39.9], [-32.2, -34.8]]:
		pass
	for rx in [f * -37.4, f * -32.2]:
		for k in range(bays + 1):
			_lbox(w, root, body, Vector3(rx, tex_y + 0.07, z0 + k * 2.6), Vector3(5.0, 0.02, 0.12), line, false)
	# lamps and a name board
	for lz in [-45.0, -20.0, 5.0]:
		var wp := root.to_global(Vector3(f * -29.0, GROUND, lz))
		var wt := root.to_global(Vector3(f * -33.0, GROUND, lz))
		RoadKit.lamp_at(w, body, Vector2(wp.x, wp.z), Vector2(wt.x, wt.z))
	var board := Label3D.new()
	board.text = title
	board.font_size = 120
	board.pixel_size = 0.02
	board.outline_size = 14
	board.modulate = Color("#ffffff")
	board.position = Vector3(f * -21.0, 5.2, zc)
	board.rotation.y = -PI * 0.5 * f
	board.double_sided = false
	root.add_child(board)
	# a second label on the back so it also reads correctly from the platform side
	var back := Label3D.new()
	back.text = title
	back.font_size = 120
	back.pixel_size = 0.02
	back.outline_size = 14
	back.modulate = Color("#ffffff")
	back.position = board.position
	back.rotation.y = board.rotation.y + PI
	back.double_sided = false
	root.add_child(back)
	var post_c := Vector3(-21.0, 3.5, zc)
	_lbox(w, root, body, Vector3(f * -20.8, 5.1, zc), Vector3(0.2, 1.4, 14.0), w._flat(Color("#1b3c78")), false)
	# parked cars
	var rr := RandomNumberGenerator.new()
	rr.seed = int(root.position.x) + 7
	for rx in [f * -37.4, f * -32.2]:
		for k in range(bays):
			if rr.randf() < 0.4:
				var wp2 := root.to_global(Vector3(rx, GROUND + 0.8 + 0.35, z0 + (k + 0.5) * 2.6))
				var car := Car.new()
				car.position = wp2
				var h := root.global_transform.basis * Vector3(1, 0, 0)
				car.rotation.y = atan2(h.x, h.z) + (0.0 if rr.randf() < 0.5 else PI)
				w.add_child(car)
				car.setup("fumi", "", true)
