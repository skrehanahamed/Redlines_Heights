class_name IslandSkyscrapers
extends RefCounted
## Redline Island Central Skyscraper District & Plaza:
## Places all 5 mainland-exclusive skyscrapers in the prime central island block (X: [0, 200], Z: [1950, 2200]):
## 1. The Vizcayne (153m) - East side, grand lobby and pool terrace facing East Avenue (X = 200)
## 2. Bank of China Tower (165m) - North side, entrance canopy facing North Street (Z = 1950)
## 3. AIT01 W2W5 (29m) - West side, long commercial storefront facade facing Bridge Boulevard (X = 0)
## 4. AIT01 W2W7 (50m) - South-West side, corner boutique entrance facing Central Crossroad (Z = 2200)
## 5. Skyscraper Peak (217m) - South-East side, rotunda atrium entrance facing Central Crossroad (Z = 2200)
## Plus central parking facility with marked bays, wheel stops, LED light poles, paved pedestrian pathways and palm trees.

const T := "res://assets/town/"
const TW := "res://assets/miami/towers/"
const MIAMI_DIR := "res://assets/miami/"
const PY := 0.22

static var _mats := {}
static var _burj_mesh: Mesh
const MAST_H := 8.0     # projector masts: tall enough that the beams reach the tower at a shallow angle
const FLAG_Y := 50.0     # height of the middle of the projected flag

static func _flat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var k := "flat|%s|%s|%s" % [color.to_html(), rough, metal]
	if _mats.has(k): return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_mats[k] = m
	return m

static func _tex(name: String) -> Texture2D:
	var path := MIAMI_DIR + "tex/" + name
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func _surface_mat(name: String, scale: float, tint := Color.WHITE, rough := 0.85) -> StandardMaterial3D:
	var k := "surf|%s|%s|%s" % [name, scale, tint.to_html()]
	if _mats.has(k): return _mats[k]
	var m := StandardMaterial3D.new()
	var t := _tex(name + "_Color.jpg")
	if t != null:
		m.albedo_texture = t
	var n := _tex(name + "_NormalGL.jpg")
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
	var r := _tex(name + "_Roughness.jpg")
	if r != null:
		m.roughness_texture = r
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.albedo_color = tint
	m.roughness = rough
	_mats[k] = m
	return m

