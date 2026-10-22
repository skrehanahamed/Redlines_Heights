class_name CityBuild
extends RefCounted
## Builds the town on its 4 x 4 grid of blocks. Every block is a paved lot with proper pavements. Ordinary blocks are cut
## into four quarters by narrow lanes (own pavements, centre dashes and lamps) and filled with two rows of buildings back
## to back, so every building and shop opens onto a street or a lane. Landmark blocks hold the tower cluster round the
## middle junction, the old-town row, the fountain plaza, and the fire station, police station and hospital with their own
## parking bays. Traffic lights, phone boxes and food carts stand on the pavements. All building materials with windows are
## registered with CityLights, so they glow at night.

const BX := [-286.5, -95.5, 95.5, 286.5]             # block centres (x and z)
const EDGE := 89.6                                   # block centre to the road's edge
const PAVE := 4.2                                    # pavement width along the main streets
const LANE_HALF := 4.0                               # half width of a lane
const LANE_PAVE := 3.0
const BASE_H := 0.30                                 # lot / pavement height
const BAND_H := 0.34
const OUTER_LINE := EDGE - PAVE - 1.0                # building front line, from the block centre, on the main streets
const LANE_LINE := LANE_HALF + LANE_PAVE + 0.8       # building front line on a lane
const MAX_DEPTH := 36.0
const LOT_TOP := 0.322
const OFFICES := false                                # the small offices in the tower blocks and the H block are off for now
const PARKED_CARS := false                            # parked cars in the lots are off for now

const T := "res://assets/town/"
const RES := "res://assets/city/low_poly_residential_buildings.glb"
const ATL := "res://assets/city/free__atlanta_corperate_office_building.glb"

## roles by [row][column]: rows run north to south (z), columns west to east (x)
const ROLES := [
	["res", "res", "res", "res"],
	["res", "tower_a", "tower_b", "services"],
	["plaza", "tower_c", "h", "res"],
	["res", "hospital", "res", "res"],
]

static var specs := {}
static var layout := {"buildings": [], "blocks": [], "lots": [], "courts": [], "plaza": []}      # recorded for drawing the maps

static func _spec(key: String, path: String, scale: float, only := "", yaw0 := 0.0) -> void:
	var b := Renowood._baked(path, 1.0, ["Object_2"] if key == "helipad" else [], true, only, scale)
	var sz: Vector3 = b.size
	var swap := absf(sin(yaw0)) > 0.5
	specs[key] = {"mesh": b.mesh, "size": sz, "yaw0": yaw0, "w": sz.z if swap else sz.x, "d": sz.x if swap else sz.z}

static func _specs() -> void:
	_spec("r1", RES, 17.0, "buillding1")
	_spec("r2a", RES, 17.0, "buillding2-1")
	_spec("r2b", RES, 17.0, "buillding2-2")
	_spec("r2c", RES, 17.0, "buillding2-3")
	_spec("soviet", T + "low_poly_-_soviet__apartment_building_8k.glb", 27.0, "", PI * 0.5)
	_spec("york", T + "york_corner_shop_1.glb", 1.25)
	_spec("bordeaux", T + "bordeaux_flat_2_corner_france.glb", 1.0)
	_spec("asian", T + "asian_shop_1.glb", 3.3)
	_spec("ait", T + "ait01/AIT01W2W2.FBX", 0.8)
	_spec("hirise", T + "hirise2/hirise2.FBX", 0.75)
	_spec("wtc", T + "3_world_trade_center.glb", 1.0)
	_spec("wtc_s", T + "3_world_trade_center.glb", 0.78)
	_spec("boc", T + "bank_of_china_tower.glb", 0.45)
	_spec("atl", ATL, 0.55)
	_spec("atl_l", ATL, 0.72)
	_spec("fire", T + "fire_department_building.glb", 0.028)
	_spec("police", T + "valleywind_police_station.glb", 1.3, "", -PI * 0.5)
	_spec("hospital", T + "jejungwon_hospital.glb", 2.0)
	_spec("helipad", T + "heliport_helipad_air_base_helicopter.glb", 0.0115, "", 0.0)
	_spec("ambulance", T + "shvan_92_ambulance_-_low_poly_model.glb", 1.0, "", PI * 0.5)
	_spec("fountain", T + "artemis_fountain.glb", 0.35)
	_spec("phone", T + "phone_booth.glb", 0.28)
	_spec("cart", T + "avika_street_food_cart.glb", 1.0)
	for pk in [["tuft", "Grass main fresh", 0.55], ["tallg", "Grass tall high", 1.05], ["fern", "SM_Fern_01", 0.8], ["flower", "Dandelion", 0.32]]:
		var src := "res://assets/plants/grass_pack_lowpoly_game-ready.glb"
		if pk[0] == "fern": src = "res://assets/plants/some_foliage.glb"
		elif pk[0] == "flower": src = "res://assets/plants/undergrowth_pack_lowpoly_game-ready.glb"
		var pb := Renowood._baked(src, float(pk[2]), [], false, String(pk[1]))
		specs[pk[0]] = {"mesh": pb.mesh, "size": pb.size, "yaw0": 0.0, "w": 1.0, "d": 1.0}
	var oak := Renowood._baked("res://assets/trees/oak_tree.glb", 12.0)
	specs["oak"] = {"mesh": oak.mesh, "size": oak.size, "yaw0": 0.0, "w": 1.0, "d": 1.0}
	# night lighting, from inside: windows glow, walls do not. Models whose materials are named for their windows use those;
	# the others get the window shader (windows from the texture, an emission map, or a grid laid by world position)
	for k in ["r1", "r2a", "r2b", "r2c", "fire", "police", "ambulance", "phone", "cart"]:
		CityLights.apply(specs[k].mesh, "names", 1.0)
	CityLights.apply_shader(specs.ait.mesh, {"mode": 3, "emit": T + "ait01/AIT01W2W2_win.png", "lit_frac": 0.5, "gain": 1.1})
	CityLights.apply_shader(specs.hirise.mesh, {"mode": 3, "emit": T + "hirise2/hirise2_win.png", "lit_frac": 0.5, "gain": 1.1})
	CityLights.apply(specs.asian.mesh, "windows_named", 1.0)         # only its real shop-window material
	# the Atlanta office: only its 'Windows' material glows at night; its other glow maps stay off
	for k in ["atl", "atl_l"]:
		CityLights.apply(specs[k].mesh, "only_windows", 1.0)
	# soviet, york, hospital and Bank of China: no real window layer found yet, so no night glow (the old grid was fake)
	CityLights.apply_shader(specs.bordeaux.mesh, {"mode": 2, "emit": T + "bordeaux_flat_2_corner_france_1.png", "lit_frac": 0.6, "gain": 1.0})
	# the World Trade Center's curtain-wall glass is separate geometry: those panes (and only those) glow, one pane at a time
	for k in ["wtc", "wtc_s"]:
		CityLights.paint_panes(specs[k].mesh, func(m: BaseMaterial3D) -> bool:
			var h := m.albedo_color.to_html(false)
			return h == "6d8997" or h == "307da6", 0.38, 0.55)


# ------------------------------------------------------------------ building blocks

## Openings cut through every slab (the metro stairwells): Rect2s in world x, z.
static var holes: Array = []
static var reserved: Array = []        # Rect2 in world x, z where the rows of buildings leave a gap (the gun shop)

