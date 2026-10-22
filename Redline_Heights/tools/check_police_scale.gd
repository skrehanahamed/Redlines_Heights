@tool
extends SceneTree

func _init() -> void:
	var scene := (load("res://assets/town/helicopter_police.glb") as PackedScene).instantiate() as Node3D
	# Calculate total AABB manually
	var t := Transform3D.IDENTITY
	# Traverse down
	var stack := [[scene, Transform3D.IDENTITY]]
	var min_pt := Vector3(9999, 9999, 9999)
	var max_pt := Vector3(-9999, -9999, -9999)
	while not stack.is_empty():
		var item = stack.pop_back()
		var n: Node3D = item[0]
		var cur_xf: Transform3D = item[1] * n.transform
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var aabb: AABB = (n as MeshInstance3D).mesh.get_aabb()
			for corner in [
				aabb.position,
				aabb.position + Vector3(aabb.size.x, 0, 0),
				aabb.position + Vector3(0, aabb.size.y, 0),
				aabb.position + Vector3(0, 0, aabb.size.z),
				aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
				aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
				aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
				aabb.position + aabb.size
			]:
				var p = cur_xf * corner
				min_pt.x = minf(min_pt.x, p.x)
				min_pt.y = minf(min_pt.y, p.y)
				min_pt.z = minf(min_pt.z, p.z)
				max_pt.x = maxf(max_pt.x, p.x)
				max_pt.y = maxf(max_pt.y, p.y)
				max_pt.z = maxf(max_pt.z, p.z)
		for c in n.get_children():
			if c is Node3D:
				stack.append([c, cur_xf])
	print("helicopter_police.glb natural bounds (scale=1.0):")
	print("   min = ", min_pt)
	print("   max = ", max_pt)
	print("   size = ", max_pt - min_pt)
	scene.free()
	quit()
