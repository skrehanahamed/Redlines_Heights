class_name Ped
extends CharacterBody3D
## A pedestrian: walks a sidewalk loop, flees from danger, can be knocked down.

var model: Node3D
var anim: AnimationPlayer
var hp := 40.0
var state := "walk"           # walk, flee, dead
var loop: Array[Vector3] = []
var wp := 0
var step_dir := 1
var flee_t := 0.0
var flee_from := Vector3.ZERO
var face := 0.0
var cur_anim := ""
var char_id := ""
var is_cop := false
var dead_t := 0.0
var walk_speed := 1.5
var _lod_t := randf()
var open_route := false        # walk the waypoints back and forth instead of looping
var tumbling := false         # flying through the air after being hit by a car
var tumble_ang := 0.0
var tumble_axis := Vector3.RIGHT

func setup(id: String, waypoints: Array[Vector3], start: int, dir: int) -> void:
	char_id = id
	loop = waypoints
	wp = start
	step_dir = dir
	walk_speed = randf_range(1.2, 1.9)
	add_to_group("peds")
	collision_layer = 8
	collision_mask = 1 | 4 | 16
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	model = Game.load_character(id)
	add_child(model)
	model.position = Vector3.ZERO
	model.rotation_degrees.y = 0
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", Game.get_anim_library(id))
	anim.seek(randf() * 1.0)
	play("Walk")

## While seated the shins would poke through the car floor, so shrink them (and the feet below).
func set_legs_hidden(hide: bool) -> void:
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty(): return
	var sk := sks[0] as Skeleton3D
	for n in ["mixamorig_LeftLeg", "mixamorig_RightLeg"]:
		var bi := sk.find_bone(n)
		if bi >= 0: sk.set_bone_pose_scale(bi, Vector3.ONE * (0.001 if hide else 1.0))

func play(name: String, speed := 1.0, blend := 0.2) -> void:
	if cur_anim == name:
		anim.speed_scale = speed
		return
	cur_anim = name
	anim.speed_scale = speed
	if not anim.has_animation(name):
		# clip not supplied yet: hold the first frame of the walk
		if anim.has_animation("Walk"):
			anim.play("Walk", 0.0)
			anim.seek(0.0, true)
			anim.pause()
		return
	anim.play(name, blend)

func hit(dmg: float, dir: Vector3, by_player := false) -> void:
	if state == "dead": return
	hp -= dmg
	flee_from = global_position - dir * 3.0
	Fx.blood(get_parent(), global_position + Vector3(0, 1.1, 0), dir, 0.6 if hp > 0.0 else 1.0)
	if hp <= 0.0:
		_die(dir, by_player)
	else:
		state = "flee"
		flee_t = 5.0
		play("Hit_Chest", 1.0, 0.05)

func _die(dir: Vector3, by_player: bool) -> void:
	state = "dead"
	collision_layer = 0
	tumbling = by_player and Game.in_car != null and absf((Game.in_car as Car).speed_ms) > 3.0
	if tumbling:
		anim.stop()               # no clip while flying; the body just flips
		var h := Vector3(dir.x, 0, dir.z)
		h = h.normalized() if h.length() > 0.01 else Vector3.FORWARD
		tumble_axis = h.cross(Vector3.UP).normalized()
		tumble_ang = 0.0
	else:
		play("Death01", 1.0, 0.05)
	velocity = dir.normalized() * 3.0
	var big := dir.length() > 0.0 and by_player and Game.in_car != null
	Fx.blood(get_parent(), global_position + Vector3(0, 0.9, 0), dir, 2.2 if big else 1.4)
	Fx.pool(get_parent(), global_position, 1.5 if big else 1.0)
	if by_player:
		Game.add_wanted(1)
		if randf() < 0.75:
			Fx.drop_cash(get_parent(), global_position, randi_range(5, 60))
	add_to_group("bodies")
	remove_from_group("peds")

