extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "Root"
	
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.18, 0.25)
	env_node.environment = env
	root.add_child(env_node)
	
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, 40, 0)
	sun.light_color = Color(0.4, 0.5, 0.6)
	sun.light_energy = 0.5
	root.add_child(sun)
	
	var scn = load("res://assets/town/skyscraper.glb")
	var inst = scn.instantiate()
	root.add_child(inst)
	
	var aabb = _calc_aabb(inst)
	print("SKYSCRAPER AABB size: ", aabb.size, " pos: ", aabb.position)
	
	# Center it
	inst.position = -aabb.get_center()
	
	var cam = Camera3D.new()
	cam.current = true
	var max_dim = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	cam.position = Vector3(max_dim * 0.8, max_dim * 0.4, max_dim * 1.0)
	cam.look_at(Vector3(0, 0, 0))
	root.add_child(cam)
	
	get_root().add_child(root)
	
	await process_frame
	await process_frame
	await process_frame
	
	var vp = get_root()
	var img = vp.get_texture().get_image()
	img.save_png("tools/skyscraper_test.png")
	print("Saved tools/skyscraper_test.png")
	quit()

func _calc_aabb(node: Node) -> AABB:
	var total = AABB()
	var first = true
	var stack = [node]
	while stack.size() > 0:
		var cur = stack.pop_back()
		if cur is VisualInstance3D:
			var b = cur.get_aabb()
			var xform = cur.global_transform
			var corners = [
				xform * b.position,
				xform * (b.position + Vector3(b.size.x, 0, 0)),
				xform * (b.position + Vector3(0, b.size.y, 0)),
				xform * (b.position + Vector3(0, 0, b.size.z)),
				xform * (b.position + Vector3(b.size.x, b.size.y, 0)),
				xform * (b.position + Vector3(b.size.x, 0, b.size.z)),
				xform * (b.position + Vector3(0, b.size.y, b.size.z)),
				xform * (b.position + b.size)
			]
			for c in corners:
				if first:
					total = AABB(c, Vector3.ZERO)
					first = false
				else:
					total = total.expand(c)
		for ch in cur.get_children():
			stack.append(ch)
	return total
