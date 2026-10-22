class_name Renowood
extends RefCounted
## Renowood: a hillside neighbourhood in the north, behind the airport. The hills are shaped round a road built from
## the same "Road Modular" pieces as the city (straights, 90 degree curves, crossroads), climbing the hill in
## switchbacks. Every villa stands on its own levelled terrace at the end of a short side road that leaves the main
## road at a proper junction. Cypress trees, a big letter sign on the crest, and a forecourt at the top for the museum.
## The ground comes from height(x, z), used by the terrain mesh, so road, terraces and sign are cut into the hill.

const HC := Vector2(850.0, -1985.0)           # centre of the hill field
const HR := Vector2(700.0, 500.0)             # its radii
const BBOX := Rect2(100.0, -2500.0, 1500.0, 1200.0)
const CREST := Vector2(850.0, -2030.0)
const PLOT_RISE := 1.25                       # the villa plot slab thickness: terrain is levelled to its top
const SAMPLE := 4.0
const MAX_GRADE := 0.085
const HOUSE_LIFT := 0.6
const HOUSE_LIFT_ALL := 0.5                       # the plain white villa has no slab: it stands this much above the terrace
const ROAD_RISE := 0.03                       # the hill road's surface stands this much above the kit road height
const RISE := 0.14                            # the whole road and every house stand this much higher, clear of the ground
const SPUR_LEN := 41.0                        # side road from the main road's centre to the plot's front edge
const PLOT_DIST := 46.0                       # plot centre distance from the main road
const MUSEUM_R := 34.0
const SIGN_C := Vector2(850.0, -2056.0)
const SIGN_HALF := Vector2(96.0, 20.0)

## Main road: a smooth curve through these points (Catmull-Rom), laid with short straight road-kit pieces that each
## turn a few degrees, so it winds up the hill instead of making square corners.
const ROUTE := [Vector2(840, -1288), Vector2(840, -1380), Vector2(880, -1440), Vector2(1000, -1500), Vector2(1090, -1570),
	Vector2(1090, -1670), Vector2(1000, -1740), Vector2(850, -1770), Vector2(720, -1810), Vector2(650, -1890),
	Vector2(700, -1960), Vector2(820, -1990), Vector2(930, -1970), Vector2(980, -1920), Vector2(930, -1880), Vector2(850, -1880)]
const PIECE := 11.2                           # length of each road piece on the winding road

static var MUSEUM_C := Vector2(816.0, -1880.0)

static var _noise_a: FastNoiseLite
static var _noise_b: FastNoiseLite
static var _ready_flag := false
static var path_pts := PackedVector2Array()    # main road centre line every SAMPLE m
static var path_hs := PackedFloat32Array()     # road base height at each (the pieces sit on this)
static var path_s := PackedFloat32Array()      # distance along the main road
static var all_pts := PackedVector2Array()     # every road sample (main + side roads)
static var all_hs := PackedFloat32Array()
static var _grid := {}
static var pads: Array = []                    # [{c, r, h, yaw, spur_from, spur_dir, road_h, s}]
static var sign_h := 0.0
static var museum_h := 0.0

static func _setup() -> void:
	if _ready_flag: return
	_ready_flag = true
	_noise_a = FastNoiseLite.new(); _noise_a.seed = 41; _noise_a.frequency = 0.0042; _noise_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_b = FastNoiseLite.new(); _noise_b.seed = 59; _noise_b.frequency = 0.013; _noise_b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_make_route()
	_make_plots()
	_index_samples()
	_drop_buried()
	sign_h = base(SIGN_C.x, SIGN_C.y) - 2.0
	museum_h = route_h(path_s[path_s.size() - 1])

## Height of the rolling hills before the road, terraces and sign are cut in.
static func base(x: float, z: float) -> float:
	var e := Vector2((x - HC.x) / HR.x, (z - HC.y) / HR.y)
	var l := e.length()
	if l >= 1.0: return 0.0
	var m := 1.0 - smoothstep(0.35, 1.0, l)
	var h := 24.0 + 34.0 * (_noise_a.get_noise_2d(x, z) + 0.3) + 9.0 * _noise_b.get_noise_2d(x, z)
	var dx := (x - CREST.x) / 230.0
	var dz := (z - CREST.y) / 190.0
	h += 62.0 * exp(-(dx * dx + dz * dz) * 0.5)
	return maxf(h, 0.0) * m

static func _slope_at(x: float, z: float) -> float:
	var dx := base(x + 8.0, z) - base(x - 8.0, z)
	var dz := base(x, z + 8.0) - base(x, z - 8.0)
	return Vector2(dx, dz).length() / 16.0

static func route_h(s: float) -> float:
	var f := clampf(s / SAMPLE, 0.0, float(path_hs.size() - 1))
	var i := mini(int(f), path_hs.size() - 2)
	return lerpf(path_hs[i], path_hs[i + 1], f - i)

static func route_grade(s: float, span := 6.0) -> float:
	return (route_h(s + span) - route_h(s - span)) / (2.0 * span)

# ------------------------------------------------------------------ the road

static func _make_route() -> void:
	var dense := PackedVector2Array()
	var n := ROUTE.size()
	for i in range(n - 1):
		var p0: Vector2 = ROUTE[maxi(i - 1, 0)]
		var p1: Vector2 = ROUTE[i]
		var p2: Vector2 = ROUTE[i + 1]
		var p3: Vector2 = ROUTE[mini(i + 2, n - 1)]
		var steps := maxi(8, int(p1.distance_to(p2) / 1.5))
		for k in range(steps):
			var t := float(k) / steps
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	dense.append(ROUTE[n - 1])
	# resample evenly every SAMPLE metres of arc length
	path_pts = PackedVector2Array()
	path_s = PackedFloat32Array()
	path_pts.append(dense[0])
	path_s.append(0.0)
	var acc := 0.0
	var since := 0.0
	for i in range(1, dense.size()):
		var seg := dense[i].distance_to(dense[i - 1])
		acc += seg
		since += seg
		if since >= SAMPLE:
			path_pts.append(dense[i])
			path_s.append(acc)
			since = 0.0
	var raw := PackedFloat32Array()
	raw.resize(path_pts.size())
	for i in range(path_pts.size()): raw[i] = base(path_pts[i].x, path_pts[i].y)
	path_hs = raw.duplicate()
	var lim := MAX_GRADE * SAMPLE
	for it in range(120):
		var nh := path_hs.duplicate()
		for i in range(1, path_pts.size() - 1):
			nh[i] = (path_hs[i - 1] + path_hs[i] * 2.0 + path_hs[i + 1]) * 0.25
		path_hs = nh
		for i in range(1, path_pts.size()): path_hs[i] = clampf(path_hs[i], path_hs[i - 1] - lim, path_hs[i - 1] + lim)
		for i in range(path_pts.size() - 2, -1, -1): path_hs[i] = clampf(path_hs[i], path_hs[i + 1] - lim, path_hs[i + 1] + lim)
		path_hs[0] = 0.0
	var end_dir := (path_pts[path_pts.size() - 1] - path_pts[path_pts.size() - 4]).normalized()
	MUSEUM_C = path_pts[path_pts.size() - 1] + end_dir * MUSEUM_R

