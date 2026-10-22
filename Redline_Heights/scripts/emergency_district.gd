class_name EmergencyDistrict
extends RefCounted
## Block B2 (x 200..400, z 1950..2200): the Redline Emergency Services quarter.
## South side (next to the hospital block): two fenced compounds, each with its own gate, barrier arms, name arch and cars parked inside -
## SENTINEL Police Headquarters (downloaded model, its own cars / bike / helicopters cut out, retextured, the game's police helicopter on the roof pad)
## and EMBER ROCK Fire & Rescue (downloaded fire station, engine bays on the apron). A side street runs between them.
## A main street crosses the block east-west. North of it: shops and apartments / offices from the city's own building set (york, bordeaux,
## asian shop, Atlanta office, soviet block), a monument plaza, palms, lamps and people. Everything is solid and on the ground.

const X0 := 206.7
const X1 := 393.3
const Z0 := 1956.7
const Z1 := 2193.3
const Y := 0.22
const SC := 0.015
const PC := Vector3(1686.3, -6.0, -2155.0)           # centre of the police model (x, lowest y, z)
const FIRE := "res://assets/district/fire_station_no._1.glb"
const MONUMENT := "res://assets/district/stylized_fox_monument.glb"
const ROAD_Z := 2066.0                               # centre of the main street
const ROAD_W := 12.0
const POLICE := Rect2(214.0, 2084.0, 76.0, 106.0)    # compound rectangles (x, z, w, d)
const FIREC := Rect2(306.0, 2112.0, 80.0, 78.0)
const T := "res://assets/town/"

static var _specs_ready := false
static var _fence_root: Node3D = null

## world position of a police-model-space point for a station standing at `at` turned by `yaw`
static func _mw(v: Vector3, at: Vector2, yaw: float) -> Vector3:
	var p := Vector3((v.x - PC.x) * SC, (v.y - PC.y) * SC, (v.z - PC.z) * SC)
	p = Basis(Vector3.UP, yaw) * p
	return Vector3(at.x + p.x, Y + p.y, at.y + p.z)

static func _need_specs() -> void:
	if _specs_ready: return
	_specs_ready = true
	for k in [["york", T + "york_corner_shop_1.glb", 1.25], ["bordeaux", T + "bordeaux_flat_2_corner_france.glb", 1.0],
			["asian", T + "asian_shop_1.glb", 3.3], ["atl", CityBuild.ATL, 0.55], ["atl_l", CityBuild.ATL, 0.72],
			["soviet", T + "low_poly_-_soviet__apartment_building_8k.glb", 27.0]]:
		if not CityBuild.specs.has(k[0]):
			CityBuild._spec(k[0], k[1], k[2], "", PI * 0.5 if k[0] == "soviet" else 0.0)
	CityLights.apply(CityBuild.specs.asian.mesh, "windows_named", 1.0)
	CityLights.apply_shader(CityBuild.specs.bordeaux.mesh, {"mode": 2, "emit": T + "bordeaux_flat_2_corner_france_1.png", "lit_frac": 0.6, "gain": 1.0})
	for k in ["atl", "atl_l"]:
		CityLights.apply(CityBuild.specs[k].mesh, "only_windows", 1.0)

## One of the city's own buildings (CityBuild spec) standing on the ground at p, its front turned to world direction `face` (0 = +z).
static func _city(w: World, body: StaticBody3D, key: String, p: Vector2, face: float) -> void:
	_need_specs()
	var sp: Dictionary = CityBuild.specs[key]
	var yaw := face + float(sp.yaw0)
	var mi := MeshInstance3D.new()
	mi.name = key
	mi.mesh = sp.mesh
	mi.position = Vector3(p.x, Y, p.y)
	mi.rotation.y = yaw
	w.static_root.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = MedicalDistrict._shape("city:" + key, sp.mesh)
	cs.transform = mi.transform
	body.add_child(cs)

