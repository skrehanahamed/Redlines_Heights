class_name Coast
extends RefCounted
## The world's ground: a big mainland and a second island, both ringed by beach and surrounded by sea.
## Everything is derived from one function, inland(x, z) = signed distance to the shore (positive on land), so the
## terrain mesh, collision, swimming, the sea and the props on the sand all agree.

const SEA_Y := -0.55            # sea level (matches the player's swim height)
const MAIN_C := Vector2(500.0, -450.0)
const MAIN_H := Vector2(1450.0, 1350.0)      # half-size of the mainland
const MAIN_R := 420.0                         # rounded corners
const HILL_C := Vector2(850.0, -1960.0)       # land added in the north for Renowood
const HILL_R := Vector2(900.0, 640.0)
const ISL_C := Vector2(200.0, 2200.0)
const ISL_R := Vector2(800.0, 480.0)
const BEACH_W := 90.0           # width of the sand band measured inland from the waterline
const SEABED := -6.7            # the seabed in the corridor of the metro tunnel and the bridge (the tunnel runs under it)
const SEABED_FAR := -22.0       # the open sea floor: the sea gets steadily deeper away from the land
const TILE := 200.0
const CELL := 5.0

static var _n1: FastNoiseLite
static var _n2: FastNoiseLite
static var _n3: FastNoiseLite
static var sea_mat: ShaderMaterial
static var extra_water_mats: Array = []      # the lagoon / canal materials (they share the rain and night updates)
static var shore_tex: ImageTexture
static var shore_rect := Rect2(-1100.0, 1400.0, 2600.0, 1600.0)
static var _bridge_range := Vector2.ZERO

## Where the road to the island is carried by the bridge along x = 0: it starts BRIDGE_APPROACH metres before the
## mainland shore (on the grass) and ends 130 m inland of the island's shore. Returns (z_start, z_end).
const BRIDGE_APPROACH := 420.0
static func bridge_range() -> Vector2:
	if _bridge_range != Vector2.ZERO: return _bridge_range
	var z := 300.0
	var z_in := -1.0
	var z_wet := -1.0
	var z_out := -1.0
	while z < 1990.0:
		var d := inland(0.0, z)
		if z_in < 0.0 and d < BRIDGE_APPROACH: z_in = z
		elif z_in >= 0.0 and z_wet < 0.0 and d < 0.0: z_wet = z
		elif z_wet >= 0.0 and d > 130.0:
			z_out = z
			break
		z += 4.0
	if z_out < 0.0: z_out = 1900.0
	# the bridge never starts on top of a railway crossing: it begins just past the crossing slab
	for cp in Rail.crossing_points():
		var c: Vector2 = cp
		if absf(c.x) < 3.0 and c.y > z_in - 40.0 and c.y < z_in + 40.0:
			z_in = c.y + Rail.GAP * 0.5 + 45.0       # a stretch of ordinary road between the crossing and the bridge
	_bridge_range = Vector2(z_in, z_out)
	return _bridge_range
static var ready_noise := false

static func _ensure() -> void:
	if ready_noise: return
	ready_noise = true
	_n1 = FastNoiseLite.new(); _n1.seed = 11; _n1.frequency = 0.0014; _n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n2 = FastNoiseLite.new(); _n2.seed = 23; _n2.frequency = 0.008; _n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n3 = FastNoiseLite.new(); _n3.seed = 5; _n3.frequency = 0.022; _n3.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

## Signed distance to the shoreline in metres: positive on land, negative at sea.
static func inland(x: float, z: float) -> float:
	_ensure()
	var p := Vector2(x, z) - MAIN_C
	var q := p.abs() - (MAIN_H - Vector2(MAIN_R, MAIN_R))
	var dm := MAIN_R - (Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0))
	var e := Vector2((x - ISL_C.x) / ISL_R.x, (z - ISL_C.y) / ISL_R.y)
	var di := (1.0 - e.length()) * minf(ISL_R.x, ISL_R.y)
	# Redline Island's two beach boulevards (west and east): the coast there is pushed out to sea so the beachfront stays on dry sand
	if z > 1700.0 and z < 2750.0:
		di += 15.0 * _isl_side(x, z)
	var eh := Vector2((x - HILL_C.x) / HILL_R.x, (z - HILL_C.y) / HILL_R.y)
	var dh := (1.0 - eh.length()) * minf(HILL_R.x, HILL_R.y)
	# the mainland and Renowood's land are joined with a smooth union, so no sandy bay is left in the notch between them
	var dmh := _smax(dm, dh, 260.0)
	var d := maxf(dmh, di)
	if d > 400.0 or d < -450.0: return d
	# the wobble only shapes the coast itself: it fades out inland, so no pocket of sand can appear away from the water
	var amp := 1.0 - smoothstep(15.0, 95.0, absf(d))
	if z > 1700.0 and z < 2750.0: amp *= 1.0 - 0.7 * _isl_side(x, z)        # a calmer coast on the island's two beach boulevards
	return d + (_n1.get_noise_2d(x, z) * 85.0 + _n2.get_noise_2d(x, z) * 14.0) * amp

