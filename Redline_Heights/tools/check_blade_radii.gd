@tool
extends SceneTree

func check_blade_radii() -> void:
	var scene := (load("res://assets/town/as350_b2.glb") as PackedScene).instantiate() as Node3D
	var rp: MeshInstance3D = null
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		if n.name.begins_with("rotor_pales"): rp = n
	
	var center := Vector3(0.082348, 3.10551, -1.578695)
	var max_dist := 0.0
	var min_dist := 999.0
	var faces := rp.mesh.get_faces()
	# check distance in XZ plane
	for v in faces:
		var d2 = Vector2(v.x - center.x, v.z - center.z).length()
		max_dist = maxf(max_dist, d2)
		min_dist = minf(min_dist, d2)
	print("Blade root distance to hub center: ", min_dist)
	print("Blade tip distance to hub center: ", max_dist)
	
	# Also let's check the root of the blades to find the exact attachment center
	# Find vertices with small distance to hub center
	var root_pts := []
	for v in faces:
		var d = (v - center).length()
		if d < 0.6:
			root_pts.append(v)
	print("Found ", root_pts.size(), " vertices near hub.")
	if not root_pts.is_empty():
		var avg := Vector3.ZERO
		for p in root_pts: avg += p
		avg /= float(root_pts.size())
		print("Average position of blade roots: ", avg)
	scene.free()

func _init() -> void:
	check_blade_radii()
	quit()
