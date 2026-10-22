class_name Train
extends StaticBody3D
## The train from the model. Two of them circle the loop in opposite directions, one per track, and stop at both stations.

const TOP_SPEED := 38.0
const ACCEL := 1.4
const BRAKE := 1.8
const WAIT := 18.0

var index := 0                 # 0: track 1, forwards   1: track 2, backwards
var _s := 0.0                  # path distance of the train's centre
var _dir := 1.0
var _off := 0.0
var _v := 0.0
var _wait_t := 4.0
var _target := 1
var _stops := [0.0, 0.0]
var _rumble: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _chime: AudioStreamPlayer3D
var _horned := false
var _inst: Node3D
var _wheels: Array = []        # [pivot, ...] axles that spin
var _wheel_angle := 0.0
var _doors: Array = []         # {pivot, base, slide, open}
var _door_open_t := 0.0        # 0 closed .. 1 open
var _doors_wanted := false
var _station_idx := 0
var _half := Vector3.ONE
var _box_c := Vector3.ZERO

func _ready() -> void:
	collision_layer = 1
	add_to_group("trains")
	var inst := (load(Rail.MODEL) as PackedScene).instantiate() as Node3D
	var tb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if not Rail.TRAIN_STEMS.has(Rail._stem(mi)):
			mi.get_parent().remove_child(mi)
			mi.free()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = Rail._rel(mi, inst) * (mi as MeshInstance3D).get_aabb()
		tb = b if first else tb.merge(b)
		first = false
		(mi as MeshInstance3D).visibility_range_end = 1100.0
	# model: nose +Z, wheels on y = -2.7: centre it on the body origin, wheels on y = 0
	var c := tb.get_center()
	var model := Node3D.new()
	model.position = Vector3(-c.x, -tb.position.y, -c.z)
	model.add_child(inst)
	var holder := Node3D.new()
	holder.rotation.y = PI * 0.5          # nose -> local +X
	holder.add_child(model)
	add_child(holder)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(tb.size.z, tb.size.y - 0.25, tb.size.x)
	cs.shape = bs
	cs.position = Vector3(0, (tb.size.y + 0.25) * 0.5 + 0.05, 0)
	add_child(cs)
	_half = Vector3(bs.size.x, bs.size.y, bs.size.z) * 0.5
	_box_c = cs.position
	_rumble = RailAudio.player(self, RailAudio.rumble(), 380.0, 28.0, -80.0, true)
	_horn = RailAudio.player(self, load("res://assets/audio/vehicles/truck_air_horn_01.ogg") as AudioStream, 900.0, 60.0, 6.0)
	_horn.pitch_scale = 0.55
	_chime = RailAudio.player(self, RailAudio.chime(), 300.0, 30.0, 2.0)
	_stops = [Rail.station_s[0] + c.z, Rail.station_s[1] + c.z]
	if index == 0:
		_dir = 1.0; _off = 0.0; _s = _stops[0]; _target = 1; _wait_t = 14.0; _station_idx = 0
	else:
		_dir = -1.0; _off = Rail.TRACK2; _s = _stops[1]; _target = 0; _wait_t = 20.0; _station_idx = 1
	_inst = inst
	_make_lamps(inst, model)
	_rig_wheels_and_doors()
	_place()

## Night lights: the model's own lamp lenses glow (white at the front, red at the back) and a real spotlight sits at each front
## lamp, so the beam starts at the headlamps. The model's nose is +Z in its own space.
func _make_lamps(inst: Node3D, model: Node3D) -> void:
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var stem := Rail._stem(mi)
		var front := stem == "train lights front" or stem == "train head"
		var back := stem == "back lights"
		if not (front or back): continue
		var m := mi as MeshInstance3D
		for i in range(m.mesh.get_surface_count()):
			var src := m.get_active_material(i) as BaseMaterial3D
			if src == null or src.resource_name != "Light_Texture": continue
			var dup := src.duplicate() as BaseMaterial3D
			m.set_surface_override_material(i, dup)
			CityLights.register_material(dup, Color(1.0, 0.95, 0.82) if front else Color(1.0, 0.1, 0.06), 4.0 if front else 2.5)
	for x in [-0.95, 0.95]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(x, -0.15, 15.15)
		sl.rotation = Vector3(-0.03, PI, 0.0)
		sl.spot_range = 90.0
		sl.spot_angle = 22.0
		sl.spot_attenuation = 0.8
		sl.light_color = Color(1.0, 0.96, 0.85)
		sl.shadow_enabled = false
		model.add_child(sl)
		CityLights.register_light(sl, 9.0)