## 1 on the island's west and east beach sides (where the boulevards run), fading to 0 towards the middle and the ends.
static func _isl_side(x: float, z: float) -> float:
	return smoothstep(420.0, 620.0, absf(x - ISL_C.x)) * smoothstep(1700.0, 1850.0, z) * (1.0 - smoothstep(2600.0, 2750.0, z))

static func _smax(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
	return lerpf(b, a, h) + k * h * (1.0 - h) * 0.5

static func is_water(x: float, z: float) -> bool:
	return inland(x, z) < 0.0 or in_pool(x, z)

## Ponds, lagoons and canals carved into the island (Miami parks): [kind (0 ellipse, 1 rectangle), cx, cz, a, b] with a, b the half sizes.
static var water_shapes: Array = []
const POOL_DEPTH := -2.4

## True when (x, z) is in a pond / canal / channel or within `m` metres of one.
static func near_pool(x: float, z: float, m: float) -> bool:
	for sh in water_shapes:
		if absf(x - float(sh[1])) < float(sh[3]) + m and absf(z - float(sh[2])) < float(sh[4]) + m: return true
	return false

static func in_pool(x: float, z: float) -> bool:
	for sh in water_shapes:
		var dx: float = x - float(sh[1])
		var dz: float = z - float(sh[2])
		if int(sh[0]) == 0:
			if absf(dx) < float(sh[3]) and absf(dz) < float(sh[4]) and (dx * dx) / (float(sh[3]) * float(sh[3])) + (dz * dz) / (float(sh[4]) * float(sh[4])) < 1.0: return true
		elif absf(dx) < float(sh[3]) and absf(dz) < float(sh[4]):
			return true
	return false

static func _dune(x: float, z: float, d: float) -> float:
	var k := smoothstep(22.0, 52.0, d) * (1.0 - smoothstep(58.0, BEACH_W, d))
	if k <= 0.0: return 0.0
	for fr in flat_rects:
		if (fr as Rect2).has_point(Vector2(x, z)): return 0.0
	# keep the strip where the bridge meets the shore flat so the road sits cleanly
	if z > 700.0: k *= smoothstep(25.0, 70.0, absf(x))
	return (_n3.get_noise_2d(x, z) * 0.5 + 0.5) * 1.1 * k

static func profile(d: float, x: float, z: float) -> float:
	if d >= BEACH_W: return Renowood.height(x, z)
	if d >= 0.0:
		return lerpf(SEA_Y, 0.0, smoothstep(0.0, 60.0, d)) + _dune(x, z, d) + Renowood.height(x, z) * smoothstep(50.0, BEACH_W, d)
	var t := clampf(-d / 70.0, 0.0, 1.0)
	var h := lerpf(SEA_Y, -3.2, smoothstep(0.0, 1.0, t))
	var f := clampf((-d - 70.0) / 300.0, 0.0, 1.0)
	var shelf := h + f * (SEABED + 3.2)                                  # the old gentle slope: kept along the metro / bridge corridor
	var deep := h + pow(f, 0.85) * (SEABED_FAR + 3.2)                    # the open sea: steadily deeper, reaching SEABED_FAR 370 m out
	return lerpf(deep, shelf, in_corridor(x, z))

## 1 inside the strip where the metro tunnel and the bridge cross the sea (x -75 / 0, between the two islands), fading to 0 beside it.
static func in_corridor(x: float, z: float) -> float:
	return (1.0 - smoothstep(70.0, 190.0, absf(x + 38.0))) * smoothstep(200.0, 320.0, z) * (1.0 - smoothstep(2040.0, 2160.0, z))

static func height_at(x: float, z: float) -> float:
	if not water_shapes.is_empty() and in_pool(x, z): return POOL_DEPTH
	return profile(inland(x, z), x, z)

# ------------------------------------------------------------------ terrain

static func _vcol(d: float, hm := 0.0) -> Color:
	var sand := 1.0 - smoothstep(62.0, BEACH_W, d)
	if d < 0.0: sand = 1.0
	var wet := smoothstep(16.0, 0.0, d) if d > 0.0 else 1.0
	var under := smoothstep(0.0, 45.0, -d)
	return Color(sand, under, wet * 0.9, hm)

## Openings cut through the ground (visual and collision): Rect2s in world x, z. Whole grid cells that touch one are removed.
static var flat_rects: Array = []     # Rect2s where the sand dunes are levelled (the beach fair)
static var holes: Array = []
static var shafts: Array = []         # corridors going down through the seabed collision (same x range, listed by z): Rect2s

static func _tile(w: World, mat: Material, x0: float, z0: float, body: StaticBody3D, cell: float) -> void:
	var n := int(TILE / cell)
	var m := n + 3
	var hs := PackedFloat32Array()
	var ds := PackedFloat32Array()
	hs.resize(m * m)
	ds.resize(m * m)
	for j in range(m):
		for i in range(m):
			var x := x0 + (i - 1) * cell
			var z := z0 + (j - 1) * cell
			var d := inland(x, z)
			ds[j * m + i] = d
			hs[j * m + i] = profile(d, x, z)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize((n + 1) * (n + 1))
	norms.resize(verts.size())
	cols.resize(verts.size())
	for j in range(n + 1):
		for i in range(n + 1):
			var gi := i + 1
			var gj := j + 1
			var k := j * (n + 1) + i
			verts[k] = Vector3(x0 + i * cell, hs[gj * m + gi], z0 + j * cell)
			var dx := hs[gj * m + gi + 1] - hs[gj * m + gi - 1]
			var dz := hs[(gj + 1) * m + gi] - hs[(gj - 1) * m + gi]
			norms[k] = Vector3(-dx, 2.0 * cell, -dz).normalized()
			cols[k] = _vcol(ds[gj * m + gi], Renowood.mask(x0 + i * cell, z0 + j * cell))
	var idx := PackedInt32Array()
	idx.resize(n * n * 6)
	var q := 0
	for j in range(n):
		for i in range(n):
			if not holes.is_empty():
				var cr := Rect2(x0 + i * cell, z0 + j * cell, cell, cell)
				var cut := false
				for hh in holes:
					if cr.intersects(hh): cut = true
				if cut: continue
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + (n + 1)
			var dd := c + 1
			idx[q] = a; idx[q + 1] = b; idx[q + 2] = c
			idx[q + 3] = b; idx[q + 4] = dd; idx[q + 5] = c
			q += 6
	idx.resize(q)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)

