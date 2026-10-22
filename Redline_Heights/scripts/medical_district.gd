class_name MedicalDistrict
extends RefCounted
## Block A2 (x 200..400, z 2200..2450): the Redline Medical District. A hospital at the back of a palm-lined pedestrian avenue that runs in from
## the north road, a fountain plaza, rows of shops / cafes facing the three outer roads (doors toward the street, wide pavements in front),
## street stalls, benches, lamps, an office tower, parked cars, ambulances and people on the pavements.
## Downloaded models (assets/district/, see CREDITS.md): hospital, corner shop, Cafe Nikki, old curiosity shop, bhelpuri stall, office skyscraper.

const D := "res://assets/district/"
const X0 := 206.7
const X1 := 393.3
const Z0 := 2206.7
const Z1 := 2443.3
const CX := 300.0
const Y := 0.22
const PAVE_N := 8.0                 # pavement depth in front of the north shop row
const PAVE_SIDE := 8.0
const PAVE_S := 6.0
const AVE := 8.0                    # half width of the avenue

## yaw offset (radians) that makes each model's door / shopfront face +Z at yaw 0 (tuned by looking at it)
const FRONT := {"hospital": 0.0, "shop": 0.0, "cafe_nikki": 0.0, "the_old_curiosity_shop_2024": 0.0,
	"singapore_office_skyscraper_free": 0.0, "bhelpuri_shop_by_ajay_indian_local_shop": 0.0,
	"brooklyn_street_row_buildings_low_poly": PI * 0.5, "modern_tower_office_apartment_house_home": 0.0, "food_kiosk_props": 0.0}

static var _cache := {}

static var _shapes := {}

## A material that glows warm at night through its own texture (a shop-front glass whose materials carry no window name).
static func _glow_mat(m: BaseMaterial3D, gain: float) -> void:
	if m == null or m.emission_enabled: return
	m.emission_enabled = true
	if m.albedo_texture != null:
		m.emission_texture = m.albedo_texture
		m.emission = CityLights.WARM
	else:
		m.emission = Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b).lerp(CityLights.WARM, 0.5)
	m.emission_energy_multiplier = 0.0
	CityLights._mats.append({"m": m, "gain": gain, "base": 1.0})

## Night lighting for each downloaded building: its real windows glow (see CityLights); chosen per model because the materials carry no window names.
## Fixed-colour glow for the black, untextured window panes of a model (all lit, as a hospital or an office block would be at night).
static func _glow_black(mesh: ArrayMesh, color: Color, gain: float, max_v := 0.06, only: Array = []) -> void:
	for i in range(mesh.get_surface_count()):
		var m := mesh.surface_get_material(i) as BaseMaterial3D
		if m == null or m.albedo_texture != null or m.emission_enabled: continue
		if not only.is_empty() and not (String(m.resource_name) in only): continue
		var c := m.albedo_color
		if maxf(c.r, maxf(c.g, c.b)) > max_v: continue
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.0
		CityLights._mats.append({"m": m, "gain": gain, "base": 1.0})

static func _night(name: String, mesh: Mesh) -> void:
	var am := mesh as ArrayMesh
	if am == null: return
	if name.begins_with("singapore"):
		CityLights.apply(mesh, "emissive", 1.0)
	elif name.begins_with("amelinco"):
		CityLights.apply_shader(mesh, {"mode": 0, "thr": 0.22, "lit_frac": 0.3, "gain": 0.55})
	elif name.begins_with("cafe_nikki"):
		for i in range(am.get_surface_count()):
			var m := am.surface_get_material(i) as BaseMaterial3D
			if m != null and (String(m.resource_name) == "lambert3" or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED): _glow_mat(m, 1.3)
	elif name == "hospital":
		_glow_black(am, Color(0.95, 0.97, 1.0), 1.0, 0.36, ["Materiais.024"])
	elif name.begins_with("cook_ville"):
		_glow_black(am, Color(1.0, 0.85, 0.6), 1.0)
	elif name.begins_with("supermarket"):
		CityLights.apply(mesh, "glass", 1.3)

