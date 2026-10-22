extends SceneTree

func _init():
	for car_name in ["greenwood", "police", "taxi", "buffalo", "infernus", "bullet", "banshee", "sultan", "elegy", "huntley", "picador", "admiral"]:
		var p = "res://assets/vehicles/cars/" + car_name + ".glb"
		if not ResourceLoader.exists(p):
			print("MISSING: ", p)
			continue
		var inst = (load(p) as PackedScene).instantiate()
		print("=== CAR: ", car_name, " ===")
		var aabb = AABB()
		var first = true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m = mi as MeshInstance3D
			if first:
				aabb = m.get_aabb()
				first = false
			else:
				aabb = aabb.merge(m.get_aabb())
			print("  mesh: ", m.name, " pos: ", m.position)
		print("  Total AABB: size=", aabb.size, " center=", aabb.get_center())
		inst.free()
	quit()
