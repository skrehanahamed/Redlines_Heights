class_name GolfInterior
extends RefCounted
## Furnishing of the Redline Golf Club clubhouse hall (see golf_club.gd): reception, lounge with wall TVs, bar, dining tables, pro shop with
## club racks and golf bags, trophy cabinet, an indoor putting mat, chandeliers and floor lamps that switch on at night.
## Props are CC0 models from assets/golf/props (Quaternius / Kenney / others, see CREDITS.md), scaled to real-world sizes. Everything is solid.

const P := "res://assets/golf/props/"
const HALL := Rect2(84.2, 2328.6, 25.0, 17.0)       # walkable floor of the hall (x, z)
static var _cache := {}

static func _bake(file: String, scale: float) -> Dictionary:
	var k := "%s|%s" % [file, scale]
	if not _cache.has(k):
		_cache[k] = Miami._bake(P + file, "", 0.0, scale)
	return _cache[k]

## Place a prop standing on the floor at p (x, z) with yaw; solid unless `solid` is false. Returns the instance.
static func prop(w: World, body: StaticBody3D, file: String, scale: float, p: Vector3, yaw: float, solid := true, grow := 1.0) -> MeshInstance3D:
	var b := _bake(file, scale)
	if b.is_empty():
		print("GolfInterior: missing ", file)
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh
	mi.position = p
	mi.rotation.y = yaw
	w.static_root.add_child(mi)
	if solid:
		var sz: Vector3 = b.size
		CoastProps._box(body, Vector3(maxf(sz.x * grow, 0.1), sz.y, maxf(sz.z * grow, 0.1)), p + Vector3(0.0, sz.y * 0.5, 0.0), yaw)
	return mi

static func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	return IslandSkyscrapers._flat(c, rough, metal)

static func _light(w: World, pos: Vector3, rng_m: float, color: Color, energy: float) -> void:
	var ol := OmniLight3D.new()
	ol.position = pos
	ol.omni_range = rng_m
	ol.light_color = color
	ol.shadow_enabled = false
	w.static_root.add_child(ol)
	CityLights.register_light(ol, energy)

