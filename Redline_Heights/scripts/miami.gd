class_name Miami
extends RefCounted
## Redline Island as a Miami: pastel Art Deco hotels and shops round palm courtyards with ponds, modern waterfront mansions with
## pools, proper paved pavements, kerbs, palms, benches and neon. Every shop, hotel and house has a real doorway into a furnished
## ground floor (sliding glass doors); the metro stairwell and its surroundings are kept clear. Everything that has windows or
## neon is registered with CityLights, so it glows at night.

## While true, Redline Island keeps only its roads (grid, the two half-circle boulevards) and the metro: no buildings, parks, ponds, props, pavements or lamps.
const ROADS_ONLY := true
const XS := [-200.0, 0.0, 200.0, 400.0, 600.0]          # the island's street grid (world x)
const ZS := [1950.0, 2200.0, 2450.0]                      # (world z)
const KERB := 6.7                                         # street centre line to the pavement edge
const PY := 0.22                                          # pavement / lot height
const SW := 5.0                                           # pavement width
const H0 := 4.0                                           # ground storey height
const FH := 3.3                                           # upper storey height
const ROLES := [["mansion", "deco", "deco", "mansion"], ["plaza", "deco", "deco", "mansion"]]      # [row z][column x]

const PASTELS := ["#f7a8b8", "#a8e6cf", "#8fd8d6", "#fdf0cf", "#ffcba4", "#cdb4f6", "#ffe08a", "#bfe3f5", "#f9c6d9"]
const ACCENTS := ["#ff5c8a", "#12b5b0", "#ffb000", "#7d5fff", "#ff7a45", "#22c55e"]
const NAMES := ["SOUTH BEACH", "THE FLAMINGO", "MARLIN", "SAVOY", "ALBION", "COLONY", "CARDOZO", "BREAKWATER", "LUMMUS", "THE TIDES", "CASA GRANDE", "PARK CENTRAL", "THE CARLYLE", "ESSEX HOUSE", "WOLFSONIAN", "ARDEN", "NEMO", "LEAF BAR", "SUNSET LOUNGE", "CLUB 305"]
const SHOP_NAMES := ["CAFE", "ICE CREAM", "GELATO", "SUSHI", "PIZZA", "BAR", "DELI", "BOUTIQUE", "SURF SHOP", "JUICE BAR", "DINER", "CIGARS"]
const MIAMI_DIR := "res://assets/miami/"

static var reserved: Array = []              # Rect2 (world x, z): kept clear (the metro stairwell)
## Props that get a collision box of their own size (the rest have their own, or are flat plants and markings).
const SOLID_PROPS := ["playground", "picnic", "bleacher", "ramp", "tower_viz", "tower_mid", "tower_low", "bench", "bins", "meter", "mailbox", "icecream", "busstop", "net", "cart", "rower", "pullup", "btable", "fence", "bar", "cafe", "hotel", "lifebuoy", "flowerbed"]
static var solid_body: StaticBody3D
static var _mats := {}
static var _inland_water: ShaderMaterial
static var _batch := {}                      # prop key -> [Transform3D]
static var _props := {}                      # prop key -> {mesh, size}
static var _lit_glass: StandardMaterial3D
static var _dark_glass: StandardMaterial3D
static var _lamp_mat: StandardMaterial3D
static var _neon_cache := {}
static var buildings := 0
static var doors := 0

# ------------------------------------------------------------------ small helpers

static func _hash(a: float, b: float, salt := 0.0) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233 + salt * 37.719) * 43758.5453, 1.0)

static func _tex(name: String) -> Texture2D:
	return load(MIAMI_DIR + "tex/" + name) as Texture2D

static func _surface_mat(key: String, name: String, scale: float, tint := Color.WHITE, rough := 1.0) -> StandardMaterial3D:
	var k := "%s|%s|%s" % [key, scale, tint.to_html()]
	if _mats.has(k): return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(name + "_Color.jpg")
	m.albedo_color = tint
	m.roughness = rough
	if ResourceLoader.exists(MIAMI_DIR + "tex/" + name + "_NormalGL.jpg"):
		m.normal_enabled = true
		m.normal_texture = _tex(name + "_NormalGL.jpg")
		m.normal_scale = 0.8
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[k] = m
	return m

static func _flat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var k := "flat|%s|%s|%s" % [color.to_html(), rough, metal]
	if _mats.has(k): return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_mats[k] = m
	return m

static func _plaster(tint: Color) -> StandardMaterial3D:
	return _surface_mat("plaster", "Plaster002", 0.35, tint, 0.92)

static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var k := "emis|%s|%s" % [color.to_html(), energy]
	if _mats.has(k): return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.55)
	m.roughness = 0.6
	CityLights.register_material(m, color, energy)
	_mats[k] = m
	return m

static func _glass_mats() -> void:
	if _dark_glass != null: return
	_dark_glass = StandardMaterial3D.new()
	_dark_glass.albedo_color = Color(0.16, 0.26, 0.34)
	_dark_glass.roughness = 0.08
	_dark_glass.metallic = 0.5
	_lit_glass = StandardMaterial3D.new()
	_lit_glass.albedo_color = Color(0.2, 0.3, 0.36)
	_lit_glass.roughness = 0.1
	_lit_glass.metallic = 0.4
	CityLights.register_material(_lit_glass, Color(1.0, 0.78, 0.45), 0.9)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.95, 0.95, 0.9)
	CityLights.register_material(_lamp_mat, Color(1.0, 0.95, 0.85), 2.2)

static func _overlaps_reserved(r: Rect2) -> bool:
	for rv in reserved:
		if (rv as Rect2).intersects(r): return true
	return false

static func _local_rect(front: Vector2, yaw: float, w: float, d: float) -> Rect2:
	var f := Vector2(sin(yaw), cos(yaw))
	var r := Vector2(f.y, -f.x)
	var pts := [front + r * w * 0.5, front - r * w * 0.5, front + r * w * 0.5 - f * d, front - r * w * 0.5 - f * d]
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	return Rect2(mn, mx - mn)

# ------------------------------------------------------------------ mesh builder (one mesh per building, one surface per material)

static func _surf(mb: Dictionary, mat: Material) -> Dictionary:
	var k := mat.get_instance_id()
	if not mb.has(k):
		mb[k] = {"mat": mat, "v": [], "n": [], "u": [], "i": []}
	return mb[k]

## a, b, c, d run counter-clockwise as seen from the outside of the face.
static func _quad(mb: Dictionary, mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uvs := 0.25) -> void:
	var s := _surf(mb, mat)
	var n := (b - a).cross(d - a).normalized()
	var base: int = (s.v as Array).size()
	var lu := (b - a).length() * uvs
	var lv := (d - a).length() * uvs
	for p in [a, b, c, d]:
		(s.v as Array).append(p)
		(s.n as Array).append(n)
	(s.u as Array).append(Vector2(0, lv))
	(s.u as Array).append(Vector2(lu, lv))
	(s.u as Array).append(Vector2(lu, 0))
	(s.u as Array).append(Vector2(0, 0))
	for k in [0, 3, 2, 0, 2, 1]:
		(s.i as Array).append(base + k)

static func _box(mb: Dictionary, mat: Material, p0: Vector3, p1: Vector3, uvs := 0.25, skip_bottom := false) -> void:
	var x0 := minf(p0.x, p1.x); var x1 := maxf(p0.x, p1.x)
	var y0 := minf(p0.y, p1.y); var y1 := maxf(p0.y, p1.y)
	var z0 := minf(p0.z, p1.z); var z1 := maxf(p0.z, p1.z)
	_quad(mb, mat, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), uvs)
	_quad(mb, mat, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), uvs)
	_quad(mb, mat, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), uvs)
	_quad(mb, mat, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), uvs)
	_quad(mb, mat, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), uvs)
	if not skip_bottom:
		_quad(mb, mat, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), uvs)

static func _finish(mb: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for k in mb:
		var s: Dictionary = mb[k]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		if (s.v as Array).is_empty(): continue
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(s.v)
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(s.n)
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(s.u)
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array(s.i)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, s.mat)
	return mesh

static func _cbox(body: StaticBody3D, size: Vector3, centre: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = centre
	body.add_child(cs)

## Collision for the box p0..p1 (local coordinates).
static func _cb(body: StaticBody3D, p0: Vector3, p1: Vector3) -> void:
	var mn := Vector3(minf(p0.x, p1.x), minf(p0.y, p1.y), minf(p0.z, p1.z))
	var mx := Vector3(maxf(p0.x, p1.x), maxf(p0.y, p1.y), maxf(p0.z, p1.z))
	_cbox(body, mx - mn, (mn + mx) * 0.5)

# ------------------------------------------------------------------ props (palms, benches, ...) baked once, instanced everywhere

## All meshes under nodes whose name starts with `prefix` (any ancestor), merged into one mesh standing on the origin and scaled so
## it is `target` metres tall (or by `scale` when given). {mesh, size}
static func _bake(path: String, prefix: String, target: float, scale := 0.0, keep := "") -> Dictionary:
	if not ResourceLoader.exists(path): return {}
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	var parts: Array = []
	_collect(inst, Transform3D.IDENTITY, [], prefix, keep, parts)
	if parts.is_empty():
		inst.free()
		return {}
	var box := AABB()
	var first := true
	for p in parts:
		var bb: AABB = (p.xf as Transform3D) * (p.mesh as Mesh).get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	var sc := scale if scale > 0.0 else target / maxf(box.size.y, 0.0001)
	var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var xf0 := Transform3D(Basis.from_scale(Vector3.ONE * sc), -foot * sc)
	var sts := {}
	for p in parts:
		var m: Mesh = p.mesh
		for si in range(m.get_surface_count()):
			if m.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES: continue
			var mat := m.surface_get_material(si)
			var key := mat.get_instance_id() if mat != null else 0
			if not sts.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				sts[key] = {"st": st, "mat": mat}
			(sts[key].st as SurfaceTool).append_from(m, si, xf0 * (p.xf as Transform3D))
	var out := ArrayMesh.new()
	for key in sts:
		var st: SurfaceTool = sts[key].st
		st.set_material(sts[key].mat)
		st.commit(out)
	inst.free()
	return {"mesh": out, "size": box.size * sc}

static func _collect(n: Node, xf: Transform3D, chain: Array, prefix: String, keep: String, out: Array) -> void:
	var t := xf
	var ch := chain.duplicate()
	if n is Node3D: t = xf * (n as Node3D).transform
	ch.append(String(n.name))
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var ok := prefix == ""
		for nm in ch:
			if prefix != "" and String(nm).begins_with(prefix): ok = true
		if ok and keep != "":
			ok = false
			for nm in ch:
				if String(nm).contains(keep): ok = true
		if ok: out.append({"mesh": (n as MeshInstance3D).mesh, "xf": t})
	for c in n.get_children(): _collect(c, t, ch, prefix, keep, out)

static func _prep_props() -> void:
	if not _props.is_empty(): return
	var palms := MIAMI_DIR + "low_poly_palms_pack.glb"
	for k in range(1, 6): _props["palm_t%d" % k] = _bake(palms, "Palm %d " % k, 13.0)
	for k in range(6, 9): _props["palm_m%d" % k] = _bake(palms, "Palm %d " % k, 8.5)
	for k in range(9, 11): _props["palm_s%d" % k] = _bake(palms, "Palm %d " % k, 4.5)
	_props["bench"] = _bake(MIAMI_DIR + "bench_wooden_01.glb", "", 0.0, 1.7)
	_props["bins"] = _bake(MIAMI_DIR + "trash_can.glb", "", 1.15)
	_props["meter"] = _bake(MIAMI_DIR + "parking_meter_scan_lowpoly.glb", "", 1.35)
	_props["mailbox"] = _bake(MIAMI_DIR + "home_us_mailbox.glb", "", 1.3)
	_props["icecream"] = _bake(MIAMI_DIR + "ice_cream_cart.glb", "", 2.5)
	_props["busstop"] = _bake(MIAMI_DIR + "bus_stop_-_low.glb", "", 0.0, 0.14)
	_props["net"] = _bake(MIAMI_DIR + "volleyball_net_no_texture.glb", "", 2.4)
	var trop := MIAMI_DIR + "tropical_plants_pack_m02p.glb"
	for k in range(1, 4): _props["trop_palm%d" % k] = _bake(trop, "SM_MZRa_Palm_B08%d" % k, 7.0)
	_props["banana"] = _bake(trop, "SM_MZRa_Banana_B091", 3.6)
	_props["fern"] = _bake(trop, "SM_MZRa_Fern_B051", 1.2)
	_props["monstera"] = _bake(trop, "tree.007", 1.8)
	_props["bush"] = _bake(MIAMI_DIR + "small_bush.glb", "", 1.2)
	_props["flowerbed"] = _bake(MIAMI_DIR + "low_poly_flower_bed.glb", "", 0.0, 0.2)
	_props["gazebo"] = _bake(MIAMI_DIR + "gazebo.glb", "", 0.0, 1.0)
	_props["tower"] = _bake(MIAMI_DIR + "lifeguard_tower.glb", "", 4.6)
	_props["soccer"] = _bake(MIAMI_DIR + "soccer_field.glb", "", 0.0, 1.0)
	var mb6 := MIAMI_DIR + "6_low_poly_boats.glb"
	_props["boat0"] = _bake(mb6, "Boat_Material_0", 3.0)
	for k in range(1, 6): _props["boat%d" % k] = _bake(mb6, "Boat_00%d_" % k, 3.0)
	_props["pier"] = _bake(MIAMI_DIR + "wooden_pier_22_mb.glb", "", 0.0, 1.0)
	_props["walkway"] = _bake(MIAMI_DIR + "wooden_walkway_lowpoly.glb", "", 0.0, 1.0)
	_props["lighthouse"] = _bake(MIAMI_DIR + "the_lighthouse.glb", "", 0.0, 0.03)
	_props["fence"] = _bake(MIAMI_DIR + "modular_chain_link_fence_set.glb", "", 0.0, 0.35)
	_props["cart"] = _bake(MIAMI_DIR + "golf_cart.glb", "", 0.0, 0.3)
	_props["rower"] = _bake(MIAMI_DIR + "rower_-_outdoor_gym.glb", "", 0.0, 0.5)
	_props["pullup"] = _bake(MIAMI_DIR + "outdoor_gymnastics_pullup_bar.glb", "", 0.0, 1.0)
	_props["btable"] = _bake(MIAMI_DIR + "beach_table.glb", "", 2.4)
	_props["lifebuoy"] = _bake(MIAMI_DIR + "classic_lifebuoy_ring.glb", "", 0.0, 0.55)
	_props["ship"] = _bake(MIAMI_DIR + "ship.glb", "", 0.0, 1.0)
	_props["fishing"] = _bake(MIAMI_DIR + "fishing_boat.glb", "", 0.0, 1.2)
	var tw := MIAMI_DIR + "towers/"
	_props["tower_viz"] = _bake(tw + "hivizcayne.FBX", "", 0.0, 1.0)
	_props["tower_mid"] = _bake(tw + "AIT01W2W7.FBX", "", 0.0, 1.0)
	_props["tower_low"] = _bake(tw + "AIT01W2W5.FBX", "", 0.0, 1.0)
	for tk in ["viz", "mid", "low"]:
		var pr: Dictionary = _props["tower_" + tk]
		if pr.is_empty(): continue
		var nm: String = {"viz": "hivizcayne", "mid": "AIT01W2W7", "low": "AIT01W2W5"}[tk]
		# real windows only: the glass mask (made from the model's specular map) lights pane by pane at night
		CityLights.apply_shader(pr.mesh, {"mode": 3, "emit": tw + nm + "_win.png", "lit_frac": 0.5, "gain": 1.1})
	_props["lounger"] = _bake(MIAMI_DIR + "wooden_lounge_chair_beach_sun_lounger.glb", "", 0.0, 1.0)
	_props["sunchair"] = _bake(MIAMI_DIR + "sunchair.glb", "", 0.0, 1.0)
	_props["playground"] = _bake(MIAMI_DIR + "low_poly_kids_playground.glb", "", 0.0, 1.0)
	_props["picnic"] = _bake(MIAMI_DIR + "picnic_tables.glb", "Picnic_Table_1", 0.0, 0.04)
	_props["bleacher"] = _bake(MIAMI_DIR + "seating__bleacher.glb", "", 0.0, 40.0)
	_props["stringlights"] = _bake(MIAMI_DIR + "string_lights.glb", "", 0.0, 1.0)
	_props["seaplane"] = _bake(MIAMI_DIR + "seaplane_cessna_172.glb", "", 0.0, 1.0)
	_props["ramp"] = _bake(MIAMI_DIR + "ramp_lowpoly.glb", "", 0.0, 0.05)
	_props["umbrella"] = _bake(MIAMI_DIR + "low_poly_beach_assets.glb", "UMBRELLA3", 2.6)
	_props["surfboard"] = _bake(MIAMI_DIR + "low_poly_beach_assets.glb", "SURFBOARD2", 2.0)
	_props["hotel"] = _bake(MIAMI_DIR + "building.glb", "", 0.0, 5.2)
	_props["cafe"] = _bake(MIAMI_DIR + "low-poly_cafe.glb", "", 0.0, 1.8)
	_props["bar"] = _bake(MIAMI_DIR + "beachside_bar__lounge.glb", "", 0.0, 1.5)
	_props["yacht"] = _bake(MIAMI_DIR + "yacht.glb", "", 0.0, 0.9)
	_props["speedboat"] = _bake(MIAMI_DIR + "free_low_poly_yacth.glb", "", 0.0, 1.2)
	_props["jetski"] = _bake(MIAMI_DIR + "kawasaki_310xultra_jet_ski.glb", "", 0.0, 20.0)
	for k in _props: print("miami prop ", k, " ", (_props[k].size if _props[k].has("size") else "MISSING"))

static func _put(key: String, pos: Vector3, yaw: float, scale := 1.0) -> void:
	if not _props.has(key) or _props[key].is_empty(): return
	if solid_body != null and key == "cypress":
		# the planter pot is solid (the tree itself is only leaves)
		CoastProps._box(solid_body, Vector3(2.1, 1.15, 2.1) * scale, pos + Vector3(0.0, 0.575 * scale, 0.0), yaw)
	elif solid_body != null and key in SOLID_PROPS:
		# every prop that stands on the ground is solid: a box round its footprint
		var sz: Vector3 = (_props[key].size as Vector3) * scale
		CoastProps._box(solid_body, Vector3(maxf(sz.x, 0.25), sz.y, maxf(sz.z, 0.25)), pos + Vector3(0.0, sz.y * 0.5, 0.0), yaw)
	if not _batch.has(key): _batch[key] = []
	(_batch[key] as Array).append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * scale), pos))

