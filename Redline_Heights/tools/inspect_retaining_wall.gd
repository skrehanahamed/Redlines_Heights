extends SceneTree

func _init():
	var res = load("res://assets/hills/fence_retaining_wall.glb")
	if res:
		var inst = res.instantiate()
		print("fence_retaining_wall root: ", inst.name)
		for c in inst.get_children():
			print("  c: ", c.name, " class=", c.get_class())
			for c2 in c.get_children():
				print("    c2: ", c2.name, " class=", c2.get_class())
	quit()
