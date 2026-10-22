class_name Player
extends CharacterBody3D
## The hero: walks, runs, jumps, punches, aims, shoots, enters and exits cars with full animations.

## Natural ground speed of each clip (measured from its planted foot), so the feet do not slide.
const WALK_V := 1.48
const PISTOL_WALK_V := 2.14
const JOG_V := 3.52
const PISTOL_RUN_V := 4.09
const SPRINT_V := 5.04
const WALK := 1.9
const RUN := 4.8
const SPRINT := 7.6
const GRAVITY := 22.0
const JUMP := 6.2

enum State { ON_FOOT, ENTERING_CAR, IN_CAR, EXITING_CAR, ROLLING }
var state: State = State.ON_FOOT

var model: Node3D
var anim: AnimationPlayer
var cam: ThirdPersonCamera
var shape: CollisionShape3D
var face := 0.0
var cur_anim := ""
var punch_t := 0.0
var _step_t := 0.0
var _foot: AudioStreamPlayer3D
var dead := false
var weapon := 1              # 0 fists, 1 gun (the built-in pistol, or a shop gun when held_id is set), 2 melee, 3 thrown
var held_id := ""            # "" = the built-in pistol; otherwise the shop item in the hand
var held_info := {}
var held_node: Node3D
var held_muzzle := Vector3.ZERO
var held_front := 0.0
var held_base := Transform3D.IDENTITY     # the computed hold, before the hand-tuned offset (used by the grip editor)
var edit_pose := ""                       # grip editor: force this pose (idle / aim / run / swing)
var grip_off := Transform3D.IDENTITY
var hand_ba: BoneAttachment3D
const SWIM_SINK := 0.95
const IDLE_SINK := 1.3
var diving := false
var _under_layer: CanvasLayer
var scoped := false
var _scope_layer: CanvasLayer
var melee_t := 0.0
var melee_hit_t := -1.0
var melee_combo := 0
var ammo := 17
var shoot_cd := 0.0
var reload_t := 0.0
var shot_anim_t := 0.0
var aiming := false
var force_aim := false
var pistol_node: Node3D
var pistol_anim_player: AnimationPlayer = null
var _shot_sfx: AudioStreamPlayer3D
var _recoil_pitch := 0.0

# Car interaction & animation variables
var active_car: Car = null
var car_anim_t := 0.0
var car_anim_duration := 1.0
var car_start_pos := Vector3.ZERO
var car_start_rot := 0.0
var car_door_side := -1.0
var _door_sfx_played := false
var _seat_phase := 0
var _walk_pts: Array[Vector3] = []     # car-local waypoints to the driver's door
var _walk_t := 0.0
var _exit_to := Vector3.ZERO           # where the player will stand after getting out (a spot clear of walls and buildings)
var _door_opened := false
var _roll_t := 0.0
var swimming := false
var air_mode := 0                # 0 on foot, 1 free fall, 2 parachute open
var _fall_t := 0.0
var _chute: Node3D = null
var _wind: AudioStreamPlayer = null
var _land_t := 0.0
var _pack: BoneAttachment3D = null
const CHUTE_SCALE := 0.24
var _chute_roll := 0.0
var _chute_pitch := 0.0
const _PACK_OFFSET := Vector3(0.0, -0.05, -0.18)
var in_heli: Chopper = null
var _splash_cd := 0.0
const WATER_Y := -0.55
var _jack_delay := 0.0         # seconds spent hauling the driver out before climbing in

# Bone caching for aim upper-body blending and torso pitch
var sk: Skeleton3D = null
var spine1_idx := -1
var spine2_idx := -1
var upper_bone_indices: Array[int] = []
var upper_bone_name_by_idx: Dictionary = {}
var aim_bone_rotations: Dictionary = {}

const CHARACTERS := [Game.MAIN_HERO]
var current_character := Game.MAIN_HERO

func _apply_model_offset() -> void:
	model.position = Vector3.ZERO
	model.rotation_degrees.y = 0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 16
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	model = Game.load_character(current_character)
	add_child(model)
	_apply_model_offset()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim = AnimationPlayer.new()
	anim.name = "CustomAnimPlayer"
	model.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", Game.get_anim_library(current_character))
	play("Idle")
	_foot = AudioStreamPlayer3D.new()
	_foot.max_distance = 25.0
	_foot.volume_db = -6.0
	add_child(_foot)
	_make_pistol()
	_cache_aim_bones()
	_shot_sfx = AudioStreamPlayer3D.new()
	_shot_sfx.max_distance = 120.0
	_shot_sfx.unit_size = 12.0
	add_child(_shot_sfx)
	Game.player = self

func switch_character(id: String = "") -> void:
	if id == "":
		var idx := CHARACTERS.find(current_character)
		current_character = CHARACTERS[(idx + 1) % CHARACTERS.size()] if idx >= 0 else Game.MAIN_HERO
	else:
		current_character = id

	if pistol_node != null and is_instance_valid(pistol_node):
		var bp := pistol_node.get_parent()
		if bp != null: bp.remove_child(pistol_node)
	if held_node != null and is_instance_valid(held_node):
		held_node.queue_free()
	held_node = null
	if model != null and is_instance_valid(model):
		model.queue_free()

	model = Game.load_character(current_character)
	add_child(model)
	_apply_model_offset()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim = AnimationPlayer.new()
	anim.name = "CustomAnimPlayer"
	model.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", Game.get_anim_library(current_character))
	_make_pistol()
	_cache_aim_bones()
	play(cur_anim if cur_anim != "" else "Idle", 1.0, 0.1)

func _make_pistol() -> void:
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty(): return
	var sk_ref := sks[0] as Skeleton3D
	var ba := BoneAttachment3D.new()
	var hand_idx := Retarget._find_matching_bone(sk_ref, "hand_r")
	var hand_bone_name := sk_ref.get_bone_name(hand_idx) if hand_idx >= 0 else "mixamorig_RightHand"
	ba.bone_name = hand_bone_name
	sk_ref.add_child(ba)
	if pistol_node == null:
		pistol_node = HandGun.make()
	pistol_node.visible = (weapon == 1)
	ba.add_child(pistol_node)
	hand_ba = ba
	_rebuild_held()
	var aps := pistol_node.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		pistol_anim_player = aps[0] as AnimationPlayer

func _cache_aim_bones() -> void:
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty(): return
	sk = sks[0] as Skeleton3D
	spine1_idx = Retarget._find_matching_bone(sk, "spine_01")
	spine2_idx = Retarget._find_matching_bone(sk, "spine_02")
	var upper_keys := [
		"spine_01", "spine_02", "spine_03", "neck_01", "Head",
		"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
		"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"
	]
	upper_bone_indices.clear()
	upper_bone_name_by_idx.clear()
	for ukey in upper_keys:
		var idx := Retarget._find_matching_bone(sk, ukey)
		if idx >= 0 and not upper_bone_indices.has(idx):
			upper_bone_indices.append(idx)
			upper_bone_name_by_idx[idx] = sk.get_bone_name(idx)

	var lib := Game.get_anim_library(current_character)
	for anim_key in ["Pistol_Aim_Neutral", "Pistol_Aim_Down", "Pistol_Aim_Up", "Rifle_Ready"]:
		if lib.has_animation(anim_key):
			var a := lib.get_animation(anim_key)
			var map: Dictionary = {}
			for t in range(a.get_track_count()):
				var p := String(a.track_get_path(t))
				if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
					for idx in upper_bone_indices:
						var bn: String = upper_bone_name_by_idx[idx]
						if p.ends_with(":" + bn):
							map[idx] = a.track_get_key_value(t, 0)
			aim_bone_rotations[anim_key] = map

func play(name: String, speed := 1.0, blend := 0.15) -> void:
	if cur_anim == name and anim.is_playing():
		anim.speed_scale = speed
		return
	cur_anim = name
	anim.speed_scale = speed
	if not anim.has_animation(name):
		# Fallback smoothly to closest available animation
		if name.begins_with("Pistol_Aim") or name.begins_with("Pistol_Idle") or name == "Interact":
			if anim.has_animation("Idle"):
				anim.play("Idle", blend)
				return
		elif name == "Run" and anim.has_animation("Jog_Fwd"):
			anim.play("Jog_Fwd", blend)
			return
		elif name.begins_with("Jump") and anim.has_animation("Jump"):
			anim.play("Jump", blend)
			return
		elif anim.has_animation("Idle"):
			anim.play("Idle", blend)
			return
		elif anim.has_animation("Walk"):
			anim.play("Walk", blend)
			return
		return
	anim.play(name, blend)