## Seconds until this train is (next) standing in station idx: 0 while it is there with its doors open.
func seconds_until(idx: int) -> float:
	var v_avg := TOP_SPEED * 0.8
	if _wait_t > 0.0 and _station_idx == idx: return 0.0
	var goal: float = _stops[_target]
	var to_target := fposmod((goal - _s) * _dir, Rail.loop_len)
	if _wait_t > 0.0 and _station_idx != idx:
		return _wait_t + fposmod((_stops[idx] - _s) * _dir, Rail.loop_len) / v_avg
	if _target == idx: return to_target / v_avg
	return to_target / v_avg + WAIT + fposmod((_stops[idx] - goal) * _dir, Rail.loop_len) / v_avg

func s_now() -> float:
	return _s

func _place() -> void:
	var a := Rail.at(_s)
	var p: Vector2 = a[0]
	var d: Vector2 = a[1]
	var n := Vector2(d.y, -d.x)
	var q := p + n * _off
	global_position = Vector3(q.x, 0.12, q.y)
	var heading := d * _dir
	rotation.y = atan2(heading.x, heading.y) - PI * 0.5

## A moving static body does not push anything, so anything caught inside the train's box is thrown clear of the track.
func _shove(delta: float) -> void:
	if _v < 1.0: return
	var targets: Array = []
	if Game.in_car != null: targets.append(Game.in_car)
	elif Game.player != null and is_instance_valid(Game.player): targets.append(Game.player)
	for t in targets:
		var node := t as Node3D
		var lp := to_local(node.global_position) - _box_c
		if absf(lp.x) < _half.x + 1.0 and absf(lp.z) < _half.z + 0.6 and absf(lp.y) < _half.y + 1.0:
			var side := 1.0 if lp.z >= 0.0 else -1.0
			var out := global_transform.basis.z * side
			node.global_position += out * ((_half.z + 1.2) - absf(lp.z))
			if node is Car:
				(node as Car).linear_velocity = out * 6.0 + Vector3.UP * 2.0
			elif node is Player:
				Game.health -= 40.0 * delta * 10.0
				(node as Player).velocity = out * 6.0

func _physics_process(delta: float) -> void:
	_shove(delta)
	# rumble follows speed; the horn sounds as the train pulls out and the chime when it arrives
	_update_moving_parts(delta)
	var sp := clampf(_v / TOP_SPEED, 0.0, 1.0)
	_rumble.volume_db = lerpf(-80.0, 4.0, clampf(sp * 3.0, 0.0, 1.0))
	_rumble.pitch_scale = 0.6 + sp * 1.1
	if _wait_t > 0.0:
		_wait_t -= delta
		_v = 0.0
		_doors_wanted = _wait_t > 3.5
		if _wait_t <= 0.0 and not _horned:
			_horn.play()
		return
	_horned = false
	var goal: float = _stops[_target]
	var dist := fposmod((goal - _s) * _dir, Rail.loop_len)
	var v_brake := sqrt(2.0 * BRAKE * maxf(dist - 0.5, 0.0))
	_v = minf(minf(_v + ACCEL * delta, TOP_SPEED), v_brake)
	if dist < 0.6 or (_v < 0.05 and dist < 3.0):
		_s = goal
		_v = 0.0
		_wait_t = WAIT
		_station_idx = _target
		_target = 1 - _target
		_chime.play()
	else:
		_s += _dir * maxf(_v, 0.3) * delta
	_place()


