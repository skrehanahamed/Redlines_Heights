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

	for key in ["police", "hospital"]:
		print("\n================== ", key.to_upper(), " ==================")
		var sp = specs[key]
		var w = float(sp.w)
		var d = float(sp.d)
		var xc = -44.0 if key == "police" else -36.0
		var cd = 18.0 if key == "police" else 15.0
		var door_dx = -5.6 if key == "police" else 0.0
		var back_t = cd + d + 0.8
		var heli_x = xc + door_dx + w * 0.5 + 12.5
		var fence_x0 = xc - (22.0 if key == "police" else 34.0)
		var fence_x1 = heli_x + 10.5
		
		# Building in compound coordinates (X, t):
		# Building center is at (xc + door_dx, cd + d * 0.5)
		# Note: In _put(c, key, o + Vector2(xc + door_dx, sgn * bz), ...):
		# bz = OUTER_LINE - cd - d * 0.5. Since t = OUTER_LINE - z (in sgn coordinates), t = cd + d * 0.5!
		var b_x_min = xc + door_dx - w * 0.5
		var b_x_max = xc + door_dx + w * 0.5
		var b_t_min = cd
		var b_t_max = cd + d
		print("Building X: [", b_x_min, ", ", b_x_max, "] (width=", w, ")")
		print("Building t: [", b_t_min, ", ", b_t_max, "] (depth=", d, ")")
		
		# Helipad in compound coordinates:
		# In city_build.gd:
		# var hyaw := (-PI * 0.5) if heli_x > xc else (PI * 0.5)
		# var hbasis := Basis(Vector3.UP, hyaw)
		# var hpos := Vector3(o.x + heli_x, BASE_H, zt.call(cd + (back_t - cd) * 0.5)) - hbasis * pad_off
		# Note that zt(t) = o.y + sgn * (OUTER_LINE - t).
		# For sgn = 1 (police): z increases as t decreases!
		# For sgn = -1 (hospital): z increases as t increases!
		# Let's work directly in (X, t) coordinate frame where t=0 is front fence, t=back_t is back fence!
		# Wait! What does hbasis do?
		# hyaw = -PI * 0.5 (-90 degrees).
		# In 3D:
		# Basis(UP, -PI*0.5) rotates X -> -Z, Z -> X!
		# Wait! zt.call(t) is in World Z!
		# Let's check how zt works with hbasis!
		print("heli_x = ", heli_x)
		print("fence X: [", fence_x0, ", ", fence_x1, "]")
		print("fence t: [0, ", back_t, "]")
		
		# Let's inspect the actual transformed vertices of the helipad mesh in world space!
		# Assume o = (0, 0), sgn = 1.0 (police) or sgn = -1.0 (hospital)
		var sgn = 1.0 if key == "police" else -1.0
		var hyaw = (-PI * 0.5) if heli_x > xc else (PI * 0.5)
		var hbasis = Basis(Vector3.UP, hyaw)
		var heli_t = cd + (back_t - cd) * 0.5
		var zt_val = sgn * (76.0 - heli_t) # OUTER_LINE is 76.0
		var hpos = Vector3(heli_x, 0.0, zt_val) - hbasis * pad_off
		var xf = Transform3D(hbasis, hpos)
		
		# Get min and max of all vertices of helipad mesh under xf
		var min_x = 1e9
		var max_x = -1e9
		var min_z = 1e9
		var max_z = -1e9
		for s in range(hm.get_surface_count()):
			var arr = hm.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				var wv = xf * v
				min_x = minf(min_x, wv.x)
				max_x = maxf(max_x, wv.x)
				min_z = minf(min_z, wv.z)
				max_z = maxf(max_z, wv.z)
		
		# Convert min_z, max_z to t:
		# wv.z = sgn * (76.0 - t) => t = 76.0 - wv.z / sgn = 76.0 - sgn * wv.z
		# Note that if sgn = 1: t_min = 76.0 - max_z, t_max = 76.0 - min_z
		# If sgn = -1: t_min = 76.0 + min_z, t_max = 76.0 + max_z
		var t1 = 76.0 - sgn * min_z
		var t2 = 76.0 - sgn * max_z
		var heli_t_min = minf(t1, t2)
		var heli_t_max = maxf(t1, t2)
		
		print("Helipad actual mesh bounds in X: [", min_x, ", ", max_x, "] (width=", max_x - min_x, ")")
		print("Helipad actual mesh bounds in t: [", heli_t_min, ", ", heli_t_max, "] (depth=", heli_t_max - heli_t_min, ")")
		print("Helipad nominal center: X=", heli_x, " t=", heli_t)
		print("Helipad mesh center: X=", (min_x + max_x)*0.5, " t=", (heli_t_min + heli_t_max)*0.5)
		
		# Check overlap with Building:
		# Building in X is [b_x_min, b_x_max], in t is [b_t_min, b_t_max]
		var overlap_x = maxf(0.0, minf(max_x, b_x_max) - maxf(min_x, b_x_min))
		var overlap_t = maxf(0.0, minf(heli_t_max, b_t_max) - maxf(heli_t_min, b_t_min))
		print("Distance from building right edge (b_x_max=", b_x_max, ") to helipad left edge (min_x=", min_x, "): ", min_x - b_x_max)
		print("Distance from helipad right edge (max_x=", max_x, ") to fence right edge (fence_x1=", fence_x1, "): ", fence_x1 - max_x)
		print("Distance from helipad front edge (heli_t_min=", heli_t_min, ") to front fence (t=0): ", heli_t_min - 0.0)
		print("Distance from helipad back edge (heli_t_max=", heli_t_max, ") to back fence (back_t=", back_t, "): ", back_t - heli_t_max)
		
		# ALSO check collision box added in city_build.gd:
		# CoastProps._box(c.body, Vector3(hr * 1.7, 1.9, hr * 1.7), Vector3(o.x + heli_x, BASE_H + 0.95, zt.call(cd + (back_t - cd) * 0.5)))
		var col_half = (hr * 1.7) * 0.5
		print("Helipad collision box in X: [", heli_x - col_half, ", ", heli_x + col_half, "]")
		print("Helipad collision box in t: [", heli_t - col_half, ", ", heli_t + col_half, "]")
	
	quit()
