class_name Metro
extends Node
## Underground metro between the town and Redline Island. One staircase at each end leads down to the middle of a two-track
## station (an island platform between the tracks, one track for each direction); a tunnel under the sea joins the two stations
## and yellow metro trains circle the line, stopping at both platforms of both stations with a short tunnel beyond each end.
## The supplied station model is a one-track station: it is used twice, the second copy mirrored, so the platforms meet in the middle.

const ENT := "res://assets/metro/subway_entrance_v2.glb"
const STN := "res://assets/metro/lowpoly_berlin_u-bahn_station.glb"
const TRN := "res://assets/metro/lowpoly_berlin_u-bahn.glb"
const XM := -75.0                  # the staircases (and the whole line) run along this x
const SW := 2.4                    # staircase width (the inside of the entrance model's railing)
const OPEN := 6.1                  # how far down the stairs the stairwell is open to the sky (the length of the entrance model's railing)
const RUN := 0.26
const CLEAR := 2.8                 # headroom over the steps
const MID_X := 6.88                # the station's centre plane in its own space (module 1 spans -1.79 .. 6.88, module 2 is its mirror)
const PLAT_Z := -16.23             # platform centre, station space
const SHELL_TOP := 4.88
const PLAT_TOP := 1.2
const STOP_Z := -19.0              # (old yellow train) centre when stopped
const EXT := 0.0                   # how far each platform is lengthened, at its last-stop end, to fit the 67 m train
const STUB := 90.0
const LANE_W := 0.17
const LANE_E := 13.59

static var L := {}                 # the computed layout, see plan()
static var ents: Array = []        # [Vector3 mouth, ...] for the dev tests
static var trains: Array = []
static var pa: Array = [null, null]          # the platform loudspeakers, [Atlanta Court, Island Plaza]
const SLUGS := ["atlanta_court", "island_plaza"]
const NAMES := ["ATLANTA COURT", "ISLAND PLAZA"]

# ------------------------------------------------------------------ layout

## Works out where everything goes and registers the openings in the ground and the town's slabs. Call before the terrain is built.
static func plan() -> void:
	var gy_a := CityBuild.BAND_H
	var gy_b := maxf(CityData.height_at(XM, 2438.0), 0.0) + 0.05
	var n_a := 71
	var y_floor := gy_a - n_a * 0.2                              # platform floor level (metres), the same for both stations
	var n_b := int(round((gy_b - y_floor) / 0.2))
	var za := 7.1                                                # A: stairs start here, going south
	var zb := 2438.2                                             # B: stairs start here, going north
	var oy := y_floor - PLAT_TOP
	var oa_z := za + n_a * RUN - PLAT_Z
	var ob_z := zb - n_b * RUN - PLAT_Z
	L = {
		"a": {"gy": gy_a, "n": n_a, "rise": (gy_a - y_floor) / n_a, "zs": za, "dir": 1.0, "o": Vector3(XM - MID_X, oy, oa_z), "yaw": PI, "holder_z": 8.3},
		"b": {"gy": gy_b, "n": n_b, "rise": (gy_b - y_floor) / n_b, "zs": zb, "dir": -1.0, "o": Vector3(XM - MID_X, oy, ob_z), "yaw": 0.0, "holder_z": 2437.0, "plug": true},
		"floor": y_floor,
	}
	CityBuild.holes.clear()
	Coast.holes.clear()
	Coast.shafts.clear()
	for k in ["a", "b"]:
		var st: Dictionary = L[k]
		var d: float = st.dir
		var z0: float = float(st.zs) - (0.02 if d > 0.0 else OPEN + 0.1)       # the opening runs exactly from the first step to the lintel
		var hole := Rect2(XM - SW * 0.5 - 0.05, z0, SW + 0.1, OPEN + 0.12)
		st["hole"] = hole
		CityBuild.holes.append(hole)
		Coast.holes.append(hole.grow(0.05))
		var run: float = float(st.n) * RUN
		var zst: float = float(st.zs)
		Coast.shafts.append(Rect2(XM - SW * 0.5 - 0.4, minf(zst, zst + d * run) - 1.0, SW + 0.8, run + 2.0))

## True while a point is inside one of the stair corridors (the camera keeps close there so it never ends up outside the walls).
static func in_stairs(p: Vector3) -> bool:
	return stair_dir(p) != 0.0

## The direction (+1 / -1 along z) in which the stairs go down at this point, or 0 when the point is not on the stairs.
static func stair_dir(p: Vector3) -> float:
	if L.is_empty(): return 0.0
	if absf(p.x - XM) > SW * 0.5 + 0.8: return 0.0
	for k in ["a", "b"]:
		var st: Dictionary = L[k]
		var s := (p.z - float(st.zs)) * float(st.dir)
		if s > -0.8 and s < float(st.n) * RUN + 2.5 and p.y < float(st.gy) - 0.3 and p.y > float(L.floor) - 1.5:
			return float(st.dir)
	return 0.0