static func build(w: World) -> void:
	print("EmergencyDistrict: building block B2...")
	Miami._prep_props()
	var body := StaticBody3D.new()
	body.name = "EmergencyDistrictBody"
	body.collision_layer = 1
	w.static_root.add_child(body)
	Miami.solid_body = body
	var rng := RandomNumberGenerator.new()
	rng.seed = 1960
	var mb := {}
	var mbs := {}
	var paving := IslandSkyscrapers._surface_mat("Concrete034", 0.2, Color(0.5, 0.5, 0.52), 0.85)
	var cobble := IslandSkyscrapers._surface_mat("PavingStones070", 0.7, Color(0.85, 0.85, 0.85), 0.8)
	var asph := IslandSkyscrapers._surface_mat("Asphalt031", 0.4, Color(0.7, 0.7, 0.72), 0.9)
	var white := IslandSkyscrapers._flat(Color(0.93, 0.93, 0.9), 0.8)
	var yellow := IslandSkyscrapers._flat(Color(0.95, 0.8, 0.2), 0.8)
	var kerb := IslandSkyscrapers._flat(Color(0.62, 0.62, 0.6), 0.8)

	# ---- ground: paved block, main street across it, side street between the two compounds
	Miami._box(mb, paving, Vector3(X0, Y, Z0), Vector3(X1, Y + 0.02, Z1))
	CoastProps._box(body, Vector3(X1 - X0, 0.06, Z1 - Z0), Vector3((X0 + X1) * 0.5, Y - 0.01, (Z0 + Z1) * 0.5))
	var rz0 := ROAD_Z - ROAD_W * 0.5
	var rz1 := ROAD_Z + ROAD_W * 0.5
	var t_ := Time.get_ticks_msec()
	_roads(w, body)
	print("TIMING  roads ", Time.get_ticks_msec() - t_); t_ = Time.get_ticks_msec()

	_fence_root = w.static_root
	_lot(w, body, mb, Rect2(212.0, 1980.0, 80.0, 30.0), rng, 9, true)
	_lot(w, body, mb, Rect2(346.0, 1980.0, 46.0, 30.0), rng, 6, false)
	_park(w, body, mb, rng)
	_police(w, body, mb, mbs)
	print("TIMING  police ", Time.get_ticks_msec() - t_); t_ = Time.get_ticks_msec()
	_fire(w, body, mb, mbs)
	print("TIMING  fire ", Time.get_ticks_msec() - t_); t_ = Time.get_ticks_msec()

	# ---- north road: old concrete shop rows and a cafe (doors on the pavement side), the supermarket with its small car park, glass towers behind
	var OC := "res://assets/district/old_concrete_building_pack__lowpoly.glb"
	MedicalDistrict.place(w, body, OC, 25.6, Vector2(224.0, 1967.0), PI)
	MedicalDistrict.place(w, body, OC, 25.6, Vector2(250.0, 1967.0), PI)
	MedicalDistrict.place(w, body, "cafe_nikki", 11.0, Vector2(274.0, 1971.0), PI)
	MedicalDistrict.place(w, body, OC, 25.6, Vector2(372.0, 1967.0), PI)
	_supermarket(w, body, mb, Vector2(322.0, 1960.0))
	for gx in [215.0, 232.0, 244.0, 258.0, 274.0, 364.0, 380.0]:
		MedicalDistrict._glow(w, Vector3(gx, Y + 3.0, 1963.0), 9.0, Color(1.0, 0.8, 0.5), 1.6)
	MedicalDistrict.place(w, body, "modern_tower_office_apartment_house_home", 40.0, Vector2(236.0, 2028.0), 0.0)
	MedicalDistrict.place(w, body, "amelinco_office_building", 25.0, Vector2(272.0, 2030.0), 0.0)
	MedicalDistrict.place(w, body, "amelinco_office_building", 25.0, Vector2(330.0, 2030.0), 0.0)
	MedicalDistrict.place(w, body, "singapore_office_skyscraper_free", 34.0, Vector2(362.0, 2030.0), 0.0)

	print("TIMING  shops ", Time.get_ticks_msec() - t_); t_ = Time.get_ticks_msec()
	# ---- monument plaza between the shop row and the apartment block
	var plaza := Vector2(300.0, 2030.0)
	var mon: Dictionary = MedicalDistrict._bake(MONUMENT, 14.0)
	if not mon.is_empty():
		var msc: float = 12.0 / maxf(float((mon.size as Vector3).y / float(mon.s)), 0.1)
		var mmi := MeshInstance3D.new()
		mmi.mesh = mon.mesh
		mmi.position = Vector3(plaza.x, Y + 0.35, plaza.y)
		mmi.scale = Vector3.ONE * msc
		w.static_root.add_child(mmi)
		var cs2 := CollisionShape3D.new()
		cs2.shape = MedicalDistrict._shape(String(mon.path), mon.mesh)
		cs2.transform = mmi.transform
		body.add_child(cs2)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 8.0
	cyl.bottom_radius = 8.4
	cyl.height = 0.35
	cyl.radial_segments = 40
	cyl.material = cobble
	var cmi := MeshInstance3D.new()
	cmi.mesh = cyl
	cmi.position = Vector3(plaza.x, Y + 0.175, plaza.y)
	w.static_root.add_child(cmi)
	var ccs := CollisionShape3D.new()
	var cyls := CylinderShape3D.new()
	cyls.radius = 8.0
	cyls.height = 0.35
	ccs.shape = cyls
	ccs.position = cmi.position
	body.add_child(ccs)
	for a in range(5):
		var ang := a * TAU / 5.0 + 0.3
		Miami._put("bench", Vector3(plaza.x + cos(ang) * 9.6, Y + 0.05, plaza.y + sin(ang) * 9.6), -ang - PI * 0.5, 1.0)

	# ---- palms along the main street, bus stops, bins
	for k in range(0, 11):
		var tx := X0 + 12.0 + k * 16.5
		if tx > 280.0 and tx < 316.0: continue
		Miami._palm(body, Vector2(tx, rz0 - 3.2), rng, "m")
		Miami._palm(body, Vector2(tx, rz1 + 3.2), rng, "m" if k % 2 == 0 else "t")
	Miami._put("busstop", Vector3(250.0, Y + 0.04, rz0 - 6.2), PI, 1.0)
	Miami._put("busstop", Vector3(350.0, Y + 0.04, rz1 + 6.2), 0.0, 1.0)
	for bn in [Vector2(244.0, rz0 - 6.0), Vector2(356.0, rz0 - 6.0), Vector2(262.0, rz1 + 6.0), Vector2(336.0, rz1 + 6.0)]:
		Miami._put("bins", Vector3(bn.x, Y + 0.04, bn.y), 0.0, 1.0)

	var mi := MeshInstance3D.new()
	mi.mesh = Miami._finish(mb)
	w.static_root.add_child(mi)
	var mi2 := MeshInstance3D.new()
	mi2.mesh = Miami._finish(mbs)
	w.static_root.add_child(mi2)
	Miami._flush(w)
	print("TIMING  rest ", Time.get_ticks_msec() - t_); t_ = Time.get_ticks_msec()
	_people(w)
	print("TIMING  people ", Time.get_ticks_msec() - t_)
	w.add_poi("emergency", "SENTINEL POLICE & EMBER ROCK FIRE", Vector3(300.0, Y + 1.0, 2185.0))
	print("EmergencyDistrict: done.")

# ------------------------------------------------------------------ compounds

## The island's own road kit (same asphalt, markings, kerbs and lamps as every other street): main street + the side street, crossroad between.
static func _roads(w: World, body: StaticBody3D) -> void:
	RoadKit._load()
	var straight := RoadKit._find("Road_33")
	var cross := RoadKit._find("Crossroad")
	var sx := 298.0
	RoadKit._put(w, body, cross, Vector3(sx, Y, ROAD_Z), 0.0)
	var half := RoadKit.CROSS_W * 0.5
	for seg in [[X0, sx - half], [sx + half, X1]]:
		var len: float = seg[1] - seg[0]
		var n := maxi(1, int(round(len / RoadKit.STRAIGHT_L)))
		var step := len / n
		for k in range(n):
			RoadKit._put(w, body, straight, Vector3(seg[0] + (k + 0.5) * step, Y, ROAD_Z), PI * 0.5, step / RoadKit.STRAIGHT_L)
	var z0 := ROAD_Z + half
	var zl := Z1 - z0
	var m := maxi(1, int(round(zl / RoadKit.STRAIGHT_L)))
	var zs := zl / m
	for k in range(m):
		RoadKit._put(w, body, straight, Vector3(sx, Y, z0 + (k + 0.5) * zs), 0.0, zs / RoadKit.STRAIGHT_L)
	var side := 1.0
	var lx := X0 + 20.0
	while lx < X1 - 10.0:
		if absf(lx - sx) > 12.0:
			RoadKit.lamp_at(w, body, Vector2(lx, ROAD_Z + side * 4.9), Vector2(lx, ROAD_Z), Y)
		side = -side
		lx += RoadKit.LAMP_SPACING * 0.5
	for lz in [2100.0, 2150.0]:
		RoadKit.lamp_at(w, body, Vector2(sx - 4.9, lz), Vector2(sx, lz), Y)

