class_name Cop
extends Ped
## A police officer who got out of a patrol car: runs at the player, stops at range and shoots until the player is dead.

var car: Car
var shoot_cd := 0.6
var leave_t := 0.0
var _hand: BoneAttachment3D
var _pistol: Node3D
var _aim_dir := Vector3.FORWARD
var _snd: AudioStreamPlayer3D
var exit_t := 0.0
var exit_from := Vector3.ZERO
var exit_to := Vector3.ZERO

func setup_cop(id: String, from_car: Car, side: float = -1.0) -> void:
	car = from_car
	setup(id, [global_position], 0, 1)
	remove_from_group("peds")           # cops are not bystanders: no scaring, no ped quota
	add_to_group("cops")
	is_cop = true
	hp = 70.0
	# starts in the seat and climbs out of the door with the real exit clip
	state = "exiting"
	exit_from = from_car.get_seat_pos(side)
	exit_to = from_car.get_door_pos(side)
	global_position = exit_from
	face = atan2(from_car.forward_dir().x, from_car.forward_dir().z)
	model.rotation.y = face
	set_legs_hidden(true)
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_hand = BoneAttachment3D.new()
		_hand.bone_name = "mixamorig_RightHand"
		(sks[0] as Skeleton3D).add_child(_hand)
		_pistol = Node3D.new()
		var g := (load("res://assets/weapons/hand_gun.glb") as PackedScene).instantiate() as Node3D
		g.scale = Vector3.ONE * HandGun.GUN_SCALE
		g.rotation_degrees = Vector3(0, HandGun.GUN_YAW, 0)
		g.position = HandGun.GUN_OFFSET
		_pistol.add_child(g)
		_hand.add_child(_pistol)
	_snd = AudioStreamPlayer3D.new()
	_snd.max_distance = 120.0
	_snd.unit_size = 12.0
	add_child(_snd)
	play("Sitting_Exit", 1.0, 0.05)

func scare(_from: Vector3) -> void:
	pass                                # cops do not run away

func _process(_delta: float) -> void:
	if _pistol != null:
		_pistol.visible = state == "cop"
		if state == "cop":
			HandGun.hold(_pistol)

func _physics_process(delta: float) -> void:
	if state == "dead" or state == "held":
		super(delta)
		return
	if state == "exiting":
		exit_t += delta
		var p := clampf(exit_t / 1.0, 0.0, 1.0)
		global_position = exit_from.lerp(exit_to, smoothstep(0.0, 1.0, p))
		var out := exit_to - exit_from
		face = lerp_angle(face, atan2(out.x, out.z), clampf(6.0 * delta, 0.0, 1.0))
		model.rotation.y = face
		if p > 0.4:
			set_legs_hidden(false)
		if p >= 1.0:
			state = "cop"
			shoot_cd = 0.5
			play("Sprint", 1.0, 0.1)
		return
	_check_threats()                    # can still be run over
	if state == "dead":
		return
	if Game.wanted == 0:
		leave_t += delta
		if leave_t > 6.0:
			queue_free()
			return
	else:
		leave_t = 0.0
	var tgt := Game.get_focus_pos()
	var to := tgt - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.ZERO
	_aim_dir = dir if dir != Vector3.ZERO else _aim_dir
	var chest := global_position + Vector3(0, 1.35, 0)
	var los := _line_of_sight(chest, tgt + Vector3(0, 1.1, 0))
	var moving := false
	if Game.dead:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	elif dist > 13.0 or not los:
		velocity.x = move_toward(velocity.x, dir.x * 5.2, 16.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * 5.2, 16.0 * delta)
		moving = true
	else:
		velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 22.0 * delta
	move_and_slide()
	if dist > 0.3:
		face = lerp_angle(face, atan2(dir.x, dir.z), clampf(10.0 * delta, 0.0, 1.0))
	model.rotation.y = face
	shoot_cd -= delta
	if moving:
		play("Sprint", 1.0)
	elif not Game.dead:
		play("Pistol_Aim_Neutral", 1.0, 0.1)
		if shoot_cd <= 0.0 and dist < 22.0:
			_shoot_at(chest, tgt + Vector3(0, 1.1, 0), dist)
			shoot_cd = randf_range(0.55, 1.0)
	else:
		play("Pistol_Idle", 1.0)

func _line_of_sight(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _shoot_at(from: Vector3, to: Vector3, dist: float) -> void:
	_snd.stream = load("res://assets/audio/guns/pistol_1911_0%d.mp3" % (1 + randi() % 2)) as AudioStream
	_snd.pitch_scale = randf_range(0.9, 1.05)
	_snd.play()
	play("Pistol_Shoot", 1.8, 0.04)
	# muzzle flash
	var fl := OmniLight3D.new()
	fl.light_color = Color("#ffd080")
	fl.light_energy = 4.0
	fl.omni_range = 4.0
	get_parent().add_child(fl)
	fl.global_position = (_pistol.global_position if _pistol != null else from) + _aim_dir * 0.2
	get_tree().create_timer(0.05).timeout.connect(fl.queue_free)
	var chance := clampf(0.55 - dist * 0.02, 0.15, 0.5)
	if randf() < chance:
		Game.health -= randf_range(3.0, 7.0)
		var cam := Game.camera as ThirdPersonCamera
		if cam != null: cam.add_shake(0.25)
