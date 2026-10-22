@tool
extends SceneTree

func test_as350_pivot() -> void:
	print("--- Testing AS350 Pivot ---")
	var scene := (load("res://assets/town/as350_b2.glb") as PackedScene).instantiate() as Node3D
	var parent_node: Node3D = null
	var rp: MeshInstance3D = null
	for n in scene.find_children("*", "Node3D", true, false):
		if n.name == "rotor_pales":
			parent_node = n.get_parent() as Node3D
			rp = n.find_child("*", true, false) as MeshInstance3D
			break
	if parent_node and rp:
		var c := rp.mesh.get_aabb().get_center()
		print("rp center in local mesh coords: ", c)
		var pivot := Node3D.new()
		pivot.name = "rotor_main_pivot"
		parent_node.add_child(pivot)
		pivot.position = c
		# reparent rp's parent node (rotor_pales) to pivot
		var r_node := rp.get_parent() as Node3D
		r_node.reparent(pivot, false)
		r_node.position = -c
		print("Reparented successfully! Rotating pivot...")
		pivot.rotate_y(0.5)
		print("Pivot rotation OK!")
	scene.free()

func _init() -> void:
	test_as350_pivot()
	quit()