static func build(w: World, body: StaticBody3D, mb: Dictionary, y: float) -> void:
	var wood := _mat(Color(0.30, 0.17, 0.09), 0.45, 0.1)
	var wood2 := _mat(Color(0.42, 0.26, 0.13), 0.5, 0.1)
	var gold := _mat(Color(0.88, 0.70, 0.28), 0.22, 0.95)
	var dark := _mat(Color(0.06, 0.06, 0.07), 0.4, 0.5)
	var granite := IslandSkyscrapers._surface_mat("Terrazzo003", 0.4, Color(0.25, 0.25, 0.28), 0.3)
	var rug_a := IslandSkyscrapers._flat(Color(0.45, 0.07, 0.10), 0.95)
	var rug_b := IslandSkyscrapers._flat(Color(0.10, 0.27, 0.19), 0.95)
	var cream := _mat(Color(0.93, 0.89, 0.78), 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var x0 := HALL.position.x
	var x1 := HALL.end.x
	var z0 := HALL.position.y
	var z1 := HALL.end.y

	# ---- floor: dark polished wood floor with a gold inlay border over the whole hall
	Miami._box(mb, wood, Vector3(x0, y, z0), Vector3(x1, y + 0.025, z1))
	Miami._box(mb, gold, Vector3(x0 + 0.5, y + 0.025, z0 + 0.5), Vector3(x1 - 0.5, y + 0.03, z0 + 0.58))
	Miami._box(mb, gold, Vector3(x0 + 0.5, y + 0.025, z1 - 0.58), Vector3(x1 - 0.5, y + 0.03, z1 - 0.5))
	Miami._box(mb, gold, Vector3(x0 + 0.5, y + 0.025, z0 + 0.5), Vector3(x0 + 0.58, y + 0.03, z1 - 0.5))
	Miami._box(mb, gold, Vector3(x1 - 0.58, y + 0.025, z0 + 0.5), Vector3(x1 - 0.5, y + 0.03, z1 - 0.5))
	var fy := y + 0.03

	# ---- reception desk (two desks + chair) in front of the door, a plaque board behind it
	prop(w, body, "desk.glb", 1.5, Vector3(100.8, fy, 2332.2), PI, true)
	prop(w, body, "desk.glb", 1.5, Vector3(103.6, fy, 2332.2), PI, true)
	prop(w, body, "office_chair.glb", 0.95, Vector3(102.2, fy, 2333.6), 0.0, true, 0.6)
	Miami._box(mb, wood2, Vector3(99.2, fy, 2331.5), Vector3(105.2, fy + 1.15, 2331.7))
	Miami._box(mb, gold, Vector3(99.15, fy + 1.15, 2331.45), Vector3(105.25, fy + 1.2, 2331.75))
	var font := load("res://assets/fonts/Pacifico-Regular.ttf") as Font
	var oswald := load("res://assets/fonts/Oswald.ttf") as Font
	_label(w, "Reception", font, Vector3(102.2, fy + 0.62, 2331.46), PI, 0.0030, Color(0.98, 0.82, 0.38))

	# ---- lounge, west side: rug, two sofas facing each other, coffee table, floor lamp, plants
	var lx := 89.0
	var lz := 2336.6
	Miami._box(mb, rug_a, Vector3(lx - 3.6, fy, lz - 2.6), Vector3(lx + 3.6, fy + 0.015, lz + 2.6))
	Miami._box(mb, gold, Vector3(lx - 3.6, fy + 0.015, lz - 2.6), Vector3(lx + 3.6, fy + 0.02, lz - 2.52))
	Miami._box(mb, gold, Vector3(lx - 3.6, fy + 0.015, lz + 2.52), Vector3(lx + 3.6, fy + 0.02, lz + 2.6))
	prop(w, body, "couch_medium.glb", 0.5, Vector3(lx, fy, lz - 2.0), PI, true)
	prop(w, body, "couch_medium.glb", 0.5, Vector3(lx, fy, lz + 2.0), 0.0, true)
	prop(w, body, "table_kenney.glb", 1.7, Vector3(lx, fy, lz), 0.0, true)
	prop(w, body, "sofa.glb", 0.5, Vector3(lx - 4.4, fy, lz), PI * 0.5, true)
	prop(w, body, "light_stand.glb", 0.6, Vector3(lx + 3.9, fy, lz - 2.3), 0.0, true)
	prop(w, body, "plant_a.glb", 1.6, Vector3(x0 + 1.0, fy, z0 + 1.2), 0.0, true)
	_light(w, Vector3(lx + 3.9, fy + 1.6, lz - 2.3), 7.0, Color(1.0, 0.82, 0.55), 1.6)

	# ---- TV wall on the north wall: three wall screens above a low console, sofas facing them
	var zt := z1 - 0.25
	Miami._box(mb, wood, Vector3(x0 + 7.0, fy, zt - 0.5), Vector3(x1 - 2.0, fy + 0.7, zt))
	Miami._box(mb, gold, Vector3(x0 + 6.95, fy + 0.7, zt - 0.55), Vector3(x1 - 1.95, fy + 0.74, zt + 0.02))
	CoastProps._box(body, Vector3(x1 - x0 - 9.0, 0.7, 0.5), Vector3((x0 + 7.0 + x1 - 2.0) * 0.5, fy + 0.35, zt - 0.25))
	var tvx := [93.8, 99.2, 104.6]
	for tx in tvx:
		var tv := prop(w, body, "tv_kenney.glb", 2.6, Vector3(tx, fy + 1.15, zt - 0.14), PI, false)
		_screen(w, Vector3(tx, fy + 1.15 + 0.28, zt - 0.26), Vector2(1.55, 0.86), rng.randi() % 3)
	prop(w, body, "couch_large.glb", 0.42, Vector3(99.2, fy, 2341.0), PI, true)
	prop(w, body, "table_kenney.glb", 1.5, Vector3(99.2, fy, 2338.6), 0.0, true)
	Miami._box(mb, rug_b, Vector3(95.0, fy, 2337.2), Vector3(103.4, fy + 0.015, 2343.0))

	# ---- bar on the east side: granite counter, gold rail, stools, back shelves with bottles
	var bx := x1 - 3.2
	Miami._box(mb, wood, Vector3(bx - 0.5, fy, 2331.2), Vector3(bx + 0.5, fy + 1.1, 2343.6))
	Miami._box(mb, granite, Vector3(bx - 0.65, fy + 1.1, 2331.1), Vector3(bx + 0.65, fy + 1.18, 2343.7))
	Miami._box(mb, gold, Vector3(bx - 0.62, fy + 0.25, 2331.1), Vector3(bx - 0.55, fy + 0.3, 2343.7))
	CoastProps._box(body, Vector3(1.3, 1.2, 12.6), Vector3(bx, fy + 0.6, 2337.4))
	for k in range(6):
		prop(w, body, "barstool.glb", 1.75, Vector3(bx - 1.5, fy, 2332.3 + k * 2.0), PI * 0.5, true)
	var sx := x1 - 0.5
	Miami._box(mb, wood, Vector3(sx - 0.4, fy, 2331.0), Vector3(sx, fy + 3.2, 2343.8))
	for row in range(4):
		var sy := fy + 0.7 + row * 0.75
		Miami._box(mb, gold, Vector3(sx - 0.42, sy, 2331.0), Vector3(sx, sy + 0.04, 2343.8))
		for k in range(15):
			var bz := 2331.4 + k * 0.82
			var col := Color.from_hsv(rng.randf(), 0.55, 0.55)
			Miami._box(mb, IslandSkyscrapers._flat(col, 0.2, 0.2), Vector3(sx - 0.3, sy + 0.04, bz - 0.06), Vector3(sx - 0.18, sy + 0.45 + rng.randf() * 0.1, bz + 0.06))
	CoastProps._box(body, Vector3(0.5, 3.2, 12.8), Vector3(sx - 0.2, fy + 1.6, 2337.4))
	_label(w, "THE 19TH HOLE", oswald, Vector3(sx - 0.45, fy + 3.5, 2337.4), -PI * 0.5, 0.0038, Color(0.98, 0.82, 0.38))

	# ---- dining: three round tables with chairs in the middle
	for k in range(3):
		var tx2 := 96.0 + (k % 2) * 4.6
		var tz2 := 2335.2 + k * 0.0
		if k == 2:
			tx2 = 94.0
			tz2 = 2339.6
		if k == 0:
			tz2 = 2335.2
		if k == 1:
			tz2 = 2335.2
		prop(w, body, "table_round.glb", 0.7, Vector3(tx2, fy, tz2), 0.0, true)
		for a in range(4):
			var ang := float(a) * PI * 0.5 + PI * 0.25
			var cp := Vector3(tx2 + cos(ang) * 1.15, fy, tz2 + sin(ang) * 1.15)
			prop(w, body, "office_chair.glb", 0.9, cp, -ang - PI * 0.5, true, 0.6)

	# ---- trophy cabinet along the west wall
	var cx := x0 + 0.5
	Miami._box(mb, wood, Vector3(cx - 0.25, fy, 2339.4), Vector3(cx + 0.45, fy + 2.4, 2344.8))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.85, 0.95, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	Miami._box(mb, glass, Vector3(cx + 0.45, fy + 0.1, 2339.5), Vector3(cx + 0.5, fy + 2.3, 2344.7))
	for row in range(3):
		var sy2 := fy + 0.55 + row * 0.65
		Miami._box(mb, gold, Vector3(cx - 0.2, sy2, 2339.45), Vector3(cx + 0.45, sy2 + 0.03, 2344.75))
		for k in range(4):
			prop(w, body, "trophy.glb", 2.2, Vector3(cx + 0.1, sy2 + 0.03, 2340.1 + k * 1.3), PI * 0.5, false)
	CoastProps._box(body, Vector3(0.8, 2.4, 5.5), Vector3(cx + 0.1, fy + 1.2, 2342.1))
	_label(w, "Hall of Champions", font, Vector3(cx + 0.55, fy + 2.7, 2342.1), PI * 0.5, 0.0036, Color(0.98, 0.82, 0.38))

	# ---- pro shop on the north-west: club racks on the wall, golf bags, a display plinth
	var rx := x0 + 2.2
	for k in range(3):
		var rz := zt - 0.1
		var px := rx + k * 2.0
		Miami._box(mb, wood2, Vector3(px - 0.8, fy + 0.9, rz - 0.12), Vector3(px + 0.8, fy + 2.0, rz))
		for j in range(5):
			prop(w, body, "golf_club_a.glb", 1.5, Vector3(px - 0.6 + j * 0.3, fy + 1.0, rz - 0.18), PI * 0.5, false)
	for k in range(4):
		_bag(w, body, Vector3(x0 + 1.6 + k * 0.7, fy, z1 - 1.5), rng)
	_label(w, "PRO SHOP", oswald, Vector3(rx + 2.0, fy + 2.5, zt - 0.05), PI, 0.0042, Color(0.98, 0.82, 0.38))

	# ---- indoor putting mat with a cup and flag
	var gp := Vector3(88.2, fy, 2342.0)
	Miami._box(mb, IslandSkyscrapers._flat(Color(0.12, 0.45, 0.14), 0.95), Vector3(gp.x - 2.8, fy, gp.z - 1.3), Vector3(gp.x + 2.8, fy + 0.03, gp.z + 1.3))
	Miami._box(mb, wood2, Vector3(gp.x - 2.9, fy, gp.z - 1.4), Vector3(gp.x + 2.9, fy + 0.04, gp.z - 1.3))
	Miami._box(mb, wood2, Vector3(gp.x - 2.9, fy, gp.z + 1.3), Vector3(gp.x + 2.9, fy + 0.04, gp.z + 1.4))
	Miami._box(mb, wood2, Vector3(gp.x - 2.9, fy, gp.z - 1.3), Vector3(gp.x - 2.8, fy + 0.04, gp.z + 1.3))
	Miami._box(mb, wood2, Vector3(gp.x + 2.8, fy, gp.z - 1.3), Vector3(gp.x + 2.9, fy + 0.04, gp.z + 1.3))
	Miami._box(mb, dark, Vector3(gp.x + 2.0 - 0.1, fy + 0.03, gp.z - 0.1), Vector3(gp.x + 2.0 + 0.1, fy + 0.035, gp.z + 0.1))
	Miami._box(mb, _mat(Color(0.95, 0.95, 0.9)), Vector3(gp.x + 2.0 - 0.012, fy + 0.03, gp.z - 0.012), Vector3(gp.x + 2.0 + 0.012, fy + 0.9, gp.z + 0.012))
	Miami._box(mb, _mat(Color(0.85, 0.1, 0.12)), Vector3(gp.x + 2.0, fy + 0.62, gp.z - 0.008), Vector3(gp.x + 2.3, fy + 0.9, gp.z + 0.008))

	# ---- ceiling chandeliers and plants
	for cp in [Vector3(92.0, 0.0, 2334.5), Vector3(100.0, 0.0, 2337.0), Vector3(106.0, 0.0, 2336.5)]:
		prop(w, body, "chandelier.glb", 2.3, Vector3(cp.x, y + 3.3, cp.z), 0.0, false)
		_light(w, Vector3(cp.x, y + 3.6, cp.z), 11.0, Color(1.0, 0.86, 0.62), 2.2)
	prop(w, body, "plant_b.glb", 2.0, Vector3(x1 - 1.2, fy, z1 - 1.2), 0.0, true)
	prop(w, body, "plant_a.glb", 1.6, Vector3(x1 - 1.2, fy, z0 + 1.4), 0.0, true)
	prop(w, body, "plant_b.glb", 2.0, Vector3(x0 + 1.2, fy, z0 + 3.4), 0.0, true)

static func _label(w: World, text: String, font: Font, pos: Vector3, yaw: float, px: float, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 96
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 4
	l.outline_modulate = Color(0.1, 0.06, 0.02, 0.8)
	l.position = pos
	l.rotation.y = yaw
	w.static_root.add_child(l)

## A glowing wall-screen picture (green fairway view / scoreboard / sunset) on a TV.
static func _screen(w: World, pos: Vector3, size: Vector2, kind: int) -> void:
	var qm := QuadMesh.new()
	qm.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tex := load(["res://assets/textures/ground/Grass005_Color.jpg", "res://assets/golf/tex/Grass001_Color.jpg", "res://assets/golf/tex/Grass008_Color.jpg"][kind]) as Texture2D
	m.albedo_texture = tex
	m.albedo_color = [Color(0.8, 1.0, 0.8), Color(0.9, 1.0, 0.85), Color(1.0, 0.95, 0.8)][kind]
	m.uv1_scale = Vector3(1.4, 0.8, 1.0)
	qm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.position = pos
	mi.rotation.y = PI
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)

## A golf bag standing on the floor: coloured body, lighter top, strap, and a few club heads sticking out.
static func _bag(w: World, body: StaticBody3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var col := Color.from_hsv(rng.randf(), 0.7, 0.55)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.17
	cm.bottom_radius = 0.14
	cm.height = 0.95
	cm.radial_segments = 14
	cm.material = _mat(col, 0.5, 0.1)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.position = p + Vector3(0.0, 0.48, 0.0)
	w.static_root.add_child(mi)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.19
	cap.bottom_radius = 0.19
	cap.height = 0.12
	cap.radial_segments = 14
	cap.material = _mat(Color(0.12, 0.12, 0.13), 0.5, 0.3)
	var ci := MeshInstance3D.new()
	ci.mesh = cap
	ci.position = p + Vector3(0.0, 0.98, 0.0)
	w.static_root.add_child(ci)
	for j in range(4):
		var kn := prop(w, body, "golf_club_a.glb", 1.3, p + Vector3((j - 1.5) * 0.06, 0.95, (j % 2) * 0.05 - 0.02), rng.randf() * TAU, false)
	CoastProps._box(body, Vector3(0.36, 1.1, 0.36), p + Vector3(0.0, 0.55, 0.0))
