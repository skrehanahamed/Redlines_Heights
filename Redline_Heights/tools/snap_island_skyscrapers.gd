extends Node

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/rh_island")
	
	Game.reset_state()
	var world := World.new()
	world.name = "World"
	add_child(world)
	Game.world = world
	await world.build()
	print("World built successfully!")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var cam := Camera3D.new()
	cam.far = 30000.0
	add_child(cam)
	
	# collision check: horizontal rays from the south across the Burj, where do they first hit?
	var space := get_viewport().world_3d.direct_space_state
	for hy in [2.0, 8.0, 20.0, 60.0]:
		var line := "COLL y=%s:" % hy
		for rx in [120.0, 128.0, 136.0, 145.0, 154.0, 162.0, 170.0]:
			var q := PhysicsRayQueryParameters3D.create(Vector3(rx, hy, 2189.0), Vector3(rx, hy, 2120.0))
			var hit := space.intersect_ray(q)
			line += "  x%d->%s" % [int(rx), ("%.1f" % hit.position.z) if not hit.is_empty() else "none"]
		print(line)

	for hy2 in [6.0, 12.0, 20.0]:
		for rr in [["N", Vector3(145.0, hy2, 2128.0), Vector3(145.0, hy2, 2156.0)], ["N2", Vector3(138.0, hy2, 2128.0), Vector3(138.0, hy2, 2156.0)], ["W", Vector3(121.5, hy2, 2156.0), Vector3(145.0, hy2, 2156.0)], ["W2", Vector3(121.5, hy2, 2148.0), Vector3(145.0, hy2, 2148.0)], ["E", Vector3(168.0, hy2, 2156.0), Vector3(145.0, hy2, 2156.0)], ["E2", Vector3(168.0, hy2, 2150.0), Vector3(145.0, hy2, 2150.0)], ["S", Vector3(145.0, hy2, 2190.0), Vector3(145.0, hy2, 2156.0)]]:
			var qq := PhysicsRayQueryParameters3D.create(rr[1], rr[2])
			var hh := space.intersect_ray(qq)
			print("COLL2 y=%s %s -> %s" % [hy2, rr[0], str(hh.position) if not hh.is_empty() else "none"])

	# --- 1. Top View of Entire District ---
	cam.fov = 50
	cam.look_at_from_position(Vector3(100.0, 850.0, 2180.0), Vector3(100.0, 0.0, 2100.0), Vector3(0, 0, -1))
	await _snap("/tmp/rh_island/island_3lots_top.png")
	print("Snapped 3lots top view")
	
	# --- 2. Daytime 3D Aerial View ---
	cam.fov = 50
	cam.look_at_from_position(Vector3(260.0, 150.0, 2300.0), Vector3(90.0, 45.0, 2080.0), Vector3.UP)
	await _snap("/tmp/rh_island/island_3lots_aerial.png")
	print("Snapped 3lots aerial view")

	# --- 3. Burj Khalifa Daytime Front View ---
	cam.fov = 55
	cam.look_at_from_position(Vector3(145.0, 22.0, 2225.0), Vector3(145.0, 65.0, 2156.0), Vector3.UP)
	await _snap("/tmp/rh_island/burj_day_front.png")
	print("Snapped burj day front")

	# --- 3B. Burj Khalifa Waterfront Lake & Plaza View ---
	cam.fov = 50
	cam.look_at_from_position(Vector3(205.0, 18.0, 2195.0), Vector3(155.0, 28.0, 2156.0), Vector3.UP)
	await _snap("/tmp/rh_island/burj_lake_day.png")
	print("Snapped burj lake day")

	cam.fov = 60
	cam.look_at_from_position(Vector3(145.0, 6.0, 2205.0), Vector3(145.0, 18.0, 2156.0), Vector3.UP)
	await _snap("/tmp/rh_island/burj_base_day.png")
	cam.fov = 60
	cam.look_at_from_position(Vector3(150.0, 7.0, 2225.0), Vector3(150.0, 3.0, 2185.0), Vector3.UP)
	await _snap("/tmp/rh_island/fence_gate_south.png")
	cam.fov = 60
	cam.look_at_from_position(Vector3(205.0, 9.0, 2110.0), Vector3(178.0, 3.0, 2155.0), Vector3.UP)
	await _snap("/tmp/rh_island/fountain_close.png")

	# --- 4. Transition to Night Mode ---
	if world.sun != null:
		world.sun.light_energy = 0.12
		world.sun.light_color = Color(0.35, 0.45, 0.75)
		world.sun.rotation_degrees = Vector3(-35, 140, 0)
	if world.env != null:
		world.env.background_mode = Environment.BG_COLOR
		world.env.background_color = Color(0.012, 0.016, 0.04)
		world.env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.env.ambient_light_color = Color(0.12, 0.14, 0.22)
		world.env.glow_enabled = true
	
	FlagProjector.override_night = 1.0
	for sm in CityLights._shaders: (sm as ShaderMaterial).set_shader_parameter("night", 1.0)
	for e in CityLights._mats: (e.m as BaseMaterial3D).emission_energy_multiplier = float(e.gain) * float(e.base)
	for l in CityLights._lights:
		(l.l as Light3D).visible = true
		(l.l as Light3D).light_energy = float(l.e)
	
	# Aerial Night showing illuminated district & glowing towers
	cam.fov = 50
	cam.look_at_from_position(Vector3(260.0, 150.0, 2300.0), Vector3(90.0, 45.0, 2080.0), Vector3.UP)
	await _snap("/tmp/rh_island/island_3lots_night_aerial.png")
	print("Snapped night aerial view")

	cam.fov = 60
	cam.look_at_from_position(Vector3(145.0, 6.0, 2205.0), Vector3(145.0, 18.0, 2156.0), Vector3.UP)
	await _snap("/tmp/rh_island/burj_base_night.png")

	cam.fov = 60
	cam.look_at_from_position(Vector3(145.0, 4.0, 2230.0), Vector3(145.0, 45.0, 2170.0), Vector3.UP)
	await _snap("/tmp/rh_island/burj_projector_night.png")
	cam.fov = 60
	cam.look_at_from_position(Vector3(175.0, 3.0, 2215.0), Vector3(145.0, 12.0, 2182.0), Vector3.UP)
	await _snap("/tmp/rh_island/projector_unit_night.png")
	for pv in [[Vector3(110.0, 4.0, 2120.0), Vector3(148.0, 22.0, 2140.0), "n"], [Vector3(105.0, 4.0, 2185.0), Vector3(126.0, 18.0, 2166.0), "w"], [Vector3(190.0, 4.0, 2185.0), Vector3(167.0, 18.0, 2155.0), "e"]]:
		cam.fov = 60
		cam.look_at_from_position(pv[0], pv[1], Vector3.UP)
		await _snap("/tmp/rh_island/proj_side_%s.png" % pv[2])

	for sd in [[Vector3(145.0, 6.0, 2105.0), "north"], [Vector3(235.0, 6.0, 2156.0), "east"], [Vector3(55.0, 6.0, 2156.0), "west"]]:
		cam.fov = 60
		cam.look_at_from_position(sd[0], Vector3(145.0, 55.0, 2156.0), Vector3.UP)
		await _snap("/tmp/rh_island/burj_flag_%s.png" % sd[1])

	# Burj Khalifa Night Front View
	cam.fov = 55
	cam.look_at_from_position(Vector3(145.0, 22.0, 2225.0), Vector3(145.0, 65.0, 2156.0), Vector3.UP)
	await _snap("/tmp/rh_island/burj_night_front.png")
	print("Snapped burj night front")

	# Burj Khalifa Night Lake View
	cam.fov = 50
	cam.look_at_from_position(Vector3(205.0, 18.0, 2195.0), Vector3(155.0, 28.0, 2156.0), Vector3.UP)
	await _snap("/tmp/rh_island/burj_lake_night.png")
	print("Snapped burj lake night")

	get_tree().quit()

func _snap(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