static func _flush(w: World) -> void:
	for key in _batch:
		var big: bool = key in ["hotel", "yacht"]
		var tower: bool = String(key).begins_with("tower_")
		Renowood._emit_blocks(w, _props[key].mesh, _batch[key], 200.0, 3000.0 if tower else (520.0 if big else 260.0))
	_batch.clear()

static func _palm(body: StaticBody3D, p: Vector2, rng: RandomNumberGenerator, kind := "t") -> void:
	var keys: Array = []
	for k in _props:
		if String(k).begins_with("palm_" + kind): keys.append(k)
	if keys.is_empty(): return
	var key: String = keys[rng.randi() % keys.size()]
	_put(key, Vector3(p.x, PY, p.y), rng.randf() * TAU, rng.randf_range(0.85, 1.15))
	CoastProps._box(body, Vector3(0.6, 5.0, 0.6), Vector3(p.x, PY + 2.5, p.y))

# ------------------------------------------------------------------ slabs

static func _cut(r: Rect2, holes: Array) -> Array:
	for h in holes:
		var hr: Rect2 = h
		if r.intersects(hr):
			var out: Array = []
			var x0 := r.position.x; var x1 := r.end.x; var z0 := r.position.y; var z1 := r.end.y
			var hx0 := maxf(hr.position.x, x0); var hx1 := minf(hr.end.x, x1)
			var hz0 := maxf(hr.position.y, z0); var hz1 := minf(hr.end.y, z1)
			if hx0 > x0: out.append_array(_cut(Rect2(x0, z0, hx0 - x0, z1 - z0), holes))
			if hx1 < x1: out.append_array(_cut(Rect2(hx1, z0, x1 - hx1, z1 - z0), holes))
			if hz0 > z0: out.append_array(_cut(Rect2(hx0, z0, hx1 - hx0, hz0 - z0), holes))
			if hz1 < z1: out.append_array(_cut(Rect2(hx0, hz1, hx1 - hx0, z1 - hz1), holes))
			return out
	return [r]

## A slab from y0 to y1 over a rectangle (world x, z), with the metro stairwell openings cut out.
static func _slab(c: Dictionary, r: Rect2, y0: float, y1: float, mat: Material, collide := true) -> void:
	for piece in _cut(r, CityBuild.holes):
		var pr: Rect2 = piece
		if pr.size.x < 0.05 or pr.size.y < 0.05: continue
		var sz := Vector3(pr.size.x, y1 - y0, pr.size.y)
		var ctr := Vector3(pr.position.x + pr.size.x * 0.5, (y0 + y1) * 0.5, pr.position.y + pr.size.y * 0.5)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = mat
		mi.position = ctr
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(c.w as World).static_root.add_child(mi)
		if collide: CoastProps._box(c.body, sz, ctr)

# ------------------------------------------------------------------ neon

