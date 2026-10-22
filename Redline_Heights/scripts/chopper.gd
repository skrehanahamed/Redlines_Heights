class_name Chopper
extends Node3D
## The player's helicopter (MD-500). Walk up and press E. Space = up, Ctrl = down, W/S = forward/back, A/D = turn,
## Shift = fast. It cannot fly through buildings or the ground. Land (below ~4 m) to get out with E.

const SC := 1.7
const MAX_SPEED := 40.0
const BOOST := 70.0

var pilot: Player = null
var engine := 0.0
var vel := Vector3.ZERO
var yaw := 0.0
var _rotor: Node3D
var _tail: Node3D
var _snd: AudioStreamPlayer3D
var _body_tilt := 0.0
var _roll := 0.0
var _crash_cd := 0.0
var body_rid := RID()
var reach := 0.0                 # extra pick-up distance for big vehicles
var cam_dist := 17.0
var is_npc_piloted := false
var hud_name := "HELICOPTER"
var hud_help := "Space up | Ctrl down | W/S fly | A/D turn | Shift fast | E exit (low: step out; high: bail out with a parachute)"
var crashing := false
var blast_scale := 1.0
var _crash_spin := 0.0
var enter_text := "E - fly the helicopter"

func _ready() -> void:
	add_to_group("player_heli")
	var scene := (load("res://assets/vehicles/heli/md500.glb") as PackedScene).instantiate() as Node3D
	scene.scale = Vector3.ONE * SC
	add_child(scene)
	_rotor = PoliceHeli._pivot_for(scene, "Top_rotor")
	_tail = PoliceHeli._pivot_for(scene, "Tail_Rotor")
	add_solid([[Vector3(0, 1.5, 0.3), Vector3(3.0, 2.6, 6.5)], [Vector3(0, 2.8, -6.0), Vector3(0.8, 0.9, 6.0)]])
	_snd = AudioStreamPlayer3D.new()
	var st := load("res://assets/audio/vehicles/helicopter_loop.ogg") as AudioStream
	if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop = true
	_snd.stream = st
	_snd.max_distance = 500.0
	_snd.unit_size = 30.0
	_snd.volume_db = -80.0
	add_child(_snd)
	_snd.play()
	yaw = rotation.y

## Solid boxes (centre, size) so cars and people cannot drive or walk through the aircraft.
func add_solid(boxes: Array) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	for b in boxes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		cs.shape = bs
		cs.position = b[0]
		body.add_child(cs)
	add_child(body)
	body_rid = body.get_rid()

func _ground_y(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 6.0, 0), p + Vector3(0, -400.0, 0), 1)
	q.exclude = [body_rid]
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return (h.position as Vector3).y if not h.is_empty() else 0.0

func height_above_ground() -> float:
	return global_position.y - _ground_y(global_position) - 0.03

func enter(p: Player) -> void:
	pilot = p
	p.in_heli = self
	Game.in_heli = self
	Game.world.set_view_scale(3.0)
	if Game.camera != null: Game.camera.far = 2600.0
	p.visible = false
	p.shape.disabled = true
	if p.pistol_node != null: p.pistol_node.visible = false

## Returns false (and says why) when too high to get out.
func try_exit(force := false) -> bool:
	if pilot == null: return true
	if not force and height_above_ground() > 4.0:
		bail_out()
		return true
	var p := pilot
	var side := global_transform.basis.x * 3.6
	var pos := global_position + side
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

## Jump out in the air: the player skydives and opens a parachute, the empty helicopter drops, blasts and leaves a scorch mark.
func bail_out() -> void:
	var p := pilot
	if p == null: return
	var start := global_position + global_transform.basis.x * 2.4 + Vector3(0, 0.4, 0)
	p.global_position = start
	p.in_heli = null
	Game.in_heli = null
	Game.world.set_view_scale(1.0)
	if Game.camera != null: Game.camera.far = 900.0
	p.visible = true
	p.shape.disabled = false
	pilot = null
	crashing = true
	_crash_spin = 1.4 if randf() < 0.5 else -1.4
	var hv := Vector3(vel.x, 0, vel.z)
	if hv.length() > 20.0: hv = hv.normalized() * 20.0
	p.start_skydive(hv + Vector3(0, 4.0, 0) + global_transform.basis.x * 3.0)
	Game.message.emit("Bailing out!")

