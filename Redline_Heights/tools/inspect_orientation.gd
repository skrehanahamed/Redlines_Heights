@tool
extends SceneTree

func inspect_model_orientation(path: String) -> void:
	print("\n================ ORIENTATION: ", path, " ================")
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	# Check all meshes and their bounding boxes and materials
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		var aabb := m.mesh.get_aabb()
		print(m.name, " (parent: ", m.get_parent().name, ")")
		print("   transform: ", m.transform)
		print("   parent transform: ", (m.get_parent() as Node3D).transform)
		print("   mesh AABB: ", aabb)
	scene.free()

func _init() -> void:
	inspect_model_orientation("res://assets/town/helicopter_police.glb")
	inspect_model_orientation("res://assets/town/as350_b2.glb")
	quit()
