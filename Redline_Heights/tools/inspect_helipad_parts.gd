@tool
extends SceneTree

func _init():
	var p = "res://assets/town/heliport_helipad_air_base_helicopter.glb"
	var parts = load("res://scripts/coast_props.gd")._parts(p)
	print("Helipad parts count: ", parts.size())
	for pt in parts:
		print("Part name: ", pt.name, " aabb: ", pt.aabb, " xf: ", pt.xf)
	
	# Also inspect specs["helipad"] mesh surfaces and vertices
	var cb_script = load("res://scripts/city_build.gd")
	cb_script._specs()
	var hs = cb_script.specs["helipad"]
	var m: Mesh = hs.mesh
	print("Baked helipad aabb: ", m.get_aabb())
	quit()
