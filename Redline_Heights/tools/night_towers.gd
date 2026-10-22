extends Node
## Shows every skyscraper that has real window lighting at night, side by side, close-ups into /tmp/rh/nt_*.png
func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/rh")
	CityBuild._specs()
	var tw := "res://assets/miami/towers/"
	var list: Array = []     # [label, mesh, size]
	for k in [["ait", "AIT01W2W2"], ["hirise", "hirise2"], ["atl", "Atlanta office"], ["wtc", "3 World Trade"]]:
		list.append([k[1], CityBuild.specs[k[0]].mesh, CityBuild.specs[k[0]].size])
	for t in [["hivizcayne", "hivizcayne"], ["AIT01W2W7", "AIT01W2W7"], ["AIT01W2W5", "AIT01W2W5"]]:
		var pr: Dictionary = Miami._bake(tw + t[0] + ".FBX", "", 0.0, 1.0)
		CityLights.apply_shader(pr.mesh, {"mode": 3, "emit": tw + t[0] + "_win.png", "lit_frac": 0.5, "gain": 1.1})
		list.append([t[1], pr.mesh, pr.size])
	var sky_bake: Dictionary = Renowood._baked("res://assets/town/skyscraper.glb", 1.0, [], true, "", 0.22)
	CityLights.apply_shader(sky_bake.mesh, {"mode": 3, "emit": "res://assets/town/skyscraper_2_win.png", "lit_frac": 0.45, "gain": 1.25}, "wins1")
	CityLights.apply_shader(sky_bake.mesh, {"mode": 3, "emit": "res://assets/town/skyscraper_0_win.png", "lit_frac": 0.50, "gain": 1.25}, "wins2")
	CityLights.apply(sky_bake.mesh, "emissive", 2.0)
	list.append(["Skyscraper Peak", sky_bake.mesh, sky_bake.size])
	var boc_bake: Dictionary = Renowood._baked("res://assets/town/bank_of_china_tower.glb", 1.0, [], true, "", 0.45)
	CityLights.apply_shader(boc_bake.mesh, {"mode": 1, "floor_h": 4.5, "cell_w": 3.0, "lit_frac": 0.52, "gain": 1.25})
	list.append(["Bank of China", boc_bake.mesh, boc_bake.size])
	for sm in CityLights._shaders: (sm as ShaderMaterial).set_shader_parameter("night", 1.0)
	for e in CityLights._mats: (e.m as BaseMaterial3D).emission_energy_multiplier = float(e.gain) * float(e.base)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.03, 0.07)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.12, 0.14, 0.24)
	env.environment.glow_enabled = true
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 150, 0)
	moon.light_color = Color(0.5, 0.6, 1.0)
	moon.light_energy = 0.25
	add_child(moon)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(4000, 600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.05, 0.06, 0.05)
	ground.material_override = gm
	add_child(ground)
	var x := 0.0
	var spots: Array = []
	for it in list:
		var sz: Vector3 = it[2]
		var mi := MeshInstance3D.new()
		mi.mesh = it[1]
		var wdt := maxf(sz.x, sz.z)
		x += wdt * 0.5 + 25.0
		mi.position = Vector3(x, 0, 0)
		add_child(mi)
		spots.append([it[0], Vector3(x, sz.y * 0.5, 0), sz])
		print("TOWER ", it[0], " size ", sz)
		x += wdt * 0.5 + 25.0
	var cam := Camera3D.new()
	cam.far = 20000.0
	add_child(cam)
	cam.look_at_from_position(Vector3(x * 0.5, 120, 700), Vector3(x * 0.5, 100, 0), Vector3.UP)
	cam.fov = 60
	await _snap("nt_all")
	for s in spots:
		var sz: Vector3 = s[2]
		var d := maxf(sz.y, maxf(sz.x, sz.z)) * 1.25
		for v in [[0.5, 0.6, "a"], [-0.7, 0.4, "b"]]:
			var dir := Vector3(v[0], 0.0, 1.0).normalized()
			cam.look_at_from_position(s[1] + dir * d + Vector3(0, sz.y * 0.05 * float(v[1]) , 0), s[1], Vector3.UP)
			await _snap("nt_%s_%s" % [String(s[0]).replace(" ", "_"), v[2]])
	get_tree().quit()

func _snap(n: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/rh/%s.png" % n)
