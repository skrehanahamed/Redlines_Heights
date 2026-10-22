extends SceneTree
## Dev tool: dumps the shore-distance grid (10 m steps over the whole map) for drawing the maps.
## godot --headless --path . -s res://scripts/export_coast.gd
func _initialize() -> void:
	var half := 3500
	var n := half * 2 / 10 + 1
	var arr := PackedFloat32Array()
	arr.resize(n * n)
	for j in range(n):
		for i in range(n):
			arr[j * n + i] = Coast.inland(-half + i * 10.0, -half + j * 10.0)
	var f := FileAccess.open("/tmp/coast_d.bin", FileAccess.WRITE)
	f.store_buffer(arr.to_byte_array())
	f.close()
	Renowood.height(850.0, -1500.0)
	var hh := PackedFloat32Array()
	hh.resize(n * n)
	for j in range(n):
		for i in range(n):
			var x := -half + i * 10.0
			var z := -half + j * 10.0
			hh[j * n + i] = Renowood.mask(x, z) if Renowood.in_bbox(Rect2(x, z, 1.0, 1.0)) else 0.0
	var f2 := FileAccess.open("/tmp/coast_mask.bin", FileAccess.WRITE)
	f2.store_buffer(hh.to_byte_array())
	f2.close()
	var hz := PackedFloat32Array()
	hz.resize(n * n)
	for j in range(n):
		for i in range(n):
			hz[j * n + i] = Coast.height_at(-half + i * 10.0, -half + j * 10.0)
	var f4 := FileAccess.open("/tmp/coast_h.bin", FileAccess.WRITE)
	f4.store_buffer(hz.to_byte_array())
	f4.close()
	var info := {"road": [], "drives": [], "pads": [], "sign": [Renowood.SIGN_C.x, Renowood.SIGN_C.y], "museum": [Renowood.MUSEUM_C.x, Renowood.MUSEUM_C.y]}
	for p in Renowood.path_pts: info.road.append([p.x, p.y])
	for pd in Renowood.pads:
		var dl := []
		for k in range(0, 31, 6):
			var q: Vector2 = pd.spur_from + pd.spur_dir * float(k)
			dl.append([q.x, q.y])
		info.drives.append(dl)
	for pd in Renowood.pads: info.pads.append([pd.c.x, pd.c.y])
	var f3 := FileAccess.open("/tmp/renowood.json", FileAccess.WRITE)
	f3.store_string(JSON.stringify(info))
	f3.close()
	print("wrote ", n, " x ", n)
	quit()