static func _slab(c: Dictionary, x0: float, z0: float, x1: float, z1: float, top: float, mat: Material, collide: bool, bottom := 0.0) -> void:
	if x1 - x0 < 0.02 or z1 - z0 < 0.02: return
	for h in holes:
		var hr: Rect2 = h
		if x0 < hr.end.x and x1 > hr.position.x and z0 < hr.end.y and z1 > hr.position.y:
			# split into the pieces round the opening
			_slab(c, x0, z0, hr.position.x, z1, top, mat, collide, bottom)
			_slab(c, hr.end.x, z0, x1, z1, top, mat, collide, bottom)
			_slab(c, maxf(x0, hr.position.x), z0, minf(x1, hr.end.x), hr.position.y, top, mat, collide, bottom)
			_slab(c, maxf(x0, hr.position.x), hr.end.y, minf(x1, hr.end.x), z1, top, mat, collide, bottom)
			return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(x1 - x0, top - bottom, z1 - z0)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3((x0 + x1) * 0.5, (top + bottom) * 0.5, (z0 + z1) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 1300.0
	(c.w as World).static_root.add_child(mi)
	if collide:
		CoastProps._box(c.body, bm.size, mi.position)

## A pavement strip along x from xa to xb (local to o), z from za to zb, with gaps where a lot's entrance cuts the kerb.
static func _xband(c: Dictionary, o: Vector2, xa: float, xb: float, za: float, zb: float, cuts: Array) -> void:
	var from := xa
	var sorted := cuts.duplicate()
	sorted.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	for cu in sorted:
		var c0: float = maxf(float(cu[0]), xa)
		var c1: float = minf(float(cu[1]), xb)
		if c1 <= c0: continue
		_slab(c, o.x + from, o.y + za, o.x + c0, o.y + zb, BAND_H, c.pave, false)
		from = c1
	_slab(c, o.x + from, o.y + za, o.x + xb, o.y + zb, BAND_H, c.pave, false)

static func _put(c: Dictionary, key: String, centre: Vector2, yaw: float, collide := true, unique := false) -> void:
	var sp: Dictionary = specs[key]
	var t := Transform3D(Basis(Vector3.UP, yaw + float(sp.yaw0)), Vector3(centre.x, BASE_H, centre.y))
	if unique:
		var mi := MeshInstance3D.new()
		mi.mesh = sp.mesh
		mi.transform = t
		mi.visibility_range_end = 2400.0
		(c.w as World).static_root.add_child(mi)
	else:
		if not (c.batch as Dictionary).has(key): c.batch[key] = []
		(c.batch[key] as Array).append(t)
	(layout.buildings as Array).append({"k": key, "x": centre.x, "z": centre.y, "yaw": yaw, "w": float(sp.w), "d": float(sp.d)})
	if collide:
		var sz: Vector3 = sp.size
		CoastProps._box(c.body, Vector3(sp.w, sz.y, sp.d), Vector3(centre.x, BASE_H + sz.y * 0.5, centre.y), yaw)

## One row of buildings along local x from x0 to x1, fronts on the line z = zf facing `facing` (+1 or -1 in z).
static func _row(c: Dictionary, origin: Vector2, keys: Array, x0: float, x1: float, zf: float, facing: float, max_depth: float) -> int:
	var rng: RandomNumberGenerator = c.rng
	var x := x0
	var last := ""
	var n := 0
	var yaw := 0.0 if facing > 0.0 else PI
	while x < x1 - 4.0:
		var key := ""
		for tries in range(10):
			var k: String = keys[rng.randi() % keys.size()]
			var sp: Dictionary = specs[k]
			if k == last and keys.size() > 1: continue
			if float(sp.d) > max_depth: continue
			if x + float(sp.w) > x1 + 0.5: continue
			key = k
			break
		if key == "":
			x += 5.0
			continue
		var sp2: Dictionary = specs[key]
		var w := float(sp2.w)
		var d := float(sp2.d)
		var fp := Rect2(origin.x + x - 1.0, minf(origin.y + zf, origin.y + zf - facing * d) - 1.0, w + 2.0, d + 2.0)
		var blocked := false
		for rv in reserved:
			if fp.intersects(rv): blocked = true
		if blocked:
			x += 4.0
			continue
		_put(c, key, origin + Vector2(x + w * 0.5, zf - facing * d * 0.5), yaw)
		last = key
		n += 1
		x += w + rng.randf_range(0.8, 3.0)
	return n

## Lot, pavements and lanes of a block. mode: "cross" (a lane each way), "ew" (one east-west lane), "none".
static func _block_base(c: Dictionary, o: Vector2, mode: String, cuts := {}) -> void:
	(layout.blocks as Array).append({"x": o.x, "z": o.y, "mode": mode})
	var conc: Material = c.conc
	var xr: Array = [[-EDGE, -LANE_HALF], [LANE_HALF, EDGE]] if mode == "cross" else [[-EDGE, EDGE]]
	var zr: Array = [[-EDGE, -LANE_HALF], [LANE_HALF, EDGE]] if mode != "none" else [[-EDGE, EDGE]]
	var LP := LANE_PAVE
	for xq in xr:
		for zq in zr:
			var x0: float = xq[0]
			var x1: float = xq[1]
			var z0: float = zq[0]
			var z1: float = zq[1]
			_slab(c, o.x + x0, o.y + z0, o.x + x1, o.y + z1, BASE_H, conc, true)
			var ex0 := x0 - (0.01 if x0 == -EDGE else 0.0)
			var ex1 := x1 + (0.01 if x1 == EDGE else 0.0)
			if z0 == -EDGE: _slab(c, o.x + ex0, o.y - EDGE - 0.01, o.x + ex1, o.y - EDGE + PAVE, BAND_H, c.pave, false)
			if z1 == EDGE: _slab(c, o.x + ex0, o.y + EDGE - PAVE, o.x + ex1, o.y + EDGE + 0.01, BAND_H, c.pave, false)
			if x0 == -EDGE: _slab(c, o.x - EDGE - 0.01, o.y + z0, o.x - EDGE + PAVE, o.y + z1, BAND_H, c.pave, false)
			if x1 == EDGE: _slab(c, o.x + EDGE - PAVE, o.y + z0, o.x + EDGE + 0.01, o.y + z1, BAND_H, c.pave, false)
			if mode != "none":
				if z1 == -LANE_HALF: _xband(c, o, x0, x1, z1 - LP, z1 + 0.01, cuts.get(-1, []))
				if z0 == LANE_HALF: _xband(c, o, x0, x1, z0 - 0.01, z0 + LP, cuts.get(1, []))
			if mode == "cross":
				if x1 == -LANE_HALF: _slab(c, o.x + x1 - LP, o.y + z0, o.x + x1 + 0.01, o.y + z1, BAND_H, c.pave, false)
				if x0 == LANE_HALF: _slab(c, o.x + x0 - 0.01, o.y + z0, o.x + x0 + LP, o.y + z1, BAND_H, c.pave, false)
	if mode == "none": return
	var asphalt: Material = c.asphalt
	var line: Material = (c.w as World)._flat(Color("#ecebe0"))
	_slab(c, o.x - EDGE - 0.4, o.y - LANE_HALF, o.x + EDGE + 0.4, o.y + LANE_HALF, 0.17, asphalt, true)
	var xx := -EDGE + 4.0
	while xx < EDGE - 4.0:
		_slab(c, o.x + xx, o.y - 0.08, o.x + xx + 2.2, o.y + 0.08, 0.176, line, false, 0.17)
		xx += 5.0
	var lamp_x: Array = [-62.0, 62.0] if mode == "cross" else [-62.0, 0.0, 62.0]
	var side := 1.0
	for lx: float in lamp_x:
		RoadKit.lamp_at(c.w, c.body, o + Vector2(lx, side * (LANE_HALF + 1.4)), o + Vector2(lx, 0.0), BASE_H)
		side = -side
	if mode == "cross":
		_slab(c, o.x - LANE_HALF, o.y - EDGE - 0.4, o.x + LANE_HALF, o.y + EDGE + 0.4, 0.17, asphalt, true)
		var zz := -EDGE + 4.0
		while zz < EDGE - 4.0:
			_slab(c, o.x - 0.08, o.y + zz, o.x + 0.08, o.y + zz + 2.2, 0.176, line, false, 0.17)
			zz += 5.0
		side = 1.0
		for lz: float in [-62.0, 62.0]:
			RoadKit.lamp_at(c.w, c.body, o + Vector2(side * (LANE_HALF + 1.4), lz), o + Vector2(0.0, lz), BASE_H)
			side = -side

static func _paved_full(c: Dictionary, o: Vector2) -> void:
	_block_base(c, o, "none")
	_slab(c, o.x - EDGE + PAVE, o.y - EDGE + PAVE, o.x + EDGE - PAVE, o.y + EDGE - PAVE, BAND_H - 0.01, c.pave, false)

static func _res_keys() -> Array:
	return ["r1", "r2a", "r2c", "soviet", "bordeaux", "york", "ait", "york", "asian", "ait", "r2b", "asian"]

## Fills one half (north sgn -1, south sgn +1) of a block with two rows of buildings. cross: split at the north-south lane.
static func _fill_half(c: Dictionary, o: Vector2, sgn: float, cross: bool) -> int:
	var segs: Array = [[-OUTER_LINE, -LANE_LINE], [LANE_LINE, OUTER_LINE]] if cross else [[-OUTER_LINE, OUTER_LINE]]
	var n := 0
	for sg in segs:
		n += _row(c, o, _res_keys(), sg[0], sg[1], sgn * OUTER_LINE, sgn, 26.0)
		n += _row(c, o, _res_keys(), sg[0], sg[1], sgn * LANE_LINE, -sgn, 26.0)
		_courtyard(c, o, sgn, sg[0], sg[1])
	return n

## Green courtyard between the two building rows of a quarter (a lawn with a few trees), so the middle of a block is a garden
## instead of bare paving.
static func _courtyard(c: Dictionary, o: Vector2, sgn: float, x0: float, x1: float) -> void:
	var za := sgn * (LANE_LINE + 27.0)
	var zb := sgn * (OUTER_LINE - 27.0)
	var z0 := minf(za, zb)
	var z1 := maxf(za, zb)
	if z1 - z0 < 8.0 or x1 - x0 < 12.0: return
	_slab(c, o.x + x0 + 3.0, o.y + z0, o.x + x1 - 3.0, o.y + z1, LOT_TOP, c.lawn, false, BASE_H)
	(layout.courts as Array).append([o.x + x0 + 3.0, o.y + z0, o.x + x1 - 3.0, o.y + z1])
	var rng: RandomNumberGenerator = c.rng
	var spots: Array = []
	var n := int((x1 - x0) / 26.0)
	for k in range(maxi(n, 1)):
		spots.append(o + Vector2(x0 + (k + 0.5) * (x1 - x0) / maxi(n, 1) + rng.randf_range(-3.0, 3.0), (z0 + z1) * 0.5 + rng.randf_range(-3.0, 3.0)))
	_trees(c, spots)
	# grass tufts, ferns and a few wildflowers over the lawn
	var area := (x1 - x0 - 6.0) * (z1 - z0)
	for k in range(mini(int(area / 7.0), 160)):
		var lp := o + Vector2(rng.randf_range(x0 + 4.0, x1 - 4.0), rng.randf_range(z0 + 1.0, z1 - 1.0))
		var r := rng.randf()
		var key := "tuft"
		if r > 0.78: key = "tallg"
		elif r > 0.66: key = "fern"
		elif r > 0.5: key = "flower"
		_scatter(c, key, lp, rng.randf_range(0.9, 1.5), LOT_TOP)

static func _near_lot(p: Vector2, margin: float) -> bool:
	# the H tower's south car park (Districts._tower_parking: x 55..135, z 164..186.6)
	if p.x > 55.0 - margin and p.x < 135.0 + margin and p.y > 164.0 - margin and p.y < 186.6 + margin: return true
	# the H tower's own forecourt car park (north side of its block) is kept free of trees too
	if p.x > 95.5 - 41.0 - margin and p.x < 95.5 + 41.0 + margin and p.y > 95.5 - 89.6 - margin and p.y < 95.5 - 62.0 + margin: return true
	for l in layout.lots:
		if p.x > float(l[0]) - margin and p.x < float(l[2]) + margin and p.y > float(l[1]) - margin and p.y < float(l[3]) + margin: return true
	return false

static func _scatter(c: Dictionary, key: String, p: Vector2, scale: float, y := BASE_H) -> void:
	var rng: RandomNumberGenerator = c.rng
	var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * scale), Vector3(p.x, y, p.y))
	if not (c.batch as Dictionary).has(key): c.batch[key] = []
	(c.batch[key] as Array).append(t)

