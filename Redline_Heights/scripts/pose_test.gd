extends SceneTree
## Dev tool: renders animation frames to /tmp/rh.
## Run: godot --path . -s res://scripts/pose_test.gd -- Walk 0,0.25,0.5,0.75 Male/Character_04
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var anim_name: String = args[0] if args.size() > 0 else "Walk"
	var times := PackedStringArray((args[1] if args.size() > 1 else "0,0.25,0.5,0.75").split(","))
	var id: String = args[2] if args.size() > 2 else "hero"
	await process_frame
	var game := root.get_node("Game")
	var model: Node3D = game.load_character(id)
	root.add_child(model)
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", game.get_anim_library(id))
	var gun: Node3D = null
	var gun_hand: Node3D = null
	if "gun" in args:
		var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var ba := BoneAttachment3D.new()
		ba.bone_name = "mixamorig_RightHand"
		sk.add_child(ba)
		var pistol := HandGun.make()
		ba.add_child(pistol)
		gun = pistol
		gun_hand = ba
	var cam := Camera3D.new()
	root.add_child(cam)
	if "back" in args:
		cam.position = Vector3(0.25, 1.75, -1.7)
		cam.look_at(Vector3(0, 1.3, 0.3))
	elif "over" in args:
		cam.position = Vector3(0, 4.0, 0.001)
		cam.look_at(Vector3(0, 1.0, 0), Vector3(0, 0, -1))
	elif "front" in args:
		cam.position = Vector3(1.0, 1.35, 2.6)
		cam.look_at(Vector3(0, 1.2, 0))
	elif "close" in args:
		cam.position = Vector3(1.4, 1.5, 1.6)
		cam.look_at(Vector3(0, 1.3, 0.3))
	elif "top" in args:
		cam.position = Vector3(0.6, 2.6, 1.2)
		cam.look_at(Vector3(0, 1.2, 0.3))
	else:
		cam.position = Vector3(3.2, 1.0, 0.0)
		cam.look_at(Vector3(0, 0.8, 0))
	var l := DirectionalLight3D.new()
	root.add_child(l)
	l.rotation_degrees = Vector3(-40, 30, 0)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.5, 0.6, 0.7)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	root.add_child(we)
	DirAccess.make_dir_recursive_absolute("/tmp/rh")
	ap.play(anim_name)
	ap.pause()
	for t in times:
		ap.seek(float(t), true)
		await process_frame
		await process_frame
		if gun != null:
			var up := 0.0
			if "low" in args: up = -0.6
			elif "up" in args: up = 0.3
			HandGun.hold(gun)
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("/tmp/rh/%s_%s.png" % [anim_name, t])
	quit()
