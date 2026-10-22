class_name RoadKit
extends RefCounted
## Lays the supplied "Road Modular" kit along the road graph: a crossroad at every node, straights between them,
## street lamps along the kerbs. Everything is solid (the pieces are low-poly, so exact trimesh collision).

const PATH := "res://assets/roads/road_modular.glb"
const CROSS_W := 11.78            # crossroad piece, metres
const STRAIGHT_L := 22.4          # straight piece length, metres
const LAMP_EVERY := 2             # a lamp on every n-th straight
const LAMP_SPACING := 44.8

static var _pieces := {}

static func _load() -> void:
	if not _pieces.is_empty(): return
	var inst := (load(PATH) as PackedScene).instantiate() as Node3D
	_walk(inst, Transform3D.IDENTITY)
	inst.free()

static func _walk(n: Node, xf: Transform3D) -> void:
	var t := xf
	if n is Node3D: t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var key := String(n.get_parent().get_parent().name)
		var mesh := (n as MeshInstance3D).mesh
		_pieces[key] = {"mesh": mesh, "xf": t, "bb": t * mesh.get_aabb()}
	for c in n.get_children():
		_walk(c, t)

static func _find(prefix: String) -> Dictionary:
	for k in _pieces:
		if String(k).begins_with(prefix): return _pieces[k]
	return {}

## Lay one piece with the middle of its footprint at `at`, turned by `yaw`, stretched `stretch` times along its length.
static func _put(w: World, body: StaticBody3D, piece: Dictionary, at: Vector3, yaw: float, stretch := 1.0, pivot := Vector2.INF, normal := Vector3.UP) -> void:
	var bb: AABB = piece.bb
	var c := bb.get_center()
	var pv := Vector2(c.x, c.z) if pivot == Vector2.INF else pivot
	var local := Transform3D(Basis.IDENTITY, Vector3(-pv.x, -bb.position.y, -pv.y)) * (piece.xf as Transform3D)
	var tilt := Basis(Quaternion(Vector3.UP, normal)) if normal != Vector3.UP else Basis.IDENTITY
	var t := Transform3D(tilt * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1, 1, stretch)), at) * local
	var mi := MeshInstance3D.new()
	mi.mesh = piece.mesh
	mi.transform = t
	mi.visibility_range_end = 3000.0
	w.static_root.add_child(mi)
	var faces: PackedVector3Array = (piece.mesh as Mesh).get_faces()
	var out := PackedVector3Array()
	out.resize(faces.size())
	for i in range(faces.size()):
		out[i] = t * faces[i]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(out)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

## Foot and head of a lamp-post piece (xz of its lowest and highest vertices), used to stand it on the kerb facing the road.
static func _pole_ends(piece: Dictionary) -> Array:
	var xf: Transform3D = piece.xf
	var base := Vector2.ZERO
	var tip := Vector2.ZERO
	var nb := 0
	var nt := 0
	for v in (piece.mesh as Mesh).get_faces():
		var p: Vector3 = xf * v
		if p.y < 0.6:
			base += Vector2(p.x, p.z); nb += 1
		elif p.y > 7.2:
			tip += Vector2(p.x, p.z); nt += 1
	return [base / maxf(nb, 1), tip / maxf(nt, 1)]

const CURVE_W := 11.72            # short-curve piece, metres
const ARM_DIRS := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]    # N E S W in (x, z)

## Which of the four compass arms of node i carry a road (kind 4 ring chords do not count).
static func _arms(i: int) -> Array:
	var out := [false, false, false, false]
	for a in CityData.adj[i]:
		var e: Array = CityData.edges[a.e]
		if int(e[2]) == 4: continue
		var d := (CityData.nodes[int(a.n)] - CityData.nodes[i]).normalized()
		for k in range(4):
			if d.dot(ARM_DIRS[k]) > 0.9: out[k] = true
	return out

static func _yaw_for_corner(arms: Array) -> float:
	# the kit's curve joins West and South at yaw 0; a quarter turn per step
	var pairs := {0.0: [3, 2], PI * 0.5: [2, 1], PI: [1, 0], PI * 1.5: [0, 3]}
	for yaw in pairs:
		var p: Array = pairs[yaw]
		if arms[p[0]] and arms[p[1]]: return yaw
	return 0.0

