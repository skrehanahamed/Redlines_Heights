class_name Airplane
extends Chopper
## A flyable aeroplane. Walk up, press E. W/S = throttle / brake (S also backs it out of its stand), A/D = steer
## on the ground and bank-and-turn in the air, Space = pull up, Ctrl = push down, Shift = afterburner boost.
## Roll along the runway past rotation speed, pull up to take off. Land gently on the runway to get out with E.

const SPECS := {
	"passenger": {"model": "res://assets/planes/air_india_plane.glb", "len": 37.0, "name": "AIRLINER", "rot": 46.0, "max": 120.0, "boost": 160.0, "accel": 12.0, "turn": 0.42, "pitch": 0.38},
	"boeing": {"model": "res://assets/planes/southwest_airlines_boeing_737.glb", "len": 38.0, "name": "BOEING 737", "rot": 46.0, "max": 125.0, "boost": 165.0, "accel": 12.0, "turn": 0.42, "pitch": 0.38},
	"private": {"model": "res://assets/planes/airplane_crj-900_cityjet.glb", "len": 26.0, "name": "PRIVATE JET", "rot": 36.0, "max": 150.0, "boost": 200.0, "accel": 18.0, "turn": 0.6, "pitch": 0.55},
}

var kind := "passenger"
var speed := 0.0
var pitch := 0.0
var _spec: Dictionary
var _floor_off := 0.0

func _ready() -> void:
	add_to_group("player_heli")
	_spec = SPECS[kind]
	hud_name = _spec.name
	hud_help = "W/S throttle | A/D turn | Space pull up | Ctrl push down | Shift boost | E exit (on the ground, slowly)"
	enter_text = "E - fly the %s" % String(_spec.name).to_lower()
	var scene := (load(_spec.model) as PackedScene).instantiate() as Node3D
	var bb := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = Car._xf_rel(mi, scene) * (mi as MeshInstance3D).get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	var sc: float = float(_spec.len) / bb.size.z
	scene.scale = Vector3.ONE * sc
	scene.position = Vector3(-bb.get_center().x * sc, -bb.position.y * sc, -bb.get_center().z * sc)
	add_child(scene)
	var sx := bb.size.x * sc
	var sy := bb.size.y * sc
	var sz := float(_spec.len)
	add_solid([
		[Vector3(0, sy * 0.5, 0), Vector3(sx * 0.11, sy * 0.5, sz)],
		[Vector3(0, sy * 0.3, sz * 0.12), Vector3(sx, 0.35, sz * 0.22)],
		[Vector3(0, sy * 0.78, -sz * 0.44), Vector3(0.4, sy * 0.42, sz * 0.12)],
		[Vector3(0, sy * 0.6, -sz * 0.46), Vector3(sx * 0.36, 0.3, sz * 0.1)]])
	reach = float(_spec.len) * 0.55
	cam_dist = float(_spec.len) * 1.5
	_snd = AudioStreamPlayer3D.new()
	var st := load("res://assets/audio/vehicles/helicopter_loop.ogg") as AudioStream
	if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop = true
	_snd.stream = st
	_snd.max_distance = 900.0
	_snd.unit_size = 60.0
	_snd.volume_db = -80.0
	add_child(_snd)
	_snd.play()
	rotation_order = EULER_ORDER_YXZ
	yaw = rotation.y

func height_above_ground() -> float:
	return global_position.y - _ground_y(global_position) - 0.12

func try_exit(force := false) -> bool:
	if pilot == null: return true
	if not force and (height_above_ground() > 1.0 or speed > 6.0):
		if height_above_ground() > 12.0:
			blast_scale = clampf(float(_spec.len) / 14.0, 1.5, 3.0)
			bail_out()                  # the plane flies on, pilotless, until it hits the ground
			return true
		Game.message.emit("Land and slow down first")
		return false
	var p := pilot
	var pos := global_position + global_transform.basis.x * (float(_spec.len) * 0.3)
	pos.y = _ground_y(pos) + 0.3
	p.global_position = pos
	p.in_heli = null
	Game.in_heli = null
	Game.world.set_view_scale(1.0)
	if Game.camera != null: Game.camera.far = 900.0
	p.visible = true
	p.shape.disabled = false
	p.velocity = Vector3.ZERO
	if p.pistol_node != null and p.weapon == 1: p.pistol_node.visible = true
	pilot = null
	return true

