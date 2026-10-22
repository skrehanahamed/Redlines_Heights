class_name MetroTrain
extends Node3D
## A metro train circling the line: town station track 1 (towards the island), island station track 1, then on through the
## stub beyond it and across onto track 2 (towards the town), island track 2, town track 2, and through the north stub back
## onto track 1. Two trains run it, half a lap apart.

var start_stop := 0            # 0: the west track, nose to +z, starting at Atlanta Court;  1: the east track, nose to -z, starting at Island Plaza
var _zs: Array = []            # standing z of each station (0 Atlanta Court, 1 Island Plaza)
var _cur := 0                  # the station it is at, or has just left
var _tgt := 1                  # the station it is heading for
var _face := 1.0               # which way the nose points along z (it never turns round: it reverses back out of the last stop)
var _mv := 1.0                 # which way it is moving along z
var _z := 0.0
var _x := 0.0
var _y := 0.0
var _v := 0.0
var _wait := 6.0
var _stage := 0                # announcements already made during this stop
var _model: Node3D
var _ab: AnimatableBody3D
var _rumble: AudioStreamPlayer3D
var _chime: AudioStreamPlayer3D
var _beep: AudioStreamPlayer3D
var _pa: AudioStreamPlayer3D         # the car's own announcements
var _ann_arriving := false           # the arrival has been announced for the leg in progress
var _prev_want := 0.0
var _pa_in: AudioStreamPlayer       # the car's announcements: heard only by someone inside it
static var riding: MetroTrain = null      # the train the player is inside with its doors shut, if any (the camera is then locked)
var _half_len := 15.6                      # half the length of the train
var cam_back := 23.0                       # how far behind the train the locked camera sits
var _slide := 0.78                         # how far each door leaf slides
var _syd := false
var ride_end := 1.0                        # which end of the car the locked camera sits at: +1 / -1 along the train's z

func _ready() -> void:
	var oa: Vector3 = Metro.L.a.o
	var ob: Vector3 = Metro.L.b.o
	_y = oa.y
	var sz := Metro.STOP_Z
	_zs = [oa.z + sz, ob.z + sz]
	_x = oa.x + (Metro.LANE_W if start_stop == 0 else Metro.LANE_E)
	_face = 1.0 if start_stop == 0 else -1.0
	_cur = 0 if start_stop == 0 else 1
	_tgt = 1 - _cur
	_z = _zs[_cur]
	_mv = signf(float(_zs[_tgt]) - _z)
	if USE_R62 and ResourceLoader.exists(R62):
		_model = Node3D.new()
		add_child(_model)
		_make_r62()
		_make_sounds()
		for k in range(4):
			var ol3 := OmniLight3D.new()
			ol3.position = Vector3(0.0, 3.2, -11.5 + k * 7.7)
			ol3.omni_range = 9.0
			ol3.light_energy = 1.0
			ol3.light_color = Color(1.0, 0.97, 0.9)
			ol3.shadow_enabled = false
			_model.add_child(ol3)
	elif USE_SYDNEY and ResourceLoader.exists(SYD):
		_model = Node3D.new()
		add_child(_model)
		_make_sydney()
		_make_sounds()
		for k in range(4):
			var ol2 := OmniLight3D.new()
			ol2.position = Vector3(0.0, 3.3, (-16.0 + k * 10.7))
			ol2.omni_range = 14.0
			ol2.light_energy = 1.1
			ol2.light_color = Color(1.0, 0.97, 0.9)
			ol2.shadow_enabled = false
			_model.add_child(ol2)
	else:
		_model = (load(Metro.TRN) as PackedScene).instantiate() as Node3D
		add_child(_model)
		for mi in _model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_make_doors_and_interior()
		_make_sounds()
		for k in range(2):
			var ol := OmniLight3D.new()
			ol.position = Vector3(0.0, 2.0, 11.0 if k == 0 else -11.0)
			ol.omni_range = 16.0
			ol.light_energy = 1.2
			ol.light_color = Color(1.0, 0.95, 0.8)
			ol.shadow_enabled = false
			_model.add_child(ol)
	_wait = 4.0 + start_stop * 5.0
	_place()

func _place() -> void:
	var before := global_transform
	global_position = Vector3(_x, _y, _z)
	rotation.y = 0.0 if _face > 0.0 else PI
	_carry(before)
	if _ab != null: _ab.global_transform = global_transform         # an animatable body does not follow its parent: it is moved by hand