## Trees along the pavements of every block (an oak every ~40 m, a little smaller than the park trees), skipping the corners
## and the mouths of the lanes.
static func _street_trees(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var n := 0
	for bj in range(4):
		for bi in range(4):
			var o := Vector2(BX[bi], BX[bj])
			var off := EDGE - PAVE * 0.5
			var t := -72.0 + rng.randf_range(0.0, 8.0)
			while t < 72.0:
				if absf(t) > 11.0:
					for edge in [[Vector2(t, -off), 0], [Vector2(t, off), 1], [Vector2(-off, t), 2], [Vector2(off, t), 3]]:
						if rng.randf() < 0.82 and not _near_lot(o + (edge[0] as Vector2), 8.0):
							var p: Vector2 = o + (edge[0] as Vector2)
							var sc := rng.randf_range(0.48, 0.62)
							var tr := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * sc), Vector3(p.x, BASE_H, p.y))
							if not (c.batch as Dictionary).has("oak"): c.batch["oak"] = []
							(c.batch["oak"] as Array).append(tr)
							CoastProps._box(c.body, Vector3(0.5, 4.0, 0.5), Vector3(p.x, BASE_H + 2.0, p.y))
							n += 1
				t += 40.0
	# the grass block round the H tower: a ring of trees
	var hc := Vector2(95.5, 95.5)
	for k in range(16):
		var a := TAU * k / 16.0 + rng.randf_range(-0.1, 0.1)
		var rr := rng.randf_range(66.0, 80.0)
		var tp: Vector2 = hc + Vector2(cos(a), sin(a)) * rr
		if _near_lot(tp, 4.0): continue
		_scatter(c, "oak", tp, rng.randf_range(0.8, 1.1), 0.0)
	print("city: %d street trees" % n)

static func _trees(c: Dictionary, spots: Array) -> void:
	for p: Vector2 in spots:
		var t := Transform3D(Basis(Vector3.UP, (c.rng as RandomNumberGenerator).randf() * TAU) * Basis.from_scale(Vector3.ONE * (c.rng as RandomNumberGenerator).randf_range(0.8, 1.1)), Vector3(p.x, BASE_H, p.y))
		if not (c.batch as Dictionary).has("oak"): c.batch["oak"] = []
		(c.batch["oak"] as Array).append(t)
		CoastProps._box(c.body, Vector3(0.9, 5.0, 0.9), Vector3(p.x, BASE_H + 2.5, p.y))

## Parking bays: an asphalt apron with painted bays on one or two sides of an aisle, with cars parked in most of them.
static func _lot(c: Dictionary, o: Vector2, x0: float, z0: float, x1: float, z1: float, car_kind: String, ambulances := 0, top := LOT_TOP) -> void:
	var w: World = c.w
	var rng: RandomNumberGenerator = c.rng
	_slab(c, o.x + x0, o.y + z0, o.x + x1, o.y + z1, top, c.asphalt, false, BASE_H)
	(layout.lots as Array).append([o.x + x0, o.y + z0, o.x + x1, o.y + z1])
	var line: Material = w._flat(Color("#ecebe0"))
	var depth := z1 - z0
	var two := depth >= 15.0
	var bay_d := 5.2
	var rows: Array = [[z0, z0 + bay_d, 1.0]]
	if two: rows.append([z1 - bay_d, z1, -1.0])
	var bay_w := 2.9
	var nb := int((x1 - x0) / bay_w)
	var amb_left := ambulances
	for r in rows:
		var zr0: float = r[0]
		var zr1: float = r[1]
		var face: float = r[2]
		for k in range(nb + 1):
			var xl := x0 + k * bay_w
			_slab(c, o.x + xl - 0.05, o.y + zr0, o.x + xl + 0.05, o.y + zr1, top + 0.006, line, false, top)
		for k in range(nb):
			var xc := x0 + (k + 0.5) * bay_w
			var zc := (zr0 + zr1) * 0.5
			var p := o + Vector2(xc, zc)
			if amb_left > 0 and face > 0.0:
				amb_left -= 1
				var amb := Car.new()
				amb.position = Vector3(p.x, top + Car.RIDE + 0.15, p.y)
				amb.rotation.y = 0.0 if face > 0.0 else PI
				w.add_child(amb)
				amb.setup("ambulance", "", true)
				continue
			if PARKED_CARS and rng.randf() < 0.3:
				var car := Car.new()
				car.position = Vector3(p.x, top + 0.62, p.y)
				car.rotation.y = 0.0 if face > 0.0 else PI
				w.add_child(car)
				car.setup(car_kind, "", true)

static func _fountain_plaza(c: Dictionary, p: Vector2) -> void:
	(layout.plaza as Array).append([p.x, p.y])
	var w: World = c.w
	var stone: Material = c.pave
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 8.2
	cm.bottom_radius = 8.2
	cm.height = 0.9
	cm.radial_segments = 40
	ring.mesh = cm
	ring.material_override = stone
	ring.position = Vector3(p.x, BASE_H + 0.45, p.y)
	w.static_root.add_child(ring)
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 7.5
	wm.bottom_radius = 7.5
	wm.height = 0.02
	wm.radial_segments = 40
	water.mesh = wm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.45, 0.62, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.3
	water.material_override = mat
	water.position = Vector3(p.x, BASE_H + 0.92, p.y)
	w.static_root.add_child(water)
	CoastProps._box(c.body, Vector3(16.4, 0.9, 16.4), Vector3(p.x, BASE_H + 0.45, p.y))
	var ped := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 2.2
	pm.bottom_radius = 2.6
	pm.height = 1.3
	ped.mesh = pm
	ped.material_override = stone
	ped.position = Vector3(p.x, BASE_H + 0.65, p.y)
	w.static_root.add_child(ped)
	_put(c, "fountain", p, 0.0, false, true)