static func build(w: World) -> void:
	_load()
	var body := StaticBody3D.new()
	body.name = "Roads"
	body.collision_layer = 1
	w.static_root.add_child(body)
	var cross := _find("Crossroad")
	var curve := _find("Short curve")
	var straight := _find("Road_33")
	var pole := _find("Light pole_001")
	var ends := _pole_ends(pole)
	var pole_base: Vector2 = ends[0]
	var pole_arm: Vector2 = (ends[1] as Vector2) - pole_base
	var arm_yaw := atan2(pole_arm.x, pole_arm.y)
	var cut := PackedFloat32Array()            # how much of each node's surroundings its junction piece covers
	cut.resize(CityData.nodes.size())
	var rings: Array = []
	for i in range(CityData.nodes.size()):
		var p := CityData.nodes[i]
		var kind := CityData.node_kind[i] if i < CityData.node_kind.size() else 0
		if kind == 1:
			cut[i] = CityData.RING_OUT - CityData.RING_R
			continue
		if kind == 5:
			cut[i] = 0.0                      # a plain road end at a car park, no junction piece or barrier
			continue
		if kind == 2:
			cut[i] = CityData.TURN_R
			_turnaround(w, body, p, i)
			continue
		var arms := _arms(i)
		var n_arms := 0
		for a in arms: if a: n_arms += 1
		if n_arms == 2 and ((arms[0] and arms[2]) or (arms[1] and arms[3])):
			cut[i] = 0.0                                    # a road simply running on
		elif n_arms == 2:
			cut[i] = CURVE_W * 0.5
			_put(w, body, curve, Vector3(p.x, 0, p.y), _yaw_for_corner(arms))
		else:
			cut[i] = CROSS_W * 0.5
			_put(w, body, cross, Vector3(p.x, 0, p.y), 0.0)
			for k in range(4):
				if not arms[k]: _barrier(w, body, p, ARM_DIRS[k])
	_roundabout(w, body)
	for e in CityData.edges:
		if int(e[2]) == 4: continue
		var ia := int(e[0])
		var ib := int(e[1])
		var a := CityData.nodes[ia]
		var b := CityData.nodes[ib]
		var d := (b - a)
		var len := d.length()
		d /= len
		var run := len - cut[ia] - cut[ib]
		if run < 4.0: continue
		# where the railway crosses this road, the road pieces stop and a plain slab with the rails laid in it takes over
		var gaps: Array = []
		for cp in Rail.crossing_points():
			var t: float = (cp as Vector2 - a).dot(d)
			if t > cut[ia] and t < len - cut[ib] and absf((cp as Vector2 - a).dot(Vector2(-d.y, d.x))) < 2.0:
				gaps.append(Vector2(t - Rail.GAP * 0.5, t + Rail.GAP * 0.5))
		var spans: Array = []
		var from := cut[ia]
		gaps.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		for g in gaps:
			spans.append(Vector2(from, g.x))
			from = g.y
		spans.append(Vector2(from, len - cut[ib]))
		var yaw := atan2(d.x, d.y)
		for sp in spans:
			var run2: float = sp.y - sp.x
			if run2 < 4.0: continue
			var n := maxi(1, int(round(run2 / STRAIGHT_L)))
			var step := run2 / n
			for k in range(n):
				var dist: float = sp.x + (k + 0.5) * step
				var c := a + d * dist
				# over open water the bridge model carries the road; a piece that only half overlaps the bridge's end stays, so no gap is left
				if absf(c.x) < 1.0 and c.y - STRAIGHT_L * step / STRAIGHT_L * 0.5 > Coast.bridge_range().x - 2.0 and c.y + STRAIGHT_L * step / STRAIGHT_L * 0.5 < Coast.bridge_range().y + 2.0: continue
				_put(w, body, straight, Vector3(c.x, 0, c.y), yaw, step / STRAIGHT_L)
		# lamps on alternating kerbs
		var side := 1.0
		var nrm := Vector2(-d.y, d.x)
		var pos := cut[ia] + LAMP_SPACING * 0.5
		while pos < len - cut[ib] - 4.0:
			var c := a + d * pos + nrm * side * 4.9
			if absf(c.x) < 8.0 and c.y > Coast.bridge_range().x - 2.0 and c.y < Coast.bridge_range().y + 2.0:
				side = -side
				pos += LAMP_SPACING
				continue
			var face := atan2(-nrm.x * side, -nrm.y * side)
			_put(w, body, pole, Vector3(c.x, 0, c.y), face - arm_yaw, 1.0, pole_base)
			var tip := c + Vector2(-nrm.x * side, -nrm.y * side) * pole_arm.length() * 0.9
			w.lamp_points.append(Vector3(tip.x, 7.3, tip.y))
			side = -side
			pos += LAMP_SPACING
	print("road kit: ", CityData.nodes.size(), " nodes, ", CityData.edges.size(), " road runs, ", w.lamp_points.size(), " lamps")