func _to_inst(n: Node3D) -> Transform3D:
	return _inst.global_transform.affine_inverse() * n.global_transform

## Axles become spinning pivots; each side of each doorway is cut out of its mesh so it can slide open on its own.
func _rig_wheels_and_doors() -> void:
	for mi in _inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var stem := Rail._stem(m)
		if stem == "bacj wheel":
			var xf := _to_inst(m)
			var c := (xf * m.get_aabb()).get_center()
			var pivot := Node3D.new()
			_inst.add_child(pivot)
			pivot.transform = Transform3D(Basis.IDENTITY, c)
			m.reparent(pivot, true)
			_wheels.append(pivot)
		elif stem == "door 1" or stem == "door 2":
			_split_door(m)

func _split_door(m: MeshInstance3D) -> void:
	var xf := _to_inst(m)
	var parent := m.get_parent()
	var local := m.transform
	var bb := xf * m.get_aabb()
	var cz := bb.get_center().z
	for side in [-1.0, 1.0]:
		var am := ArrayMesh.new()
		var any := false
		for si in range(m.mesh.get_surface_count()):
			var arr: Array = m.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for i in range(v.size()): idx[i] = i
			var keep := PackedInt32Array()
			for t in range(idx.size() / 3):
				var c := (xf * v[idx[t * 3]] + xf * v[idx[t * 3 + 1]] + xf * v[idx[t * 3 + 2]]) / 3.0
				if (c.x >= 0.0) == (side > 0.0):
					keep.append(idx[t * 3]); keep.append(idx[t * 3 + 1]); keep.append(idx[t * 3 + 2])
			if keep.is_empty(): continue
			var a2 := []
			a2.resize(Mesh.ARRAY_MAX)
			a2[Mesh.ARRAY_VERTEX] = v
			if arr[Mesh.ARRAY_NORMAL] != null: a2[Mesh.ARRAY_NORMAL] = arr[Mesh.ARRAY_NORMAL]
			if arr[Mesh.ARRAY_TEX_UV] != null: a2[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV]
			a2[Mesh.ARRAY_INDEX] = keep
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
			am.surface_set_material(am.get_surface_count() - 1, m.mesh.surface_get_material(si))
			any = true
		if not any: continue
		var pivot := Node3D.new()
		_inst.add_child(pivot)
		pivot.transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
		var ni := MeshInstance3D.new()
		ni.mesh = am
		ni.visibility_range_end = 1100.0
		pivot.add_child(ni)
		ni.transform = xf
		# slide towards the middle of the car, 1.3 m, along the train's length
		var slide := Vector3(0, 0, -signf(cz - _car_mid(cz)) * 1.3)
		_doors.append({"pivot": pivot, "side": side, "slide": slide})
	m.get_parent().remove_child(m)
	m.free()

func _car_mid(cz: float) -> float:
	# the two cars are centred on about z = 9.6 - 3.7 and -29: pick the nearer car's middle
	return -29.0 if cz < -14.5 else -2.0

func _update_moving_parts(delta: float) -> void:
	_wheel_angle += (_v / 0.66) * delta
	for p in _wheels:
		(p as Node3D).rotation = Vector3(_wheel_angle, 0, 0)
	_door_open_t = move_toward(_door_open_t, 1.0 if _doors_wanted else 0.0, delta / 1.6)
	for d in _doors:
		var pv: Node3D = d.pivot
		var opening := _door_open_t if _opens_here(pv, d.side) else 0.0
		pv.position = (d.slide as Vector3) * smoothstep(0.0, 1.0, opening)

## Only the doors on the platform side (the side the station building is on) open.
func _opens_here(pv: Node3D, side: float) -> bool:
	var door_world := _inst.to_global(Vector3(side * 1.6, 0, 0))
	var centre := _inst.to_global(Vector3.ZERO)
	var off := Vector2(door_world.x - centre.x, door_world.z - centre.z)
	return off.dot(Rail.station_dir[_station_idx]) > 0.0

## Dev: --traintest puts the player's camera beside a stopped train with its doors open.
