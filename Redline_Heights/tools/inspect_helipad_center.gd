@tool
extends SceneTree

func _init():
	var cb_script = load("res://scripts/city_build.gd")
	cb_script._specs()
	var hs = cb_script.specs["helipad"]
	var hm: Mesh = hs.mesh
	var hb: AABB = hm.get_aabb()
	var hr: float = 7.37 * 0.0115 * 100.0
	var pad_off = Vector3(hb.position.x + hr, 0.0, hb.position.z + hr)

	# Let's inspect where Object_4 (the circular pad) center ends up in the baked mesh:
	# In the original GLB, the circular pad center was at X=0, Z=0.
	# What is that vertex in the baked mesh?
	# In Renowood._baked: vertex was shifted by -foot.
	# foot was (box.get_center().x, box.position.y, box.get_center().z) * sc
	# In baked mesh, the circular pad center is at (0 - foot.x, 0, 0 - foot.z).
	# Since hb is symmetric in X (-9.31 to +9.31), foot.x was 0.
	# foot.z was roughly 2.08m, so circular pad center in baked mesh is at (0, 0, -2.17).
	# Let's verify by finding vertices of Object_4 in the baked mesh:
	# Object_4 has y around 151.7 * 0.0115 = 1.74m.
	# Let's find vertices with y between 1.6 and 1.9:
	var pad_verts: PackedVector3Array = []
	for s in range(hm.get_surface_count()):
		var arr = hm.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.y > 1.6 and v.y < 2.0:
				pad_verts.append(v)
	
	var min_pv = Vector3(1e9, 1e9, 1e9)
	var max_pv = Vector3(-1e9, -1e9, -1e9)
	for v in pad_verts:
		min_pv = min_pv.min(v)
		max_pv = max_pv.max(v)
	print("Circular pad bounds in baked mesh: min=", min_pv, " max=", max_pv)
	var pad_center = (min_pv + max_pv) * 0.5
	print("Circular pad center in baked mesh: ", pad_center)
	print("hb AABB center: ", hb.get_center())
	print("pad_off: ", pad_off)
	
	# If we transform pad_center by hbasis and hpos:
	var hyaw = -PI * 0.5
	var hbasis = Basis(Vector3.UP, hyaw)
	# hpos = heli_target - hbasis * pad_off
	# transformed pad_center = hpos + hbasis * pad_center
	#                        = heli_target + hbasis * (pad_center - pad_off)
	var heli_target = Vector3(0, 0, 0)
	var actual_pad_in_world = heli_target + hbasis * (pad_center - pad_off)
	print("Relative to heli_target (0,0), circular pad center is at: ", actual_pad_in_world)
	print("Relative to heli_target (0,0), mesh min=", hbasis * (hb.position - pad_off), " mesh max=", hbasis * (hb.end - pad_off))
	
	quit()
