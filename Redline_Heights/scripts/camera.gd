class_name ThirdPersonCamera
extends Camera3D
## Orbit camera: over-the-shoulder on foot, chase camera in a car. Mouse looks around.

var yaw := 0.0
var pitch := 0.32
var sens := 0.0026
var idle_t := 0.0
var shake := 0.0
var player: Node3D

var cur_focus := Vector3.ZERO
var cur_dist := 3.6
var _first_frame := true

func _ready() -> void:
	far = 900.0
	fov = 65.0
	current = true
	Game.camera = self

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k := 0.25 if Game.scoped else 1.0
		yaw -= event.relative.x * sens * k
		pitch = clampf(pitch + event.relative.y * sens * k, -0.15, 1.25)
		idle_t = 0.0

func add_shake(a: float) -> void:
	shake = maxf(shake, a)

func _physics_process(delta: float) -> void:
	idle_t += delta
	# riding a metro with its doors shut: the camera is fixed behind the train looking down the tunnel the way it travels, and cannot be moved
	var rt := MetroTrain.riding
	if rt != null and is_instance_valid(rt) and player != null:
		var tb := rt.global_transform
		var from := tb * Vector3(0.0, 3.1, -rt.cam_back * rt.ride_end)        # outside, behind the rear of the train, in the tunnel
		var to := tb * Vector3(0.0, 2.0, 12.0 * rt.ride_end)
		global_position = from
		look_at(to, Vector3.UP)
		fov = lerpf(fov, 72.0, clampf(delta * 4.0, 0.0, 1.0))
		var fwd := (tb.basis * Vector3(0, 0, rt.ride_end))
		yaw = atan2(-fwd.x, -fwd.z)           # the player's controls follow the car's direction, so W walks along the car
		pitch = 0.2
		cur_focus = player.global_position + Vector3(0, 1.45, 0)
		_first_frame = false
		return
	var car := Game.in_car as Car
	var target_focus: Vector3
	var target_dist: float
	var side := Vector3.ZERO
	var heli := Game.in_heli as Chopper
	if heli != null:
		target_focus = heli.global_position + Vector3(0, 1.0 + heli.cam_dist * 0.05, 0)
		pitch = maxf(pitch, 0.14)       # never dip under the fuselage / wings
		target_dist = heli.cam_dist * 1.5 + clampf(heli.vel.length() * 0.12, 0.0, 6.0)
		if idle_t > 0.8 and heli.vel.length() > 3.0:
			yaw = lerp_angle(yaw, heli.yaw + PI, clampf(delta * 1.6, 0.0, 1.0))
		fov = lerpf(fov, 70.0, clampf(delta * 3.0, 0.0, 1.0))
	elif car != null:
		# long / tall vehicles (ambulance) get the camera further back and higher so it stays outside the body
		var big := clampf(car.model_len - 4.8, 0.0, 3.0)
		target_focus = car.global_position + Vector3(0, 0.85 + big * 0.9, 0) + car.linear_velocity * 0.03
		var spd := absf(car.speed_ms)
		target_dist = 4.7 + big * 1.8 + clampf(spd * 0.02, 0.0, 0.9)
		# swing behind the car while it moves and the mouse is idle
		if idle_t > 0.8 and car.linear_velocity.length() > 2.0:
			var f := car.forward_dir() * (1.0 if car.speed_ms >= 0.0 else -1.0)
			var target_yaw := atan2(-f.x, -f.z)
			yaw = lerp_angle(yaw, target_yaw, clampf(delta * 2.2, 0.0, 1.0))
		fov = lerpf(fov, 62.0 + clampf(spd * 0.2, 0.0, 9.0), clampf(delta * 3.0, 0.0, 1.0))
	elif player != null:
		target_focus = player.global_position + Vector3(0, 1.45, 0)
		target_dist = 2.3 if Game.aiming else 3.5
		if Game.scoped: target_dist = 0.12
		var sdir := Metro.stair_dir(player.global_position)
		if sdir != 0.0:
			# inside a stair corridor the camera is held behind the player along the stairs, so it can never swing out through the walls
			target_dist = 1.6
			var fx := sin(player.face)
			var fz := cos(player.face)
			var going_down := fz * sdir > 0.0
			var want_yaw := atan2(-fx, -fz)
			if absf(fz) < 0.3: want_yaw = yaw                  # facing sideways: leave it as it is
			yaw = lerp_angle(yaw, want_yaw, clampf(delta * 8.0, 0.0, 1.0))
			pitch = lerpf(pitch, 0.5 if going_down else -0.1, clampf(delta * 8.0, 0.0, 1.0))
		if player.get("air_mode") != null and int(player.get("air_mode")) != 0:
			target_dist = 8.0               # pull back and stay low so the whole canopy is in view
			pitch = clampf(pitch, 0.0, 0.25)
			target_focus.y += 1.4             # look at the canopy and the player together
		side = Vector3(cos(yaw), 0, -sin(yaw)) * (0.8 if Game.aiming else 0.55)
		if Game.scoped:
			side = Vector3.ZERO
			target_focus = player.global_position + Vector3(0, 1.6, 0)
		fov = lerpf(fov, 12.0 if Game.scoped else (52.0 if Game.aiming else 65.0), clampf(delta * 8.0, 0.0, 1.0))
	else:
		return
	target_focus += side

	if _first_frame:
		cur_focus = target_focus
		cur_dist = target_dist
		_first_frame = false
	else:
		cur_focus = cur_focus.lerp(target_focus, clampf(delta * (16.0 if car != null else 8.0), 0.0, 1.0))
		cur_dist = lerpf(cur_dist, target_dist, clampf(delta * 6.0, 0.0, 1.0))

	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * cur_dist
	var desired := cur_focus + offset
	# keep the camera out of walls
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cur_focus, desired, 1)
	# never let the vehicle we are in (or the player) block the view, or the camera ends up inside the plane
	var skip: Array[RID] = []
	if heli != null:
		for b in heli.find_children("*", "CollisionObject3D", true, false):
			skip.append((b as CollisionObject3D).get_rid())
	if car != null: skip.append(car.get_rid())
	if player is CollisionObject3D: skip.append((player as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		desired = (hit.position as Vector3) + (cur_focus - desired).normalized() * 0.3
	global_position = desired
	if shake > 0.0:
		global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.3
		shake = maxf(0.0, shake - delta * 2.0)
	look_at(cur_focus, Vector3.UP)