## Position and unit tangent of the road at arc length s.
static func route_at(s: float) -> Array:
	var f := clampf(s / SAMPLE, 0.0, float(path_pts.size() - 1))
	var i := mini(int(f), path_pts.size() - 2)
	var p := path_pts[i].lerp(path_pts[i + 1], f - i)
	var j0 := maxi(i - 1, 0)
	var j1 := mini(i + 2, path_pts.size() - 1)
	return [p, (path_pts[j1] - path_pts[j0]).normalized()]

## Houses: at 30 m steps along every leg, both sides, wherever the hill is gentle enough and clear of other roads
## and houses. Each gets a junction on the main road and a short side road to its terrace.
static func _make_plots() -> void:
	pads = []
	var total: float = path_s[path_s.size() - 1]
	var t := 36.0
	while t < total - 45.0:
		var rt := route_at(t)
		var at: Vector2 = rt[0]
		var d: Vector2 = rt[1]
		var h := route_h(t)
		for side in [1.0, -1.0]:
			var nrm := Vector2(-d.y, d.x) * float(side)
			var c := at + nrm * PLOT_DIST
			var ok := BBOX.has_point(c) and base(c.x, c.y) > 8.0 and absf(base(c.x, c.y) - h) < 15.0 and _slope_at(c.x, c.y) < 0.42
			if ok:
				for rr: float in [0.0, 14.0, 24.0]:
					for k in range(8):
						var q: Vector2 = c + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * rr
						if absf(base(q.x, q.y) - h) > 19.0: ok = false
			if ok:
				for pd in pads:
					if (pd.c as Vector2).distance_to(c) < 66.0: ok = false
					if (pd.spur_from as Vector2).distance_to(at) < 40.0: ok = false
			if ok:
				# clear of every other stretch of the road (another switchback), the sign and the forecourt
				for q in path_pts:
					if (q as Vector2).distance_to(c) < 40.0 and (q as Vector2).distance_to(at) > 70.0: ok = false
				if c.distance_to(SIGN_C) < 90.0 or c.distance_to(MUSEUM_C) < 110.0: ok = false
			if ok:
				pads.append({"c": c, "r": 32.0, "h": h + 0.1856 - PLOT_RISE, "yaw": atan2(-nrm.x, -nrm.y), "spur_from": at,
					"spur_dir": nrm, "road_h": h, "s": t, "tan": d})
		t += 24.0

## Removes any plot where the hill still stands higher than the house floor somewhere under the house.
static func _drop_buried() -> void:
	var keep: Array = []
	for pd in pads:
		var top: float = pd.h + PLOT_RISE
		var worst := -1e9
		var c: Vector2 = pd.c
		var yaw: float = pd.yaw
		var f := Vector2(sin(yaw), cos(yaw))
		var r := Vector2(f.y, -f.x)
		for ox in [-13.0, -6.0, 0.0, 6.0, 13.0]:
			for oz in [-14.0, -7.0, 0.0, 7.0, 14.0]:
				var q: Vector2 = c + r * float(ox) + f * float(oz)
				worst = maxf(worst, height(q.x, q.y) - top)
		if worst < 0.25:
			pd["which"] = keep.size() % 2
			keep.append(pd)
	pads = keep
	_index_samples()

static func _index_samples() -> void:
	all_pts = path_pts.duplicate()
	all_hs = path_hs.duplicate()
	for pd in pads:
		var from: Vector2 = pd.spur_from
		var dir: Vector2 = pd.spur_dir
		var n := int(SPUR_LEN / SAMPLE)
		for k in range(1, n + 1):
			var tt := SPUR_LEN * float(k) / n
			all_pts.append(from + dir * tt)
			# type B's drive rises onto the house slab; the ground under it rises with it
			var lift := B_SLAB_RISE * smoothstep(SLAB_EDGE - 9.0, SLAB_EDGE, tt) if int(pd.get("which", 0)) == 1 else 0.0
			all_hs.append(float(pd.road_h) + lift)
	_grid = {}
	for i in range(all_pts.size()):
		var key := Vector2i(int(floor(all_pts[i].x / 24.0)), int(floor(all_pts[i].y / 24.0)))
		if not _grid.has(key): _grid[key] = []
		(_grid[key] as Array).append(i)

static func _road_near(x: float, z: float) -> Vector3:
	var best := 1e9
	var bh := 0.0
	var bi := -1
	var cx := int(floor(x / 24.0))
	var cz := int(floor(z / 24.0))
	for ox in range(-1, 2):
		for oz in range(-1, 2):
			var key := Vector2i(cx + ox, cz + oz)
			if not _grid.has(key): continue
			for i in _grid[key]:
				var d := Vector2(x, z).distance_to(all_pts[i])
				if d < best:
					best = d
					bh = all_hs[i]
					bi = i
	return Vector3(best, bh, bi)

## Terrain height at (x, z) with the road, terraces, forecourt and sign cut in.
static func height(x: float, z: float) -> float:
	if x < BBOX.position.x or x > BBOX.end.x or z < BBOX.position.y or z > BBOX.end.y: return 0.0
	_setup()
	var h := base(x, z)
	var r := _road_near(x, z)
	if r.x < 40.0:
		h = lerpf(h, r.y + 0.04, 1.0 - smoothstep(10.0, 40.0, r.x))
	for p in pads:
		var c: Vector2 = p.c
		var dd := Vector2(x, z).distance_to(c)
		if dd < p.r + 26.0:
			h = lerpf(h, p.h + PLOT_RISE - (B_DROP + 0.6 if int(p.get("which", 0)) == 1 else 0.0), 1.0 - smoothstep(p.r * 0.55, p.r + 26.0, dd))
	if r.x < 12.0:
		h = lerpf(h, r.y + 0.02, 1.0 - smoothstep(10.0, 17.0, r.x))
	var md := Vector2(x, z).distance_to(MUSEUM_C)
	if md < MUSEUM_R + 40.0:
		h = lerpf(h, museum_h - 0.12, 1.0 - smoothstep(MUSEUM_R, MUSEUM_R + 40.0, md))
	var q := (Vector2(x, z) - SIGN_C).abs() - SIGN_HALF
	var sd := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	if sd < 22.0:
		h = lerpf(h, sign_h, 1.0 - smoothstep(0.0, 22.0, sd))
	return h

## Pad data for the terrain shader's paved floors (see terrain.gdshader).
static func pave_data() -> PackedVector4Array:
	var out := PackedVector4Array()
	for pd in pads:
		if int(pd.which) != 0: continue          # only the white villas' fenced gardens are paved
		var c: Vector2 = pd.c
		out.append(Vector4(c.x, c.y, float(pd.yaw), 0.0))
	while out.size() < 16: out.append(Vector4(0, 0, 0, 0))
	return out