static func _xf(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

static func _solid(body: StaticBody3D, mesh: Mesh, xf: Transform3D) -> void:
	var f := mesh.get_faces()
	var out := PackedVector3Array()
	out.resize(f.size())
	for i in range(f.size()): out[i] = xf * f[i]
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(out)
	sh.backface_collision = true            # solid from both sides: the stair walls must hold the player in as well as out
	var cs := CollisionShape3D.new()
	cs.shape = sh
	body.add_child(cs)

static func _box(w: Node3D, body: StaticBody3D, a: Vector3, b: Vector3, mat: Material, collide := true, visible := true) -> void:
	if not visible:
		if collide: CoastProps._box(body, (b - a).abs(), (a + b) * 0.5)
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = (b - a).abs()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	if collide: CoastProps._box(body, bm.size, mi.position)

# ------------------------------------------------------------------ build

static func build(w: World) -> void:
	if L.is_empty(): plan()
	var body := StaticBody3D.new()
	body.name = "MetroSolid"
	body.collision_layer = 1
	w.add_child(body)
	var conc := StandardMaterial3D.new()
	conc.albedo_color = Color(0.46, 0.47, 0.48)
	conc.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.11)
	dark.roughness = 0.9
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var inst_a := _station(w, body, L.a.o, conc, "ATLANTA COURT")
	var inst_b := _station(w, body, L.b.o, conc, "ISLAND PLAZA")
	_stairs(w, body, L.a, conc)
	_stairs(w, body, L.b, conc)
	_entrance(w, body, L.a)
	_entrance(w, body, L.b)
	_tunnel(w, body, conc)
	w.add_poi("station", "ATLANTA COURT METRO", Vector3(XM, 0.0, L.a.zs))
	w.add_poi("station", "ISLAND PLAZA METRO", Vector3(XM, 0.0, L.b.zs))
	var t0 := MetroTrain.new()
	t0.start_stop = 0
	var t1 := MetroTrain.new()
	t1.start_stop = 1
	for t in [t0, t1]:
		w.add_child(t)
		trains.append(t)

## One two-track station: the model twice (the second mirrored), its walls and ceiling re-cut so the platforms form one island.
static func _station(w: World, body: StaticBody3D, o: Vector3, conc: Material, title: String) -> Node3D:
	var root := Node3D.new()
	root.position = o
	root.name = "MetroStation"
	w.add_child(root)
	var src := (load(STN) as PackedScene).instantiate() as Node3D
	var sidx := 0 if title == NAMES[0] else 1
	# the model carries its own train: ours move, so it goes
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).get_active_material(0)
		var rn := String(mat.resource_name) if mat != null else ""
		if rn == "SIGNS" and mat is BaseMaterial3D:
			# the name boards say this station's name (repainted from the model's own sign texture)
			var sm := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			sm.albedo_texture = load("res://assets/metro/signs/signs_%s.png" % SLUGS[sidx]) as Texture2D
			(mi as MeshInstance3D).set_surface_override_material(0, sm)
		if rn == "checker.002" and mat is BaseMaterial3D:
			# the hanging departure boards: English, with this station's destination
			var bm := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			bm.albedo_texture = load("res://assets/metro/signs/board_%s.png" % SLUGS[sidx]) as Texture2D
			(mi as MeshInstance3D).set_surface_override_material(0, bm)
		if rn == "Ticket" and mat is BaseMaterial3D:
			var tm := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			tm.albedo_texture = load("res://assets/metro/signs/ticket_en.png") as Texture2D
			(mi as MeshInstance3D).set_surface_override_material(0, tm)
		if rn == "blueprint":
			mi.get_parent().remove_child(mi)
			mi.free()
		elif rn == "base":
			(mi as MeshInstance3D).mesh = _recut_shell((mi as MeshInstance3D).mesh, _xf(mi, src))
	var mirror_xf := Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3(2.0 * MID_X, 0, 0))
	for k in range(2):
		var inst: Node3D = src if k == 0 else (src.duplicate() as Node3D)
		var holder := Node3D.new()
		holder.transform = Transform3D.IDENTITY if k == 0 else mirror_xf
		holder.add_child(inst)
		root.add_child(holder)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var mat := m.get_active_material(0)
			var rn := String(mat.resource_name) if mat != null else ""
			if k == 1 and rn == "SIGNS":
				m.visible = false
				continue
			if rn in ["base", "checker", "checker.001", "checker.002", "checker.003", "bench", "Ticket", "Trashcanbreak", "pillars", "vendingmachine", "Material"]:
				_solid(body, m.mesh, o_xf(o) * holder.transform * _xf(m, inst))
	# own ceiling over both modules, with the stairwell opening cut in it
	var x0 := o.x - 1.79
	var x1 := o.x + 2.0 * MID_X + 1.79
	var zc0 := o.z - 47.1
	var zc1 := o.z + 15.8
	var cy := o.y + SHELL_TOP
	var hole := Rect2(0, 0, 0, 0)
	for kk in ["a", "b"]:
		var st: Dictionary = L[kk]
		if (st.o as Vector3).is_equal_approx(o):
			var d: float = st.dir
			var slope: float = float(st.rise) / RUN
			var s_c: float = (float(st.gy) - cy) / slope                       # run at which the steps meet the ceiling plane
			var send: float = float(st.n) * RUN
			var za0: float = float(st.zs) + d * (s_c - 1.1)          # the plate is 0.5 thick: open the hole before the steps meet its top
			var za1: float = float(st.zs) + d * (send + 0.3)
			hole = Rect2(XM - SW * 0.5 - 0.1, minf(za0, za1), SW + 0.2, absf(za1 - za0))
	var cm := conc
	_box(w, body, Vector3(x0, cy, zc0), Vector3(hole.position.x, cy + 0.5, zc1), cm)
	_box(w, body, Vector3(hole.end.x, cy, zc0), Vector3(x1, cy + 0.5, zc1), cm)
	_box(w, body, Vector3(hole.position.x, cy, zc0), Vector3(hole.end.x, cy + 0.5, hole.position.y), cm)
	_box(w, body, Vector3(hole.position.x, cy, hole.end.y), Vector3(hole.end.x, cy + 0.5, zc1), cm)
	# lights, and the names
	for k in range(8):
		for lx in [2.8, 10.96]:
			var ol := OmniLight3D.new()
			ol.position = Vector3(o.x + lx, o.y + 3.7, o.z - 45.0 + k * 8.4)
			ol.omni_range = 11.0
			ol.light_energy = 1.1
			ol.light_color = Color(1.0, 0.96, 0.85)
			ol.shadow_enabled = false
			w.add_child(ol)
	# the platform loudspeaker
	var spk := AudioStreamPlayer3D.new()
	spk.max_distance = 60.0
	spk.unit_size = 18.0                # a loud public-address system: carries along the whole platform
	spk.volume_db = 6.0
	spk.position = o + Vector3(MID_X, 3.4, -16.0)
	w.add_child(spk)
	pa[sidx] = spk
	return root

