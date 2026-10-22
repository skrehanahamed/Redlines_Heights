extends SceneTree
## --m=path --t=0,5,10 : side views of a model with its first animation seeked to each time -> /tmp/rh/af_<i>.png
func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var path := ""
	var times: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--m="): path = a.substr(4)
		if a.begins_with("--t="): times = a.substr(4).split(",")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(inst)
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var nm: String = ap.get_animation_list()[0]
	ap.play(nm)
	ap.pause()
	await process_frame
	var i := 0
	for t in times:
		ap.seek(float(t), true)
		await process_frame
		await process_frame
		var bb := AABB()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		var c := bb.get_center()
		var r := bb.size.length() * 1.0
		cam.look_at_from_position(c + Vector3(r, 0.15 * r, 0), c, Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rh/af_%d.png" % i)
		print("AF ", i, " t=", t, " size ", bb.size.snapped(Vector3(0.01, 0.01, 0.01)), " centre ", c.snapped(Vector3(0.01, 0.01, 0.01)))
		i += 1
	quit()