func _unhandled_input(event: InputEvent) -> void:
	if Game.dead: return
	if event.is_action_pressed("interact"):
		if in_heli == null and Game.in_car == null and state == State.ON_FOOT:
			if GunShop.near_counter(global_position):
				GunMenu.toggle_for(get_tree().current_scene)
				return
		if in_heli != null:
			in_heli.try_exit()
			return
		var hh := nearest_heli(7.0)
		if hh != null and state == State.ON_FOOT and Game.in_car == null:
			hh.enter(self)
			return
		if state == State.IN_CAR or Game.in_car != null:
			_exit_car()
		elif state == State.ON_FOOT:
			_try_enter_car()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		if state == State.ON_FOOT:
			switch_character()
	elif event.is_action_pressed("reload") and state == State.ON_FOOT and weapon == 1 and held_id == "":
		if ammo < 17 and reload_t <= 0.0:
			reload_t = 1.3
			play("Pistol_Reload", 1.25, 0.1)
			if pistol_anim_player != null:
				pistol_anim_player.play("reload", -1, 1.2)
			_play_sfx("res://assets/audio/guns/pistol_reload.ogg")
			ammo = 17
	elif event.is_action_pressed("weapon_next") and state == State.ON_FOOT:
		cycle_weapon()

## The weapons the player can switch between: fists, the built-in pistol, and everything bought that is still usable.
func weapon_list() -> Array:
	var l: Array = ["fists", ""]
	for gi in range(GunShop.GUNS.size()):
		var id := String(GunShop.GUNS[gi][0])
		if int(Game.guns_owned.get(id, 0)) > 0 and (Game.ammo_reserve > 0 or int(Game.guns_owned[id]) > 0): l.append(id)
	for e in GunShop.EXTRAS:
		if int(Game.guns_owned.get(String(e[0]), 0)) > 0: l.append(String(e[0]))
	return l

func cycle_weapon() -> void:
	var l := weapon_list()
	var cur := "fists" if weapon == 0 else held_id
	equip(String(l[(maxi(0, l.find(cur)) + 1) % l.size()]))

## Puts a weapon in the hand: "fists", "" (built-in pistol) or a shop item id.
func equip(id: String) -> void:
	melee_t = 0.0
	melee_hit_t = -1.0
	if id == "fists":
		weapon = 0
		held_id = ""
	elif id == "":
		weapon = 1
		held_id = ""
	else:
		var inf := Weapons.info(id)
		if inf.is_empty(): return
		held_id = id
		held_info = inf
		match String(inf.kind):
			"melee": weapon = 2
			"thrown": weapon = 3
			_: weapon = 1
	_rebuild_held()

func _rebuild_held() -> void:
	if held_node != null and is_instance_valid(held_node): held_node.queue_free()
	held_node = null
	if held_id == "" or hand_ba == null: return
	held_info = Weapons.info(held_id)
	var made := Weapons.make_held(held_id, held_info)
	if made.is_empty(): return
	held_node = made.node
	held_muzzle = made.muzzle
	held_front = float(made.get("front", 0.0))
	hand_ba.add_child(held_node)

## Clip name for a slot (idle / walk / run / aim / shoot) of the weapon in the hand, "" = use the plain clip.
func _wanim(slot: String) -> String:
	if weapon == 2:
		return {"idle": "Melee_Idle", "walk": "Melee_Walk", "run": "Melee_Run"}.get(slot, "")
	if weapon != 1: return ""
	var k := String(held_info.get("kind", "pistol")) if held_id != "" else "pistol"
	if k == "pistol":
		return {"idle": "Pistol_Idle", "walk": "Pistol_Walk", "run": "Pistol_Run", "shoot": "Pistol_Shoot"}.get(slot, "")
	return {"idle": "Rifle_Idle", "walk": "Rifle_Walk", "run": "Rifle_Run", "aim": "Rifle_Ready", "shoot": "Shotgun_Shot" if k == "shotgun" else "Rifle_Shot"}.get(slot, "")

## Which pose the held weapon is in right now (the grip offsets are saved per pose).
func grip_pose() -> String:
	if edit_pose != "": return edit_pose
	if weapon == 2 and melee_t > 0.0: return "swing"
	if aiming: return "aim"
	if Vector2(velocity.x, velocity.z).length() > 2.2: return "run"
	return "idle"

func _is_rifle_class() -> bool:
	return weapon == 1 and held_id != "" and String(held_info.get("kind", "")) != "pistol"

func nearest_car(max_d := 4.5) -> Car:
	var best: Car = null
	var bd := max_d
	for c in get_tree().get_nodes_in_group("cars"):
		var d := global_position.distance_to((c as Node3D).global_position)
		if d < bd:
			bd = d
			best = c
	return best

func nearest_heli(max_d := 7.0) -> Chopper:
	for h in get_tree().get_nodes_in_group("player_heli"):
		if global_position.distance_to((h as Node3D).global_position) < max_d + (h as Chopper).reach:
			return h as Chopper
	return null

func nearest_traffic(max_d := 4.5) -> TrafficCar:
	var best: TrafficCar = null
	var bd := max_d
	for t in get_tree().get_nodes_in_group("traffic"):
		var d := global_position.distance_to((t as Node3D).global_position)
		if d < bd:
			bd = d
			best = t
	return best

## Take a moving car: swap the AI car for a drivable one, throw its driver out onto the road, and get in.
func _carjack(tc: TrafficCar) -> Car:
	var xf := tc.global_transform
	var parent := tc.get_parent()
	var kind := tc.kind
	var paint := tc.paint
	var driver_id := tc.driver_id
	tc.remove_from_group("traffic")
	tc.queue_free()
	var car := Car.new()
	parent.add_child(car)
	car.global_transform = Transform3D(xf.basis, xf.origin + Vector3(0, 0.62, 0))
	car.setup(kind, paint, false)
	# Choreography with the real clips:
	#  player: PickUp_Table (grab)  |  driver: startled in the seat -> Sitting_Exit while yanked to the door ->
	#  Hit_Knockback onto the road -> LayToIdle (gets up) -> runs off
	var door := car.get_door_pos(-1.0)
	var seat := car.get_seat_pos(-1.0)
	var out_dir := (door - car.global_position)
	out_dir.y = 0.0
	out_dir = out_dir.normalized()
	var land := door + out_dir * 1.5
	var ped := Ped.new()
	parent.add_child(ped)
	ped.global_position = seat
	ped.setup(driver_id if driver_id != "" else "Male/Character_12", [ped.global_position], 0, 1)
	ped.state = "held"
	ped.face = atan2(car.forward_dir().x, car.forward_dir().z)
	ped.model.rotation.y = ped.face
	ped.set_legs_hidden(true)
	ped.play("Driving", 1.0, 0.0)
	car.open_door(-1.0, 0.25)
	# the player turns to the door and grabs
	face = atan2(door.x - global_position.x, door.z - global_position.z)
	model.rotation.y = face
	var tw := ped.create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		ped.play("Sitting_Exit", 1.4, 0.05)
		ped.face = atan2(out_dir.x, out_dir.z)
		ped.model.rotation.y = ped.face)
	tw.tween_callback(func(): ped.set_legs_hidden(false)).set_delay(0.3)
	tw.tween_property(ped, "global_position", door + Vector3(0, 0.3, 0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		ped.face = atan2(-out_dir.x, -out_dir.z)    # flung backwards onto the road
		ped.model.rotation.y = ped.face
		ped.play("Hit_Knockback", 1.0, 0.05)
		Fx.blood(parent, ped.global_position + Vector3(0, 1.0, 0), out_dir, 0.7))
	tw.tween_property(ped, "global_position", Vector3(land.x, door.y, land.z), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): ped.play("LayToIdle", 1.0, 0.1))
	tw.tween_interval(1.5)
	tw.tween_callback(func():
		ped.state = "flee"
		ped.flee_t = 7.0
		ped.flee_from = global_position)
	Game.add_wanted(1)
	_play_sfx("res://assets/audio/vehicles/door_open_01.ogg")
	_jack_delay = 1.0
	return car