## 0..1: how "hill" a place is (drives the dry-grass and rock colouring in the terrain shader).
static func mask(x: float, z: float) -> float:
	var e := Vector2((x - HC.x) / HR.x, (z - HC.y) / HR.y)
	return 1.0 - smoothstep(0.55, 1.1, e.length())

static func in_bbox(rect: Rect2) -> bool:
	return BBOX.intersects(rect)

# ------------------------------------------------------------------ building it

const VILLA := "res://assets/hills/modern_luxury_villa_house_building.glb"
const VILLA_POOL := "res://assets/hills/modern_luxury_villa_house_building_with_pool.glb"
const CYPRESS := "res://assets/hills/cypress_tree.glb"

static func build(w: World) -> void:
	_setup()
	var t0 := Time.get_ticks_msec()
	var body := StaticBody3D.new()
	body.name = "Renowood"
	body.collision_layer = 1
	w.static_root.add_child(body)
	_road(w, body)
	_houses(w, body)
	_trees(w, body)
	_canopy(w, body)
	_ground_cover(w, body)
	_sign(w, body)
	_museum_site(w, body)
	w.add_poi("city", "RENOWOOD", Vector3(CREST.x, 0.0, CREST.y + 120.0))
	print("renowood: %d road samples, %d houses (%d ms) museum c=%s h=%.1f end=%s" % [all_pts.size(), pads.size(), Time.get_ticks_msec() - t0, MUSEUM_C, museum_h, ROUTE[ROUTE.size() - 1]])

static func _normal_for(g: Vector2) -> Vector3:
	return Vector3(-g.x, 1.0, -g.y).normalized()

## Lays the road kit along the curve: a crossroad wherever a side road leaves, short straight pieces between (each turned
## a few degrees from the last, slightly overlapping, with an asphalt strip under them so no sliver of ground shows),
## each piece tilted to the slope. Side roads and the lamps are added the same way.
static func _road(w: World, body: StaticBody3D) -> void:
	RoadKit._load()
	RoadKit._mats(w)
	var cross := RoadKit._find("Crossroad")
	var straight := RoadKit._find("Road_33")
	var total: float = path_s[path_s.size() - 1]
	var pave := w._mat("res://assets/roads/pavement.png", 0.18, Color(1.05, 1.03, 1.0))
	var plain := RoadKit._plain_mat
	# main road: one continuous surface from end to end, with its kerbs
	_strip(w, body, 0.0, total, -4.25, 4.25, 0.19 + ROAD_RISE, RoadKit._road_mat, true)
	_strip(w, body, 0.0, total, -5.85, -4.25, 0.215 + ROAD_RISE, pave, true, true)
	_strip(w, body, 0.0, total, 4.25, 5.85, 0.215 + ROAD_RISE, pave, true, true)
	# side roads: plain asphalt from the main road's edge to the house, flush with it, with a rounded flare at the mouth
	for pd in pads:
		_spur_road(w, body, pd, plain, pave)
	var stops: Array = []
	for pd in pads: stops.append({"s": pd.s, "pad": pd})
	var side := 1.0
	var s2 := 40.0
	while s2 < total - 20.0:
		var rt2 := route_at(s2)
		var pp: Vector2 = rt2[0]
		var dd: Vector2 = rt2[1]
		var nrm := Vector2(-dd.y, dd.x) * side
		var near_stop := false
		for st in stops:
			if st.has("pad") and absf(float(st.s) - s2) < 14.0: near_stop = true
		if not near_stop:
			RoadKit.lamp_at(w, body, pp + nrm * 5.3, pp + nrm * 2.0, route_h(s2) + 0.04)
			side = -side
		s2 += 44.8

## A vertical skirt hanging from the edge of a strip down below the ground, so the road never looks like it floats.
static func _skirt(w: World, pts: Array, _mat: Material) -> void:
	if pts.size() < 2: return
	var mat: Material = w._mat("res://assets/textures/y2k_grass.png", 0.12, Color(0.55, 0.62, 0.42))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var run := 0.0
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		if i > 0: run += p.distance_to(pts[i - 1])
		verts.append(p)
		verts.append(p - Vector3(0, 0.5, 0))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		uvs.append(Vector2(run * 0.2, 0.0))
		uvs.append(Vector2(run * 0.2, 0.3))
	for i in range(pts.size() - 1):
		var a := i * 2
		idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3, a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

## One smooth strip of surface along the curve from arc length s_a to s_b, between lateral offsets o0 and o1.
static func _strip(w: World, body: StaticBody3D, s_a: float, s_b: float, o0: float, o1: float, lift: float, mat: Material, collide: bool, skirts := false) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := maxi(2, int(ceil((s_b - s_a) / 2.0)))
	var edge_a: Array = []
	var edge_b: Array = []
	for i in range(n + 1):
		var sv := s_a + (s_b - s_a) * float(i) / n
		var rt := route_at(sv)
		var p: Vector2 = rt[0]
		var d: Vector2 = rt[1]
		var nrm := Vector2(-d.y, d.x)
		var h := route_h(sv)
		for o in [o0, o1]:
			var q: Vector2 = p + nrm * float(o)
			verts.append(Vector3(q.x, h + lift, q.y))
			(edge_a if o == o0 else edge_b).append(Vector3(q.x, h + lift, q.y))
			norms.append(Vector3.UP)
			uvs.append(Vector2((float(o) - o0) / (o1 - o0), sv / 22.4))
	for i in range(n):
		var a := i * 2
		idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)
	if skirts:
		_skirt(w, edge_a, mat)
		_skirt(w, edge_b, mat)
	if collide:
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)

## A plain asphalt strip just under the road pieces along the whole curve, hiding the thin wedges between pieces.
static func _underlay(w: World, total: float) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := path_pts.size()
	for i in range(n):
		var rt := route_at(path_s[i])
		var p: Vector2 = rt[0]
		var d: Vector2 = rt[1]
		var nrm := Vector2(-d.y, d.x)
		for o in [-5.6, 5.6]:
			var q: Vector2 = p + nrm * float(o)
			verts.append(Vector3(q.x, path_hs[i] + 0.15, q.y))
			norms.append(Vector3.UP)
			uvs.append(Vector2(float(o) * 0.1, path_s[i] * 0.1))
	for i in range(n - 1):
		var a := i * 2
		idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = RoadKit._plain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

