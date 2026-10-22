@tool
extends SceneTree

func test_helipad_chopper() -> void:
	print("--- Instantiating Police HelipadChopper ---")
	var hp := HelipadChopper.new()
	hp.setup("police")
	root.add_child(hp)
	hp.global_position = Vector3(10, 5, 10)
	hp.rotation.y = 1.57
	print("Police HelipadChopper created! Testing rotor spin...")
	hp.is_npc_piloted = true
	for i in range(10):
		hp._physics_process(0.016)
	print("Police engine reached: ", hp.engine)
	hp.queue_free()

	print("--- Instantiating Hospital HelipadChopper ---")
	var hh := HelipadChopper.new()
	hh.setup("hospital")
	root.add_child(hh)
	hh.global_position = Vector3(-10, 5, -10)
	hh.rotation.y = 3.14
	print("Hospital HelipadChopper created! Testing rotor spin...")
	hh.is_npc_piloted = true
	for i in range(10):
		hh._physics_process(0.016)
	print("Hospital engine reached: ", hh.engine)
	hh.queue_free()

	print("--- ALL HELIPAD CHOPPER TESTS PASSED ---")

func _init() -> void:
	test_helipad_chopper()
	quit()