static func build(w: World) -> void:
	print("IslandSkyscrapers: building central skyscraper district...")
	Miami._prep_props()
	Miami._glass_mats()

	var body := StaticBody3D.new()
	body.name = "IslandSkyscrapersBody"
	body.collision_layer = 1
	w.static_root.add_child(body)
	Miami.solid_body = body

	var mb := {}
	var mb_pave := {}

	# -------------------------------------------------------------
	# 1. BASE DISTRICT SLAB (covers the entire central city block)
	# Block bounds: X in [6.7, 193.3], Z in [1956.7, 2193.3]
	# -------------------------------------------------------------
	var x0 := Miami.XS[1] + Miami.KERB       # 0.0 + 6.7 = 6.7
	var x1 := Miami.XS[2] - Miami.KERB       # 200.0 - 6.7 = 193.3
	var z0 := Miami.ZS[0] + Miami.KERB       # 1950.0 + 6.7 = 1956.7
	var z1 := Miami.ZS[1] - Miami.KERB       # 2200.0 - 6.7 = 2193.3

	var pave_mat := _surface_mat("PavingStones136", 0.45, Color(1.15, 1.1, 1.0), 0.85)
	Miami._box(mb_pave, pave_mat, Vector3(x0, 0.0, z0), Vector3(x1, PY, z1))
	CoastProps._box(body, Vector3(x1 - x0, PY, z1 - z0), Vector3((x0 + x1) * 0.5, PY * 0.5, (z0 + z1) * 0.5))

	# -------------------------------------------------------------
	# 2. BAKE & PLACE THE 5 SKYSCRAPERS
	# -------------------------------------------------------------
	# A. The Vizcayne (153m) - East side
	var viz_b: Dictionary = Miami._bake(TW + "hivizcayne.FBX", "", 0.0, 1.0)
	if not viz_b.is_empty():
		CityLights.apply_shader(viz_b.mesh, {"mode": 3, "emit": TW + "hivizcayne_win.png", "lit_frac": 0.5, "gain": 1.1})
		var pos := Vector3(135.0, PY, 2060.0)
		var yaw := PI * 0.5 # Front lobby faces East towards avenue at X = 200
		_spawn_tower(w, body, viz_b.mesh, pos, yaw, viz_b.size)

	# B. Bank of China Tower (165m) - North side
	var boc_b: Dictionary = Renowood._baked(T + "bank_of_china_tower.glb", 1.0, [], true, "", 0.45)
	if not boc_b.is_empty():
		CityLights.apply_shader(boc_b.mesh, {"mode": 1, "floor_h": 4.5, "cell_w": 3.0, "lit_frac": 0.52, "gain": 1.25})
		var pos := Vector3(50.0, PY, 1990.0)
		var yaw := PI # Front entrance canopy faces North towards street at Z = 1950
		_spawn_tower(w, body, boc_b.mesh, pos, yaw, boc_b.size)

	# C. AIT01 W2W5 (29m) - West side
	var w2w5_b: Dictionary = Miami._bake(TW + "AIT01W2W5.FBX", "", 0.0, 1.0)
	if not w2w5_b.is_empty():
		CityLights.apply_shader(w2w5_b.mesh, {"mode": 3, "emit": TW + "AIT01W2W5_win.png", "lit_frac": 0.55, "gain": 1.35})
		var pos := Vector3(45.0, PY, 2060.0)
		var yaw := -PI * 0.5 # Storefront facade faces West towards bridge road at X = 0
		_spawn_tower(w, body, w2w5_b.mesh, pos, yaw, w2w5_b.size)

	# D. AIT01 W2W7 (50m) - South-West side
	var w2w7_b: Dictionary = Miami._bake(TW + "AIT01W2W7.FBX", "", 0.0, 1.0)
	if not w2w7_b.is_empty():
		CityLights.apply_shader(w2w7_b.mesh, {"mode": 3, "emit": TW + "AIT01W2W7_win.png", "lit_frac": 0.5, "gain": 1.1})
		var pos := Vector3(45.0, PY, 2165.0)
		var yaw := 0.0 # Luxury boutique entrance faces South towards road at Z = 2200
		_spawn_tower(w, body, w2w7_b.mesh, pos, yaw, w2w7_b.size)

	# E. Burj Khalifa (240m) - South-East side
	var burj_b: Dictionary = Renowood._baked(T + "burj_khalifa.glb", 240.0)
	if not burj_b.is_empty():
		# Surface 0 (Vitres): Architectural reflective curtain-wall glass facade
		CityLights.apply_shader(burj_b.mesh, {
			"mode": 1,
			"facade": true,
			"radial": true,
			"center": Vector2(145.0, 2156.0),
			"albedo_tex": load("res://assets/town/burj_facade.png"),
			"albedo_col": Color(0.80, 0.87, 0.95),
			"floor_h": 3.8,
			"cell_w": 2.8,
			"metal": 0.35,
			"rough": 0.28,
			"lit_frac": 0.52,
			"gain": 1.45,
			"warm": Color(1.0, 0.82, 0.52)
		}, "vitres")

		# Surface 1 (Rebord): the tiered podium and silver ribs - silver fins by day, drifting LED colours at night
		var reb_sm := ShaderMaterial.new()
		reb_sm.shader = load("res://shaders/burj_trim.gdshader") as Shader
		reb_sm.set_shader_parameter("gain", 0.0)   # LED strips off: the projectors do the light show now
		CityLights._shaders.append(reb_sm)
		(burj_b.mesh as ArrayMesh).surface_set_material(1, reb_sm)

		var pos := Vector3(145.0, PY, 2156.0)
		var yaw := 0.0
		_burj_mesh = burj_b.mesh
		_spawn_tower(w, body, burj_b.mesh, pos, yaw, burj_b.size)

	# -------------------------------------------------------------
	# 3. DEDICATED CENTRAL PARKING LOT
	# Positioned in the southern courtyard between W2W7 and Peak:
	# X in [68.0, 118.0], Z in [2118.0, 2193.3]
	# -------------------------------------------------------------
	var pk_x0 := 68.0
	var pk_x1 := 118.0
	var pk_z0 := 2118.0
	var pk_z1 := z1 # 2193.3, connects to road sidewalk
	var pk_py := PY + 0.015

	var asphalt := _flat(Color("#28282b"), 0.92)
	var kerb_mat := _flat(Color("#c2bfb8"), 0.85)
	var line_mat := _flat(Color("#f0eee4"), 0.8)
	var stop_mat := _flat(Color("#e0ded8"), 0.85)

	# Asphalt bed
	Miami._box(mb, asphalt, Vector3(pk_x0, PY, pk_z0), Vector3(pk_x1, pk_py, pk_z1))
	CoastProps._box(body, Vector3(pk_x1 - pk_x0, 0.05, pk_z1 - pk_z0), Vector3((pk_x0 + pk_x1) * 0.5, pk_py, (pk_z0 + pk_z1) * 0.5))
	(CityBuild.layout.lots as Array).append([pk_x0, pk_z0, pk_x1, pk_z1])

	# Concrete border kerb around the parking lot (except entrance opening)
	var kw := 0.28
	var kh := 0.16
	# North border
	Miami._box(mb, kerb_mat, Vector3(pk_x0 - kw, PY, pk_z0 - kw), Vector3(pk_x1 + kw, PY + kh, pk_z0))
	CoastProps._box(body, Vector3(pk_x1 - pk_x0 + kw * 2.0, kh, kw), Vector3((pk_x0 + pk_x1) * 0.5, PY + kh * 0.5, pk_z0 - kw * 0.5))
	# West border
	Miami._box(mb, kerb_mat, Vector3(pk_x0 - kw, PY, pk_z0), Vector3(pk_x0, PY + kh, pk_z1))
	CoastProps._box(body, Vector3(kw, kh, pk_z1 - pk_z0), Vector3(pk_x0 - kw * 0.5, PY + kh * 0.5, (pk_z0 + pk_z1) * 0.5))
	# East border
	Miami._box(mb, kerb_mat, Vector3(pk_x1, PY, pk_z0), Vector3(pk_x1 + kw, PY + kh, pk_z1))
	CoastProps._box(body, Vector3(kw, kh, pk_z1 - pk_z0), Vector3(pk_x1 + kw * 0.5, PY + kh * 0.5, (pk_z0 + pk_z1) * 0.5))

	# South street curbs flanking the 8m entrance driveway (entrance between X=89 and X=97)
	Miami._box(mb, kerb_mat, Vector3(pk_x0 - kw, PY, pk_z1), Vector3(89.0, PY + kh, pk_z1 + kw))
	CoastProps._box(body, Vector3(89.0 - (pk_x0 - kw), kh, kw), Vector3((pk_x0 - kw + 89.0) * 0.5, PY + kh * 0.5, pk_z1 + kw * 0.5))
	Miami._box(mb, kerb_mat, Vector3(97.0, PY, pk_z1), Vector3(pk_x1 + kw, PY + kh, pk_z1 + kw))
	CoastProps._box(body, Vector3(pk_x1 + kw - 97.0, kh, kw), Vector3((97.0 + pk_x1 + kw) * 0.5, PY + kh * 0.5, pk_z1 + kw * 0.5))

	# Parking Bays: Two rows of bays (West row and East row) facing the central 7.5m driving lane
	var bay_w := 3.2
	var bay_d := 5.8
	var lw := 0.12
	var ly := pk_py + 0.005

	# West side bays (along X=70..76)
	var z_cur := pk_z0 + 4.0
	while z_cur + bay_w <= pk_z1 - 8.0:
		Miami._box(mb, line_mat, Vector3(70.0, pk_py, z_cur - lw * 0.5), Vector3(70.0 + bay_d, ly, z_cur + lw * 0.5))
		var stop_z := z_cur + bay_w * 0.5
		Miami._box(mb, stop_mat, Vector3(70.4, pk_py, stop_z - 0.9), Vector3(70.7, pk_py + 0.12, stop_z + 0.9))
		CoastProps._box(body, Vector3(0.3, 0.12, 1.8), Vector3(70.55, pk_py + 0.06, stop_z))
		z_cur += bay_w
	Miami._box(mb, line_mat, Vector3(70.0, pk_py, z_cur - lw * 0.5), Vector3(70.0 + bay_d, ly, z_cur + lw * 0.5))

	# East side bays (along X=110..116)
	z_cur = pk_z0 + 4.0
	while z_cur + bay_w <= pk_z1 - 8.0:
		Miami._box(mb, line_mat, Vector3(116.0 - bay_d, pk_py, z_cur - lw * 0.5), Vector3(116.0, ly, z_cur + lw * 0.5))
		var stop_z := z_cur + bay_w * 0.5
		Miami._box(mb, stop_mat, Vector3(115.3, pk_py, stop_z - 0.9), Vector3(115.6, pk_py + 0.12, stop_z + 0.9))
		CoastProps._box(body, Vector3(0.3, 0.12, 1.8), Vector3(115.45, pk_py + 0.06, stop_z))
		z_cur += bay_w
	Miami._box(mb, line_mat, Vector3(116.0 - bay_d, pk_py, z_cur - lw * 0.5), Vector3(116.0, ly, z_cur + lw * 0.5))

	# -------------------------------------------------------------
	# 3B. NORTH EXECUTIVE PARKING LOT (serving Bank of China & Vizcayne North)
	# Location: X in [112.0, 168.0], Z in [1956.7, 2002.0]
	# -------------------------------------------------------------
	var n_x0 := 112.0
	var n_x1 := 168.0
	var n_z0 := z0 # 1956.7 (connects directly to North road)
	var n_z1 := 2002.0
	var n_py := PY + 0.015

	Miami._box(mb, asphalt, Vector3(n_x0, PY, n_z0), Vector3(n_x1, n_py, n_z1))
	CoastProps._box(body, Vector3(n_x1 - n_x0, 0.05, n_z1 - n_z0), Vector3((n_x0 + n_x1) * 0.5, n_py, (n_z0 + n_z1) * 0.5))
	(CityBuild.layout.lots as Array).append([n_x0, n_z0, n_x1, n_z1])

	# Border kerbs
	Miami._box(mb, kerb_mat, Vector3(n_x0 - kw, PY, n_z1), Vector3(n_x1 + kw, PY + kh, n_z1 + kw))
	CoastProps._box(body, Vector3(n_x1 - n_x0 + kw * 2.0, kh, kw), Vector3((n_x0 + n_x1) * 0.5, PY + kh * 0.5, n_z1 + kw * 0.5))
	Miami._box(mb, kerb_mat, Vector3(n_x0 - kw, PY, n_z0), Vector3(n_x0, PY + kh, n_z1))
	CoastProps._box(body, Vector3(kw, kh, n_z1 - n_z0), Vector3(n_x0 - kw * 0.5, PY + kh * 0.5, (n_z0 + n_z1) * 0.5))
	Miami._box(mb, kerb_mat, Vector3(n_x1, PY, n_z0), Vector3(n_x1 + kw, PY + kh, n_z1))
	CoastProps._box(body, Vector3(kw, kh, n_z1 - n_z0), Vector3(n_x1 + kw * 0.5, PY + kh * 0.5, (n_z0 + n_z1) * 0.5))

	# North street curbs flanking the 10m driveway (between X=135 and X=145)
	Miami._box(mb, kerb_mat, Vector3(n_x0 - kw, PY, n_z0 - kw), Vector3(135.0, PY + kh, n_z0))
	CoastProps._box(body, Vector3(135.0 - (n_x0 - kw), kh, kw), Vector3((n_x0 - kw + 135.0) * 0.5, PY + kh * 0.5, n_z0 - kw * 0.5))
	Miami._box(mb, kerb_mat, Vector3(145.0, PY, n_z0 - kw), Vector3(n_x1 + kw, PY + kh, n_z0))
	CoastProps._box(body, Vector3(n_x1 + kw - 145.0, kh, kw), Vector3((145.0 + n_x1 + kw) * 0.5, PY + kh * 0.5, n_z0 - kw * 0.5))

	# North Lot Bays: West row (X=114..120) and East row (X=160..166)
	var nz_cur := n_z0 + 8.0
	while nz_cur + bay_w <= n_z1 - 3.0:
		# West bay
		Miami._box(mb, line_mat, Vector3(n_x0 + 2.0, n_py, nz_cur - lw * 0.5), Vector3(n_x0 + 2.0 + bay_d, ly, nz_cur + lw * 0.5))
		var stop_z := nz_cur + bay_w * 0.5
		Miami._box(mb, stop_mat, Vector3(n_x0 + 2.4, n_py, stop_z - 0.9), Vector3(n_x0 + 2.7, n_py + 0.12, stop_z + 0.9))
		CoastProps._box(body, Vector3(0.3, 0.12, 1.8), Vector3(n_x0 + 2.55, n_py + 0.06, stop_z))
		# East bay
		Miami._box(mb, line_mat, Vector3(n_x1 - 2.0 - bay_d, n_py, nz_cur - lw * 0.5), Vector3(n_x1 - 2.0, ly, nz_cur + lw * 0.5))
		Miami._box(mb, stop_mat, Vector3(n_x1 - 2.7, n_py, stop_z - 0.9), Vector3(n_x1 - 2.4, n_py + 0.12, stop_z + 0.9))
		CoastProps._box(body, Vector3(0.3, 0.12, 1.8), Vector3(n_x1 - 2.55, n_py + 0.06, stop_z))
		nz_cur += bay_w
	Miami._box(mb, line_mat, Vector3(n_x0 + 2.0, n_py, nz_cur - lw * 0.5), Vector3(n_x0 + 2.0 + bay_d, ly, nz_cur + lw * 0.5))
	Miami._box(mb, line_mat, Vector3(n_x1 - 2.0 - bay_d, n_py, nz_cur - lw * 0.5), Vector3(n_x1 - 2.0, ly, nz_cur + lw * 0.5))

	# -------------------------------------------------------------
	# 3C. WEST COMMERCIAL RETAIL PARKING LOT (serving W2W5 & W2W7 retail)
	# Location: X in [6.7, 56.0], Z in [2100.0, 2142.0]
	# -------------------------------------------------------------
	var w_x0 := x0 # 6.7 (connects directly to West road)
	var w_x1 := 56.0
	var w_z0 := 2100.0
	var w_z1 := 2142.0
	var w_py := PY + 0.015

	Miami._box(mb, asphalt, Vector3(w_x0, PY, w_z0), Vector3(w_x1, w_py, w_z1))
	CoastProps._box(body, Vector3(w_x1 - w_x0, 0.05, w_z1 - w_z0), Vector3((w_x0 + w_x1) * 0.5, w_py, (w_z0 + w_z1) * 0.5))
	(CityBuild.layout.lots as Array).append([w_x0, w_z0, w_x1, w_z1])

	# Border kerbs
	Miami._box(mb, kerb_mat, Vector3(w_x0, PY, w_z0 - kw), Vector3(w_x1 + kw, PY + kh, w_z0))
	CoastProps._box(body, Vector3(w_x1 - w_x0 + kw, kh, kw), Vector3((w_x0 + w_x1 + kw) * 0.5, PY + kh * 0.5, w_z0 - kw * 0.5))
	Miami._box(mb, kerb_mat, Vector3(w_x0, PY, w_z1), Vector3(w_x1 + kw, PY + kh, w_z1 + kw))
	CoastProps._box(body, Vector3(w_x1 - w_x0 + kw, kh, kw), Vector3((w_x0 + w_x1 + kw) * 0.5, PY + kh * 0.5, w_z1 + kw * 0.5))
	Miami._box(mb, kerb_mat, Vector3(w_x1, PY, w_z0), Vector3(w_x1 + kw, PY + kh, w_z1))
	CoastProps._box(body, Vector3(kw, kh, w_z1 - w_z0), Vector3(w_x1 + kw * 0.5, PY + kh * 0.5, (w_z0 + w_z1) * 0.5))

	# West road curbs flanking the 10m driveway (between Z=2116 and Z=2126)
	Miami._box(mb, kerb_mat, Vector3(w_x0 - kw, PY, w_z0 - kw), Vector3(w_x0, PY + kh, 2116.0))
	CoastProps._box(body, Vector3(kw, kh, 2116.0 - (w_z0 - kw)), Vector3(w_x0 - kw * 0.5, PY + kh * 0.5, (w_z0 - kw + 2116.0) * 0.5))
	Miami._box(mb, kerb_mat, Vector3(w_x0 - kw, PY, 2126.0), Vector3(w_x0, PY + kh, w_z1 + kw))
	CoastProps._box(body, Vector3(kw, kh, w_z1 + kw - 2126.0), Vector3(w_x0 - kw * 0.5, PY + kh * 0.5, (2126.0 + w_z1 + kw) * 0.5))

	# West Lot Bays: North row (Z=2102..2108) and South row (Z=2134..2140)
	var wx_cur := w_x0 + 10.0
	while wx_cur + bay_w <= w_x1 - 3.0:
		# North bay
		Miami._box(mb, line_mat, Vector3(wx_cur - lw * 0.5, w_py, w_z0 + 2.0), Vector3(wx_cur + lw * 0.5, ly, w_z0 + 2.0 + bay_d))
		var stop_x := wx_cur + bay_w * 0.5
		Miami._box(mb, stop_mat, Vector3(stop_x - 0.9, w_py, w_z0 + 2.4), Vector3(stop_x + 0.9, w_py + 0.12, w_z0 + 2.7))
		CoastProps._box(body, Vector3(1.8, 0.12, 0.3), Vector3(stop_x, w_py + 0.06, w_z0 + 2.55))
		# South bay
		Miami._box(mb, line_mat, Vector3(wx_cur - lw * 0.5, w_py, w_z1 - 2.0 - bay_d), Vector3(wx_cur + lw * 0.5, ly, w_z1 - 2.0))
		Miami._box(mb, stop_mat, Vector3(stop_x - 0.9, w_py, w_z1 - 2.7), Vector3(stop_x + 0.9, w_py + 0.12, w_z1 - 2.4))
		CoastProps._box(body, Vector3(1.8, 0.12, 0.3), Vector3(stop_x, w_py + 0.06, w_z1 - 2.55))
		wx_cur += bay_w
	Miami._box(mb, line_mat, Vector3(wx_cur - lw * 0.5, w_py, w_z0 + 2.0), Vector3(wx_cur + lw * 0.5, ly, w_z0 + 2.0 + bay_d))
	Miami._box(mb, line_mat, Vector3(wx_cur - lw * 0.5, w_py, w_z1 - 2.0 - bay_d), Vector3(wx_cur + lw * 0.5, ly, w_z1 - 2.0))

	# -------------------------------------------------------------
	# 4. PEDESTRIAN PATHWAYS & CONNECTORS
	# -------------------------------------------------------------
	var walk_mat := _surface_mat("PavingStones136", 0.35, Color(1.25, 1.22, 1.15), 0.75)
	var wy := PY + 0.01

	# Pathway 1: Central North-South Promenade from Bank of China south plaza down to South Parking Lot (X: 89..97, Z: 2010..2118)
	Miami._box(mb_pave, walk_mat, Vector3(89.0, PY, 2008.0), Vector3(97.0, wy, pk_z0))

	# Pathway 2: East-West Central Connector between W2W5 East plaza and The Vizcayne West plaza (Z: 2056..2064, X: 73..88)
	Miami._box(mb_pave, walk_mat, Vector3(73.0, PY, 2056.0), Vector3(88.0, wy, 2064.0))

	# Pathway 3: Crossway connecting Burj Khalifa west entrance to South Parking Lot (X: 118..125, Z: 2150..2162)
	Miami._box(mb_pave, walk_mat, Vector3(118.0, PY, 2150.0), Vector3(125.0, wy, 2162.0))

	# Pathway 4: Crossway connecting AIT01 W2W7 east walkway to South Parking Lot (X: 61..68, Z: 2160..2170)
	Miami._box(mb_pave, walk_mat, Vector3(61.0, PY, 2160.0), Vector3(68.0, wy, 2170.0))

	# Pathway 5: Connector from North Executive Lot to Bank of China east entrance (X: 68..112, Z: 1986..1994)
	Miami._box(mb_pave, walk_mat, Vector3(68.0, PY, 1986.0), Vector3(112.0, wy, 1994.0))

	# Pathway 6: Connector from West Commercial Lot to Central Promenade (X: 56..89, Z: 2117..2125)
	Miami._box(mb_pave, walk_mat, Vector3(56.0, PY, 2117.0), Vector3(89.0, wy, 2125.0))

	# -------------------------------------------------------------
	# 4B. BURJ KHALIFA GRAND WATERFRONT PLAZA & REFLECTIVE LAKE
	# Utilizes the entire South-East site (X: 120..192.5, Z: 2125..2192.5)
	# -------------------------------------------------------------
	var bk_x0 := 120.0
	var bk_x1 := 192.5
	var bk_z0 := 2125.0
	var bk_z1 := 2192.5
	var bk_py := PY + 0.02

	# Grand Plaza Paving
	var bk_pave := _surface_mat("PavingStones130", 0.35, Color(1.15, 1.12, 1.08), 0.72)
	Miami._box(mb_pave, bk_pave, Vector3(bk_x0, PY, bk_z0), Vector3(bk_x1, bk_py, bk_z1))
	CoastProps._box(body, Vector3(bk_x1 - bk_x0, 0.04, bk_z1 - bk_z0), Vector3((bk_x0 + bk_x1) * 0.5, PY + 0.02, (bk_z0 + bk_z1) * 0.5))

	# Dark granite coping perimeter around Burj Khalifa podium
	var bk_border := _flat(Color("#222326"), 0.4, 0.3)
	var bkw := 0.35
	var bkh := 0.14
	Miami._box(mb, bk_border, Vector3(bk_x0 - bkw, PY, bk_z0 - bkw), Vector3(bk_x1 + bkw, PY + bkh, bk_z0))
	Miami._box(mb, bk_border, Vector3(bk_x0 - bkw, PY, bk_z1), Vector3(bk_x1 + bkw, PY + bkh, bk_z1 + bkw))
	Miami._box(mb, bk_border, Vector3(bk_x0 - bkw, PY, bk_z0), Vector3(bk_x0, PY + bkh, bk_z1))
	Miami._box(mb, bk_border, Vector3(bk_x1, PY, bk_z0), Vector3(bk_x1 + bkw, PY + bkh, bk_z1))

	# Reflective Lake (Architectural Water Basin on East waterfront terrace)
	var lake_x0 := 169.0
	var lake_x1 := 188.5
	var lake_z0 := 2132.0
	var lake_z1 := 2178.0
	var lkw := 0.45
	var lkh := 0.32

	# Granite coping rim around lake
	Miami._box(mb, bk_border, Vector3(lake_x0 - lkw, bk_py, lake_z0 - lkw), Vector3(lake_x1 + lkw, bk_py + lkh, lake_z0))
	CoastProps._box(body, Vector3(lake_x1 - lake_x0 + lkw * 2.0, lkh, lkw), Vector3((lake_x0 + lake_x1) * 0.5, bk_py + lkh * 0.5, lake_z0 - lkw * 0.5))
	Miami._box(mb, bk_border, Vector3(lake_x0 - lkw, bk_py, lake_z1), Vector3(lake_x1 + lkw, bk_py + lkh, lake_z1 + lkw))
	CoastProps._box(body, Vector3(lake_x1 - lake_x0 + lkw * 2.0, lkh, lkw), Vector3((lake_x0 + lake_x1) * 0.5, bk_py + lkh * 0.5, lake_z1 + lkw * 0.5))
	Miami._box(mb, bk_border, Vector3(lake_x0 - lkw, bk_py, lake_z0), Vector3(lake_x0, bk_py + lkh, lake_z1))
	CoastProps._box(body, Vector3(lkw, lkh, lake_z1 - lake_z0), Vector3(lake_x0 - lkw * 0.5, bk_py + lkh * 0.5, (lake_z0 + lake_z1) * 0.5))
	Miami._box(mb, bk_border, Vector3(lake_x1, bk_py, lake_z0), Vector3(lake_x1 + lkw, bk_py + lkh, lake_z1))
	CoastProps._box(body, Vector3(lkw, lkh, lake_z1 - lake_z0), Vector3(lake_x1 + lkw * 0.5, bk_py + lkh * 0.5, (lake_z0 + lake_z1) * 0.5))

	# Realistic Animated Fountain Water
	var water_sh := load("res://shaders/fountain_water.gdshader") as Shader
	var water_sm := ShaderMaterial.new()
	water_sm.shader = water_sh
	water_sm.set_shader_parameter("normal_tex", load("res://assets/coast/ocean_tile_normal.png"))
	water_sm.set_shader_parameter("shallow_col", Color(0.15, 0.72, 0.85))
	water_sm.set_shader_parameter("deep_col", Color(0.02, 0.30, 0.44))
	water_sm.set_shader_parameter("glow_col", Color(0.2, 0.92, 1.0))
	water_sm.set_shader_parameter("flow_speed", 0.65)
	water_sm.set_shader_parameter("normal_depth", 0.28)
	water_sm.set_shader_parameter("shallow_col", Color(0.10, 0.62, 0.78))
	water_sm.set_shader_parameter("deep_col", Color(0.0, 0.17, 0.27))
	CityLights._shaders.append(water_sm)

	water_sm.set_shader_parameter("clarity", 0.45)
	# pool-tile floor under the water so it reads as a real basin
	Miami._box(mb, _flat(Color(0.10, 0.36, 0.48), 0.3, 0.1), Vector3(lake_x0, bk_py, lake_z0), Vector3(lake_x1, bk_py + 0.05, lake_z1))
	var water_mi := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(lake_x1 - lake_x0, 0.02, lake_z1 - lake_z0)
	wm.flip_faces = false
	water_mi.mesh = wm
	water_mi.material_override = water_sm
	water_mi.position = Vector3((lake_x0 + lake_x1) * 0.5, bk_py + 0.30, (lake_z0 + lake_z1) * 0.5)
	w.static_root.add_child(water_mi)

	# Fountain: the Artemis fountain model on a marble island in the middle of the lake, ringed by water jets
	var jet_spots: Array = _build_fountain(w, body, mb, Vector3((lake_x0 + lake_x1) * 0.5, bk_py, (lake_z0 + lake_z1) * 0.5), lake_x0, lake_x1, lake_z0, lake_z1)

	# Planting round the lake and along the inside of the fence: hedges, ferns, monstera, banana and tropical palms, flowerbeds
	var prng := RandomNumberGenerator.new()
	prng.seed = 4242
	var green: Array = ["bush", "bush", "fern", "monstera", "flowerbed", "bush"]
	# behind the benches on the lake's west edge
	var gz := lake_z0 + 2.0
	while gz < lake_z1 - 1.0:
		if absf(gz - 2148.0) > 2.2 and absf(gz - 2162.0) > 2.2 and absf(gz - 2155.0) > 2.6:
			var kind: String = green[prng.randi() % green.size()]
			Miami._put(kind, Vector3(165.6, bk_py, gz), prng.randf() * TAU, (0.25 if kind == "flowerbed" else 1.0) * prng.randf_range(0.9, 1.2))
		gz += 3.2
	# the two ends of the lake: low planting with a tropical palm in each corner
	for ez in [lake_z0 - 3.4, lake_z1 + 3.6]:
		var ex := lake_x0 + 1.5
		while ex < lake_x1 - 1.0:
			var kind2: String = green[prng.randi() % green.size()]
			Miami._put(kind2, Vector3(ex, bk_py, ez), prng.randf() * TAU, (0.25 if kind2 == "flowerbed" else 1.0) * prng.randf_range(0.9, 1.2))
			ex += 3.0
		Miami._put("trop_palm%d" % (1 + prng.randi() % 3), Vector3(lake_x0 - 1.5, bk_py, ez), prng.randf() * TAU, 1.0)
		Miami._put("trop_palm%d" % (1 + prng.randi() % 3), Vector3(lake_x1 + 1.5, bk_py, ez), prng.randf() * TAU, 1.0)
	# east promenade: ferns between the palms and the fence
	for fz2 in [2140.0, 2150.0, 2160.0, 2170.0]:
		Miami._put("fern", Vector3(191.3, bk_py, fz2), prng.randf() * TAU, 1.0)
	# hedge line just inside the north and south fence runs
	for hx in [123.5, 127.0, 130.5, 134.0, 138.0, 160.0, 164.0, 168.0, 172.0, 176.0, 180.0, 184.0, 188.0]:
		Miami._put("bush", Vector3(hx, bk_py, bk_z0 + 2.0), prng.randf() * TAU, prng.randf_range(1.0, 1.3))
	for hx2 in [123.5, 127.0, 130.5, 160.0, 164.0, 168.0, 172.0, 176.0, 180.0, 184.0, 188.0]:
		Miami._put("bush", Vector3(hx2, bk_py, bk_z1 - 2.0), prng.randf() * TAU, prng.randf_range(1.0, 1.3))
	Miami._put("banana", Vector3(122.5, bk_py, 2128.0), 0.0, 1.0)
	Miami._put("banana", Vector3(190.5, bk_py, 2128.5), 0.0, 1.0)
	Miami._put("banana", Vector3(190.5, bk_py, 2188.5), 0.0, 1.0)

	# VIP Forecourt Drop-off (South side facing boulevard road)
	var vip_pave := _surface_mat("Terrazzo003", 0.4, Color(1.12, 1.1, 1.05))
	Miami._box(mb_pave, vip_pave, Vector3(135.0, bk_py, 2178.0), Vector3(155.0, bk_py + 0.05, 2192.5))

	# Landscaping: Flowerbeds & Shrubbery
	Miami._put("flowerbed", Vector3(132.0, bk_py, 2185.0), 0.0, 0.25)
	Miami._put("flowerbed", Vector3(158.0, bk_py, 2185.0), 0.0, 0.25)
	Miami._put("flowerbed", Vector3(167.5, bk_py, 2142.0), 0.0, 0.25)
	Miami._put("flowerbed", Vector3(167.5, bk_py, 2168.0), 0.0, 0.25)

	Miami._put("bush", Vector3(123.5, bk_py, 2135.0), 0.0, 1.3)
	Miami._put("bush", Vector3(123.5, bk_py, 2155.0), 0.0, 1.3)
	Miami._put("bush", Vector3(123.5, bk_py, 2175.0), 0.0, 1.3)

	# Benches: Along west lake edge facing water, and along east waterfront promenade
	Miami._put("bench", Vector3(167.5, bk_py, 2148.0), PI * 0.5, 1.5)
	Miami._put("bench", Vector3(167.5, bk_py, 2162.0), PI * 0.5, 1.5)
	Miami._put("bench", Vector3(190.5, bk_py, 2145.0), -PI * 0.5, 1.5)
	Miami._put("bench", Vector3(190.5, bk_py, 2165.0), -PI * 0.5, 1.5)

	# -------------------------------------------------------------
	# 5A. DEDICATED PARKING FLOODLIGHT POLES (3D Asset: single_parking_lot_light.glb)
	# Minimal, clean lighting kept deep inside parking lots, well away from perimeter roads
	var parking_lights := [
		# South Main Parking Lot (illuminates central driving aisle, 50m from road)
		[Vector2(69.2, 2150.0), Vector2(75.0, 2150.0)],
		# North Executive Parking Lot (illuminates central aisle, 45m from road)
		[Vector2(140.0, 1995.0), Vector2(140.0, 1985.0)],
		# West Commercial Parking Lot (illuminates central aisle, 35m from road)
		[Vector2(40.0, 2120.0), Vector2(30.0, 2120.0)],
	]
	for pl in parking_lights:
		_add_parking_floodlight(w, body, pl[0], pl[1])

	# Palms around plaza perimeter, central promenade & Burj Khalifa Grand Plaza
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var palm_spots := [
		# Along Central Promenade
		Vector2(86.5, 2020.0), Vector2(99.5, 2020.0),
		Vector2(86.5, 2050.0), Vector2(99.5, 2050.0),
		Vector2(86.5, 2075.0), Vector2(99.5, 2075.0),
		Vector2(86.5, 2100.0), Vector2(99.5, 2100.0),
		# Around Central Parking Lot
		Vector2(65.5, 2135.0), Vector2(65.5, 2165.0),
		Vector2(116.5, 2135.0), Vector2(116.5, 2170.0),
		# Bank of China North Plaza
		Vector2(38.0, 1968.0), Vector2(62.0, 1968.0),
		# Burj Khalifa VIP Forecourt
		Vector2(129.0, 2182.0), Vector2(129.0, 2190.0),
		Vector2(161.0, 2182.0), Vector2(161.0, 2190.0),
		# Burj Khalifa Waterfront Promenade (East of Lake)
		Vector2(190.5, 2175.0),
		# Burj Khalifa North Garden Buffer
		Vector2(135.0, 2128.0), Vector2(155.0, 2128.0), Vector2(178.0, 2128.0),
	]
	for ps in palm_spots:
		_plant_palm(w, body, ps, rng)

	# Benches along promenade
	var bench_spots := [
		[Vector3(87.0, PY, 2040.0), PI * 0.5],
		[Vector3(99.0, PY, 2040.0), -PI * 0.5],
		[Vector3(87.0, PY, 2065.0), PI * 0.5],
		[Vector3(99.0, PY, 2065.0), -PI * 0.5],
	]
	for bs in bench_spots:
		Miami._put("bench", bs[0], bs[1], 1.5)

	# Wrought-iron fence round the whole plaza, with open gates where the paths and the forecourt come in
	_build_fence(body, mb, mb_pave, Vector2(bk_x0 + 0.6, bk_z0 + 0.6), Vector2(bk_x1 - 0.6, bk_z1 - 0.6),
		{"s": [Vector2(134.0, 156.0)], "n": [Vector2(143.0, 157.0)], "w": [Vector2(2148.0, 2162.0)], "e": [Vector2(2148.0, 2162.0)]}, bk_py)

	_build_projectors(w, body, mb, Vector3(145.0, PY, 2156.0), bk_py)

	# Commit base slabs
	var mi_pave := MeshInstance3D.new()
	mi_pave.mesh = Miami._finish(mb_pave)
	w.static_root.add_child(mi_pave)

	var mi_details := MeshInstance3D.new()
	mi_details.mesh = Miami._finish(mb)
	w.static_root.add_child(mi_details)

	# Flush all placed Miami props (palms, benches, flowerbeds, bushes)
	Miami._flush(w)

	# Register Map POI
	w.add_poi("city", "REDLINE SKYSCRAPER DISTRICT", Vector3(100.0, PY + 1.0, 2080.0))
	print("IslandSkyscrapers: finished building district successfully.")

