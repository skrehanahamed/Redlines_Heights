@tool
extends SceneTree

func check_md500() -> void:
	var scene := (load("res://assets/vehicles/heli/md500.glb") as PackedScene).instantiate() as Node3D
	# Check where nose and tail are in md500.glb
	var aabb := AABB()
	var first := true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var a = mi.mesh.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
		print(mi.name, " aabb=", a)
	print("md500 total aabb: ", aabb)
	print("md500 center: ", aabb.get_center())
	scene.free()

func _init() -> void:
	check_md500()
	quit()
