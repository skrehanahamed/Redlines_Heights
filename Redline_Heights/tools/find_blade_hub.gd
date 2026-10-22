@tool
extends SceneTree

func find_exact_blade_hub() -> void:
	var scene := (load("res://assets/town/as350_b2.glb") as PackedScene).instantiate() as Node3D
	var rp: MeshInstance3D = null
	var hub: MeshInstance3D = null
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		if n.name.begins_with("rotor_pales"): rp = n
		elif n.name.begins_with("moyeu_arbre"): hub = n
	
	print("--- Hub mesh bounds ---")
	var haabb := hub.mesh.get_aabb()
	print("Hub AABB: pos=", haabb.position, " size=", haabb.size, " center=", haabb.get_center())
	
	# Let's inspect the vertices of rotor_pales that are closest to haabb.get_center()
	var d := rp.mesh.get_faces()
	# The hub center is around haabb.get_center()
	# Find vertices near X=0.08, Z=-1.58
	var hub_c := haabb.get_center()
	print("Hub center: ", hub_c)
	
	# Also let's check rotor_anticouple (tail rotor hub)
	var ra: MeshInstance3D = null
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		if n.name.begins_with("rotor_anticouple"): ra = n
	var raabb := ra.mesh.get_aabb()
	print("Tail rotor AABB: pos=", raabb.position, " size=", raabb.size, " center=", raabb.get_center())
	
	# Find the shaft / hub of the tail rotor from the faces
	# A 2-blade tail rotor has its center right at its midpoint or hub
	# Let's check min/max X, Y, Z of tail rotor faces
	var rad := ra.mesh.get_faces()
	var r_min := Vector3(999, 999, 999)
	var r_max := Vector3(-999, -999, -999)
	for v in rad:
		r_min.x = minf(r_min.x, v.x); r_max.x = maxf(r_max.x, v.x)
		r_min.y = minf(r_min.y, v.y); r_max.y = maxf(r_max.y, v.y)
		r_min.z = minf(r_min.z, v.z); r_max.z = maxf(r_max.z, v.z)
	print("Tail rotor faces: min=", r_min, " max=", r_max, " mid=", (r_min + r_max) * 0.5)

	scene.free()

func _init() -> void:
	find_exact_blade_hub()
	quit()