## A fenced compound: dark steel railings with posts, open on the south side where the gate stands.
static func _fence(body: StaticBody3D, mb: Dictionary, r: Rect2, gate_x0: float, gate_x1: float) -> void:
	var steel := IslandSkyscrapers._flat(Color(0.10, 0.11, 0.14), 0.45, 0.6)
	var rail := IslandSkyscrapers._flat(Color(0.75, 0.1, 0.1), 0.5, 0.3)
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var h := 2.2
	var bars: Array = []          # bar centres (x, z), drawn afterwards as one MultiMesh
	var runs := [[x0, z0, x1, z0], [x0, z0, x0, z1], [x1, z0, x1, z1], [x0, z1, gate_x0, z1], [gate_x1, z1, x1, z1]]
	for rn in runs:
		var ax: float = rn[0]; var az: float = rn[1]; var bx: float = rn[2]; var bz: float = rn[3]
		var along_x := absf(bx - ax) > absf(bz - az)
		var len := absf(bx - ax) if along_x else absf(bz - az)
		var n := maxi(1, int(ceil(len / 3.0)))
		var lo_x := minf(ax, bx)
		var lo_z := minf(az, bz)
		for i in range(n + 1):
			var t := float(i) / float(n)
			var px := lo_x + (len * t if along_x else 0.0)
			var pz := lo_z + (0.0 if along_x else len * t)
			Miami._box(mb, steel, Vector3(px - 0.1, Y, pz - 0.1), Vector3(px + 0.1, Y + h, pz + 0.1))
		if along_x:
			Miami._box(mb, steel, Vector3(lo_x, Y + 0.2, lo_z - 0.03), Vector3(lo_x + len, Y + 0.28, lo_z + 0.03))
			Miami._box(mb, steel, Vector3(lo_x, Y + h - 0.3, lo_z - 0.03), Vector3(lo_x + len, Y + h - 0.22, lo_z + 0.03))
			Miami._box(mb, rail, Vector3(lo_x, Y + h * 0.5, lo_z - 0.02), Vector3(lo_x + len, Y + h * 0.5 + 0.08, lo_z + 0.02))
			var cnt := int(len / 0.2)
			for k in range(1, cnt):
				bars.append(Vector2(lo_x + len * float(k) / float(cnt), lo_z))
			CoastProps._box(body, Vector3(len, h, 0.2), Vector3(lo_x + len * 0.5, Y + h * 0.5, lo_z))
		else:
			Miami._box(mb, steel, Vector3(lo_x - 0.03, Y + 0.2, lo_z), Vector3(lo_x + 0.03, Y + 0.28, lo_z + len))
			Miami._box(mb, steel, Vector3(lo_x - 0.03, Y + h - 0.3, lo_z), Vector3(lo_x + 0.03, Y + h - 0.22, lo_z + len))
			Miami._box(mb, rail, Vector3(lo_x - 0.02, Y + h * 0.5, lo_z), Vector3(lo_x + 0.02, Y + h * 0.5 + 0.08, lo_z + len))
			var cnt2 := int(len / 0.2)
			for k in range(1, cnt2):
				bars.append(Vector2(lo_x, lo_z + len * float(k) / float(cnt2)))
			CoastProps._box(body, Vector3(0.2, h, len), Vector3(lo_x, Y + h * 0.5, lo_z + len * 0.5))
	if not bars.is_empty():
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, h - 0.58, 0.03)
		bm.material = steel
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bm
		mm.instance_count = bars.size()
		for i in range(bars.size()):
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(bars[i].x, Y + 0.28 + (h - 0.58) * 0.5, bars[i].y)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		_fence_root.add_child(mmi)

## Entrance: a guard booth between the lanes, barrier arms (inbound closed, outbound raised), stone gate piers with lanterns, the name carved on a low
## stone wall beside each pier (no overhead board), and concrete / red barricades from the street asset pack set as a chicane inside the drive.
## Sliding engine gate: a bar leaf on a track that rolls west behind the fence when anything comes near, with a drive-motor housing.
static func _slide_gate(w: World, body: StaticBody3D, mb: Dictionary, x0: float, x1: float, z: float) -> void:
	var iron := IslandSkyscrapers._flat(Color(0.08, 0.08, 0.1), 0.4, 0.7)
	var red := IslandSkyscrapers._flat(Color(0.78, 0.08, 0.08), 0.5, 0.3)
	var zl := z + 0.55
	var ln := x1 - x0 + 0.2
	var h := 2.5
	var leaf := SlideGate.new()
	leaf.position = Vector3(x0 - 0.1, Y + 0.12, zl)
	leaf.open_dx = -(ln + 1.0)
	leaf.centre = Vector2((x0 + x1) * 0.5, z)
	var lm := {}
	Miami._box(lm, iron, Vector3(0.0, 0.0, -0.06), Vector3(ln, 0.14, 0.06))
	Miami._box(lm, iron, Vector3(0.0, h - 0.14, -0.06), Vector3(ln, h, 0.06))
	Miami._box(lm, red, Vector3(0.0, h * 0.5, -0.05), Vector3(ln, h * 0.5 + 0.1, 0.05))
	Miami._box(lm, iron, Vector3(0.0, 0.0, -0.08), Vector3(0.12, h, 0.08))
	Miami._box(lm, iron, Vector3(ln - 0.12, 0.0, -0.08), Vector3(ln, h, 0.08))
	var n := int(ln / 0.16)
	for i in range(1, n):
		var bx := float(i) * ln / n
		Miami._box(lm, iron, Vector3(bx - 0.02, 0.14, -0.025), Vector3(bx + 0.02, h - 0.14, 0.025))
	var mi := MeshInstance3D.new()
	mi.mesh = Miami._finish(lm)
	leaf.add_child(mi)
	var ab := StaticBody3D.new()
	ab.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(ln, h, 0.2)
	cs.shape = bx
	cs.position = Vector3(ln * 0.5, h * 0.5, 0.0)
	ab.add_child(cs)
	leaf.solid_shape = cs
	leaf.add_child(ab)
	w.static_root.add_child(leaf)
	# track across the opening and rolling carriers / motor housing at the west end
	Miami._box(mb, iron, Vector3(x0 - ln - 1.5, Y, zl - 0.05), Vector3(x1 + 0.5, Y + 0.07, zl + 0.05))
	Miami._box(mb, iron, Vector3(x1 - 0.1, Y, zl - 0.12), Vector3(x1 + 0.1, Y + h + 0.1, zl + 0.12))
	Miami._box(mb, iron, Vector3(x0 - 1.4, Y, zl + 0.2), Vector3(x0 - 0.3, Y + 1.0, zl + 0.9))
	Miami._box(mb, red, Vector3(x0 - 1.4, Y + 1.0, zl + 0.2), Vector3(x0 - 0.3, Y + 1.08, zl + 0.9))
	CoastProps._box(body, Vector3(1.1, 1.0, 0.7), Vector3(x0 - 0.85, Y + 0.5, zl + 0.55))