## The two rounded corners where a side road meets the main road: a fan of asphalt between the arc and the corner.
static func _fillets(w: World, pd: Dictionary, plain: Material) -> void:
	var from: Vector2 = pd.spur_from
	var dir: Vector2 = pd.spur_dir
	var tan: Vector2 = pd.tan
	var h: float = pd.road_h
	var R := 7.0
	var edge := 4.25
	var half := 3.4
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for sg in [-1.0, 1.0]:
		# local frame: u along the main road, v along the side road
		var pts: Array = [Vector2(sg * half, edge)]
		pts.append(Vector2(sg * half, edge + R))
		for k in range(1, 10):
			var a := PI * 0.5 * float(k) / 10.0
			pts.append(Vector2(sg * (half + R) - sg * R * cos(a), edge + R - R * sin(a)) if false else Vector2(sg * (half + R - R * cos(a)), edge + R - R * sin(a)))
		pts.append(Vector2(sg * (half + R), edge))
		var base_i := verts.size()
		for q in pts:
			var wp: Vector2 = from + tan * (q as Vector2).x + dir * (q as Vector2).y
			verts.append(Vector3(wp.x, h + 0.214 + ROAD_RISE, wp.y))
			norms.append(Vector3.UP)
			uvs.append(Vector2(wp.x * 0.15, wp.y * 0.15))
		for k in range(1, pts.size() - 1):
			# both windings, so the fan is visible from above whichever way it was wound
			idx.append_array(PackedInt32Array([base_i, base_i + k + 1, base_i + k, base_i, base_i + k, base_i + k + 1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = plain
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

## A trimmed lawn round the house on its terrace: bright grass with a low stone edge.
static func _lawn(w: World, body: StaticBody3D, pd: Dictionary) -> void:
	var c: Vector2 = pd.c
	var y: float = float(pd.h) + PLOT_RISE + 0.012 - (B_DROP + 0.25 if int(pd.which) == 1 else 0.0)
	var lawn_mat: StandardMaterial3D = w._mat("res://assets/textures/y2k_grass.png", 0.2, Color(0.72, 1.0, 0.58))
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 30.0
	cm.bottom_radius = 30.0
	cm.height = 0.02
	cm.radial_segments = 48
	mi.mesh = cm
	mi.material_override = lawn_mat
	mi.position = Vector3(c.x, y, c.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)
	var edge := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 30.0
	tm.outer_radius = 30.7
	tm.rings = 48
	tm.ring_segments = 4
	edge.mesh = tm
	edge.scale = Vector3(1, 0.12, 1)
	edge.material_override = w._mat("res://assets/roads/pavement.png", 0.25, Color(0.95, 0.95, 0.92))
	edge.position = Vector3(c.x, y, c.y)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(edge)
	# hedges are left to the cypress trees; the terrace edge is kept clear

const SPUR_A := 31.0                          # type A (white villa): the drive stops at its fence
const B_SLAB_RISE := 0.15                     # how far the brick villa's slab top stands above the drive
const SLAB_EDGE := 28.5                       # distance from the main road to the brick villa's slab border
const B_DROP := 0.28                          # type B (brick villa) sits this much lower so its slab is level with the drive

static func _spur_road(w: World, body: StaticBody3D, pd: Dictionary, plain: Material, pave: Material) -> void:
	_fillets(w, pd, plain)
	# (no lawn disc: the garden inside the type A fence gets its own props instead)
	var from: Vector2 = pd.spur_from
	var dir: Vector2 = pd.spur_dir
	var nrm := Vector2(-dir.y, dir.x)
	var h: float = pd.road_h
	var L: float = SPUR_A if int(pd.which) == 0 else SLAB_EDGE + 0.15
	for part in [[-3.4, 3.4, 0.213 + ROAD_RISE, plain], [-5.0, -3.4, 0.23 + ROAD_RISE, pave], [3.4, 5.0, 0.23 + ROAD_RISE, pave]]:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var n := 16
		var e0: Array = []
		var e1: Array = []
		for i in range(n + 1):
			var t := 4.6 + (L - 4.6) * float(i) / n
			# the mouth flares out a little so the junction has rounded corners
			var flare := 1.0
			if part[3] == plain:
				flare = 1.0 + 0.7 * smoothstep(L - 10.0, L - 2.0, t)
			for o in [part[0], part[1]]:
				var q: Vector2 = from + dir * t + nrm * float(o) * flare
				# type B: the drive rises to the height of the house's own slab and stops exactly at its border, so the two join flush
				var rise := B_SLAB_RISE * smoothstep(SLAB_EDGE - 9.0, SLAB_EDGE, t) if int(pd.which) == 1 else -0.03 * smoothstep(L - 9.0, L - 1.0, t)
				verts.append(Vector3(q.x, h + float(part[2]) + rise, q.y))
				(e0 if o == part[0] else e1).append(Vector3(q.x, h + float(part[2]) + rise, q.y))
				norms.append(Vector3.UP)
				uvs.append(Vector2(float(o) * 0.15, t * 0.15))
		for i in range(n):
			var a := i * 2
			idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = part[3]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mi)
		if part[3] == pave:
			_skirt(w, e0 if part[0] < 0.0 else e1, pave)
		else:
			_skirt(w, e1 if false else [], pave)
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)

static func _spur(w: World, body: StaticBody3D, straight: Dictionary, p: Vector2, dir: Vector2, h: float) -> void:
	var cut := RoadKit.CROSS_W * 0.5
	var run := SPUR_LEN - cut
	var c := p + dir * (cut + run * 0.5)
	RoadKit._put(w, body, straight, Vector3(c.x, h, c.y), atan2(dir.x, dir.y), run / RoadKit.STRAIGHT_L)

static func _group(path: String, skip: Array = []) -> Dictionary:
	var parts := CoastProps._parts(path)
	if not skip.is_empty():
		parts = parts.filter(func(p: Dictionary) -> bool: return not skip.has(p.name))
	var g := CoastProps._group(parts, func(_n: String) -> bool: return true)
	var box := AABB()
	var first := true
	for p in parts:
		box = p.aabb if first else box.merge(p.aabb)
		first = false
	g["box"] = box
	g["raw"] = parts
	return g

## Exact (triangle) collision for a whole villa in its own foot-centred space, built once per model and shared by every
## copy: walls, floors and stairs are solid, but doorways and windows that are open in the model stay open, so the player
## can walk inside.
static func _shape_for(g: Dictionary) -> ConcavePolygonShape3D:
	var box: AABB = g.box
	var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var faces := PackedVector3Array()
	for part in g.raw:
		var xf := Transform3D(Basis.IDENTITY, -foot) * (part.xf as Transform3D)
		var sz: Vector3 = (part.aabb as AABB).size
		if sz.length() < 0.5: continue
		for v in (part.mesh as Mesh).get_faces():
			faces.append(xf * v)
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(faces)
	return sh

static func _houses(w: World, body: StaticBody3D) -> void:
	var models: Array = [_group(VILLA), _group(VILLA_POOL)]
	var shapes: Array = [_shape_for(models[0]), _shape_for(models[1])]
	# each villa model is baked into one mesh (a surface per material): the originals are hundreds of loose pieces,
	# which would cost hundreds of draw calls per house
	var meshes: Array = []
	for k in range(2):
		var bx: AABB = (models[k] as Dictionary).box
		var vm: Mesh = _baked(VILLA if k == 0 else VILLA_POOL, bx.size.y, [], true).mesh
		CityLights.apply(vm, "glass", 1.0)
		meshes.append(vm)
	for pi in range(pads.size()):
		var p: Dictionary = pads[pi]
		var which: int = p.which
		var c: Vector2 = p.c
		var yaw: float = p.yaw + (0.0 if which == 0 else PI)
		var base_t := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, p.h - 0.05 + RISE + (HOUSE_LIFT_ALL + HOUSE_LIFT if which == 0 else -B_DROP), c.y))
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[which]
		mi.transform = base_t
		mi.visibility_range_end = 900.0
		w.static_root.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = shapes[which]
		cs.transform = base_t
		body.add_child(cs)
	_gardens(w, body)
	for pd in pads:
		if int(pd.which) == 1: _fence_b(w, body, pd)

