class_name WheelSlicer
extends RefCounted
## Finds the four wheels baked into a single-mesh PSX car (small separate triangle islands touching the ground),
## and returns them as their own meshes centred on the axle so they can spin and steer.
## Returns {} when exactly four wheels are not found, otherwise {"body": ArrayMesh, "wheels": [{mesh, center, radius}]}.

static func extract(mesh: Mesh) -> Dictionary:
	var bodies: Array = []
	var wheel_tris: Dictionary = {}     # island root -> {"v","n","uv","min","max"}
	var island_of_surface: Array = []
	for si in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(vs.size())
			for i in range(vs.size()): idx[i] = i
		# weld vertices by position so UV seams do not split islands
		var weld := {}
		var wid := PackedInt32Array()
		wid.resize(vs.size())
		for i in range(vs.size()):
			var k := Vector3i((vs[i] * 1000.0).round())
			if not weld.has(k): weld[k] = weld.size()
			wid[i] = weld[k]
		var parent := PackedInt32Array()
		parent.resize(weld.size())
		for i in range(parent.size()): parent[i] = i
		for t in range(0, idx.size() - 2, 3):
			var a := _find(parent, wid[idx[t]])
			for k in range(1, 3):
				var b := _find(parent, wid[idx[t + k]])
				if a != b: parent[b] = a
		var islands := {}
		for t in range(0, idx.size() - 2, 3):
			var r := _find(parent, wid[idx[t]])
			if not islands.has(r):
				islands[r] = {"tris": [], "min": Vector3(1e9, 1e9, 1e9), "max": Vector3(-1e9, -1e9, -1e9)}
			var isl: Dictionary = islands[r]
			(isl.tris as Array).append(t)
			for k in range(3):
				var p := vs[idx[t + k]]
				isl.min = (isl.min as Vector3).min(p)
				isl.max = (isl.max as Vector3).max(p)
		var body := {"v": [], "n": [], "uv": []}
		var found: Array = []
		for r in islands:
			var isl: Dictionary = islands[r]
			var sz: Vector3 = isl.max - isl.min
			var is_wheel: bool = (isl.tris as Array).size() <= 64 and (isl.min as Vector3).y < 0.15 \
				and sz.y > 0.5 and sz.y < 1.4 and sz.z > 0.5 and sz.z < 1.4 and sz.x < 0.6
			for t in isl.tris:
				var target: Dictionary = body
				if is_wheel:
					if not wheel_tris.has(r):
						wheel_tris[r] = {"v": [], "n": [], "uv": [], "min": isl.min, "max": isl.max}
					target = wheel_tris[r]
				for k in range(3):
					var i := idx[t + k]
					(target.v as Array).append(vs[i])
					(target.n as Array).append(ns[i] if i < ns.size() else Vector3.UP)
					(target.uv as Array).append(uvs[i] if i < uvs.size() else Vector2.ZERO)
		bodies.append(body)
	if wheel_tris.size() != 4:
		return {}
	var wheels: Array = []
	for r in wheel_tris:
		var w: Dictionary = wheel_tris[r]
		var center: Vector3 = ((w.min as Vector3) + (w.max as Vector3)) * 0.5
		var m := ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		var vs2 := PackedVector3Array(w.v)
		for i in range(vs2.size()): vs2[i] -= center
		arr[Mesh.ARRAY_VERTEX] = vs2
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(w.n)
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(w.uv)
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var sz2: Vector3 = (w.max as Vector3) - (w.min as Vector3)
		wheels.append({"mesh": m, "center": center, "radius": (sz2.y + sz2.z) * 0.25})
	var bm := ArrayMesh.new()
	for b in bodies:
		if (b.v as Array).is_empty(): continue
		var arr2 := []
		arr2.resize(Mesh.ARRAY_MAX)
		arr2[Mesh.ARRAY_VERTEX] = PackedVector3Array(b.v)
		arr2[Mesh.ARRAY_NORMAL] = PackedVector3Array(b.n)
		arr2[Mesh.ARRAY_TEX_UV] = PackedVector2Array(b.uv)
		bm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
	return {"body": bm, "wheels": wheels}

static func _find(parent: PackedInt32Array, a: int) -> int:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a
