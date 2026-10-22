extends SceneTree

func _init():
	var Renowood = load("res://scripts/renowood.gd")
	var g0 = Renowood._group(Renowood.VILLA)
	var g1 = Renowood._group(Renowood.VILLA_POOL)
	print("--- VILLA PARTS Y RANGE ---")
	_check_parts(g0)
	print("--- VILLA_POOL PARTS Y RANGE ---")
	_check_parts(g1)
	quit()

func _check_parts(g):
	var min_y = 1e9
	var max_y = -1e9
	var low_parts = []
	for p in g.parts:
		var m = p.mesh
		var aabb = p.xf * m.get_aabb()
		if aabb.position.y < min_y: min_y = aabb.position.y
		if aabb.end.y > max_y: max_y = aabb.end.y
		if aabb.position.y < 0.5:
			low_parts.append({"name": m.resource_name, "y": aabb.position.y, "size_y": aabb.size.y, "sz": aabb.size})
	print("Min Y: ", min_y, " Max Y: ", max_y, " low parts count: ", low_parts.size())
	for i in range(mini(5, low_parts.size())):
		print("  low part: ", low_parts[i])