func _physics_process(delta: float) -> void:
	_update_doors(delta)
	_check_rider()
	_update_sounds(delta)
	_spin_wheels(delta)
	if _wait > 0.0:
		_wait -= delta
		_v = 0.0
		# what is said while standing at the platform
		if _stage == 0 and _wait < 11.0:
			_stage = 1
			_say("train_to_%s" % Metro.SLUGS[_tgt])
		if _stage == 1 and _wait < 7.5:
			_stage = 2
			Metro.announce(_cur, "plat_departing_%s" % Metro.SLUGS[_cur])
		if _stage == 2 and _wait < 2.5:
			_stage = 3
			_say("train_doors_closing")
		return
	# running: it reverses out of a last stop, so its nose points the same way going and coming back
	var goal: float = _zs[_tgt]
	var dist := (goal - _z) * _mv
	_v = minf(_v + 1.8 * delta, 44.0)
	_v = minf(_v, sqrt(2.0 * 1.9 * maxf(dist - 0.3, 0.0)) + 0.3)
	_z += _mv * _v * delta
	if _v > 0.5: ride_end = signf(_mv * _face)       # the camera rides behind the way it is travelling
	if dist > 170.0: _ann_arriving = false
	if dist < 150.0 and not _ann_arriving:
		_ann_arriving = true
		Metro.announce(_tgt, "plat_arriving_%s" % Metro.SLUGS[_tgt])
		_say("train_arrive_%s" % Metro.SLUGS[_tgt])
	if dist < 0.4:
		_z = goal
		_v = 0.0
		_cur = _tgt
		_tgt = 1 - _cur
		_mv = signf(float(_zs[_tgt]) - _z)
		_wait = 14.0
		_stage = 0
		_ann_arriving = false
		_chime.play()
		_beep.play()
	_place()

# ------------------------------------------------------------------ doors, interior, boarding
## Door pairs on the platform side (+x of the train), by their centre along the train; each pair is two leaves 0.79 m wide.
const R62 := "res://assets/metro/subway_car_r62a.glb"
const USE_R62 := true            # two cars of the NYC R62A (15.6 m each): short enough for the station
const USE_SYDNEY := false      # the Sydney train (assets/metro) needs a longer platform; the yellow Berlin train is used for now
const SYD := "res://assets/metro/sydney_metro_driverless_train__alstom_metropolis.glb"
const SYD_XC := -20.16         # the middle of the whole train, in the model's own x
const DOOR_Z := [-12.56, -7.82, -3.06, 3.06, 7.82, 12.56]
const DOOR_HALF := 0.79
const DOOR_Y0 := 1.25
const DOOR_Y1 := 3.38
const SKIN_X := 0.9
const FLOOR_Y := 1.2

var _leaves: Array = []         # [{mi, z0, dir}] z0 = closed position (0), dir = -1 / +1 slide direction along z
var _open := 0.0                # 0 closed .. 1 open
var _door_shapes: Array = []    # CollisionShape3D of each door gap in the wall (disabled while open)