static func _neon_label(parent: Node3D, text: String, pos: Vector3, color: Color, px := 0.012, font := "monoton", yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Monoton-Regular.ttf" if font == "monoton" else ("res://assets/fonts/Righteous-Regular.ttf" if font == "righteous" else "res://assets/fonts/Pacifico-Regular.ttf")) as Font
	l.font_size = 96
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = color.darkened(0.7)
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	l.visibility_range_end = 220.0
	parent.add_child(l)
	return l

static func _stripes(c1: Color, c2: Color) -> StandardMaterial3D:
	var k := "stripe|%s|%s" % [c1.to_html(), c2.to_html()]
	if _mats.has(k): return _mats[k]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			img.set_pixel(x, y, c1 if (x / 8) % 2 == 0 else c2)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[k] = m
	return m

# ------------------------------------------------------------------ windows

## Windows along a wall: P(u, v) = origin + along * u + up * v; `out` is the outward normal (along x up must equal out).
static func _wall_windows(mb: Dictionary, origin: Vector3, along: Vector3, out: Vector3, length: float, y0: float, h: float, ww: float, gap: float, rng: RandomNumberGenerator, lit := 0.55, frame := true) -> void:
	var n := int(floor((length - gap) / (ww + gap)))
	if n <= 0: return
	var used := n * ww + (n - 1) * gap
	var u := (length - used) * 0.5
	var frame_mat := _flat(Color("#fbfbf6"), 0.7)
	for k in n:
		var ua := u + k * (ww + gap)
		var ub := ua + ww
		var glass: Material = _lit_glass if rng.randf() < lit else _dark_glass
		var fo := 0.012
		var po := 0.03
		if frame:
			_quad(mb, frame_mat, origin + along * (ua - 0.12) + Vector3.UP * (y0 - 0.12) + out * fo, origin + along * (ub + 0.12) + Vector3.UP * (y0 - 0.12) + out * fo,
				origin + along * (ub + 0.12) + Vector3.UP * (y0 + h + 0.12) + out * fo, origin + along * (ua - 0.12) + Vector3.UP * (y0 + h + 0.12) + out * fo)
		_quad(mb, glass, origin + along * ua + Vector3.UP * y0 + out * po, origin + along * ub + Vector3.UP * y0 + out * po,
			origin + along * ub + Vector3.UP * (y0 + h) + out * po, origin + along * ua + Vector3.UP * (y0 + h) + out * po)

# ------------------------------------------------------------------ the Art Deco building

## A pastel Art Deco building with a furnished, walkable ground floor. `front` is the middle of its front edge (world x, z), `yaw`
## turns local +z (the front) to the world. kind: cafe, shop, lobby, bar.
static func _building(c: Dictionary, front: Vector2, yaw: float, w: float, d: float, floors: int, kind: String, rng: RandomNumberGenerator, title := "", style := "deco", gy := PY) -> bool:
	if _overlaps_reserved(_local_rect(front, yaw, w + 2.0, d + 2.0)): return false
	if "--roadcheck" in OS.get_cmdline_user_args():
		var rr := _local_rect(front, yaw, w, d)
		var bad := false
		for xv in XS:
			if rr.position.x < xv + KERB and rr.end.x > xv - KERB and rr.position.y < 2460.0 and rr.end.y > 1940.0: bad = true
		for zv in ZS:
			if rr.position.y < zv + KERB and rr.end.y > zv - KERB and rr.position.x > -210.0 and rr.end.x < 610.0: bad = true
		if bad: print("ROADHIT ", kind, " front ", front, " yaw ", snappedf(yaw, 0.01), " w ", snappedf(w, 0.1), " d ", d, " rect ", rr)
	_glass_mats()
	var modern := style == "modern"
	var tint := Color(PASTELS[rng.randi() % PASTELS.size()])
	var acc := Color(ACCENTS[rng.randi() % ACCENTS.size()])
	if modern:
		tint = Color(["#f6f4ee", "#ebe7dc", "#e2e9ec", "#f3ece0"][rng.randi() % 4])
		acc = Color("#9b6a3c")
	var plaster := _plaster(tint)
	var plaster_light := _plaster(tint.lerp(Color.WHITE, 0.55))
	var white := _plaster(Color("#fbfaf4"))
	var accent := _flat(acc, 0.55)
	var floor_mat := _surface_mat("tile", "Tiles107", 0.6, Color(0.95, 0.93, 0.9), 0.4)
	var mb := {}
	var root := Node3D.new()
	root.position = Vector3(front.x, gy, front.y)
	root.rotation.y = yaw
	(c.w as World).static_root.add_child(root)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	var hw := w * 0.5
	var tk := 0.3
	if gy > PY + 0.01:
		_box(mb, plaster, Vector3(-hw, -2.0, -d), Vector3(hw, 0.0, 0.0), 0.25, true)       # plinth down into sloping ground
	var total := H0 + (floors - 1) * FH
	# --- ground floor shell
	_box(mb, floor_mat, Vector3(-hw, 0.0, -d), Vector3(hw, 0.04, 0.0), 0.5)
	_box(mb, plaster, Vector3(-hw, 0.0, -d), Vector3(hw, H0, -d + tk))
	_box(mb, plaster, Vector3(-hw, 0.0, -d + tk), Vector3(-hw + tk, H0, -tk))
	_box(mb, plaster, Vector3(hw - tk, 0.0, -d + tk), Vector3(hw, H0, -tk))
	_cb(body, Vector3(-hw, 0.0, -d), Vector3(hw, H0, -d + tk))
	_cb(body, Vector3(-hw, 0.0, -d + tk), Vector3(-hw + tk, H0, -tk))
	_cb(body, Vector3(hw - tk, 0.0, -d + tk), Vector3(hw, H0, -tk))
	# front wall with the doorway
	var dw := 3.2
	var xd := clampf((rng.randf() - 0.5) * w * 0.4, -hw + 2.8, hw - 2.8)
	var glass_shop := _lit_glass if rng.randf() < 0.8 else _dark_glass
	for seg in [[-hw, xd - dw * 0.5], [xd + dw * 0.5, hw]]:
		var a: float = seg[0]
		var b: float = seg[1]
		if b - a < 0.2: continue
		_box(mb, plaster, Vector3(a, 0.0, -tk), Vector3(b, 0.8, 0.0))
		_box(mb, plaster, Vector3(a, 3.35, -tk), Vector3(b, H0, 0.0))
		_box(mb, white, Vector3(a, 0.8, -tk), Vector3(a + 0.35, 3.35, 0.0))
		_box(mb, white, Vector3(b - 0.35, 0.8, -tk), Vector3(b, 3.35, 0.0))
		_quad(mb, glass_shop, Vector3(a + 0.35, 0.8, -0.1), Vector3(b - 0.35, 0.8, -0.1), Vector3(b - 0.35, 3.35, -0.1), Vector3(a + 0.35, 3.35, -0.1))
		_cb(body, Vector3(a, 0.0, -tk), Vector3(b, H0, 0.0))
	_box(mb, plaster, Vector3(xd - dw * 0.5, 2.7, -tk), Vector3(xd + dw * 0.5, H0, 0.0))
	_cb(body, Vector3(xd - dw * 0.5, 2.7, -tk), Vector3(xd + dw * 0.5, H0, 0.0))
	# --- upper floors
	_box(mb, plaster, Vector3(-hw, H0 - 0.25, -d), Vector3(hw, total, 0.0))
	_cb(body, Vector3(-hw, H0 - 0.25, -d), Vector3(hw, total, 0.0))
	var ww := rng.randf_range(1.2, 1.5)
	if modern:
		ww = 3.4
	for f in range(1, floors):
		var y0 := H0 + (f - 1) * FH + 0.8
		_wall_windows(mb, Vector3(-hw, 0, 0), Vector3.RIGHT, Vector3.BACK, w, y0, 2.0 if modern else 1.7, ww, 0.5 if modern else 1.1, rng)
		_wall_windows(mb, Vector3(hw, 0, -d), Vector3.LEFT, Vector3.FORWARD, w, y0, 1.7, ww, 1.1, rng)
		_wall_windows(mb, Vector3(-hw, 0, -d), Vector3.BACK, Vector3.LEFT, d, y0, 1.7, 1.3, 1.6, rng)
		_wall_windows(mb, Vector3(hw, 0, 0), Vector3.FORWARD, Vector3.RIGHT, d, y0, 1.7, 1.3, 1.6, rng)
		# Art Deco eyebrows over every window row, plus a pastel band between the storeys
		_box(mb, white, Vector3(-hw - 0.08, y0 + (2.25 if modern else 1.95), 0.0), Vector3(hw + 0.08, y0 + (2.42 if modern else 2.12), 1.1 if modern else 0.55))
		_box(mb, plaster_light, Vector3(-hw - 0.05, y0 - 0.9, -0.05), Vector3(hw + 0.05, y0 - 0.55, 0.12))
	# roof: parapet, stepped top tier, fins
	_box(mb, white, Vector3(-hw - 0.15, total, -d - 0.15), Vector3(hw + 0.15, total + 0.45, 0.15))
	if floors >= 3:
		var inset := minf(3.0, hw * 0.3)
		_box(mb, plaster_light, Vector3(-hw + inset, total + 0.45, -d + 2.0), Vector3(hw - inset, total + FH * 0.8, -d + d * 0.55))
		_box(mb, white, Vector3(-hw + inset - 0.15, total + FH * 0.8, -d + 1.85), Vector3(hw - inset + 0.15, total + FH * 0.8 + 0.3, -d + d * 0.55 + 0.15))
	var fin_x := (hw - 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
	if modern:
		# wooden slat screen over part of the upper front and a flat roof slab with a glass balustrade
		_box(mb, accent, Vector3(fin_x - 2.2, H0, 0.05), Vector3(fin_x + 2.2, total, 0.35))
		_box(mb, white, Vector3(-hw - 0.9, total, -d - 0.9), Vector3(hw + 0.9, total + 0.3, 1.4))
	else:
		_box(mb, accent, Vector3(fin_x - 0.45, H0, 0.0), Vector3(fin_x + 0.45, total + 2.6, 0.9))
		_box(mb, white, Vector3(fin_x - 0.15, total + 2.6, 0.0), Vector3(fin_x + 0.15, total + 3.2, 0.6))
	# --- awning over the shopfront (a striped skirt, clear of heads)
	if modern:
		_box(mb, white, Vector3(-hw - 0.4, 3.4, 0.0), Vector3(hw + 0.4, 3.62, 2.4))
	else:
		var stripe := _stripes(acc, Color("#fbfaf4"))
		_quad(mb, stripe, Vector3(-hw, 2.9, 1.9), Vector3(hw, 2.9, 1.9), Vector3(hw, 3.5, 0.0), Vector3(-hw, 3.5, 0.0), 0.5)
	# --- interior
	_interior(mb, body, hw, d, xd, kind, rng, acc)
	# ceiling lamps
	for lx in [-hw * 0.5, hw * 0.5]:
		_box(mb, _lamp_mat, Vector3(lx - 0.7, H0 - 0.3, -d * 0.5 - 0.25), Vector3(lx + 0.7, H0 - 0.25, -d * 0.5 + 0.25), 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _finish(mb)
	mi.visibility_range_end = 700.0
	root.add_child(mi)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, H0 - 0.8, -d * 0.5)
	lamp.omni_range = maxf(w, d) * 0.9
	lamp.light_color = Color(1.0, 0.88, 0.7)
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 50.0
	lamp.distance_fade_length = 25.0
	root.add_child(lamp)
	CityLights.register_light(lamp, 1.3)
	# door
	var door := AutoDoor.new()
	door.position = Vector3(xd, 0.0, -tk * 0.5)
	root.add_child(door)
	door.setup(dw, 2.7, _door_glass(), _flat(Color("#2b2f36"), 0.4, 0.6))
	doors += 1
	# signs: the hotel name on the roof, the shop name over the door
	var t: String = title if title != "" else String(NAMES[rng.randi() % NAMES.size()])
	var shop: String = String(SHOP_NAMES[rng.randi() % SHOP_NAMES.size()]) if kind != "lobby" else "HOTEL"
	var neon_cols := [Color("#ff4fa3"), Color("#25e6e0"), Color("#ffd23f"), Color("#b388ff")]
	var nc: Color = neon_cols[rng.randi() % neon_cols.size()]
	if not modern:
		_neon_label(root, t, Vector3(fin_x * -0.3, total + 1.0, 0.45), nc, 0.014 * clampf(w / 18.0, 0.8, 1.2), "monoton")
		_neon_label(root, shop, Vector3(xd, 3.05, 0.35), Color("#fff4d6"), 0.0065, "righteous")
	var neon_light := OmniLight3D.new()
	neon_light.position = Vector3(0, total + 1.0, 2.5)
	neon_light.light_color = nc
	neon_light.omni_range = 18.0
	neon_light.distance_fade_enabled = true
	neon_light.distance_fade_begin = 70.0
	neon_light.distance_fade_length = 30.0
	if not modern:
		root.add_child(neon_light)
		CityLights.register_light(neon_light, 2.5)
	else:
		neon_light.free()
	buildings += 1
	if "--miamidbg" in OS.get_cmdline_user_args(): print("MIAMIDBG ", kind, " front ", front, " yaw ", yaw, " door_x ", xd, " w ", w, " d ", d)
	return true

static var _door_glass_mat: StandardMaterial3D
static func _door_glass() -> StandardMaterial3D:
	if _door_glass_mat == null:
		_door_glass_mat = StandardMaterial3D.new()
		_door_glass_mat.albedo_color = Color(0.7, 0.9, 1.0, 0.28)
		_door_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_door_glass_mat.roughness = 0.05
		_door_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _door_glass_mat

## Furniture of the ground floor, off to the sides so the way in from the door stays free.
static func _interior(mb: Dictionary, body: StaticBody3D, hw: float, d: float, xd: float, kind: String, rng: RandomNumberGenerator, acc: Color) -> void:
	var wood := _flat(Color("#8a5a33"), 0.6)
	var dark := _flat(Color("#2a2d33"), 0.5, 0.3)
	var fabric := _flat(acc.darkened(0.1), 0.9)
	var white := _flat(Color("#f4f1ea"), 0.6)
	var zb := -d + 0.3                      # back wall's inner face
	match kind:
		"living":
			# open-plan living: a sofa group and TV wall on one side, a dining table and kitchen island on the other
			var sx3: float = -hw + 2.8 if xd > 0.0 else hw - 2.8
			_box(mb, fabric, Vector3(sx3 - 1.6, 0.04, -d * 0.45 - 0.5), Vector3(sx3 + 1.6, 0.5, -d * 0.45 + 0.5))
			_box(mb, fabric, Vector3(sx3 - 1.6, 0.5, -d * 0.45 - 0.6), Vector3(sx3 + 1.6, 1.0, -d * 0.45 - 0.35))
			_cb(body, Vector3(sx3 - 1.6, 0.04, -d * 0.45 - 0.6), Vector3(sx3 + 1.6, 1.0, -d * 0.45 + 0.5))
			_box(mb, dark, Vector3(sx3 - 1.2, 0.9, zb), Vector3(sx3 + 1.2, 2.0, zb + 0.12), 1.0)
			_box(mb, white, Vector3(sx3 - 0.9, 0.04, -d * 0.45 + 1.4), Vector3(sx3 + 0.9, 0.42, -d * 0.45 + 2.2))
			var kx: float = hw - 3.0 if xd > 0.0 else -hw + 3.0
			_box(mb, white, Vector3(kx - 1.8, 0.04, zb + 1.2), Vector3(kx + 1.8, 1.05, zb + 2.2))
			_cb(body, Vector3(kx - 1.8, 0.04, zb + 1.2), Vector3(kx + 1.8, 1.05, zb + 2.2))
			_box(mb, wood, Vector3(kx - 1.8, 1.05, zb + 1.15), Vector3(kx + 1.8, 1.1, zb + 2.25))
			_box(mb, wood, Vector3(kx - 1.0, 0.04, -d * 0.5 + 0.5), Vector3(kx + 1.0, 0.76, -d * 0.5 + 2.1))
			_cb(body, Vector3(kx - 1.0, 0.04, -d * 0.5 + 0.5), Vector3(kx + 1.0, 0.76, -d * 0.5 + 2.1))
			for px in [-hw + 0.8, hw - 0.8]:
				_box(mb, _flat(Color("#3b8f4b"), 0.9), Vector3(px - 0.35, 0.04, -1.8), Vector3(px + 0.35, 1.4, -1.1))
		"cafe", "bar":
			# a long counter along the back wall with a shelf of bottles above it, stools in front
			_box(mb, wood, Vector3(-hw + 1.2, 0.04, zb + 0.6), Vector3(hw - 1.2, 1.1, zb + 1.5))
			_cb(body, Vector3(-hw + 1.2, 0.04, zb + 0.6), Vector3(hw - 1.2, 1.1, zb + 1.5))
			_box(mb, dark, Vector3(-hw + 1.2, 1.1, zb + 0.55), Vector3(hw - 1.2, 1.16, zb + 1.55))
			_box(mb, dark, Vector3(-hw + 1.5, 1.7, zb), Vector3(hw - 1.5, 1.75, zb + 0.4))
			for k in range(int((hw * 2.0 - 3.0) / 0.5)):
				_box(mb, _flat(Color.from_hsv(rng.randf(), 0.6, 0.8), 0.3), Vector3(-hw + 1.6 + k * 0.5, 1.75, zb + 0.1), Vector3(-hw + 1.78 + k * 0.5, 2.1, zb + 0.28))
			for k in range(int((hw * 2.0 - 4.0) / 1.4)):
				var sx := -hw + 2.2 + k * 1.4
				if absf(sx - xd) < 1.6: continue
				_box(mb, fabric, Vector3(sx - 0.22, 0.04, zb + 2.0), Vector3(sx + 0.22, 0.7, zb + 2.44))
				_cb(body, Vector3(sx - 0.22, 0.04, zb + 2.0), Vector3(sx + 0.22, 0.7, zb + 2.44))
			for side in [-1.0, 1.0]:
				var tx: float = xd + side * (hw * 0.5)
				if absf(tx) > hw - 1.5: tx = side * (hw - 1.6)
				_box(mb, white, Vector3(tx - 0.5, 0.74, -d * 0.5 - 0.5), Vector3(tx + 0.5, 0.8, -d * 0.5 + 0.5))
				_box(mb, dark, Vector3(tx - 0.06, 0.04, -d * 0.5 - 0.06), Vector3(tx + 0.06, 0.74, -d * 0.5 + 0.06))
				_cb(body, Vector3(tx - 0.5, 0.04, -d * 0.5 - 0.5), Vector3(tx + 0.5, 0.8, -d * 0.5 + 0.5))
				for sz in [-0.8, 0.8]:
					_box(mb, fabric, Vector3(tx - 0.2, 0.04, -d * 0.5 + sz - 0.2), Vector3(tx + 0.2, 0.5, -d * 0.5 + sz + 0.2))
		"shop":
			for side in [-1.0, 1.0]:
				var sx: float = side * (hw - 0.3 - 0.3)
				_box(mb, wood, Vector3(sx - 0.3, 0.04, zb + 1.0), Vector3(sx + 0.3, 2.2, -2.2))
				_cb(body, Vector3(sx - 0.3, 0.04, zb + 1.0), Vector3(sx + 0.3, 2.2, -2.2))
				for sh in range(4):
					_box(mb, fabric if sh % 2 == 0 else white, Vector3(sx - 0.28, 0.4 + sh * 0.5, zb + 1.1), Vector3(sx + 0.28, 0.55 + sh * 0.5, -2.3))
			_box(mb, dark, Vector3(-1.2, 0.04, zb + 0.6), Vector3(1.2, 1.05, zb + 1.3))
			_cb(body, Vector3(-1.2, 0.04, zb + 0.6), Vector3(1.2, 1.05, zb + 1.3))
			_box(mb, white, Vector3(-hw + 1.0, 0.04, zb + 0.5), Vector3(-hw + 1.4, 2.0, zb + 1.0))
		_:
			# lobby: reception desk across the back, a sofa and plants at the sides, lift doors on the back wall
			_box(mb, wood, Vector3(-2.2, 0.04, zb + 1.2), Vector3(2.2, 1.1, zb + 2.0))
			_cb(body, Vector3(-2.2, 0.04, zb + 1.2), Vector3(2.2, 1.1, zb + 2.0))
			_box(mb, dark, Vector3(-2.3, 1.1, zb + 1.15), Vector3(2.3, 1.16, zb + 2.05))
			_box(mb, dark, Vector3(hw - 2.2, 0.04, zb), Vector3(hw - 0.4, 2.6, zb + 0.1), 1.0)
			_box(mb, _flat(Color("#9aa3ad"), 0.3, 0.7), Vector3(hw - 2.0, 0.04, zb + 0.1), Vector3(hw - 0.6, 2.4, zb + 0.14), 1.0)
			var sx2: float = -hw + 2.0 if xd > 0.0 else hw - 2.0
			_box(mb, fabric, Vector3(sx2 - 1.2, 0.04, -d * 0.5 - 0.5), Vector3(sx2 + 1.2, 0.5, -d * 0.5 + 0.5))
			_box(mb, fabric, Vector3(sx2 - 1.2, 0.5, -d * 0.5 - 0.6), Vector3(sx2 + 1.2, 1.0, -d * 0.5 - 0.35))
			_cb(body, Vector3(sx2 - 1.2, 0.04, -d * 0.5 - 0.6), Vector3(sx2 + 1.2, 1.0, -d * 0.5 + 0.5))
			for px in [-hw + 0.9, hw - 0.9]:
				_box(mb, _flat(Color("#3b8f4b"), 0.9), Vector3(px - 0.35, 0.04, -1.6), Vector3(px + 0.35, 1.3, -0.9))
				_cb(body, Vector3(px - 0.35, 0.04, -1.6), Vector3(px + 0.35, 1.3, -0.9))

# ------------------------------------------------------------------ ponds, pools, lawns

## Canals, ponds and lakes use the sea's own water shader, so their colour matches the sea; only swimming pools get a bright pool blue.
static func _water_mat(pool := false) -> Material:
	if not pool and Coast.sea_mat != null:
		if _inland_water == null:
			# the sea's own shader and colours, but with the ripples drifting very slowly and no waves: calm canal / lagoon water
			_inland_water = Coast.sea_mat.duplicate() as ShaderMaterial
			_inland_water.set_shader_parameter("flow", 0.1)
			_inland_water.set_shader_parameter("wave_amp", 0.0)
			_inland_water.set_shader_parameter("depth_scale", 0.1)
			_inland_water.set_shader_parameter("foam_amount", 0.0)
			_inland_water.set_shader_parameter("surf", 0.0)
			Coast.extra_water_mats.append(_inland_water)
			CityLights.register(_inland_water)
		return _inland_water
	var k := "water|%s" % pool
	if _mats.has(k): return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.62, 0.72, 0.78) if pool else Color(0.08, 0.5, 0.52, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04
	m.metallic = 0.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.normal_enabled = true
	m.normal_texture = load("res://assets/coast/ocean_tile_normal.png") as Texture2D
	m.normal_scale = 0.35
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * (0.25 if pool else 0.12)
	if pool:
		CityLights.register_material(m, Color(0.2, 0.9, 1.0), 0.8)      # the pool lights come on at night
	_mats[k] = m
	return m

## A flat disc / ellipse of water-level at height y.
static func _disc(mb: Dictionary, mat: Material, ctr: Vector2, rx: float, rz: float, y: float, seg := 32) -> void:
	for k in range(seg):
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var c3 := Vector3(ctr.x, y, ctr.y)
		var p0 := Vector3(ctr.x + cos(a0) * rx, y, ctr.y + sin(a0) * rz)
		var p1 := Vector3(ctr.x + cos(a1) * rx, y, ctr.y + sin(a1) * rz)
		# counter-clockwise seen from above: centre, p1, p0 mirrored ... (quad degenerate on the centre)
		_quad(mb, mat, c3, p0, p1, c3, 0.2)

## A raised ornamental pond: stone rim, a shallow dark bed, translucent water, lilies and rocks. The rim is solid; the water inside is
## ankle deep, so it can be waded through without falling anywhere.
static func _lawn(c: Dictionary, r: Rect2) -> void:
	var lawn: StandardMaterial3D = (c.w as World)._mat("res://assets/textures/y2k_grass.png", 0.2, Color(0.8, 1.0, 0.65))
	_slab(c, r, PY, PY + 0.03, lawn, false)

static func _paving(c: Dictionary, r: Rect2, kind := "walk") -> void:
	var mat: Material = _surface_mat("walk", "PavingStones136", 0.5, Color(1.15, 1.1, 1.0), 0.85) if kind == "walk" else _surface_mat("hex", "PavingStones130", 0.45, Color(1.1, 1.0, 1.0), 0.85)
	_slab(c, r, PY, PY + 0.04, mat, false)

# ------------------------------------------------------------------ rows of buildings

## Buildings side by side along a front line from a to b (world x, z); they face `yaw` and are all `depth` deep.
static func _row(c: Dictionary, a: Vector2, b: Vector2, yaw: float, depth: float, rng: RandomNumberGenerator, arcade_at := -1.0, hotel_bias := 0.3) -> int:
	var dir := (b - a)
	var length := dir.length()
	dir = dir.normalized()
	var pos := 0.0
	var n := 0
	while pos < length - 12.0:
		var w := rng.randf_range(15.0, 23.0)
		if pos + w > length: w = length - pos
		if w < 12.0: break
		if arcade_at >= 0.0 and pos < arcade_at and pos + w + 1.0 > arcade_at:
			pos = arcade_at + 8.0                          # a gap through the block: an alley into the courtyard
			continue
		var floors := 3 + rng.randi() % 3
		var roll := rng.randf()
		var kind := "lobby" if roll < hotel_bias else ("cafe" if roll < hotel_bias + 0.3 else ("shop" if roll < hotel_bias + 0.55 else "bar"))
		var centre := a + dir * (pos + w * 0.5)
		if _building(c, centre, yaw, w, depth, floors, kind, rng): n += 1
		pos += w + 1.2
	return n

# ------------------------------------------------------------------ blocks

static func _street_furniture(c: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var off := 1.9                                                 # from the kerb
	var edges := [[Vector2(r.position.x + 8.0, r.position.y + off), Vector2(r.end.x - 8.0, r.position.y + off), 0.0],
		[Vector2(r.position.x + 8.0, r.end.y - off), Vector2(r.end.x - 8.0, r.end.y - off), PI],
		[Vector2(r.position.x + off, r.position.y + 8.0), Vector2(r.position.x + off, r.end.y - 8.0), PI * 0.5],
		[Vector2(r.end.x - off, r.position.y + 8.0), Vector2(r.end.x - off, r.end.y - 8.0), -PI * 0.5]]
	var idx := 0
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var len := a.distance_to(b)
		var t := 6.0 + rng.randf_range(0.0, 4.0)
		while t < len - 6.0:
			var p := a + (b - a).normalized() * t
			if not _overlaps_reserved(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5))):
				var roll := (idx + int(t / 13.0)) % 6
				if roll == 0 or roll == 3:
					_palm(body, p, rng, "t" if roll == 0 else "m")
				elif roll == 1:
					_put("bench", Vector3(p.x, PY, p.y), float(e[2]) + PI, 1.0)
				elif roll == 2:
					_put("meter", Vector3(p.x, PY, p.y), float(e[2]), 1.0)
				elif roll == 4 and rng.randf() < 0.5:
					_put("bins", Vector3(p.x, PY, p.y), float(e[2]), 1.0)
				elif roll == 5 and rng.randf() < 0.4:
					_put("mailbox", Vector3(p.x, PY, p.y), float(e[2]), 1.0)
			t += 13.0
			idx += 1

## A courtyard garden: lawn, paved paths, a big pond with a stone fountain-less island of palms, benches, cafes and ice cream carts.
static func _courtyard(c: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	_lawn(c, r)
	var cx := r.position.x + r.size.x * 0.5
	var cz := r.position.y + r.size.y * 0.5
	# a paved promenade round the garden and two crossing paths
	_paving(c, Rect2(r.position.x, r.position.y, r.size.x, 3.0), "hex")
	_paving(c, Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), "hex")
	_paving(c, Rect2(r.position.x, r.position.y, 3.0, r.size.y), "hex")
	_paving(c, Rect2(r.end.x - 3.0, r.position.y, 3.0, r.size.y), "hex")
	_paving(c, Rect2(cx - 2.5, r.position.y, 5.0, r.size.y), "hex")
	_paving(c, Rect2(r.position.x, cz - 2.5, r.size.x, 5.0), "hex")
	var sites := tower_sites(r)
	var blocked: Array = []
	for st in sites:
		blocked.append(tower_rect(st).grow(2.0))
		_tower(c, st, rng)
	if not sites.is_empty():
		_tower_parking(c, r, rng)
		blocked.append(parking_rect(r).grow(2.0))
	# palms round the four ponds (the ponds themselves are carved into the ground by MiamiParks)
	for pnd in courtyard_ponds(r):
		var pc: Vector2 = pnd.c
		var pr := Vector2(pnd.rx, pnd.rz)
		for a2 in range(7):
			var ang := TAU * a2 / 7.0 + rng.randf() * 0.4
			var pp := pc + Vector2(cos(ang) * (pr.x + 6.0), sin(ang) * (pr.y + 6.0))
			if r.has_point(pp) and not _overlaps_reserved(Rect2(pp - Vector2(2, 2), Vector2(4, 4))):
				_palm(body, pp, rng, "t" if a2 % 2 == 0 else "m")
	# benches along the cross paths, ice cream carts, cafes at the junction
	var free := func(p: Vector2) -> bool:
		for b in blocked:
			if (b as Rect2).has_point(p): return false
		return true
	for sgn in [-1.0, 1.0]:
		for t in [-0.7, -0.35, 0.35, 0.7]:
			var bp1 := Vector2(cx + sgn * 3.6, cz + t * r.size.y * 0.5)
			var bp2 := Vector2(cx + t * r.size.x * 0.5, cz + sgn * 3.6)
			if free.call(bp1): _put("bench", Vector3(bp1.x, PY + 0.04, bp1.y), PI * 0.5 * sgn, 1.0)
			if free.call(bp2): _put("bench", Vector3(bp2.x, PY + 0.04, bp2.y), 0.0 if sgn > 0 else PI, 1.0)
	if sites.is_empty():
		_put("icecream", Vector3(cx + 6.0, PY + 0.04, cz + 6.0), 0.5, 1.0)
		_put("icecream", Vector3(cx - 6.0, PY + 0.04, cz - 6.0), 3.6, 1.0)
		CoastProps._box(body, Vector3(1.4, 2.4, 2.2), Vector3(cx + 6.0, PY + 1.2, cz + 6.0))
		CoastProps._box(body, Vector3(1.4, 2.4, 2.2), Vector3(cx - 6.0, PY + 1.2, cz - 6.0))

## A tower standing on a paved plaza, with a glass lobby annex on one side (a real walk-in lobby with a sliding door).
static func _tower(c: Dictionary, site: Dictionary, rng: RandomNumberGenerator) -> void:
	var pr: Dictionary = _props.get(String(site.key), {})
	if pr.is_empty(): return
	var p: Vector2 = site.pos
	var f: float = site.face
	var sz: Vector3 = pr.size
	var plaza := Rect2(p.x - sz.x * 0.5 - 6.0, p.y - sz.z * 0.5 - (6.0 if f > 0.0 else ANNEX_D + 6.0), sz.x + 12.0, sz.z + ANNEX_D + 12.0)
	_paving(c, plaza, "hex")
	_put(String(site.key), Vector3(p.x, PY, p.y), 0.0, 1.0)
	# the annex: front towards the courtyard, backed against the tower's side
	var front_z: float = (p.y + sz.z * 0.5 + ANNEX_D) if f > 0.0 else (p.y - sz.z * 0.5 - ANNEX_D)
	var yaw := 0.0 if f > 0.0 else PI
	var names := ["THE VIZCAYNE", "RIVIERA TOWER", "BAYSIDE PLAZA", "CORAL TOWER", "SKYLINE CENTRE"]
	var nm: String = "THE VIZCAYNE" if String(site.key) == "tower_viz" else String(names[1 + rng.randi() % 4])
	_building(c, Vector2(p.x, front_z), yaw, ANNEX_W, ANNEX_D, 2, "lobby", rng, nm)

## The car park: asphalt with painted bays in two rows round a central aisle, kerbs, a drive out through the gap in the buildings to the
## street, lamps, and cars parked in about half the bays.
static func _tower_parking(c: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var lot := parking_rect(r)
	if lot.size == Vector2.ZERO: return
	var w: World = c.w
	var body: StaticBody3D = c.body
	var asphalt := _flat(Color("#2c2c30"), 0.9)
	var line := _flat(Color("#f0eee4"), 0.8)
	var kerb := _flat(Color("#c2bfb8"), 0.85)
	var py := PY + 0.06
	var north := lot.position.y < r.get_center().y
	var cx := r.get_center().x
	var mb := {}
	# the lot and the drive to the street (the gap in the building row is round the courtyard's centre line)
	var drive := Rect2(cx - 6.0, (r.position.y - 23.0) if north else lot.end.y, 12.0, (lot.position.y - r.position.y + 23.0) if north else (r.end.y + 23.0 - lot.end.y))
	for rc in [lot, drive]:
		var rr: Rect2 = rc
		_box(mb, asphalt, Vector3(rr.position.x, 0.0, rr.position.y), Vector3(rr.end.x, py, rr.end.y), 0.1)
		_cb(body, Vector3(rr.position.x, 0.0, rr.position.y), Vector3(rr.end.x, py, rr.end.y))
	# kerbs: round the lot except where the drive meets it
	var kh := 0.18
	var drive_x0 := cx - 6.0
	var drive_x1 := cx + 6.0
	var edge_z := lot.position.y if north else lot.end.y
	var far_z := lot.end.y if north else lot.position.y
	for kz in [[far_z - 0.15, far_z + 0.15]]:
		_box(mb, kerb, Vector3(lot.position.x, py, minf(kz[0], kz[1])), Vector3(lot.end.x, py + kh, maxf(kz[0], kz[1])))
	for kx in [lot.position.x, lot.end.x - 0.3]:
		_box(mb, kerb, Vector3(kx, py, lot.position.y), Vector3(kx + 0.3, py + kh, lot.end.y))
	for seg in [[lot.position.x, drive_x0], [drive_x1, lot.end.x]]:
		_box(mb, kerb, Vector3(seg[0], py, edge_z - 0.15), Vector3(seg[1], py + kh, edge_z + 0.15))
	# bays: a row along each long edge of the lot, nose to the kerb, the aisle between them
	var bay_w := 3.0
	var bay_d := 5.2
	var nb := int(floor((lot.size.x - 4.0) / bay_w))
	var x_start := lot.position.x + (lot.size.x - nb * bay_w) * 0.5
	var row_z := [lot.position.y + 0.3, lot.end.y - 0.3 - bay_d]
	for ri in range(2):
		var z0: float = row_z[ri]
		for b in range(nb + 1):
			var bx := x_start + b * bay_w
			_box(mb, line, Vector3(bx - 0.06, py, z0), Vector3(bx + 0.06, py + 0.012, z0 + bay_d))
		_box(mb, line, Vector3(x_start, py, z0 + (0.0 if ri == 1 else bay_d) - 0.06), Vector3(x_start + nb * bay_w, py + 0.012, z0 + (0.0 if ri == 1 else bay_d) + 0.06))
	var mi := MeshInstance3D.new()
	mi.mesh = _finish(mb)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)
	# cars: about a third of the bays, never in front of the drive; each nose to the kerb
	var kinds := ["fumi", "taxi", "saloon"]
	for ri in range(2):
		var z0: float = row_z[ri]
		for b in range(nb):
			var bx := x_start + b * bay_w + bay_w * 0.5
			if absf(bx - cx) < 8.0: continue
			if rng.randf() > 0.35: continue
			var car := Car.new()
			car.position = Vector3(bx, py + Car.RIDE + 0.12, z0 + bay_d * 0.5)
			car.rotation.y = PI if ri == 0 else 0.0                  # nose toward the nearest long edge
			w.add_child(car)
			car.setup(kinds[rng.randi() % kinds.size()], "", true)
	# lamps along the car park's back edge
	for k in range(3):
		var lx := lot.position.x + 12.0 + k * ((lot.size.x - 24.0) / 2.0)
		var lm := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.16, 5.0, 0.16)
		lm.mesh = lb
		lm.material_override = _flat(Color("#3b4048"), 0.5, 0.6)
		lm.position = Vector3(lx, py + 2.5, far_z)
		w.static_root.add_child(lm)
		var hd := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.6, 0.15, 0.3)
		hd.mesh = hb
		hd.material_override = _lamp_mat
		hd.position = Vector3(lx, py + 5.0, far_z)
		hd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(hd)
		CoastProps._box(body, Vector3(0.3, 5.0, 0.3), Vector3(lx, py + 2.5, far_z))

