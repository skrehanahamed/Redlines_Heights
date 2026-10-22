@tool
extends SceneTree

func inspect_parts(path: String) -> void:
	print("\n================== ", path, " ==================")
	var scene := load(path) as PackedScene
	var inst := scene.instantiate() as Node3D
	for n in inst.find_children("*", "Node3D", true, false):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var aabb := mi.mesh.get_aabb() if mi.mesh else AABB()
			print(mi.name, " (parent: ", mi.get_parent().name, ")")
			print("   pos=", mi.position, " rot=", mi.rotation_degrees, " scale=", mi.scale)
			print("   mesh AABB pos=", aabb.position, " size=", aabb.size)
			print("   mesh AABB center=", aabb.get_center())
		else:
			print(n.name, " [", n.get_class(), "] pos=", n.position, " rot=", n.rotation_degrees, " scale=", n.scale)
	inst.free()

func _init() -> void:
	inspect_parts("res://assets/town/helicopter_police.glb")
	inspect_parts("res://assets/town/as350_b2.glb")
	quit()