## Supermarket with a small car park between it and the north road: store faces the road, 2 rows of painted bays, trolley bay, lamps, two parked cars.
static func _supermarket(w: World, body: StaticBody3D, mb: Dictionary, p: Vector2) -> void:
	var asph := IslandSkyscrapers._surface_mat("Asphalt031", 0.4, Color(0.62, 0.62, 0.64), 0.9)
	var white := IslandSkyscrapers._flat(Color(0.93, 0.93, 0.9), 0.8)
	var kerb := IslandSkyscrapers._flat(Color(0.7, 0.7, 0.68), 0.8)
	var x0 := p.x - 24.0
	var x1 := p.x + 24.0
	var z0 := p.y + 5.0
	var z1 := p.y + 19.0
	Miami._box(mb, asph, Vector3(x0, Y + 0.02, z0), Vector3(x1, Y + 0.04, z1))
	Miami._box(mb, kerb, Vector3(x0, Y + 0.02, z1), Vector3(x1, Y + 0.14, z1 + 0.3))
	for k in range(0, 17):
		var bx := x0 + 1.5 + k * 2.75
		Miami._box(mb, white, Vector3(bx - 0.05, Y + 0.04, z0 + 1.0), Vector3(bx + 0.05, Y + 0.045, z0 + 6.0))
		Miami._box(mb, white, Vector3(bx - 0.05, Y + 0.04, z1 - 6.0), Vector3(bx + 0.05, Y + 0.045, z1 - 1.0))
	var st: Dictionary = MedicalDistrict.place(w, body, "res://assets/district/supermarket_clean.res", 30.0, Vector2(p.x, z1 + 0.3 + 11.0), PI, 0.0, false, 0.95)
	for k in [3, 8, 12]:
		LazyCars.add(w, ["hatch", "saloon", "taxi"][k % 3], Vector3(x0 + 1.5 + k * 2.75 + 1.37, Y + Car.RIDE + 0.2, z0 + 3.5), 0.0)
	for lx in [x0 + 4.0, x1 - 4.0]:
		IslandSkyscrapers._add_parking_floodlight(w, body, Vector2(lx, z0 + 1.0), Vector2(lx, z1))