## A modern waterfront estate: wall and gate on the street, drive, a modern house with a walk-in living room, pool and a pond garden.
static func _estate(c: Dictionary, front: Vector2, yaw: float, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var body: StaticBody3D = c.body
	var f := Vector2(sin(yaw), cos(yaw))
	var rt := Vector2(f.y, -f.x)
	# local (lx, lz) with lz negative into the lot -> world
	var wp := func(lx: float, lz: float) -> Vector2: return front + rt * lx + f * lz
	var wall_mat := _plaster(Color("#faf6ee"))
	var hedge_mat := _flat(Color("#2f7d3a"), 0.95)
	var mb := {}
	var rot := Basis(Vector3.UP, yaw)
	var root := Node3D.new()
	root.position = Vector3(front.x, PY, front.y)
	root.rotation.y = yaw
	(c.w as World).static_root.add_child(root)
	var eb := StaticBody3D.new()
	eb.collision_layer = 1
	root.add_child(eb)
	var hw := w * 0.5
	var gate := 8.0
	var info := estate_info(front, yaw, w, d)
	var gate_x: float = info.gate_x
	# the street wall with a gate gap, pillars each side; hedges on the other three sides
	for seg in [[-hw, gate_x - gate * 0.5], [gate_x + gate * 0.5, hw]]:
		var a: float = seg[0]
		var b: float = seg[1]
		if b - a > 0.5:
			_box(mb, wall_mat, Vector3(a, 0.0, -0.6), Vector3(b, 1.3, 0.0))
			_cb(eb, Vector3(a, 0.0, -0.6), Vector3(b, 1.3, 0.0))
	for px in [gate_x - gate * 0.5, gate_x + gate * 0.5]:
		_box(mb, wall_mat, Vector3(px - 0.5, 0.0, -0.9), Vector3(px + 0.5, 2.0, 0.1))
		_box(mb, _lamp_mat, Vector3(px - 0.25, 2.0, -0.65), Vector3(px + 0.25, 2.4, -0.15), 1.0)
		_cb(eb, Vector3(px - 0.5, 0.0, -0.9), Vector3(px + 0.5, 2.0, 0.1))
	for hseg in [[Vector3(-hw, 0.0, -d), Vector3(hw, 1.6, -d + 0.8)], [Vector3(-hw, 0.0, -d + 0.8), Vector3(-hw + 0.8, 1.6, -0.6)], [Vector3(hw - 0.8, 0.0, -d + 0.8), Vector3(hw, 1.6, -0.6)]]:
		_box(mb, hedge_mat, hseg[0], hseg[1], 0.6)
		_cb(eb, hseg[0], hseg[1])
	var mi := MeshInstance3D.new()
	mi.mesh = _finish(mb)
	root.add_child(mi)
	# drive and the house
	var drive_w := 6.0
	var house_w := 22.0
	var house_d := 14.0
	var house_z := 24.0
	var hx := gate_x
	hx = clampf(hx, -hw + house_w * 0.5 + 6.0, hw - house_w * 0.5 - 6.0)
	var dr: Vector2 = wp.call(gate_x, -(house_z + 1.0))
	var dr2: Vector2 = wp.call(gate_x, 0.0)
	var drive := Rect2(minf(dr.x, dr2.x) - drive_w * 0.5, minf(dr.y, dr2.y) - drive_w * 0.5, absf(dr.x - dr2.x) + drive_w, absf(dr.y - dr2.y) + drive_w)
	if absf(f.x) > 0.5:
		drive = Rect2(minf(dr.x, dr2.x), minf(dr.y, dr2.y) - drive_w * 0.5, absf(dr.x - dr2.x), drive_w)
	else:
		drive = Rect2(minf(dr.x, dr2.x) - drive_w * 0.5, minf(dr.y, dr2.y), drive_w, absf(dr.y - dr2.y))
	_paving(c, drive, "walk")
	var house_front: Vector2 = wp.call(hx, -house_z)
	_building(c, house_front, yaw, house_w, house_d, 2, "living", rng, "", "modern")
	_lawn(c, _local_rect(front, yaw, w, d))
	MiamiFill.estate_extras(c, front, yaw, info, rng)
	var pc: Vector2 = info.pond_c
	var pool_c: Vector2 = info.pool_c
	var deck := Rect2(pool_c - Vector2(14.0, 10.0), Vector2(28.0, 20.0))
	for k in range(9):
		var lp: Vector2 = wp.call(rng.randf_range(-hw + 3.0, hw - 3.0), -rng.randf_range(5.0, d - 4.0))
		if _overlaps_reserved(Rect2(lp - Vector2(2, 2), Vector2(4, 4))): continue
		if Rect2(drive).grow(2.0).has_point(lp) or deck.grow(2.5).has_point(lp) or _local_rect(house_front, yaw, house_w + 4.0, house_d + 4.0).has_point(lp): continue
		if lp.distance_to(pc) < 19.0: continue
		var in_extra := false
		for ex in info.extras:
			if (ex as Rect2).grow(3.0).has_point(lp): in_extra = true
		if in_extra: continue
		_palm(body, lp, rng, "t" if k % 3 else "m")

## Where everything in an estate goes (deterministic, so MiamiParks can carve its pool and pond into the ground before the estate is built).
static func estate_info(front: Vector2, yaw: float, w: float, d: float) -> Dictionary:
	var f := Vector2(sin(yaw), cos(yaw))
	var rt := Vector2(f.y, -f.x)
	var hw := w * 0.5
	var gate_x := (_hash(front.x, front.y, 3.0) - 0.5) * (w * 0.4)
	var hx := clampf(gate_x, -hw + 22.0 * 0.5 + 6.0, hw - 22.0 * 0.5 - 6.0)
	var pool_c := front + rt * hx + f * -(24.0 + 14.0 + 11.0)
	var pond_c := front + rt * (-hw * 0.4) + f * -(d - 16.0)
	var wpx := func(lx: float, lz: float) -> Vector2: return front + rt * lx + f * lz
	var guest_lx := (-hw + 14.0) if hx >= 0.0 else (hw - 14.0)
	var has_court := (int(floor(front.x / 10.0)) + int(floor(front.y / 10.0))) % 2 == 0
	var extras: Array = []
	var ga: Vector2 = wpx.call(guest_lx - 6.5, -10.0)
	var gb: Vector2 = wpx.call(guest_lx + 6.5, -20.0)
	extras.append(Rect2(minf(ga.x, gb.x), minf(ga.y, gb.y), absf(ga.x - gb.x), absf(ga.y - gb.y)))
	var court_c: Vector2 = wpx.call(hx, -80.0)
	var pad_c: Vector2 = wpx.call(0.0, -92.0)
	if has_court: extras.append(Rect2(court_c - Vector2(21.0, 15.0), Vector2(42.0, 30.0)))
	else: extras.append(Rect2(pad_c - Vector2(11.0, 11.0), Vector2(22.0, 22.0)))
	return {"extras": extras, "guest": wpx.call(guest_lx, -10.0), "court": has_court, "court_c": court_c, "pad_c": pad_c, "gate_x": gate_x, "hx": hx, "pool_c": pool_c, "pool_r": Vector2(8.5, 5.0), "pond_c": pond_c, "pond_r": Vector2(12.0, 8.0)}

## The towers standing in a courtyard of the middle blocks: [{key, pos (centre of the footprint, world x z), face (+1 annex to the south, -1 to the north)}].
static func tower_sites(r: Rect2) -> Array:
	var c := r.get_center()
	var east := c.x > 200.0
	var south := c.y > 2200.0
	if c.x < 0.0 or c.x > 400.0: return []
	if not east and not south: return [{"key": "tower_viz", "pos": Vector2(100.0, 2085.0), "face": 1.0}]
	if east and not south: return [{"key": "tower_low", "pos": Vector2(300.0, 2088.0), "face": 1.0}]
	if not east and south: return [{"key": "tower_mid", "pos": Vector2(60.0, 2300.0), "face": -1.0}, {"key": "tower_mid", "pos": Vector2(140.0, 2300.0), "face": -1.0}]
	return [{"key": "tower_mid", "pos": Vector2(300.0, 2325.0), "face": -1.0}]

const ANNEX_D := 10.0
const ANNEX_W := 22.0

## Footprint of a tower together with its lobby annex, as a world rectangle.
static func tower_rect(site: Dictionary) -> Rect2:
	var pr: Dictionary = _props.get(String(site.key), {})
	var sz: Vector3 = pr.size if not pr.is_empty() else Vector3(40.0, 40.0, 40.0)
	var p: Vector2 = site.pos
	var f: float = site.face
	var r := Rect2(p.x - sz.x * 0.5, p.y - sz.z * 0.5, sz.x, sz.z)
	if f > 0.0: r.size.y += ANNEX_D
	else:
		r.position.y -= ANNEX_D
		r.size.y += ANNEX_D
	return r

## The visitors' car park of a tower courtyard: a strip along the north or south end of the court (the end that has a gap through
## the row of buildings to the street), 18 m deep, full width. {} when the court has no towers.
static func parking_rect(r: Rect2) -> Rect2:
	var sites := tower_sites(r)
	if sites.is_empty(): return Rect2()
	var c := r.get_center()
	var south_end: bool = c.x > 200.0 and c.y > 2200.0                   # the south-east court has no north gap
	var y: float = (r.end.y - 21.0) if south_end else (r.position.y + 3.0)
	return Rect2(r.position.x + 8.0, y, r.size.x - 16.0, 18.0)

## The ponds of a courtyard (centre, radii): four candidate spots, those that would touch a tower or its annex are dropped.
static func courtyard_ponds(r: Rect2) -> Array:
	var out: Array = []
	var cx := r.position.x + r.size.x * 0.5
	var cz := r.position.y + r.size.y * 0.5
	var qx := r.size.x * 0.25
	var qz := r.size.y * 0.25
	var sites := tower_sites(r)
	var cand: Array = []
	for sg in [-1.0, 1.0]:
		cand.append(Vector2(cx + sg * qx, cz + sg * qz))
	if not sites.is_empty():
		for sg in [-1.0, 1.0]:
			cand.append(Vector2(cx + sg * qx, cz - sg * qz))
			cand.append(Vector2(cx + sg * qx, r.position.y + 19.0))                # the garden strips beside the towers
			cand.append(Vector2(cx + sg * qx, r.end.y - 19.0))
	for pcn in cand:
		var rx := minf(qx * 0.7, 22.0)
		var rz := minf(qz * 0.6, 15.0) if absf(pcn.y - cz) > 0.0 and (pcn.y - r.position.y) > 25.0 and (r.end.y - pcn.y) > 25.0 else 11.0
		var box := Rect2(pcn - Vector2(rx, rz), Vector2(rx, rz) * 2.0)
		var hit := false
		for st in sites:
			if tower_rect(st).grow(3.0).intersects(box): hit = true
		var pk := parking_rect(r)
		if pk.size != Vector2.ZERO and pk.grow(3.0).intersects(box): hit = true
		for o in out:
			var orc := Rect2((o.c as Vector2) - Vector2(o.rx, o.rz), Vector2(o.rx, o.rz) * 2.0)
			if orc.grow(4.0).intersects(box): hit = true
		if not hit: out.append({"c": pcn, "rx": rx, "rz": rz})
	return out.slice(0, 1)                        # one pond per courtyard is enough

## Every courtyard rectangle and estate of the island's blocks (the same numbers _block uses).
static func layout() -> Dictionary:
	var courts: Array = []
	var estates: Array = []
	for j in range(2):
		for i in range(4):
			var x0: float = XS[i] + KERB
			var x1: float = XS[i + 1] - KERB
			var z0: float = ZS[j] + KERB
			var z1: float = ZS[j + 1] - KERB
			match String(ROLES[j][i]):
				"deco":
					var depth := 20.0
					var cz0 := z0 + SW + depth + 3.0
					var cz1 := z1 - SW - depth - 3.0
					if i == 2 and j == 0:
						cz1 = 2132.0               # reserve south half for police & fire compounds
					elif i == 2 and j == 1:
						cz0 = 2270.0               # reserve north half for hospital compound
					courts.append(Rect2(x0 + SW + depth + 3.0, cz0, (x1 - x0) - 2.0 * (SW + depth + 3.0), cz1 - cz0))
				"plaza":
					courts.append(Rect2(x0 + SW, z0 + SW, (x1 - x0) - 2.0 * SW, (z1 - z0) - 2.0 * SW))
				"mansion":
					var m := 2.0
					var wlot := (x1 - x0 - 2.0 * SW) * 0.5 - m
					var dlot := (z1 - z0 - 2.0 * SW) * 0.5 - m
					estates.append({"front": Vector2(x0 + SW + m + wlot * 0.5, z0 + SW), "yaw": PI, "w": wlot, "d": dlot})
					estates.append({"front": Vector2(x1 - SW - m - wlot * 0.5, z0 + SW), "yaw": PI, "w": wlot, "d": dlot})
					estates.append({"front": Vector2(x0 + SW + m + wlot * 0.5, z1 - SW), "yaw": 0.0, "w": wlot, "d": dlot})
					estates.append({"front": Vector2(x1 - SW - m - wlot * 0.5, z1 - SW), "yaw": 0.0, "w": wlot, "d": dlot})
	return {"courts": courts, "estates": estates}

# ------------------------------------------------------------------ the island

static func _reserve_metro() -> void:
	reserved.clear()
	if Metro.L.is_empty(): return
	for k in ["a", "b"]:
		var st: Dictionary = Metro.L[k]
		if st.has("hole"):
			var h: Rect2 = st.hole
			if h.position.y > 1800.0:
				reserved.append(h.grow_individual(22.0, 14.0, 22.0, 24.0))
	for ko in MiamiParks.keepout: reserved.append(ko)
	for sh in Coast.shafts:
		var sr: Rect2 = sh
		if sr.position.y > 1800.0:
			reserved.append(sr.grow(3.0))
	# Redline Ammo - Island (shop + customer/rear parking lot)
	reserved.append(Rect2(82.0, 2170.0, 33.0, 26.0))
	# North Marina Parking Lot (shifted back with clear dock walkway)
	reserved.append(Rect2(112.0, 1916.0, 76.0, 30.0))
	# Island Plaza Metro Parking
	reserved.append(Rect2(14.0, 2412.0, 34.0, 35.0))
	# Island Police Station Compound
	reserved.append(Rect2(208.0, 2134.0, 84.0, 66.0))
	# Island Fire Station
	reserved.append(Rect2(294.0, 2134.0, 98.0, 66.0))
	# Island Hospital Compound
	reserved.append(Rect2(212.0, 2202.0, 106.0, 68.0))

static func _block(c: Dictionary, i: int, j: int, rng: RandomNumberGenerator) -> void:
	var x0: float = XS[i] + KERB
	var x1: float = XS[i + 1] - KERB
	var z0: float = ZS[j] + KERB
	var z1: float = ZS[j + 1] - KERB
	var R := Rect2(x0, z0, x1 - x0, z1 - z0)
	var pave := _surface_mat("walk", "PavingStones136", 0.5, Color(1.15, 1.1, 1.0), 0.85)
	_slab(c, R, 0.0, PY, pave)
	var role: String = ROLES[j][i]
	match role:
		"deco":
			var depth := 20.0
			# the ring of hotels, cafes and shops round the courtyard
			var n := 0
			if not (i == 2 and j == 1):
				n += _row(c, Vector2(x0 + SW + 2.0, z0 + SW), Vector2(x1 - SW - 2.0, z0 + SW), PI, depth, rng, (x1 - x0) * 0.5, 0.35)
			if not (i == 2 and j == 0):
				n += _row(c, Vector2(x0 + SW + 2.0, z1 - SW), Vector2(x1 - SW - 2.0, z1 - SW), 0.0, depth, rng, (x1 - x0) * 0.5, 0.35)
			n += _row(c, Vector2(x0 + SW, z0 + SW + depth + 2.0), Vector2(x0 + SW, z1 - SW - depth - 2.0), -PI * 0.5, depth, rng, -1.0, 0.1)
			n += _row(c, Vector2(x1 - SW, z0 + SW + depth + 2.0), Vector2(x1 - SW, z1 - SW - depth - 2.0), PI * 0.5, depth, rng, -1.0, 0.1)
			var cz0 := z0 + SW + depth + 3.0
			var cz1 := z1 - SW - depth - 3.0
			if i == 2 and j == 0:
				cz1 = 2132.0
			elif i == 2 and j == 1:
				cz0 = 2270.0
			var inner := Rect2(x0 + SW + depth + 3.0, cz0, (x1 - x0) - 2.0 * (SW + depth + 3.0), cz1 - cz0)
			_courtyard(c, inner, rng)
		"mansion":
			var hx := (x0 + x1) * 0.5
			var hz := (z0 + z1) * 0.5
			var m := 2.0
			var wlot := (x1 - x0 - 2.0 * SW) * 0.5 - m
			var dlot := (z1 - z0 - 2.0 * SW) * 0.5 - m
			_estate(c, Vector2(x0 + SW + m + wlot * 0.5, z0 + SW), PI, wlot, dlot, rng)
			_estate(c, Vector2(x1 - SW - m - wlot * 0.5, z0 + SW), PI, wlot, dlot, rng)
			_estate(c, Vector2(x0 + SW + m + wlot * 0.5, z1 - SW), 0.0, wlot, dlot, rng)
			_estate(c, Vector2(x1 - SW - m - wlot * 0.5, z1 - SW), 0.0, wlot, dlot, rng)
		"plaza":
			var inner2 := Rect2(x0 + SW, z0 + SW, (x1 - x0) - 2.0 * SW, (z1 - z0) - 2.0 * SW)
			_courtyard(c, inner2, rng)
	_street_furniture(c, R, rng)

## The context the boulevard code needs when nothing else is built: a body for collisions and the world.
static func null_c(w: World) -> Dictionary:
	var body := StaticBody3D.new()
	body.name = "MiamiRoads"
	body.collision_layer = 1
	w.static_root.add_child(body)
	solid_body = null
	return {"w": w, "body": body}

static func build(w: World) -> void:
	var t0 := Time.get_ticks_msec()
	buildings = 0
	doors = 0
	_batch.clear()
	if ROADS_ONLY:
		_boulevards(null_c(w), null)
		IslandBeach.build(w)
		BeachLife.build(w)
		IslandSkyscrapers.build(w)
		var tb := Time.get_ticks_msec()
		GolfClub.build(w)
		print("TIMING golf ", Time.get_ticks_msec() - tb, " ms")
		tb = Time.get_ticks_msec()
		MedicalDistrict.build(w)
		print("TIMING medical ", Time.get_ticks_msec() - tb, " ms")
		tb = Time.get_ticks_msec()
		EmergencyDistrict.build(w)
		print("TIMING emergency ", Time.get_ticks_msec() - tb, " ms")
		EmergencyDistrict.scatter_hydrants(w)
		print("miami: roads only + island skyscrapers + golf club + medical district")
		return
	_prep_props()
	_glass_mats()
	_reserve_metro()
	var body := StaticBody3D.new()
	body.name = "MiamiBody"
	body.collision_layer = 1
	w.static_root.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 305
	var c := {"w": w, "body": body}
	solid_body = body
	for j in range(2):
		for i in range(4):
			_block(c, i, j, rng)
	_boulevards(c, rng)
	MiamiParks.build(c)
	MiamiFill.build(c)

	# Redline Ammo - Island branch with customer & staff parking
	GunShop.build(w, body, 85.0, 2200.0 - KERB, PY)
	w.add_poi("gun_shop", "REDLINE AMMO - ISLAND", Vector3(85.0 + GunShop.W * 0.5, PY + 1.5, 2200.0 - KERB - GunShop.D * 0.5))

	# Dedicated public parking facilities on the island
	_build_island_parking(c, rng)

	# Island Emergency Services: Police Station, Fire Station & Hospital
	_build_island_emergency_services(c, rng)

	IslandSkyscrapers.build(w)
	GolfClub.build(w)
	MedicalDistrict.build(w)
	EmergencyDistrict.build(w)
	_flush(w)
	print("miami: %d buildings, %d doors (%d ms)" % [buildings, doors, Time.get_ticks_msec() - t0])

## Builds designated public parking lots on Redline Island:
## 1. North Marina Parking Lot (large lot serving the yacht marina, docks and boardwalk)
## 2. West Beach Scenic Turnout Parking (ocean-view angled bays along the west beachfront boulevard)
## 3. Island Plaza Metro Parking (transit parking serving the Island Plaza underground metro station)
static func _build_island_parking(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var w: World = c.w
	var body: StaticBody3D = c.body
	var asphalt := _flat(Color("#28282b"), 0.9)
	var kerb_mat := _flat(Color("#c2bfb8"), 0.85)
	var line_mat := _flat(Color("#f0eee4"), 0.8)
	var stop_mat := _flat(Color("#e0ded8"), 0.85)
	var mb := {}
	var kw := 0.28
	var kh := 0.18
	var bay_w := 3.2
	var bay_d := 5.8
	var lw := 0.12

	# -------------------------------------------------------------
	# 1. NORTH MARINA PARKING LOT (x in [115, 185], z in [1928, 1943.3])
	# Shifted back away from canal, leaving a wide 10m promenade with direct walkways to the docks
	# -------------------------------------------------------------
	var m_x0 := 115.0
	var m_x1 := 185.0
	var m_z0 := 1928.0
	var m_z1 := 1950.0 - KERB
	var m_py := PY + 0.02
	_box(mb, asphalt, Vector3(m_x0, 0.0, m_z0), Vector3(m_x1, m_py, m_z1))
	_cb(body, Vector3(m_x0, 0.0, m_z0), Vector3(m_x1, m_py, m_z1))
	(CityBuild.layout.lots as Array).append([m_x0, m_z0, m_x1, m_z1])

	# Paved walkways connecting parking lot directly to the canal boardwalk & docks:
	var walk_mat := _surface_mat("walk", "PavingStones136", 0.5, Color(1.15, 1.1, 1.0), 0.85)
	# Main Walkway: Aligned with the central marina pier at x = 160.0
	_box(mb, walk_mat, Vector3(157.5, m_py - 0.005, 1917.5), Vector3(162.5, m_py + 0.015, m_z0))
	_cb(body, Vector3(157.5, 0.0, 1917.5), Vector3(162.5, m_py + 0.015, m_z0))
	# Secondary Walkway: Connecting west parking bays to the boardwalk and pier at x = 115.0
	_box(mb, walk_mat, Vector3(122.5, m_py - 0.005, 1917.5), Vector3(127.5, m_py + 0.015, m_z0))
	_cb(body, Vector3(122.5, 0.0, 1917.5), Vector3(127.5, m_py + 0.015, m_z0))

	# Perimeter Kerbs (with cutouts for dock walkways and street entrance)
	_box(mb, kerb_mat, Vector3(m_x0 - kw, m_py, m_z0 - kw), Vector3(122.5, m_py + kh, m_z0))
	_cb(body, Vector3(m_x0 - kw, m_py, m_z0 - kw), Vector3(122.5, m_py + kh, m_z0))
	_box(mb, kerb_mat, Vector3(127.5, m_py, m_z0 - kw), Vector3(157.5, m_py + kh, m_z0))
	_cb(body, Vector3(127.5, m_py, m_z0 - kw), Vector3(157.5, m_py + kh, m_z0))
	_box(mb, kerb_mat, Vector3(162.5, m_py, m_z0 - kw), Vector3(m_x1 + kw, m_py + kh, m_z0))
	_cb(body, Vector3(162.5, m_py, m_z0 - kw), Vector3(m_x1 + kw, m_py + kh, m_z0))

	_box(mb, kerb_mat, Vector3(m_x0 - kw, m_py, m_z0), Vector3(m_x0, m_py + kh, m_z1))
	_cb(body, Vector3(m_x0 - kw, m_py, m_z0), Vector3(m_x0, m_py + kh, m_z1))
	_box(mb, kerb_mat, Vector3(m_x1, m_py, m_z0), Vector3(m_x1 + kw, m_py + kh, m_z1))
	_cb(body, Vector3(m_x1, m_py, m_z0), Vector3(m_x1 + kw, m_py + kh, m_z1))

	# South kerb (street apron entrance between 138.0 and 162.0)
	_box(mb, kerb_mat, Vector3(m_x0 - kw, m_py, m_z1), Vector3(138.0, m_py + kh, m_z1 + kw))
	_cb(body, Vector3(m_x0 - kw, m_py, m_z1), Vector3(138.0, m_py + kh, m_z1 + kw))
	_box(mb, kerb_mat, Vector3(162.0, m_py, m_z1), Vector3(m_x1 + kw, m_py + kh, m_z1 + kw))
	_cb(body, Vector3(162.0, m_py, m_z1), Vector3(m_x1 + kw, m_py + kh, m_z1 + kw))

	# North row parking bays
	var n_bays := int(floor((m_x1 - m_x0 - 8.0) / bay_w))
	for b in range(n_bays):
		var bx := m_x0 + 4.0 + b * bay_w
		_box(mb, line_mat, Vector3(bx - lw * 0.5, m_py, m_z0 + 0.2), Vector3(bx + lw * 0.5, m_py + 0.015, m_z0 + 4.8))
		_box(mb, stop_mat, Vector3(bx + 0.6, m_py, m_z0 + 0.4), Vector3(bx + bay_w - 0.6, m_py + 0.14, m_z0 + 0.7))
		_cb(body, Vector3(bx + 0.6, m_py, m_z0 + 0.4), Vector3(bx + bay_w - 0.6, m_py + 0.14, m_z0 + 0.7))
	_box(mb, line_mat, Vector3(m_x0 + 4.0 + n_bays * bay_w - lw * 0.5, m_py, m_z0 + 0.2), Vector3(m_x0 + 4.0 + n_bays * bay_w + lw * 0.5, m_py + 0.015, m_z0 + 4.8))

	# South row bays
	for b in range(6):
		var bx := m_x0 + 4.0 + b * bay_w
		_box(mb, line_mat, Vector3(bx - lw * 0.5, m_py, m_z1 - 4.8), Vector3(bx + lw * 0.5, m_py + 0.015, m_z1 - 0.2))
		_box(mb, stop_mat, Vector3(bx + 0.6, m_py, m_z1 - 0.7), Vector3(bx + bay_w - 0.6, m_py + 0.14, m_z1 - 0.4))
		_cb(body, Vector3(bx + 0.6, m_py, m_z1 - 0.7), Vector3(bx + bay_w - 0.6, m_py + 0.14, m_z1 - 0.4))
	_box(mb, line_mat, Vector3(m_x0 + 4.0 + 6 * bay_w - lw * 0.5, m_py, m_z1 - 4.8), Vector3(m_x0 + 4.0 + 6 * bay_w + lw * 0.5, m_py + 0.015, m_z1 - 0.2))

	for b in range(5):
		var bx := 162.0 + b * bay_w
		_box(mb, line_mat, Vector3(bx - lw * 0.5, m_py, m_z1 - 4.8), Vector3(bx + lw * 0.5, m_py + 0.015, m_z1 - 0.2))
		_box(mb, stop_mat, Vector3(bx + 0.6, m_py, m_z1 - 0.7), Vector3(bx + bay_w - 0.6, m_py + 0.14, m_z1 - 0.4))
		_cb(body, Vector3(bx + 0.6, m_py, m_z1 - 0.7), Vector3(bx + bay_w - 0.6, m_py + 0.14, m_z1 - 0.4))
	_box(mb, line_mat, Vector3(162.0 + 5 * bay_w - lw * 0.5, m_py, m_z1 - 4.8), Vector3(162.0 + 5 * bay_w + lw * 0.5, m_py + 0.015, m_z1 - 0.2))

	# Decorative palms and floodlight illumination
	_palm(body, Vector2(m_x0 + 2.0, m_z0 + 2.0), rng, "m")
	_palm(body, Vector2(m_x1 - 2.0, m_z0 + 2.0), rng, "m")
	_palm(body, Vector2(m_x0 + 2.0, m_z1 - 2.0), rng, "m")
	_palm(body, Vector2(m_x1 - 2.0, m_z1 - 2.0), rng, "m")

	for lx in [m_x0 + 16.0, m_x1 - 16.0]:
		var lpos := Vector3(lx, m_py, (m_z0 + m_z1) * 0.5)
		_box(mb, kerb_mat, lpos + Vector3(-0.4, 0, -0.4), lpos + Vector3(0.4, 0.4, 0.4))
		_box(mb, _flat(Color("#36383e"), 0.5), lpos + Vector3(-0.1, 0.4, -0.1), lpos + Vector3(0.1, 7.0, 0.1))
		var fl_head := lpos + Vector3(0, 7.0, 0)
		_box(mb, _lamp_mat, fl_head + Vector3(-0.4, -0.1, -0.4), fl_head + Vector3(0.4, 0.2, 0.4))
		var fl := OmniLight3D.new()
		fl.position = fl_head + Vector3(0, -0.3, 0)
		fl.omni_range = 28.0
		fl.light_energy = 2.2
		fl.light_color = Color(1.0, 0.95, 0.85)
		CityLights.register_light(fl, 2.2)
		w.add_child(fl)

	# Drivable parked vehicles in Marina Lot
	var marina_cars := [
		["fumi", m_x0 + 4.0 + 1.5 * bay_w, m_z0 + 2.5, 0.0],
		["factory_gt", m_x0 + 4.0 + 4.5 * bay_w, m_z0 + 2.5, 0.0],
		["wagon", m_x0 + 4.0 + 7.5 * bay_w, m_z0 + 2.5, 0.0],
		["saloon", m_x0 + 4.0 + 11.5 * bay_w, m_z0 + 2.5, 0.0],
		["van", m_x0 + 4.0 + 14.5 * bay_w, m_z0 + 2.5, 0.0],
		["old", m_x0 + 4.0 + 17.5 * bay_w, m_z0 + 2.5, 0.0],
		["saloon", m_x0 + 4.0 + 2.5 * bay_w, m_z1 - 2.5, PI],
		["fumi", 162.0 + 2.5 * bay_w, m_z1 - 2.5, PI]
	]
	for cinfo in marina_cars:
		var car := Car.new()
		car.position = Vector3(cinfo[1], m_py + Car.RIDE + 0.15, cinfo[2])
		car.rotation.y = cinfo[3]
		w.add_child(car)
		car.setup(cinfo[0], "", true)

	# -------------------------------------------------------------
	# 3. ISLAND PLAZA METRO PARKING (x in [16, 46], z in [2415, 2445])
	# -------------------------------------------------------------
	var p_x0 := 16.0
	var p_x1 := 46.0
	var p_z0 := 2415.0
	var p_z1 := 2445.0
	var p_py := PY + 0.02
	_box(mb, asphalt, Vector3(p_x0, 0.0, p_z0), Vector3(p_x1, p_py, p_z1))
	_cb(body, Vector3(p_x0, 0.0, p_z0), Vector3(p_x1, p_py, p_z1))
	(CityBuild.layout.lots as Array).append([p_x0, p_z0, p_x1, p_z1])

	_box(mb, kerb_mat, Vector3(p_x0 - kw, p_py, p_z0 - kw), Vector3(p_x1 + kw, p_py + kh, p_z0))
	_cb(body, Vector3(p_x0 - kw, p_py, p_z0 - kw), Vector3(p_x1 + kw, p_py + kh, p_z0))
	_box(mb, kerb_mat, Vector3(p_x0 - kw, p_py, p_z0), Vector3(p_x0, p_py + kh, p_z1))
	_cb(body, Vector3(p_x0 - kw, p_py, p_z0), Vector3(p_x0, p_py + kh, p_z1))
	_box(mb, kerb_mat, Vector3(p_x1, p_py, p_z0), Vector3(p_x1 + kw, p_py + kh, p_z1))
	_cb(body, Vector3(p_x1, p_py, p_z0), Vector3(p_x1 + kw, p_py + kh, p_z1))

	for b in range(5):
		var bx := p_x0 + 4.0 + b * 4.2
		_box(mb, line_mat, Vector3(bx - lw * 0.5, p_py, p_z0 + 0.3), Vector3(bx + lw * 0.5, p_py + 0.015, p_z0 + 5.8))
		_box(mb, stop_mat, Vector3(bx + 0.6, p_py, p_z0 + 0.6), Vector3(bx + 3.6, p_py + 0.14, p_z0 + 0.9))
		_cb(body, Vector3(bx + 0.6, p_py, p_z0 + 0.6), Vector3(bx + 3.6, p_py + 0.14, p_z0 + 0.9))
	_box(mb, line_mat, Vector3(p_x0 + 4.0 + 5 * 4.2 - lw * 0.5, p_py, p_z0 + 0.3), Vector3(p_x0 + 4.0 + 5 * 4.2 + lw * 0.5, p_py + 0.015, p_z0 + 5.8))

	_palm(body, Vector2(p_x0 + 2.0, p_z0 + 2.0), rng, "m")
	_palm(body, Vector2(p_x1 - 2.0, p_z0 + 2.0), rng, "m")

	var plaza_cars := [
		["police", p_x0 + 4.0 + 1.0 * 4.2, p_z0 + 2.9, 0.0],
		["saloon", p_x0 + 4.0 + 3.0 * 4.2, p_z0 + 2.9, 0.0]
	]
	for cinfo in plaza_cars:
		var car := Car.new()
		car.position = Vector3(cinfo[1], p_py + Car.RIDE + 0.15, cinfo[2])
		car.rotation.y = cinfo[3]
		w.add_child(car)
		car.setup(cinfo[0], "", true)

	var pmesh := _finish(mb)
	if pmesh.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = pmesh
		body.add_child(mi)

## Builds municipal emergency facilities on Redline Island:
## 1. Redline Island Police Station Compound (station, helipad with flyable chopper, garage with 3 cruisers, gate sign, security fence, guard booth, cops)
## 2. Redline Island Fire Station (firehouse, perimeter wall/fence, emergency apparatus apron with fire truck & chief cruiser, arch sign, siren, beacons)
## 3. Redline Island Hospital Compound (hospital, medevac helipad with flyable chopper, ambulance canopy with 2 ambulances, perimeter security fence, gate sign, doctors/nurses)
static func _fence_run(w: World, body: StaticBody3D, iron: Material, p0: Vector3, p1: Vector3) -> void:
	var along_x := absf(p1.x - p0.x) > absf(p1.z - p0.z)
	var len := (p1 - p0).length()
	if len < 0.6: return
	var mid := (p0 + p1) * 0.5
	for ry in [0.45, 1.0, 1.65]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(len, 0.08, 0.08) if along_x else Vector3(0.08, 0.08, len)
		rail.mesh = rb
		rail.material_override = iron
		rail.position = mid + Vector3(0, ry, 0)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(rail)
	var np := int(len / 2.5) + 1
	for k in range(np + 1):
		var f := float(k) / float(np)
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.14, 1.8, 0.14)
		post.mesh = pb
		post.material_override = iron
		post.position = p0.lerp(p1, f) + Vector3(0, 0.9, 0)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(post)
	var nb := int(len / 0.45)
	if nb > 0:
		var bars := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 1.55, 0.03)
		mm.mesh = bm
		mm.instance_count = nb
		for k in range(nb):
			var f := (float(k) + 0.5) / float(nb)
			var bp := p0.lerp(p1, f) + Vector3(0, 0.88, 0)
			mm.set_instance_transform(k, Transform3D(Basis(), bp))
		bars.multimesh = mm
		bars.material_override = iron
		bars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(bars)
	CoastProps._box(body, Vector3(len, 1.8, 0.2) if along_x else Vector3(0.2, 1.8, len), mid + Vector3(0, 0.9, 0))