## An announcement over a station's loudspeaker (only one at a time).
static func announce(station: int, file: String) -> void:
	var spk := pa[station] as AudioStreamPlayer3D
	if spk == null: return
	if MetroTrain.riding != null: return            # inside a car with the doors shut you hear only the car
	var st := load("res://assets/metro/audio/%s.wav" % file) as AudioStream
	if st == null: return
	spk.stream = st
	spk.play()

static func o_xf(o: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, o)

## The station shell without its ceiling (we build one with an opening) and without its east wall (the platforms join there).
static func _recut_shell(mesh: Mesh, xf: Transform3D) -> Mesh:
	var out := ArrayMesh.new()
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn = arr[Mesh.ARRAY_NORMAL]
		var uu = arr[Mesh.ARRAY_TEX_UV]
		var ids: PackedInt32Array = PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null: ids = arr[Mesh.ARRAY_INDEX]
		else:
			ids.resize(v.size())
			for i in range(v.size()): ids[i] = i
		var kv := PackedVector3Array()
		var kn := PackedVector3Array()
		var ku := PackedVector2Array()
		for t in range(ids.size() / 3):
			var wa: Vector3 = xf * v[ids[t * 3]]
			var wb: Vector3 = xf * v[ids[t * 3 + 1]]
			var wc: Vector3 = xf * v[ids[t * 3 + 2]]
			var cen := (wa + wb + wc) / 3.0                             # in the station's space (the mesh node is rotated)
			var nrm := (wb - wa).cross(wc - wa).normalized()
			var ceiling := cen.y > 3.5 and absf(nrm.y) > 0.8
			var east := cen.x > 6.4 and absf(nrm.x) > 0.8
			if ceiling or east: continue
			for k in range(3):
				var i2 := ids[t * 3 + k]
				kv.append(v[i2])
				kn.append(nn[i2] if nn != null else Vector3.UP)
				ku.append(uu[i2] if uu != null else Vector2.ZERO)
		if kv.is_empty(): continue
		var a2 := []
		a2.resize(Mesh.ARRAY_MAX)
		a2[Mesh.ARRAY_VERTEX] = kv
		a2[Mesh.ARRAY_NORMAL] = kn
		a2[Mesh.ARRAY_TEX_UV] = ku
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(si))
	return out

