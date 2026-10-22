extends SceneTree
## Renders each model given as --m=path (several allowed) from 4 angles into /tmp/rh/ms_<name>_<i>.png
func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var paths: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--m="): paths.append(a.substr(4))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.far = 100000.0
	for p in paths:
		var inst := (load(p) as PackedScene).instantiate() as Node3D
		root.add_child(inst)
		await process_frame
		var bb := AABB()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		var c := bb.get_center()
		var r := bb.size.length() * 0.62
		print("MODEL ", p, " size ", bb.size)
		var views := [Vector3(1, 0.5, 1), Vector3(-1, 0.5, 1), Vector3(1, 0.1, -1), Vector3(-1, 0.1, -1)]
		for i in views.size():
			cam.look_at_from_position(c + views[i].normalized() * r, c, Vector3.UP)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/rh/ms_%s_%d.png" % [p.get_file().get_basename(), i])
		inst.queue_free()
		await process_frame
	quit()