func _make_doors_and_interior() -> void:
	var mi := _model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var xf := Metro._xf(mi, _model)
	var inv := xf.affine_inverse()
	var mat0 := mi.get_active_material(0)
	var body_out := DoorSlicer._new_out()
	var leaf_out: Array = []
	for k in range(DOOR_Z.size() * 2): leaf_out.append(DoorSlicer._new_out())
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nn = arr[Mesh.ARRAY_NORMAL]
	var uu = arr[Mesh.ARRAY_TEX_UV]
	var ids: PackedInt32Array = PackedInt32Array()
	if arr[Mesh.ARRAY_INDEX] != null: ids = arr[Mesh.ARRAY_INDEX]
	else:
		ids.resize(v.size())
		for i in range(v.size()): ids[i] = i
	for t in range(ids.size() / 3):
		var poly: Array = []
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		for k in range(3):
			var i := ids[t * 3 + k]
			var pm := xf * v[i]
			lo = lo.min(pm)
			hi = hi.max(pm)
			poly.append({"p": pm, "uv": (uu[i] if uu != null else Vector2.ZERO), "n": ((xf.basis * nn[i]).normalized() if nn != null else Vector3.UP)})
		var rest: Array = [poly]
		if lo.x > SKIN_X and hi.y > DOOR_Y0 and lo.y < DOOR_Y1:
			for di in range(DOOR_Z.size()):
				var zc: float = DOOR_Z[di]
				if hi.z < zc - DOOR_HALF or lo.z > zc + DOOR_HALF: continue
				var next: Array = []
				for pc in rest:
					var cur: Array = pc
					for plane in [[2, zc - DOOR_HALF, 1.0], [2, zc + DOOR_HALF, -1.0], [1, DOOR_Y0, 1.0], [1, DOOR_Y1, -1.0]]:
						if cur.size() < 3: break
						var sp: Array = DoorSlicer._split(cur, plane[0], plane[1], plane[2])
						if (sp[1] as Array).size() >= 3: next.append(sp[1])
						cur = sp[0]
					if cur.size() >= 3:
						var sp2: Array = DoorSlicer._split(cur, 2, zc, 1.0)       # inside = the half at z >= zc
						DoorSlicer._emit(sp2[0], leaf_out[di * 2 + 1])
						DoorSlicer._emit(sp2[1], leaf_out[di * 2])
				rest = next
		for pc in rest: DoorSlicer._emit(pc, body_out)
	var out_mesh := _to_mesh(body_out, inv, mat0)
	mi.mesh = out_mesh
	# the door leaves
	for k in range(leaf_out.size()):
		var lm := _to_mesh(leaf_out[k], Transform3D.IDENTITY, mat0)         # leaves are kept in the train's own space so they slide along it
		if lm == null: continue
		var leaf := MeshInstance3D.new()
		leaf.mesh = lm
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(leaf)
		_leaves.append({"mi": leaf, "dir": -1.0 if k % 2 == 0 else 1.0})
	# the inside: the shell's back faces (cull front) in a light interior colour, a little inside the outer skin
	if mat0 is StandardMaterial3D:
		var inner := mat0.duplicate() as StandardMaterial3D
		inner.cull_mode = BaseMaterial3D.CULL_FRONT
		inner.albedo_color = Color(0.93, 0.88, 0.74)
		var imi := MeshInstance3D.new()
		imi.mesh = out_mesh
		imi.material_override = inner
		imi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.get_parent().add_child(imi)
		imi.transform = mi.transform
	# collision: a moving platform, so a rider is carried
	var ab := AnimatableBody3D.new()
	ab.name = "TrainBody"
	_ab = ab
	ab.sync_to_physics = true
	ab.collision_layer = 1
	add_child(ab)
	var L := 15.6
	var bx := func(pos: Vector3, size: Vector3) -> CollisionShape3D:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		ab.add_child(cs)
		return cs
	bx.call(Vector3(0.55, FLOOR_Y - 0.12, 0), Vector3(3.9, 0.24, 2.0 * L))                 # floor, reaching out across the gap to the platform edge
	bx.call(Vector3(0, 3.95, 0), Vector3(2.8, 0.2, 2.0 * L))                               # roof
	bx.call(Vector3(-1.38, 2.6, 0), Vector3(0.1, 2.8, 2.0 * L))                            # the far wall
	bx.call(Vector3(0, 2.6, -L - 0.05), Vector3(2.8, 2.8, 0.1))                            # ends
	bx.call(Vector3(0, 2.6, L + 0.05), Vector3(2.8, 2.8, 0.1))
	var edges: Array = [-L]
	for zc in DOOR_Z:
		edges.append(zc - DOOR_HALF)
		edges.append(zc + DOOR_HALF)
	edges.append(L)
	for k in range(0, edges.size(), 2):
		var za: float = edges[k]
		var zb: float = edges[k + 1]
		bx.call(Vector3(1.38, 2.6, (za + zb) * 0.5), Vector3(0.1, 2.8, zb - za))           # wall between doors
	for zc in DOOR_Z:
		bx.call(Vector3(1.38, (DOOR_Y1 + 3.95) * 0.5, zc), Vector3(0.1, 3.95 - DOOR_Y1, 2.0 * DOOR_HALF))   # above each door
		_door_shapes.append(bx.call(Vector3(1.38, (DOOR_Y0 + DOOR_Y1) * 0.5, zc), Vector3(0.1, DOOR_Y1 - DOOR_Y0, 2.0 * DOOR_HALF)))
	_build_interior()

static func _to_mesh(o: Dictionary, inv: Transform3D, mat: Material) -> ArrayMesh:
	if (o.v as Array).is_empty(): return null
	var vs := PackedVector3Array(o.v)
	var ns := PackedVector3Array(o.n)
	for i in range(vs.size()):
		vs[i] = inv * vs[i]
		ns[i] = (inv.basis * ns[i]).normalized()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = vs
	a[Mesh.ARRAY_NORMAL] = ns
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array(o.uv)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.surface_set_material(0, mat)
	return m