## The staircase: treads, a smooth ramp to walk on, side walls and a sloping roof, from the street down to the platform.
static func _stairs(w: World, body: StaticBody3D, st: Dictionary, conc: Material) -> void:
	var gy: float = st.gy
	var n: int = st.n
	var rise: float = st.rise
	var d: float = st.dir
	var zs: float = st.zs
	var slope := rise / RUN
	var tread_m := StandardMaterial3D.new()
	var step_tex := load("res://assets/metro/subway_entrance_v2_7.png") as Texture2D
	if step_tex != null:
		tread_m.albedo_texture = step_tex
		tread_m.uv1_triplanar = true
		tread_m.uv1_world_triplanar = true
		tread_m.uv1_scale = Vector3(1.2, 1.2, 1.2)
	else:
		tread_m.albedo_color = Color(0.55, 0.55, 0.56)
	tread_m.roughness = 0.8
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(SW, rise + 0.3, RUN)
	mm.mesh = bm
	mm.instance_count = n
	for i in range(n):
		var top := gy - i * rise
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(XM, top - (rise + 0.3) * 0.5, zs + d * (i + 0.5) * RUN)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = tread_m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mmi)
	# ramp to walk on: its surface starts flush with the street at the top of the stairs and runs down just above the treads
	var ang := atan(slope)
	var length := (n * RUN + 0.3) / cos(ang)
	var fwd := Vector3(0, -sin(ang), d * cos(ang))
	var up := Vector3(0, cos(ang), d * sin(ang))
	var p0 := Vector3(XM, gy + 0.06, zs)            # the walking surface runs through the middle of the treads, 6 cm up at the street edge
	var mid := p0 + fwd * (length * 0.5) - up * 0.15
	var rcs := CollisionShape3D.new()
	var rbx := BoxShape3D.new()
	rbx.size = Vector3(SW, 0.3, length)
	rcs.shape = rbx
	rcs.transform = Transform3D(Basis.looking_at(-fwd, up), mid)
	body.add_child(rcs)
	# walls and roof as one mesh
	var stt := SurfaceTool.new()
	stt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := SW * 0.5
	for k in range(n):
		var s0 := k * RUN
		var s1 := (k + 1) * RUN
		var y0 := gy - s0 * slope
		var y1 := gy - s1 * slope
		var open_part := s1 <= OPEN + 0.001
		var t0 := gy + 1.0 if open_part else minf(y0 + CLEAR, gy + 1.0)
		var t1 := gy + 1.0 if open_part else minf(y1 + CLEAR, gy + 1.0)
		var z0 := zs + d * s0
		var z1 := zs + d * s1
		for sx in [-hw, hw]:
			var pa := Vector3(XM + sx, y0, z0)
			var pb := Vector3(XM + sx, y1, z1)
			var pc := Vector3(XM + sx, t1, z1)
			var pd := Vector3(XM + sx, t0, z0)
			for tri in [[pa, pb, pc], [pa, pc, pd]]:
				for p in tri: stt.add_vertex(p)
		# roof once the stairs have gone under the street (the stairwell is open to the sky until OPEN)
		if s0 >= OPEN - 0.001 and (y0 + CLEAR < gy - 0.05 or y1 + CLEAR < gy - 0.05):
			var ra := Vector3(XM - hw, y0 + CLEAR, z0)
			var rb2 := Vector3(XM + hw, y0 + CLEAR, z0)
			var rc := Vector3(XM + hw, y1 + CLEAR, z1)
			var rd := Vector3(XM - hw, y1 + CLEAR, z1)
			for tri in [[ra, rb2, rc], [ra, rc, rd]]:
				for p in tri: stt.add_vertex(p)
	# the lintel closing the open stairwell where the roof begins (the entrance model's sign hangs on it)
	var sl := OPEN
	var yl := gy - sl * slope
	var zl := zs + d * sl
	var la := Vector3(XM - hw, yl + CLEAR, zl)
	var lb := Vector3(XM + hw, yl + CLEAR, zl)
	var lc := Vector3(XM + hw, gy + 1.0, zl)
	var ld := Vector3(XM - hw, gy + 1.0, zl)
	for tri in [[la, lb, lc], [la, lc, ld]]:
		for p in tri: stt.add_vertex(p)
	stt.generate_normals()
	var wm := StandardMaterial3D.new()
	var wall_tex := load("res://assets/metro/subway_entrance_v2_2.jpg") as Texture2D
	if wall_tex != null:
		wm.albedo_texture = wall_tex
		wm.uv1_triplanar = true
		wm.uv1_world_triplanar = true
		wm.uv1_scale = Vector3(0.9, 0.9, 0.9)
		wm.roughness = 0.45
	else:
		wm.albedo_color = Color(0.62, 0.64, 0.6)
		wm.roughness = 0.9
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shell := stt.commit()
	var smi := MeshInstance3D.new()
	smi.mesh = shell
	smi.material_override = wm
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(smi)
	_solid(body, shell, Transform3D.IDENTITY)
	# stair lights and a parapet round the opening at street level
	for k in range(0, n, 14):
		var ol := OmniLight3D.new()
		var s := k * RUN + 1.0
		ol.position = Vector3(XM, gy - s * slope + 2.0, zs + d * s)
		ol.omni_range = 7.0
		ol.light_energy = 1.0
		ol.light_color = Color(1.0, 0.95, 0.8)
		ol.shadow_enabled = false
		w.add_child(ol)
	var hole: Rect2 = st.hole
	# the ground the terrain lost round the opening (the terrain is cut in whole cells)
	if bool(st.get("plug", false)):
		var cell := Coast.CELL
		var r := Rect2(floorf(hole.position.x / cell) * cell, floorf(hole.position.y / cell) * cell, 0, 0)
		r.end = Vector2(ceilf(hole.end.x / cell) * cell, ceilf(hole.end.y / cell) * cell)
		var pave := w._mat("res://assets/town/paving_tiles.png", 0.25, Color(1.06, 1.0, 0.9))
		var top := gy
		var depth := top - 1.5
		_box(w, body, Vector3(r.position.x, depth, r.position.y), Vector3(hole.position.x, top, r.end.y), pave)
		_box(w, body, Vector3(hole.end.x, depth, r.position.y), Vector3(r.end.x, top, r.end.y), pave)
		_box(w, body, Vector3(hole.position.x, depth, r.position.y), Vector3(hole.end.x, top, hole.position.y), pave)
		_box(w, body, Vector3(hole.position.x, depth, hole.end.y), Vector3(hole.end.x, top, r.end.y), pave)