## Small park north of the fire station: lawn with a raised kerb, a cobble cross path and a round seating circle, palms and shrubs, benches, flower beds, bins, lamps.
static func _park(w: World, body: StaticBody3D, mb: Dictionary, rng: RandomNumberGenerator) -> void:
	var r := Rect2(312.0, 2076.0, 74.0, 30.0)
	var lawn := StandardMaterial3D.new()
	lawn.albedo_texture = load("res://assets/golf/tex/Grass001_Color.jpg") as Texture2D
	lawn.albedo_color = Color(0.72, 0.86, 0.58)
	lawn.roughness = 0.95
	lawn.uv1_world_triplanar = true
	lawn.uv1_scale = Vector3.ONE * 0.2
	var kerb := IslandSkyscrapers._flat(Color(0.66, 0.66, 0.64), 0.8)
	var cobble := IslandSkyscrapers._surface_mat("PavingStones070", 0.7, Color(0.85, 0.85, 0.85), 0.8)
	Miami._box(mb, kerb, Vector3(r.position.x - 0.3, Y + 0.02, r.position.y - 0.3), Vector3(r.end.x + 0.3, Y + 0.1, r.end.y + 0.3))
	Miami._box(mb, lawn, Vector3(r.position.x, Y + 0.1, r.position.y), Vector3(r.end.x, Y + 0.12, r.end.y))
	CoastProps._box(body, Vector3(r.size.x + 0.6, 0.1, r.size.y + 0.6), Vector3(r.position.x + r.size.x * 0.5, Y + 0.07, r.position.y + r.size.y * 0.5))
	# paths: east-west through the middle, three short links to the pavement, seating circle in the centre
	var cx := r.position.x + r.size.x * 0.5
	var cz := r.position.y + r.size.y * 0.5
	Miami._box(mb, cobble, Vector3(r.position.x, Y + 0.12, cz - 1.2), Vector3(r.end.x, Y + 0.125, cz + 1.2))
	for px in [r.position.x + 12.0, cx, r.end.x - 12.0]:
		Miami._box(mb, cobble, Vector3(px - 1.1, Y + 0.12, r.position.y), Vector3(px + 1.1, Y + 0.125, cz - 1.2))
		Miami._box(mb, cobble, Vector3(px - 1.1, Y + 0.12, cz + 1.2), Vector3(px + 1.1, Y + 0.125, r.end.y))
	var cm := CylinderMesh.new()
	cm.top_radius = 5.0
	cm.bottom_radius = 5.0
	cm.height = 0.04
	cm.radial_segments = 36
	cm.material = cobble
	var cmi := MeshInstance3D.new()
	cmi.mesh = cm
	cmi.position = Vector3(cx, Y + 0.14, cz)
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(cmi)
	for a in range(6):
		var ang := a * TAU / 6.0
		Miami._put("bench", Vector3(cx + cos(ang) * 6.0, Y + 0.14, cz + sin(ang) * 6.0), -ang - PI * 0.5, 1.0)
	Miami._put("flowerbed", Vector3(cx, Y + 0.14, cz), 0.0, 0.3)
	# trees and shrubs on the lawn, clear of the paths
	for k in range(0, 8):
		var tx := r.position.x + 6.0 + k * 9.6
		if absf(tx - cx) < 8.0 or absf(tx - (r.position.x + 12.0)) < 2.5 or absf(tx - (r.end.x - 12.0)) < 2.5: continue
		Miami._palm(body, Vector2(tx, r.position.y + 5.0), rng, "m" if k % 2 == 0 else "t")
		Miami._palm(body, Vector2(tx + 3.0, r.end.y - 5.0), rng, "m")
	for k in range(0, 5):
		var fx := r.position.x + 8.0 + k * 14.0
		if absf(fx - cx) < 8.0: continue
		Miami._put("flowerbed", Vector3(fx, Y + 0.12, r.position.y + 10.0), 0.0, 0.25)
		Miami._put("flowerbed", Vector3(fx + 4.0, Y + 0.12, r.end.y - 10.0), 0.0, 0.25)
	for bx in [r.position.x + 3.0, r.end.x - 3.0]:
		Miami._put("bins", Vector3(bx, Y + 0.12, cz + 2.4), 0.0, 1.0)
		IslandSkyscrapers._add_parking_floodlight(w, body, Vector2(bx, r.position.y + 2.0), Vector2(bx, cz))
	LazyCars.add_npc(w, "npc_luiz", Vector3(cx - 8.0, Y + 0.16, cz), PI * 0.5, "Idle", [Vector3(cx - 8.0, Y + 0.16, cz), Vector3(cx + 30.0, Y + 0.16, cz)])
	LazyCars.add_npc(w, "npc_ch21", Vector3(cx + 6.0, Y + 0.16, cz + 6.0), PI, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_luiz", Vector3(cx + 7.2, Y + 0.16, cz + 6.9), -PI * 0.5, "UAL_Idle_Talking")

## A public car park: asphalt, two rows of painted bays facing a drive aisle, a kerb round it, lamps, and some of the bays occupied by parked cars.
static func _lot(w: World, body: StaticBody3D, mb: Dictionary, r: Rect2, rng: RandomNumberGenerator, cars: int, open_west: bool) -> void:
	var asph := IslandSkyscrapers._surface_mat("Asphalt031", 0.4, Color(0.6, 0.6, 0.62), 0.9)
	var white := IslandSkyscrapers._flat(Color(0.93, 0.93, 0.9), 0.8)
	var kerb := IslandSkyscrapers._flat(Color(0.72, 0.72, 0.7), 0.8)
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	Miami._box(mb, asph, Vector3(x0, Y + 0.02, z0), Vector3(x1, Y + 0.04, z1))
	Miami._box(mb, kerb, Vector3(x0, Y + 0.02, z0 - 0.3), Vector3(x1, Y + 0.12, z0))
	Miami._box(mb, kerb, Vector3(x0, Y + 0.02, z1), Vector3(x1, Y + 0.12, z1 + 0.3))
	Miami._box(mb, white, Vector3(x0, Y + 0.04, (z0 + z1) * 0.5 - 0.06), Vector3(x1, Y + 0.045, (z0 + z1) * 0.5 + 0.06))     # aisle centre line
	var bays := int((x1 - x0 - 2.0) / 2.75)
	var spots: Array = []
	for k in range(bays + 1):
		var bx := x0 + 1.0 + k * 2.75
		Miami._box(mb, white, Vector3(bx - 0.05, Y + 0.04, z0 + 1.0), Vector3(bx + 0.05, Y + 0.045, z0 + 6.5))
		Miami._box(mb, white, Vector3(bx - 0.05, Y + 0.04, z1 - 6.5), Vector3(bx + 0.05, Y + 0.045, z1 - 1.0))
		if k < bays:
			spots.append([bx + 1.375, z0 + 3.9, 0.0])
			spots.append([bx + 1.375, z1 - 3.9, PI])
	spots.shuffle()
	var kinds := ["fumi", "fumi", "factory_gt"]
	for i in range(mini(cars, spots.size())):
		var sp: Array = spots[i]
		LazyCars.add(w, kinds[i % kinds.size()], Vector3(sp[0], Y + Car.RIDE + 0.2, sp[1]), sp[2] + rng.randf_range(-0.04, 0.04))
	for lx in [x0 + 6.0, (x0 + x1) * 0.5, x1 - 6.0]:
		IslandSkyscrapers._add_parking_floodlight(w, body, Vector2(lx, z0 + 0.8), Vector2(lx, z1))

static func _piece(name: String) -> Dictionary:
	var m := load("res://assets/district/pieces/%s.res" % name) as Mesh
	if m == null: return {}
	return {"mesh": m, "size": m.get_aabb().size}

static func _gate(w: World, body: StaticBody3D, mb: Dictionary, cx: float, z: float, title: String, sub: String, tint: Color, wide := false) -> void:
	var stone := IslandSkyscrapers._surface_mat("Bricks076A", 0.4, Color(1.1, 1.1, 1.1), 0.85)
	var cap := IslandSkyscrapers._flat(Color(0.82, 0.82, 0.8), 0.6)
	var plate := IslandSkyscrapers._flat(tint, 0.4, 0.3)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.95, 0.8)
	CityLights.register_material(lamp, Color(1.0, 0.85, 0.5), 3.0)
	var gw := 9.0 if wide else 6.0
	for sx in [-1.0, 1.0]:
		var px: float = cx + sx * gw
		Miami._box(mb, stone, Vector3(px - 0.6, Y, z - 0.6), Vector3(px + 0.6, Y + 2.4, z + 0.6))
		Miami._box(mb, cap, Vector3(px - 0.72, Y + 2.4, z - 0.72), Vector3(px + 0.72, Y + 2.55, z + 0.72))
		Miami._box(mb, lamp, Vector3(px - 0.25, Y + 2.55, z - 0.25), Vector3(px + 0.25, Y + 3.1, z + 0.25))
		CoastProps._box(body, Vector3(1.2, 2.5, 1.2), Vector3(px, Y + 1.25, z))
		# low stone wall with the lettered plate, running out from the pier along the road
		var wx0: float = px + sx * 0.6
		var wx1: float = px + sx * 7.6
		Miami._box(mb, stone, Vector3(minf(wx0, wx1), Y, z - 0.35), Vector3(maxf(wx0, wx1), Y + 1.0, z + 0.35))
		Miami._box(mb, cap, Vector3(minf(wx0, wx1), Y + 1.0, z - 0.42), Vector3(maxf(wx0, wx1), Y + 1.1, z + 0.42))
		CoastProps._box(body, Vector3(7.0, 1.1, 0.7), Vector3((wx0 + wx1) * 0.5, Y + 0.55, z))
		var mx: float = (wx0 + wx1) * 0.5
		Miami._box(mb, plate, Vector3(mx - 3.0, Y + 0.18, z + 0.36), Vector3(mx + 3.0, Y + 0.92, z + 0.4))
		var t := Label3D.new()
		t.text = title if sx < 0.0 else sub
		t.font = load("res://assets/fonts/Oswald.ttf") as Font
		t.font_size = 64
		t.pixel_size = 0.0075 if sx < 0.0 else 0.0090
		t.modulate = Color(0.96, 0.9, 0.62)
		t.outline_size = 4
		t.outline_modulate = Color(0.02, 0.03, 0.08)
		t.position = Vector3(mx, Y + 0.55, z + 0.42)
		w.static_root.add_child(t)
		var ol := OmniLight3D.new()
		ol.position = Vector3(px, Y + 3.0, z + 1.5)
		ol.omni_range = 12.0
		ol.light_color = Color(1.0, 0.88, 0.62)
		ol.shadow_enabled = false
		w.static_root.add_child(ol)
		CityLights.register_light(ol, 1.6)
	if wide:
		return                       # engine gate: a plain open drive, nothing in the way of the trucks
	# guard booth on a kerbed island between the lanes
	var isl := IslandSkyscrapers._flat(Color(0.62, 0.60, 0.55), 0.8)
	Miami._box(mb, isl, Vector3(cx - 1.6, Y, z - 5.0), Vector3(cx + 1.6, Y + 0.16, z + 1.0))
	CoastProps._box(body, Vector3(3.2, 0.16, 6.0), Vector3(cx, Y + 0.08, z - 2.0))
	var gbk: Dictionary = Miami._bake("res://assets/golf/checkpoint_gate.glb", "Guard House", 0.0, 0.6, "")
	if gbk.is_empty(): gbk = Miami._bake("res://assets/golf/checkpoint_gate.glb", "", 0.0, 0.6)
	if not gbk.is_empty():
		var gmi := MeshInstance3D.new()
		gmi.mesh = gbk.mesh
		gmi.position = Vector3(cx, Y + 0.16, z - 2.0)
		gmi.rotation.y = 0.0
		w.static_root.add_child(gmi)
		CoastProps._box(body, Vector3(minf(gbk.size.x, 3.0), gbk.size.y, minf(gbk.size.z, 3.0)), gmi.position + Vector3(0.0, gbk.size.y * 0.5, 0.0))
	GolfClub._barrier(w, body, mb, Vector3(cx - 2.6, Y, z - 3.2), -1.0, false)
	GolfClub._barrier(w, body, mb, Vector3(cx + 2.6, Y, z - 3.2), 1.0, true)
	# chicane just inside the gate: concrete barriers staggered across the drive, cones, a red barrier
	var pack := "res://assets/city/street_asset_pack.glb"
	for it in [["concrete_barrier", -2.4, -11.0, 0.0], ["concrete_barrier", 2.4, -15.0, 0.0], ["red_barrier", -3.4, -19.0, 0.4]]:
		var bk: Dictionary = _piece(String(it[0]))
		if bk.is_empty(): continue
		var bmi := MeshInstance3D.new()
		bmi.mesh = bk.mesh
		bmi.position = Vector3(cx + float(it[1]), Y, z + float(it[2]))
		bmi.rotation.y = float(it[3])
		w.static_root.add_child(bmi)
		CoastProps._box(body, Vector3(bk.size.x, bk.size.y, bk.size.z), bmi.position + Vector3(0.0, bk.size.y * 0.5, 0.0), float(it[3]))
	var ck: Dictionary = _piece("cone")
	if not ck.is_empty():
		for dx in [-4.4, -3.2, 3.2, 4.4]:
			var cmi := MeshInstance3D.new()
			cmi.mesh = ck.mesh
			cmi.position = Vector3(cx + dx, Y, z - 6.0)
			w.static_root.add_child(cmi)
			CoastProps._box(body, Vector3(0.6, 1.0, 0.6), cmi.position + Vector3(0.0, 0.5, 0.0))
	var ol2 := OmniLight3D.new()
	ol2.position = Vector3(cx, Y + 3.5, z - 2.0)
	ol2.omni_range = 14.0
	ol2.light_color = Color(1.0, 0.92, 0.75)
	ol2.shadow_enabled = false
	w.static_root.add_child(ol2)
	CityLights.register_light(ol2, 2.0)