## A steel-and-timber garden fence round the brick villa's plot: posts, rails and vertical slats, a stone corner pier at each
## corner, and a gate gap where the drive comes in. Solid.
static func _fence_b(w: World, body: StaticBody3D, pd: Dictionary) -> void:
	var c: Vector2 = pd.c
	var yaw: float = pd.yaw
	var rot := Basis(Vector3.UP, yaw)
	var y: float = float(pd.road_h) + 0.37 + RISE
	var hx := 17.1
	var hz := 17.3
	var steel := w._flat(Color("#2d3036"))
	var wood := w._mat("res://assets/airport/tex/Concrete034.jpg", 0.3, Color(0.78, 0.74, 0.68))
	var stone := w._mat("res://assets/roads/pavement.png", 0.25, Color(0.85, 0.85, 0.82))
	var add := func(lx: float, lz: float, sx: float, sy: float, sz: float, mat: Material, collide: bool) -> void:
		var v := rot * Vector3(lx, 0.0, lz)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sx, sy, sz)
		mi.mesh = bm
		mi.material_override = mat
		mi.transform = Transform3D(rot, Vector3(c.x + v.x, y + sy * 0.5, c.y + v.z))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mi)
		if collide:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = bm.size
			cs.shape = bs
			cs.transform = mi.transform
			body.add_child(cs)
	# four sides: panels of slats between posts every 2.4 m, the front side (+Z) opens for the drive
	var sides: Array = [[0.0, hz, true], [0.0, -hz, true], [hx, 0.0, false], [-hx, 0.0, false]]
	for sd in sides:
		var along_x: bool = sd[2]
		var length := hx * 2.0 if along_x else hz * 2.0
		var n := int(round(length / 2.4))
		for k in range(n + 1):
			var t := -length * 0.5 + length * float(k) / n
			var lx: float = (t if along_x else float(sd[0]))
			var lz: float = (float(sd[1]) if along_x else t)
			if along_x and float(sd[1]) > 0.0 and absf(t) < 3.4: continue       # gate gap
			add.call(lx, lz, 0.16, 1.5, 0.16, steel, false)
			if k < n:
				var mid := t + length / n * 0.5
				if along_x and float(sd[1]) > 0.0 and absf(mid) < 3.4: continue
				var mx: float = (mid if along_x else float(sd[0]))
				var mz: float = (float(sd[1]) if along_x else mid)
				var seg := length / n - 0.16
				# top and bottom rails
				add.call(mx, mz, seg if along_x else 0.1, 0.07, 0.1 if along_x else seg, steel, false)
				# slats
				var ns := 9
				for q in range(ns):
					var off := -seg * 0.5 + seg * (float(q) + 0.5) / ns
					add.call(mx + (off if along_x else 0.0), mz + (0.0 if along_x else off), 0.06 if along_x else 0.05, 1.25, 0.05 if along_x else 0.06, wood, false)
				# one solid collision box for the whole panel
				var v := rot * Vector3(mx, 0.0, mz)
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(seg if along_x else 0.3, 1.5, 0.3 if along_x else seg)
				cs.shape = bs
				cs.transform = Transform3D(rot, Vector3(c.x + v.x, y + 0.75, c.y + v.z))
				body.add_child(cs)
	# corner piers and gate piers
	for cx in [-hx, hx]:
		for cz in [-hz, hz]:
			add.call(cx, cz, 0.55, 1.9, 0.55, stone, true)
	for gx in [-3.4, 3.4]:
		add.call(gx, hz, 0.55, 1.9, 0.55, stone, true)

const GARDEN := "res://assets/garden/"

## Inside each type A fence: a trimmed hedge round the sides and back, flower urns by the front steps, garden chairs and
## daisy / sunflower bushes along the fence. Everything is placed in the house's own frame (+Z towards the road).
static func _gardens(w: World, body: StaticBody3D) -> void:
	var hedge := _group(GARDEN + "hedge.glb")
	var urn := _group(GARDEN + "garden_urn.glb")
	var chair := _group(GARDEN + "monobloc_plastic_garden_chair.glb")
	var bush := _group(GARDEN + "bush_daisies_sunflower.glb")
	var batches := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var models: Array = [_group(VILLA), _group(VILLA_POOL)]
	var box: AABB = (models[0] as Dictionary).box
	var hx := box.size.x * 0.5 - 1.3          # inside the fence
	var hz := box.size.z * 0.5 - 1.3
	var count := 0
	for pd in pads:
		if int(pd.which) != 0: continue
		var c: Vector2 = pd.c
		var yaw: float = pd.yaw
		var gy: float = float(pd.h) - 0.05 + RISE + HOUSE_LIFT_ALL + HOUSE_LIFT + 0.02
		var rot := Basis(Vector3.UP, yaw)
		var at := func(lx: float, lz: float) -> Vector3:
			var v := rot * Vector3(lx, 0.0, lz)
			return Vector3(c.x + v.x, gy, c.y + v.z)
		# hedge: sides and back, 5 m panels
		var hs := 5.0 / 11.37
		for side in [-1.0, 1.0]:
			var z := -hz + 2.5
			while z < hz - 6.0:
				var t := Transform3D(rot * Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(hs, hs * 0.6, hs)), at.call(side * hx, z))
				CoastProps._place(batches, "hedge", hedge, t)
				z += 5.0
		var x := -hx + 2.5
		while x < hx - 1.0:
			var t2 := Transform3D(rot * Basis.from_scale(Vector3(hs, hs * 0.6, hs)), at.call(x, -hz))
			CoastProps._place(batches, "hedge", hedge, t2)
			x += 5.0
		# urns on each side of the front steps, chairs on the side patio
		var us := 1.0 / 117.0
		for ux in [-3.6, 3.6]:
			CoastProps._place(batches, "urn", urn, Transform3D(rot * Basis.from_scale(Vector3.ONE * us), at.call(ux, hz - 3.5)))
		CoastProps._place(batches, "chair", chair, Transform3D(rot * Basis(Vector3.UP, 2.4), at.call(-hx + 3.0, hz - 5.5)))
		CoastProps._place(batches, "chair", chair, Transform3D(rot * Basis(Vector3.UP, 3.9), at.call(-hx + 3.0, hz - 7.7)))
		# bushes along the inside of the hedge
		var bs := 1.1 / 540.0
		for k in range(10):
			var lx := rng.randf_range(-hx + 1.8, hx - 1.8)
			var lz := -hz + 1.8 if k % 2 == 0 else hz - 1.6
			if k % 5 == 4: lx = -hx + 1.8 if k < 5 else hx - 1.8; lz = rng.randf_range(-hz + 3.0, hz - 3.0)
			CoastProps._place(batches, "bush", bush, Transform3D(rot * Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * bs * rng.randf_range(0.8, 1.3)), at.call(lx, lz)))
		count += 1
	CoastProps._flush(w, batches, false)