## Seats along both walls between the doors, hand poles beside every door, light strips on the ceiling.
func _build_interior() -> void:
	var seat := StandardMaterial3D.new()
	seat.albedo_color = Color(0.15, 0.25, 0.55)
	var back := StandardMaterial3D.new()
	back.albedo_color = Color(0.12, 0.2, 0.46)
	var pole := StandardMaterial3D.new()
	pole.albedo_color = Color(0.85, 0.85, 0.88)
	pole.metallic = 0.7
	pole.roughness = 0.35
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1, 1, 1)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.97, 0.88)
	lamp.emission_energy_multiplier = 2.0
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_color = Color(0.32, 0.33, 0.35)
	floor_m.roughness = 0.9
	_in_box(Vector3(0, FLOOR_Y + 0.01, 0), Vector3(2.5, 0.02, 31.0), floor_m)
	var gaps: Array = [-15.0]
	for zc in DOOR_Z:
		gaps.append(zc - 1.05)
		gaps.append(zc + 1.05)
	gaps.append(15.0)
	for side in [-1.0, 1.0]:
		for k in range(0, gaps.size(), 2):
			var za: float = gaps[k]
			var zb: float = gaps[k + 1]
			if zb - za < 0.8: continue
			var zc2 := (za + zb) * 0.5
			var x: float = side * 1.12
			_in_box(Vector3(x, FLOOR_Y + 0.45, zc2), Vector3(0.45, 0.12, zb - za), seat)
			_in_box(Vector3(x, FLOOR_Y + 0.22, zc2), Vector3(0.4, 0.4, zb - za - 0.1), back)
			_in_box(Vector3(side * 1.31, FLOOR_Y + 0.95, zc2), Vector3(0.06, 0.55, zb - za), back)
	for zc in DOOR_Z:
		for dz in [-1.1, 1.1]:
			_in_box(Vector3(0.95, FLOOR_Y + 1.35, zc + dz), Vector3(0.05, 2.7, 0.05), pole)
	for k in range(8):
		var zl := -13.5 + k * 3.85
		_in_box(Vector3(0, 3.78, zl), Vector3(0.5, 0.04, 1.4), lamp)

func _in_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)

func _update_doors(delta: float) -> void:
	var want := 1.0 if (_wait > 2.5 and _v < 0.05) else 0.0
	_open = move_toward(_open, want, delta * 0.9)
	for lf in _leaves:
		if lf.has("off"):
			(lf.mi as Node3D).position = (lf.off as Vector3) + Vector3(0.04 * _open, 0.0, float(lf.dir) * _slide * _open)
		elif lf.has("base"):
			(lf.mi as Node3D).transform = Transform3D(Basis(), Vector3(0.0, 0.0, float(lf.dir) * _slide * _open)) * (lf.base as Transform3D)
		else:
			(lf.mi as Node3D).position = Vector3(0.04 * _open, 0.0, float(lf.dir) * _slide * _open)
	var open_now := _open > 0.5
	for cs in _door_shapes:
		(cs as CollisionShape3D).disabled = open_now

## The player is "riding" when inside this car with the doors shut. The camera is then fixed at the back of the car.
func _check_rider() -> void:
	var p := Game.player as Node3D
	if p == null or not is_instance_valid(p) or Game.in_car != null or Game.in_heli != null:
		if riding == self: riding = null
		return
	var lp := to_local(p.global_position)
	var inside := absf(lp.x) < 1.3 and absf(lp.z) < _half_len - 0.4 and lp.y > FLOOR_Y - 0.3 and lp.y < 3.6
	var shut := _open < 0.05
	if inside and shut:
		if riding != self:
			for spk in Metro.pa:
				if spk != null: (spk as AudioStreamPlayer3D).stop()        # the station's speakers are not heard once the doors are shut
		riding = self
	elif riding == self and (not inside or _open > 0.25):
		riding = null

## Whoever is inside the car is carried with it exactly (the physics engine's own carrying slips when the train brakes hard), so
## braking or arriving never throws the player out of the car. Godot's own platform carrying is switched off while inside.
var _carrying := false

