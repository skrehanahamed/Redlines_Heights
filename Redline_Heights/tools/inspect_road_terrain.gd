extends SceneTree

func _init():
	var res = load("res://assets/hills/american_road_hilly_terrain.glb")
	if res:
		var inst = res.instantiate()
		print("american_road_hilly_terrain root: ", inst.name)
		for c in inst.get_children():
			print("  child: ", c.name, " class=", c.get_class())
			for c2 in c.get_children():
				print("    grandchild: ", c2.name, " class=", c2.get_class())
	quit()
