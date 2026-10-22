extends Node

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/rh_doors")
	
	var T := "res://assets/town/"
	var tw := "res://assets/miami/towers/"
	
	var list := [
		["skyscraper_peak", Renowood._baked(T + "skyscraper.glb", 1.0, [], true, "", 0.22)],
		["bank_of_china", Renowood._baked(T + "bank_of_china_tower.glb", 1.0, [], true, "", 0.45)],
		["vizcayne", Miami._bake(tw + "hivizcayne.FBX", "", 0.0, 1.0)],
		["ait_w2w7", Miami._bake(tw + "AIT01W2W7.FBX", "", 0.0, 1.0)],
		["ait_w2w5", Miami._bake(tw + "AIT01W2W5.FBX", "", 0.0, 1.0)]
	]
	
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.7, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env_node.environment = env
	add_child(env_node)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	add_child(sun)
	
	var mi := MeshInstance3D.new()
	add_child(mi)
	
	var cam := Camera3D.new()
	cam.far = 2000.0
	add_child(cam)
	
	for it in list:
		var id: String = it[0]
		var b: Dictionary = it[1]
		mi.mesh = b.mesh
		var sz: Vector3 = b.size
		print("Model ", id, " size=", sz)
		
		# Low angle ground-level camera to see the ground entrance doors clearly
		var h := minf(sz.y * 0.15, 8.0)
		var d := maxf(sz.x, sz.z) * 0.85
		
		# Look at local +Z side (from +Z looking back at origin)
		cam.look_at_from_position(Vector3(0, h, d), Vector3(0, h * 0.5, 0), Vector3.UP)
		await _snap("/tmp/rh_doors/%s_posZ.png" % id)
		
		# Look at local -Z side (from -Z looking towards origin)
		cam.look_at_from_position(Vector3(0, h, -d), Vector3(0, h * 0.5, 0), Vector3.UP)
		await _snap("/tmp/rh_doors/%s_negZ.png" % id)
		
		# Look at local +X side (from +X looking towards origin)
		cam.look_at_from_position(Vector3(d, h, 0), Vector3(0, h * 0.5, 0), Vector3.UP)
		await _snap("/tmp/rh_doors/%s_posX.png" % id)
		
		# Look at local -X side (from -X looking towards origin)
		cam.look_at_from_position(Vector3(-d, h, 0), Vector3(0, h * 0.5, 0), Vector3.UP)
		await _snap("/tmp/rh_doors/%s_negX.png" % id)
		
	get_tree().quit()

func _snap(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
