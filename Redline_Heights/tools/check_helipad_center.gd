@tool
extends SceneTree

func check_helipad_world_center() -> void:
	var cb_script = load("res://scripts/city_build.gd")
	cb_script._specs()
	var specs = cb_script.specs
	var hs = specs["helipad"]
	var hm: Mesh = hs.mesh
	var hb: AABB = hm.get_aabb()
	var hr: float = 7.37 * 0.0115 * 100.0
	var pad_off = Vector3(hb.position.x + hr, 0.0, hb.position.z + hr)
	print("pad_off = ", pad_off)
	print("hb = ", hb)
	print("hb center = ", hb.get_center())

	for key in ["police", "hospital"]:
		var sp = specs[key]
		var w = float(sp.w)
		var d = float(sp.d)
		var xc = -44.0 if key == "police" else -36.0
		var cd = 18.0 if key == "police" else 15.0
		var door_dx = -5.6 if key == "police" else 0.0
		var back_t = cd + d + 0.8
		var heli_x = xc + door_dx + w * 0.5 + 16.5
		var hyaw = (-PI * 0.5) if heli_x > xc else (PI * 0.5)
		var hbasis = Basis(Vector3.UP, hyaw)
		var z_center = 0.0 # let's just use 0
		var hpos = Vector3(heli_x, 10.0, z_center) - hbasis * pad_off
		
		# Now helipad mesh transform is Transform3D(hbasis, hpos)
		# The center of the mesh is hpos + hbasis * hb.get_center()
		var mesh_center = hpos + hbasis * hb.get_center()
		print("\n", key.to_upper(), ":")
		print("heli_x = ", heli_x)
		print("Current pad_centre X = ", heli_x)
		print("Actual helipad mesh center X = ", mesh_center.x)
		print("Difference (mesh_center.x - heli_x) = ", mesh_center.x - heli_x)
		print("Actual helipad mesh center Z = ", mesh_center.z)

	quit()

func _init() -> void:
	check_helipad_world_center()