static func _entrance(w: World, body: StaticBody3D, st: Dictionary) -> void:
	var inst := (load(ENT) as PackedScene).instantiate() as Node3D
	var yaw: float = st.yaw
	var holder := Node3D.new()
	holder.rotation.y = yaw
	var lx := -0.415                  # the middle of the railing frame
	holder.position = Vector3(XM - lx * cos(yaw), float(st.gy) - 0.22, float(st.holder_z))      # sunk so the frame's plinth is flush with the pavement
	var sidx := 0 if st == L.a else 1
	var ent_tex := load("res://assets/metro/signs/entrance_%s.png" % SLUGS[sidx]) as Texture2D
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var pn := String(mi.get_parent().name)
		if pn in ["sidewalk", "Subway_steps", "SubwayWall", "Subway_ceiling", "Subway_Rails"]:
			mi.get_parent().remove_child(mi)
			mi.free()
			continue
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if ent_tex != null:
			var mat := (mi as MeshInstance3D).get_active_material(0)
			if mat is BaseMaterial3D:
				var em := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				em.albedo_texture = ent_tex
				(mi as MeshInstance3D).set_surface_override_material(0, em)
	holder.add_child(inst)
	w.static_root.add_child(holder)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(XM, float(st.gy) + 3.0, float(st.holder_z))
	lamp.omni_range = 9.0
	lamp.light_energy = 0.8
	lamp.light_color = Color(0.6, 1.0, 0.8)
	lamp.visible = false
	w.add_child(lamp)
	CityLights.register_light(lamp, 1.6)

