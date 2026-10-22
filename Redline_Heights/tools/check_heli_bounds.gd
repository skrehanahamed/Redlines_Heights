@tool
extends SceneTree

func check_heli_bottom(path: String, sc: float) -> void:
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	scene.scale = Vector3.ONE * sc
	var min_y := 999999.0
	var max_y := -999999.0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		var aabb := m.mesh.get_aabb()
		for corner in [
			aabb.position,
			aabb.position + Vector3(aabb.size.x, 0, 0),
			aabb.position + Vector3(0, aabb.size.y, 0),
			aabb.position + Vector3(0, 0, aabb.size.z),
			aabb.position + aabb.size,
		]:
			var pt = scene.global_transform.affine_inverse() * m.global_transform * corner
			min_y = minf(min_y, pt.y)
			max_y = maxf(max_y, pt.y)
	print(path, " scaled by ", sc, ":")
	print("   min_y = ", min_y)
	print("   max_y = ", max_y)
	print("   total height = ", max_y - min_y)
	scene.queue_free()

func _init() -> void:
	check_heli_bottom("res://assets/town/helicopter_police.glb", 0.045)
	check_heli_bottom("res://assets/town/as350_b2.glb", 1.5)
	quit()