func _carry(before: Transform3D) -> void:
	var p := Game.player as CharacterBody3D
	if p == null or not is_instance_valid(p): return
	if _player_inside() and Game.in_car == null and Game.in_heli == null:
		if before.origin != global_transform.origin or before.basis != global_transform.basis:
			p.global_position = global_transform * (before.affine_inverse() * p.global_position)
		p.platform_floor_layers = 0
		_carrying = true
		# never out through an end wall, nor through a shut side: the end walls are thin and a fast train can slip past them
		var lp := to_local(p.global_position)
		var cz := clampf(lp.z, -_half_len + 1.05, _half_len - 1.05)
		var cx := lp.x
		if _open < 0.05: cx = clampf(lp.x, -1.12, 1.12)
		if cz != lp.z or cx != lp.x:
			p.global_position = to_global(Vector3(cx, lp.y, cz))
	elif _carrying:
		_carrying = false
		p.platform_floor_layers = 0xFFFFFFFF

# ------------------------------------------------------------------ sounds and announcements
func _make_sounds() -> void:
	_rumble = RailAudio.player(self, RailAudio.rumble(), 90.0, 16.0, -80.0, true)
	_chime = RailAudio.player(self, RailAudio.chime(), 70.0, 14.0, 0.0)
	_beep = RailAudio.player(self, RailAudio.door_beep(), 40.0, 10.0, -2.0)
	_pa_in = AudioStreamPlayer.new()
	_pa_in.volume_db = -9.0              # light: it is only the car's own speaker
	_pa_in.bus = &"Master"
	add_child(_pa_in)

func _player_inside() -> bool:
	var p := Game.player as Node3D
	if p == null or not is_instance_valid(p): return false
	var lp := to_local(p.global_position)
	return absf(lp.x) < 1.6 and absf(lp.z) < _half_len + 0.1 and lp.y > FLOOR_Y - 0.5 and lp.y < 4.0

## The car's own speaker: heard only by someone inside the car, never from the platform.
func _say(file: String) -> void:
	if not _player_inside(): return
	var st := load("res://assets/metro/audio/%s.wav" % file) as AudioStream
	if st == null: return
	_pa_in.stream = st
	_pa_in.play()

func _update_sounds(_delta: float) -> void:
	var sp := clampf(_v / 30.0, 0.0, 1.0)
	_rumble.volume_db = lerpf(-80.0, (4.0 if riding == self else 0.0), clampf(sp * 3.0, 0.0, 1.0))
	_rumble.pitch_scale = 0.6 + sp * 1.0
	# the doors: a warning beep (and the spoken warning) as they begin to close, a beep as they begin to open
	var want := 1.0 if (_wait > 2.5 and _v < 0.05) else 0.0
	if want != _prev_want:
		_beep.play()
		_prev_want = want