## The tunnel: from the north stub of the town station, under the sea, to the south stub of the island station.
static func _tunnel(w: World, body: StaticBody3D, conc: Material) -> void:
	var oa: Vector3 = L.a.o
	var ob: Vector3 = L.b.o
	var x0 := oa.x - 1.79
	var x1 := oa.x + 2.0 * MID_X + 1.79
	var y0 := oa.y
	var y1 := oa.y + SHELL_TOP
	var segs := [[oa.z + 15.8, ob.z - 47.1]]            # only the stretch between the two stations: both stations end at a wall
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.2, 0.21)
	dark.roughness = 1.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.16, 0.18)
	steel.metallic = 0.6
	steel.roughness = 0.5
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 1, 1)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.96, 0.85)
	glow.emission_energy_multiplier = 2.5
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var za: float = segs[0][0]
	var zb: float = segs[0][1]
	var tube_hw := 2.4                 # half the clear width of the round tunnel (it is invisible collision under the model)
	var th := 4.6
	for lane in [LANE_W, LANE_E]:
		var cx: float = oa.x + lane
		_box(w, body, Vector3(cx - tube_hw, y0 - 0.6, za), Vector3(cx + tube_hw, y0, zb), dark)                       # floor
		_box(w, body, Vector3(cx - tube_hw, y0 + th, za), Vector3(cx + tube_hw, y0 + th + 0.5, zb), conc, true, false)    # ceiling
		_box(w, body, Vector3(cx - tube_hw - 0.5, y0 - 0.6, za), Vector3(cx - tube_hw, y0 + th + 0.5, zb), conc, true, false)
		_box(w, body, Vector3(cx + tube_hw, y0 - 0.6, za), Vector3(cx + tube_hw + 0.5, y0 + th + 0.5, zb), conc, true, false)
	# the supplied round tunnel, tiled along each track; the rails and sleepers are the station's own track, tiled and aligned with it
	var tile := _tunnel_tile()
	if tile != null:
		var tlen: float = tile.length
		var n := maxi(1, int(round((zb - za) / tlen)))
		var kz := (zb - za) / (float(n) * tlen)
		for lane in [LANE_W, LANE_E]:
			var cx2: float = oa.x + lane
			var tfs: Array = []
			for i in range(n):
				tfs.append(Transform3D(Basis.from_scale(Vector3(1, 1, kz)), Vector3(cx2, y0 - float(tile.foot), za + (float(i) + 0.5) * tlen * kz)))
			_chunks(w, tile.mesh, tfs, 20)
	var rails := _station_rails()
	if not rails.is_empty():
		var rlen: float = float(rails.length)
		var nr := maxi(1, int(round((zb - za) / rlen)))
		var kr := (zb - za) / (float(nr) * rlen)
		for lane_i in range(2):
			var rm: Mesh = rails.meshes[lane_i]
			var tfs2: Array = []
			for i in range(nr):
				tfs2.append(Transform3D(Basis.from_scale(Vector3(1, 1, kr)), Vector3(oa.x, y0, za + (float(i) + 0.5) * rlen * kr - kr * float(rails.mid))))
			_chunks(w, rm, tfs2, 2)          # a long span would be hidden by its centre being far away: keep the pieces short
	# wooden sleepers under both tracks (a short run of them per piece, so each piece is drawn only when you are near it)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.33, 0.21, 0.12)
	wood.roughness = 0.95
	var slm := BoxMesh.new()
	slm.size = Vector3(2.5, 0.14, 0.26)
	slm.material = wood
	var pitch := 0.62
	var ns := int((zb - za) / pitch)
	for lane in [LANE_W, LANE_E]:
		var cxs: float = oa.x + lane
		var tfs3: Array = []
		for i in range(ns):
			tfs3.append(Transform3D(Basis(), Vector3(cxs, y0 + 0.02, za + (float(i) + 0.5) * pitch)))
		_chunks(w, slm, tfs3, 150)
	# both outer ends of the line close with a wall and a buffer-stop barricade across each track: the last / first stop
	_terminus(w, body, oa, oa.z - 47.1, 1.0, dark)
	_terminus(w, body, ob, ob.z + 15.8, -1.0, dark)
	# at the tunnel end of each station: a wall with an opening for each track only
	_mouth(w, body, oa, oa.z + 15.8, 1.0, conc)
	_mouth(w, body, ob, ob.z - 47.1, -1.0, conc)

## The supplied tunnel model baked into one mesh (the ring and its lamps), scaled to fit the trains: {mesh, length, foot}.
static func _tunnel_tile() -> Dictionary:
	if not ResourceLoader.exists("res://assets/metro/railway_underground.glb"): return {}
	var sc := 0.0075
	var b := Renowood._baked("res://assets/metro/railway_underground.glb", 1.0, [], true, "tunnel|Sphere", sc)
	var sz: Vector3 = b.size
	# the baked mesh stands on its lowest point: the rail level of the model sits 7.33 units above it
	return {"mesh": b.mesh, "length": sz.z, "foot": 7.33 * sc}