static func _spawn_tower(w: World, body: StaticBody3D, mesh: Mesh, pos: Vector3, yaw: float, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	w.static_root.add_child(mi)
	_tower_collision(body, mesh, pos, yaw, size)

## Collision that follows the tower: it is cut into height bands and each band gets the convex hull of the model's vertices in it,
## so the setbacks, wings and the podium are as wide as the building really is (a single bounding box made invisible walls).
static func _tower_collision(body: StaticBody3D, mesh: Mesh, pos: Vector3, yaw: float, size: Vector3) -> void:
	var bas := Basis(Vector3.UP, yaw)
	var pts := PackedVector3Array()
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null: continue
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var stride := maxi(1, v.size() / 60000)
		var i := 0
		while i < v.size():
			pts.append(v[i])
			i += stride
	if pts.size() < 8:
		CoastProps._box(body, size, pos + Vector3(0.0, size.y * 0.5, 0.0), yaw)
		return
	var h := size.y
	var edges: Array = [0.0, 0.025, 0.05, 0.085, 0.125, 0.19, 0.29, 0.42, 0.58, 0.8, 1.0]
	for k in range(edges.size() - 1):
		var y0: float = edges[k] * h
		var y1: float = edges[k + 1] * h
		var pad := 3.0
		var seen := {}
		var hull := PackedVector3Array()
		for p in pts:
			if p.y < y0 - pad or p.y > y1 + pad: continue
			var key := Vector2i(int(roundf(p.x * 2.0)), int(roundf(p.z * 2.0)))
			if seen.has(key): continue
			seen[key] = true
			var q := bas * Vector3(p.x, 0.0, p.z)
			hull.append(Vector3(pos.x + q.x, pos.y + y0, pos.z + q.z))
			hull.append(Vector3(pos.x + q.x, pos.y + y1, pos.z + q.z))
		if hull.size() < 8: continue
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)

