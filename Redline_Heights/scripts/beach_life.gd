class_name BeachLife
extends RefCounted
## Everything alive or washed up on Redline Island's beaches: sea animals that stay in their own depth of water, birds, crabs and
## pelicans, palms and dune plants on the dune line, shells, driftwood and rocks along the tide line. Everything with a body is solid.

const LIFE := "res://assets/beach/life/"
const PH := "res://assets/beach/ph/"
const CTR := Vector2(200.0, 2200.0)

static var rng := RandomNumberGenerator.new()
static var body: StaticBody3D
static var placed: Array = []             # [Vector2, radius] of everything solid, so nothing lands inside anything else
static var report := {}
static var put_log: Array = []            # [{node, kind}] every ground-standing prop placed by _put, for the floating check

# ------------------------------------------------------------------ helpers

static var _bounds_cache := {}

## Bounds of a model from its own node transforms (independent of the scene tree): {size, bottom (lowest y), centre}.
static func _bounds(path: String) -> Dictionary:
	if _bounds_cache.has(path): return _bounds_cache[path]
	var n := _load(path)
	var out := {"size": Vector3.ONE, "bottom": 0.0, "centre": Vector3.ZERO}
	if n != null:
		var bb := AABB()
		var first := true
		var stack: Array = [[n, Transform3D.IDENTITY]]
		while not stack.is_empty():
			var it: Array = stack.pop_back()
			var nd: Node = it[0]
			var xf: Transform3D = it[1]
			if nd is Node3D and nd != n: xf = xf * (nd as Node3D).transform
			if nd is MeshInstance3D and (nd as MeshInstance3D).mesh != null:
				var b: AABB = xf * (nd as MeshInstance3D).mesh.get_aabb()
				bb = b if first else bb.merge(b)
				first = false
			for ch in nd.get_children(): stack.append([ch, xf])
		if not first: out = {"size": bb.size, "bottom": bb.position.y, "centre": bb.get_center()}
		n.free()
	_bounds_cache[path] = out
	return out

## The scale that makes the model `target` metres along its longest side (`by` = "long") or tall (`by` = "tall").
static func _scale_for(path: String, target: float, by := "long") -> float:
	var sz: Vector3 = _bounds(path).size
	var dim := sz.y if by == "tall" else maxf(sz.x, maxf(sz.y, sz.z))
	return target / maxf(dim, 0.0001)

static func _load(path: String) -> Node3D:
	var ps := load(path) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null

static func _depth(p: Vector2) -> float:
	return -Coast.inland(p.x, p.y)

static func _near_bridge(p: Vector2) -> bool:
	return absf(p.x) < 48.0 and p.y < 2000.0

static func _free(p: Vector2, r: float) -> bool:
	for q in placed:
		if (q[0] as Vector2).distance_to(p) < float(q[1]) + r: return false
	return true

## A random point on the island whose distance inland is in [d0, d1], clear of the bridge, ponds and other things.
static func _spot(d0: float, d1: float, r: float) -> Variant:
	for i in range(80):
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.5, 1.45)
		var p := CTR + Vector2(cos(a) * 800.0, sin(a) * 480.0) * rr
		var d := Coast.inland(p.x, p.y)
		if d < d0 or d > d1: continue
		if _near_bridge(p) or Coast.near_pool(p.x, p.y, 4.0): continue
		if absf(p.x - -75.0) < 14.0 and p.y > 2400.0: continue                   # the metro stairs
		if not _free(p, r): continue
		return p
	return null

static func _ground(p: Vector2) -> float:
	return Coast.height_at(p.x, p.y)

## Bounds of everything under `n` in the space of n's parent, using every node's real transform (so a model's own built-in rotation /
## scale count): the AABB of its meshes.
static func _tree_bounds(n: Node3D) -> AABB:
	var bb := AABB()
	var first := true
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var nd: Node = it[0]
		var xf: Transform3D = it[1]
		if nd is Node3D: xf = xf * (nd as Node3D).transform
		if nd is MeshInstance3D and (nd as MeshInstance3D).mesh != null:
			var b: AABB = xf * (nd as MeshInstance3D).mesh.get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		for ch in nd.get_children(): stack.append([ch, xf])
	return bb