# ------------------------------------------------------------------ the Sydney Metro train
## The whole Alstom Metropolis, three cars, 67 m: every part is placed in the
## train's own space (nose to +z, the platform side +x). Each door is its own piece and slides open, the wheels turn.
func _make_sydney() -> void:
	_syd = true
	var inst := (load(SYD) as PackedScene).instantiate() as Node3D
	_half_len = 33.5
	cam_back = _half_len + 7.4
	_slide = 0.92
	var basis_a := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))      # model +x (nose) -> z, model -z (the platform side) -> +x
	var base := Transform3D(basis_a, Vector3(0.0, 0.0, -SYD_XC))
	var leaf_list: Array = []
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var grp := String(m.get_parent().name)
		var xf := Metro._xf(m, inst)
		var cen := xf * m.mesh.get_aabb().get_center()
		if grp.begins_with("panto"): continue
		var tr := base * xf
		var node := MeshInstance3D.new()
		node.mesh = m.mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in range(m.mesh.get_surface_count()):
			var mat := m.get_surface_override_material(si)
			if mat != null: node.set_surface_override_material(si, mat)
		if grp.begins_with("Wheel_"):
			var cl := tr * m.mesh.get_aabb().get_center()
			var pivot := Node3D.new()
			pivot.position = cl
			_model.add_child(pivot)
			node.transform = Transform3D(Basis(), -cl) * tr
			pivot.add_child(node)
			_wheels.append(pivot)
		else:
			node.transform = tr
			_model.add_child(node)
			if grp.begins_with("Door") and cen.z < 0.0:
				leaf_list.append({"mi": node, "base": tr, "z": (tr * m.mesh.get_aabb().get_center()).z})
	# door pairs on the platform side: two leaves a doorway, each slides away from the middle of the pair
	leaf_list.sort_custom(func(a, b): return a.z < b.z)
	var gaps: Array = []
	var i := 0
	while i < leaf_list.size():
		var a: Dictionary = leaf_list[i]
		if i + 1 < leaf_list.size() and absf(float((leaf_list[i + 1] as Dictionary).z) - float(a.z)) < 1.3:
			var b: Dictionary = leaf_list[i + 1]
			_leaves.append({"mi": a.mi, "base": a.base, "dir": -1.0})
			_leaves.append({"mi": b.mi, "base": b.base, "dir": 1.0})
			gaps.append((float(a.z) + float(b.z)) * 0.5)
			i += 2
		else:
			_leaves.append({"mi": a.mi, "base": a.base, "dir": 1.0})
			i += 1
	# solid: a moving platform carrying a floor, roof, ends and walls with a gap for each doorway
	var ab := AnimatableBody3D.new()
	ab.name = "TrainBody"
	_ab = ab
	ab.sync_to_physics = true
	ab.collision_layer = 1
	add_child(ab)
	var L := _half_len
	var bx := func(pos: Vector3, size: Vector3) -> CollisionShape3D:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		ab.add_child(cs)
		return cs
	bx.call(Vector3(0.55, FLOOR_Y - 0.12, 0), Vector3(4.0, 0.24, 2.0 * L))
	bx.call(Vector3(0, 3.95, 0), Vector3(3.0, 0.2, 2.0 * L))
	bx.call(Vector3(-1.5, 2.6, 0), Vector3(0.1, 2.8, 2.0 * L))
	bx.call(Vector3(0, 2.6, -L - 0.05), Vector3(3.0, 2.8, 0.1))
	bx.call(Vector3(0, 2.6, L + 0.05), Vector3(3.0, 2.8, 0.1))
	var half_gap := 0.95
	var edges: Array = [-L]
	for zc in gaps:
		edges.append(float(zc) - half_gap)
		edges.append(float(zc) + half_gap)
	edges.append(L)
	for k in range(0, edges.size(), 2):
		var za: float = edges[k]
		var zb: float = edges[k + 1]
		if zb - za > 0.05: bx.call(Vector3(1.5, 2.6, (za + zb) * 0.5), Vector3(0.1, 2.8, zb - za))
	for zc in gaps:
		bx.call(Vector3(1.5, (DOOR_Y1 + 3.95) * 0.5, float(zc)), Vector3(0.1, 3.95 - DOOR_Y1, 2.0 * half_gap))
		_door_shapes.append(bx.call(Vector3(1.5, (DOOR_Y0 + DOOR_Y1) * 0.5, float(zc)), Vector3(0.1, DOOR_Y1 - DOOR_Y0, 2.0 * half_gap)))

var _wheels: Array = []         # pivots of the wheels (they turn about the axle, the train's x)
var _wheel_angle := 0.0

func _spin_wheels(delta: float) -> void:
	if not _syd or _wheels.is_empty(): return
	_wheel_angle += (_mv * _face * _v) / 0.44 * delta
	for pv in _wheels:
		(pv as Node3D).rotation.x = _wheel_angle

