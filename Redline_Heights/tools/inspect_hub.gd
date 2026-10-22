@tool
extends SceneTree

func inspect_hub() -> void:
	var scene := (load("res://assets/town/as350_b2.glb") as PackedScene).instantiate() as Node3D
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		print(mi.name, " aabb=", mi.mesh.get_aabb(), " center=", mi.mesh.get_aabb().get_center())
	scene.free()

func _init() -> void:
	inspect_hub()
	quit()