## The model baked ONCE at its own size (shared by every placement), plus the scale that makes its larger horizontal side `width` metres.
## {mesh, size (at that width), s}
static func _bake(file: String, width: float) -> Dictionary:
	var path := file if file.begins_with("res://") else D + file + ".glb"
	if not _cache.has(path):
		var raw: Dictionary = {}
		if path.ends_with(".res"):
			var rm := load(path) as Mesh
			if rm != null:
				var bb := rm.get_aabb()
				raw = {"mesh": rm, "size": bb.size}
				# the mesh keeps its model-space origin: recentre by shifting through the miny / placement (centre assumed at origin)
		else:
			raw = Miami._bake(path, "", 0.0, 1.0)
		if raw.is_empty(): print("MedicalDistrict: missing ", file)
		if not raw.is_empty():
			# true lowest vertex (a model's bounds can sit below its real floor): stand that on the ground
			var lo := 1e12
			for si in range((raw.mesh as ArrayMesh).get_surface_count()):
				for v in ((raw.mesh as ArrayMesh).surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					lo = minf(lo, v.y)
			raw["miny"] = lo
		if not raw.is_empty(): _night(path.get_file().get_basename(), raw.mesh)
		_cache[path] = raw
	var raw2: Dictionary = _cache[path]
	if raw2.is_empty(): return {}
	var sz: Vector3 = raw2.size
	var s := width / maxf(sz.x, sz.z)
	return {"mesh": raw2.mesh, "size": sz * s, "s": s, "path": path, "miny": float(raw2.get("miny", 0.0)) * s, "rawsize": sz}

## One exact trimesh collision shape per model (built once, scaled per placement).
static func _shape(path: String, mesh: Mesh) -> ConcavePolygonShape3D:
	if not _shapes.has(path):
		var ts := mesh.create_trimesh_shape()
		ts.backface_collision = true
		_shapes[path] = ts
	return _shapes[path]

## Put a model on the ground at p (x, z) so that its front faces world direction `face` (0 = +z, PI = -z, PI/2 = +x, -PI/2 = -x).
## `lift` raises it (the hospital slab is 0.45 m thick). Solid as the model's own triangles (`trimesh`) or one box.
static func place(w: World, body: StaticBody3D, file: String, width: float, p: Vector2, face: float, lift := 0.0, trimesh := true, shrink := 1.0) -> Dictionary:
	var b := _bake(file, width)
	if b.is_empty(): return {}
	var yaw := face - float(FRONT.get(file, 0.0))
	var sc: float = b.s
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh
	mi.name = file.get_file().get_basename()
	mi.position = Vector3(p.x, Y + lift - float(b.miny), p.y)
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * sc
	w.static_root.add_child(mi)
	var sz: Vector3 = b.size
	if trimesh:
		var cs := CollisionShape3D.new()
		cs.shape = _shape(String(b.path), b.mesh)
		cs.transform = mi.transform
		body.add_child(cs)
	else:
		CoastProps._box(body, Vector3(sz.x * shrink, sz.y, sz.z * shrink), Vector3(p.x, Y + lift + sz.y * 0.5, p.y), yaw)
	return {"size": sz, "node": mi, "yaw": yaw}

static func _glow(w: World, pos: Vector3, rng_m: float, color: Color, energy: float) -> void:
	var ol := OmniLight3D.new()
	ol.position = pos
	ol.omni_range = rng_m
	ol.light_color = color
	ol.shadow_enabled = false
	w.static_root.add_child(ol)
	CityLights.register_light(ol, energy)

static var _lt := 0
static func _lap(n: String) -> void:
	var t := Time.get_ticks_msec()
	print("TIMING   med ", n, " ", t - _lt)
	_lt = t

static func build(w: World) -> void:
	_lt = Time.get_ticks_msec()
	print("MedicalDistrict: building block A2...")
	Miami._prep_props()
	var body := StaticBody3D.new()
	body.name = "MedicalDistrictBody"
	body.collision_layer = 1
	w.static_root.add_child(body)
	Miami.solid_body = body
	var rng := RandomNumberGenerator.new()
	rng.seed = 2210
	var mb := {}
	var paving := IslandSkyscrapers._surface_mat("Concrete034", 0.2, Color(0.66, 0.66, 0.68), 0.85)
	var cobble := IslandSkyscrapers._surface_mat("PavingStones070", 0.7, Color(0.85, 0.85, 0.85), 0.8)
	var plazat := IslandSkyscrapers._surface_mat("Tiles074", 1.1, Color(0.85, 0.85, 0.85), 0.45)
	var terr := IslandSkyscrapers._surface_mat("Terrazzo003", 0.4, Color(1.05, 1.02, 0.95), 0.5)
	var lawn := StandardMaterial3D.new()
	lawn.albedo_texture = load("res://assets/golf/tex/Grass001_Color.jpg") as Texture2D
	lawn.albedo_color = Color(0.72, 0.86, 0.58)
	lawn.roughness = 0.95
	lawn.uv1_world_triplanar = true
	lawn.uv1_scale = Vector3.ONE * 0.2
	var kerb := IslandSkyscrapers._flat(Color(0.62, 0.62, 0.6), 0.8)

	# ---- ground: paved all over (a campus, not a park), lawn beds only where they are planted, the avenue and the fountain plaza
	var gy := Y + 0.03
	_slab(mb, body, paving, X0, Z0, X1, Z1, Y, Y + 0.02)
	_slab(mb, body, terr, CX - AVE, Z0, CX + AVE, 2362.0, Y + 0.02, gy + 0.005)    # the avenue
	var beds: Array = []   # the two lawn parks beside the avenue
	for r in beds:
		var rr: Rect2 = r
		Miami._box(mb, kerb, Vector3(rr.position.x - 0.3, Y + 0.02, rr.position.y - 0.3), Vector3(rr.end.x + 0.3, Y + 0.09, rr.end.y + 0.3))
		Miami._box(mb, lawn, Vector3(rr.position.x, Y + 0.09, rr.position.y), Vector3(rr.end.x, Y + 0.11, rr.end.y))
	# marked walkways for travelling round the park: cross street through the plaza and a path along each tower row
	_slab(mb, body, cobble, X0, 2287.0, X1, 2293.0, Y + 0.02, gy + 0.004)
	_slab(mb, body, cobble, 224.0, Z0, 230.0, Z1, Y + 0.02, gy + 0.004)
	_slab(mb, body, cobble, 370.0, Z0, 376.0, Z1, Y + 0.02, gy + 0.004)
	var plaza_c := Vector2(CX, 2290.0)
	_disc(w, cobble, plaza_c, 17.0, Y + 0.045)
	_disc(w, plazat, plaza_c, 13.0, Y + 0.05)
	var fb: Dictionary = Miami._bake("res://assets/golf/props/fountain_clover.glb", "", 0.0, 2.1)
	if not fb.is_empty():
		var fmi := MeshInstance3D.new()
		fmi.mesh = fb.mesh
		fmi.position = Vector3(plaza_c.x, Y + 0.07, plaza_c.y)
		w.static_root.add_child(fmi)
		CoastProps._box(body, Vector3(fb.size.x * 0.92, fb.size.y * 0.5, fb.size.z * 0.92), Vector3(plaza_c.x, Y + 0.07 + fb.size.y * 0.25, plaza_c.y))
		GolfClub._fountain_jets(w, Vector3(plaza_c.x, Y + 0.07, plaza_c.y), float(fb.size.y))

	_lap("ground")
	# ---- hospital at the back of the avenue, its entrance and car park facing the avenue
	var hp := Vector2(CX, 2392.0)
	place(w, body, "hospital", 70.0, hp, PI * 0.5, -0.4, true)
	_ambulance_bay(w, body, mb)

	_lap("hospital")
	# ---- shop streets: two long rows (the Brooklyn terrace, doors on the pavement side) with a cafe at each end, all facing the north road
	var zr := Z0 + PAVE_N + 10.0
	place(w, body, "brooklyn_street_row_buildings_low_poly", 64.0, Vector2(260.0, zr), PI)
	place(w, body, "brooklyn_street_row_buildings_low_poly", 64.0, Vector2(340.0, zr), PI)
	place(w, body, "cafe_nikki", 11.0, Vector2(221.5, Z0 + PAVE_N + 6.0), PI)
	place(w, body, "cafe_nikki", 11.0, Vector2(378.5, Z0 + PAVE_N + 6.0), PI)
	# IT park: three office towers round the back, each facing the avenue / plaza
	place(w, body, "modern_tower_office_apartment_house_home", 52.0, Vector2(244.0, 2392.0), PI * 0.5)
	place(w, body, "singapore_office_skyscraper_free", 38.0, Vector2(362.0, 2420.0), -PI * 0.5)
	place(w, body, "modern_tower_office_apartment_house_home", 34.0, Vector2(358.0, 2372.0), -PI * 0.5)
	# south road: a shop terrace and cafes, doors on the south pavement
	place(w, body, "brooklyn_street_row_buildings_low_poly", 56.0, Vector2(252.0, 2433.0), 0.0)
	place(w, body, "cafe_nikki", 11.0, Vector2(300.0, 2433.0), 0.0)
	place(w, body, "shop", 12.0, Vector2(316.0, 2433.0), 0.0)
	place(w, body, "cafe_nikki", 11.0, Vector2(332.0, 2433.0), 0.0)
	place(w, body, "modern_tower_office_apartment_house_home", 44.0, Vector2(250.0, 2322.0), PI * 0.5)
	place(w, body, "modern_tower_office_apartment_house_home", 46.0, Vector2(256.0, 2260.0), PI * 0.5)
	place(w, body, "modern_tower_office_apartment_house_home", 46.0, Vector2(346.0, 2260.0), -PI * 0.5)
	place(w, body, "modern_tower_office_apartment_house_home", 40.0, Vector2(352.0, 2318.0), -PI * 0.5)

	_lap("shops+towers")
	# ---- street stalls, kiosks and vending machines
	for st in [[Vector2(X0 + 3.5, 2290.0), -PI * 0.5], [Vector2(X1 - 3.5, 2290.0), PI * 0.5], [Vector2(X0 + 3.5, 2340.0), -PI * 0.5]]:
		place(w, body, "bhelpuri_shop_by_ajay_indian_local_shop", 2.4, st[0], st[1], 0.0, false)
	for kp in [[Vector2(300.0 - 24.0, 2300.0), 0.0], [Vector2(300.0 + 24.0, 2300.0), 0.0]]:
		place(w, body, "food_kiosk_props", 3.4, kp[0], float(kp[1]), -0.12, false)
	for vm in [Vector2(226.0, 2237.5), Vector2(292.5, 2237.5), Vector2(307.5, 2237.5), Vector2(374.0, 2237.5)]:
		place(w, body, "psx_-_vending_machine", 1.0, vm, PI, 0.0, false)

	_lap("stalls")
	# ---- trees along the avenue, trees and benches in the parks, bins and mailboxes on the pavements
	for k in range(0, 8):
		var zz := Z0 + PAVE_N + 16.0 + k * 11.0
		if absf(zz - plaza_c.y) < 20.0: continue
		for sx in [-1.0, 1.0]:
			Miami._palm(body, Vector2(CX + sx * (AVE - 1.2), zz), rng, "m")
	for r in beds:
		var rr: Rect2 = r
		for k in range(0, 6):
			Miami._palm(body, Vector2(rr.position.x + 8.0 + k * 10.5, rr.position.y + 6.0), rng, "m" if k % 2 == 0 else "t")
			Miami._palm(body, Vector2(rr.position.x + 8.0 + k * 10.5, rr.end.y - 6.0), rng, "m" if k % 2 == 1 else "t")
		for k in range(0, 3):
			Miami._put("bench", Vector3(rr.position.x + 14.0 + k * 19.0, Y + 0.11, rr.position.y + 22.0), PI, 1.0)
			Miami._put("bench", Vector3(rr.position.x + 14.0 + k * 19.0, Y + 0.11, rr.end.y - 22.0), 0.0, 1.0)
			Miami._put("flowerbed", Vector3(rr.position.x + 23.0 + k * 19.0, Y + 0.11, rr.position.y + 46.0), 0.0, 0.25)
	for a in range(4):
		var ang := a * PI * 0.5 + PI * 0.25
		Miami._put("bench", Vector3(plaza_c.x + cos(ang) * 11.5, Y + 0.09, plaza_c.y + sin(ang) * 11.5), -ang - PI * 0.5, 1.0)
	for bn in [Vector2(CX - 7.2, 2250.0), Vector2(CX + 7.2, 2250.0), Vector2(CX - 7.2, 2340.0), Vector2(CX + 7.2, 2340.0), Vector2(230.0, Z0 + 1.2), Vector2(370.0, Z0 + 1.2)]:
		Miami._put("bins", Vector3(bn.x, Y + 0.04, bn.y), 0.0, 1.0)
	Miami._put("busstop", Vector3(X0 + 3.0, Y + 0.04, 2315.0), PI * 0.5, 1.0)
	Miami._put("busstop", Vector3(X1 - 3.0, Y + 0.04, 2315.0), -PI * 0.5, 1.0)
	for mp in [Vector2(X0 + 2.0, 2240.0), Vector2(X1 - 2.0, 2240.0)]:
		Miami._put("mailbox", Vector3(mp.x, Y + 0.04, mp.y), 0.0, 1.0)
	# lamps: along the avenue and the south pavement
	for lz in [2252.0, 2328.0, 2352.0]:
		IslandSkyscrapers._add_parking_floodlight(w, body, Vector2(CX - 9.5, lz), Vector2(CX, lz))
		IslandSkyscrapers._add_parking_floodlight(w, body, Vector2(CX + 9.5, lz), Vector2(CX, lz))
	for lx in [226.0, 276.0, 324.0, 374.0]:
		IslandSkyscrapers._add_parking_floodlight(w, body, Vector2(lx, Z1 - 2.5), Vector2(lx, Z1 - 20.0))

	_lap("trees+lamps")
	# ---- district sign over the avenue entrance

	# ---- night: shop-front glow along the north rows, hospital entrance lights
	for sx in [221.5, 244.0, 276.0, 324.0, 356.0, 378.5]:
		_glow(w, Vector3(sx, Y + 3.2, Z0 + PAVE_N - 0.5), 11.0, Color(1.0, 0.82, 0.55), 1.6)
	for hx in [-22.0, -8.0, 8.0, 22.0]:
		_glow(w, Vector3(CX + hx, Y + 4.2, 2363.5), 15.0, Color(0.92, 1.0, 0.96), 2.0)
	_glow(w, Vector3(CX, Y + 9.0, 2360.0), 22.0, Color(1.0, 0.95, 0.9), 1.6)

	var mi := MeshInstance3D.new()
	mi.mesh = Miami._finish(mb)
	w.static_root.add_child(mi)
	Miami._flush(w)
	_lap("batch")
	_people_and_cars(w, hp)
	_lap("people")
	w.add_poi("medical", "REDLINE HEALTH & IT PARK", Vector3(CX, Y + 1.0, 2230.0))
	print("MedicalDistrict: done.")

## Covered ambulance bay on the west end of the hospital front: red-striped canopy on pillars, EMERGENCY sign, painted bays.
static func _ambulance_bay(w: World, body: StaticBody3D, mb: Dictionary) -> void:
	var white := IslandSkyscrapers._flat(Color(0.93, 0.94, 0.95), 0.6)
	var asph := IslandSkyscrapers._flat(Color(0.16, 0.17, 0.19), 0.9)
	var red := IslandSkyscrapers._flat(Color(0.82, 0.08, 0.10), 0.5)
	var x0 := CX - 30.0
	var x1 := CX - 12.0
	var z0 := 2364.0
	var z1 := 2376.0
	Miami._box(mb, asph, Vector3(x0 - 1.0, Y + 0.02, z0 - 1.0), Vector3(x1 + 1.0, Y + 0.05, z1 + 1.0))
	Miami._box(mb, red, Vector3(x0 - 1.0, Y + 0.05, z0 - 1.0), Vector3(x1 + 1.0, Y + 0.06, z0 - 0.7))
	for bx in [CX - 26.0, CX - 17.5]:
		Miami._box(mb, white, Vector3(bx - 2.0, Y + 0.05, z0 + 1.2), Vector3(bx - 1.85, Y + 0.06, z1 - 1.2))
		Miami._box(mb, white, Vector3(bx + 1.85, Y + 0.05, z0 + 1.2), Vector3(bx + 2.0, Y + 0.06, z1 - 1.2))

## Ground helipad next to the hospital: a round paved pad with an H and a medevac helicopter you can fly (E).
static func _helipad(w: World, body: StaticBody3D, mb: Dictionary, c: Vector2) -> void:
	var asph := IslandSkyscrapers._flat(Color(0.20, 0.21, 0.23), 0.9)
	var yel := IslandSkyscrapers._flat(Color(0.95, 0.80, 0.12), 0.6)
	_disc(w, asph, c, 11.0, Y + 0.045)
	_disc(w, yel, c, 10.2, Y + 0.05)
	_disc(w, asph, c, 9.6, Y + 0.055)
	var t := Label3D.new()
	t.text = "H"
	t.font = load("res://assets/fonts/Oswald.ttf") as Font
	t.font_size = 220
	t.pixel_size = 0.012
	t.modulate = Color(1.0, 1.0, 1.0)
	t.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	t.position = Vector3(c.x, Y + 0.09, c.y)
	w.static_root.add_child(t)
	var ch := HelipadChopper.new()
	ch.setup("hospital")
	w.add_child(ch)
	ch.global_position = Vector3(c.x, Y + 1.95, c.y)
	ch.rotation.y = PI * 0.5
	for k in range(4):
		var a := k * PI * 0.5 + PI * 0.25
		_glow(w, Vector3(c.x + cos(a) * 9.5, Y + 0.6, c.y + sin(a) * 9.5), 7.0, Color(1.0, 0.85, 0.3), 1.2)

static func _slab(mb: Dictionary, body: StaticBody3D, mat: Material, x0: float, z0: float, x1: float, z1: float, y0: float, y1: float) -> void:
	Miami._box(mb, mat, Vector3(x0, y0, z0), Vector3(x1, y1, z1))
	CoastProps._box(body, Vector3(x1 - x0, 0.06, z1 - z0), Vector3((x0 + x1) * 0.5, y1 - 0.03, (z0 + z1) * 0.5))

static func _disc(w: World, mat: Material, c: Vector2, r: float, y: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.06
	cm.radial_segments = 48
	cm.rings = 1
	cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = Vector3(c.x, y, c.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

static func _sign_gantry(w: World, body: StaticBody3D, mb: Dictionary) -> void:
	var steel := IslandSkyscrapers._flat(Color(0.22, 0.24, 0.27), 0.45, 0.6)
	var plate := IslandSkyscrapers._flat(Color(0.05, 0.30, 0.22), 0.4, 0.2)
	var white := IslandSkyscrapers._flat(Color(0.95, 0.95, 0.92), 0.5)
	var zz := Z0 + PAVE_N + 1.0
	for sx in [-1.0, 1.0]:
		Miami._box(mb, steel, Vector3(CX + sx * (AVE - 0.5) - 0.25, Y, zz - 0.25), Vector3(CX + sx * (AVE - 0.5) + 0.25, Y + 9.0, zz + 0.25))
		CoastProps._box(body, Vector3(0.5, 9.0, 0.5), Vector3(CX + sx * (AVE - 0.5), Y + 4.5, zz))
	Miami._box(mb, steel, Vector3(CX - AVE, Y + 6.8, zz - 0.3), Vector3(CX + AVE, Y + 9.4, zz + 0.3))
	Miami._box(mb, plate, Vector3(CX - AVE + 0.3, Y + 7.0, zz - 0.34), Vector3(CX + AVE - 0.3, Y + 9.2, zz - 0.3))
	Miami._box(mb, white, Vector3(CX - 0.5, Y + 8.0, zz - 0.36), Vector3(CX + 0.5, Y + 8.35, zz - 0.34))
	Miami._box(mb, white, Vector3(CX - 0.18, Y + 7.6, zz - 0.36), Vector3(CX + 0.18, Y + 8.7, zz - 0.34))
	var t := Label3D.new()
	t.text = "REDLINE HEALTH & IT PARK"
	t.font = load("res://assets/fonts/Oswald.ttf") as Font
	t.font_size = 80
	t.pixel_size = 0.0060
	t.modulate = Color(0.96, 0.97, 0.94)
	t.outline_size = 5
	t.outline_modulate = Color(0.02, 0.12, 0.08)
	t.rotation.y = PI
	t.position = Vector3(CX, Y + 8.55, zz - 0.4)
	w.static_root.add_child(t)
	_glow(w, Vector3(CX, Y + 6.2, zz - 1.5), 12.0, Color(0.9, 1.0, 0.95), 1.4)

static func _people_and_cars(w: World, hp: Vector2) -> void:
	var py := Y + 0.04
	# walkers on the north and south pavements, people chatting at the shops, doctors and a nurse at the hospital
	var north: Array = [Vector3(228.0, py, Z0 + 3.5), Vector3(282.0, py, Z0 + 3.5)]
	LazyCars.add_npc(w, "npc_luiz", Vector3(240.0, py, Z0 + 3.5), PI * 0.5, "Idle", north)
	var north2: Array = [Vector3(318.0, py, Z0 + 5.0), Vector3(372.0, py, Z0 + 5.0)]
	LazyCars.add_npc(w, "npc_ch21", Vector3(330.0, py, Z0 + 5.0), -PI * 0.5, "Idle", north2)
	var south: Array = [Vector3(230.0, py, Z1 - 3.0), Vector3(370.0, py, Z1 - 3.0)]
	LazyCars.add_npc(w, "npc_luiz", Vector3(300.0, py, Z1 - 3.0), PI * 0.5, "Idle", south)
	var west: Array = [Vector3(X0 + 4.0, py, 2215.0), Vector3(X0 + 4.0, py, 2300.0)]
	LazyCars.add_npc(w, "npc_ch21", Vector3(X0 + 4.0, py, 2250.0), 0.0, "Idle", west)
	LazyCars.add_npc(w, "npc_ch21", Vector3(CX + 3.0, py, 2276.0), PI * 0.75, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_luiz", Vector3(CX + 4.4, py, 2277.2), -PI * 0.25, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_luiz", Vector3(252.0, py, Z0 + 5.0), PI, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_ch21", Vector3(254.0, py, Z0 + 5.6), PI * 0.5, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_nurse", Vector3(hp.x - 6.0, py, 2358.0), PI, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_doctor", Vector3(hp.x - 4.6, py, 2359.0), PI * 0.5, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_doctor", Vector3(CX - 21.5, py, 2363.0), 0.0, "Idle")
	LazyCars.add_npc(w, "npc_ch21", Vector3(CX - 24.0, py, 2290.0), -PI * 0.5, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_luiz", Vector3(CX + 24.0, py, 2290.0), PI * 0.5, "UAL_Idle_Talking")
	# parked cars in the hospital car park and two ambulances at the emergency end
	var cars := [["hatch", Vector2(CX + 13.9, 2366.3), PI], ["saloon", Vector2(CX + 6.9, 2366.3), 0.0], ["taxi", Vector2(CX + 10.4, 2366.3), PI], ["ambulance", Vector2(CX - 20.0, 2379.0), PI * 0.5], ["ambulance", Vector2(CX - 10.0, 2379.0), PI * 0.5]]
	for c in cars:
		LazyCars.add(w, c[0], Vector3(c[1].x, Y + Car.RIDE + 0.2, c[1].y), c[2])


# ------------------------------------------------------------------ police station (block B2)

const POLICE_RES := "res://assets/district/police_station_clean.res"

## Retextured copy of the police station mesh: plain white / grey materials get real CC0 surface textures (triplanar, metres).
static func police_mesh() -> ArrayMesh:
	var src := load(POLICE_RES) as ArrayMesh
	if src == null: return null
	var m := src.duplicate() as ArrayMesh
	var wall := IslandSkyscrapers._surface_mat("Facade005", 0.5, Color(1.0, 1.0, 1.0), 0.6)
	var conc := IslandSkyscrapers._surface_mat("Concrete042A", 0.35, Color(1.25, 1.25, 1.25), 0.85)
	var roof := IslandSkyscrapers._surface_mat("Asphalt031", 0.4, Color(0.8, 0.8, 0.82), 0.9)
	var stone := IslandSkyscrapers._surface_mat("Bricks076A", 0.4, Color(1.15, 1.15, 1.15), 0.85)
	var map := {"material": wall, "Cladding_Stucco_White": conc, "Cladding_Stucco_White_1": conc, "Color_003": conc, "Color_001": conc,
		"Charcoal_1": roof, "Charcoal": roof, "Gainsboro": stone, "Concrete-rough": stone, "material_1": conc, "Color_002": conc, "Color_005": conc}
	for i in range(m.get_surface_count()):
		var mat := m.surface_get_material(i)
		if mat != null and map.has(String(mat.resource_name)):
			m.surface_set_material(i, map[String(mat.resource_name)])
	return m