# ------------------------------------------------------------------ the R62A train
## Two R62A cars end to end. Model: long axis x, up y, the platform side is its -z. Train space: nose +z, platform side +x, the floor at
## FLOOR_Y. The three door pairs on the platform side are clipped out of the body shell (each leaf slides along the train).
func _make_r62() -> void:
	var k := 0.00345
	var t0 := Transform3D(Basis(Vector3(0, 0, k), Vector3(0, k, 0), Vector3(-k, 0, 0)), Vector3(238.4 * k, FLOOR_Y + 366.0 * k, 0.0))
	var src := (load(R62) as PackedScene).instantiate() as Node3D
	var door_z := [-4.8, 0.0, 4.8]
	var hw := 0.78
	var y0 := FLOOR_Y
	var y1 := FLOOR_Y + 2.15
	var metal_fix := {}
	var parts: Array = []
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var tr := t0 * Metro._xf(m, src)
		var sp := _r62_split(m.mesh, tr, door_z, hw, y0, y1)
		parts.append({"tr": tr, "split": sp, "mesh": m.mesh})
	var car_z := [-7.95, 7.95]
	var gaps: Array = []
	for ci in range(2):
		var zc: float = car_z[ci]
		for pr in parts:
			var sp2: Dictionary = pr.split
			var node := MeshInstance3D.new()
			node.mesh = sp2.body
			node.transform = Transform3D(Basis(), Vector3(0, 0, zc)) * (pr.tr as Transform3D)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_model.add_child(node)
			_fix_metal(node, metal_fix)
			if sp2.extra != null:
				var ex := MeshInstance3D.new()
				ex.mesh = sp2.extra
				ex.position = Vector3(0, 0, zc)
				ex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_model.add_child(ex)
				_fix_metal(ex, metal_fix)
			for di in range(3):
				for side in range(2):
					var lm = (sp2.leaves as Array)[di * 2 + side]
					if lm == null: continue
					var lf := MeshInstance3D.new()
					lf.mesh = lm
					lf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					_model.add_child(lf)
					_fix_metal(lf, metal_fix)
					_leaves.append({"mi": lf, "dir": -1.0 if side == 0 else 1.0, "off": Vector3(0, 0, zc)})
		for dz in door_z: gaps.append(zc + float(dz))
	src.free()
	_half_len = 15.85
	_slide = 0.8
	# solid: a moving platform with floor, roof, ends and walls with a gap for each doorway
	var ab := AnimatableBody3D.new()
	ab.name = "TrainBody"
	_ab = ab
	ab.sync_to_physics = true
	ab.collision_layer = 1
	add_child(ab)
	var L := _half_len
	var bx := func(pos: Vector3, size: Vector3) -> CollisionShape3D:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		ab.add_child(cs)
		return cs
	bx.call(Vector3(0.55, FLOOR_Y - 0.12, 0), Vector3(3.9, 0.24, 2.0 * L))
	bx.call(Vector3(0, 3.7, 0), Vector3(2.7, 0.2, 2.0 * L))
	bx.call(Vector3(-1.3, 2.5, 0), Vector3(0.1, 2.6, 2.0 * L))
	bx.call(Vector3(0, 2.5, -L - 0.3), Vector3(2.7, 2.6, 0.6))
	bx.call(Vector3(0, 2.5, L + 0.3), Vector3(2.7, 2.6, 0.6))
	var edges: Array = [-L]
	gaps.sort()
	for zc2 in gaps:
		edges.append(float(zc2) - hw)
		edges.append(float(zc2) + hw)
	edges.append(L)
	for i in range(0, edges.size(), 2):
		var za: float = edges[i]
		var zb: float = edges[i + 1]
		if zb - za > 0.05: bx.call(Vector3(1.3, 2.5, (za + zb) * 0.5), Vector3(0.1, 2.6, zb - za))
	for zc3 in gaps:
		bx.call(Vector3(1.3, (y1 + 3.7) * 0.5, float(zc3)), Vector3(0.1, 3.7 - y1, 2.0 * hw))
		_door_shapes.append(bx.call(Vector3(1.3, (y0 + y1) * 0.5, float(zc3)), Vector3(0.1, y1 - y0, 2.0 * hw)))

## Metallic "mirror" paint has nothing to reflect underground: make it a plain brushed steel.
func _fix_metal(node: MeshInstance3D, cache: Dictionary) -> void:
	if node.mesh == null: return
	for si in range(node.mesh.get_surface_count()):
		var m := node.mesh.surface_get_material(si) as BaseMaterial3D
		if m == null or m.metallic < 0.5: continue
		if not cache.has(m):
			var d := m.duplicate() as BaseMaterial3D
			d.metallic = 0.15
			d.roughness = maxf(d.roughness, 0.55)
			cache[m] = d
		node.set_surface_override_material(si, cache[m])