func _physics_process(delta: float) -> void:
	_crash_cd = maxf(0.0, _crash_cd - delta)
	var driven := pilot != null and not Game.dead and not get_tree().paused
	if crashing:
		_crash_cd = 1.0
	var thr := 0.0
	var turn := 0.0
	var pull := 0.0
	if driven:
		thr = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		turn = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		pull = Input.get_action_strength("jump") - Input.get_action_strength("walk_slow")
	engine = move_toward(engine, 1.0 if (driven and thr > -0.5) else 0.15 if driven else 0.0, delta * 0.5)
	var vmax: float = _spec.boost if Input.is_action_pressed("sprint") and driven else _spec.max
	var gy := _ground_y(global_position)
	var floor_y := gy + 0.12
	var airborne := global_position.y > floor_y + 0.3
	var rot_speed: float = _spec.rot
	# throttle
	if thr > 0.0:
		speed = move_toward(speed, vmax, float(_spec.accel) * thr * delta)
	elif thr < 0.0:
		var brake := 12.0 if not airborne else 5.0
		speed = move_toward(speed, -5.0 if not airborne else 0.0, brake * -thr * delta)
	else:
		speed = move_toward(speed, 0.0, (2.5 if not airborne else 0.6) * delta)
	if speed > vmax: speed = move_toward(speed, vmax, 25.0 * delta)
	if crashing:
		speed = move_toward(speed, maxf(speed * 0.9, 40.0), 8.0 * delta)         # keeps its speed while it falls
		engine = move_toward(engine, 0.3, delta * 0.2)
	var flying := airborne and speed > rot_speed * 0.78 and not crashing
	# steering: nose wheel on the ground, bank and turn in the air
	if not airborne:
		yaw += turn * float(_spec.turn) * clampf(absf(speed) / 6.0, 0.0, 1.0) * signf(speed) * delta * 1.2
	else:
		yaw += turn * float(_spec.turn) * delta * (1.0 if flying else 0.3)
	# pitch: pull up only once fast enough, otherwise the nose stays on the runway
	var pitch_rate: float = _spec.pitch
	if not airborne:
		if pull > 0.0 and speed > rot_speed: pitch = move_toward(pitch, 0.3, pitch_rate * pull * delta)
		else: pitch = move_toward(pitch, 0.0, 0.8 * delta)
	elif flying:
		if absf(pull) > 0.01: pitch = clampf(pitch + pull * pitch_rate * delta, -0.6, 0.5)
		else: pitch = move_toward(pitch, 0.0, 0.12 * delta)
	elif crashing:
		pitch = move_toward(pitch, -0.42, 0.14 * delta)          # nose down, spiralling
		yaw += _crash_spin * 0.35 * delta
	else:
		pitch = move_toward(pitch, -0.55, 0.45 * delta)          # stalled: the nose drops
	var fwd := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var vy := fwd.y * speed
	if airborne and not flying and not crashing: vy -= 18.0
	if crashing: vy = fwd.y * speed - 6.0
	vel = Vector3(fwd.x * speed, vy if airborne or pitch > 0.02 and speed > rot_speed else 0.0, fwd.z * speed)
	# nothing solid ahead: stop dead against buildings and fences
	var hv := Vector3(vel.x, 0, vel.z)
	if hv.length() > 1.0:
		var from := global_position + Vector3(0, 2.5, 0)
		var to := from + hv.normalized() * (float(_spec.len) * 0.55 + hv.length() * delta)
		var hq := PhysicsRayQueryParameters3D.create(from, to, 1)
		hq.exclude = [body_rid]
		var hit := get_world_3d().direct_space_state.intersect_ray(hq)
		if not hit.is_empty():
			if hv.length() > 15.0 and _crash_cd == 0.0 and pilot != null:
				_crash_cd = 1.0
				Game.health -= 25.0
				Fx.crash(get_parent(), hit.position, 2.0)
				var cam := Game.camera as ThirdPersonCamera
				if cam != null: cam.add_shake(1.0)
			speed = 0.0
			vel = Vector3.ZERO
	global_position += vel * delta
	if global_position.y <= floor_y:
		if crashing:
			_explode()
			return
		if airborne and vel.y < -9.0 and _crash_cd == 0.0 and pilot != null:
			_crash_cd = 1.0
			Game.health -= clampf(-vel.y * 2.0, 10.0, 60.0)
			Fx.crash(get_parent(), global_position, 1.5)
		global_position.y = floor_y
		if pitch < 0.0: pitch = move_toward(pitch, 0.0, 2.0 * delta)
	global_position.x = clampf(global_position.x, -CityData.half + 20.0, CityData.half - 20.0)
	global_position.z = clampf(global_position.z, -CityData.half + 20.0, CityData.half - 20.0)
	if global_position.y > 1200.0: global_position.y = 1200.0
	_snd.volume_db = lerpf(-80.0, 6.0, engine)
	_snd.pitch_scale = 0.55 + engine * 0.3 + absf(speed) * 0.004
	_roll = lerpf(_roll, (_crash_spin * 0.45 if crashing else turn * 0.5 if flying else 0.0), clampf(delta * 1.8, 0.0, 1.0))
	rotation = Vector3(-pitch, yaw, _roll)