static func _build_island_emergency_services(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var w: World = c.w
	var body: StaticBody3D = c.body
	if CityBuild.specs.is_empty():
		CityBuild._specs()

	var asphalt := _flat(Color("#28282b"), 0.9)
	var conc := _flat(Color("#9b9a94"), 0.85)
	var iron := _flat(Color("#23262b"), 0.7)
	var line_mat := _flat(Color("#f0eee4"), 0.8)
	var stop_mat := _flat(Color("#e0ded8"), 0.85)
	var curb_mat := _flat(Color("#c2bfb8"), 0.85)
	var red_brick := _flat(Color("#7a3b2c"), 0.85)
	var garage_roof_mat := _flat(Color("#2f3b52"), 0.8)
	var mb := {}
	var py := PY

	# Common helipad geometry specs
	var hs: Dictionary = CityBuild.specs["helipad"]
	var hb: AABB = (hs.mesh as Mesh).get_aabb()
	var hbasis := Basis(Vector3.UP, -PI * 0.5)

	# =========================================================================
	# 1. REDLINE ISLAND POLICE STATION COMPOUND
	# Block (i=2, j=0), south frontage facing Avenue 2200 (z1 = 2193.3)
	# Dedicated municipal lot: x in [210.0, 286.0], z in [2138.0, 2193.3] (outside park)
	# =========================================================================
	var p_x0 := 210.0
	var p_x1 := 286.0
	var p_z0 := 2138.0
	var p_z1 := 2200.0 - KERB
	var p_gate_x0 := 240.0
	var p_gate_x1 := 256.0
	var p_gate_xc := (p_gate_x0 + p_gate_x1) * 0.5

	# Heavy asphalt compound base
	_box(mb, asphalt, Vector3(p_x0, 0.0, p_z0), Vector3(p_x1, py + 0.02, p_z1))
	_cb(body, Vector3(p_x0, 0.0, p_z0), Vector3(p_x1, py + 0.02, p_z1))
	# Paved main driveway from entrance gate to station
	_box(mb, _flat(Color("#c8c7be")), Vector3(p_gate_x0 + 1.0, py + 0.022, p_z1 - 24.0), Vector3(p_gate_x1 - 1.0, py + 0.025, p_z1))
	(CityBuild.layout.lots as Array).append([p_x0, p_z0, p_x1, p_z1])

	# Perimeter Kerbs: North, West, East, and South (leaving the 16m gate completely unobstructed)
	var kw := 0.28
	var kh := 0.18
	_box(mb, curb_mat, Vector3(p_x0 - kw, py, p_z0 - kw), Vector3(p_x1 + kw, py + kh, p_z0))
	_cb(body, Vector3(p_x0 - kw, py, p_z0 - kw), Vector3(p_x1 + kw, py + kh, p_z0))
	_box(mb, curb_mat, Vector3(p_x0 - kw, py, p_z0), Vector3(p_x0, py + kh, p_z1))
	_cb(body, Vector3(p_x0 - kw, py, p_z0), Vector3(p_x0, py + kh, p_z1))
	_box(mb, curb_mat, Vector3(p_x1, py, p_z0), Vector3(p_x1 + kw, py + kh, p_z1))
	_cb(body, Vector3(p_x1, py, p_z0), Vector3(p_x1 + kw, py + kh, p_z1))
	_box(mb, curb_mat, Vector3(p_x0 - kw, py, p_z1), Vector3(p_gate_x0, py + kh, p_z1 + kw))
	_cb(body, Vector3(p_x0 - kw, py, p_z1), Vector3(p_gate_x0, py + kh, p_z1 + kw))
	_box(mb, curb_mat, Vector3(p_gate_x1, py, p_z1), Vector3(p_x1 + kw, py + kh, p_z1 + kw))
	_cb(body, Vector3(p_gate_x1, py, p_z1), Vector3(p_x1 + kw, py + kh, p_z1 + kw))

	# Perimeter Security Fence (open 16m entrance across the driveway)
	_fence_run(w, body, iron, Vector3(p_x0, py, p_z1), Vector3(p_gate_x0, py, p_z1))
	_fence_run(w, body, iron, Vector3(p_gate_x1, py, p_z1), Vector3(p_x1, py, p_z1))
	_fence_run(w, body, iron, Vector3(p_x0, py, p_z0), Vector3(p_x0, py, p_z1))
	_fence_run(w, body, iron, Vector3(p_x1, py, p_z0), Vector3(p_x1, py, p_z1))
	_fence_run(w, body, iron, Vector3(p_x0, py, p_z0), Vector3(p_x1, py, p_z0))

	# Gate Pillars & Illuminated Overhead Arch Sign
	for pil_x in [p_gate_x0, p_gate_x1]:
		_box(mb, conc, Vector3(pil_x - 0.45, py, p_z1 - 0.45), Vector3(pil_x + 0.45, py + 4.8, p_z1 + 0.45))
		_cb(body, Vector3(pil_x - 0.45, py, p_z1 - 0.45), Vector3(pil_x + 0.45, py + 4.8, p_z1 + 0.45))
	_box(mb, _flat(Color("#2b55c8"), 0.9), Vector3(p_gate_x0 - 0.5, py + 4.4, p_z1 - 0.28), Vector3(p_gate_x1 + 0.5, py + 5.6, p_z1 + 0.28))

	for face in [-1.0, 1.0]:
		var plb := Label3D.new()
		plb.text = "REDLINE ISLAND POLICE"
		plb.font_size = 64
		plb.pixel_size = 0.0075
		plb.outline_size = 14
		plb.modulate = Color(1, 1, 1)
		plb.outline_modulate = Color("#112255")
		plb.shaded = false
		plb.double_sided = false
		plb.position = Vector3(p_gate_xc, py + 5.0, p_z1 + face * 0.3)
		plb.rotation.y = 0.0 if face > 0.0 else PI
		w.static_root.add_child(plb)

	var p_bl := OmniLight3D.new()
	p_bl.position = Vector3(p_gate_xc, py + 6.0, p_z1)
	p_bl.omni_range = 18.0
	p_bl.light_energy = 2.0
	p_bl.light_color = Color("#2b55c8")
	CityLights.register_light(p_bl, 2.0)
	w.add_child(p_bl)

	# Checkpoint Guard Booth inside gate
	var g_pos := Vector3(p_gate_x0 - 2.8, py, p_z1 - 3.5)
	_box(mb, conc, g_pos + Vector3(-1.2, 0, -1.2), g_pos + Vector3(1.2, 2.8, 1.2))
	_cb(body, g_pos + Vector3(-1.2, 0, -1.2), g_pos + Vector3(1.2, 2.8, 1.2))
	_box(mb, _flat(Color("#2b55c8"), 0.9), g_pos + Vector3(-1.3, 2.8, -1.3), g_pos + Vector3(1.3, 3.1, 1.3))
	_box(mb, _lit_glass, g_pos + Vector3(-1.0, 1.0, 1.15), g_pos + Vector3(1.0, 2.2, 1.25))

	# Police Station Building (facing south towards Avenue 2200)
	var pol_sp: Dictionary = CityBuild.specs["police"]
	var pol_pos := Vector3(236.0, py, 2154.0)
	var pol_t := Transform3D(Basis(Vector3.UP, 0.0 + float(pol_sp.yaw0)), pol_pos)
	var pol_mi := MeshInstance3D.new()
	pol_mi.mesh = pol_sp.mesh
	pol_mi.transform = pol_t
	pol_mi.visibility_range_end = 2400.0
	w.static_root.add_child(pol_mi)
	CoastProps._box(body, Vector3(pol_sp.w, pol_sp.size.y, pol_sp.d), pol_pos + Vector3(0, pol_sp.size.y * 0.5, 0), 0.0)

	# Police Helipad (placed on east yard with >10m clearance to building & fences)
	var p_pad_center := Vector3(268.0, py, 2156.0)
	var p_hpos := p_pad_center - hbasis * hb.get_center()
	var p_hmi := MeshInstance3D.new()
	p_hmi.mesh = hs.mesh
	p_hmi.transform = Transform3D(hbasis, p_hpos)
	p_hmi.visibility_range_end = 900.0
	w.static_root.add_child(p_hmi)
	var p_hcs := CollisionShape3D.new()
	p_hcs.shape = (hs.mesh as Mesh).create_trimesh_shape()
	p_hcs.transform = Transform3D(hbasis, p_hpos)
	body.add_child(p_hcs)

	var p_chopper := HelipadChopper.new()
	p_chopper.setup("police")
	w.add_child(p_chopper)
	p_chopper.global_position = Vector3(p_pad_center.x, py + 1.9, p_pad_center.z)
	p_chopper.rotation.y = PI * 0.5

	# Police Garage & Parking (west yard: 3 cruisers)
	var gw := 17.0
	var gd := 12.0
	var gx0 := p_x0 + 3.0
	var gz0 := p_z1 - 22.0
	_box(mb, garage_roof_mat, Vector3(gx0, py + 3.8, gz0), Vector3(gx0 + gw, py + 4.1, gz0 + gd))
	_cb(body, Vector3(gx0, py + 3.8, gz0), Vector3(gx0 + gw, py + 4.1, gz0 + gd))
	for px in [gx0 + 0.3, gx0 + gw - 0.3]:
		for pz in [gz0 + 0.3, gz0 + gd - 0.3]:
			_box(mb, iron, Vector3(px - 0.15, py, pz - 0.15), Vector3(px + 0.15, py + 3.8, pz + 0.15))
			_cb(body, Vector3(px - 0.15, py, pz - 0.15), Vector3(px + 0.15, py + 3.8, pz + 0.15))

	for k in range(3):
		var car := Car.new()
		car.position = Vector3(gx0 + 3.0 + k * 5.2, py + Car.RIDE + 0.15, gz0 + gd * 0.5)
		car.rotation.y = 0.0
		w.add_child(car)
		car.setup("police", "", true)
		_box(mb, line_mat, Vector3(gx0 + 0.4 + k * 5.2, py + 0.02, gz0 + 0.5), Vector3(gx0 + 0.55 + k * 5.2, py + 0.035, gz0 + gd - 0.5))
		_box(mb, stop_mat, Vector3(gx0 + 1.2 + k * 5.2, py + 0.02, gz0 + gd - 1.2), Vector3(gx0 + 4.8 + k * 5.2, py + 0.16, gz0 + gd - 0.9))
		_cb(body, Vector3(gx0 + 1.2 + k * 5.2, py + 0.02, gz0 + gd - 1.2), Vector3(gx0 + 4.8 + k * 5.2, py + 0.16, gz0 + gd - 0.9))
	_box(mb, line_mat, Vector3(gx0 + 0.4 + 3 * 5.2, py + 0.02, gz0 + 0.5), Vector3(gx0 + 0.55 + 3 * 5.2, py + 0.035, gz0 + gd - 0.5))

	for st in [["cop", -4.0, p_z1 - 10.0], ["cop", 4.0, p_z1 - 10.0], ["cop", -12.0, p_z1 - 16.0], ["cop", 12.0, p_z1 - 16.0]]:
		(w as World).spawns.append({"type": "npc", "who": st[0], "pos": Vector3(p_gate_xc + float(st[1]), py, float(st[2])), "yaw": 0.0, "wander": 8.0})

	w.add_poi("police", "REDLINE ISLAND POLICE", Vector3(pol_pos.x, py + 1.5, pol_pos.z))

	# =========================================================================
	# 2. REDLINE ISLAND FIRE STATION
	# Block (i=2, j=0), south frontage facing Avenue 2200 (z1 = 2193.3)
	# Dedicated municipal lot: x in [296.0, 390.0], z in [2138.0, 2193.3] (outside park)
	# =========================================================================
	var f_x0 := 296.0
	var f_x1 := 390.0
	var f_z0 := 2138.0
	var f_z1 := 2200.0 - KERB
	var f_gate_x0 := 330.0
	var f_gate_x1 := 360.0
	var f_gate_xc := (f_gate_x0 + f_gate_x1) * 0.5

	_box(mb, asphalt, Vector3(f_x0, 0.0, f_z0), Vector3(f_x1, py + 0.02, f_z1))
	_cb(body, Vector3(f_x0, 0.0, f_z0), Vector3(f_x1, py + 0.02, f_z1))
	(CityBuild.layout.lots as Array).append([f_x0, f_z0, f_x1, f_z1])

	# Perimeter kerb (with 30m open exit for emergency engines)
	_box(mb, curb_mat, Vector3(f_x0 - kw, py, f_z0 - kw), Vector3(f_x1 + kw, py + kh, f_z0))
	_cb(body, Vector3(f_x0 - kw, py, f_z0 - kw), Vector3(f_x1 + kw, py + kh, f_z0))
	_box(mb, curb_mat, Vector3(f_x0 - kw, py, f_z0), Vector3(f_x0, py + kh, f_z1))
	_cb(body, Vector3(f_x0 - kw, py, f_z0), Vector3(f_x0, py + kh, f_z1))
	_box(mb, curb_mat, Vector3(f_x1, py, f_z0), Vector3(f_x1 + kw, py + kh, f_z1))
	_cb(body, Vector3(f_x1, py, f_z0), Vector3(f_x1 + kw, py + kh, f_z1))
	_box(mb, curb_mat, Vector3(f_x0 - kw, py, f_z1), Vector3(f_gate_x0, py + kh, f_z1 + kw))
	_cb(body, Vector3(f_x0 - kw, py, f_z1), Vector3(f_gate_x0, py + kh, f_z1 + kw))
	_box(mb, curb_mat, Vector3(f_gate_x1, py, f_z1), Vector3(f_x1 + kw, py + kh, f_z1 + kw))
	_cb(body, Vector3(f_gate_x1, py, f_z1), Vector3(f_x1 + kw, py + kh, f_z1 + kw))

	# Boundary Fence (wide open apron entrance to the street)
	_fence_run(w, body, iron, Vector3(f_x0, py, f_z1), Vector3(f_gate_x0, py, f_z1))
	_fence_run(w, body, iron, Vector3(f_gate_x1, py, f_z1), Vector3(f_x1, py, f_z1))
	_fence_run(w, body, iron, Vector3(f_x0, py, f_z0), Vector3(f_x0, py, f_z1))
	_fence_run(w, body, iron, Vector3(f_x1, py, f_z0), Vector3(f_x1, py, f_z1))
	_fence_run(w, body, iron, Vector3(f_x0, py, f_z0), Vector3(f_x1, py, f_z0))

	# Fire Station Building: rotated PI so the three engine doors face SOUTH to the street
	var fire_sp: Dictionary = CityBuild.specs["fire"]
	var fire_pos := Vector3(345.0, py, 2154.0)
	var fire_t := Transform3D(Basis(Vector3.UP, PI + float(fire_sp.yaw0)), fire_pos)
	var fire_mi := MeshInstance3D.new()
	fire_mi.mesh = fire_sp.mesh
	fire_mi.transform = fire_t
	fire_mi.visibility_range_end = 2400.0
	w.static_root.add_child(fire_mi)
	CoastProps._box(body, Vector3(fire_sp.w, fire_sp.size.y, fire_sp.d), fire_pos + Vector3(0, fire_sp.size.y * 0.5, 0), 0.0)

	# Yellow chevron emergency apron markings leading out to Avenue
	var yel := _flat(Color("#f0b824"), 0.8)
	for i in range(5):
		var yz := f_z1 - 22.0 + float(i) * 4.5
		_box(mb, yel, Vector3(f_gate_x0 + 1.0, py + 0.022, yz - 0.12), Vector3(f_gate_x1 - 1.0, py + 0.035, yz + 0.12))

	# Fire Apparatus: Fire Truck and Chief Vehicle parked on apron facing south
	var f_truck := Car.new()
	f_truck.position = Vector3(f_gate_xc - 6.0, py + Car.RIDE + 0.15, f_z1 - 12.0)
	f_truck.rotation.y = 0.0
	w.add_child(f_truck)
	f_truck.setup("box", "", true)

	var f_chief := Car.new()
	f_chief.position = Vector3(f_gate_xc + 6.0, py + Car.RIDE + 0.15, f_z1 - 12.0)
	f_chief.rotation.y = 0.0
	w.add_child(f_chief)
	f_chief.setup("van", "", true)

	# Red Brick Entrance Pillars & Overhead Arch Sign
	for pil_x in [f_gate_x0, f_gate_x1]:
		_box(mb, red_brick, Vector3(pil_x - 0.55, py, f_z1 - 0.55), Vector3(pil_x + 0.55, py + 5.0, f_z1 + 0.55))
		_cb(body, Vector3(pil_x - 0.55, py, f_z1 - 0.55), Vector3(pil_x + 0.55, py + 5.0, f_z1 + 0.55))
	_box(mb, _flat(Color("#c82424"), 0.9), Vector3(f_gate_x0 - 0.6, py + 4.6, f_z1 - 0.28), Vector3(f_gate_x1 + 0.6, py + 5.8, f_z1 + 0.28))

	for face in [-1.0, 1.0]:
		var flb := Label3D.new()
		flb.text = "REDLINE ISLAND FIRE DEPT"
		flb.font_size = 64
		flb.pixel_size = 0.0075
		flb.outline_size = 14
		flb.modulate = Color(1, 1, 1)
		flb.outline_modulate = Color("#551111")
		flb.shaded = false
		flb.double_sided = false
		flb.position = Vector3(f_gate_xc, py + 5.2, f_z1 + face * 0.3)
		flb.rotation.y = 0.0 if face > 0.0 else PI
		w.static_root.add_child(flb)

	var f_bl := OmniLight3D.new()
	f_bl.position = Vector3(f_gate_xc, py + 6.2, f_z1)
	f_bl.omni_range = 18.0
	f_bl.light_energy = 2.2
	f_bl.light_color = Color("#e02a2a")
	CityLights.register_light(f_bl, 2.2)
	w.add_child(f_bl)

	w.add_poi("fire", "REDLINE ISLAND FIRE DEPT", Vector3(fire_pos.x, py + 1.5, fire_pos.z))

	# =========================================================================
	# 3. REDLINE ISLAND HOSPITAL COMPOUND
	# Block (i=2, j=1), north frontage facing Avenue 2200 (z0 = 2206.7)
	# Dedicated municipal lot: x in [214.0, 316.0], z in [2206.7, 2266.0] (outside park)
	# =========================================================================
	var h_x0 := 214.0
	var h_x1 := 316.0
	var h_z0 := 2200.0 + KERB
	var h_z1 := 2266.0
	var h_gate_x0 := 246.0
	var h_gate_x1 := 264.0
	var h_gate_xc := (h_gate_x0 + h_gate_x1) * 0.5

	_box(mb, asphalt, Vector3(h_x0, 0.0, h_z0), Vector3(h_x1, py + 0.02, h_z1))
	_cb(body, Vector3(h_x0, 0.0, h_z0), Vector3(h_x1, py + 0.02, h_z1))
	# Main entrance apron from Avenue gate into hospital lobby
	_box(mb, _flat(Color("#d8d7ce")), Vector3(h_gate_x0 + 1.0, py + 0.022, h_z0), Vector3(h_gate_x1 - 1.0, py + 0.025, h_z0 + 26.0))
	(CityBuild.layout.lots as Array).append([h_x0, h_z0, h_x1, h_z1])

	# Perimeter kerb (with 18m open entrance to the avenue)
	_box(mb, curb_mat, Vector3(h_x0 - kw, py, h_z0 - kw), Vector3(h_gate_x0, py + kh, h_z0))
	_cb(body, Vector3(h_x0 - kw, py, h_z0 - kw), Vector3(h_gate_x0, py + kh, h_z0))
	_box(mb, curb_mat, Vector3(h_gate_x1, py, h_z0 - kw), Vector3(h_x1 + kw, py + kh, h_z0))
	_cb(body, Vector3(h_gate_x1, py, h_z0 - kw), Vector3(h_x1 + kw, py + kh, h_z0))
	_box(mb, curb_mat, Vector3(h_x0 - kw, py, h_z0), Vector3(h_x0, py + kh, h_z1))
	_cb(body, Vector3(h_x0 - kw, py, h_z0), Vector3(h_x0, py + kh, h_z1))
	_box(mb, curb_mat, Vector3(h_x1, py, h_z0), Vector3(h_x1 + kw, py + kh, h_z1))
	_cb(body, Vector3(h_x1, py, h_z0), Vector3(h_x1 + kw, py + kh, h_z1))
	_box(mb, curb_mat, Vector3(h_x0 - kw, py, h_z1), Vector3(h_x1 + kw, py + kh, h_z1 + kw))
	_cb(body, Vector3(h_x0 - kw, py, h_z1), Vector3(h_x1 + kw, py + kh, h_z1 + kw))

	# Perimeter Security Fence (open 18m entrance across the driveway)
	_fence_run(w, body, iron, Vector3(h_x0, py, h_z0), Vector3(h_gate_x0, py, h_z0))
	_fence_run(w, body, iron, Vector3(h_gate_x1, py, h_z0), Vector3(h_x1, py, h_z0))
	_fence_run(w, body, iron, Vector3(h_x0, py, h_z0), Vector3(h_x0, py, h_z1))
	_fence_run(w, body, iron, Vector3(h_x1, py, h_z0), Vector3(h_x1, py, h_z1))
	_fence_run(w, body, iron, Vector3(h_x0, py, h_z1), Vector3(h_x1, py, h_z1))

	# Hospital Building: oriented 0.0 facing NORTH towards Avenue 2200
	var hosp_sp: Dictionary = CityBuild.specs["hospital"]
	var hosp_pos := Vector3(250.0, py, 2246.0)
	var hosp_t := Transform3D(Basis(Vector3.UP, 0.0 + float(hosp_sp.yaw0)), hosp_pos)
	var hosp_mi := MeshInstance3D.new()
	hosp_mi.mesh = hosp_sp.mesh
	hosp_mi.transform = hosp_t
	hosp_mi.visibility_range_end = 2400.0
	w.static_root.add_child(hosp_mi)
	CoastProps._box(body, Vector3(hosp_sp.w, hosp_sp.size.y, hosp_sp.d), hosp_pos + Vector3(0, hosp_sp.size.y * 0.5, 0), 0.0)

	# Hospital Medevac Helipad (east yard: >13m clearance to hospital building, 20m clearance to fences)
	var h_pad_center := Vector3(296.0, py, 2246.0)
	var h_hpos := h_pad_center - hbasis * hb.get_center()
	var h_hmi := MeshInstance3D.new()
	h_hmi.mesh = hs.mesh
	h_hmi.transform = Transform3D(hbasis, h_hpos)
	h_hmi.visibility_range_end = 900.0
	w.static_root.add_child(h_hmi)
	var h_hcs := CollisionShape3D.new()
	h_hcs.shape = (hs.mesh as Mesh).create_trimesh_shape()
	h_hcs.transform = Transform3D(hbasis, h_hpos)
	body.add_child(h_hcs)

	var h_chopper := HelipadChopper.new()
	h_chopper.setup("hospital")
	w.add_child(h_chopper)
	h_chopper.global_position = Vector3(h_pad_center.x, py + 1.9, h_pad_center.z)
	h_chopper.rotation.y = PI * 0.5

	# Covered Ambulance Emergency Bay (west yard)
	var a_gw := 16.0
	var a_gd := 12.0
	var a_gx0 := h_x0 + 3.0
	var a_gz0 := h_z0 + 4.0
	_box(mb, _flat(Color("#c8d0d6"), 0.8), Vector3(a_gx0, py + 3.8, a_gz0), Vector3(a_gx0 + a_gw, py + 4.1, a_gz0 + a_gd))
	_cb(body, Vector3(a_gx0, py + 3.8, a_gz0), Vector3(a_gx0 + a_gw, py + 4.1, a_gz0 + a_gd))
	_box(mb, _flat(Color("#e02a2a")), Vector3(a_gx0 - 0.1, py + 3.75, a_gz0), Vector3(a_gx0 + a_gw + 0.1, py + 3.95, a_gz0 + 0.3))

	for px in [a_gx0 + 0.3, a_gx0 + a_gw - 0.3]:
		for pz in [a_gz0 + 0.3, a_gz0 + a_gd - 0.3]:
			_box(mb, iron, Vector3(px - 0.15, py, pz - 0.15), Vector3(px + 0.15, py + 3.8, pz + 0.15))
			_cb(body, Vector3(px - 0.15, py, pz - 0.15), Vector3(px + 0.15, py + 3.8, pz + 0.15))

	for k in range(2):
		var amb := Car.new()
		amb.position = Vector3(a_gx0 + 4.0 + k * 6.8, py + Car.RIDE + 0.15, a_gz0 + a_gd * 0.5)
		amb.rotation.y = 0.0
		w.add_child(amb)
		amb.setup("ambulance", "", true)
		_box(mb, line_mat, Vector3(a_gx0 + 0.5 + k * 6.8, py + 0.02, a_gz0 + 0.5), Vector3(a_gx0 + 0.7 + k * 6.8, py + 0.035, a_gz0 + a_gd - 0.5))
		_box(mb, stop_mat, Vector3(a_gx0 + 1.2 + k * 6.8, py + 0.02, a_gz0 + 0.8), Vector3(a_gx0 + 6.0 + k * 6.8, py + 0.16, a_gz0 + 1.1))
		_cb(body, Vector3(a_gx0 + 1.2 + k * 6.8, py + 0.02, a_gz0 + 0.8), Vector3(a_gx0 + 6.0 + k * 6.8, py + 0.16, a_gz0 + 1.1))
	_box(mb, line_mat, Vector3(a_gx0 + 0.5 + 2 * 6.8, py + 0.02, a_gz0 + 0.5), Vector3(a_gx0 + 0.7 + 2 * 6.8, py + 0.035, a_gz0 + a_gd - 0.5))

	# Hospital Entrance Pillars & Illuminated Overhead Arch Sign
	for pil_x in [h_gate_x0, h_gate_x1]:
		_box(mb, conc, Vector3(pil_x - 0.45, py, h_z0 - 0.45), Vector3(pil_x + 0.45, py + 4.8, h_z0 + 0.45))
		_cb(body, Vector3(pil_x - 0.45, py, h_z0 - 0.45), Vector3(pil_x + 0.45, py + 4.8, h_z0 + 0.45))
	_box(mb, _flat(Color("#e02a2a"), 0.9), Vector3(h_gate_x0 - 0.5, py + 4.4, h_z0 - 0.28), Vector3(h_gate_x1 + 0.5, py + 5.6, h_z0 + 0.28))

	for face in [-1.0, 1.0]:
		var hlb := Label3D.new()
		hlb.text = "REDLINE ISLAND HOSPITAL"
		hlb.font_size = 64
		hlb.pixel_size = 0.0075
		hlb.outline_size = 14
		hlb.modulate = Color(1, 1, 1)
		hlb.outline_modulate = Color("#551111")
		hlb.shaded = false
		hlb.double_sided = false
		hlb.position = Vector3(h_gate_xc, py + 5.0, h_z0 + face * 0.3)
		hlb.rotation.y = 0.0 if face > 0.0 else PI
		w.static_root.add_child(hlb)

	var h_bl := OmniLight3D.new()
	h_bl.position = Vector3(h_gate_xc, py + 6.0, h_z0)
	h_bl.omni_range = 18.0
	h_bl.light_energy = 2.2
	h_bl.light_color = Color("#e02a2a")
	CityLights.register_light(h_bl, 2.2)
	w.add_child(h_bl)

	for st in [["doctor", -4.0, h_z0 + 10.0], ["nurse", 4.0, h_z0 + 10.0], ["doctor", -12.0, h_z0 + 16.0], ["nurse", 12.0, h_z0 + 16.0]]:
		(w as World).spawns.append({"type": "npc", "who": st[0], "pos": Vector3(h_gate_xc + float(st[1]), py, float(st[2])), "yaw": PI, "wander": 8.0})

	w.add_poi("hospital", "REDLINE ISLAND HOSPITAL", Vector3(hosp_pos.x, py + 1.5, hosp_pos.z))

	var pmesh := _finish(mb)
	if pmesh.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = pmesh
		body.add_child(mi)


# ------------------------------------------------------------------ the beach boulevards (half-circle roads)

static func _ground(x: float, z: float) -> float:
	return maxf(Coast.height_at(x, z), 0.0)

## Strip along an arc: between radii r0 and r1 (from the centre), at height lift above the ground, over angles a0..a1.
static func _arc_strip(mb: Dictionary, mat: Material, ctr: Vector2, r0: float, r1: float, a0: float, a1: float, lift: float, step := 0.02, uvs := 0.12, lvl_lo := 0.0, lvl_hi := 0.0, bridge := false) -> void:
	var n := int(ceil(absf(a1 - a0) / step))
	var lo := lvl_lo if lvl_hi > 0.0 else r0
	var hi := lvl_hi if lvl_hi > 0.0 else r1
	# the height at each angle is the highest ground across the whole boulevard section, so the road is level across and never sinks
	var lvl := PackedFloat32Array()
	for k in range(n + 1):
		var t := a0 + (a1 - a0) * k / n
		var m := 0.0
		for q in 5:
			var rr := lerpf(lo, hi, q / 4.0)
			m = maxf(m, _ground(ctr.x + cos(t) * rr, ctr.y + sin(t) * rr))
		if bridge: m = _bridge_h(ctr.y + sin(t) * (lo + hi) * 0.5)
		lvl.append(m)
	# smooth along the arc so the road does not step
	for it in (0 if bridge else 3):
		for k in range(1, n):
			lvl[k] = maxf(lvl[k], (lvl[k - 1] + lvl[k + 1]) * 0.5)
	for k in range(n):
		var t0 := a0 + (a1 - a0) * k / n
		var t1 := a0 + (a1 - a0) * (k + 1) / n
		var p00 := ctr + Vector2(cos(t0), sin(t0)) * r0
		var p01 := ctr + Vector2(cos(t0), sin(t0)) * r1
		var p10 := ctr + Vector2(cos(t1), sin(t1)) * r0
		var p11 := ctr + Vector2(cos(t1), sin(t1)) * r1
		var v00 := Vector3(p00.x, lvl[k] + lift, p00.y)
		var v01 := Vector3(p01.x, lvl[k] + lift, p01.y)
		var v10 := Vector3(p10.x, lvl[k + 1] + lift, p10.y)
		var v11 := Vector3(p11.x, lvl[k + 1] + lift, p11.y)
		if a1 < a0:
			_quad(mb, mat, v00, v01, v11, v10, uvs)
		else:
			_quad(mb, mat, v10, v11, v01, v00, uvs)

## One boulevard: asphalt with an edge line and a dashed centre line, a pavement on each side, palms and lamps. The arc is the circle
## through the two corner nodes a and b that bulges `sag` metres away from the chord (towards `bulge`: +1 / -1 along x for the
## sideways arcs).
static func _boulevard(c: Dictionary, a: Vector2, b: Vector2, sag: float, side: float, rng: RandomNumberGenerator) -> Dictionary:
	var w: World = c.w
	var chord := a.distance_to(b)
	var R := (chord * chord * 0.25 + sag * sag) / (2.0 * sag)
	var mid := (a + b) * 0.5
	var dirn := Vector2(side, 0.0)                              # bulge direction
	var ctr := mid - dirn * (sag - R)                           # centre of the circle
	var ang_a := (a - ctr).angle()
	var ang_b := (b - ctr).angle()
	# go from a to b through the bulge (the short way round for sag < R, the long way for sag > R: here sag <= R)
	var d := wrapf(ang_b - ang_a, -PI, PI)
	var bulge_ang := dirn.angle()
	var mid_ang := ang_a + d * 0.5
	if absf(wrapf(mid_ang - bulge_ang, -PI, PI)) > 0.5:
		d = d - signf(d) * TAU
	var a0 := ang_a
	var a1 := ang_a + d
	var asphalt: Material = RoadKit._plain_mat if RoadKit._plain_mat != null else _flat(Color("#3a3d42"), 0.9)
	var half := 5.9
	var mb := {}
	var L0 := R - half - 7.0
	var L1 := R + half + 7.0
	var white := _flat(Color("#f4f4ee"), 0.8)
	var yellow := _flat(Color("#f2c230"), 0.8)
	var pave := _surface_mat("walk", "PavingStones136", 0.5, Color(1.15, 1.1, 1.0), 0.85)
	var curb := _flat(Color("#c9c6bd"), 0.9)
	# the east boulevard crosses the sea channel on a fixed bridge: the flat road is drawn either side, the bridge in between
	var is_east := ctr.x > 0.0 and not ROADS_ONLY
	var segs: Array = [[a0, a1]]
	if is_east:
		var t_in := asin(-BR_HALF / R)
		var t_out := asin(BR_HALF / R)
		segs = [[a0, t_in], [t_out, a1]]
		_bridge_section(c, {"ctr": ctr, "R": R, "half": half}, t_in, t_out)
	for sg in segs:
		var sa: float = sg[0]
		var sb: float = sg[1]
		_arc_strip(mb, asphalt, ctr, R - half, R + half, sa, sb, 0.05, 0.02, 0.12, L0, L1)
		_arc_strip(mb, white, ctr, R - half + 0.35, R - half + 0.55, sa, sb, 0.07, 0.02, 0.12, L0, L1)
		_arc_strip(mb, white, ctr, R + half - 0.55, R + half - 0.35, sa, sb, 0.07, 0.02, 0.12, L0, L1)
		var ndd := int(absf(sb - sa) * R / 6.0)
		for k in range(ndd):
			if k % 2 == 0:
				_arc_strip(mb, yellow, ctr, R - 0.14, R + 0.14, sa + (sb - sa) * (k + 0.1) / ndd, sa + (sb - sa) * (k + 0.9) / ndd, 0.07, 0.05, 0.12, L0, L1)
		_arc_strip(mb, pave, ctr, R + half, R + half + 6.0, sa, sb, 0.2, 0.02, 0.2, L0, L1)
		_arc_strip(mb, pave, ctr, R - half - 6.0, R - half, sa, sb, 0.2, 0.02, 0.2, L0, L1)
		_arc_strip(mb, curb, ctr, R + half - 0.02, R + half + 0.25, sa, sb, 0.22, 0.02, 0.2, L0, L1)
		_arc_strip(mb, curb, ctr, R - half - 0.25, R - half + 0.02, sa, sb, 0.22, 0.02, 0.2, L0, L1)
	var mi := MeshInstance3D.new()
	mi.mesh = _finish(mb)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)
	# palms and lamps along both pavements (not in roads-only mode)
	var body: StaticBody3D = c.body
	var len := absf(d) * R
	var nlp := 0 if ROADS_ONLY else int(len / 26.0)
	for k in range(0 if ROADS_ONLY else nlp + 1):
		var t := a0 + d * float(k) / maxf(nlp, 1)
		for rr in [R + half + 2.2, R - half - 2.2]:
			var p: Vector2 = ctr + Vector2(cos(t), sin(t)) * rr
			if _overlaps_reserved(Rect2(p - Vector2(2, 2), Vector2(4, 4))): continue
			if is_east and absf(p.y - BR_Z) < BR_HALF + 4.0: continue
			var tt := t + d / maxf(nlp, 1) * 0.5
			var pp: Vector2 = ctr + Vector2(cos(tt), sin(tt)) * rr
			_palm(body, pp, rng, "t")
			# lamp post
			var gy := _ground(p.x, p.y)
			var lp := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.18, 6.0, 0.18)
			lp.mesh = bm
			lp.material_override = _flat(Color("#3b4048"), 0.5, 0.6)
			lp.position = Vector3(p.x, gy + 3.1, p.y)
			w.static_root.add_child(lp)
			var head := MeshInstance3D.new()
			var hb := BoxMesh.new()
			hb.size = Vector3(0.7, 0.2, 0.35)
			head.mesh = hb
			head.material_override = _lamp_mat
			head.position = Vector3(p.x, gy + 6.1, p.y)
			head.rotation.y = -t
			head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			w.static_root.add_child(head)
			CoastProps._box(body, Vector3(0.3, 6.0, 0.3), Vector3(p.x, gy + 3.0, p.y))
	return {"ctr": ctr, "R": R, "a0": a0, "d": d, "half": half}