## Fills the empty ground of one half-block with offices and shops: greedy over a grid, only where the footprint is clear.
static func _fill_gaps(c: Dictionary, o: Vector2, sgn: float, keys: Array) -> int:
	var rng: RandomNumberGenerator = c.rng
	var occ: Array = _occupied()
	var n := 0
	var zmin := LANE_LINE + 0.5
	var zmax := OUTER_LINE
	var gx := -OUTER_LINE
	while gx < OUTER_LINE - 8.0:
		var gz := zmin
		var placed := false
		while gz < zmax - 8.0:
			var order := keys.duplicate()
			order.shuffle()
			for k in order:
				var sp: Dictionary = specs[k]
				var w := float(sp.w)
				var d := float(sp.d)
				if gx + w > OUTER_LINE or gz + d > zmax: continue
				var cx := o.x + gx + w * 0.5
				var cz := o.y + sgn * (gz + d * 0.5)
				var rect := [cx - w * 0.5, cz - d * 0.5, cx + w * 0.5, cz + d * 0.5]
				if not _free(occ, rect, 2.0): continue
				var near_lane := (gz + d * 0.5) < (zmin + zmax) * 0.5
				var facing := -sgn if near_lane else sgn
				_put(c, k, Vector2(cx, cz), 0.0 if facing > 0.0 else PI)
				occ.append(rect)
				n += 1
				gx += w
				placed = true
				break
			if placed: break
			gz += 3.0
		if not placed: gx += 3.0
	return n

## The fenced compound in front of the police station / hospital: fence along the street with a gate, parking bays just inside,
## an open garage with the station's vehicles on one side, and a straight paved way from the gate to the door.
## t runs from the fence (0) inward to the building front (cd); the street is on the sgn side.
static func _compound(c: Dictionary, o: Vector2, sgn: float, key: String, xc: float, fx0: float, fx1: float, cd: float, back_t: float, heli_x: float) -> void:
	var w: World = c.w
	var top := LOT_TOP
	var x0 := fx0
	var x1 := fx1
	var cw := x1 - x0
	var iron: Material = w._flat(Color("#23262b"))
	var conc: Material = w._flat(Color("#9b9a94"))
	var accent := Color("#2b55c8") if key == "police" else Color("#e02a2a")
	var lanemat: Material = w._flat(Color("#ecebe0"))
	# ground: asphalt, a paved straight way from the gate to the door
	_slab(c, o.x + x0, minf(o.y + sgn * OUTER_LINE, o.y + sgn * (OUTER_LINE - back_t)), o.x + x1, maxf(o.y + sgn * OUTER_LINE, o.y + sgn * (OUTER_LINE - back_t)), top, c.asphalt, false, BASE_H)
	var pw := 5.0
	_slab(c, o.x + xc - pw * 0.5, minf(o.y + sgn * OUTER_LINE, o.y + sgn * (OUTER_LINE - cd)), o.x + xc + pw * 0.5, maxf(o.y + sgn * OUTER_LINE, o.y + sgn * (OUTER_LINE - cd)), top + 0.006, c.pave, false, top)
	(layout.lots as Array).append([o.x + x0, minf(o.y + sgn * OUTER_LINE, o.y + sgn * (OUTER_LINE - back_t)), o.x + x1, maxf(o.y + sgn * OUTER_LINE, o.y + sgn * (OUTER_LINE - back_t))])
	var zt := func(t: float) -> float: return o.y + sgn * (OUTER_LINE - t)
	# fence: posts and rails, solid collision; a gate gap in front, the building closes the back
	var gate := 8.0
	var runs: Array = [
		["x", x0, xc - gate * 0.5, 0.0], ["x", xc + gate * 0.5, x1, 0.0],
		["z", 0.0, back_t, x0], ["z", 0.0, back_t, x1], ["x", x0, x1, back_t]]
	for r in runs:
		var along_x: bool = r[0] == "x"
		var a0: float = r[1]
		var a1: float = r[2]
		var fixed: float = r[3]
		var len := a1 - a0
		if len < 0.5: continue
		var mid := (a0 + a1) * 0.5
		var pos := Vector3(o.x + mid, top, zt.call(fixed)) if along_x else Vector3(o.x + fixed, top, zt.call(mid))
		for ry in [0.45, 1.0, 1.65]:
			var rail := MeshInstance3D.new()
			var rb := BoxMesh.new()
			rb.size = Vector3(len, 0.08, 0.08) if along_x else Vector3(0.08, 0.08, len)
			rail.mesh = rb
			rail.material_override = iron
			rail.position = pos + Vector3(0, ry, 0)
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			w.static_root.add_child(rail)
		var np := int(len / 2.0) + 1
		for k in range(np + 1):
			var f := float(k) / float(np)
			var post := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(0.14, 1.8, 0.14)
			post.mesh = pb
			post.material_override = iron
			post.position = Vector3(o.x + a0 + len * f, top + 0.9, zt.call(fixed)) if along_x else Vector3(o.x + fixed, top + 0.9, zt.call(a0 + len * f))
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			w.static_root.add_child(post)
		# pickets: one thin textured-by-colour wall of bars as a single box would hide the yard, so a see-through grid of slim bars
		var nb := int(len / 0.45)
		var bars := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 1.55, 0.03)
		mm.mesh = bm
		mm.instance_count = nb
		for k in range(nb):
			var f := (float(k) + 0.5) / float(nb)
			var bp := Vector3(o.x + a0 + len * f, top + 0.88, zt.call(fixed)) if along_x else Vector3(o.x + fixed, top + 0.88, zt.call(a0 + len * f))
			mm.set_instance_transform(k, Transform3D(Basis(), bp))
		bars.multimesh = mm
		bars.material_override = iron
		bars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(bars)
		CoastProps._box(c.body, Vector3(len, 1.8, 0.2) if along_x else Vector3(0.2, 1.8, len), pos + Vector3(0, 0.9, 0))
	# gate pillars and a sign beam across the gate
	for gx in [xc - gate * 0.5, xc + gate * 0.5]:
		var pil := MeshInstance3D.new()
		var pbx := BoxMesh.new()
		pbx.size = Vector3(0.7, 4.6, 0.7)
		pil.mesh = pbx
		pil.material_override = conc
		pil.position = Vector3(o.x + gx, top + 2.3, zt.call(0.0))
		w.static_root.add_child(pil)
		CoastProps._box(c.body, pbx.size, pil.position)
	var beam := MeshInstance3D.new()
	var bbx := BoxMesh.new()
	bbx.size = Vector3(gate + 0.7, 1.4, 0.5)
	beam.mesh = bbx
	beam.material_override = w._flat(accent, 0.9)
	beam.position = Vector3(o.x + xc, top + 4.2, zt.call(0.0))
	w.static_root.add_child(beam)
	# the name, readable from the street and from inside
	var title := "REDLINE CITY POLICE" if key == "police" else "REDLINE CITY HOSPITAL"
	for face in [1.0, -1.0]:
		var lb := Label3D.new()
		lb.text = title
		lb.font_size = 72
		lb.pixel_size = 0.0075
		lb.outline_size = 14
		lb.modulate = Color(1, 1, 1)
		lb.outline_modulate = accent.darkened(0.55)
		lb.shaded = false
		lb.double_sided = false
		lb.position = beam.position + Vector3(0, 0, face * sgn * 0.27)
		lb.rotation.y = 0.0 if face * sgn > 0.0 else PI
		w.static_root.add_child(lb)
	# parking bays just inside the gate, on both sides of the way
	var bay_w := 2.9
	for side in [-1.0, 1.0]:
		var bx_start: float = xc + float(side) * (pw * 0.5 + 0.8)
		var nbay := int(((xc - x0) if side < 0.0 else (x1 - xc)) / bay_w - 1.3)
		if side > 0.0: nbay = mini(nbay, 5)
		for k in range(nbay + 1):
			var lx: float = bx_start + float(side) * k * bay_w
			var tz0: float = zt.call(1.2)
			var tz1: float = zt.call(6.4)
			_slab(c, o.x + lx - 0.05, minf(tz0, tz1), o.x + lx + 0.05, maxf(tz0, tz1), top + 0.012, lanemat, false, top)
	# garage on the left of the way, against the building side; open towards the way, back wall towards the building
	var gw := 15.0 if key == "police" else 14.0
	var gd := 6.4
	var gx1 := xc - pw * 0.5 - 1.5
	var gx0 := gx1 - gw
	var t_back := cd - 1.0
	var t_open := t_back - gd
	var gzmid: float = zt.call((t_back + t_open) * 0.5)
	var roof_y := top + 3.6
	var roof := MeshInstance3D.new()
	var rfb := BoxMesh.new()
	rfb.size = Vector3(gw + 0.8, 0.3, gd + 0.8)
	roof.mesh = rfb
	roof.material_override = w._flat(Color("#2f3b52") if key == "police" else Color("#c8d0d6"))
	roof.position = Vector3(o.x + (gx0 + gx1) * 0.5, roof_y, gzmid)
	w.static_root.add_child(roof)
	CoastProps._box(c.body, rfb.size, roof.position)
	var trim := MeshInstance3D.new()
	var tbx := BoxMesh.new()
	tbx.size = Vector3(gw + 0.9, 0.2, 0.2)
	trim.mesh = tbx
	trim.material_override = w._flat(accent, 0.7)
	trim.position = Vector3(roof.position.x, roof_y - 0.1, zt.call(t_open))
	w.static_root.add_child(trim)
	var back := MeshInstance3D.new()
	var bkb := BoxMesh.new()
	bkb.size = Vector3(gw + 0.4, 3.6, 0.3)
	back.mesh = bkb
	back.material_override = w._flat(Color("#5b6475"))
	back.position = Vector3(roof.position.x, top + 1.8, zt.call(t_back + 0.1))
	w.static_root.add_child(back)
	CoastProps._box(c.body, bkb.size, back.position)
	var nposts := int(gw / 5.0) + 1
	for k in range(nposts):
		var px := gx0 + gw * float(k) / float(nposts - 1)
		var pst := MeshInstance3D.new()
		var pbk := BoxMesh.new()
		pbk.size = Vector3(0.35, 3.6, 0.35)
		pst.mesh = pbk
		pst.material_override = w._flat(Color("#5b6475"))
		pst.position = Vector3(o.x + px, top + 1.8, zt.call(t_open))
		w.static_root.add_child(pst)
		CoastProps._box(c.body, pbk.size, pst.position)
	var ol := OmniLight3D.new()
	ol.position = Vector3(roof.position.x, roof_y - 0.6, gzmid)
	ol.omni_range = 11.0
	ol.light_energy = 0.9
	ol.light_color = Color("#fff1d6")
	ol.shadow_enabled = false
	w.add_child(ol)
	# the helipad inside the fence, beside the building, its stairs towards the way
	var hs: Dictionary = specs["helipad"]
	var hb: AABB = (hs.mesh as Mesh).get_aabb()
	var hr := 7.37 * 0.0115 * 100.0
	var pad_off := Vector3(hb.position.x + hr, 0.0, hb.position.z + hr)
	var hyaw := (-PI * 0.5) if heli_x > xc else (PI * 0.5)
	var hbasis := Basis(Vector3.UP, hyaw)
	var hpos := Vector3(o.x + heli_x, BASE_H, zt.call(cd + (back_t - cd) * 0.5)) - hbasis * pad_off
	var hmi := MeshInstance3D.new()
	hmi.mesh = hs.mesh
	hmi.transform = Transform3D(hbasis, hpos)
	hmi.visibility_range_end = 900.0
	w.static_root.add_child(hmi)
	var pad_center := hpos + hbasis * hb.get_center()
	# solid: the helipad's own mesh (drum, deck, stairs) is the collision, so the deck is walkable and the stairs climbable
	var hcs := CollisionShape3D.new()
	hcs.shape = (hs.mesh as Mesh).create_trimesh_shape()
	hcs.transform = Transform3D(hbasis, hpos)
	c.body.add_child(hcs)
	(layout.buildings as Array).append({"k": "helipad", "x": pad_center.x, "z": pad_center.z, "yaw": 0.0, "w": hr * 2.0, "d": hr * 2.0})
	var hc := HelipadChopper.new()
	hc.setup(key)
	w.add_child(hc)
	hc.global_position = Vector3(pad_center.x, BASE_H + 1.9, pad_center.z)
	hc.rotation.y = hyaw + PI          # face away from the building (toward the open yard)
	# the station's own vehicles: nose towards the street
	var face_yaw := 0.0 if sgn > 0.0 else PI
	var kind := "police" if key == "police" else "ambulance"
	var ngar := 3
	for k in range(ngar):
		var car := Car.new()
		car.position = Vector3(o.x + gx0 + 2.8 + k * (gw - 5.6) / float(ngar - 1), top + Car.RIDE + 0.15, gzmid)
		car.rotation.y = face_yaw
		w.add_child(car)
		car.setup(kind, "", true)
	for k in range(2):
		var car2 := Car.new()
		car2.position = Vector3(o.x + xc + pw * 0.5 + 0.8 + bay_w * (0.5 + float(k) * 2.0), top + Car.RIDE + 0.15, zt.call(3.8))
		car2.rotation.y = face_yaw + PI
		w.add_child(car2)
		car2.setup(kind, "", true)