const PLANTS := "res://assets/plants/"

## Grass, flowers, ferns, dead bushes and rocks over the hills. Every kind is baked once (with level-of-detail), then
## scattered in 64 m blocks that are only drawn within ~80 m of the camera, so thousands of tufts stay cheap.
static func _ground_cover(w: World, body: StaticBody3D) -> void:
	var G := PLANTS + "grass_pack_lowpoly_game-ready.glb"
	var kinds := {}
	kinds["fresh"] = _baked(G, 0.55, [], false, "Grass main fresh")
	kinds["aged"] = _baked(G, 0.6, [], false, "Grass main aged")
	kinds["dryg"] = _baked(G, 0.6, [], false, "Grass main dry")
	kinds["tall"] = _baked(G, 1.05, [], false, "Grass tall high")
	kinds["tall_low"] = _baked(G, 0.8, [], false, "Grass tall low")
	kinds["clump"] = _baked(PLANTS + "dry_grass.glb", 0.95)
	kinds["dandelion"] = _baked(PLANTS + "undergrowth_pack_lowpoly_game-ready.glb", 0.3, [], false, "Dandelion")
	kinds["lactuca"] = _baked(PLANTS + "undergrowth_pack_lowpoly_game-ready.glb", 0.55, [], false, "Lactuca")
	kinds["plantain"] = _baked(PLANTS + "undergrowth_pack_lowpoly_game-ready.glb", 0.4, [], false, "Plantain")
	kinds["fern1"] = _baked(PLANTS + "some_foliage.glb", 0.85, [], false, "SM_Fern_01")
	kinds["fern2"] = _baked(PLANTS + "some_foliage.glb", 0.8, [], false, "SM_Fern_02")
	kinds["dead"] = _baked(PLANTS + "some_foliage.glb", 1.0, [], false, "SM_DeadBush_01|SM_DeadBush_02")
	kinds["wgrass"] = _baked(PLANTS + "some_foliage.glb", 0.9, [], false, "SM_Grass_02|SM_Grass_03|SM_Grass_04")
	kinds["wgrass2"] = _baked(PLANTS + "some_foliage.glb", 0.7, [], false, "SM_Grass_06|SM_Grass_05")
	var rocks: Array = []
	for rn in ["Object_4", "Object_12", "Object_22", "Object_20", "Object_10", "Object_6"]:
		rocks.append(_baked(PLANTS + "free_rock_assets_pack.glb", 1.0, [], false, rn))
	var lists := {}
	for k in kinds: lists[k] = []
	var rlist: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var bigrock := 0
	var step := 3.4
	var x := BBOX.position.x
	var placed := 0
	while x < BBOX.end.x:
		var z := BBOX.position.y
		while z < BBOX.end.y:
			var jx := x + rng.randf_range(-step, step) * 0.5
			var jz := z + rng.randf_range(-step, step) * 0.5
			z += step
			if Coast.inland(jx, jz) < 70.0: continue
			var m := mask(jx, jz)
			if m < 0.15: continue
			var road_d := _road_near(jx, jz).x
			if road_d < 9.5: continue
			var skip_pad := false
			for p in pads:
				if (p.c as Vector2).distance_to(Vector2(jx, jz)) < 33.0: skip_pad = true
			if skip_pad or Vector2(jx, jz).distance_to(MUSEUM_C) < 40.0: continue
			if absf(jx - SIGN_C.x) < SIGN_HALF.x + 24.0 and absf(jz - SIGN_C.y) < 40.0: continue
			var slope := _slope_at(jx, jz)
			if slope > 0.6: continue
			var y := height(jx, jz)
			var patch := _noise_b.get_noise_2d(jx * 1.3 + 31.0, jz * 1.3)          # large soft patches of species
			var flow := _noise_a.get_noise_2d(jx * 2.7 + 900.0, jz * 2.7)
			var dry := slope > 0.22 or patch < -0.12
			var r := rng.randf()
			var kind := ""
			if slope > 0.3:
				# the bare brown slopes: dry tufts and rocks
				if r < 0.28: kind = "clump"
				elif r < 0.45: kind = "dryg"
				elif r < 0.52: kind = "dead"
				elif r < 0.58 and rlist.size() < 420:
					var rk: int = rng.randi() % rocks.size()
					var rs := rng.randf_range(0.9, 2.8)
					var rt := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)) * Basis.from_scale(Vector3(rs, rs * rng.randf_range(0.6, 1.0), rs)), Vector3(jx, y - 0.15 * rs, jz))
					(rlist as Array).append([rk, rt])
					if rs > 1.8 and bigrock < 60:
						CoastProps._box(body, Vector3(rs * 1.1, rs * 0.7, rs * 1.1), Vector3(jx, y + rs * 0.25, jz))
						bigrock += 1
					continue
				else: continue
			elif dry:
				if r < 0.34: kind = "clump"
				elif r < 0.58: kind = "dryg"
				elif r < 0.7: kind = "tall_low"
				elif r < 0.78: kind = "aged"
				elif r < 0.81: kind = "dead"
				else: continue
			else:
				if r < 0.3: kind = "fresh"
				elif r < 0.5: kind = "tall"
				elif r < 0.62: kind = "wgrass" if rng.randf() < 0.6 else "wgrass2"
				elif r < 0.68 and flow > 0.05: kind = "dandelion"
				elif r < 0.73 and flow > -0.1: kind = "lactuca"
				elif r < 0.77: kind = "plantain"
				elif r < 0.81 and patch > 0.15: kind = "fern1" if rng.randf() < 0.5 else "fern2"
				elif r < 0.9: kind = "aged"
				else: continue
			var sc := rng.randf_range(0.85, 1.55)
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc * rng.randf_range(0.85, 1.25), sc)), Vector3(jx, y - 0.04, jz))
			(lists[kind] as Array).append(t)
			placed += 1
		x += step
	for k in kinds:
		_emit_blocks(w, kinds[k].mesh, lists[k], 64.0, 85.0)
	# rocks, grouped by variant
	var by_rock: Array = []
	for i in range(rocks.size()): by_rock.append([])
	for e in rlist: (by_rock[e[0]] as Array).append(e[1])
	for i in range(rocks.size()): _emit_blocks(w, rocks[i].mesh, by_rock[i], 128.0, 220.0)
	print("ground cover: %d tufts, %d rocks" % [placed, rlist.size()])

