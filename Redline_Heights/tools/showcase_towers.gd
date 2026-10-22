extends Node

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/rh_towers")
	
	# Load models
	var T := "res://assets/town/"
	var tw := "res://assets/miami/towers/"
	
	var towers := [] # [{name, mesh, size, setup_night: Callable}]
	
	# 1. Skyscraper Peak (Burj / Spire)
	var sky_b := Renowood._baked(T + "skyscraper.glb", 1.0, [], true, "", 0.22)
	towers.append({
		"id": "skyscraper_peak",
		"name": "Skyscraper Peak (217m Spire)",
		"mesh": sky_b.mesh,
		"size": sky_b.size,
		"night_fn": func(mesh):
			CityLights.apply_shader(mesh, {"mode": 3, "emit": T + "skyscraper_2_win.png", "lit_frac": 0.45, "gain": 1.25}, "wins1")
			CityLights.apply_shader(mesh, {"mode": 3, "emit": T + "skyscraper_0_win.png", "lit_frac": 0.50, "gain": 1.25}, "wins2")
			CityLights.apply(mesh, "emissive", 2.0)
	})
	
	# 2. The Vizcayne
	var viz_b: Dictionary = Miami._bake(tw + "hivizcayne.FBX", "", 0.0, 1.0)
	towers.append({
		"id": "the_vizcayne",
		"name": "The Vizcayne (153m Miami Condo)",
		"mesh": viz_b.mesh,
		"size": viz_b.size,
		"night_fn": func(mesh):
			CityLights.apply_shader(mesh, {"mode": 3, "emit": tw + "hivizcayne_win.png", "lit_frac": 0.5, "gain": 1.1})
	})
	
	# 3. AIT01 W2W7
	var w2w7_b: Dictionary = Miami._bake(tw + "AIT01W2W7.FBX", "", 0.0, 1.0)
	towers.append({
		"id": "ait_w2w7",
		"name": "AIT01 W2W7 (50m Corner Highrise)",
		"mesh": w2w7_b.mesh,
		"size": w2w7_b.size,
		"night_fn": func(mesh):
			CityLights.apply_shader(mesh, {"mode": 3, "emit": tw + "AIT01W2W7_win.png", "lit_frac": 0.5, "gain": 1.1})
	})

	# 4. AIT01 W2W5
	var w2w5_b: Dictionary = Miami._bake(tw + "AIT01W2W5.FBX", "", 0.0, 1.0)
	towers.append({
		"id": "ait_w2w5",
		"name": "AIT01 W2W5 (29m Commercial Block)",
		"mesh": w2w5_b.mesh,
		"size": w2w5_b.size,
		"night_fn": func(mesh):
			CityLights.apply_shader(mesh, {"mode": 3, "emit": tw + "AIT01W2W5_win.png", "lit_frac": 0.55, "gain": 1.35})
	})
	
	# 5. Bank of China
	var boc_b: Dictionary = Renowood._baked(T + "bank_of_china_tower.glb", 1.0, [], true, "", 0.45)
	towers.append({
		"id": "bank_of_china",
		"name": "Bank of China Tower (165m Geometric Landmark)",
		"mesh": boc_b.mesh,
		"size": boc_b.size,
		"night_fn": func(mesh):
			CityLights.apply_shader(mesh, {"mode": 1, "floor_h": 4.5, "cell_w": 3.0, "lit_frac": 0.52, "gain": 1.25})
	})

	# Apply all night configs
	for t in towers:
		t.night_fn.call(t.mesh)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env_node.environment = env
	add_child(env_node)
	
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(2000, 2000)
	ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.12, 0.14, 0.16)
	ground.material_override = gm
	add_child(ground)
	
	var tower_mi := MeshInstance3D.new()
	add_child(tower_mi)
	
	var cam := Camera3D.new()
	cam.far = 20000.0
	cam.fov = 55
	add_child(cam)
	
	for t in towers:
		tower_mi.mesh = t.mesh
		var sz: Vector3 = t.size
		var center_y := sz.y * 0.45
		var dist := maxf(sz.y, maxf(sz.x, sz.z)) * 1.35
		var cam_pos := Vector3(dist * 0.6, sz.y * 0.55, dist * 0.85)
		cam.look_at_from_position(cam_pos, Vector3(0, center_y, 0), Vector3.UP)
		
		# --- 1. RENDER DAY VIEW ---
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.45, 0.65, 0.9)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.55, 0.65)
		env.glow_enabled = false
		
		sun.rotation_degrees = Vector3(-45, 45, 0)
		sun.light_color = Color(1.0, 0.95, 0.88)
		sun.light_energy = 1.2
		
		for sm in CityLights._shaders: (sm as ShaderMaterial).set_shader_parameter("night", 0.0)
		for e in CityLights._mats: (e.m as BaseMaterial3D).emission_energy_multiplier = 0.0
		
		await _snap("/tmp/rh_towers/%s_day.png" % t.id)
		
		# --- 2. RENDER NIGHT VIEW ---
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.03, 0.07)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.12, 0.14, 0.22)
		env.glow_enabled = true
		
		sun.rotation_degrees = Vector3(-35, 140, 0)
		sun.light_color = Color(0.4, 0.5, 0.8)
		sun.light_energy = 0.3
		
		for sm in CityLights._shaders: (sm as ShaderMaterial).set_shader_parameter("night", 1.0)
		for e in CityLights._mats: (e.m as BaseMaterial3D).emission_energy_multiplier = float(e.gain) * float(e.base)
		
		await _snap("/tmp/rh_towers/%s_night.png" % t.id)
		print("Finished rendering ", t.name)
		
	get_tree().quit()

func _snap(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