func _try_enter_car() -> void:
	if state != State.ON_FOOT: return
	var c := nearest_car()
	var tc := nearest_traffic()
	if tc != null and (c == null or global_position.distance_to(tc.global_position) < global_position.distance_to(c.global_position)):
		c = _carjack(tc)
	if c == null: return
	active_car = c
	var local_p := c.to_local(global_position)
	car_door_side = -1.0          # the wheel is on the driver's side: always get in there, walking round the car if needed
	var stand_l := c.to_local((c.entry_path(-1.0)[0] as Vector3))
	var hw := c.model_w * 0.5 + 1.1
	var hl := c.model_len * 0.5 + 1.2
	_walk_pts = [c.to_local(Vector3(global_position.x, c.global_position.y - Car.RIDE, global_position.z))]
	if local_p.x * c.drv_x < 0.0:
		var ez := hl if local_p.z >= 0.0 else -hl
		if absf(local_p.z) < 0.6: ez = hl
		_walk_pts.append(Vector3(-c.drv_x * hw, stand_l.y, ez))
		_walk_pts.append(Vector3(c.drv_x * hw, stand_l.y, ez))
	_walk_pts.append(stand_l)
	var plen := 0.0
	for i in range(_walk_pts.size() - 1):
		plen += Vector2(_walk_pts[i + 1].x - _walk_pts[i].x, _walk_pts[i + 1].z - _walk_pts[i].z).length()
	_walk_t = clampf(plen / 3.4, 0.0, 6.0)
	state = State.ENTERING_CAR
	shape.disabled = true
	velocity = Vector3.ZERO
	if pistol_node != null: pistol_node.visible = false
	if _walk_t > 0.4:
		play("Walk", 1.15, 0.15)
	else:
		_walk_t = 0.0
		if c.has_method("open_door"):
			c.open_door(car_door_side, 0.45, Car.DOOR_WIDE)
		play("Sitting_Enter", 1.0, 0.15)
	_door_opened = _walk_t == 0.0
	car_anim_t = 0.0
	car_anim_duration = 2.0 + _walk_t
	_seat_phase = 0
	_door_sfx_played = false
	car_start_pos = global_position
	car_start_rot = model.rotation.y
	if _jack_delay > 0.0:
		# carjack: haul the driver out first (Push), then climb in
		car_anim_t = -_jack_delay
		_jack_delay = 0.0
		play("PickUp_Table", 1.0, 0.1)

## True if the player's capsule would touch anything solid (buildings, walls, trees, other cars) when standing at p.
func _blocked_at(p: Vector3, ignore: Array) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape.shape
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.95, 0))
	q.collision_mask = 1
	q.exclude = ignore
	q.margin = 0.05
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

## The nearest standing spot to `wanted` that is clear of every solid object and has ground under it: the driver's door
## first, then the other side, then rings round the car. Falls back to the wanted spot.
func _clear_spot_near(c: Car, wanted: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ignore: Array = [get_rid(), c.get_rid()]
	var cands: Array[Vector3] = [wanted, c.entry_path(1.0)[0]]
	var centre := c.global_position
	for r in [c.model_w * 0.5 + 1.0, c.model_w * 0.5 + 2.2, c.model_len * 0.5 + 1.2, c.model_len * 0.5 + 2.6, c.model_len * 0.5 + 4.5]:
		for k in range(16):
			var a := TAU * float(k) / 16.0
			cands.append(centre + Vector3(sin(a), 0.0, cos(a)) * r)
	var best := wanted
	var best_d := 1e9
	for i in range(cands.size()):
		var cp: Vector3 = cands[i]
		var rq := PhysicsRayQueryParameters3D.create(cp + Vector3(0, 2.0, 0), cp + Vector3(0, -3.0, 0), 1)
		rq.exclude = ignore
		var hit := space.intersect_ray(rq)
		if hit.is_empty(): continue
		var gp: Vector3 = hit.position
		if absf(gp.y - wanted.y) > 1.6: continue                    # not the same level (a roof, a kerb up to a plot)
		var spot := Vector3(cp.x, gp.y + 0.03, cp.z)
		if _blocked_at(spot, ignore): continue
		var d := Vector2(spot.x - wanted.x, spot.z - wanted.z).length() + (0.0 if i < 2 else 0.4)
		if i < 2:
			return spot                                             # the doors are always preferred when clear
		if d < best_d:
			best_d = d
			best = spot
	return best

func _exit_car() -> void:
	var c := Game.in_car as Car
	if c == null:
		c = active_car
	if c == null: return
	active_car = c
	car_door_side = -1.0          # the driver always gets out of the driver's door

	if absf(c.speed_ms) > 7.5:
		# bail out of a moving car: tuck and roll along the road (the capsule must be live or we fall through the ground)
		state = State.ROLLING
		shape.disabled = false
		_set_legs_hidden(false)
		_play_sfx("res://assets/audio/vehicles/door_open_01.ogg")
		var side_dir := c.global_transform.basis.x * c.drv_x                           # towards the driver's door
		var spot := _clear_spot_near(c, c.to_global(Vector3(c.drv_x * (c.model_w * 0.5 + 0.9), -Car.RIDE + 0.15, c.model_len * 0.1)))
		global_position = spot + Vector3(0, 0.12, 0)
		var along := c.linear_velocity
		along.y = 0.0
		if along.length() > 14.0: along = along.normalized() * 14.0
		velocity = along * 0.8 + side_dir * 2.5 + Vector3.UP * 1.0
		face = atan2(along.x, along.z) if along.length() > 0.5 else face
		model.rotation.y = face
		c.exit_car(car_door_side)
		play("Roll", 1.3, 0.05)
		_roll_t = 1.1
		Game.health -= 15.0
		if cam != null: cam.add_shake(0.5)
		_play_sfx("res://assets/audio/footsteps/land_concrete_01.ogg")
	else:
		state = State.EXITING_CAR
		_set_legs_hidden(false)
		_set_legs_hidden(true)
		car_anim_t = 0.0
		car_anim_duration = 2.0
		_seat_phase = 0
		_door_sfx_played = false
		car_start_pos = global_position
		car_start_rot = model.rotation.y
		_exit_to = _clear_spot_near(c, c.entry_path(car_door_side)[0])
		c.player_controlled = false
		c.engine_force = 0.0
		c.brake = 25.0
		if c.has_method("open_door"):
			c.open_door(car_door_side, 0.4, Car.DOOR_WIDE)
		else:
			_play_sfx("res://assets/audio/vehicles/door_open_01.ogg")
		play("Sitting_Exit", 1.0, 0.1)

func _splash() -> void:
	Fx.splash(get_parent(), Vector3(global_position.x, WATER_Y, global_position.z))
	_play_sfx("res://assets/audio/sea/wave_03.mp3")

func _play_sfx(path: String) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path) as AudioStream
	p.max_distance = 40.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## Thrown out of an aircraft: free fall for a moment, then the parachute opens and the player glides down.
func start_skydive(initial: Vector3) -> void:
	air_mode = 1
	_fall_t = 0.0
	velocity = initial
	_skydive_sound(true)
	_add_pack()
	state = State.ON_FOOT

## A round-ish ram-air canopy built from 14 coloured gores that curve down at the edge, with suspension lines to a harness.
func _make_chute() -> Node3D:
	var root := Node3D.new()
	var inst := (load("res://assets/town/pubg_green_parachute.glb") as PackedScene).instantiate() as Node3D
	var sc := CHUTE_SCALE
	inst.scale = Vector3.ONE * sc
	inst.position = Vector3(0, 1.5 + 11.23 * sc, -0.3)     # the lines' lower end sits just behind the shoulders, above the pack
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m0 := (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if m0 != null:
			var m1 := m0.duplicate() as StandardMaterial3D
			m1.cull_mode = BaseMaterial3D.CULL_DISABLED
			(mi as MeshInstance3D).material_override = m1
	root.add_child(inst)
	root.set_meta("canopy", inst)
	return root

## The parachute pack on the back (follows the spine bone so it moves with the body).
func _add_pack() -> void:
	if _pack != null: return
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty(): return
	var sk := sks[0] as Skeleton3D
	var bi := sk.find_bone("mixamorig_Spine2")
	if bi < 0: bi = sk.find_bone("mixamorig_Spine1")
	if bi < 0: return
	var ba := BoneAttachment3D.new()
	ba.bone_name = sk.get_bone_name(bi)
	sk.add_child(ba)
	var pack := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.28, 0.14)
	mat.roughness = 0.9
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.55, 0.2)
	bm.material = mat
	body.mesh = bm
	pack.add_child(body)
	var strap_m := StandardMaterial3D.new()
	strap_m.albedo_color = Color(0.08, 0.08, 0.08)
	for sx in [-1.0, 1.0]:
		var st := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.05, 0.7, 0.04)
		sb.material = strap_m
		st.mesh = sb
		st.position = Vector3(sx * 0.17, 0.12, 0.12)
		pack.add_child(st)
	pack.position = _PACK_OFFSET
	pack.scale = Vector3.ONE / maxf(model.global_transform.basis.get_scale().x, 0.0001)
	ba.add_child(pack)
	_pack = ba