## A service building (fire / police / hospital) on the outer row of one half-block, its parking lot on the lane side
## with the lane kerb cut away at the entrance, and ordinary rows filling the rest of the half.
static func _service(c: Dictionary, o: Vector2, sgn: float, key: String, xc: float, lot_x0: float, lot_x1: float, car_kind: String, ambulances := 0) -> int:
	var sp: Dictionary = specs[key]
	var w := float(sp.w)
	var d := float(sp.d)
	var compound := key == "police" or key == "hospital"
	var cd := 0.0
	var fence_x0 := xc - w * 0.5
	var fence_x1 := xc + w * 0.5
	var bz := OUTER_LINE - d * 0.5               # building centre, measured inwards from the block centre on the sgn side
	if compound:
		cd = 18.0 if key == "police" else 15.0
		bz = OUTER_LINE - cd - d * 0.5
	var door_dx := -5.6 if key == "police" else 0.0       # the police station's door is off-centre: line it up with the way
	_put(c, key, o + Vector2(xc + door_dx, sgn * bz), 0.0 if sgn > 0.0 else PI, true, true)
	var poi_names := {"fire": "FIRE STATION", "police": "REDLINE CITY POLICE", "hospital": "REDLINE CITY HOSPITAL"}
	(c.w as World).add_poi(key, poi_names[key], Vector3(o.x + xc, 0.0, o.y + sgn * (OUTER_LINE - cd * 0.5 - (0.0 if compound else d * 0.5))))
	var depth := 17.0
	var zl0 := (LANE_HALF + LANE_PAVE + 0.6) if sgn > 0.0 else -(LANE_HALF + LANE_PAVE + 0.6 + depth)
	_lot(c, o, lot_x0, zl0, lot_x1, zl0 + depth, car_kind, 0)
	var lane_depth := MAX_DEPTH
	if compound:
		var back_t := cd + d + 0.8
		var heli_x := xc + door_dx + w * 0.5 + 16.5  # +4 offset so the helipad mesh clears the building by ~2 m (mesh left edge is ~14.5 m left of anchor)
		fence_x0 = xc - (22.0 if key == "police" else 34.0)
		fence_x1 = heli_x + 10.5
		_compound(c, o, sgn, key, xc, fence_x0, fence_x1, cd, back_t, heli_x)
		lane_depth = OUTER_LINE - cd - d - 1.5 - LANE_LINE
		# staff stand and roam on the way and in the parking, inside the fence
		var staff: Array = []
		if key == "hospital": staff = [["doctor", -3.0, 9.0], ["nurse", 3.0, 11.0], ["nurse", -12.0, 8.0], ["doctor", 12.0, 8.0], ["nurse", 0.0, 12.0]]
		else: staff = [["cop", -3.0, 6.0], ["cop", 3.0, 6.0], ["cop", -9.0, 5.0], ["cop", 9.0, 5.0], ["cop", 0.0, 8.0]]
		for st in staff:
			var t_pos := 4.0 + (float(st[2]) * 0.5)
			var spos := Vector3(o.x + xc + float(st[1]), 0.0, o.y + sgn * (OUTER_LINE - minf(t_pos, cd - 2.0)))
			(c.w as World).spawns.append({"type": "npc", "who": st[0], "pos": spos, "yaw": 0.0, "wander": minf(float(st[2]), cd * 0.45)})
	var keys := _res_keys()
	var n := 0
	var bx0 := fence_x0 - 3.0
	var bx1 := fence_x1 + 3.0
	n += _row(c, o, keys, -OUTER_LINE, bx0, sgn * OUTER_LINE, sgn, MAX_DEPTH)
	n += _row(c, o, keys, bx1, OUTER_LINE, sgn * OUTER_LINE, sgn, MAX_DEPTH)
	n += _row(c, o, keys, -OUTER_LINE, lot_x0 - 3.0, sgn * LANE_LINE, -sgn, lane_depth)
	n += _row(c, o, keys, lot_x1 + 3.0, OUTER_LINE, sgn * LANE_LINE, -sgn, lane_depth)
	return n

# ------------------------------------------------------------------ offices