## Splits one mesh: the skin triangles of the platform side that lie in a door box are clipped out. Returns {body, extra, leaves}.
## body keeps the mesh's own vertices (only the clipped triangles are dropped); extra and leaves are in train space.
func _r62_split(mesh: Mesh, tr: Transform3D, door_z: Array, hw: float, y0: float, y1: float) -> Dictionary:
	var out := {"body": mesh, "extra": null, "leaves": [null, null, null, null, null, null]}
	var body := ArrayMesh.new()
	var extra := ArrayMesh.new()
	var leaf_meshes: Array = []
	for i in range(6): leaf_meshes.append(ArrayMesh.new())
	var any := false
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array = PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null: ids = arr[Mesh.ARRAY_INDEX]
		else:
			ids.resize(v.size())
			for i in range(v.size()): ids[i] = i
		var pv := PackedVector3Array()
		pv.resize(v.size())
		for i in range(v.size()): pv[i] = tr * v[i]
		var keep := PackedInt32Array()
		var hits: Array = []
		for t in range(ids.size() / 3):
			var a := pv[ids[t * 3]]
			var b := pv[ids[t * 3 + 1]]
			var c := pv[ids[t * 3 + 2]]
			var lox := minf(a.x, minf(b.x, c.x))
			var hit := false
			if lox > 1.22:
				var hiy := maxf(a.y, maxf(b.y, c.y))
				var loy := minf(a.y, minf(b.y, c.y))
				if hiy > y0 and loy < y1:
					var hiz := maxf(a.z, maxf(b.z, c.z))
					var loz := minf(a.z, minf(b.z, c.z))
					for dz in door_z:
						if hiz > float(dz) - hw and loz < float(dz) + hw:
							hit = true
							break
			if hit: hits.append(t)
			else:
				keep.append(ids[t * 3])
				keep.append(ids[t * 3 + 1])
				keep.append(ids[t * 3 + 2])
		if hits.is_empty():
			body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			body.surface_set_material(body.get_surface_count() - 1, mesh.surface_get_material(si))
			continue
		any = true
		var arr2 := arr.duplicate()
		arr2[Mesh.ARRAY_INDEX] = keep
		if keep.size() >= 3:
			body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
			body.surface_set_material(body.get_surface_count() - 1, mesh.surface_get_material(si))
		var nn = arr[Mesh.ARRAY_NORMAL]
		var uu = arr[Mesh.ARRAY_TEX_UV]
		var rest_out := DoorSlicer._new_out()
		var leaf_out: Array = []
		for i in range(6): leaf_out.append(DoorSlicer._new_out())
		for t in hits:
			var poly: Array = []
			var zlo := 1e9
			var zhi := -1e9
			for kk in range(3):
				var i2 := ids[t * 3 + kk]
				var p := pv[i2]
				zlo = minf(zlo, p.z)
				zhi = maxf(zhi, p.z)
				poly.append({"p": p, "uv": (uu[i2] if uu != null else Vector2.ZERO), "n": ((tr.basis * nn[i2]).normalized() if nn != null else Vector3.UP)})
			var rest: Array = [poly]
			for di in range(door_z.size()):
				var zc: float = door_z[di]
				if zhi < zc - hw or zlo > zc + hw: continue
				var nxt: Array = []
				for pc in rest:
					var cur: Array = pc
					for plane in [[2, zc - hw, 1.0], [2, zc + hw, -1.0], [1, y0, 1.0], [1, y1, -1.0]]:
						if cur.size() < 3: break
						var sp: Array = DoorSlicer._split(cur, plane[0], plane[1], plane[2])
						if (sp[1] as Array).size() >= 3: nxt.append(sp[1])
						cur = sp[0]
					if cur.size() >= 3:
						var sp2: Array = DoorSlicer._split(cur, 2, zc, 1.0)
						DoorSlicer._emit(sp2[1], leaf_out[di * 2])          # z below the middle
						DoorSlicer._emit(sp2[0], leaf_out[di * 2 + 1])
				rest = nxt
			for pc in rest: DoorSlicer._emit(pc, rest_out)
		var mat := mesh.surface_get_material(si)
		var pairs: Array = [[rest_out, extra]]
		for li in range(6): pairs.append([leaf_out[li], leaf_meshes[li]])
		for pair in pairs:
			var o: Dictionary = pair[0]
			if (o.v as Array).is_empty(): continue
			var a2 := []
			a2.resize(Mesh.ARRAY_MAX)
			a2[Mesh.ARRAY_VERTEX] = PackedVector3Array(o.v)
			a2[Mesh.ARRAY_NORMAL] = PackedVector3Array(o.n)
			a2[Mesh.ARRAY_TEX_UV] = PackedVector2Array(o.uv)
			var tgt: ArrayMesh = pair[1]
			tgt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			tgt.surface_set_material(tgt.get_surface_count() - 1, mat)
	out.body = body
	if not any: return {"body": mesh, "extra": null, "leaves": out.leaves}
	if extra.get_surface_count() > 0: out.extra = extra
	for i in range(6):
		if (leaf_meshes[i] as ArrayMesh).get_surface_count() > 0: out.leaves[i] = leaf_meshes[i]
	return out