static func _flat_quads(rects: Array, y: float, color: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for r in rects:
		var rr: Rect2 = r
		var b := verts.size()
		for c in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			verts.append(Vector3(rr.position.x + c.x * rr.size.x, y, rr.position.y + c.y * rr.size.y))
			norms.append(Vector3.UP)
			cols.append(color)
		idx.append_array(PackedInt32Array([b, b + 1, b + 3, b + 1, b + 2, b + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

static func build(w: World) -> void:
	_ensure()
	var half := CityData.half
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader") as Shader
	mat.set_shader_parameter("grass_tex", load("res://assets/textures/ground/Grass005_Color.jpg"))
	mat.set_shader_parameter("grass2_tex", load("res://assets/textures/ground/Grass004_Color.jpg"))
	mat.set_shader_parameter("dirt_tex", load("res://assets/textures/ground/Ground037_Color.jpg"))
	mat.set_shader_parameter("sand_tex", load("res://assets/coast/sand_tile.jpg"))
	mat.set_shader_parameter("pave_tex", load("res://assets/roads/pavement.png"))
	mat.set_shader_parameter("conc_tex", load("res://assets/airport/tex/Concrete034.jpg"))
	Renowood.height(850.0, -1500.0)
	mat.set_shader_parameter("pave_pads", Renowood.pave_data())
	var n_pave := 0
	for pd in Renowood.pads:
		if int(pd.which) == 0: n_pave += 1
	mat.set_shader_parameter("pave_n", mini(n_pave, 16))
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	w.static_root.add_child(body)
	var nt := int(half * 2.0 / TILE)
	var grass_rects: Array = []
	var diag := TILE * 0.7071 * 1.3
	var coast_tiles := 0
	for tj in range(nt):
		for ti in range(nt):
			var x0 := -half + ti * TILE
			var z0 := -half + tj * TILE
			var d := inland(x0 + TILE * 0.5, z0 + TILE * 0.5)
			var hill_tile := Renowood.in_bbox(Rect2(x0, z0, TILE, TILE))
			var has_hole := false
			for hh2 in holes:
				if Rect2(x0, z0, TILE, TILE).intersects(hh2): has_hole = true
			if has_hole:
				_tile(w, mat, x0, z0, body, CELL)       # a tile with an opening in it is built from cells, so the cells can be left out
				coast_tiles += 1
			elif d > BEACH_W + diag and not hill_tile:
				grass_rects.append(Rect2(x0, z0, TILE, TILE))
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(TILE, 2.0, TILE)
				cs.shape = bs
				cs.position = Vector3(x0 + TILE * 0.5, -1.0, z0 + TILE * 0.5)
				body.add_child(cs)
			elif d < -370.0 - diag and in_corridor(x0 + TILE * 0.5, z0 + TILE * 0.5) < 0.02 and in_corridor(x0, z0) < 0.02 and in_corridor(x0 + TILE, z0 + TILE) < 0.02:
				pass            # open sea: the big seabed plane covers it
			else:
				_tile(w, mat, x0, z0, body, 2.5 if hill_tile else (CELL if d > -140.0 else 20.0))
				coast_tiles += 1
	var gm := MeshInstance3D.new()
	gm.mesh = _flat_quads(grass_rects, 0.0, Color(0, 0, 0, 0))
	gm.material_override = mat
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(gm)
	# the seabed and the sea surface exist only where there is water: tiles lying well inland are left out, so nothing
	# of them is under the city (a free camera below the ground no longer sees sea or sand there)
	var ext := half + 1500.0
	var wt := 250.0
	var nw := int(ext * 2.0 / wt)
	var wdiag := wt * 0.7071 * 1.3
	var water_rects: Array = []
	for tj in range(nw):
		for ti in range(nw):
			var wx := -ext + ti * wt
			var wz := -ext + tj * wt
			if inland(wx + wt * 0.5, wz + wt * 0.5) > 60.0 + wdiag: continue
			# a water tile lying wholly under dry land where a stair corridor goes down is left out: it would show through the opening
			var trect := Rect2(wx, wz, wt, wt)
			var over_shaft := false
			for sh2 in shafts:
				if trect.intersects((sh2 as Rect2).grow(3.0)): over_shaft = true
			if over_shaft:
				var dry := true
				for cx in [wx, wx + wt]:
					for cz in [wz, wz + wt]:
						if inland(cx, cz) < 20.0: dry = false
				if dry: continue
			water_rects.append(trect)
	var sb := MeshInstance3D.new()
	sb.mesh = _flat_quads(water_rects, SEABED_FAR, Color(1, 1, 0, 0))
	sb.material_override = mat
	sb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(sb)
	var full := (half + 1500.0) * 2.0
	if shafts.is_empty():
		var sbc := CollisionShape3D.new()
		var sbs := BoxShape3D.new()
		sbs.size = Vector3(full, 2.0, full)
		sbc.shape = sbs
		sbc.position = Vector3(0, SEABED_FAR - 1.0, 0)
		body.add_child(sbc)
	else:
		# the seabed floor with the stair corridors left open: two big side pieces and the column between cut into runs
		var sx0: float = (shafts[0] as Rect2).position.x
		var sx1: float = (shafts[0] as Rect2).end.x
		var pieces: Array = [Rect2(-full * 0.5, -full * 0.5, full * 0.5 + sx0, full), Rect2(sx1, -full * 0.5, full * 0.5 - sx1, full)]
		var zs: Array = []
		for sh in shafts: zs.append([(sh as Rect2).position.y, (sh as Rect2).end.y])
		zs.sort_custom(func(a, b): return a[0] < b[0])
		var zcur := -full * 0.5
		for zr in zs:
			if zr[0] > zcur: pieces.append(Rect2(sx0, zcur, sx1 - sx0, zr[0] - zcur))
			zcur = zr[1]
		pieces.append(Rect2(sx0, zcur, sx1 - sx0, full * 0.5 - zcur))
		for pr in pieces:
			var r2: Rect2 = pr
			var pc := CollisionShape3D.new()
			var pb := BoxShape3D.new()
			pb.size = Vector3(r2.size.x, 2.0, r2.size.y)
			pc.shape = pb
			pc.position = Vector3(r2.position.x + r2.size.x * 0.5, SEABED_FAR - 1.0, r2.position.y + r2.size.y * 0.5)
			body.add_child(pc)
	# ---- sea surface (a subdivided grid per water tile, so the waves still move)
	var sea := MeshInstance3D.new()
	var sv := PackedVector3Array()
	var sn := PackedVector3Array()
	var si := PackedInt32Array()
	for r in water_rects:
		var rr: Rect2 = r
		var sub := 40 if inland(rr.position.x + rr.size.x * 0.5, rr.position.y + rr.size.y * 0.5) > -320.0 else 8       # a fine mesh near the coast, so waves can roll
		var b0 := sv.size()
		for j in range(sub + 1):
			for i in range(sub + 1):
				sv.append(Vector3(rr.position.x + rr.size.x * i / sub, 0.0, rr.position.y + rr.size.y * j / sub))
				sn.append(Vector3.UP)
		for j in range(sub):
			for i in range(sub):
				var a0 := b0 + j * (sub + 1) + i
				si.append_array(PackedInt32Array([a0, a0 + 1, a0 + sub + 1, a0 + 1, a0 + sub + 2, a0 + sub + 1]))
	var sarr := []
	sarr.resize(Mesh.ARRAY_MAX)
	sarr[Mesh.ARRAY_VERTEX] = sv
	sarr[Mesh.ARRAY_NORMAL] = sn
	sarr[Mesh.ARRAY_INDEX] = si
	var smesh := ArrayMesh.new()
	smesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sarr)
	sea.mesh = smesh
	sea.position = Vector3(0, SEA_Y, 0)
	sea.custom_aabb = AABB(Vector3(-ext, -5, -ext), Vector3(ext * 2.0, 10, ext * 2.0))
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = load("res://shaders/sea.gdshader") as Shader
	sea_mat.set_shader_parameter("normal_tex", load("res://assets/coast/ocean_tile_normal.png"))
	sea_mat.set_shader_parameter("albedo_tex", load("res://assets/coast/ocean_tile_albedo.png"))
	sea_mat.set_shader_parameter("shore_tex", build_shore_texture())
	sea_mat.set_shader_parameter("shore_rect", Vector4(shore_rect.position.x, shore_rect.position.y, shore_rect.size.x, shore_rect.size.y))
	sea.material_override = sea_mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.static_root.add_child(sea)
	print("coast: ", coast_tiles, " shore tiles, ", grass_rects.size(), " grass tiles")


## Distance from every point of the island's surroundings to the nearest land (in water; 0 on land), 0 .. 64 m in 0.25 m steps, for the
## sea shader's waves.
static func build_shore_texture() -> ImageTexture:
	if shore_tex != null: return shore_tex
	_ensure()
	var nx := 520
	var nz := 320
	var d := PackedFloat32Array()
	d.resize(nx * nz)
	for j in range(nz):
		for i in range(nx):
			var x := shore_rect.position.x + (float(i) + 0.5) * shore_rect.size.x / nx
			var z := shore_rect.position.y + (float(j) + 0.5) * shore_rect.size.y / nz
			d[j * nx + i] = clampf(-inland(x, z), 0.0, 64.0)
	var bytes := PackedByteArray()
	bytes.resize(nx * nz)
	for k in range(nx * nz): bytes[k] = int(d[k] / 64.0 * 255.0)
	shore_tex = ImageTexture.create_from_image(Image.create_from_data(nx, nz, false, Image.FORMAT_R8, bytes))
	return shore_tex
