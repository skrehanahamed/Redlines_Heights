class_name CityRoads
extends RefCounted
## Builds the road network from the graph: asphalt ribbons (streets 16 m, highways 20 m), junction patches,
## a raised deck with collision wherever a road crosses water (the bridge), and street lamps.

const DECK_Y := 0.18
const BRIDGE_MAX := 6.5          # deck height above the sea at the middle of a long span

## Height of the road deck over open water at p: rises from the shore to BRIDGE_MAX over about 70 m.
static func bridge_h(p: Vector2) -> float:
	var shore := 80.0
	for a in range(8):
		var dir := Vector2.from_angle(a * TAU / 8.0)
		var dd := 0.0
		while dd < 80.0 and CityData.is_water(p.x + dir.x * dd, p.y + dir.y * dd):
			dd += 8.0
		shore = minf(shore, dd)
	var t := clampf(shore / 70.0, 0.0, 1.0)
	return 0.18 + t * t * (3.0 - 2.0 * t) * BRIDGE_MAX

static func _y_at(p: Vector2) -> float:
	return maxf(CityData.height_at(p.x, p.y), -0.2) + 0.04

static func build(w: World) -> void:
	var lined := _mat("res://assets/roads/road_lined.png", Color(1.0, 1.0, 1.0))
	var plain := _mat("res://assets/roads/road_plain.png", Color(1.0, 1.0, 1.0))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var deg := PackedInt32Array()
	deg.resize(CityData.nodes.size())
	for e in CityData.edges:
		deg[int(e[0])] += 1
		deg[int(e[1])] += 1
	var decks: Array = []
	for e in CityData.edges:
		var kind := int(e[2])
		var a := CityData.nodes[int(e[0])]
		var b := CityData.nodes[int(e[1])]
		var dir := (b - a)
		var length := dir.length()
		if length < 0.5: continue
		dir /= length
		var nrm := Vector2(-dir.y, dir.x)
		var width := 20.0 if kind == 1 else CityData.road_w
		var mid := (a + b) * 0.5
		var on_water := CityData.is_water(mid.x, mid.y)
		var wa := CityData.is_water(a.x, a.y)
		var wb := CityData.is_water(b.x, b.y)
		var ya := bridge_h(a) if (on_water or wa) else _y_at(a)
		var yb := bridge_h(b) if (on_water or wb) else _y_at(b)
		if on_water: ya = bridge_h(a); yb = bridge_h(b)
		var base := verts.size()
		var p0 := a - nrm * width * 0.5
		var p1 := a + nrm * width * 0.5
		var p2 := b - nrm * width * 0.5
		var p3 := b + nrm * width * 0.5
		verts.append(Vector3(p0.x, ya, p0.y)); verts.append(Vector3(p1.x, ya, p1.y))
		verts.append(Vector3(p2.x, yb, p2.y)); verts.append(Vector3(p3.x, yb, p3.y))
		for i in range(4): norms.append(Vector3.UP)
		var vl := length / 24.0
		uvs.append(Vector2(0, 0)); uvs.append(Vector2(1, 0)); uvs.append(Vector2(0, vl)); uvs.append(Vector2(1, vl))
		idx.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
		if on_water:
			decks.append({"mid": mid, "len": length, "ang": atan2(dir.x, dir.y), "w": width, "ya": ya, "yb": yb})
	if verts.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, lined)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = "Roads"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mi)
	# junction patches without markings
	var jv := PackedVector3Array()
	var jn := PackedVector3Array()
	var ju := PackedVector2Array()
	var ji := PackedInt32Array()
	for i in range(CityData.nodes.size()):
		if deg[i] < 3: continue
		var p := CityData.nodes[i]
		if CityData.is_water(p.x, p.y): continue
		var hw_ := 9.0
		var y := _y_at(p) + 0.005
		var base := jv.size()
		jv.append(Vector3(p.x - hw_, y, p.y - hw_)); jv.append(Vector3(p.x + hw_, y, p.y - hw_))
		jv.append(Vector3(p.x - hw_, y, p.y + hw_)); jv.append(Vector3(p.x + hw_, y, p.y + hw_))
		for k in range(4): jn.append(Vector3.UP)
		ju.append(Vector2(0, 0)); ju.append(Vector2(1, 0)); ju.append(Vector2(0, 1)); ju.append(Vector2(1, 1))
		ji.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
	if jv.size() > 0:
		var arr2 := []
		arr2.resize(Mesh.ARRAY_MAX)
		arr2[Mesh.ARRAY_VERTEX] = jv
		arr2[Mesh.ARRAY_NORMAL] = jn
		arr2[Mesh.ARRAY_TEX_UV] = ju
		arr2[Mesh.ARRAY_INDEX] = ji
		var m2 := ArrayMesh.new()
		m2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
		m2.surface_set_material(0, plain)
		var mi2 := MeshInstance3D.new()
		mi2.mesh = m2
		mi2.name = "Junctions"
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mi2)
	# bridge: sloped collision decks, railings, pillars and lamps
	var concrete := w._mat("res://assets/textures/y2k_concrete.png", 0.3, Color(1.1, 1.05, 1.0))
	var steel := w._flat(Color("#9aa0a8"))
	var n_deck := 0
	for d in decks:
		var ym: float = (d.ya + d.yb) * 0.5
		var slope := atan2(d.yb - d.ya, d.len)
		var body := StaticBody3D.new()
		body.position = Vector3(d.mid.x, ym - 0.3, d.mid.y)
		body.rotation = Vector3(0, d.ang, 0)
		body.rotate_object_local(Vector3.RIGHT, -slope)
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(d.w + 2.0, 0.6, d.len + 0.6)
		cs.shape = bs
		body.add_child(cs)
		var mi3 := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(d.w + 2.0, 0.6, d.len + 0.6)
		mi3.mesh = bm
		mi3.material_override = concrete
		body.add_child(mi3)
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.22, 1.0, d.len + 0.4)
			rail.mesh = rm
			rail.material_override = steel
			rail.position = Vector3(side * (d.w * 0.5 + 0.8), 0.8, 0)
			body.add_child(rail)
			var top := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.3, 0.12, d.len + 0.4)
			top.mesh = tm
			top.material_override = steel
			top.position = Vector3(side * (d.w * 0.5 + 0.8), 1.35, 0)
			body.add_child(top)
			# the railing also blocks cars
			var wall := CollisionShape3D.new()
			var ws := BoxShape3D.new()
			ws.size = Vector3(0.3, 1.6, d.len + 0.4)
			wall.shape = ws
			wall.position = Vector3(side * (d.w * 0.5 + 0.8), 0.8, 0)
			body.add_child(wall)
		w.static_root.add_child(body)
		# pillars every other segment, down to the sea floor
		if ym > 1.8 and n_deck % 2 == 0:
			for side in [-1.0, 1.0]:
				var px: Vector2 = (d.mid as Vector2) + Vector2(cos(d.ang), -sin(d.ang)) * float(side) * (float(d.w) * 0.5 - 1.5)
				var pil := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				pm.top_radius = 0.9
				pm.bottom_radius = 1.1
				pm.height = ym + 10.0
				pm.radial_segments = 8
				pil.mesh = pm
				pil.material_override = concrete
				pil.position = Vector3(px.x, (ym - 0.6 - 10.0) * 0.5 + 0.0, px.y)
				w.static_root.add_child(pil)
			var cap := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(d.w + 1.0, 0.8, 2.2)
			cap.mesh = cm
			cap.material_override = concrete
			cap.position = Vector3(d.mid.x, ym - 0.9, d.mid.y)
			cap.rotation.y = d.ang
			w.static_root.add_child(cap)
		if ym > 3.0 and n_deck % 3 == 0:
			for side in [-1.0, 1.0]:
				var lp: Vector2 = (d.mid as Vector2) + Vector2(cos(d.ang), -sin(d.ang)) * float(side) * (float(d.w) * 0.5 + 0.8)
				w.place("res://assets/props/street/lamp_cobra.glb", "", Vector3(lp.x, ym + 0.1, lp.y), d.ang + (PI if side > 0.0 else 0.0), 1.0, -1.0, 6.5, false)
		n_deck += 1
	# street lamps at the junctions
	var lamps: Array = []
	for i in range(CityData.nodes.size()):
		if deg[i] < 3: continue
		var p := CityData.nodes[i]
		if CityData.is_water(p.x, p.y): continue
		lamps.append(Transform3D(Basis(Vector3.UP, atan2(-1.0, -1.0)), Vector3(p.x + 10.5, _y_at(p) - 0.04, p.y + 10.5)))
	w.multi_place("res://assets/props/street/lamp_cobra.glb", "", lamps, 7.5)

static func _mat(path: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path) as Texture2D
	m.albedo_color = tint
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return m