static var _office_mats := {}

static func _office_mat(tint: Color) -> ShaderMaterial:
	var key := tint.to_html()
	if _office_mats.has(key): return _office_mats[key]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/building_night.gdshader") as Shader
	sm.set_shader_parameter("has_tex", true)
	sm.set_shader_parameter("albedo_tex", load("res://assets/town/office_facade.png"))
	sm.set_shader_parameter("albedo_col", tint)
	sm.set_shader_parameter("facade", true)
	sm.set_shader_parameter("mode", 1)
	sm.set_shader_parameter("floor_h", 3.6)
	sm.set_shader_parameter("cell_w", 2.6)
	sm.set_shader_parameter("lit_frac", 0.62)
	sm.set_shader_parameter("gain", 1.0)
	CityLights.register(sm)
	_office_mats[key] = sm
	return sm

## Occupied ground rectangles (x0, z0, x1, z1): every building put so far, the car parks and the plazas.
static func _occupied() -> Array:
	var occ: Array = []
	for b in layout.buildings:
		if b.k in ["oak", "phone", "cart", "ambulance", "fountain", "tuft", "tallg", "fern", "flower"]: continue
		var hw := float(b.w) * 0.5
		var hd := float(b.d) * 0.5
		occ.append([float(b.x) - hw, float(b.z) - hd, float(b.x) + hw, float(b.z) + hd])
	for l in layout.lots: occ.append([float(l[0]) - 7.0, float(l[1]) - 7.0, float(l[2]) + 7.0, float(l[3]) + 7.0])     # car parks keep a clear apron round them
	for pz in layout.plaza: occ.append([float(pz[0]) - 12.0, float(pz[1]) - 12.0, float(pz[0]) + 12.0, float(pz[1]) + 12.0])
	return occ

static func _free(occ: Array, r: Array, margin: float) -> bool:
	for o in occ:
		if r[0] < float(o[2]) + margin and r[2] > float(o[0]) - margin and r[1] < float(o[3]) + margin and r[3] > float(o[1]) - margin: return false
	return true

## A small glass-and-concrete office: a solid box with the window-cell facade, a roof parapet and plant room, a canopy and a
## glass entrance on the front (facing +z in the building's own frame, turned by yaw).
static func _office(c: Dictionary, centre: Vector2, w: float, d: float, h: float, yaw: float, tint: Color, apron := true) -> void:
	var wd: World = c.w
	var rot := Basis(Vector3.UP, yaw)
	if apron:
		var hx := (w if absf(sin(yaw)) < 0.5 else d) * 0.5 + 2.0
		var hz := (d if absf(sin(yaw)) < 0.5 else w) * 0.5 + 2.0
		_slab(c, centre.x - hx, centre.y - hz, centre.x + hx, centre.y + hz, BASE_H, c.conc, false)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	box.mesh = bm
	box.material_override = _office_mat(tint)
	box.transform = Transform3D(rot, Vector3(centre.x, BASE_H + h * 0.5, centre.y))
	box.visibility_range_end = 900.0
	wd.static_root.add_child(box)
	CoastProps._box(c.body, bm.size, box.position, yaw)
	var roof_y := BASE_H + h
	var flat: Material = wd._flat(Color(0.36, 0.37, 0.4))
	var par := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(w * 0.34, 1.6, d * 0.4)
	par.mesh = pb
	par.material_override = flat
	par.transform = Transform3D(rot, Vector3(centre.x, roof_y + 0.8, centre.y) + rot * Vector3(w * 0.15, 0.0, -d * 0.1))
	par.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wd.static_root.add_child(par)
	# entrance: a glass door band and a canopy slab over it, on the +z (front) face
	var front := rot * Vector3(0.0, 0.0, d * 0.5)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(min(6.0, w * 0.3), 2.8, 0.2)
	door.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.1, 0.16, 0.22)
	dmat.metallic = 0.5
	dmat.roughness = 0.15
	door.material_override = dmat
	door.transform = Transform3D(rot, Vector3(centre.x, BASE_H + 1.4, centre.y) + front + rot * Vector3(0, 0, 0.12))
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wd.static_root.add_child(door)
	var can := MeshInstance3D.new()
	var cmx := BoxMesh.new()
	cmx.size = Vector3(min(7.5, w * 0.4), 0.25, 2.4)
	can.mesh = cmx
	can.material_override = flat
	can.transform = Transform3D(rot, Vector3(centre.x, BASE_H + 3.3, centre.y) + front + rot * Vector3(0, 0, 1.1))
	can.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wd.static_root.add_child(can)
	(layout.buildings as Array).append({"k": "office", "x": centre.x, "z": centre.y, "yaw": yaw, "w": w if absf(sin(yaw)) < 0.5 else d, "d": d if absf(sin(yaw)) < 0.5 else w})

const OFFICE_SIZES := [Vector3(24, 16, 14), Vector3(30, 20, 16), Vector3(20, 14, 13), Vector3(34, 24, 18), Vector3(26, 18, 15), Vector3(18, 12, 10), Vector3(22, 13, 11)]
const OFFICE_TINTS := [Color(0.82, 0.9, 1.0), Color(1.0, 0.95, 0.86), Color(0.86, 0.94, 0.9), Color(0.95, 0.88, 0.88), Color(0.8, 0.84, 0.92)]

## A row of offices along a frontage: from x0 to x1 (block-local), fronts on z = zf facing `facing`, taking every gap that is free.
static func _office_row(c: Dictionary, o: Vector2, x0: float, x1: float, zf: float, facing: float, occ: Array, max_depth := 20.0) -> int:
	var rng: RandomNumberGenerator = c.rng
	var x := x0
	var n := 0
	var yaw := 0.0 if facing > 0.0 else PI
	while x < x1 - 8.0:
		var placed := false
		for tries in range(6):
			var sz: Vector3 = OFFICE_SIZES[rng.randi() % OFFICE_SIZES.size()]
			if sz.z > max_depth or x + sz.x > x1: continue
			var cx := o.x + x + sz.x * 0.5
			var cz := o.y + zf - facing * sz.z * 0.5
			var rect := [cx - sz.x * 0.5, cz - sz.z * 0.5, cx + sz.x * 0.5, cz + sz.z * 0.5]
			if not _free(occ, rect, 2.5): continue
			_office(c, Vector2(cx, cz), sz.x, sz.z, sz.y + rng.randf_range(-2.0, 6.0), yaw, OFFICE_TINTS[rng.randi() % OFFICE_TINTS.size()])
			occ.append([rect[0] - 2.0, rect[1] - 2.0, rect[2] + 2.0, rect[3] + 2.0])
			x += sz.x + 4.0
			n += 1
			placed = true
			break
		if not placed: x += 4.0
	return n

# ------------------------------------------------------------------ the carnival in the fountain plaza

const PZ := "res://assets/plaza/"

## Rides, stalls, benches and balloons round the fountain. The Ferris wheel turns (the model's own animation), the pirate ship
## swings (its boat, seats and flag are moved as one about the top bar), the carts and stalls face the fountain, and every
## ride and stall is solid. Positions are relative to the plaza block's centre o.
static func _carnival(c: Dictionary, o: Vector2) -> void:
	var w: World = c.w
	for it in [["hotdog", "new_york_hot_dog_cart", 1.0], ["icecream", "ice_cream_cart", 0.0085], ["mexice", "mexican_ice_cream_cart", 0.5],
			["lumpia", "gerobak_lumpia", 0.0055], ["kiosk", "simple_90s_kiosk", 0.9], ["lemon", "updated_lemonade_stand", 1.4],
			["bench", "park_bench", 0.0135], ["stalls", "side_stalls", 0.5], ["bumper", "lunapark_-_bumper_cars", 1.0],
			["balloons", "air_balloons", 1.2]]:
		_spec(it[0], PZ + String(it[1]) + ".glb", float(it[2]))
	# stalls facing the fountain (the model's front is its +z side)
	var f0 := o
	var stalls: Array = [["hotdog", Vector2(40, -6)], ["icecream", Vector2(-6, 42)], ["mexice", Vector2(-40, 8)], ["lumpia", Vector2(-30, -32)],
		["kiosk", Vector2(2, -44)], ["lemon", Vector2(32, -30)], ["hotdog", Vector2(-44, 36)], ["lemon", Vector2(38, 34)]]
	for st in stalls:
		var p := o + (st[1] as Vector2)
		var face := f0 - p
		_put(c, st[0], p, atan2(face.x, face.y), true)
	# benches in a ring round the basin, backs to the water... facing out to the stalls
	for k in range(8):
		var a := TAU * (float(k) + 0.5) / 8.0
		var p2 := o + Vector2(cos(a), sin(a)) * 15.0
		var out := Vector2(cos(a), sin(a))
		_put(c, "bench", p2, atan2(out.x, out.y), true)
	# two rows of side stalls on the south side, facing the fountain
	_put(c, "stalls", o + Vector2(-38, 72), PI, true)
	_put(c, "stalls", o + Vector2(38, 72), PI, true)
	# balloon clusters tied near the paths
	for bp in [Vector2(-72, 0), Vector2(72, -8), Vector2(12, 78), Vector2(-14, -70)]:
		_put(c, "balloons", o + bp, 0.0, false)
	# bumper cars
	_put(c, "bumper", o + Vector2(54, -56), 0.0, true, true)
	_ferris_wheel(c, o + Vector2(-56, -52))
	_pirate_ship(c, o + Vector2(58, 34))
	# four stadium floodlights, one at each corner of the fair, lamps turned in over the rides
	for cn in [Vector2(-80, -80), Vector2(80, -80), Vector2(80, 80), Vector2(-80, 80)]:
		_stadium_light(c, o + cn, o)

