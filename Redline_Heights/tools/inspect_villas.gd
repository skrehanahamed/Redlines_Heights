extends SceneTree

func _init():
	print("--- INSPECTING HILL VILLA ASSETS ---")
	for path in [
		"res://assets/hills/modern_luxury_villa_house_building.glb",
		"res://assets/hills/modern_luxury_villa_house_building_with_pool.glb",
		"res://assets/hills/american_road_hilly_terrain.glb",
		"res://assets/hills/modern_house.glb"
	]:
		var res = load(path)
		if res:
			var inst = res.instantiate()
			print("\nAsset: ", path)
			_inspect_node(inst, 0)
		else:
			print("Failed to load: ", path)
	quit()

func _inspect_node(node: Node, depth: int):
	var indent = "  ".repeat(depth)
	if node is VisualInstance3D:
		var aabb = node.get_aabb()
		print(indent, node.name, " (", node.get_class(), ") aabb=", aabb, " pos=", node.position)
	elif depth < 3:
		print(indent, node.name, " (", node.get_class(), ") pos=", node.position)
	for child in node.get_children():
		_inspect_node(child, depth + 1)
