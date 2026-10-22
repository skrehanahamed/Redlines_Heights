@tool
extends SceneTree

func test_model(path: String, main_name: String, tail_name: String, key: String) -> void:
	print("\n>>> Testing: ", path)
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	
	# Find main rotor
	var main_node: Node3D = null
	var tail_node: Node3D = null
	for n in scene.find_children("*", "Node3D", true, false):
		if n.name == main_name:
			main_node = n
		elif n.name == tail_name:
			tail_node = n
	
	print("Found main: ", main_node != null, " tail: ", tail_node != null)
	if main_node:
		var mi := main_node if main_node is MeshInstance3D else main_node.find_child("*", true, false) as MeshInstance3D
		if mi and mi.mesh:
			var aabb: AABB = mi.mesh.get_aabb()
			print("Main rotor mesh AABB center: ", aabb.get_center())
			print("Main rotor node pos: ", main_node.position, " rot: ", main_node.rotation_degrees)
	if tail_node:
		var mi := tail_node if tail_node is MeshInstance3D else tail_node.find_child("*", true, false) as MeshInstance3D
		if mi and mi.mesh:
			var aabb: AABB = mi.mesh.get_aabb()
			print("Tail rotor mesh AABB center: ", aabb.get_center())
			print("Tail rotor node pos: ", tail_node.position, " rot: ", tail_node.rotation_degrees)
	scene.free()

func _init() -> void:
	test_model("res://assets/town/helicopter_police.glb", "Cylinder", "Cylinder_001", "police")
	test_model("res://assets/town/as350_b2.glb", "rotor_pales", "rotor_anticouple", "hospital")
	quit()
