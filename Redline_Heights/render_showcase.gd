extends SceneTree

func _init():
	var root_node = Node3D.new()
	root.add_child(root_node)

	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#181c24")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#d8e2ee")
	e.ambient_light_energy = 0.9
	env.environment = e
	root_node.add_child(env)

	# Main key light
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 45, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -135, 0)
	fill.light_color = Color("#7090b0")
	fill.light_energy = 0.6
	root_node.add_child(fill)

	# Ground
	var ground = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = Color("#222730")
	gmat.roughness = 0.85
	ground.material_override = gmat
	root_node.add_child(ground)

	# Sweet
	var sweet = (load("res://assets/characters/cast/sweet.glb") as PackedScene).instantiate()
	sweet.position = Vector3(-2.2, 0.96, 0.2)
	sweet.rotation_degrees = Vector3(0, 180, 0)
	root_node.add_child(sweet)

	# Big Smoke
	var smoke = (load("res://assets/characters/cast/smoke.glb") as PackedScene).instantiate()
	smoke.position = Vector3(-1.1, 0.96, 0.2)
	smoke.rotation_degrees = Vector3(0, 180, 0)
	root_node.add_child(smoke)

	# Ryder
	var ryder = (load("res://assets/characters/cast/ryder.glb") as PackedScene).instantiate()
	ryder.position = Vector3(0.0, 0.96, 0.2)
	ryder.rotation_degrees = Vector3(0, 180, 0)
	root_node.add_child(ryder)

	# Hero Carl
	var cj = (load("res://assets/characters/cj/Character_CJ.fbx") as PackedScene).instantiate()
	var cj_mat = StandardMaterial3D.new()
	cj_mat.albedo_texture = load("res://assets/characters/cj/Character_CJ.png") as Texture2D
	cj_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	for mi in cj.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = cj_mat
	cj.position = Vector3(1.1, 0.0, 0.2)
	cj.rotation_degrees = Vector3(0, 0, 0)
	root_node.add_child(cj)

	# The Car (Greenwood Sedan)
	var car = (load("res://assets/vehicles/cars/greenwood.glb") as PackedScene).instantiate()
	car.position = Vector3(3.8, 0.43, -0.2)
	car.rotation_degrees = Vector3(0, -35, 0)
	root_node.add_child(car)

	# Open the driver door to show interior
	var dfl = car.find_child("*porta*", true, false) as Node3D
	if dfl:
		dfl.rotation_degrees = Vector3(0, -60, 0)

	var cam = Camera3D.new()
	root_node.add_child(cam)
	cam.position = Vector3(0.8, 1.25, 3.8)
	cam.look_at_from_position(Vector3(0.8, 1.25, 3.8), Vector3(0.8, 0.85, 0), Vector3.UP)
	cam.current = true

	# Wait a couple of frames then capture
	for i in range(6):
		await process_frame

	var img = root.get_viewport().get_texture().get_image()
	if img:
		var path = "/Users/reno/.gemini/antigravity-ide/brain/d4ea8e4b-6050-4327-b45e-11f46149b658/showcase.png"
		var err = img.save_png(path)
		print("Screenshot saved! Result: ", err, " size: ", img.get_size(), " path: ", path)
	else:
		print("Could not get image from viewport")

	quit(0)