func _remove_pack() -> void:
	if _pack != null:
		_pack.queue_free()
		_pack = null

func _skydive_sound(on: bool) -> void:
	if on and _wind == null:
		_wind = AudioStreamPlayer.new()
		var st := load("res://assets/audio/weather/wind_howl_loop.ogg") as AudioStream
		if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop = true
		_wind.stream = st
		_wind.volume_db = -30.0
		add_child(_wind)
		_wind.play()
	elif not on and _wind != null:
		var w := _wind
		_wind = null
		var tw := w.create_tween()
		tw.tween_property(w, "volume_db", -60.0, 0.8)
		tw.tween_callback(w.queue_free)

func _process_skydive(delta: float) -> void:
	_fall_t += delta
	if air_mode == 1 and _fall_t > 1.6:
		air_mode = 2
		_chute = _make_chute()
		add_child(_chute)
		_chute.scale = Vector3(0.15, 0.15, 0.15)
		var tw := _chute.create_tween()
		tw.tween_property(_chute, "scale", Vector3(1.0, 1.0, 1.0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_play_sfx("res://assets/audio/vehicles/door_open_01.ogg")
		if _wind != null: _wind.volume_db = -22.0
	var yaw := cam.yaw if cam != null else 0.0
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := right * input.x + fwd * -input.y
	if _wind != null and air_mode == 1:
		_wind.volume_db = lerpf(_wind.volume_db, -4.0, clampf(delta * 1.5, 0.0, 1.0))
		_wind.pitch_scale = 0.8 + absf(velocity.y) * 0.012
	if _chute != null:
		var sway := sin(_fall_t * 1.7) * 0.05 - input.x * 0.2
		_chute_roll = lerpf(_chute_roll, sway, clampf(delta * 3.0, 0.0, 1.0))
		_chute_pitch = lerpf(_chute_pitch, input.y * 0.16 + sin(_fall_t * 1.3) * 0.02, clampf(delta * 3.0, 0.0, 1.0))
		_chute.basis = Basis(Vector3.UP, face) * Basis(Vector3.BACK, _chute_roll) * Basis(Vector3.RIGHT, _chute_pitch)
		var cn := _chute.get_meta("canopy") as Node3D
		cn.scale = Vector3(1.0 + sin(_fall_t * 4.0) * 0.015, 1.0 + sin(_fall_t * 5.3) * 0.03, 1.0 + sin(_fall_t * 4.0) * 0.015) * CHUTE_SCALE
	if air_mode == 1:
		velocity.y = maxf(velocity.y - 26.0 * delta, -42.0)
		velocity.x = lerpf(velocity.x, dir.x * 6.0, clampf(delta * 1.2, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, dir.z * 6.0, clampf(delta * 1.2, 0.0, 1.0))
		play("Falling Idle" if anim.has_animation("Falling Idle") else "Jump", 1.0, 0.25)
	else:
		velocity.y = lerpf(velocity.y, -5.0, clampf(delta * 3.0, 0.0, 1.0))
		velocity.x = lerpf(velocity.x, dir.x * 9.0, clampf(delta * 1.5, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, dir.z * 9.0, clampf(delta * 1.5, 0.0, 1.0))
		play("Floating" if anim.has_animation("Floating") else "Jump", 1.0, 0.4)
	move_and_slide()
	if Vector2(velocity.x, velocity.z).length() > 0.6:
		face = lerp_angle(face, atan2(velocity.x, velocity.z), clampf(4.0 * delta, 0.0, 1.0))
	model.rotation.y = face
	var in_sea := CityData.is_loaded and CityData.is_water(global_position.x, global_position.z) and global_position.y < 0.6 and global_position.y > -3.0
	if is_on_floor() or in_sea:
		var chuted := air_mode == 2
		air_mode = 0
		var land := "Falling To Landing" if chuted else "Hard Landing"
		if not in_sea and anim.has_animation(land):
			_land_t = minf(anim.get_animation(land).length, 1.6)
			play(land, 1.0, 0.08)
		_skydive_sound(false)
		_remove_pack()
		_play_sfx("res://assets/audio/vehicles/door_close_01.ogg")
		if _chute != null:
			var ch := _chute
			_chute = null
			var tw2 := ch.create_tween()
			tw2.tween_property(ch, "scale", Vector3(1.0, 0.05, 1.0), 0.4)
			tw2.tween_callback(ch.queue_free)
		velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if _land_t > 0.0 and in_heli == null and not Game.dead:
		_land_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		if _land_t <= 0.0: cur_anim = ""
		return
	if air_mode != 0 and in_heli == null and not Game.dead:
		_process_skydive(delta)
		return
	if in_heli != null:
		global_position = in_heli.global_position
		velocity = Vector3.ZERO
		return
	if state == State.ENTERING_CAR:
		_process_entering_car(delta)
		return
	elif state == State.EXITING_CAR:
		_process_exiting_car(delta)
		return
	elif state == State.IN_CAR or Game.in_car != null:
		_process_in_car(delta)
		return
	elif state == State.ROLLING:
		_process_rolling(delta)
		return

	if Game.dead:
		return

	punch_t = maxf(0.0, punch_t - delta)
	shoot_cd = maxf(0.0, shoot_cd - delta)
	shot_anim_t = maxf(0.0, shot_anim_t - delta)
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, 2.0 * delta)

	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = 12

	aiming = weapon == 1 and not swimming and not get_tree().paused and (force_aim or (edit_pose == "" and (Input.is_action_pressed("aim") or Input.is_action_pressed("attack"))))
	Game.aiming = aiming
	_update_scope()
	melee_t = maxf(0.0, melee_t - delta)
	if melee_hit_t > 0.0:
		melee_hit_t -= delta
		if melee_hit_t <= 0.0: _melee_hit()
	if weapon == 0: Game.weapon_text = "FISTS"
	elif held_id == "": Game.weapon_text = "PISTOL  %d / inf%s" % [ammo, "  (reloading)" if reload_t > 0.0 else ""]
	elif weapon == 1: Game.weapon_text = "%s  %d" % [String(held_info.get("name", "")).to_upper(), int(Game.guns_owned.get(held_id, 0)) + Game.ammo_reserve]
	elif weapon == 2: Game.weapon_text = String(held_info.get("name", "")).to_upper()
	else: Game.weapon_text = "%s  x%d" % [String(held_info.get("name", "")).to_upper(), int(Game.guns_owned.get(held_id, 0))]

	if weapon == 1 and held_id == "" and Input.is_action_just_pressed("reload") and reload_t <= 0.0 and ammo < 12:
		reload_t = 1.3
		play("Pistol_Reload", 1.25, 0.1)
		if pistol_anim_player != null:
			pistol_anim_player.play("reload", -1, 1.2)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := cam.yaw if cam != null else 0.0
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := (right * input.x + fwd * -input.y)
	if dir.length() > 0.01:
		dir = dir.normalized()
	var speed := RUN
	if aiming: speed = WALK
	elif Input.is_action_pressed("sprint"): speed = SPRINT
	elif Input.is_action_pressed("walk_slow"): speed = WALK
	if weapon == 1 and bool(held_info.get("heavy", false)) and held_id != "": speed *= 0.7        # machine guns are heavy
	# in the sea: swim at the surface
	var was_swimming := swimming
	swimming = CityData.is_loaded and CityData.is_water(global_position.x, global_position.z) and CityData.height_at(global_position.x, global_position.z) < -1.7 and global_position.y < 0.15 and global_position.y > -3.0       # not in the metro: the tunnel runs under the sea
	if swimming != was_swimming:
		_splash()
		# Weapons are kept out of the water; restore the hand model on shore.
		if pistol_node != null: pistol_node.visible = not swimming and weapon == 1 and held_id == ""
		if held_node != null: held_node.visible = not swimming
	if swimming:
		speed = 3.4 if Input.is_action_pressed("sprint") else 2.2
	var target := dir * speed
	var accel := 28.0 if is_on_floor() else 8.0
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if swimming:
		# Float with the body just under the surface, gently bobbing.  The visual
		# body is lifted and laid flat below, independently of the collision capsule.
		var bob := sin(Time.get_ticks_msec() * 0.004) * 0.05
		var stroke := Vector2(velocity.x, velocity.z).length() > 0.4
		var sink := SWIM_SINK if stroke else IDLE_SINK     # swimming lies in the water with the back just awash, treading water is chest deep
		var target_y := WATER_Y - sink + bob
		diving = Input.is_action_pressed("walk_slow") and not get_tree().paused
		if diving:
			# Ctrl: dive. Down to near the seabed (never below the metro's roof), always lying flat; letting go brings you back up.
			var bed := CityData.height_at(global_position.x, global_position.z)
			target_y = clampf(maxf(bed + 0.5, -2.6), -2.6, WATER_Y - 0.12)
			if bed > -1.0: target_y = WATER_Y - 0.12
		velocity.y = clampf((target_y - global_position.y) * (3.0 if diving else 6.0), -2.4, 3.0)
		stroke = stroke or diving
	elif is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
		else:
			velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	step_t = maxf(0.0, step_t - delta)
	_step_up(delta)
	move_and_slide()

	# Face movement / camera direction
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if aiming and cam != null:
		face = lerp_angle(face, cam.yaw + PI, clampf(14.0 * delta, 0.0, 1.0))
	elif hspeed > 0.4 and punch_t <= 0.0:
		face = lerp_angle(face, atan2(velocity.x, velocity.z), clampf(12.0 * delta, 0.0, 1.0))
	model.rotation.y = face
	model.position = Vector3.ZERO
	model.rotation = Vector3(0.0, face, 0.0)         # the swim clips themselves lie the body flat (crawl) or stand it in the water (treading)

	# Attack inputs
	var editing := edit_pose != ""
	if editing:
		pass
	elif weapon == 0 and Input.is_action_just_pressed("attack") and punch_t <= 0.0 and not get_tree().paused:
		punch_t = 0.45
		play("Punch_Jab", 1.4, 0.05)
		_do_punch()
	elif weapon == 1 and Input.is_action_pressed("attack") and not get_tree().paused and not swimming:
		_shoot()
	elif weapon == 2 and Input.is_action_just_pressed("attack") and melee_t <= 0.0 and not get_tree().paused and not swimming:
		_melee_attack()
	elif weapon == 3 and Input.is_action_just_pressed("attack") and melee_t <= 0.0 and not get_tree().paused and not swimming:
		_throw()

	# Animation selection
	var pitch := cam.pitch if cam != null else 0.32
	if swimming:
		# the downloaded crawl-stroke and treading-water clips (Universal Animation Library), speed following the swimmer
		play("Swim_Fwd" if (hspeed > 0.4 or diving) else "Swim_Idle", clampf(hspeed / 1.8, 0.9, 1.5) if hspeed > 0.4 else 1.0, 0.25)
	elif edit_pose != "" and edit_pose != "aim":
		var ec := {"idle": "idle", "run": "run", "swing": "idle"}.get(edit_pose, "idle") as String
		var clip := _wanim(ec)
		play(clip if clip != "" and anim.has_animation(clip) else "Idle")
		if edit_pose == "swing" and weapon == 2: play("Melee_Attack1", 0.0, 0.0)
	elif punch_t > 0.0 or melee_t > 0.0:
		pass
	elif reload_t > 0.0 and anim.has_animation("Pistol_Reload"):
		play("Pistol_Reload", 1.25, 0.1)
	elif shot_anim_t > 0.0 and anim.has_animation(_wanim("shoot")):
		play(_wanim("shoot"), 1.8 if not _is_rifle_class() else 1.0, 0.04)
	elif not is_on_floor() and step_t <= 0.0:
		play("Jump", 1.0, 0.1)
	elif aiming:
		if hspeed > 0.4:
			var wk := _wanim("walk")
			play(wk if anim.has_animation(wk) else "Walk", clampf(hspeed / PISTOL_WALK_V, 0.7, 1.5), 0.15)
			_apply_aim_upper_body(pitch)
		elif _is_rifle_class() and anim.has_animation("Rifle_Ready"):
			play("Rifle_Ready", 1.0, 0.15)
		else:
			if false:
				pass
			else:
				play("Pistol_Aim_Neutral", 1.0, 0.15)
	elif hspeed > 5.5:
		play("Sprint", clampf(hspeed / SPRINT_V, 0.8, 1.5))
	elif hspeed > 2.2:
		# running: pistol run only with the pistol drawn, otherwise the plain jog
		if _wanim("run") != "" and anim.has_animation(_wanim("run")):
			play(_wanim("run"), clampf(hspeed / PISTOL_RUN_V, 0.8, 1.5))
		else:
			play("Jog_Fwd", clampf(hspeed / JOG_V, 0.8, 1.5))
	elif hspeed > 0.3:
		if _wanim("walk") != "" and anim.has_animation(_wanim("walk")):
			play(_wanim("walk"), clampf(hspeed / PISTOL_WALK_V, 0.6, 1.5))
		else:
			play("Walk", clampf(hspeed / WALK_V, 0.6, 1.5))
	else:
		play(_wanim("idle") if _wanim("idle") != "" and anim.has_animation(_wanim("idle")) else ("Pistol_Idle" if weapon == 1 else "Idle"))

	# Dynamic torso pitch adjustment while aiming or shooting
	if (aiming or shot_anim_t > 0.0) and is_instance_valid(sk) and spine1_idx >= 0:
		var pitch_offset := (0.32 - pitch) * 0.45 + _recoil_pitch
		var pitch_quat := Quaternion(Vector3.RIGHT, pitch_offset)
		sk.set_bone_pose_rotation(spine1_idx, sk.get_bone_pose_rotation(spine1_idx) * pitch_quat)

	# a heavy gun drags the torso back and makes the upper body sway with the steps
	if weapon == 1 and held_id != "" and bool(held_info.get("heavy", false)) and is_instance_valid(sk) and spine1_idx >= 0:
		var sway := sin(Time.get_ticks_msec() * 0.006) * 0.025 * clampf(hspeed / 3.0, 0.0, 1.0)
		var lean := Quaternion(Vector3.RIGHT, -0.12 + sway) * Quaternion(Vector3.FORWARD, sway * 1.5)
		sk.set_bone_pose_rotation(spine1_idx, sk.get_bone_pose_rotation(spine1_idx) * lean)
		if spine2_idx >= 0: sk.set_bone_pose_rotation(spine2_idx, sk.get_bone_pose_rotation(spine2_idx) * Quaternion(Vector3.RIGHT, -0.08))

	_update_underwater()
	_water_fx(delta)

	# Footstep sounds
	if is_on_floor() and hspeed > 1.0 and not swimming:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.55 if hspeed < 2.5 else (0.34 if hspeed < 5.5 else 0.27)
			_foot.stream = load("res://assets/audio/footsteps/walk_concrete_02.ogg") as AudioStream
			_foot.pitch_scale = randf_range(0.9, 1.1)
			_foot.play()

func _apply_aim_upper_body(pitch: float) -> void:
	if not is_instance_valid(sk): return
	var key := "Pistol_Aim_Neutral"
	if _is_rifle_class() and aim_bone_rotations.has("Rifle_Ready"):
		key = "Rifle_Ready"
	elif pitch > 0.45 and aim_bone_rotations.has("Pistol_Aim_Down"):
		key = "Pistol_Aim_Down"
	elif pitch < 0.20 and aim_bone_rotations.has("Pistol_Aim_Up"):
		key = "Pistol_Aim_Up"

	if not aim_bone_rotations.has(key): return
	var map: Dictionary = aim_bone_rotations[key]
	for idx in map:
		sk.set_bone_pose_rotation(idx, map[idx])

func _process(_delta: float) -> void:
	# the pistol clips hold the gun in the hand; the gun just follows the hand bone
	if pistol_node != null and is_instance_valid(pistol_node):
		HandGun.hold(pistol_node)
		# the gun is in hand whenever the pistol is selected (and not driving)
		pistol_node.visible = weapon == 1 and held_id == "" and state == State.ON_FOOT
	if held_node != null and is_instance_valid(held_node):
		if weapon == 1: Weapons.hold(held_node, sk, held_front)
		elif weapon == 2 and sk != null: Weapons.hold_melee(held_node, sk)
		else: HandGun.hold(held_node)
		held_base = held_node.global_transform
		if edit_pose == "": grip_off = Weapons.grip_offset(held_id, grip_pose())
		if held_id != "": held_node.global_transform = held_base * grip_off
		held_node.visible = weapon != 0 and held_id != "" and state == State.ON_FOOT and not scoped

## Steps a body along a path of waypoints: t in 0..1 over n segments, each eased.
func _along(pts: Array, t: float) -> Vector3:
	var n := pts.size() - 1
	var f := clampf(t, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	var k := smoothstep(0.0, 1.0, f - i)
	return (pts[i] as Vector3).lerp(pts[i + 1] as Vector3, k)

func _facing_to(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)

func _process_entering_car(delta: float) -> void:
	if active_car == null or not is_instance_valid(active_car):
		state = State.ON_FOOT
		shape.disabled = false
		return
	car_anim_t += delta
	if car_anim_t < 0.0:
		return                    # still pulling the driver out
	var c := active_car
	var s := (c.drv_x if car_door_side <= 0.0 else -c.drv_x)
	if car_anim_t < _walk_t:
		# walk round the car to the driver's door
		var d := car_anim_t / _walk_t
		var tot := 0.0
		var lens: Array[float] = []
		for i in range(_walk_pts.size() - 1):
			var l := Vector2(_walk_pts[i + 1].x - _walk_pts[i].x, _walk_pts[i + 1].z - _walk_pts[i].z).length()
			lens.append(l)
			tot += l
		var dist := d * tot
		var seg := 0
		while seg < lens.size() - 1 and dist > lens[seg]:
			dist -= lens[seg]
			seg += 1
		var a: Vector3 = _walk_pts[seg]
		var b: Vector3 = _walk_pts[seg + 1]
		var u := clampf(dist / maxf(lens[seg], 0.001), 0.0, 1.0)
		var wp := c.to_global(a.lerp(b, u))
		global_position = Vector3(wp.x, global_position.y, wp.z)
		var dir := c.to_global(b) - c.to_global(a)
		face = lerp_angle(face, atan2(dir.x, dir.z), clampf(12.0 * delta, 0.0, 1.0))
		model.rotation.y = face
		return
	if not _door_opened:
		_door_opened = true
		c.open_door(car_door_side, 0.45, Car.DOOR_WIDE)
		play("Sitting_Enter", 1.0, 0.15)
		car_start_pos = global_position
		car_start_rot = face
	var t := car_anim_t - _walk_t
	var path := c.entry_path(car_door_side)
	var stand: Vector3 = path[0]
	var sill: Vector3 = path[1]
	var own: Vector3 = path[2]
	var drv: Vector3 = path[3]
	var to_car := _facing_to(-c.global_transform.basis.x * s)
	var car_yaw := _facing_to(c.forward_dir())
	if cur_anim == "PickUp_Table":
		play("Sitting_Enter", 1.0, 0.15)
	var start := Vector3(car_start_pos.x, stand.y, car_start_pos.z)
	if t < 0.55:
		# walk up to the door, facing the car
		global_position = start.lerp(stand, smoothstep(0.0, 1.0, t / 0.55))
		face = lerp_angle(car_start_rot, to_car, smoothstep(0.0, 1.0, t / 0.4))
	elif t < 0.9:
		# reach in and step onto the sill
		global_position = stand.lerp(sill, smoothstep(0.0, 1.0, (t - 0.55) / 0.35))
		face = to_car
	elif t < 1.45:
		# sit down: slide through the doorway, drop onto the seat and turn to face forward
		if _seat_phase == 0:
			_seat_phase = 1
			_set_legs_hidden(true)
			play("Driving", 1.0, 0.25)
		var q := (t - 0.9) / 0.55
		var xz := sill.lerp(own, smoothstep(0.0, 1.0, q))
		xz.y = lerpf(sill.y, own.y, smoothstep(0.25, 1.0, q))
		global_position = xz
		face = lerp_angle(to_car, car_yaw, smoothstep(0.0, 1.0, q))
	else:
		global_position = own.lerp(drv, smoothstep(0.0, 1.0, (t - 1.45) / 0.25))
		face = car_yaw
	model.rotation.y = face
	if t >= 1.5 and not _door_sfx_played:
		_door_sfx_played = true
		if c.has_method("close_door"):
			c.close_door(car_door_side, 0.35)
		else:
			_play_sfx("res://assets/audio/vehicles/door_close_01.ogg")
	if car_anim_t >= car_anim_duration:
		state = State.IN_CAR
		c.enter(self)
		Game.in_car = c
		play("Driving", 1.0, 0.15)

## While seated the lower legs would poke out under the floor, so shrink the calves (and the feet below them).
func _set_legs_hidden(hide: bool) -> void:
	if not is_instance_valid(sk): return
	if hide and active_car != null and is_instance_valid(active_car) and active_car.def.get("open", false): return   # open cart: the legs stay visible
	for n in ["mixamorig_LeftLeg", "mixamorig_RightLeg"]:
		var i := sk.find_bone(n)
		if i >= 0:
			sk.set_bone_pose_scale(i, Vector3.ONE * (0.001 if hide else 1.0))

func _process_in_car(_delta: float) -> void:
	var c := Game.in_car as Car
	if c == null: c = active_car
	if c == null or not is_instance_valid(c):
		state = State.ON_FOOT
		shape.disabled = false
		return
	active_car = c
	state = State.IN_CAR
	aiming = false
	Game.aiming = false
	_set_legs_hidden(true)
	global_position = c.get_driver_seat_pos()
	var car_yaw := atan2(c.forward_dir().x, c.forward_dir().z)
	face = car_yaw
	model.rotation.y = face
	play("Driving", 1.0, 0.15)

	if is_instance_valid(sk) and spine2_idx >= 0:
		var lean := -c.steering * 0.22
		sk.set_bone_pose_rotation(spine2_idx, sk.get_bone_pose_rotation(spine2_idx) * Quaternion(Vector3.UP, lean))

func _process_exiting_car(delta: float) -> void:
	car_anim_t += delta
	var t := car_anim_t
	var c := active_car
	if c == null or not is_instance_valid(c):
		# the car vanished: just stand up where we are
		state = State.ON_FOOT
		shape.disabled = false
		_set_legs_hidden(false)
		Game.in_car = null
		active_car = null
		play("Idle", 1.0, 0.15)
		return
	var s := (c.drv_x if car_door_side <= 0.0 else -c.drv_x)
	var path := c.entry_path(car_door_side)
	var stand: Vector3 = _exit_to if _exit_to != Vector3.ZERO else path[0]
	var sill: Vector3 = path[1]
	var own: Vector3 = path[3]          # we always start from the driver's seat
	var out_face := _facing_to(c.global_transform.basis.x * s)
	var car_yaw := _facing_to(c.forward_dir())
	if t < 0.3:
		# door swings open, hands come off the wheel
		global_position = own
		face = car_yaw
	elif t < 0.85:
		# slide across and up through the doorway, turning towards it
		var q := (t - 0.3) / 0.55
		var xz := own.lerp(sill, smoothstep(0.0, 1.0, q))
		xz.y = lerpf(own.y, sill.y, smoothstep(0.0, 0.75, q))
		global_position = xz
		face = lerp_angle(car_yaw, out_face, smoothstep(0.0, 1.0, q))
	else:
		if _seat_phase == 0:
			_seat_phase = 1
			_set_legs_hidden(false)
			play("Walk", 0.9, 0.2)
		global_position = sill.lerp(stand, smoothstep(0.0, 1.0, (t - 0.85) / 0.5))
		face = out_face
	model.rotation.y = face
	if t >= 1.35 and not _door_sfx_played:
		_door_sfx_played = true
		c.close_door(car_door_side, 0.35)
	if t >= car_anim_duration:
		state = State.ON_FOOT
		shape.disabled = false
		_set_legs_hidden(false)
		global_position = stand
		_exit_to = Vector3.ZERO
		c.exit_car(car_door_side)
		active_car = null
		Game.in_car = null
		if pistol_node != null and weapon == 1:
			pistol_node.visible = true
		play("Idle", 1.0, 0.2)

func _process_rolling(delta: float) -> void:
	_roll_t -= delta
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	velocity.y -= GRAVITY * delta
	if is_on_floor() and velocity.y < 0.0: velocity.y = -1.0
	move_and_slide()
	model.rotation.y = face
	if _roll_t <= 0.0:
		state = State.ON_FOOT
		shape.disabled = false
		play("Idle", 1.0, 0.2)

## Kerbs, pavement edges and low steps: when walking into something up to STEP_H high with room above it, the player is lifted onto it
## instead of having to jump (the floor snap then settles the feet on the top).
const STEP_H := 0.45

func _step_up(delta: float) -> void:
	if not is_on_floor() or swimming: return
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if h.length() < 0.5: return
	var ahead := h.normalized() * maxf(h.length() * delta, 0.16)
	if not test_move(global_transform, ahead): return                      # nothing in the way
	if test_move(global_transform, Vector3(0.0, STEP_H, 0.0)): return      # no headroom
	# lift by the smallest height that clears the obstacle, so tiny lips (shop thresholds) are not a hop
	for lift in [0.04, 0.1, 0.18, 0.28, STEP_H]:
		var raised := global_transform
		raised.origin.y += lift
		if not test_move(raised, ahead):
			global_position.y += lift + 0.01
			step_t = 0.3
			return

var step_t := 0.0                                                            # > 0 just after a step-up: no jump / fall pose

func _do_punch() -> void:
	var f := Vector3(sin(face), 0, cos(face))
	for p in get_tree().get_nodes_in_group("peds"):
		var d := (p as Node3D).global_position - global_position
		if d.length() < 1.6 and d.normalized().dot(f) > 0.3:
			if p.has_method("hit"):
				p.hit(25.0, f, true)

func _shoot() -> void:
	if shoot_cd > 0.0 or reload_t > 0.0:
		return
	var shop := held_id != ""
	var inf: Dictionary = held_info if shop else {}
	if shop:
		if not _take_round():
			shoot_cd = 0.35
			_play_sfx("res://assets/audio/guns_and_gameplay/dry_fire_01.ogg")
			return
	elif ammo <= 0:
		reload_t = 1.3
		play("Pistol_Reload", 1.25, 0.1)
		if pistol_anim_player != null:
			pistol_anim_player.play("reload", -1, 1.2)
		return
	else:
		ammo -= 1
	var dmg := float(inf.get("dmg", 34.0))
	var pellets := int(inf.get("pellets", 1))
	var spread := float(inf.get("spread", 0.0))
	shoot_cd = float(inf.get("cd", 0.26))
	shot_anim_t = minf(shoot_cd, 0.28) if _is_rifle_class() else 0.28
	_recoil_pitch = 0.22 if not shop else (0.5 if String(inf.get("kind", "")) == "shotgun" else (0.3 if bool(inf.get("heavy", false)) else 0.16))

	# Gun animation & recoil
	if not shop:
		play("Pistol_Shoot", 1.8, 0.04)
		if pistol_anim_player != null:
			pistol_anim_player.stop()
			pistol_anim_player.play("fire", -1, 1.4)
	if cam != null:
		cam.add_shake(0.32 if not shop else clampf(dmg / 120.0 + 0.1, 0.15, 0.9))

	var sfx: Array = inf.get("sfx", ["res://assets/audio/guns/pistol_1911_01.mp3", "res://assets/audio/guns/pistol_1911_02.mp3"]) if shop else ["res://assets/audio/guns/pistol_1911_01.mp3", "res://assets/audio/guns/pistol_1911_02.mp3"]
	_shot_sfx.stream = load(String(sfx[randi() % sfx.size()])) as AudioStream
	_shot_sfx.pitch_scale = randf_range(0.95, 1.05)
	_shot_sfx.play()

	# Muzzle flash and shell casing
	var gun_node: Node3D = held_node if (shop and held_node != null) else pistol_node
	var muzzle_pos := global_position + Vector3(sin(face) * 0.6, 1.35, cos(face) * 0.6)
	var shoot_dir := Vector3(sin(face), 0, cos(face))
	if shop and held_node != null and is_instance_valid(held_node):
		muzzle_pos = held_node.to_global(held_muzzle)
		shoot_dir = (held_node.to_global(held_muzzle + Vector3(0, 0, 0.2)) - muzzle_pos).normalized()
	elif pistol_node != null and is_instance_valid(pistol_node):
		muzzle_pos = pistol_node.to_global(Vector3(0.0, 0.04, 0.14))
		shoot_dir = (pistol_node.to_global(Vector3(0.0, 0.04, 0.3)) - muzzle_pos).normalized()
		_eject_casing(pistol_node.to_global(Vector3(0.015, 0.03, 0.05)))
	_muzzle_flash(muzzle_pos, shoot_dir)

	# Raycasts from the camera through the crosshair (several pellets for a shotgun)
	var c := Game.camera
	if c == null: return
	var from := c.global_position
	var base_dir := -c.global_transform.basis.z
	for k in pellets:
		var dir := base_dir
		if spread > 0.0:
			dir = (base_dir + c.global_transform.basis.x * randf_range(-spread, spread) + c.global_transform.basis.y * randf_range(-spread, spread)).normalized()
		var q := PhysicsRayQueryParameters3D.create(from + dir * 1.5, from + dir * 140.0, 1 | 4 | 8 | 16)
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var col: Object = hit.collider
			if col is Ped:
				(col as Ped).hit(dmg, dir, true)
			elif col is Car:
				(col as Car).hp -= dmg * 0.4
			if k == 0 or pellets == 1: _spark(hit.position)

	# The neighbourhood notices gunfire
	var noticed := false
	for p in get_tree().get_nodes_in_group("peds"):
		if (p as Node3D).global_position.distance_to(global_position) < 35.0:
			(p as Ped).scare(global_position)
			noticed = true
	if noticed and randf() < 0.18:
		Game.add_wanted(1)

## One round from the gun's own pool, then from the shared ammo reserve (bought ammo boxes).
func _take_round() -> bool:
	if int(Game.guns_owned.get(held_id, 0)) > 0:
		Game.guns_owned[held_id] = int(Game.guns_owned[held_id]) - 1
		return true
	if Game.ammo_reserve > 0:
		Game.ammo_reserve -= 1
		return true
	return false

## Starts a melee swing: the clip plays now, the hit lands part way through it.
func _melee_attack() -> void:
	var clips := ["Melee_Attack1", "Melee_Attack2", "Melee_Attack3"]
	var clip: String = clips[melee_combo % clips.size()]
	melee_combo += 1
	var a: Animation = anim.get_animation(clip) if anim.has_animation(clip) else null
	var dur: float = a.length if a != null else 0.8
	var speed := 1.5
	melee_t = dur / speed
	melee_hit_t = float(held_info.get("hit", 0.28)) * dur / speed + 0.1
	play(clip, speed, 0.08)
	_play_sfx(String(Weapons.SWING_SFX[0]))

## Water animation round the player: expanding rings on the surface (faster when moving), a V-shaped wake behind a swimmer, droplets
## thrown up by the strokes, and small rings round the feet when wading through shallows.
var _fx_t := 0.0
var _spray: CPUParticles3D
var _mist: CPUParticles3D
var _tex_cache := {}

func _vfx_tex(name: String) -> Texture2D:
	if not _tex_cache.has(name): _tex_cache[name] = load("res://assets/vfx/%s.png" % name) as Texture2D
	return _tex_cache[name]

func _sprite_mat(tex: Texture2D, tint: Color, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = tint
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
	return m

## One ripple: a flat ring sprite (Kenney particle pack) that spreads over the water and fades.
func _ripple(at: Vector3, size: float, life: float, strength: float) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.orientation = PlaneMesh.FACE_Y
	qm.size = Vector2.ONE
	mi.mesh = qm
	var m := _sprite_mat(_vfx_tex("circle_02" if randf() < 0.6 else "circle_04"), Color(1, 1, 1, 0.5 * strength), false)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	mi.global_position = Vector3(at.x, WATER_Y + 0.05, at.z)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(0.4, 1.0, 0.4)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(size, 1.0, size), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)

func _make_spray() -> void:
	# droplets: fleck sprites flung up and out, falling back under gravity
	_spray = CPUParticles3D.new()
	_spray.amount = 36
	_spray.lifetime = 0.8
	_spray.direction = Vector3(0, 1, 0)
	_spray.spread = 55.0
	_spray.initial_velocity_min = 1.2
	_spray.initial_velocity_max = 3.2
	_spray.gravity = Vector3(0, -8.0, 0)
	_spray.scale_amount_min = 0.12
	_spray.scale_amount_max = 0.34
	_spray.angle_max = 360.0
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.material = _sprite_mat(_vfx_tex("dirt_01"), Color(0.95, 0.99, 1.0, 0.9), true)
	_spray.mesh = qm
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	_spray.color_ramp = g
	_spray.top_level = true
	add_child(_spray)
	# mist: soft puffs that rise and thin out
	_mist = CPUParticles3D.new()
	_mist.amount = 10
	_mist.lifetime = 1.1
	_mist.direction = Vector3(0, 1, 0)
	_mist.spread = 35.0
	_mist.initial_velocity_min = 0.3
	_mist.initial_velocity_max = 0.9
	_mist.gravity = Vector3(0, 0.0, 0)
	_mist.scale_amount_min = 0.35
	_mist.scale_amount_max = 0.8
	_mist.angle_max = 360.0
	var qm2 := QuadMesh.new()
	qm2.size = Vector2.ONE
	qm2.material = _sprite_mat(_vfx_tex("smoke_05"), Color(0.95, 0.98, 1.0, 0.55), true)
	_mist.mesh = qm2
	var g2 := Gradient.new()
	g2.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	g2.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	_mist.color_ramp = g2
	_mist.top_level = true
	add_child(_mist)

func _water_fx(delta: float) -> void:
	var wading := false
	if not swimming and state == State.ON_FOOT and CityData.is_loaded and CityData.is_water(global_position.x, global_position.z):
		var depth := WATER_Y - CityData.height_at(global_position.x, global_position.z)
		wading = depth > 0.05 and global_position.y < WATER_Y + 0.9
	if not swimming and not wading:
		if _spray != null:
			_spray.emitting = false
			_mist.emitting = false
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	var fwd := Vector3(sin(face), 0.0, cos(face))
	var side := Vector3(cos(face), 0.0, -sin(face))
	_fx_t -= delta
	if _fx_t <= 0.0:
		if swimming:
			_fx_t = 0.38 if moving else 1.0
			_ripple(global_position - fwd * (0.5 if moving else 0.0), 2.4 if moving else 1.8, 1.7 if moving else 2.2, 1.0)
			if moving:
				# the wake: rings spreading out from either side behind the swimmer
				_ripple(global_position - fwd * 1.5 + side * 0.8, 1.5, 1.4, 0.55)
				_ripple(global_position - fwd * 1.5 - side * 0.8, 1.5, 1.4, 0.55)
		elif moving:
			_fx_t = 0.3
			_ripple(global_position, 1.3, 1.0, 0.8)
	if _spray == null: _make_spray()
	var at := Vector3(global_position.x, WATER_Y + 0.05, global_position.z)
	_spray.emitting = moving and swimming
	_mist.emitting = moving
	_spray.global_position = at + fwd * 0.6
	_mist.global_position = at + fwd * 0.4

## Under the surface: a blue-green tint over the screen and a muffled look (the camera itself is below sea level).
func _update_underwater() -> void:
	var cam3 := Game.camera as Camera3D
	var under := cam3 != null and swimming and cam3.global_position.y < WATER_Y - 0.15
	if under and _under_layer == null:
		_under_layer = CanvasLayer.new()
		_under_layer.layer = 5
		var r := ColorRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.color = Color(0.03, 0.32, 0.4, 0.5)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_under_layer.add_child(r)
		add_child(_under_layer)
	if _under_layer != null: _under_layer.visible = under

## Snipers have no mounted scope: aiming (right mouse) looks through a zoomed scope with a crosshair, the player model is hidden.
func _update_scope() -> void:
	var want := edit_pose == "" and weapon == 1 and held_id != "" and bool(held_info.get("scope", false)) and Input.is_action_pressed("aim") and not swimming and not get_tree().paused and state == State.ON_FOOT and not Game.dead
	if want != scoped:
		scoped = want
		Game.scoped = want
		if model != null: model.visible = not want
		if _scope_layer == null and want:
			_scope_layer = _make_scope_layer()
		if _scope_layer != null: _scope_layer.visible = want

func _make_scope_layer() -> CanvasLayer:
	var l := CanvasLayer.new()
	l.layer = 35
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 sz = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (UV - 0.5) * vec2(sz.x / sz.y, 1.0);
	float d = length(p);
	float outside = smoothstep(0.446, 0.452, d);
	float line = max(smoothstep(0.0012, 0.0, abs(p.x)), smoothstep(0.0012, 0.0, abs(p.y))) * step(d, 0.45) * step(0.012, d);
	float dots = 0.0;
	for (int i = 1; i < 6; i++) {
		float o = float(i) * 0.035;
		dots += smoothstep(0.003, 0.0, length(p - vec2(o, 0.0))) + smoothstep(0.003, 0.0, length(p + vec2(o, 0.0))) + smoothstep(0.003, 0.0, length(p - vec2(0.0, o))) + smoothstep(0.003, 0.0, length(p + vec2(0.0, o)));
	}
	float rim = smoothstep(0.006, 0.0, abs(d - 0.449));
	float mark = clamp(line + dots, 0.0, 1.0) * (1.0 - outside);
	COLOR = vec4(0.0, 0.0, 0.0, max(outside, max(mark, rim * 0.9)));
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	l.add_child(r)
	add_child(l)
	return l

## Throws the grenade / molotov in the hand: the overhand swing plays and the item leaves the hand part way through.
func _throw() -> void:
	if int(Game.guns_owned.get(held_id, 0)) <= 0: return
	Game.guns_owned[held_id] = int(Game.guns_owned[held_id]) - 1
	melee_t = 0.8
	play("Melee_Attack2", 1.6, 0.05)
	await get_tree().create_timer(0.3).timeout
	if state != State.ON_FOOT or Game.dead: return
	var from := global_position + Vector3(sin(face) * 0.5, 1.5, cos(face) * 0.5)
	if held_node != null and is_instance_valid(held_node): from = held_node.global_position
	var c := Game.camera
	var dir := Vector3(sin(face), 0.0, cos(face)) if c == null else -c.global_transform.basis.z
	var vel := dir * 15.0 + Vector3(0, 5.0, 0)
	Thrown.launch(get_tree().current_scene, held_id, from, vel)
	if int(Game.guns_owned.get(held_id, 0)) <= 0:
		equip("")

func _melee_hit() -> void:
	if weapon != 2: return
	var f := Vector3(sin(face), 0, cos(face))
	var reach := float(held_info.get("reach", 1.9))
	var dmg := float(held_info.get("dmg", 40.0))
	for p in get_tree().get_nodes_in_group("peds"):
		var d := (p as Node3D).global_position - global_position
		if d.length() < reach and d.normalized().dot(f) > 0.2 and p.has_method("hit"):
			p.hit(dmg, f, true)
	if cam != null: cam.add_shake(0.25)

func _muzzle_flash(pos: Vector3, dir: Vector3) -> void:
	var fl := OmniLight3D.new()
	fl.light_color = Color("#ffd080")
	fl.light_energy = 5.0
	fl.omni_range = 5.0
	get_tree().current_scene.add_child(fl)
	fl.global_position = pos
	get_tree().create_timer(0.05).timeout.connect(fl.queue_free)

	var m := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.25, 0.25)
	m.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ffffff")
	mat.emission_enabled = true
	mat.emission = Color("#ffb030")
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	m.global_position = pos + dir * 0.05
	get_tree().create_timer(0.04).timeout.connect(m.queue_free)

func _eject_casing(pos: Vector3) -> void:
	var casing := ShellCasing.new(pos, pistol_node.global_transform.basis if pistol_node != null else global_transform.basis)
	get_tree().current_scene.add_child(casing)

func _spark(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ffd060")
	mat.emission_enabled = true
	mat.emission = Color("#ffb030")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	m.global_position = pos
	get_tree().create_timer(0.12).timeout.connect(m.queue_free)

class ShellCasing extends MeshInstance3D:
	var spawn_pos: Vector3
	var vel: Vector3
	var rot_speed: Vector3
	var life := 1.8

	func _init(start_pos: Vector3, gun_basis: Basis) -> void:
		spawn_pos = start_pos
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.008
		cyl.bottom_radius = 0.008
		cyl.height = 0.026
		cyl.radial_segments = 6
		mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#e5be42")
		mat.metallic = 0.95
		mat.roughness = 0.2
		material_override = mat
		vel = gun_basis * Vector3(randf_range(1.5, 2.5), randf_range(1.8, 3.2), randf_range(-0.4, 0.4))
		rot_speed = Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15))

	func _ready() -> void:
		top_level = true
		global_position = spawn_pos

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		vel.y -= 18.0 * delta
		global_position += vel * delta
		rotate_x(rot_speed.x * delta)
		rotate_y(rot_speed.y * delta)
		if global_position.y < 0.02 and vel.y < 0.0:
			global_position.y = 0.02
			vel.y = -vel.y * 0.35
			vel.x *= 0.6
			vel.z *= 0.6
			rot_speed *= 0.5