static func _police(w: World, body: StaticBody3D, mb: Dictionary, mbs: Dictionary) -> void:
	var r := POLICE
	var asph := IslandSkyscrapers._surface_mat("Asphalt031", 0.4, Color(0.7, 0.7, 0.72), 0.9)
	var white := IslandSkyscrapers._flat(Color(0.93, 0.93, 0.9), 0.8)
	Miami._box(mb, asph, Vector3(r.position.x, Y + 0.02, r.end.y - 30.0), Vector3(r.end.x, Y + 0.04, r.end.y))          # inner drive and parking apron
	var tf := Time.get_ticks_msec()
	_fence(body, mb, r, 246.0, 262.0)
	print("TIMING   fence ", Time.get_ticks_msec() - tf); tf = Time.get_ticks_msec()
	_gate(w, body, mb, 254.0, r.end.y, "SENTINEL POLICE HEADQUARTERS", "REDLINE ISLAND DIVISION", Color(0.03, 0.08, 0.2))
	print("TIMING   gate ", Time.get_ticks_msec() - tf)
	var pat := Vector2(247.0, 2124.0)
	var pyaw := 0.0
	var t1 := Time.get_ticks_msec()
	var pm := police_mesh()
	print("TIMING   police_mesh ", Time.get_ticks_msec() - t1); t1 = Time.get_ticks_msec()
	if pm != null:
		var pmi := MeshInstance3D.new()
		pmi.name = "PoliceStation"
		pmi.mesh = pm
		pmi.position = Vector3(pat.x, Y, pat.y) - Basis(Vector3.UP, pyaw) * Vector3(PC.x * SC, PC.y * SC, PC.z * SC)
		pmi.rotation.y = pyaw
		pmi.scale = Vector3.ONE * SC
		w.static_root.add_child(pmi)
		for bx in [[620.0, 1330.0, 0.0, 1230.0, -2680.0, -535.0], [1330.0, 1820.0, 0.0, 1440.0, -2600.0, -630.0],
				[1820.0, 2800.0, 0.0, 1000.0, -1976.0, -630.0], [750.0, 1570.0, 0.0, 420.0, -4083.0, -3354.0]]:
			var c := Vector3((bx[0] + bx[1]) * 0.5, (bx[2] + bx[3]) * 0.5, (bx[4] + bx[5]) * 0.5)
			var sz := Vector3(bx[1] - bx[0], bx[3] - bx[2], bx[5] - bx[4]) * SC
			CoastProps._box(body, sz, _mw(c, pat, pyaw), pyaw)
		print("TIMING   pmi+boxes ", Time.get_ticks_msec() - t1); t1 = Time.get_ticks_msec()
		var pad := _mw(Vector3(1069.0, 423.0, -3728.0), pat, pyaw)
		var ch := HelipadChopper.new()
		ch.setup("police")
		w.add_child(ch)
		ch.global_position = Vector3(pad.x, pad.y + 1.9, pad.z)
		ch.rotation.y = PI * 0.5
	print("TIMING   chopper ", Time.get_ticks_msec() - t1); t1 = Time.get_ticks_msec()
	# officers' quarters: the downloaded police headquarters building on the east side of the compound
	MedicalDistrict.place(w, body, "res://assets/district/cook_ville_police_head_quarters.glb", 18.0, Vector2(279.0, 2122.0), -PI * 0.5)
	print("TIMING   quarters ", Time.get_ticks_msec() - t1)
	# cruisers parked inside the fence, nose to the building, painted bays
	for k in range(6):
		var bx2 := r.position.x + 8.0 + k * 4.4
		Miami._box(mb, white, Vector3(bx2 - 2.3, Y + 0.04, r.end.y - 21.0), Vector3(bx2 - 2.2, Y + 0.045, r.end.y - 12.0))
		LazyCars.add(w, "police", Vector3(bx2, Y + Car.RIDE + 0.25, r.end.y - 16.5), PI)

