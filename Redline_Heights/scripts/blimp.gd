class_name Blimp
extends Node3D
## An advertising blimp that drifts round the whole map, carrying the "Welcome to Redline Heights" picture on both sides. The picture
## glows at night (its own colours), and the blimp has red / green / white navigation lights and a strobe. Ornament only: you cannot board it.

const MODEL := "res://assets/blimp/goodyear_blimp.glb"
const HULL_TEX := "res://assets/blimp/hull_clean.png"
const SIGN_TEX := "res://assets/blimp/welcome.png"
const ALT := 300.0
const SCALE := 1.5
const SPEED := 15.0
const ROUTE := [Vector2(-75, 0), Vector2(400, -250), Vector2(850, -930), Vector2(1250, -1500), Vector2(850, -2000), Vector2(300, -1500), Vector2(-300, -800),
	Vector2(-800, -150), Vector2(-850, 650), Vector2(-400, 1450), Vector2(-50, 2050), Vector2(200, 2550), Vector2(750, 2300), Vector2(1000, 1500), Vector2(800, 600), Vector2(400, 250)]

var _pts: Array = []           # the smoothed closed route, a point every metre or so
var _cum: Array = []           # distance along it
var _len := 0.0
var _s := 0.0
var _model: Node3D
var _strobe: MeshInstance3D
var _t := 0.0
var _nose_sign := 1.0

static func spawn(w: Node) -> void:
	if not ResourceLoader.exists(MODEL): return
	var b := Blimp.new()
	w.add_child(b)

func _ready() -> void:
	_build_route()
	_build_model()
	_s = 0.0
	_place(0.0)

func _build_route() -> void:
	var n := ROUTE.size()
	var raw: Array = []
	for i in range(n):
		var p0: Vector2 = ROUTE[(i - 1 + n) % n]
		var p1: Vector2 = ROUTE[i]
		var p2: Vector2 = ROUTE[(i + 1) % n]
		var p3: Vector2 = ROUTE[(i + 2) % n]
		for k in range(40):
			var t := float(k) / 40.0
			raw.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	_pts = raw
	_cum = [0.0]
	for i in range(1, raw.size() + 1):
		_cum.append(float(_cum[i - 1]) + (raw[i % raw.size()] as Vector2).distance_to(raw[i - 1]))
	_len = _cum[raw.size()]

func _at(s: float) -> Array:
	s = fposmod(s, _len)
	var lo := 0
	var hi := _pts.size()
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if float(_cum[mid]) <= s: lo = mid
		else: hi = mid
	var a: Vector2 = _pts[lo]
	var b: Vector2 = _pts[(lo + 1) % _pts.size()]
	var f := (s - float(_cum[lo])) / maxf(float(_cum[lo + 1]) - float(_cum[lo]), 0.001)
	return [a.lerp(b, f), (b - a).normalized()]