## Loads a model and wraps it in a holder: the model keeps its own transform, is moved so that its footprint is centred on the holder's
## origin and its lowest point (or its middle when `centre_y`) is at height 0, and the holder is scaled so the model is `target` metres
## along its longest side (`by` = "long") or tall (`by` = "tall"). `prefix` keeps only the mesh parts whose name starts with it.
static func _fit(path: String, target: float, by := "long", prefix := "", centre_y := false) -> Node3D:
	var n := _load(path)
	if n == null: return null
	if prefix != "":
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			if not String(mi.name).begins_with(prefix): mi.free()
	var bb := _tree_bounds(n)
	n.position -= Vector3(bb.get_center().x, bb.get_center().y if centre_y else bb.position.y, bb.get_center().z)
	var dim := bb.size.y if by == "tall" else maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * (target / maxf(dim, 0.0001))
	holder.add_child(n)
	return holder

## Stands a model on the ground at p: footprint centred there, its lowest point on the terrain (minus `sink`), turned by `yaw`, `target`
## metres long / tall, hidden beyond `vis` metres, optionally solid ("box" = a box of the given size, "convex" = a convex hull of each mesh).
static func _put(w: World, path: String, p: Vector2, yaw: float, target: float, vis: float, solid := "", box := Vector3.ZERO, sink := 0.0, by := "long", prefix := "") -> Node3D:
	var n := _fit(path, target, by, prefix)
	if n == null: return null
	n.position = Vector3(p.x, _ground(p) - sink, p.y)
	n.rotation.y = yaw
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = vis
		(mi as GeometryInstance3D).visibility_range_end_margin = vis * 0.1
	w.static_root.add_child(n)
	put_log.append({"node": n, "kind": path.get_file()})
	if solid == "box":
		CoastProps._box(body, box, Vector3(p.x, _ground(p) - sink + box.y * 0.5, p.y), yaw)
	elif solid == "convex":
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null: continue
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			m.add_child(sb)
			var cs := CollisionShape3D.new()
			cs.shape = m.mesh.create_convex_shape(true, true)
			sb.add_child(cs)
	return n

# ------------------------------------------------------------------ sea animals

## One swimming animal: a loop of radius `rad` in water whose distance from the shore is within [d0, d1].
static func _swimmer(w: World, path: String, length: float, yaw0: float, d0: float, d1: float, rad: float, spd: float, y: float, phase: float) -> bool:
	var ok := func(q: Vector2) -> bool:
		var d := _depth(q)
		return d >= d0 and d <= d1 and not _near_bridge(q) and Coast.is_water(q.x, q.y)
	for attempt in range(300):
		var a := rng.randf() * TAU
		var c := Vector2.ZERO
		var found := false
		for rr in range(160, 60, -1):                         # march in from open sea until the water is at the right distance
			var q := CTR + Vector2(cos(a) * 800.0, sin(a) * 480.0) * (float(rr) / 100.0)
			if _depth(q) <= (d0 + d1) * 0.5 and Coast.inland(q.x, q.y) < 0.0:
				c = q
				found = true
				break
		if not found: continue
		var loop: Array[Vector2] = []
		for k in range(8):
			var an := TAU * k / 8.0
			loop.append(c + Vector2(cos(an) * rad, sin(an) * rad * 0.7))
		var n := _fit(path, length, "long", "", true)
		if n == null: return false
		SeaCreature.play_loop(n, "", 1.0)
		var sc := SeaCreature.new()
		if sc.setup(n, loop, spd, phase, y, yaw0, ok):
			w.static_root.add_child(sc)
			SeaCreature.play_loop(n, "", 1.0)
			sc.set_meta("depth_band", Vector2(d0, d1))
			report["swim"] = int(report.get("swim", 0)) + 1
			return true
		sc.free()
	return false

static func _sea(w: World) -> void:
	# [file, length in metres, forward-yaw, shore distance min, max, loop radius, speed, y, count]
	var defs := [
		["game-ready_dolphin_swimming.glb", 2.6, 0.0, 22.0, 75.0, 34.0, 5.0, -0.45, 6],
		["model_46a_-_subadult_green_sea_turtle.glb", 1.2, 0.0, 6.0, 20.0, 12.0, 1.0, -0.5, 5],
		["manta_ray_birostris_animated.glb", 3.2, 0.0, 18.0, 55.0, 24.0, 2.0, -0.8, 3],
		["great_hammerhead.glb", 3.2, PI * 0.5, 40.0, 110.0, 40.0, 3.0, -0.6, 3],
		["blue_whale_-_textured.glb", 14.0, 0.0, 120.0, 260.0, 60.0, 2.0, -1.4, 2]]
	for d in defs:
		var path := LIFE + String(d[0])
		for k in range(int(d[8])):
			var ok := _swimmer(w, path, float(d[1]), float(d[2]), float(d[3]), float(d[4]), float(d[5]), float(d[6]), float(d[7]), float(k) / float(d[8]) + rng.randf() * 0.2)
			if not ok: print("beach life: could not place ", d[0])
			elif String(d[0]).begins_with("game-ready_dolphin"): (w.static_root.get_child(w.static_root.get_child_count() - 1) as SeaCreature).leap = true

