extends SceneTree
## Dev tool: renders the coast assets. godot --path . -s res://scripts/coast_view.gd -- beach|ocean
func _initialize() -> void:
	var which: String = OS.get_cmdline_user_args()[0]
	await process_frame
	var sc := (load("res://assets/coast/%s.glb" % ("sand_at_sunset_beach" if which == "beach" else "free_ocean_wave_animation")) as PackedScene).instantiate() as Node3D
	root.add_child(sc)
	for ap in sc.find_children("*", "AnimationPlayer", true, false):
		var a := ap as AnimationPlayer
		a.play(a.get_animation_list()[0])
		a.seek(10.0, true)
	var cam := Camera3D.new()
	root.add_child(cam)
	if which == "beach":
		cam.position = Vector3(18, 8, 18)
		cam.look_at(Vector3(0, -8.3, -2))
	else:
		cam.position = Vector3(18, 9, 18)
		cam.look_at(Vector3(0, 0, 0))
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
	for i in range(8): await process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/rh")
	root.get_viewport().get_texture().get_image().save_png("/tmp/rh/coast_%s.png" % which)
	quit()
