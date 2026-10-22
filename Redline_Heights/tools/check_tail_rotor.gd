@tool
extends SceneTree

func check_tail() -> void:
	var scene := (load("res://assets/town/as350_b2.glb") as PackedScene).instantiate() as Node3D
	var ra: MeshInstance3D = null
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		if n.name.begins_with("rotor_anticouple"): ra = n
	
	var faces := ra.mesh.get_faces()
	# Check distances from mid point (0.3298, 2.0284, 4.5363)
	var mid := Vector3(0.3298, 2.0284, 4.5363)
	var max_d := 0.0
	for v in faces:
		# distance in YZ plane
		var d = Vector2(v.y - mid.y, v.z - mid.z).length()
		max_d = maxf(max_d, d)
	print("Tail rotor radius in YZ plane: ", max_d)
	
	# Find vertices near root to find hub center
	var root_pts := []
	for v in faces:
		var d = (v - mid).length()
		if d < 0.2: root_pts.append(v)
	print("Found ", root_pts.size(), " vertices near tail hub.")
	if not root_pts.is_empty():
		var avg := Vector3.ZERO
		for p in root_pts: avg += p
		avg /= float(root_pts.size())
		print("Average position of tail blade roots: ", avg)
	scene.free()

func _init() -> void:
	check_tail()
	quit()