func _land_after_tumble() -> void:
	tumbling = false
	var h := Vector3(velocity.x, 0, velocity.z)
	if h.length() > 0.3:
		face = atan2(h.x, h.z) + PI     # fall onto the back, head towards the way they flew
	model.transform = Transform3D(Basis(Vector3.UP, face), Vector3.ZERO)
	if anim.has_animation("Death01"):
		anim.play("Death01", 0.0)
		anim.seek(anim.current_animation_length * 0.8, true)
	Fx.blood(get_parent(), global_position + Vector3(0, 0.3, 0), Vector3.UP, 1.0)
	velocity.x *= 0.3
	velocity.z *= 0.3

func scare(from: Vector3) -> void:
	if state == "dead": return
	state = "flee"
	flee_t = 4.0
	flee_from = from

func _physics_process(delta: float) -> void:
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = 0.5
		var cam := get_viewport().get_camera_3d()
		if cam != null and anim != null:
			var d := cam.global_position.distance_to(global_position)
			var near := d < 70.0 or state == "dead"
			anim.active = near
			model.visible = d < 170.0
	if state == "held":
		return                    # being dragged out of a car; a tween moves the ped
	if state == "dead":
		dead_t += delta
		if not tumbling:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		velocity.y -= 22.0 * delta
		move_and_slide()
		if tumbling:
			if is_on_floor() and dead_t > 0.15:
				_land_after_tumble()
			else:
				tumble_ang += 9.0 * delta
				var basis := Basis(tumble_axis, tumble_ang) * Basis(Vector3.UP, face)
				# spin around the hips, not the feet
				model.transform = Transform3D(basis, Vector3(0, 0.9, 0) - basis * Vector3(0, 0.9, 0))
		if dead_t > 25.0:
			queue_free()
		return
	_check_threats()
	var target := Vector3.ZERO
	var speed := walk_speed
	if state == "flee":
		flee_t -= delta
		var away := global_position - flee_from
		away.y = 0
		target = global_position + away.normalized() * 10.0
		speed = 5.2
		if flee_t <= 0.0:
			state = "walk"
	else:
		if loop.is_empty():
			return
		target = loop[wp]
		if Vector2(global_position.x - target.x, global_position.z - target.z).length() < 1.2:
			if open_route:
				var nw := wp + step_dir
				if nw < 0 or nw >= loop.size():
					step_dir = -step_dir
					nw = wp + step_dir
				wp = clampi(nw, 0, loop.size() - 1)
			else:
				wp = (wp + step_dir + loop.size()) % loop.size()
			target = loop[wp]
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 12.0 * delta)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 22.0 * delta
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.3:
		face = lerp_angle(face, atan2(velocity.x, velocity.z), clampf(8.0 * delta, 0.0, 1.0))
	model.rotation.y = face
	if state == "flee":
		play("Sprint", 1.0)
	elif hs > 0.3:
		play("Walk", clampf(hs / 1.5, 0.7, 1.4))
	else:
		play("Idle")

func _check_threats() -> void:
	var car := Game.in_car as Car
	if car != null:
		var local := car.to_local(global_position)
		var spd := absf(car.speed_ms)
		var dir_sign := 1.0 if car.speed_ms >= 0.0 else -1.0
		# inside the car's footprint (with a little margin), on the end that is moving forward
		var hit_zone := absf(local.x) < car.model_w * 0.5 + 0.35 and absf(local.z) < car.model_len * 0.5 + 0.3 and local.z * dir_sign > -0.5
		if hit_zone and spd > 3.0:
			var away := (global_position - car.global_position)
			away.y = 0.0
			var push := car.global_transform.basis.z * dir_sign * 0.7 + away.normalized() * 0.3
			hit(spd * 6.0, push, true)
			if state == "dead":
				velocity = push.normalized() * (3.0 + spd * 0.35)
				velocity.y = 3.0 + spd * 0.1
		elif car.global_position.distance_to(global_position) < 14.0 and spd > 9.0 and state != "flee":
			scare(car.global_position)
	elif Game.player != null and is_instance_valid(Game.player):
		var pl := Game.player as Player
		if pl.punch_t > 0.0 and global_position.distance_to(pl.global_position) < 9.0:
			scare(pl.global_position)