## Beachfront buildings on the sea side of a boulevard: hotels, cafes, shops and bars with their fronts to the road.
static func _beachfront(c: Dictionary, bv: Dictionary, rng: RandomNumberGenerator, depth := 16.0) -> int:
	var ctr: Vector2 = bv.ctr
	var R: float = bv.R
	var a0: float = bv.a0
	var d: float = bv.d
	var half: float = bv.half
	var front_r := R + half + 6.0 + 4.0                     # past the pavement
	var s := 0.0
	var len := absf(d) * front_r
	var n := 0
	var sgn := signf(d)
	var skipped := 0
	while s < len - 20.0:
		var w := rng.randf_range(15.0, 22.0)
		var t := a0 + sgn * (s + w * 0.5) / front_r
		var dir := Vector2(cos(t), sin(t))
		var front: Vector2 = ctr + dir * front_r
		var yaw := atan2(-dir.x, -dir.y)                    # local +z points to the road (the centre)
		# only where there is land for the whole depth
		if not _overlaps_reserved(_local_rect(front, yaw, w + 2.0, depth + 2.0)) and absf(front.y - 2200.0) > 26.0:
			var roll := rng.randf()
			var kind := "lobby" if roll < 0.4 else ("cafe" if roll < 0.65 else ("bar" if roll < 0.85 else "shop"))
			var floors := 3 + rng.randi() % 3
			if _building(c, front, yaw, w, depth, floors, kind, rng, "", "deco", _ground(front.x, front.y) + 0.12): n += 1
		s += w + 1.5
	return n