static func _fire(w: World, body: StaticBody3D, mb: Dictionary, mbs: Dictionary) -> void:
	var r := FIREC
	var asph := IslandSkyscrapers._surface_mat("Asphalt031", 0.4, Color(0.7, 0.7, 0.72), 0.9)
	var white := IslandSkyscrapers._flat(Color(0.93, 0.93, 0.9), 0.8)
	var red := IslandSkyscrapers._flat(Color(0.8, 0.08, 0.08), 0.5)
	Miami._box(mb, asph, Vector3(r.position.x, Y + 0.02, r.end.y - 36.0), Vector3(r.end.x, Y + 0.04, r.end.y))
	_fence(body, mb, r, 337.8, 354.2)
	_gate(w, body, mb, 346.0, r.end.y, "EMBER ROCK FIRE & RESCUE", "STATION No. 1", Color(0.35, 0.03, 0.03), true)
	MedicalDistrict.place(w, body, FIRE, 31.3, Vector2(346.0, 2140.0), 0.0)
	# engine bays on the apron in front of the garage doors (painted, red kerb line), a hydrant row
	for k in range(3):
		var bx := 332.0 + k * 11.5
		Miami._box(mb, white, Vector3(bx - 5.0, Y + 0.04, 2154.0), Vector3(bx - 4.9, Y + 0.045, 2172.0))
		Miami._box(mb, white, Vector3(bx + 5.0, Y + 0.04, 2154.0), Vector3(bx + 5.1, Y + 0.045, 2172.0))
	Miami._box(mb, red, Vector3(318.0, Y + 0.04, 2175.0), Vector3(376.0, Y + 0.045, 2175.4))
	_slide_gate(w, body, mb, 337.8, 354.2, r.end.y)
	# the fire engines (the game's own drivable fire truck) parked in two of the three engine bays
	for bxx in [332.0, 355.0]:
		LazyCars.add(w, "firetruck", Vector3(bxx, Y + Car.RIDE + 0.3, 2163.0), 0.0)
	# crew quarters: the downloaded residential house block beside the engine house
	MedicalDistrict.place(w, body, "res://assets/district/residential_quarter_houses.glb", 20.0, Vector2(318.0, 2128.0), PI * 0.5)

	# garage-door glow: warm light spilling out of the engine bays at night
	for gx in [332.0, 343.5, 355.0, 366.5]:
		var gl := OmniLight3D.new()
		gl.position = Vector3(gx, Y + 3.2, 2155.0)
		gl.omni_range = 11.0
		gl.light_color = Color(1.0, 0.88, 0.62)
		gl.shadow_enabled = false
		w.static_root.add_child(gl)
		CityLights.register_light(gl, 1.8)
	# hydrants beside the engine bays
	var hk: Dictionary = _piece("hydrant")
	if not hk.is_empty():
		for hx in [320.0, 372.0]:
			var hmi := MeshInstance3D.new()
			hmi.mesh = hk.mesh
			hmi.position = Vector3(hx, Y + 0.04, 2174.0)
			w.static_root.add_child(hmi)
			CoastProps._box(body, Vector3(0.7, 1.0, 0.7), hmi.position + Vector3(0.0, 0.5, 0.0))