# ------------------------------------------------------------------ horses

## Horses walking slowly along the sand in loops (the supplied walk cycle), each with a solid body that moves with it.
static func _horses(w: World) -> void:
	for k in range(3):
		var c = _spot(26.0, 52.0, 18.0)
		if c == null: continue
		var cc: Vector2 = c
		var loop: Array[Vector2] = []
		for j in range(8):
			var an := TAU * j / 8.0
			loop.append(cc + Vector2(cos(an) * 13.0, sin(an) * 9.0))
		var n := _fit(LIFE + "horse_riggedgame_ready.glb", 2.3)
		if n == null: continue
		SeaCreature.play_loop(n, "", 1.0)
		var sc := SeaCreature.new()
		var ok := func(q: Vector2) -> bool:
			var d := Coast.inland(q.x, q.y)
			return d > 14.0 and d < 80.0 and not _near_bridge(q) and not Coast.near_pool(q.x, q.y, 3.0)
		if sc.setup(n, loop, 1.4, float(k) / 3.0, 0.0, 0.0, ok):
			sc.ground = true
			sc.bob = 0.0
			sc.tilt = 0.0
			w.static_root.add_child(sc)
			var ab := AnimatableBody3D.new()
			ab.collision_layer = 1
			ab.sync_to_physics = false
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.7, 1.7, 2.0)
			cs.shape = bs
			cs.position = Vector3(0.0, 0.85, 0.0)
			ab.add_child(cs)
			n.add_child(ab)
			ab.position = Vector3.ZERO
			report["horses"] = int(report.get("horses", 0)) + 1
		else:
			sc.free()

# ------------------------------------------------------------------ birds, crabs, pelicans

static func _birds(w: World) -> void:
	# flocks of four wheeling slowly over the beach (the animation carries the wing beats), and single gulls circling along the shore
	for k in range(4):
		var p = _spot(30.0, 70.0, 2.0)
		if p == null: continue
		var n := _fit(LIFE + "seagulls_animated.glb", 7.0, "long", "", true)
		if n == null: continue
		SeaCreature.play_loop(n)
		n.position = Vector3(p.x, 24.0 + rng.randf() * 10.0, p.y)
		w.static_root.add_child(n)
		var tw := n.create_tween().set_loops()
		tw.tween_property(n, "rotation:y", TAU, 40.0 + rng.randf() * 20.0).from(0.0)
		report["flocks"] = int(report.get("flocks", 0)) + 1
	for k in range(6):
		var a := rng.randf() * TAU
		var c := CTR + Vector2(cos(a) * 780.0, sin(a) * 470.0)
		var loop: Array[Vector2] = []
		for j in range(8):
			var an := TAU * j / 8.0
			loop.append(c + Vector2(cos(an) * 45.0, sin(an) * 32.0))
		var n := _fit(LIFE + "seagull.glb", 1.2, "long", "", true)
		if n == null: continue
		SeaCreature.play_loop(n)
		var sc := SeaCreature.new()
		var ok := func(q: Vector2) -> bool: return not _near_bridge(q)
		if sc.setup(n, loop, 7.0, float(k) / 6.0, 20.0 + rng.randf() * 12.0, PI * 0.5, ok):
			sc.bob = 0.8
			sc.tilt = 0.12
			w.static_root.add_child(sc)
			report["gulls"] = int(report.get("gulls", 0)) + 1
		else:
			sc.free()