## The sand beyond the beachfront: beach bars, loungers with parasols, volleyball nets, and the lifeguard and palms already supplied.
static func _beach_life(c: Dictionary, bv: Dictionary, rng: RandomNumberGenerator) -> void:
	var ctr: Vector2 = bv.ctr
	var R: float = bv.R
	var d: float = bv.d
	var a0: float = bv.a0
	var body: StaticBody3D = c.body
	var sgn := signf(d)
	var r_sand: float = R + float(bv.half) + 6.0 + 4.0 + 16.0 + 8.0
	var len: float = absf(d) * r_sand
	var s := 18.0
	var k := 0
	while s < len - 18.0:
		var t: float = a0 + sgn * s / r_sand
		var dir := Vector2(cos(t), sin(t))
		var p: Vector2 = ctr + dir * r_sand
		if Coast.inland(p.x, p.y) > 6.0 and not _overlaps_reserved(Rect2(p - Vector2(8, 8), Vector2(16, 16))):
			var gy := _ground(p.x, p.y)
			var face := atan2(-dir.x, -dir.y)
			match k % 4:
				0:
					_put("bar", Vector3(p.x, gy, p.y), face + PI, 1.0)
					CoastProps._box(body, Vector3(7.0, 2.7, 7.0), Vector3(p.x, gy + 1.35, p.y), face)
				1:
					_put("net", Vector3(p.x, gy, p.y), face + PI * 0.5, 1.0)
				2:
					_palm(body, p, rng, "t")
					_palm(body, p + Vector2(3.0, 1.0), rng, "m")
				3:
					_put("bar", Vector3(p.x, gy, p.y), face + PI, 1.0)
					CoastProps._box(body, Vector3(7.0, 2.7, 7.0), Vector3(p.x, gy + 1.35, p.y), face)
		k += 1
		s += 34.0