## Like _emit but with a given block size and view distance.
static func _emit_blocks(w: World, mesh: Mesh, xfs: Array, block: float, range_end: float) -> void:
	if xfs.is_empty(): return
	var blocks := {}
	for t in xfs:
		var o: Vector3 = (t as Transform3D).origin
		var key := Vector2i(int(floor(o.x / block)), int(floor(o.z / block)))
		if not blocks.has(key): blocks[key] = []
		(blocks[key] as Array).append(t)
	for key in blocks:
		var list: Array = blocks[key]
		var centre := Vector3((key.x + 0.5) * block, 0.0, (key.y + 0.5) * block)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in range(list.size()):
			var tt: Transform3D = list[i]
			tt.origin -= centre
			mm.set_instance_transform(i, tt)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = centre
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = range_end
		mmi.custom_aabb = AABB(Vector3(-block, -20, -block), Vector3(block * 2.0, 160, block * 2.0))
		w.static_root.add_child(mmi)

const TREES := "res://assets/trees/"

## All parts of a model baked into one mesh (one surface per material) standing on the origin, scaled to a target height.
## Models made of thousands of loose leaf cards would otherwise cost one draw call per card.
static func _baked(path: String, target_h: float, skip: Array = [], keep_flat := false, only := "", scale := 0.0) -> Dictionary:
	var parts := CoastProps._parts(path)
	if only != "":
		parts = parts.filter(func(p: Dictionary) -> bool:
			for pre in only.split("|"):
				if String(p.name).begins_with(pre): return true
			return false)
	var keep: Array = []
	var box := AABB()
	var first := true
	for p in parts:
		var sz: Vector3 = (p.aabb as AABB).size
		if skip.has(p.name) or (not keep_flat and sz.y < 0.0001 * maxf(sz.x, 1.0) and sz.x > 0.0): continue
		keep.append(p)
		box = p.aabb if first else box.merge(p.aabb)
		first = false
	var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var sc := scale if scale > 0.0 else target_h / maxf(box.size.y, 0.0001)
	var xf0 := Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -foot)
	var accum := {}
	for p in keep:
		var m: Mesh = p.mesh
		var xf: Transform3D = xf0 * (p.xf as Transform3D)
		for si in range(m.get_surface_count()):
			if m.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES: continue
			var mat := m.surface_get_material(si)
			var key := mat.get_instance_id() if mat != null else 0
			if not accum.has(key):
				accum[key] = {"mat": mat, "v": [], "n": [], "u": [], "i": []}
			var a := m.surface_get_arrays(si)
			var vv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nn = a[Mesh.ARRAY_NORMAL]
			var uu = a[Mesh.ARRAY_TEX_UV]
			var ii = a[Mesh.ARRAY_INDEX]
			var acc: Dictionary = accum[key]
			var base_i: int = (acc.v as Array).size()
			for k in range(vv.size()):
				(acc.v as Array).append(xf * vv[k])
				(acc.n as Array).append((xf.basis * (nn[k] if nn != null and nn.size() > k else Vector3.UP)).normalized())
				(acc.u as Array).append(uu[k] if uu != null and uu.size() > k else Vector2.ZERO)
			if ii == null or ii.is_empty():
				for k in range(vv.size()): (acc.i as Array).append(base_i + k)
			else:
				for k in ii: (acc.i as Array).append(base_i + k)
	# built through an ImporterMesh so the engine generates level-of-detail versions (far trees draw with a fraction of the
	# triangles, exactly as an imported model would)
	var imp := ImporterMesh.new()
	for key in accum:
		var acc: Dictionary = accum[key]
		if (acc.v as Array).is_empty() or (acc.i as Array).size() < 3: continue
		while (acc.i as Array).size() % 3 != 0: (acc.i as Array).pop_back()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(acc.v)
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(acc.n)
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(acc.u)
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array(acc.i)
		imp.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, acc.mat)
	imp.generate_lods(25.0, 60.0, [])
	var out := imp.get_mesh()
	var h := target_h
	return {"mesh": out, "h": h, "w": maxf(box.size.x, box.size.z) * sc, "size": box.size * sc}

## Big shade trees over the hill: oaks and maples in clumps, jacarandas lining the road, all baked to a few draw calls.
static func _canopy(w: World, body: StaticBody3D) -> void:
	var kinds: Array = [
		{"name": "oaks", "d": _baked(TREES + "oak_trees.glb", 13.0), "share": 0.2},
		{"name": "oak", "d": _baked(TREES + "oak_tree.glb", 14.0), "share": 0.34},
		{"name": "maple", "d": _baked(TREES + "maple_tree.glb", 11.0, ["Material22069", "Material22070"]), "share": 0.3},
	]
	# road-side trees: the hill's own trees (oak, maple, cypress), not palms
	var side_meshes: Array = [kinds[1].d.mesh, kinds[2].d.mesh, _baked(CYPRESS, 7.5, ["Object_50", "Object_52", "Object_54", "Object_56", "Object_58", "Object_60", "Object_62", "Object_33", "Object_35", "Object_37", "Object_39", "Object_41", "Object_43", "Object_45", "Object_47", "Object_65"]).mesh]
	var mms := {}
	for k in kinds: mms[k.name] = []
	mms["jac"] = [[], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var count := 0
	var x := BBOX.position.x
	while x < BBOX.end.x:
		var z := BBOX.position.y
		while z < BBOX.end.y:
			var jx := x + rng.randf_range(-12.0, 12.0)
			var jz := z + rng.randf_range(-12.0, 12.0)
			z += 24.0
			if Coast.inland(jx, jz) < 110.0: continue
			var m := mask(jx, jz)
			if m < 0.3: continue
			var clump := smoothstep(-0.35, 0.25, _noise_b.get_noise_2d(jx * 1.7 + 77.0, jz * 1.7))
			if rng.randf() > 0.95 * m * clump: continue
			if _road_near(jx, jz).x < 15.0: continue
			var near := false
			for p in pads:
				if (p.c as Vector2).distance_to(Vector2(jx, jz)) < 34.0: near = true
			if near or Vector2(jx, jz).distance_to(MUSEUM_C) < 80.0: continue
			if absf(jx - SIGN_C.x) < SIGN_HALF.x + 30.0 and absf(jz - SIGN_C.y) < 60.0: continue
			if _slope_at(jx, jz) > 0.5: continue
			var roll := rng.randf()
			var pick: Dictionary = kinds[0]
			var acc := 0.0
			for kd in kinds:
				acc += float(kd.share)
				if roll < acc / 0.84:
					pick = kd
					break
			var sc := rng.randf_range(0.8, 1.25)
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * sc), Vector3(jx, height(jx, jz) - 0.15, jz))
			(mms[pick.name] as Array).append(t)
			count += 1
			if count % 2 == 0: CoastProps._box(body, Vector3(1.0, 6.0, 1.0), Vector3(jx, height(jx, jz) + 3.0, jz))
		x += 24.0
	# hill trees along the road, one every ~46 m on alternating sides, set back from the pavement
	var total: float = path_s[path_s.size() - 1]
	var s2 := 30.0
	var side := 1.0
	while s2 < total - 25.0:
		var rt := route_at(s2)
		var p: Vector2 = rt[0]
		var d: Vector2 = rt[1]
		var q := p + Vector2(-d.y, d.x) * side * 11.0
		var ok := _road_near(q.x, q.y).x > 8.0
		for pd in pads:
			if (pd.c as Vector2).distance_to(q) < 30.0 or (pd.spur_from as Vector2).distance_to(q) < 16.0: ok = false
		if ok:
			var t2 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.85, 1.15)), Vector3(q.x, height(q.x, q.y) - 0.1, q.y))
			((mms["jac"] as Array)[rng.randi() % 3] as Array).append(t2)
			CoastProps._box(body, Vector3(0.7, 5.0, 0.7), Vector3(q.x, height(q.x, q.y) + 2.5, q.y))
		side = -side
		s2 += 46.0
	var skip := OS.get_cmdline_user_args()
	for k in kinds:
		if not ("--skip=" + String(k.name)) in skip: _emit(w, k.d.mesh, mms[k.name])
	if not "--skip=jac" in skip:
		for pi in range(3): _emit(w, side_meshes[pi], (mms["jac"] as Array)[pi], 260.0)
	if "--skip=cyp" in skip: pass
	print("canopy: %d hill trees + road-side trees" % count)

