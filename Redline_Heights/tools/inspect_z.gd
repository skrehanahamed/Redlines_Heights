@tool
extends SceneTree

func inspect_helicopter_police() -> void:
	print("--- Inspecting helicopter_police.glb ---")
	var scene := (load("res://assets/town/helicopter_police.glb") as PackedScene).instantiate() as Node3D
	# Find Cube_Material_0 (body)
	var body: MeshInstance3D = null
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		if n.name.begins_with("Cube"): body = n
	if body:
		var m := body.mesh
		var d := m.get_faces()
		# Find min/max Z and Y in world/scene coords
		var min_z := 999.0
		var max_z := -999.0
		for v in d:
			# transform to scene space
			var pt = scene.transform.affine_inverse() * body.global_transform * v
			min_z = minf(min_z, pt.z)
			max_z = maxf(max_z, pt.z)
		print("Body Z extent in scene space: [", min_z, ", ", max_z, "]")
	scene.free()

func _init() -> void:
	inspect_helicopter_police()
	quit()