## The station's own rails (the running rail and the third rail), as meshes in station space: one for each of the two tracks
## (the second mirrored, like the second half of the station). Returns {meshes, length, mid}: mid is the z of the middle of the rails.
static func _station_rails() -> Dictionary:
	var src := (load(STN) as PackedScene).instantiate() as Node3D
	var out := {"meshes": [], "length": 0.0, "mid": 0.0}
	var parts: Array = []
	var zlo := 1e9
	var zhi := -1e9
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).get_active_material(0)
		var rn := String(mat.resource_name) if mat != null else ""
		if rn == "rail" or rn == "3rd_rail":
			var xf := _xf(mi, src)
			parts.append([(mi as MeshInstance3D).mesh, xf])
			var bb: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
			zlo = minf(zlo, bb.position.z)
			zhi = maxf(zhi, bb.end.z)
	src.free()
	if parts.is_empty(): return {}
	var mid := (zlo + zhi) * 0.5
	for lane_i in range(2):
		var am := ArrayMesh.new()
		for pr in parts:
			var m: Mesh = pr[0]
			var xf2: Transform3D = pr[1]
			for si in range(m.get_surface_count()):
				var arr := m.surface_get_arrays(si)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var nn = arr[Mesh.ARRAY_NORMAL]
				var uu = arr[Mesh.ARRAY_TEX_UV]
				var ids: PackedInt32Array = PackedInt32Array()
				if arr[Mesh.ARRAY_INDEX] != null: ids = arr[Mesh.ARRAY_INDEX]
				else:
					ids.resize(v.size())
					for i in range(v.size()): ids[i] = i
				var ov := PackedVector3Array()
				var on := PackedVector3Array()
				var ou := PackedVector2Array()
				for t in range(ids.size() / 3):
					for k in ([0, 1, 2] if lane_i == 0 else [0, 2, 1]):
						var i2 := ids[t * 3 + k]
						var p: Vector3 = xf2 * v[i2]
						var n2: Vector3 = (xf2.basis * (nn[i2] if nn != null else Vector3.UP)).normalized()
						if lane_i == 1:
							p.x = 2.0 * MID_X - p.x
							n2.x = -n2.x
						ov.append(p)
						on.append(n2)
						ou.append(uu[i2] if uu != null else Vector2.ZERO)
				var a2 := []
				a2.resize(Mesh.ARRAY_MAX)
				a2[Mesh.ARRAY_VERTEX] = ov
				a2[Mesh.ARRAY_NORMAL] = on
				a2[Mesh.ARRAY_TEX_UV] = ou
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
				am.surface_set_material(am.get_surface_count() - 1, m.surface_get_material(si))
		(out.meshes as Array).append(am)
	out.length = zhi - zlo
	out.mid = mid
	return out

## Instances a mesh at many transforms as several MultiMeshes of `per` instances, each only drawn when you are near it.
static func _chunks(w: Node3D, mesh: Mesh, tfs: Array, per: int) -> void:
	var i := 0
	while i < tfs.size():
		var cnt := mini(per, tfs.size() - i)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = cnt
		for k in range(cnt): mm.set_instance_transform(k, tfs[i + k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 260.0
		w.add_child(mmi)
		i += cnt

## The tunnel end of a station: a wall across the whole station with a track-sized opening for each of the two lines.
static func _mouth(w: Node3D, body: StaticBody3D, o: Vector3, z_end: float, out: float, mat: Material) -> void:
	var x0 := o.x - 1.79
	var x1 := o.x + 2.0 * MID_X + 1.79
	var za := minf(z_end, z_end + out * 0.6)
	var zb := maxf(z_end, z_end + out * 0.6)
	var top := o.y + SHELL_TOP + 0.5
	var open_h := 4.6
	var ranges: Array = []
	var cur := x0 - 0.5
	for lane in [LANE_W, LANE_E]:
		var cx: float = o.x + lane
		ranges.append([cur, cx - 2.4])
		cur = cx + 2.4
	ranges.append([cur, x1 + 0.5])
	for r in ranges:
		if float(r[1]) - float(r[0]) > 0.05:
			_box(w, body, Vector3(float(r[0]), o.y - 0.6, za), Vector3(float(r[1]), top, zb), mat)
	for lane in [LANE_W, LANE_E]:
		var cx2: float = o.x + lane
		_box(w, body, Vector3(cx2 - 2.4, o.y + open_h, za), Vector3(cx2 + 2.4, top, zb), mat)
		# the corners between the square opening and the round tunnel behind it: filled in bands, so only the round bore stays open
		var yc := o.y + 2.47
		var rr := 2.47
		var yb := o.y
		while yb < o.y + open_h:
			var ym := yb + 0.1
			var d := ym - yc
			var hw2 := sqrt(maxf(rr * rr - d * d, 0.0))
			if hw2 < 2.4:
				_box(w, body, Vector3(cx2 - 2.4, yb, za), Vector3(cx2 - hw2, yb + 0.2, zb), mat)
				_box(w, body, Vector3(cx2 + hw2, yb, za), Vector3(cx2 + 2.4, yb + 0.2, zb), mat)
			yb += 0.2


## A station's last-stop end lengthened by EXT: track beds, the island platform, side walls, ceiling, rails, sleepers and lights.
## z0 is where the supplied model ends, d the direction of the extension (+1 / -1 along z).
static func _extend(w: Node3D, body: StaticBody3D, o: Vector3, z0: float, d: float, _conc: Material) -> void:
	var za := minf(z0, z0 + d * EXT)
	var zb := maxf(z0, z0 + d * EXT)
	var x0 := o.x - 1.79
	var x1 := o.x + 2.0 * MID_X + 1.79
	var tile := StandardMaterial3D.new()
	tile.albedo_color = Color(0.75, 0.77, 0.8)
	tile.roughness = 0.8
	var tex := load("res://assets/metro/signs/floor_tile.png") as Texture2D
	if tex != null:
		tile.albedo_texture = tex
		tile.uv1_triplanar = true
		tile.uv1_world_triplanar = true
		tile.uv1_scale = Vector3(0.25, 0.25, 0.25)
	var bed := StandardMaterial3D.new()
	bed.albedo_color = Color(0.2, 0.2, 0.21)
	bed.roughness = 1.0
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.5, 0.52, 0.55)
	wall.roughness = 0.95
	_box(w, body, Vector3(x0, o.y - 0.6, za), Vector3(x1, o.y, zb), bed)
	_box(w, body, Vector3(o.x + 1.7, o.y, za), Vector3(o.x + 2.0 * MID_X - 1.7, o.y + 1.12, zb), tile)
	_box(w, body, Vector3(x0 - 0.3, o.y - 0.6, za), Vector3(x0, o.y + SHELL_TOP + 0.5, zb), wall)
	_box(w, body, Vector3(x1, o.y - 0.6, za), Vector3(x1 + 0.3, o.y + SHELL_TOP + 0.5, zb), wall)
	_box(w, body, Vector3(x0, o.y + SHELL_TOP, za), Vector3(x1, o.y + SHELL_TOP + 0.5, zb), wall)
	var yel := StandardMaterial3D.new()
	yel.albedo_color = Color(0.9, 0.85, 0.2)
	_box(w, body, Vector3(o.x + 1.7, o.y + 1.12, za), Vector3(o.x + 2.1, o.y + 1.135, zb), yel, false)
	_box(w, body, Vector3(o.x + 2.0 * MID_X - 2.1, o.y + 1.12, za), Vector3(o.x + 2.0 * MID_X - 1.7, o.y + 1.135, zb), yel, false)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.2, 0.22, 0.28)
	steel.metallic = 0.6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.33, 0.21, 0.12)
	for lane in [LANE_W, LANE_E]:
		var cx: float = o.x + lane
		for dx in [-0.72, 0.72]:
			_box(w, body, Vector3(cx + dx - 0.04, o.y, za), Vector3(cx + dx + 0.04, o.y + 0.14, zb), steel, false)
		var n := int((zb - za) / 0.62)
		for i in range(n):
			var zz := za + (float(i) + 0.5) * 0.62
			_box(w, body, Vector3(cx - 1.25, o.y + 0.02, zz - 0.13), Vector3(cx + 1.25, o.y + 0.16, zz + 0.13), wood, false)
	for k in range(2):
		var ol := OmniLight3D.new()
		ol.position = Vector3(o.x + MID_X, o.y + 3.7, za + (float(k) + 0.5) * EXT * 0.5)
		ol.omni_range = 11.0
		ol.light_energy = 1.1
		ol.light_color = Color(1.0, 0.96, 0.85)
		ol.shadow_enabled = false
		w.add_child(ol)

