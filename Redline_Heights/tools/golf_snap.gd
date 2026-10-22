extends Node
## Dev tool: builds the island and takes pictures of the golf club (block 3) into /tmp/rh_island/golf_*.png
var night := false

func _ready() -> void:
	_run()

func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/rh_island/golf_%s.png" % name)

func _run() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/rh_island")
	Game.reset_state()
	var world := World.new()
	world.name = "World"
	add_child(world)
	Game.world = world
	await world.build()
	await get_tree().process_frame
	var cam := Camera3D.new()
	cam.far = 30000.0
	add_child(cam)
	var views := [
		["top", Vector3(100, 520, 2325), Vector3(100, 0, 2325), Vector3(0, 0, 1), 40.0],
		["entrance", Vector3(100, 5, 2185), Vector3(100, 3, 2240), Vector3.UP, 65.0],
		["gate", Vector3(70, 4, 2195), Vector3(98, 3.5, 2215), Vector3.UP, 60.0],
		["gate2", Vector3(100, 3, 2192), Vector3(100, 3.5, 2225), Vector3.UP, 70.0],
		["in1", Vector3(96.4, 1.9, 2326.5), Vector3(98, 1.9, 2345), Vector3.UP, 85.0],
		["in2", Vector3(100, 2.2, 2330), Vector3(88, 1.2, 2340), Vector3.UP, 85.0],
		["in3", Vector3(95, 2.2, 2330), Vector3(110, 1.2, 2339), Vector3.UP, 85.0],
		["in4", Vector3(106, 2.4, 2344), Vector3(88, 1.4, 2332), Vector3.UP, 85.0],
		["house", Vector3(100, 8, 2280), Vector3(100, 8, 2332), Vector3.UP, 60.0],
		["cart", Vector3(60, 3, 2312), Vector3(56, 0.8, 2327), Vector3.UP, 60.0],
		["flag", Vector3(30, 3.5, 2370), Vector3(26, 1.5, 2392), Vector3.UP, 55.0],
		["barrier", Vector3(100, 3, 2193), Vector3(100, 1.0, 2226), Vector3.UP, 70.0],
		["sign", Vector3(75, 2.5, 2185), Vector3(80, 1.9, 2206.7), Vector3.UP, 60.0],
		["course", Vector3(30, 14, 2420), Vector3(110, 0, 2360), Vector3.UP, 60.0],
		["course2", Vector3(160, 10, 2255), Vector3(165, 0, 2340), Vector3.UP, 62.0],
		["aerial", Vector3(40, 90, 2180), Vector3(110, 0, 2330), Vector3.UP, 60.0],
	]
	# cutaway plan of the clubhouse: roof and exterior hidden
	var hn := world.static_root.get_node_or_null("GolfHouse") as MeshInstance3D
	if hn != null:
		var blank := StandardMaterial3D.new()
		blank.albedo_color = Color(0, 0, 0, 0)
		blank.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for si in [4, 0, 3, 5, 6]:
			hn.set_surface_override_material(si, blank)
		cam.fov = 40
		cam.look_at_from_position(Vector3(100, 70, 2334.01), Vector3(100, 0, 2334), Vector3(0, 0, -1))
		await _snap("plan")
		for si in range(hn.mesh.get_surface_count()):
			hn.set_surface_override_material(si, null)
	for v in views:
		cam.fov = v[4]
		cam.look_at_from_position(v[1], v[2], v[3])
		await _snap(v[0])
	# can the player walk in? horizontal rays at chest height through the entrance porch into the hall
	var space := get_viewport().world_3d.direct_space_state
	for xx in [94.5, 96.4, 98.0]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(xx, 1.1, 2316.0), Vector3(xx, 1.1, 2344.0))
		var hit := space.intersect_ray(q)
		print("WALK x=%s first hit z=%s" % [xx, ("%.2f" % hit.position.z) if not hit.is_empty() else "none (clear to the north wall)"])
	# night
	FlagProjector.override_night = 1.0
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
	for sm in CityLights._shaders: (sm as ShaderMaterial).set_shader_parameter("night", 1.0)
	for e in CityLights._mats: (e.m as BaseMaterial3D).emission_energy_multiplier = float(e.gain) * float(e.base)
	for l in CityLights._lights:
		(l.l as Light3D).visible = true
		(l.l as Light3D).light_energy = float(l.e)
	for nv in [["n_aerial", Vector3(40, 90, 2180), Vector3(110, 0, 2330), 60.0], ["n_in", Vector3(100, 2.2, 2330), Vector3(88, 1.2, 2340), 85.0], ["n_light", Vector3(60, 12, 2290), Vector3(15, 14, 2330), 65.0], ["n_gate", Vector3(100, 3, 2192), Vector3(100, 3.5, 2225), 70.0]]:
		cam.fov = nv[3]
		cam.look_at_from_position(nv[1], nv[2], Vector3.UP)
		await _snap(nv[0])
	get_tree().quit()