## A floodlight tower (the model's own pole and lamp bank, scaled up). The lamp discs glow at night, and a real spotlight sits in
## front of each lamp pair, so the beams come from the lamps themselves.
static func _stadium_light(c: Dictionary, at: Vector2, aim: Vector2) -> void:
	floodlight(c.w, c.body, BASE_H, at, aim, 2.4)

## Public version: any world, any body for the solid pole, any ground height and scale.
static func floodlight(w: World, body: StaticBody3D, gy: float, at: Vector2, aim: Vector2, sc: float, spot_count := 4) -> void:
	var inst := (load(T + "low_poly_reflector.glb") as PackedScene).instantiate() as Node3D
	var holder := Node3D.new()
	holder.position = Vector3(at.x, gy, at.y)
	var dir := aim - at
	holder.rotation.y = atan2(dir.x, dir.y)            # the lamps face the model's +z
	inst.scale = Vector3.ONE * sc
	inst.position = Vector3(0.1 * sc, 0.0, 0.0)          # the pole stands slightly off the model's origin
	holder.add_child(inst)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		CityLights.apply((mi as MeshInstance3D).mesh, "emissive", 3.0)
	w.static_root.add_child(holder)
	CoastProps._box(body, Vector3(0.9, 8.0 * sc, 0.9), Vector3(at.x, gy + 4.0 * sc, at.y), holder.rotation.y)
	for row in ([7.55, 6.75] if spot_count >= 4 else [7.15]):
		for sx in [-0.4, 0.4]:
			var sl := SpotLight3D.new()
			sl.position = Vector3(sx * sc, row * sc, 0.85 * sc)
			sl.rotation = Vector3(-0.62, PI, 0.0)
			sl.spot_range = 40.0 * sc
			sl.spot_angle = 48.0
			sl.spot_attenuation = 0.7
			sl.light_color = Color(1.0, 0.96, 0.88)
			sl.shadow_enabled = false
			holder.add_child(sl)
			CityLights.register_light(sl, 16.0 if spot_count >= 4 else 22.0)

## Floodlights at both train stations and along the airport apron.
static func extra_floodlights(w: World) -> void:
	var body := StaticBody3D.new()
	body.name = "Floodlights"
	body.collision_layer = 1
	w.static_root.add_child(body)
	for i in range(2):
		if Rail.station_dir[i] == Vector2.ZERO: continue
		var a := Rail.at(Rail.station_s[i] + Rail.PLATFORM_Z)
		var p: Vector2 = a[0]
		var d: Vector2 = a[1]
		var sd: Vector2 = Rail.station_dir[i]
		var gy := maxf(CityData.height_at(p.x, p.y), 0.0)
		for k in [-1.0, 1.0]:
			var at: Vector2 = p + d * (34.0 * k) + sd * 34.0       # clear of the platform, the shelters and the station roof
			floodlight(w, body, gy, at, p, 2.0)
	for x in [765.0, 835.0, 915.0, 1000.0]:
		var gy2 := maxf(CityData.height_at(x, -896.0), 0.0)
		floodlight(w, body, gy2 + 0.12, Vector2(x, -896.0), Vector2(x, -950.0), 2.6)

static func _ferris_wheel(c: Dictionary, at: Vector2, sc := 0.62, base := BASE_H, yaw := 0.0) -> void:
	var w: World = c.w
	var holder := Node3D.new()
	# the model's origin is not its ground: its lowest bone sits 23.85 m above the origin, so lower it by that much
	holder.position = Vector3(at.x, base - 23.85 * sc, at.y)
	holder.rotation.y = yaw
	holder.scale = Vector3.ONE * sc
	w.static_root.add_child(holder)
	var inst := (load(PZ + "ferris_wheel.glb") as PackedScene).instantiate() as Node3D
	holder.add_child(inst)
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		var a := ap as AnimationPlayer
		var nm := a.get_animation_list()[0]
		a.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
		a.speed_scale = 0.7 * 0.62 / sc
		a.play(nm)
	# solid: the base and the two A-frames
	var k := sc / 0.62
	var rot := Basis(Vector3.UP, yaw)
	CoastProps._box(c.body, Vector3(9.0 * k, 3.0, 24.0 * k), Vector3(at.x, base + 1.5, at.y), yaw)
	for sz in [-1.0, 1.0]:
		var off := rot * Vector3(0.0, 0.0, sz * 7.0 * k)
		CoastProps._box(c.body, Vector3(1.6 * k, 24.0 * k, 1.6 * k), Vector3(at.x + off.x, base + 12.0 * k, at.y + off.z), yaw)