## The end of a station: a full wall, and on each track a red-and-white striped buffer stop with a post, set a little in front of the wall.
static func _terminus(w: Node3D, body: StaticBody3D, o: Vector3, z_end: float, into: float, wall_mat: Material) -> void:
	var x0 := o.x - 1.79
	var x1 := o.x + 2.0 * MID_X + 1.79
	_box(w, body, Vector3(x0 - 0.5, o.y - 0.6, minf(z_end, z_end - into * 0.6)), Vector3(x1 + 0.5, o.y + SHELL_TOP + 0.5, maxf(z_end, z_end - into * 0.6)), wall_mat)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.08, 0.06)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.95)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.08, 0.08, 0.08)
	for lane in [LANE_W, LANE_E]:
		var cx: float = o.x + lane
		var zb: float = z_end + into * 2.0                        # the barricade face, 2 m in front of the wall
		for k in range(6):
			var mat: Material = red if k % 2 == 0 else white
			_box(w, body, Vector3(cx - 1.2 + k * 0.4, o.y + 0.25, zb - 0.15), Vector3(cx - 0.8 + k * 0.4, o.y + 1.35, zb + 0.15), mat)
		_box(w, body, Vector3(cx - 1.25, o.y + 0.1, zb - 0.5), Vector3(cx + 1.25, o.y + 0.3, zb + 0.5), black)
		_box(w, body, Vector3(cx - 1.25, o.y + 1.35, zb - 0.2), Vector3(cx + 1.25, o.y + 1.5, zb + 0.2), black)
		for dx in [-1.1, 1.1]:
			_box(w, body, Vector3(cx + dx - 0.08, o.y + 0.3, zb - 0.1 - into * 1.0), Vector3(cx + dx + 0.08, o.y + 1.5, zb + 0.1), black)
		_box(w, body, Vector3(cx - 0.06, o.y + 0.3, zb + into * 0.15), Vector3(cx + 0.06, o.y + 0.9, zb + into * 1.8), black)
