extends Node

func _ready() -> void:
	await get_tree().process_frame
	var b := Renowood._baked("res://assets/town/skyscraper.glb", 1.0, [], true, "", 0.20)
	print("Baked skyscraper size: ", b.size)
	
	# Apply city lights
	CityLights.apply(b.mesh, "names", 1.2)
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
	var pm := PlaneMesh.new(); pm.size = Vector2(2000, 2000)
	ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.05, 0.06, 0.05)
	ground.material_override = gm
	add_child(ground)
	
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh
	mi.position = Vector3(0, 0, 0)
	add_child(mi)
	
	var cam := Camera3D.new()
	cam.far = 10000.0
	add_child(cam)
	var sz: Vector3 = b.size
	cam.look_at_from_position(Vector3(sz.x * 1.5, sz.y * 0.5, sz.z * 2.5), Vector3(0, sz.y * 0.45, 0), Vector3.UP)
	
	for i in range(10): await get_tree().process_frame
	
	var vp := get_viewport()
	var tex := vp.get_texture()
	var img := tex.get_image()
	img.save_png("/tmp/rh_skyscraper_night.png")
	print("Saved /tmp/rh_skyscraper_night.png")
	get_tree().quit()