## One multimesh per 200 m block, each placed at the block's own centre so it can be hidden by distance (a visibility
## range is measured from the node's origin, so a single huge multimesh could not be culled).
static func _emit(w: World, mesh: Mesh, xfs: Array, range_end := 260.0) -> void:
	if xfs.is_empty(): return
	var blocks := {}
	for t in xfs:
		var o: Vector3 = (t as Transform3D).origin
		var key := Vector2i(int(floor(o.x / 200.0)), int(floor(o.z / 200.0)))
		if not blocks.has(key): blocks[key] = []
		(blocks[key] as Array).append(t)
	for key in blocks:
		var list: Array = blocks[key]
		var centre := Vector3((key.x + 0.5) * 200.0, 0.0, (key.y + 0.5) * 200.0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in range(list.size()):
			var tt: Transform3D = list[i]
			tt.origin -= centre
			mm.set_instance_transform(i, tt)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = centre
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = range_end
		mmi.custom_aabb = AABB(Vector3(-140, -10, -140), Vector3(280, 120, 280))
		w.static_root.add_child(mmi)

static func _trees(w: World, body: StaticBody3D) -> void:
	var cy := _group(CYPRESS, ["Object_50", "Object_52", "Object_54", "Object_56", "Object_58", "Object_60", "Object_62", "Object_33", "Object_35", "Object_37", "Object_39", "Object_41", "Object_43", "Object_45", "Object_47", "Object_65"])
	var batches := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var count := 0
	var x := BBOX.position.x
	while x < BBOX.end.x:
		var z := BBOX.position.y
		while z < BBOX.end.y:
			var jx := x + rng.randf_range(-9.0, 9.0)
			var jz := z + rng.randf_range(-9.0, 9.0)
			z += 18.0
			if Coast.inland(jx, jz) < 100.0: continue
			var m := mask(jx, jz)
			var clump := smoothstep(-0.05, 0.4, _noise_a.get_noise_2d(jx * 2.1 + 500.0, jz * 2.1))
			if m < 0.25 or rng.randf() > 0.38 * m * clump: continue
			if _road_near(jx, jz).x < 12.0: continue
			var near_pad := false
			for p in pads:
				if (p.c as Vector2).distance_to(Vector2(jx, jz)) < 36.0: near_pad = true
			if near_pad: continue
			if absf(jx - SIGN_C.x) < SIGN_HALF.x + 30.0 and absf(jz - SIGN_C.y) < 60.0: continue
			if Vector2(jx, jz).distance_to(MUSEUM_C) < 90.0: continue
			if _slope_at(jx, jz) > 0.45: continue
			var s := rng.randf_range(2.2, 3.4)
			var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.9, 1.4), s)), Vector3(jx, height(jx, jz) - 0.1, jz))
			CoastProps._place(batches, "cyp", cy, t)
			count += 1
			if count % 6 == 0: CoastProps._box(body, Vector3(0.9, 5.0, 0.9), Vector3(jx, height(jx, jz) + 2.5, jz))
		x += 18.0
	CoastProps._flush(w, batches, false)

## The road ends in a round forecourt with a kerb: the museum goes on the west side of it.
static func _museum_site(w: World, body: StaticBody3D) -> void:
	var asphalt := w._mat("res://assets/hills/american_road_hilly_terrain_9.jpg", 0.12, Color(1, 1, 1))
	var kerb := w._mat("res://assets/hills/american_road_hilly_terrain_3.jpg", 0.22, Color(0.9, 0.9, 0.9))
	var y := museum_h
	for part in [[MUSEUM_R - 4.0, 0.12, asphalt], [MUSEUM_R, 0.2, kerb]]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = part[0]
		cm.bottom_radius = part[0]
		cm.height = part[1]
		cm.radial_segments = 48
		mi.mesh = cm
		mi.material_override = part[2]
		mi.position = Vector3(MUSEUM_C.x, y + part[1] * 0.5 + (0.0 if part[1] > 0.15 else 0.1), MUSEUM_C.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mi)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = part[0]
		cyl.height = part[1]
		cs.shape = cyl
		cs.position = mi.position
		body.add_child(cs)
	w.add_poi("museum", "RENOWOOD MUSEUM", Vector3(MUSEUM_C.x - 40.0, 0.0, MUSEUM_C.y))

static func _sign(w: World, body: StaticBody3D) -> void:
	var font := load("res://assets/ui/fonts/BebasNeue-Regular.ttf") as Font
	var tm := TextMesh.new()
	tm.text = "RENOWOOD"
	tm.font = font
	tm.font_size = 256
	tm.pixel_size = 0.24
	tm.depth = 1.4
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.96, 0.94)
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.97, 0.9)
	mat.emission_energy_multiplier = 0.0
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = mat
	var sz := tm.get_aabb().size
	var lift := 9.0
	mi.position = Vector3(SIGN_C.x, sign_h + lift + sz.y * 0.5, SIGN_C.y)
	w.static_root.add_child(mi)
	var steel := w._flat(Color("#4b5058"))
	var half_w := sz.x * 0.5
	var k := -half_w + 4.0
	while k < half_w:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, lift + 2.0, 0.7)
		post.mesh = bm
		post.material_override = steel
		post.position = Vector3(SIGN_C.x + k, sign_h + (lift + 2.0) * 0.5 - 0.3, SIGN_C.y - 0.2)
		w.static_root.add_child(post)
		k += 18.0
	CoastProps._box(body, Vector3(sz.x, lift + sz.y, 1.6), Vector3(SIGN_C.x, sign_h + (lift + sz.y) * 0.5, SIGN_C.y))
	w.set_meta("renowood_sign_mat", mat)