static func _pirate_ship(c: Dictionary, at: Vector2) -> void:
	var w: World = c.w
	var sc := 1.0
	var parts := CoastProps._parts(PZ + "pirate_ship.glb")
	var box := AABB()
	var first := true
	for p in parts:
		box = p.aabb if first else box.merge(p.aabb)
		first = false
	var holder := Node3D.new()
	holder.position = Vector3(at.x, BASE_H, at.y)
	holder.scale = Vector3.ONE * sc
	w.static_root.add_child(holder)
	var inst := (load(PZ + "pirate_ship.glb") as PackedScene).instantiate() as Node3D
	inst.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)       # stand it on the ground, centred
	holder.add_child(inst)
	var top := box.size.y
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, top - 0.6, 0.0)
	holder.add_child(pivot)
	for nm in ["Boat_13", "Seat_Divider_10", "Post_11", "Flag_12", "Flagpole_14"]:
		var n := inst.find_child(nm, true, false) as Node3D
		if n != null: n.reparent(pivot, true)
	var tw := pivot.create_tween().set_loops()
	tw.tween_property(pivot, "rotation:z", 0.62, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pivot, "rotation:z", -0.62, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# solid: the two legs and the base
	CoastProps._box(c.body, Vector3(box.size.x * 0.9, 1.0, box.size.z + 1.0), Vector3(at.x, BASE_H + 0.5, at.y))
	for sx in [-1.0, 1.0]:
		CoastProps._box(c.body, Vector3(1.2, top, box.size.z), Vector3(at.x + sx * box.size.x * 0.3, BASE_H + top * 0.5, at.y))

static func _street_items(c: Dictionary) -> void:
	var w: World = c.w
	var tl := Renowood._baked(T + "low_poly__game_ready_traffic_light.glb", 1.0, [], true, "", 0.65)
	CityLights.apply(tl.mesh, "names", 1.0)
	var info := _foot_and_arm(T + "low_poly__game_ready_traffic_light.glb", 0.65)
	var foot_off: Vector2 = info.foot
	var arm: Vector2 = info.arm
	var a0 := atan2(arm.x, arm.y)
	var xfs: Array = []
	for ji in range(1, 4):
		for jj in range(1, 4):
			var jc := Vector2((float(BX[ji - 1]) + float(BX[ji])) * 0.5, (float(BX[jj - 1]) + float(BX[jj])) * 0.5)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var corner := jc + Vector2(sx * 7.3, sz * 7.3)
					var to_j := (jc - corner).normalized()
					var yaw := atan2(to_j.x, to_j.y) - a0
					var rot := Basis(Vector3.UP, yaw)
					var fo := rot * Vector3(foot_off.x, 0.0, foot_off.y)
					xfs.append(Transform3D(rot, Vector3(corner.x - fo.x, BASE_H, corner.y - fo.z)))
					CoastProps._box(c.body, Vector3(0.5, 4.0, 0.5), Vector3(corner.x, BASE_H + 2.0, corner.y))
	Renowood._emit_blocks(w, tl.mesh, xfs, 200.0, 420.0)
	var rng: RandomNumberGenerator = c.rng
	for k in range(14):
		var bi: int = rng.randi() % 4
		var bj: int = rng.randi() % 4
		if ROLES[bj][bi] == "h": continue
		var o := Vector2(BX[bi], BX[bj])
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var p := o + Vector2(rng.randf_range(-60.0, 60.0), side * (EDGE - PAVE * 0.5))
		_put(c, "phone" if k % 3 != 0 else "cart", p, 0.0 if side < 0.0 else PI, true)

static func _foot_and_arm(path: String, scale: float) -> Dictionary:
	var parts := CoastProps._parts(path)
	var box := AABB()
	var first := true
	for p in parts:
		box = p.aabb if first else box.merge(p.aabb)
		first = false
	var low := Vector2.ZERO
	var nlow := 0
	for p in parts:
		for v in (p.mesh as Mesh).get_faces():
			var wp: Vector3 = (p.xf as Transform3D) * v
			if wp.y < box.position.y + box.size.y * 0.02:
				low += Vector2(wp.x, wp.z)
				nlow += 1
	var foot := low / maxf(nlow, 1)
	var centre := Vector2(box.get_center().x, box.get_center().z)
	var arm := (centre - foot)
	if arm.length() < 0.01: arm = Vector2(0, 1)
	return {"foot": (foot - centre) * scale, "arm": arm.normalized()}

# ------------------------------------------------------------------ the town

static func build(w: World) -> void:
	var t0 := Time.get_ticks_msec()
	_specs()
	var body := StaticBody3D.new()
	body.name = "CityBuildings"
	body.collision_layer = 1
	w.static_root.add_child(body)
	RoadKit._mats(w)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8128
	var c := {"w": w, "body": body, "rng": rng, "batch": {},
		"conc": w._mat("res://assets/town/lot_concrete.png", 0.1667, Color(0.9, 0.9, 0.9)),
		"pave": w._mat("res://assets/town/paving_tiles.png", 0.25, Color(1.06, 1.0, 0.9)),
		"asphalt": RoadKit._plain_mat,
		"lawn": w._mat("res://assets/textures/y2k_grass.png", 0.2, Color(0.8, 1.0, 0.65))}
	var nb := 0
	var tower_blocks: Array = []
	for bj in range(4):
		for bi in range(4):
			var role: String = ROLES[bj][bi]
			if role == "h": continue
			var o := Vector2(BX[bi], BX[bj])
			match role:
				"res":
					_block_base(c, o, "cross")
					nb += _fill_half(c, o, -1.0, true) + _fill_half(c, o, 1.0, true)
				"tower_a", "tower_b", "tower_c":
					# the tower cluster round the middle junction: towers in the half nearest it, ordinary rows in the far half
					var near := 1.0 if bj <= 1 else -1.0
					tower_blocks.append([o, near])
					var lots: Array = {"tower_a": [[-84.0, -30.0]], "tower_b": [[48.0, 86.0]], "tower_c": [[-84.0, -30.0], [12.0, 84.0]]}[role]
					var cuts: Dictionary = {int(near): lots}
					if role == "tower_a":
						cuts[-1] = [[-34.0, -21.0]]
					_block_base(c, o, "ew", cuts)
					_slab(c, o.x - EDGE + PAVE, o.y + (LANE_HALF + LANE_PAVE if near > 0.0 else -EDGE + PAVE), o.x + EDGE - PAVE, o.y + (EDGE - PAVE if near > 0.0 else -LANE_HALF - LANE_PAVE), BAND_H - 0.01, c.pave, false)
					if role == "tower_a":
						# the gun shop stands in the far half of this block, on the inner row facing the lane
						var gx0 := o.x - 48.0
						var gz1 := o.y - (LANE_LINE if near > 0.0 else -LANE_LINE)
						reserved.append(Rect2(gx0 - 3.0, gz1 - GunShop.D - GunShop.BACK_D - 3.0, GunShop.W + GunShop.LOT_W + 6.0, GunShop.D + GunShop.BACK_D + 6.0))
						GunShop.build(c.w, c.body, gx0, gz1, BASE_H)
					nb += _fill_half(c, o, -near, false)
					var zt := near * 48.0
					match role:
						"tower_a":
							_put(c, "atl", o + Vector2(46.0, zt), 0.0, true, true)
							_put(c, "hirise", o + Vector2(-8.0, near * 54.0), 0.0, true, true)
						"tower_b":
							_put(c, "wtc", o + Vector2(-46.0, zt), 0.0, true, true)
							_put(c, "atl_l", o + Vector2(20.0, zt), 0.0, true, true)
						"tower_c":
							_put(c, "boc", o + Vector2(46.0, zt), 0.0, true, true)
							_put(c, "hirise", o + Vector2(-8.0, near * 54.0), PI, true, true)
					var zl := (LANE_HALF + LANE_PAVE + 0.6) if near > 0.0 else -(LANE_HALF + LANE_PAVE + 0.6 + 17.0)
					for lt in lots:
						_lot(c, o, lt[0], zl, lt[1], zl + 17.0, "fumi", 0, 0.336)
				"services":
					# fire station (north half) and police station (south half), each with its own parking bays
					var cuts := {-1: [[-8.0, 72.0]], 1: [[-8.0, 72.0]]}
					_block_base(c, o, "ew", cuts)
					nb += _service(c, o, -1.0, "fire", -48.0, -8.0, 72.0, "fumi")
					nb += _service(c, o, 1.0, "police", -44.0, -8.0, 72.0, "fumi")
					nb += _fill_gaps(c, o, 1.0, ["ait", "ait", "york", "bordeaux", "asian", "soviet"])
				"hospital":
					var cuts2 := {-1: [[10.0, 84.0]]}
					_block_base(c, o, "ew", cuts2)
					nb += _service(c, o, -1.0, "hospital", -36.0, 10.0, 84.0, "fumi", 3)
					nb += _fill_half(c, o, 1.0, true)
				"plaza":
					_paved_full(c, o)
					_fountain_plaza(c, o + Vector2(0.0, 0.0))
					# trees only where no ride or stall stands (the Ferris wheel, bumper cars and side stalls had trees growing into them)
					_trees(c, [o + Vector2(-62, 50), o + Vector2(68, 56), o + Vector2(24, -70)])
					_put(c, "cart", o + Vector2(20.0, 22.0), 0.4, true)
					_put(c, "cart", o + Vector2(-22.0, -20.0), 3.5, true)
					_carnival(c, o)
	if OFFICES:
		# offices: wherever there is room in the tower blocks (round the towers and their car parks), and along the north and south
		# edges of the H tower's block, so the whole middle of the town is an office district
		var occ := _occupied()
		var n_off := 0
		for tb in tower_blocks:
			var to: Vector2 = tb[0]
			var tn: float = tb[1]
			n_off += _office_row(c, to, -OUTER_LINE, OUTER_LINE, tn * OUTER_LINE, tn, occ, 20.0)
			n_off += _office_row(c, to, -OUTER_LINE, OUTER_LINE, tn * LANE_LINE, -tn, occ, 20.0)
		var ho := Vector2(95.5, 95.5)
		occ.append([ho.x - 97.0, ho.y - 67.0, ho.x + 97.0, ho.y + 69.0])                  # the H towers and their platform
		occ.append([ho.x - 41.0, ho.y - 89.6, ho.x + 41.0, ho.y - 65.0])                  # the H tower's forecourt car park
		_slab(c, ho.x - EDGE, ho.y - EDGE - 0.01, ho.x + EDGE, ho.y - EDGE + PAVE, BAND_H, c.pave, false)
		_slab(c, ho.x - EDGE, ho.y + EDGE - PAVE, ho.x + EDGE, ho.y + EDGE + 0.01, BAND_H, c.pave, false)
		n_off += _office_row(c, ho, -OUTER_LINE, OUTER_LINE, -OUTER_LINE, -1.0, occ, 15.0)
		n_off += _office_row(c, ho, -OUTER_LINE, OUTER_LINE, OUTER_LINE, 1.0, occ, 13.0)
		print("city: %d offices" % n_off)
	_street_items(c)
	_street_trees(c)
	for key in c.batch:
		var sp: Dictionary = specs[key]
		var small: bool = key in ["tuft", "tallg", "fern", "flower"]
		Renowood._emit_blocks(w, sp.mesh, c.batch[key], 200.0, 140.0 if small else (300.0 if key == "oak" else 520.0))
	if "--dumpcity" in OS.get_cmdline_user_args():
		var f := FileAccess.open("/tmp/city_layout.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(layout))
		f.close()
	print("city: %d buildings in the blocks, plus towers, services and plaza (%d ms)" % [nb, Time.get_ticks_msec() - t0])
