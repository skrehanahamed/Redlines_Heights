@tool
extends SceneTree

func _init():
	var cb_script = load("res://scripts/city_build.gd")
	cb_script._specs()
	var specs = cb_script.specs
	var hs = specs["helipad"]
	var hm: Mesh = hs.mesh
	var hb: AABB = hm.get_aabb()
	var hr: float = 7.37 * 0.0115 * 100.0
	var pad_off = Vector3(hb.position.x + hr, 0.0, hb.position.z + hr)

	# Distance from heli_x to mesh left/right edges (measured earlier)
	var dist_to_left = 14.50   # mesh left edge is 14.5m LEFT of heli_x anchor
	var dist_to_right = 8.48  # mesh right edge is 8.48m RIGHT of heli_x anchor

	print("========== AFTER FIX (offset 16.5) ==========")
	for key in ["police", "hospital"]:
		var sp = specs[key]
		var w = float(sp.w)
		var d = float(sp.d)
		var xc = -44.0 if key == "police" else -36.0
		var cd = 18.0 if key == "police" else 15.0
		var door_dx = -5.6 if key == "police" else 0.0
		var back_t = cd + d + 0.8
		var NEW_OFFSET = 16.5
		var heli_x = xc + door_dx + w * 0.5 + NEW_OFFSET
		var fence_x0 = xc - (22.0 if key == "police" else 34.0)
		var fence_x1 = heli_x + 10.5
		var b_x_max = xc + door_dx + w * 0.5

		var mesh_left = heli_x - dist_to_left
		var mesh_right = heli_x + dist_to_right

		print("\n--- ", key.to_upper(), " ---")
		print("Building right edge:    X = ", b_x_max)
		print("Helipad mesh left edge: X = ", mesh_left)
		print("GAP (building -> pad):  ", mesh_left - b_x_max, " m  (positive = clear!)")
		print("Helipad mesh right edge:X = ", mesh_right)
		print("Fence right edge:       X = ", fence_x1)
		print("GAP (pad -> fence):     ", fence_x1 - mesh_right, " m  (positive = clear!)")
	
	quit()