## A low concrete barrier across an open arm of a junction, so the road ends properly instead of just stopping.
static func _barrier(w: World, body: StaticBody3D, at: Vector2, dir: Vector2, y := 0.0) -> void:
	var c := at + dir * (CROSS_W * 0.5 + 0.4)
	var yaw := atan2(dir.x, dir.y)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(11.4, 0.9, 0.7)
	mi.mesh = bm
	mi.material_override = w._mat("res://assets/roads/pavement.png", 0.3, Color(0.85, 0.85, 0.85))
	mi.position = Vector3(c.x, 0.45 + y, c.y)
	mi.rotation.y = yaw
	mi.visibility_range_end = 500.0
	w.static_root.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), mi.position)
	body.add_child(cs)

static var _road_mat: StandardMaterial3D
static var _plain_mat: StandardMaterial3D

static func _mats(w: World) -> void:
	if _road_mat != null: return
	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_texture = load("res://assets/roads/road_lined.png") as Texture2D
	_road_mat.roughness = 0.95
	_road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_plain_mat = StandardMaterial3D.new()
	_plain_mat.albedo_texture = load("res://assets/roads/road_plain.png") as Texture2D
	_plain_mat.roughness = 0.95
	_plain_mat.uv1_triplanar = true
	_plain_mat.uv1_world_triplanar = true
	_plain_mat.uv1_scale = Vector3.ONE * 0.08
	_plain_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

