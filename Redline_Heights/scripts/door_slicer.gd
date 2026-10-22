class_name DoorSlicer
extends RefCounted
## Cuts a door out of a single-mesh PSX car. Side-panel triangles are clipped to a box
## (z between back edge and hinge, y above the sill); UVs and normals are interpolated so the
## baked texture still lines up. Returns {"body", "door", "pivot"} in the source mesh space.

static func _lerp_v(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {"p": (a.p as Vector3).lerp(b.p, t), "uv": (a.uv as Vector2).lerp(b.uv, t), "n": ((a.n as Vector3).lerp(b.n, t)).normalized()}

## Splits a convex polygon by axis plane; returns [inside, outside] where inside has p[axis]*sign >= limit*sign.
static func _split(poly: Array, axis: int, limit: float, sign: float) -> Array:
	var inside: Array = []
	var outside: Array = []
	for i in range(poly.size()):
		var a: Dictionary = poly[i]
		var b: Dictionary = poly[(i + 1) % poly.size()]
		var da: float = ((a.p as Vector3)[axis] - limit) * sign
		var db: float = ((b.p as Vector3)[axis] - limit) * sign
		if da >= 0.0: inside.append(a)
		else: outside.append(a)
		if (da >= 0.0) != (db >= 0.0):
			var t := da / (da - db)
			var m := _lerp_v(a, b, t)
			inside.append(m)
			outside.append(m)
	return [inside, outside]

static func _emit(poly: Array, out: Dictionary) -> void:
	if poly.size() < 3: return
	for i in range(1, poly.size() - 1):
		for v in [poly[0], poly[i], poly[i + 1]]:
			(out.v as Array).append(v.p)
			(out.n as Array).append(v.n)
			(out.uv as Array).append(v.uv)

static func _new_out() -> Dictionary:
	return {"v": [], "n": [], "uv": []}

static func _to_mesh(parts: Array, offset: Vector3) -> ArrayMesh:
	var m := ArrayMesh.new()
	for out in parts:
		if (out.v as Array).is_empty(): continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		var vs := PackedVector3Array(out.v)
		if offset != Vector3.ZERO:
			for i in range(vs.size()): vs[i] -= offset
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(out.n)
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(out.uv)
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## side: +1 cuts the +X door, -1 the -X door. z_hinge > z_back. y_min is the sill height. x_min is how far
## out (abs x) a triangle must lie to count as side panel.
static func slice(mesh: Mesh, side: float, z_hinge: float, z_back: float, y_min: float, x_min: float) -> Dictionary:
	var bodies: Array = []
	var doors: Array = []
	var hinge_x := 0.0
	var hinge_n := 0
	for si in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(vs.size())
			for i in range(vs.size()): idx[i] = i
		var body := _new_out()
		var door := _new_out()
		for t in range(0, idx.size() - 2, 3):
			var poly: Array = []
			var all_side := true
			for k in range(3):
				var i := idx[t + k]
				var p := vs[i]
				if p.x * side < x_min: all_side = false
				poly.append({"p": p, "uv": uvs[i] if i < uvs.size() else Vector2.ZERO, "n": ns[i] if i < ns.size() else Vector3.UP})
			if not all_side:
				_emit(poly, body)
				continue
			# clip to the door box; whatever falls outside goes back to the body
			var s1 := _split(poly, 2, z_hinge, -1.0)    # inside: z <= hinge
			_emit(s1[1], body)
			var s2 := _split(s1[0], 2, z_back, 1.0)     # inside: z >= back
			_emit(s2[1], body)
			var s3 := _split(s2[0], 1, y_min, 1.0)      # inside: y >= sill
			_emit(s3[1], body)
			_emit(s3[0], door)
		bodies.append(body)
		doors.append(door)
	# hinge pivot x: average x of door vertices at the hinge edge
	for out in doors:
		for p in (out.v as Array):
			if absf(p.z - z_hinge) < 0.06:
				hinge_x += p.x
				hinge_n += 1
	var pivot := Vector3(hinge_x / maxf(hinge_n, 1) if hinge_n > 0 else side * x_min, 0.0, z_hinge)
	return {"body": _to_mesh(bodies, Vector3.ZERO), "door": _to_mesh(doors, pivot), "pivot": pivot}