func _explode() -> void:
	var at := global_position
	var par := get_parent()
	var boom := AudioStreamPlayer3D.new()
	boom.stream = load("res://assets/audio/guns_and_gameplay/explosion_rocket_01.ogg") as AudioStream
	boom.max_distance = 700.0
	boom.unit_size = 45.0
	boom.volume_db = 8.0
	boom.pitch_scale = 0.62
	par.add_child(boom)
	boom.global_position = at
	boom.play()
	boom.finished.connect(boom.queue_free)
	var crash := AudioStreamPlayer3D.new()
	crash.stream = load("res://assets/audio/vehicles/crash_wall_01.ogg") as AudioStream
	crash.max_distance = 400.0
	crash.unit_size = 30.0
	crash.volume_db = 4.0
	par.add_child(crash)
	crash.global_position = at
	crash.play()
	crash.finished.connect(crash.queue_free)
	# shock ring on the ground
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.8, 0.5, 0.7)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.6, 0.2)
	tm.material = rm
	ring.mesh = tm
	ring.scale = Vector3(1.0, 0.25, 1.0)
	par.add_child(ring)
	ring.global_position = at + Vector3(0, 0.3, 0)
	var rt := ring.create_tween()
	rt.set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(26.0, 3.0, 26.0) * blast_scale, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_property(rm, "albedo_color:a", 0.0, 0.7)
	rt.chain().tween_callback(ring.queue_free)
	# fireball
	var ball := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 1.0
	bs.height = 2.0
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.65, 0.2, 0.9)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.45, 0.08)
	bmat.emission_energy_multiplier = 3.0
	bs.material = bmat
	ball.mesh = bs
	ball.scale = Vector3(1.5, 1.5, 1.5)
	par.add_child(ball)
	ball.global_position = at + Vector3(0, 1.5, 0)
	var bt := ball.create_tween()
	bt.set_parallel(true)
	bt.tween_property(ball, "scale", Vector3(8.0, 7.0, 8.0) * blast_scale, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bt.tween_property(ball, "position:y", ball.position.y + 4.0, 0.9)
	bt.tween_property(bmat, "albedo_color:a", 0.0, 0.9)
	bt.chain().tween_callback(ball.queue_free)
	# flying wreckage: dark chunks and a spinning rotor blade
	for k in range(int(14 * blast_scale)):
		var ch := RigidBody3D.new()
		var cm := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(randf_range(0.2, 0.7), randf_range(0.1, 0.4), randf_range(0.2, 1.4)) if k > 0 else Vector3(0.15, 0.04, 4.0)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.08, 0.08, 0.09) if k % 3 else Color(0.5, 0.1, 0.08)
		cb.material = cmat
		cm.mesh = cb
		ch.add_child(cm)
		ch.collision_layer = 0
		ch.collision_mask = 1
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = cb.size
		cs.shape = bx
		ch.add_child(cs)
		par.add_child(ch)
		ch.global_position = at + Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1))
		ch.linear_velocity = Vector3(randf_range(-9, 9), randf_range(6, 15), randf_range(-9, 9))
		ch.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		get_tree().create_timer(9.0).timeout.connect(ch.queue_free)
	for k in range(4):
		Fx.crash(par, at + Vector3(randf_range(-2, 2) * blast_scale, 0.8 + k * 0.4, randf_range(-2, 2) * blast_scale), 3.5 * blast_scale)
	var fire := CPUParticles3D.new()
	fire.one_shot = true
	fire.emitting = true
	fire.amount = 90
	fire.lifetime = 1.6
	fire.explosiveness = 0.9
	fire.direction = Vector3.UP
	fire.spread = 60.0
	fire.initial_velocity_min = 4.0
	fire.initial_velocity_max = 15.0
	fire.gravity = Vector3(0, -4, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.5, 0.1)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.4, 0.05)
	fm.emission_energy_multiplier = 4.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = fm
	fire.mesh = sm
	fire.scale_amount_min = 0.5
	fire.scale_amount_max = 2.2
	par.add_child(fire)
	fire.global_position = at + Vector3(0, 0.5, 0)
	fire.finished.connect(fire.queue_free)
	var smoke := fire.duplicate() as CPUParticles3D
	smoke.amount = 40
	smoke.lifetime = 4.0
	smoke.initial_velocity_max = 6.0
	smoke.gravity = Vector3(0, 2.0, 0)
	var smm := StandardMaterial3D.new()
	smm.albedo_color = Color(0.1, 0.1, 0.1, 0.6)
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sm2 := SphereMesh.new()
	sm2.radius = 0.7
	sm2.height = 1.4
	sm2.material = smm
	smoke.mesh = sm2
	smoke.scale_amount_max = 3.0
	par.add_child(smoke)
	smoke.global_position = at + Vector3(0, 1.0, 0)
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.2)
	flash.light_energy = 12.0
	flash.omni_range = 40.0
	par.add_child(flash)
	flash.global_position = at + Vector3(0, 3.0, 0)
	var ft := flash.create_tween()
	ft.tween_property(flash, "light_energy", 0.0, 0.8)
	ft.tween_callback(flash.queue_free)
	_scorch(par, Vector3(at.x, _ground_y(at), at.z))
	var cam := Game.camera as ThirdPersonCamera
	if cam != null and cam.global_position.distance_to(at) < 200.0: cam.add_shake(0.8)
	for d in get_tree().get_nodes_in_group("peds"):
		if (d as Node3D).global_position.distance_to(at) < 9.0 * blast_scale and d.has_method("hit"):
			d.hit(80.0, ((d as Node3D).global_position - at).normalized(), false)
	queue_free()

