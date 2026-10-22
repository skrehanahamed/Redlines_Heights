extends Node
## Dev tool: renders a parked car on the ground to /tmp/rh/car_<kind>.png.
## Run: godot --path . res://scenes/car_test.tscn -- <kind> [doors] [seat] [side|front]
##   doors  opens all doors,  seat  puts a seated driver in the car
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var kind: String = args[0] if args.size() > 0 else "sedan"
	await get_tree().process_frame
	var ground := StaticBody3D.new()
	var gcs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(60, 1, 60)
	gcs.shape = gb
	ground.add_child(gcs)
	ground.position.y = -0.5
	ground.collision_layer = 1
	add_child(ground)
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.25, 0.25, 0.27)
	gm.material_override = gmat
	add_child(gm)
	var car := Car.new()
	car.position = Vector3(0, 1.0, 0)
	add_child(car)
	car.setup(kind, "", not ("drive" in args))
	var cam := Camera3D.new()
	add_child(cam)
	if "nose" in args:
		cam.position = Vector3(0, 1.5, 4.2)
		cam.look_at(Vector3(0, 0.8, 0))
	elif "top" in args:
		cam.position = Vector3(0.05, 6.5, 0.5)
		cam.look_at(Vector3(0, 0.5, 0.5), Vector3(0, 0, -1))
	elif "left" in args:
		cam.position = Vector3(-6.0, 1.2, 0.5)
		cam.look_at(Vector3(0, 0.5, 0.2))
	elif "front" in args:
		cam.position = Vector3(5.5, 2.4, 5.5)
	elif "window" in args:
		cam.position = Vector3(car.model_len * 0.55, 1.3 + car.model_h * 0.15, car.model_len * 0.22)
	elif "close" in args:
		cam.position = Vector3(3.4, 1.5, 2.6)
	elif "side" in args:
		cam.position = Vector3(6.0, 1.2, 0.5)
	else:
		cam.position = Vector3(5.5, 3.2, 3.5)
	cam.look_at(Vector3(0, 0.9 if ("close" in args or "window" in args) else 0.5, 0.2))
	var l := DirectionalLight3D.new()
	add_child(l)
	l.rotation_degrees = Vector3(-40, 30, 0)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.5, 0.6, 0.7)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(we)
	await get_tree().create_timer(2.6).timeout
	if "wake" in args:
		car.player_controlled = true
		car.enter(self)
		car.scripted = false
		var t := 0.0
		while t < 2.0:
			await get_tree().create_timer(0.25).timeout
			t += 0.25
			print("WAKE t=%.2f pos=%s frozen=%s speed=%.2f" % [t, car.global_position, car.freeze, car.speed_ms])
		get_tree().quit()
		return
	if "drive" in args:
		car.scripted = true
		car.s_throttle = 1.0
		car.s_steer = 0.7
		var e0 := car.wheels[0].transform.basis.get_euler()
		await get_tree().create_timer(1.5).timeout
		var e1 := car.wheels[0].transform.basis.get_euler()
		var e2 := car.wheels[2].transform.basis.get_euler()
		print("DBG speed %.1f m/s  front wheel steer(yaw) %.2f rad  spin x %.2f -> %.2f, rear spin x %.2f, wheel mesh child: %s" % [car.speed_ms, e1.y, e0.x, e1.x, e2.x, car.wheels[0].get_child_count() > 0])
		get_tree().quit()
		return
	print("DBG settled y=%.3f frozen=%s" % [car.global_position.y, car.freeze])
	if "doors" in args:
		car.toggle_doors()
	if "nodoor" in args and car.door_fl:
		car.door_fl.visible = false
	if "seat" in args:
		var m: Node3D = Game.load_character(Game.MAIN_HERO)
		add_child(m)
		var ap := AnimationPlayer.new()
		m.add_child(ap)
		ap.root_node = NodePath("..")
		ap.add_animation_library("", Game.get_anim_library())
		ap.play("Driving")
		await get_tree().process_frame
		var msk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for n in ["mixamorig_LeftLeg", "mixamorig_RightLeg"]:
			msk.set_bone_pose_scale(msk.find_bone(n), Vector3.ONE * 0.001)
		m.global_position = car.get_driver_seat_pos()
		m.rotation.y = atan2(car.forward_dir().x, car.forward_dir().z)
	await get_tree().create_timer(0.6).timeout
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/rh")
	get_viewport().get_texture().get_image().save_png("/tmp/rh/car_%s.png" % kind)
	get_tree().quit()