func _build_model() -> void:
	var inst := (load(MODEL) as PackedScene).instantiate() as Node3D
	_model = Node3D.new()
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_model.add_child(inst)
	# the hull's own painted lettering is removed: a clean blue hull with its yellow stripes
	var clean := load(HULL_TEX) as Texture2D
	var hull: MeshInstance3D = null
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var mat := m.get_active_material(0) as BaseMaterial3D
		if mat == null: continue
		if mat.resource_name in ["blimp_sign_1", "blimp_sign_1__PAINT_1", "vehicle_generic_detail2"]:
			var d := mat.duplicate() as BaseMaterial3D
			d.albedo_texture = clean
			m.set_surface_override_material(0, d)
			if mat.resource_name == "blimp_sign_1__PAINT_1": hull = m
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if hull == null: return
	var xf := Metro._xf(hull, inst)
	# radial profile of the envelope about its axis (x = 0, y = middle of the hull's height), taken from the mesh's own vertices
	var verts := PackedVector3Array()
	for v in hull.mesh.get_faces(): verts.append(xf * v)
	var lo := 1e9
	var hi := -1e9
	var ymin := 1e9
	var ymax := -1e9
	for v in verts:
		lo = minf(lo, v.z)
		hi = maxf(hi, v.z)
		ymin = minf(ymin, v.y)
		ymax = maxf(ymax, v.y)
	var yc := (ymin + ymax) * 0.5
	# the tail is the end carrying the fins (they stick out further than the envelope)
	var ext_lo := 0.0
	var ext_hi := 0.0
	for v in verts:
		var r := Vector2(v.x, v.y - yc).length()
		if v.z < lo + 8.0: ext_lo = maxf(ext_lo, r)
		if v.z > hi - 8.0: ext_hi = maxf(ext_hi, r)
	_nose_sign = 1.0 if ext_hi < ext_lo else -1.0          # +1: the nose is at the model's +z
	var zc := (lo + hi) * 0.5 - _nose_sign * 3.0
	var half_len := 15.5
	var bins := 54
	var prof := PackedFloat32Array()
	prof.resize(bins + 1)
	var cnt := PackedInt32Array()
	cnt.resize(bins + 1)
	var rs: Array = []
	for i in range(bins + 1): rs.append([])
	for v in verts:
		var f := (v.z - (zc - half_len - 2.0)) / (2.0 * half_len + 4.0)
		if f < 0.0 or f > 1.0: continue
		var bi := int(f * bins)
		var dx := v.x
		var dy := v.y - yc
		if absf(dy) > 5.0 and absf(dx) < 1.5: continue                         # fin edges
		(rs[bi] as Array).append(Vector2(dx, dy).length())
	for i in range(bins + 1):
		var a: Array = rs[i]
		if a.is_empty():
			prof[i] = prof[i - 1] if i > 0 else 6.0
			continue
		a.sort()
		prof[i] = float(a[mini(int(a.size() * 0.97), a.size() - 1)])
	var sign_tex := load(SIGN_TEX) as Texture2D
	var asp := 2048.0 / 768.0
	var height := 2.0 * half_len / asp
	for side in [1.0, -1.0]:
		var cols := 36
		var rows := 14
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var grid: Array = []
		for ci in range(cols + 1):
			var u := float(ci) / cols
			var z := zc - half_len + u * 2.0 * half_len
			var bi2 := clampi(int((z - (zc - half_len - 2.0)) / (2.0 * half_len + 4.0) * bins), 0, bins)
			var r := float(prof[bi2]) + 0.7
			var col: Array = []
			for ri in range(rows + 1):
				var v2 := float(ri) / rows
				var ang := (v2 - 0.5) * (height / r)             # arc length along the cross-section -> angle
				var p := Vector3(side * r * cos(ang), yc + r * sin(ang), z)
				var uu := u if side > 0.0 else (1.0 - u)         # read left-to-right from outside
				if _nose_sign < 0.0: uu = 1.0 - uu
				col.append([p, Vector2(uu, 1.0 - v2)])
			grid.append(col)
		for ci in range(cols):
			for ri in range(rows):
				var q := [grid[ci][ri], grid[ci + 1][ri], grid[ci + 1][ri + 1], grid[ci][ri + 1]]
				for tri in ([[0, 1, 2], [0, 2, 3]] if side < 0.0 else [[0, 2, 1], [0, 3, 2]]):
					for ix in tri:
						st.set_uv(q[ix][1])
						st.add_vertex(q[ix][0])
		st.generate_normals()
		var dm := StandardMaterial3D.new()
		dm.albedo_texture = sign_tex
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		dm.cull_mode = BaseMaterial3D.CULL_DISABLED
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED          # a self-lit picture: it keeps its colours at night, like a lit sign
		dm.emission_enabled = true
		dm.emission_texture = sign_tex
		dm.emission = Color(1, 1, 1)
		dm.emission_energy_multiplier = 0.0
		CityLights.register_material(dm, Color(1, 1, 1), 0.35)
		dm.emission_texture = sign_tex
		var dmi := MeshInstance3D.new()
		dmi.mesh = st.commit()
		dmi.material_override = dm
		dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.add_child(dmi)                              # the vertices are in the model's own space
	# navigation lights
	var red := _glow(Color(1, 0.05, 0.05), 5.0)
	var green := _glow(Color(0.05, 1, 0.15), 5.0)
	var white := _glow(Color(1, 1, 1), 6.0)
	var tail_z := (hi if _nose_sign < 0.0 else lo) + _nose_sign * 1.0
	var nose_z := (lo if _nose_sign < 0.0 else hi) - _nose_sign * 0.6
	for pr in [[Vector3(-7.4, yc, tail_z), red, 0.35], [Vector3(7.4, yc, tail_z), green, 0.35], [Vector3(0.0, yc + 8.2, tail_z), white, 0.3], [Vector3(0.0, yc, nose_z), white, 0.35]]:
		var sm := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = float(pr[2])
		sp.height = float(pr[2]) * 2.0
		sm.mesh = sp
		sm.material_override = pr[1]
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.add_child(sm)
		sm.position = pr[0]
		if pr[1] == white and sm.position.y > yc + 4.0: _strobe = sm
	var snd := AudioStreamPlayer3D.new()
	var st2 := load("res://assets/audio/vehicles/helicopter_loop.ogg") as AudioStream
	if st2 is AudioStreamOggVorbis: (st2 as AudioStreamOggVorbis).loop = true
	snd.stream = st2
	snd.pitch_scale = 0.42
	snd.volume_db = -14.0
	snd.max_distance = 700.0
	snd.unit_size = 80.0
	_model.add_child(snd)
	snd.play()
	print("blimp: nose ", "+z" if _nose_sign > 0.0 else "-z", " route ", snappedf(_len, 1.0), " m")

func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.6
	CityLights.register_material(m, c, e)
	return m

func _place(delta: float) -> void:
	_s += SPEED * delta
	var a := _at(_s)
	var p: Vector2 = a[0]
	var d: Vector2 = a[1]
	var bob := sin(_s * 0.011) * 6.0
	global_position = Vector3(p.x, ALT + bob, p.y)
	var yaw := atan2(d.x, d.y)
	rotation = Vector3(sin(_s * 0.017) * 0.015, yaw + (0.0 if _nose_sign > 0.0 else PI), sin(_s * 0.013) * 0.02)

func _process(delta: float) -> void:
	_place(delta)
	_t += delta
	if _strobe != null: _strobe.visible = fmod(_t, 1.6) < 0.12 or not Game.is_night