## Crabs on the wet sand, scuttling a short way along the water's edge.
static func _crabs(w: World) -> void:
	for k in range(14):
		var p = _spot(4.0, 11.0, 3.0)
		if p == null: continue
		var n := _fit(LIFE + "dancing_crab_-_uca_mjoebergi.glb", 0.3)
		if n == null: continue
		SeaCreature.play_loop(n)
		var holder := Node3D.new()
		holder.position = Vector3(p.x, _ground(p), p.y)
		holder.rotation.y = rng.randf() * TAU
		var sway := Node3D.new()
		sway.add_child(n)
		holder.add_child(sway)
		w.static_root.add_child(holder)
		put_log.append({"node": holder, "kind": "crab"})
		placed.append([p, 1.2])
		var tw := sway.create_tween().set_loops()
		tw.tween_property(sway, "rotation:y", 0.7, 2.0 + rng.randf()).from(-0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(sway, "rotation:y", -0.7, 2.0 + rng.randf()).set_trans(Tween.TRANS_SINE)
		report["crabs"] = int(report.get("crabs", 0)) + 1

## Pelicans standing on the sand (idle clips), solid.
static func _pelicans(w: World) -> void:
	for k in range(11):
		var p = _spot(8.0, 28.0, 2.5)
		if p == null: continue
		var n := _put(w, LIFE + "pelican_-_animated_low_poly.glb", p, rng.randf() * TAU, 1.5, 300.0, "box", Vector3(0.5, 1.0, 0.8))
		if n == null: continue
		SeaCreature.play_loop(n, "idle_A" if k % 2 == 0 else "idle_B")
		placed.append([p, 1.5])
		report["pelicans"] = int(report.get("pelicans", 0)) + 1

# ------------------------------------------------------------------ plants and washed-up things

static func _palms(w: World) -> void:
	var n_c := 0
	for k in range(60):
		var p = _spot(30.0, 80.0, 4.0)
		if p == null: continue
		var which := k % 4
		var yaw := rng.randf() * TAU
		if which < 2:
			var n := _put(w, LIFE + "coconut_palm.glb", p, yaw, rng.randf_range(8.0, 11.0), 700.0, "box", Vector3(0.7, 4.5, 0.7), 0.0, "tall")
			if n == null: continue
		else:
			var n2 := _put(w, LIFE + "palm_tree_pack_lowpoly.glb", p, yaw, rng.randf_range(7.5, 10.5), 700.0, "box", Vector3(0.7, 4.0, 0.7), 0.0, "tall", ["PALMLOW_", "PALMLOW2_", "PALMLOW3_"][rng.randi() % 3])
			if n2 == null: continue
		placed.append([p, 3.5])
		n_c += 1
	report["palms"] = n_c

static func _dune_plants(w: World) -> void:
	var n := 0
	for k in range(70):
		var centre = _spot(38.0, 80.0, 2.0)
		if centre == null: continue
		var cluster := 3 + rng.randi() % 4
		for j in range(cluster):
			var p: Vector2 = (centre as Vector2) + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
			var d := Coast.inland(p.x, p.y)
			if d < 28.0 or d > 88.0 or Coast.near_pool(p.x, p.y, 3.0): continue
			var fern := (j % 3 == 0)
			var pp := PH + ("fern_02/fern_02.gltf" if fern else "grass_medium_02/grass_medium_02.gltf")
			_put(w, pp, p, rng.randf() * TAU, rng.randf_range(0.7, 1.1) if fern else rng.randf_range(0.5, 0.9), 140.0)
			n += 1
	report["plants"] = n

static func _tide_line(w: World) -> void:
	var shells := 0
	for k in range(60):
		var p = _spot(4.5, 26.0, 1.0)
		if p == null: continue
		var path := (PH + "lambis_shell/lambis_shell.gltf") if k % 2 == 0 else (LIFE + "seashell.glb")
		_put(w, path, p, rng.randf() * TAU, rng.randf_range(0.14, 0.26), 90.0)
		shells += 1
	report["shells"] = shells
	var wood := 0
	for k in range(12):
		var p = _spot(7.0, 26.0, 3.0)
		if p == null: continue
		var path := (PH + "dead_tree_trunk_02/dead_tree_trunk_02.gltf") if k % 2 == 0 else (LIFE + "beachwood0002.glb")
		var n := _put(w, path, p, rng.randf() * TAU, rng.randf_range(2.2, 3.6), 400.0, "convex", Vector3.ZERO, 0.05)
		if n == null: continue
		placed.append([p, 2.2])
		wood += 1
	report["driftwood"] = wood

static func build(w: World) -> void:
	rng.seed = 2468
	placed.clear()
	report.clear()
	put_log.clear()
	body = StaticBody3D.new()
	body.name = "BeachLifeBody"
	body.collision_layer = 1
	w.static_root.add_child(body)
	_sea(w)
	_birds(w)
	_tide_line(w)
	_palms(w)
	_dune_plants(w)
	_pelicans(w)
	_crabs(w)
	# (horses removed: the _horses() function is kept but not called)
	print("beach life: ", report)