static func _spawn_prop(w: World, mesh: Mesh, pos: Vector3, yaw: float, scale_v := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = scale_v
	w.static_root.add_child(mi)
	return mi


static var _parking_light_scene: PackedScene = null

static func _add_parking_floodlight(w: World, body: StaticBody3D, at: Vector2, toward: Vector2) -> void:
	if _parking_light_scene == null:
		_parking_light_scene = load("res://assets/props/single_parking_lot_light.glb") as PackedScene
	if _parking_light_scene == null:
		return
	
	var pole_inst := _parking_light_scene.instantiate() as Node3D
	var light_scale := 0.75  # ~7.6m pole height, 1.7m arm reach
	pole_inst.scale = Vector3.ONE * light_scale
	
	var dir := (toward - at).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector2(1, 0)
	
	var yaw := atan2(-dir.y, dir.x)
	pole_inst.rotation.y = yaw
	pole_inst.position = Vector3(at.x, PY, at.y)
	w.static_root.add_child(pole_inst)
	
	# Collision for the pole base
	CoastProps._box(body, Vector3(0.5, 7.6, 0.5), Vector3(at.x, PY + 3.8, at.y))
	
	# Register emissive head with CityLights so it illuminates at dusk/night
	for c in pole_inst.find_children("*", "MeshInstance3D"):
		var mi := c as MeshInstance3D
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var m := mi.mesh.surface_get_material(s)
				if m and (m.resource_name == "material_15" or m.resource_name.contains("15")):
					var dup: StandardMaterial3D = m.duplicate()
					mi.set_surface_override_material(s, dup)
					CityLights.register_material(dup, Color(1.0, 0.95, 0.88), 4.5)
	
	var head_local := Vector3(2.24, 10.13, 0.0)
	var head_world: Vector3 = pole_inst.transform * head_local
	
	# Ambient omni fill under the fixture
	var flood := OmniLight3D.new()
	flood.position = head_world + Vector3(0, -0.2, 0)
	flood.omni_range = 28.0
	flood.omni_attenuation = 0.75
	flood.light_energy = 0.0
	flood.light_color = Color(1.0, 0.96, 0.88)
	flood.shadow_enabled = false
	CityLights.register_light(flood, 2.8)
	w.static_root.add_child(flood)
	
	# Downward angled beam illuminating the lot asphalt & bays
	var spot := SpotLight3D.new()
	spot.position = head_world
	spot.spot_range = 32.0
	spot.spot_angle = 62.0
	spot.spot_attenuation = 0.8
	spot.light_energy = 0.0
	spot.light_color = Color(1.0, 0.95, 0.85)
	spot.shadow_enabled = false
	var target_pos := Vector3(at.x + dir.x * 10.0, PY, at.y + dir.y * 10.0)
	spot.look_at_from_position(head_world, target_pos, Vector3.UP)
	CityLights.register_light(spot, 3.5)
	w.static_root.add_child(spot)

static func _plant_palm(w: World, body: StaticBody3D, p: Vector2, rng: RandomNumberGenerator) -> void:
	CoastProps._box(body, Vector3(0.8, 6.0, 0.8), Vector3(p.x, PY + 3.0, p.y))
	Miami._palm(body, p, rng, "t" if rng.randf() > 0.3 else "m")




## Black wrought-iron fence (bars with gold spear tips, granite pillars with gold caps) round the rectangle p0..p1.
## gaps: side letter (n s w e) -> list of Vector2(from, to) openings along that side (x for n/s, z for w/e).
static func _build_fence(body: StaticBody3D, mb: Dictionary, mb_stone: Dictionary, p0: Vector2, p1: Vector2, gaps: Dictionary, y0: float) -> void:
	var iron := _flat(Color(0.04, 0.04, 0.05), 0.4, 0.7)
	var gold := _flat(Color(0.86, 0.68, 0.28), 0.25, 0.9)
	var stone := _surface_mat("PavingStones130", 0.4, Color(0.75, 0.74, 0.72), 0.55)
	var sides := {
		"n": [Vector2(p0.x, p0.y), Vector2(p1.x, p0.y)], "s": [Vector2(p0.x, p1.y), Vector2(p1.x, p1.y)],
		"w": [Vector2(p0.x, p0.y), Vector2(p0.x, p1.y)], "e": [Vector2(p1.x, p0.y), Vector2(p1.x, p1.y)],
	}
	for k in sides:
		var a: Vector2 = sides[k][0]
		var b: Vector2 = sides[k][1]
		var along_x: bool = k == "n" or k == "s"
		var lo: float = a.x if along_x else a.y
		var hi: float = b.x if along_x else b.y
		var fixed: float = a.y if along_x else a.x
		# cut the side into runs between the gaps
		var cuts: Array = []
		var g: Array = (gaps.get(k, []) as Array).duplicate()
		g.sort_custom(func(u, v): return u.x < v.x)
		var cur := lo
		for gp in g:
			cuts.append(Vector2(cur, gp.x))
			cur = gp.y
		cuts.append(Vector2(cur, hi))
		for c in cuts:
			_fence_run(body, mb, mb_stone, along_x, fixed, c.x, c.y, y0, iron, gold, stone)

static func _fence_run(body: StaticBody3D, mb: Dictionary, mb_stone: Dictionary, along_x: bool, fixed: float, t0: float, t1: float, y0: float, iron: Material, gold: Material, stone: Material) -> void:
	var len := t1 - t0
	if len < 1.0: return
	var h := 1.8
	var n := maxi(1, int(ceil(len / 4.0)))
	var step := len / float(n)
	var pw := 0.28       # pillar half width
	for i in range(n + 1):
		var t := t0 + step * i
		_fbox(mb_stone, stone, along_x, fixed, t - pw, t + pw, y0, y0 + 2.0, pw)
		_fbox(mb, gold, along_x, fixed, t - pw - 0.07, t + pw + 0.07, y0 + 2.0, y0 + 2.12, pw + 0.07)
		_fbox(mb, gold, along_x, fixed, t - 0.11, t + 0.11, y0 + 2.12, y0 + 2.34, 0.11)
	var bar := 0.022
	for i in range(n):
		var a := t0 + step * i + pw
		var b := t0 + step * (i + 1) - pw
		_fbox(mb, iron, along_x, fixed, a, b, y0 + 0.12, y0 + 0.2, 0.035)
		_fbox(mb, iron, along_x, fixed, a, b, y0 + h - 0.22, y0 + h - 0.14, 0.035)
		_fbox(mb, iron, along_x, fixed, a, b, y0 + h, y0 + h + 0.06, 0.03)
		var cnt := int((b - a) / 0.17)
		for j in range(cnt + 1):
			var tt := a + (b - a) * (float(j) / float(maxi(cnt, 1)))
			_fbox(mb, iron, along_x, fixed, tt - bar, tt + bar, y0 + 0.1, y0 + h - 0.06, bar)
			_fbox(mb, gold, along_x, fixed, tt - bar * 0.8, tt + bar * 0.8, y0 + h - 0.06, y0 + h + 0.12, bar * 0.8)
	# solid: one slim wall for the whole run so nothing walks through the bars
	var c2 := Vector3((t0 + t1) * 0.5, y0 + h * 0.5, fixed) if along_x else Vector3(fixed, y0 + h * 0.5, (t0 + t1) * 0.5)
	CoastProps._box(body, Vector3(len, h, 0.3) if along_x else Vector3(0.3, h, len), c2)

static func _fbox(mb: Dictionary, mat: Material, along_x: bool, fixed: float, t0: float, t1: float, y0: float, y1: float, half: float) -> void:
	if along_x: Miami._box(mb, mat, Vector3(t0, y0, fixed - half), Vector3(t1, y1, fixed + half))
	else: Miami._box(mb, mat, Vector3(fixed - half, y0, t0), Vector3(fixed + half, y1, t1))

## Artemis fountain on a marble island in the lake, with ring of water jets (Kenney particle sprites).
static func _build_fountain(w: World, body: StaticBody3D, mb: Dictionary, c: Vector3, lx0: float, lx1: float, lz0: float, lz1: float) -> Array:
	var marble := _surface_mat("PavingStones130", 0.4, Color(1.2, 1.18, 1.15), 0.5)
	var plinth_top := c.y + 0.34
	var fb: Dictionary = Miami._bake(T + "artemis_fountain.glb", "", 0.0, 0.5)
	var sz := Vector3(9.0, 0.0, 5.0)
	if not fb.is_empty():
		sz = fb.size
	# marble island: long side along z (the model is long in x, so it is turned a quarter turn)
	var ix := sz.z + 2.4
	var iz := sz.x + 2.4
	Miami._box(mb, marble, Vector3(c.x - ix * 0.5, c.y, c.z - iz * 0.5), Vector3(c.x + ix * 0.5, plinth_top, c.z + iz * 0.5))
	CoastProps._box(body, Vector3(ix, plinth_top - c.y, iz), Vector3(c.x, (c.y + plinth_top) * 0.5, c.z))
	if not fb.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = fb.mesh
		mi.position = Vector3(c.x, plinth_top, c.z)
		mi.rotation.y = PI * 0.5
		w.static_root.add_child(mi)
		CoastProps._box(body, Vector3(sz.z * 0.9, sz.y, sz.x * 0.9), Vector3(c.x, plinth_top + sz.y * 0.5, c.z))
	# jets along both long sides of the lake (and beyond the island at the two ends)
	var tex := load("res://assets/vfx/circle_05.png") as Texture2D
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.vertex_color_use_as_albedo = true
	pm.albedo_texture = tex
	pm.albedo_color = Color(0.92, 0.98, 1.0, 0.6)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	quad.material = pm
	var spots: Array = []
	for zz in [lz0 + 5.0, lz0 + 11.0, lz1 - 11.0, lz1 - 5.0]:
		spots.append(Vector3(lx0 + 2.5, c.y + 0.2, zz))
		spots.append(Vector3(lx1 - 2.5, c.y + 0.2, zz))
	spots.append(Vector3(c.x, c.y + 0.2, lz0 + 2.5))
	spots.append(Vector3(c.x, c.y + 0.2, lz1 - 2.5))
	for sp in spots:
		var pr := ParticleProcessMaterial.new()
		pr.direction = Vector3(0.0, 1.0, 0.0)
		pr.spread = 7.0
		pr.initial_velocity_min = 9.0
		pr.initial_velocity_max = 11.5
		pr.gravity = Vector3(0.0, -9.8, 0.0)
		pr.scale_min = 0.7
		pr.scale_max = 1.3
		var pt := GPUParticles3D.new()
		pt.process_material = pr
		pt.draw_pass_1 = quad
		pt.amount = 300
		pt.lifetime = 2.3
		pt.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 20, 12))
		pt.position = sp
		w.static_root.add_child(pt)
	return spots


