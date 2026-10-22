extends SceneTree
## Dev tool: renders the gun in the hand at all 24 right-angle orientations into /tmp/rh/gg_<n>.png
func _initialize() -> void:
	await process_frame
	var game := root.get_node("Game")
	var model: Node3D = game.load_character("hero")
	root.add_child(model)
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", game.get_anim_library("hero"))
	var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ba := BoneAttachment3D.new()
	ba.bone_name = "mixamorig_RightHand"
	sk.add_child(ba)
	var gun := HandGun.make()
	ba.add_child(gun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(1.4, 1.5, 1.6)
	cam.look_at(Vector3(0, 1.3, 0.3))
	var l := DirectionalLight3D.new()
	root.add_child(l)
	l.rotation_degrees = Vector3(-40, 30, 0)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.5, 0.6, 0.7)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root.add_child(we)
	ap.play("Pistol_Idle")
	ap.pause()
	ap.seek(0.0, true)
	var seen := []
	var n := 0
	for x in range(4):
		for y in range(4):
			for z in range(4):
				var b := Basis.from_euler(Vector3(x, y, z) * (PI * 0.5))
				var key := str(b.x.round()) + str(b.y.round()) + str(b.z.round())
				if key in seen: continue
				seen.append(key)
				gun.transform = Transform3D(b, HandGun.GUN_HAND_POS)
				await process_frame
				await process_frame
				var img := root.get_viewport().get_texture().get_image()
				img.save_png("/tmp/rh/gg_%02d.png" % n)
				print("GG ", n, " ", Vector3(x, y, z) * 90.0)
				n += 1
	quit()
