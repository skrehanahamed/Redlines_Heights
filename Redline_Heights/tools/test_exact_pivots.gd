@tool
extends SceneTree

func test_perfect_pivots() -> void:
	print("--- Testing AS350 exact pivots ---")
	var scene := (load("res://assets/town/as350_b2.glb") as PackedScene).instantiate() as Node3D
	
	var lp: Node3D = null
	var rp: Node3D = null
	var ra: Node3D = null
	for n in scene.find_children("*", "Node3D", true, false):
		if n.name == "AS350_B2_complet_LP": lp = n
		elif n.name == "rotor_pales": rp = n
		elif n.name == "rotor_anticouple": ra = n
	
	var main_hub := Vector3(0.0912, 3.1408, -1.5791)
	var main_piv := Node3D.new()
	main_piv.name = "main_piv"
	lp.add_child(main_piv)
	main_piv.position = main_hub
	rp.owner = null
	rp.reparent(main_piv, false)
	rp.position = -main_hub
	
	var tail_hub := Vector3(0.4265, 2.0284, 4.5367)
	var tail_piv := Node3D.new()
	tail_piv.name = "tail_piv"
	lp.add_child(tail_piv)
	tail_piv.position = tail_hub
	ra.owner = null
	ra.reparent(tail_piv, false)
	ra.position = -tail_hub
	
	print("Testing 100 rotation steps...")
	for i in range(100):
		main_piv.rotate_y(0.1)
		tail_piv.rotate_x(0.15)
	
	print("Rotated 100 steps without error!")
	scene.free()

func _init() -> void:
	test_perfect_pivots()
	quit()