## A night projector aimed at the Burj: a Decal (a box that paints a picture onto the surfaces inside it) lit with the Indian flag,
## rippling like cloth. It is switched on by the night clock (FlagProjector). The casing boxes in the forecourt are the "projectors".
static func _build_projectors(w: World, body: StaticBody3D, mb: Dictionary, tower: Vector3, y0: float) -> void:
	var fp := FlagProjector.new()
	var housing_mat := _flat(Color(0.10, 0.11, 0.13), 0.35, 0.75)
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.9, 0.95, 1.0)
	CityLights.register_material(lens_mat, Color(1.0, 0.95, 0.85), 3.0)
	var beam_mat_shader := load("res://shaders/projector_beam.gdshader") as Shader
	# four projectors, one per side of the tower: [ground position, direction from the tower out to the projector, half depth of the tower there]
	var units: Array = [
		[Vector3(129.0, y0, 2189.5), Vector3(0, 0, 1), 14.0],
		[Vector3(134.0, y0, 2130.5), Vector3(0, 0, -1), 14.0],
		[Vector3(122.6, y0, 2166.0), Vector3(-1, 0, 0), 13.0],
		[Vector3(167.8, y0, 2155.0), Vector3(1, 0, 0), 13.0],
	]
	for u in units:
		var pos: Vector3 = u[0]
		var out: Vector3 = u[1]
		# aim at the real wall: its outermost point on this side at the flag height, then a metre into the tower so the beam stops on the surface
		var wall := _wall_point(tower, out, FLAG_Y, float(u[2]))
		var target := wall - out * 7.0   # ends deep inside the tower: the wall hides the end, so the light simply touches the wall
		# pedestal and head, solid
		var unit := Node3D.new()
		unit.position = pos
		w.static_root.add_child(unit)
		var ped := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.45, MAST_H, 0.45)
		pm.material = housing_mat
		ped.mesh = pm
		ped.position = Vector3(0.0, MAST_H * 0.5, 0.0)
		unit.add_child(ped)
		var head := Node3D.new()
		head.position = Vector3(0.0, MAST_H + 0.45, 0.0)
		unit.add_child(head)
		var hm := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.8, 0.7, 1.4)
		hb.material = housing_mat
		hm.mesh = hb
		head.add_child(hm)
		var lens := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.3
		lc.bottom_radius = 0.3
		lc.height = 0.12
		lc.material = lens_mat
		lens.mesh = lc
		lens.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		lens.position = Vector3(0.0, 0.0, -0.74)
		head.add_child(lens)
		head.look_at_from_position(pos + Vector3(0.0, MAST_H + 0.45, 0.0), target, Vector3.UP)
		CoastProps._box(body, Vector3(0.9, MAST_H, 0.9), pos + Vector3(0.0, MAST_H * 0.5, 0.0))
		# the visible beam: a cone from the lens to the tower face
		var lens_w: Vector3 = (head.global_transform * Vector3(0.0, 0.0, -0.8))
		var dist := lens_w.distance_to(target)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.25
		cone.bottom_radius = 3.2
		cone.height = dist
		cone.radial_segments = 28
		cone.rings = 1
		cone.cap_top = false
		cone.cap_bottom = false
		var bm := ShaderMaterial.new()
		bm.shader = beam_mat_shader
		bm.set_shader_parameter("length_m", dist)
		CityLights.register(bm)
		cone.material = bm
		var beam := MeshInstance3D.new()
		beam.mesh = cone
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var yv := (lens_w - target).normalized()
		var xv := yv.cross(Vector3.UP).normalized()
		var zv := xv.cross(yv)
		beam.transform = Transform3D(Basis(xv, yv, zv), (lens_w + target) * 0.5)
		w.static_root.add_child(beam)
	# the picture on the tower, one patch per side, switched on by the night clock
	for b in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var d := Decal.new()
		d.size = Vector3(60.0, 56.0, 60.0)    # x: width, y: depth along the beam, z: height of the picture
		var yv2: Vector3 = -b
		var zv2 := Vector3(0, -1, 0)
		d.basis = Basis(yv2.cross(zv2), yv2, zv2)
		d.position = Vector3(tower.x, FLAG_Y, tower.z) - b * 6.0
		d.emission_energy = 0.0
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		d.normal_fade = 0.5
		d.visible = false
		w.static_root.add_child(d)
		fp.decals.append(d)
	w.static_root.add_child(fp)


## The outermost point of the Burj's wall on one side at height y (world), found from the model's vertices near that height and
## near the middle of that side. `out` points from the tower to that side. Falls back to `fallback` metres from the centre.
static func _wall_point(tower: Vector3, out: Vector3, y: float, fallback: float) -> Vector3:
	var best := -INF
	var side := Vector3(-out.z, 0.0, out.x)
	if _burj_mesh != null:
		for si in range(_burj_mesh.get_surface_count()):
			var arr := _burj_mesh.surface_get_arrays(si)
			if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null: continue
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var stride := maxi(1, v.size() / 150000)
			var i := 0
			while i < v.size():
				var p := v[i]
				if absf(p.y + tower.y - y) < 4.0 and absf(p.dot(side)) < 6.0:
					var d := p.dot(out)
					if d > best: best = d
				i += stride
	if best == -INF: best = fallback
	return Vector3(tower.x, y, tower.z) + out * best