## Retextured copy of the police station mesh: the plain white / grey materials get real CC0 surface textures (triplanar, in model units).
static func police_mesh() -> ArrayMesh:
	var src := load("res://assets/district/police_station_clean.res") as ArrayMesh
	if src == null: return null
	var m := src.duplicate() as ArrayMesh
	CityLights.apply(m, "glass", 1.2)
	var wall := IslandSkyscrapers._surface_mat("Facade005", 0.5 / SC, Color(1.0, 1.0, 1.0), 0.6)
	var conc := IslandSkyscrapers._surface_mat("Concrete042A", 0.35 / SC, Color(1.25, 1.25, 1.25), 0.85)
	var roof := IslandSkyscrapers._surface_mat("Asphalt031", 0.4 / SC, Color(0.8, 0.8, 0.82), 0.9)
	var stone := IslandSkyscrapers._surface_mat("Bricks076A", 0.4 / SC, Color(1.15, 1.15, 1.15), 0.85)
	var map := {"material": wall, "Cladding_Stucco_White": conc, "Cladding_Stucco_White_1": conc, "Color_003": conc, "Color_001": conc,
		"Charcoal_1": roof, "Charcoal": roof, "Gainsboro": stone, "Concrete-rough": stone, "material_1": conc, "Color_002": conc, "Color_005": conc}
	for i in range(m.get_surface_count()):
		var mat := m.surface_get_material(i)
		if mat != null and map.has(String(mat.resource_name)):
			m.surface_set_material(i, map[String(mat.resource_name)])
	return m

static func _people(w: World) -> void:
	var py := Y + 0.04
	# firefighters (the downloaded unrigged model): two in front of each engine bay, one at the crew quarters, one by the gate
	var ff := "res://assets/npc/character_type_fire_fighter.glb"
	for fp in []: # [[333.0, 2176.0, 0.4], [337.0, 2176.5, -0.5], [354.0, 2176.0, 0.2], [358.5, 2176.8, -0.3], [322.0, 2136.0, PI * 0.5], [349.0, 2186.0, PI]]:
		LazyCars.add_figure(w, ff, 1.82, Vector3(fp[0], py, fp[1]), fp[2])
	# gate guards and officers inside the compounds, firefighters at the engine bays, people on the main street pavements
	LazyCars.add_npc(w, "npc_guard", Vector3(251.0, py, 2187.0), PI, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_police", Vector3(262.0, py, 2186.5), 0.0, "Idle")
	var beat: Array = [Vector3(222.0, py, 2170.0), Vector3(280.0, py, 2170.0)]
	LazyCars.add_npc(w, "npc_police", Vector3(230.0, py, 2170.0), PI * 0.5, "Idle", beat)
	LazyCars.add_npc(w, "npc_police", Vector3(240.0, py, 2162.0), PI, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_guard", Vector3(241.3, py, 2162.8), PI * 0.5, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_guard", Vector3(354.0, py, 2186.0), PI, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_police", Vector3(338.0, py, 2186.5), 0.0, "Idle")
	var south_beat: Array = [Vector3(320.0, py, 2180.0), Vector3(372.0, py, 2180.0)]
	LazyCars.add_npc(w, "npc_police", Vector3(330.0, py, 2180.0), PI * 0.5, "Idle", south_beat)
	var main1: Array = [Vector3(222.0, py, 2056.0), Vector3(286.0, py, 2056.0)]
	LazyCars.add_npc(w, "npc_luiz", Vector3(240.0, py, 2056.0), PI * 0.5, "Idle", main1)
	var main2: Array = [Vector3(312.0, py, 2077.0), Vector3(380.0, py, 2077.0)]
	LazyCars.add_npc(w, "npc_ch21", Vector3(340.0, py, 2077.0), -PI * 0.5, "Idle", main2)
	LazyCars.add_npc(w, "npc_ch21", Vector3(300.0, py, 2035.0), PI, "UAL_Idle_Talking")
	LazyCars.add_npc(w, "npc_luiz", Vector3(301.2, py, 2036.0), -PI * 0.5, "UAL_Idle_Talking")


# ------------------------------------------------------------------ fire hydrants round the island

## Fire hydrants (downloaded model) on the island's pavements: 0.7 m in from the kerb (not in the road, not in the middle of the footpath),
## at random spots along the street edges, never near a junction, a bridge or the metro. Solid.
static func scatter_hydrants(w: World, count := 26) -> void:
	var hy: Dictionary = MedicalDistrict._bake("res://assets/district/fire_hydrant.glb", 0.5)
	if hy.is_empty(): return
	var body := StaticBody3D.new()
	body.name = "Hydrants"
	body.collision_layer = 1
	w.static_root.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var cand: Array = []
	for e in CityData.edges:
		if int(e[2]) != 0: continue
		var a := CityData.nodes[int(e[0])]
		var b := CityData.nodes[int(e[1])]
		if minf(a.y, b.y) < 1930.0 or maxf(a.y, b.y) > 2470.0 or minf(a.x, b.x) < -230.0 or maxf(a.x, b.x) > 640.0: continue
		if absf(a.x) < 1.0 and absf(b.x) < 1.0: continue          # the bridge road
		var len := a.distance_to(b)
		if len < 60.0: continue
		var d := (b - a) / len
		var nrm := Vector2(-d.y, d.x)
		for k in range(4):
			var t := rng.randf_range(16.0, len - 16.0)
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var pos := a + d * t + nrm * side * (Miami.KERB + 0.7)
			cand.append({"p": pos, "face": atan2(nrm.x * side, nrm.y * side)})
	cand.shuffle()
	var placed := 0
	var spots: Array = []
	for c in cand:
		if placed >= count: break
		var p: Vector2 = c.p
		if CityData.is_water(p.x, p.y): continue
		if Metro.in_stairs(Vector3(p.x, 0.0, p.y)): continue
		var ok := true
		for q in spots:
			if (q as Vector2).distance_to(p) < 40.0: ok = false
		if not ok: continue
		spots.append(p)
		var mi := MeshInstance3D.new()
		mi.mesh = hy.mesh
		mi.position = Vector3(p.x, Miami.PY - float(hy.miny), p.y)
		mi.scale = Vector3.ONE * float(hy.s)
		mi.rotation.y = float(c.face)
		mi.visibility_range_end = 200.0
		w.static_root.add_child(mi)
		var sz: Vector3 = hy.size
		CoastProps._box(body, Vector3(maxf(sz.x, 0.3), sz.y, maxf(sz.z, 0.3)), Vector3(p.x, Miami.PY + sz.y * 0.5, p.y))
		placed += 1
		if placed <= 3: print("HYDRANT ", p)
	print("hydrants placed: ", placed)