static func _boulevards(c: Dictionary, rng: RandomNumberGenerator) -> void:
	var n := 0
	for spec in [[Vector2(XS[0] - CityData.ARC_STUB, ZS[0]), Vector2(XS[0] - CityData.ARC_STUB, ZS[2]), 250.0, -1.0], [Vector2(XS[4] + CityData.ARC_STUB, ZS[0]), Vector2(XS[4] + CityData.ARC_STUB, ZS[2]), 250.0, 1.0]]:
		var bv := _boulevard(c, spec[0], spec[1], spec[2], spec[3], rng)
		if not ROADS_ONLY:
			n += _beachfront(c, bv, rng)
			_beach_life(c, bv, rng)
	print("miami: %d beachfront buildings on the boulevards" % n)


# ------------------------------------------------------------------ the fixed bridge over the sea channel

const BR_Z := 2200.0              # the channel's centre line
const BR_HALF := 66.0             # half length of the ramp-bridge-ramp along the road
const BR_H := 4.8                 # road height at the middle (boats pass under with ~4 m to spare)

## Road height of the bridge at world z (0 on the ground, rising smoothly to BR_H over the channel).
static func _bridge_h(z: float) -> float:
	return BR_H * smoothstep(0.0, 1.0, clampf(1.0 - absf(z - BR_Z) / BR_HALF, 0.0, 1.0))

## The east boulevard rises over the sea channel on a fixed bridge: a gentle ramp up, a concrete deck with rails, a ramp down. The
## underneath is clear over the water, embankment on the land; the whole thing is solid.
static func _bridge_section(c: Dictionary, bv: Dictionary, a0: float, a1: float) -> void:
	var w: World = c.w
	var ctr: Vector2 = bv.ctr
	var R: float = bv.R
	var half: float = bv.half
	var asphalt: Material = RoadKit._plain_mat if RoadKit._plain_mat != null else _flat(Color("#3a3d42"), 0.9)
	var white := _flat(Color("#f4f4ee"), 0.8)
	var yellow := _flat(Color("#f2c230"), 0.8)
	var pave := _surface_mat("walk", "PavingStones136", 0.5, Color(1.15, 1.1, 1.0), 0.85)
	var concrete := _flat(Color(0.74, 0.73, 0.7), 0.9)
	var rail := _flat(Color("#eceae2"), 0.6)
	var vis := {}
	var L0 := R - half - 7.0
	var L1 := R + half + 7.0
	_arc_strip(vis, asphalt, ctr, R - half, R + half, a0, a1, 0.05, 0.02, 0.12, L0, L1, true)
	_arc_strip(vis, white, ctr, R - half + 0.35, R - half + 0.55, a0, a1, 0.07, 0.02, 0.12, L0, L1, true)
	_arc_strip(vis, white, ctr, R + half - 0.55, R + half - 0.35, a0, a1, 0.07, 0.02, 0.12, L0, L1, true)
	var nd := int(absf(a1 - a0) * R / 6.0)
	for k in range(nd):
		if k % 2 == 0:
			_arc_strip(vis, yellow, ctr, R - 0.14, R + 0.14, a0 + (a1 - a0) * (k + 0.1) / nd, a0 + (a1 - a0) * (k + 0.9) / nd, 0.07, 0.05, 0.12, L0, L1, true)
	_arc_strip(vis, pave, ctr, R + half, R + half + 6.0, a0, a1, 0.2, 0.02, 0.2, L0, L1, true)
	_arc_strip(vis, pave, ctr, R - half - 6.0, R - half, a0, a1, 0.2, 0.02, 0.2, L0, L1, true)
	var vmi := MeshInstance3D.new()
	vmi.mesh = _finish(vis)
	vmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(vmi)
	# the solid body: top, both sides, underside and rails, built row by row
	var sol := {}
	var step := 0.02
	var n := int(ceil(absf(a1 - a0) / step))
	var edges := [R - half - 6.3, R - half, R + half, R + half + 6.3]
	var tops := [0.18, 0.03, 0.18]                       # solid tops under pavement, road, pavement (just below the visual strips)
	for k in range(n):
		var t0 := a0 + (a1 - a0) * k / n
		var t1 := a0 + (a1 - a0) * (k + 1) / n
		var z0 := ctr.y + sin(t0) * R
		var z1 := ctr.y + sin(t1) * R
		var h0 := _bridge_h(z0)
		var h1 := _bridge_h(z1)
		var over0 := absf(z0 - BR_Z) < 12.0
		var over1 := absf(z1 - BR_Z) < 12.0
		var b0 := (h0 - 1.0) if over0 else -0.4
		var b1 := (h1 - 1.0) if over1 else -0.4
		var p := func(t: float, r: float, y: float) -> Vector3: return Vector3(ctr.x + cos(t) * r, y, ctr.y + sin(t) * r)
		# tops (faces up, runs with increasing angle: winding depends on the direction)
		var flip := a1 < a0
		for e in range(3):
			var ra: float = edges[e]
			var rb: float = edges[e + 1]
			var A: Vector3 = p.call(t0, ra, h0 + float(tops[e]))
			var B: Vector3 = p.call(t0, rb, h0 + float(tops[e]))
			var C: Vector3 = p.call(t1, rb, h1 + float(tops[e]))
			var D: Vector3 = p.call(t1, ra, h1 + float(tops[e]))
			if flip: _quad(sol, concrete, A, B, C, D, 0.2)
			else: _quad(sol, concrete, D, C, B, A, 0.2)
		# curb faces between the road and the pavements
		for er in [1, 2]:
			var rr: float = edges[er]
			var hi_a: Vector3 = p.call(t0, rr, h0 + 0.18)
			var hi_b: Vector3 = p.call(t1, rr, h1 + 0.18)
			var lo_a: Vector3 = p.call(t0, rr, h0 + 0.03)
			var lo_b: Vector3 = p.call(t1, rr, h1 + 0.03)
			_quad(sol, concrete, hi_a, hi_b, lo_b, lo_a, 0.2)
			_quad(sol, concrete, lo_a, lo_b, hi_b, hi_a, 0.2)
		# outer sides (down to the underside) and the underside
		for side in [0, 1]:
			var rs: float = edges[0] if side == 0 else edges[3]
			var ta: Vector3 = p.call(t0, rs, h0 + 0.18)
			var tb: Vector3 = p.call(t1, rs, h1 + 0.18)
			var ba: Vector3 = p.call(t0, rs, b0)
			var bb: Vector3 = p.call(t1, rs, b1)
			if (side == 0) == flip: _quad(sol, concrete, ta, tb, bb, ba, 0.2)
			else: _quad(sol, concrete, tb, ta, ba, bb, 0.2)
			# the rail: a thin wall along the outer edge, both faces
			var ra2: Vector3 = ta + Vector3(0, 1.1, 0)
			var rb2: Vector3 = tb + Vector3(0, 1.1, 0)
			_quad(sol, rail, ta, tb, rb2, ra2, 0.5)
			_quad(sol, rail, tb, ta, ra2, rb2, 0.5)
		var u0: Vector3 = p.call(t0, edges[0], b0)
		var u1: Vector3 = p.call(t0, edges[3], b0)
		var u2: Vector3 = p.call(t1, edges[3], b1)
		var u3: Vector3 = p.call(t1, edges[0], b1)
		if flip: _quad(sol, concrete, u3, u2, u1, u0, 0.2)
		else: _quad(sol, concrete, u0, u1, u2, u3, 0.2)
	var mesh := _finish(sol)
	var smi := MeshInstance3D.new()
	smi.mesh = mesh
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(smi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	cs.shape.backface_collision = true
	(c.body as StaticBody3D).add_child(cs)