## Flat annular sector of road (r0 may be 0 for a disc) between angles a0..a1; returns [surface mesh, faces].
static func _annulus(c: Vector2, r0: float, r1: float, a0: float, a1: float, y: float, uv_scale: float) -> Array:
	var seg := maxi(4, int((a1 - a0) / deg_to_rad(6.0)))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in range(seg + 1):
		var a := a0 + (a1 - a0) * float(k) / seg
		var dirv := Vector2(sin(a), cos(a))
		verts.append(Vector3(c.x + dirv.x * r0, y, c.y + dirv.y * r0))
		verts.append(Vector3(c.x + dirv.x * r1, y, c.y + dirv.y * r1))
		var v := a * (r0 + r1) * 0.5 * uv_scale
		uvs.append(Vector2(0, v)); uvs.append(Vector2(1, v))
		norms.append(Vector3.UP); norms.append(Vector3.UP)
	for k in range(seg):
		var i := k * 2
		idx.append_array(PackedInt32Array([i, i + 2, i + 1, i + 1, i + 2, i + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return [m, verts, idx]

static func _add_surface(w: World, body: StaticBody3D, ann: Array, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ann[0]
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 3000.0
	w.static_root.add_child(mi)
	var verts: PackedVector3Array = ann[1]
	var idx: PackedInt32Array = ann[2]
	var faces := PackedVector3Array()
	for i in idx: faces.append(verts[i])
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = sh
	body.add_child(cs)

## A raised kerb ring segment (top and both walls) between radii r0..r1 over the given angle range.
static func _kerb(w: World, body: StaticBody3D, c: Vector2, r0: float, r1: float, a0: float, a1: float, h: float) -> void:
	var seg := maxi(2, int((a1 - a0) / deg_to_rad(6.0)))
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in range(seg + 1):
		var a := a0 + (a1 - a0) * float(k) / seg
		var dv := Vector2(sin(a), cos(a))
		for r in [r0, r1]:
			verts.append(Vector3(c.x + dv.x * r, 0.04, c.y + dv.y * r))     # bottom
			verts.append(Vector3(c.x + dv.x * r, h, c.y + dv.y * r))        # top
	# per step: vertices [in_bot, in_top, out_bot, out_top]
	for k in range(seg):
		var i := k * 4
		var j := i + 4
		idx.append_array(PackedInt32Array([i + 1, j + 1, i + 3, j + 1, j + 3, i + 3]))      # top
		idx.append_array(PackedInt32Array([i, j, i + 1, j, j + 1, i + 1]))                  # inner wall
		idx.append_array(PackedInt32Array([i + 2, i + 3, j + 2, j + 2, i + 3, j + 3]))      # outer wall
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m = _with_normals(m)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = w._mat("res://assets/roads/pavement.png", 0.25, Color(0.92, 0.92, 0.9))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 3000.0
	w.static_root.add_child(mi)
	var faces := PackedVector3Array()
	for i in idx: faces.append(verts[i])
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = sh
	body.add_child(cs)

static func _with_normals(m: ArrayMesh) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from_arrays(m.surface_get_arrays(0))
	st.generate_normals()
	return st.commit()

static func _gap_angles(c: Vector2, r: float, openings: Array, half_w: float) -> Array:
	# angle ranges of the ring kerb that stay closed, given the arm directions (angles) that open it
	var cuts: Array = []
	for a in openings:
		var da := asin(clampf(half_w / r, 0.0, 1.0))
		cuts.append([a - da, a + da])
	cuts.sort_custom(func(x, y): return x[0] < y[0])
	var out: Array = []
	var cur := 0.0
	for cc in cuts:
		var c0: float = cc[0]
		if c0 < 0.0: c0 += TAU
		var c1: float = cc[1]
		if c1 < 0.0: c1 += TAU
		out.append([c0, c1])
	out.sort_custom(func(x, y): return x[0] < y[0])
	var res: Array = []
	var start := 0.0
	for o in out:
		if o[0] > start: res.append([start, o[0]])
		start = maxf(start, o[1])
	if start < TAU: res.append([start, TAU])
	return res

## The roundabout in front of the terminal: a ring of asphalt round a grass island, kerbed, open where roads join.
static func _roundabout(w: World, body: StaticBody3D) -> void:
	_mats(w)
	var c := CityData.RING_C
	_add_surface(w, body, _annulus(c, CityData.RING_IN, CityData.RING_OUT, 0.0, TAU, 0.06, 0.06), _road_mat)
	# island: raised kerb ring and a grass top
	_kerb(w, body, c, CityData.RING_IN - 0.6, CityData.RING_IN, 0.0, TAU, 0.2)
	var island := StaticBody3D.new()
	island.collision_layer = 1
	var disc := CylinderMesh.new()
	disc.top_radius = CityData.RING_IN - 0.6
	disc.bottom_radius = CityData.RING_IN - 0.6
	disc.height = 0.2
	disc.radial_segments = 32
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = w._mat("res://assets/textures/y2k_grass.png", 0.2, Color(0.8, 0.95, 0.75))
	island.add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = CityData.RING_IN - 0.6
	cyl.height = 0.2
	cs.shape = cyl
	island.add_child(cs)
	island.position = Vector3(c.x, 0.1, c.y)
	w.static_root.add_child(island)
	# outer kerb: closed except where the gate road (south), the two forecourt arms (east, west) and the terminal side (north, kept closed) meet it
	var openings := [0.0, PI * 0.5, PI * 1.5]            # angles measured from +Z (south) through +X (east)
	for seg in _gap_angles(c, CityData.RING_OUT, openings, 6.2):
		_kerb(w, body, c, CityData.RING_OUT, CityData.RING_OUT + 0.6, seg[0], seg[1], 0.2)
	# lamps round the island
	for k in range(3):
		var a := PI * (0.25 + k * 0.5) + (PI if k == 1 else 0.0)
		var at := c + Vector2(sin(a), cos(a)) * (CityData.RING_IN + 0.5)
		lamp_at(w, body, at, c + Vector2(sin(a), cos(a)) * (CityData.RING_IN + 6.0))

## A turnaround circle at the end of a road: asphalt disc with a kerb all round except where the road comes in.
static func _turnaround(w: World, body: StaticBody3D, p: Vector2, node_id: int) -> void:
	_mats(w)
	_add_surface(w, body, _annulus(p, 0.0, CityData.TURN_R, 0.0, TAU, 0.06, 0.06), _plain_mat)
	var open := []
	for a in CityData.adj[node_id]:
		var d: Vector2 = CityData.nodes[int(a.n)] - p
		open.append(atan2(d.x, d.y) if atan2(d.x, d.y) >= 0.0 else atan2(d.x, d.y) + TAU)
	for seg in _gap_angles(p, CityData.TURN_R, open, 6.2):
		_kerb(w, body, p, CityData.TURN_R, CityData.TURN_R + 0.6, seg[0], seg[1], 0.2)

## One lamp post of the kit standing at `at` (xz) with its arm reaching towards `toward` (xz); adds its light point.
static func lamp_at(w: World, body: StaticBody3D, at: Vector2, toward: Vector2, y := 0.0) -> void:
	_load()
	var pole := _find("Light pole_001")
	var ends := _pole_ends(pole)
	var base: Vector2 = ends[0]
	var arm: Vector2 = (ends[1] as Vector2) - base
	var arm_yaw := atan2(arm.x, arm.y)
	var dir := (toward - at).normalized()
	_put(w, body, pole, Vector3(at.x, y, at.y), atan2(dir.x, dir.y) - arm_yaw, 1.0, base)
	var tip := at + dir * arm.length() * 0.9
	w.lamp_points.append(Vector3(tip.x, y + 7.3, tip.y))