## A black blast mark that stays on the ground (it fades only after a long time).
func _scorch(par: Node, ground: Vector3) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	m.mesh = q
	var mat := StandardMaterial3D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 0.85, 1.0])
	grad.colors = PackedColorArray([Color(0.02, 0.02, 0.02, 0.95), Color(0.04, 0.035, 0.03, 0.9), Color(0.08, 0.06, 0.05, 0.4), Color(0.1, 0.08, 0.06, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	mat.albedo_texture = gt
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3(13.0 * blast_scale, 1, 13.0 * blast_scale)
	par.add_child(m)
	m.global_position = ground + Vector3(0, 0.05, 0)
	m.rotation.y = randf() * TAU

func _physics_process(delta: float) -> void:
	_crash_cd = maxf(0.0, _crash_cd - delta)
	var target_engine := 1.0 if (pilot != null or is_npc_piloted) else 0.0
	engine = move_toward(engine, target_engine, delta * (0.35 if target_engine > engine else 0.25))
	if _rotor != null: _rotor.rotate_y(delta * 42.0 * engine)
	if _tail != null: _tail.rotate_x(delta * 52.0 * engine)
	_snd.volume_db = lerpf(-80.0, 3.0, engine)
	_snd.pitch_scale = 0.7 + engine * 0.35 + vel.length() * 0.002
	var move := Vector2.ZERO
	var lift := 0.0
	var turn := 0.0
	if pilot != null and not Game.dead and not get_tree().paused:
		move.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		turn = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		lift = Input.get_action_strength("jump") - Input.get_action_strength("walk_slow")
	var spd := BOOST if Input.is_action_pressed("sprint") else MAX_SPEED
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var power := engine if engine > 0.85 else 0.0                # no lift or thrust until the rotors are up to speed
	yaw += turn * delta * 1.1 * power
	var want := fwd * move.y * spd * power
	vel.x = lerpf(vel.x, want.x, clampf(delta * 0.9, 0.0, 1.0))
	vel.z = lerpf(vel.z, want.z, clampf(delta * 0.9, 0.0, 1.0))
	var gy := _ground_y(global_position)
	var floor_y := gy + 0.03
	var airborne := global_position.y > floor_y + 0.15
	if power > 0.0:
		var vy_want := lift * 13.0
		vel.y = lerpf(vel.y, vy_want, clampf(delta * 2.0, 0.0, 1.0))
	else:
		vel.y = lerpf(vel.y, (-30.0 if crashing else -9.0) if airborne else 0.0, clampf(delta * (2.5 if crashing else 1.5), 0.0, 1.0))
		if crashing: yaw += _crash_spin * delta
		vel.x = lerpf(vel.x, 0.0, clampf(delta * 2.0, 0.0, 1.0))
		vel.z = lerpf(vel.z, 0.0, clampf(delta * 2.0, 0.0, 1.0))
	# do not fly into buildings: look ahead along the motion (and 8 m around) for solid geometry
	var space := get_world_3d().direct_space_state
	var hv := Vector3(vel.x, 0, vel.z)
	if hv.length() > 1.0:
		var from := global_position + Vector3(0, 0.5, 0)
		var to := from + hv.normalized() * (7.5 + hv.length() * delta)
		var q := PhysicsRayQueryParameters3D.create(from, to, 1)
		q.exclude = [body_rid]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			if hv.length() > 14.0 and _crash_cd == 0.0 and pilot != null:
				_crash_cd = 1.0
				Game.health -= 8.0
				Fx.crash(get_parent(), hit.position, 1.0)
				var cam := Game.camera as ThirdPersonCamera
				if cam != null: cam.add_shake(0.6)
			vel.x = 0.0
			vel.z = 0.0
			global_position -= hv.normalized() * 0.4
	# roof above?
	if vel.y > 0.0:
		var qu := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, 4.0, 0), 1)
		qu.exclude = [body_rid]
		if not space.intersect_ray(qu).is_empty(): vel.y = 0.0
	global_position += vel * delta
	if global_position.y < floor_y:
		global_position.y = floor_y
		if crashing:
			_explode()
			return
		if vel.y < 0.0: vel.y = 0.0
	# keep on the map
	global_position.x = clampf(global_position.x, -CityData.half + 20.0, CityData.half - 20.0)
	global_position.z = clampf(global_position.z, -CityData.half + 20.0, CityData.half - 20.0)
	if global_position.y > 420.0: global_position.y = 420.0
	# lean into the movement
	var lean := clampf(move.y * 0.14 * power, -0.14, 0.2)
	_body_tilt = lerpf(_body_tilt, lean, clampf(delta * 2.0, 0.0, 1.0))
	_roll = lerpf(_roll, turn * 0.22 * power, clampf(delta * 2.0, 0.0, 1.0))
	rotation = Vector3(_body_tilt, yaw, _roll)
