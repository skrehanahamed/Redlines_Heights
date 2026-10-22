@tool
extends SceneTree

func test_spins() -> void:
	print("--- Testing police rotor rotation ---")
	var pol := (load("res://assets/town/helicopter_police.glb") as PackedScene).instantiate() as Node3D
	var cyl: Node3D = null
	var cyl1: Node3D = null
	for n in pol.find_children("*", "Node3D", true, false):
		if n.name == "Cylinder": cyl = n
		elif n.name == "Cylinder_001": cyl1 = n
	
	if cyl:
		print("Cylinder initial basis: ", cyl.basis)
		# local Z axis in parent coordinates:
		print("Cylinder local Z in parent space: ", cyl.transform.basis.z)
		# rotate_z(0.1)
		cyl.rotate_object_local(Vector3.FORWARD, 0.1)
		print("Cylinder rotated local Z successfully")
	
	if cyl1:
		print("Cylinder_001 initial basis: ", cyl1.basis)
		print("Cylinder_001 local axes in parent space:")
		print("   X: ", cyl1.transform.basis.x)
		print("   Y: ", cyl1.transform.basis.y)
		print("   Z: ", cyl1.transform.basis.z)
		# We want the spin axis to be perpendicular to the blade disc.
		# The blade disc for tail rotor is in the YZ plane (vertical along fuselage).
		# So the normal axis is X (pointing sideways)!
		# Which local axis of cyl1 points sideways (along parent X)?
		# Let's see which basis vector has largest X component.
	pol.free()

	print("\n--- Testing as350 rotor rotation ---")
	var as350 := (load("res://assets/town/as350_b2.glb") as PackedScene).instantiate() as Node3D
	var rp: Node3D = null
	var ra: Node3D = null
	for n in as350.find_children("*", "Node3D", true, false):
		if n.name == "rotor_pales": rp = n
		elif n.name == "rotor_anticouple": ra = n
	print("Found rp: ", rp != null, " ra: ", ra != null)
	as350.free()

func _init() -> void:
	test_spins()
	quit()
