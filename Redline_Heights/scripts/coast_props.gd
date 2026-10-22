class_name CoastProps
extends RefCounted
## Things on the beaches: palm trees, beach umbrellas and loungers, lifeguard towers, and the bridge's pillars and parapets.
## The models are the supplied Sketchfab ones in assets/coast.

const PALMS := "res://assets/coast/palm_trees.glb"
const COCONUT := "res://assets/coast/coconut_palm.glb"
const KIT := "res://assets/coast/beach_kit.glb"
const TOWER := "res://assets/coast/lifeguard_tower.glb"

static func _parts(path: String) -> Array:
	var out: Array = []
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	_walk(inst, Transform3D.IDENTITY, out)
	inst.free()
	return out

static func _walk(n: Node, xf: Transform3D, out: Array) -> void:
	var t := xf
	if n is Node3D: t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m := n as MeshInstance3D
		out.append({"name": String(n.name), "mesh": m.mesh, "xf": t, "aabb": t * m.mesh.get_aabb()})
	for c in n.get_children(): _walk(c, t, out)

## Group of parts re-centred so its foot sits at the origin: [{mesh, xf}], plus the group's height and radius.
static func _group(parts: Array, pick: Callable) -> Dictionary:
	var sel: Array = []
	var box := AABB()
	var first := true
	for p in parts:
		if pick.call(String(p.name)):
			sel.append(p)
			box = p.aabb if first else box.merge(p.aabb)
			first = false
	var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var out: Array = []
	for p in sel:
		out.append({"mesh": p.mesh, "xf": Transform3D(Basis.IDENTITY, -foot) * (p.xf as Transform3D)})
	return {"parts": out, "h": box.size.y, "r": maxf(box.size.x, box.size.z) * 0.5}

class Batch:
	var mesh: Mesh
	var xfs: Array = []

static func _flush(w: World, batches: Dictionary, shadows := false) -> void:
	for k in batches:
		var b: Batch = batches[k]
		if b.xfs.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b.mesh
		mm.instance_count = b.xfs.size()
		for i in range(b.xfs.size()): mm.set_instance_transform(i, b.xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.static_root.add_child(mmi)

static func _place(batches: Dictionary, key: String, grp: Dictionary, base: Transform3D) -> void:
	var i := 0
	for p in grp.parts:
		var k := "%s_%d" % [key, i]
		if not batches.has(k):
			var b := Batch.new()
			b.mesh = p.mesh
			batches[k] = b
		(batches[k] as Batch).xfs.append(base * (p.xf as Transform3D))
		i += 1

static func _box(body: StaticBody3D, size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	body.add_child(cs)

static func _hash(x: float, z: float, salt: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233 + salt * 37.719) * 43758.5453, 1.0)

static func build(w: World) -> void:
	var t0 := Time.get_ticks_msec()
	_bridge(w)
	var body := StaticBody3D.new()
	body.name = "BeachProps"
	body.collision_layer = 1
	w.static_root.add_child(body)
	var batches := {}
	# ---- palms
	var pp := _parts(PALMS)
	var types: Array = []
	for n in [2, 3, 4]:
		var tag := "_%d_" % n
		types.append(_group(pp, func(nm: String) -> bool: return nm.begins_with("Bark" + tag) or nm.begins_with("Leaf" + tag)))
	var cp := _parts(COCONUT)
	types.append(_group(cp, func(_nm: String) -> bool: return true))
	var palm_count := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for part in [[MAIN_BOX, 20.0], [ISL_BOX, 20.0]]:
		var bb: Rect2 = part[0]
		var step: float = part[1]
		var x := bb.position.x
		while x < bb.end.x:
			var z := bb.position.y
			while z < bb.end.y:
				var jx := x + (rng.randf() - 0.5) * step
				var jz := z + (rng.randf() - 0.5) * step
				var d := Coast.inland(jx, jz)
				if d > 20.0 and d < 78.0 and not _near_bridge(jx, jz):
					var cluster: float = Coast._n1.get_noise_2d(jx * 3.1, jz * 3.1)
					if rng.randf() < (0.34 if cluster > -0.15 else 0.07):
						var ti := rng.randi() % types.size()
						var g: Dictionary = types[ti]
						var target := rng.randf_range(6.5, 9.5)
						var s := target / maxf(g.h, 0.5)
						var yaw := rng.randf() * TAU
						var base := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s), Vector3(jx, Coast.height_at(jx, jz) - 0.05, jz))
						_place(batches, "palm%d" % ti, g, base)
						_box(body, Vector3(0.7, 4.0, 0.7), Vector3(jx, Coast.height_at(jx, jz) + 2.0, jz))
						palm_count += 1
				z += step
			x += step
	# ---- umbrellas, loungers, towels, balls
	var kp := _parts(KIT)
	var umb := _group(kp, func(nm: String) -> bool: return nm.begins_with("Beach umbrella"))
	var chair := _group(kp, func(nm: String) -> bool: return nm.begins_with("Beach chair"))
	var towel := _group(kp, func(nm: String) -> bool: return nm.begins_with("Beach towel"))
	var ball := _group(kp, func(nm: String) -> bool: return nm.begins_with("Beach ball"))
	var sets := 0
	for part in [[MAIN_BOX, 60.0], [ISL_BOX, 60.0]]:
		var bb2: Rect2 = part[0]
		var step2: float = part[1]
		var x2 := bb2.position.x
		while x2 < bb2.end.x:
			var z2 := bb2.position.y
			while z2 < bb2.end.y:
				var jx2 := x2 + (rng.randf() - 0.5) * step2
				var jz2 := z2 + (rng.randf() - 0.5) * step2
				var d2 := Coast.inland(jx2, jz2)
				if d2 > 30.0 and d2 < 52.0 and not _near_bridge(jx2, jz2) and rng.randf() < 0.16:
					# face the sea
					var e := 4.0
					var gx := Coast.inland(jx2 + e, jz2) - Coast.inland(jx2 - e, jz2)
					var gz := Coast.inland(jx2, jz2 + e) - Coast.inland(jx2, jz2 - e)
					var sea_yaw := atan2(-gx, -gz)
					var c := Vector3(jx2, Coast.height_at(jx2, jz2), jz2)
					var fwd := Vector3(sin(sea_yaw), 0, cos(sea_yaw))
					var side := Vector3(fwd.z, 0, -fwd.x)
					_place(batches, "umb", umb, Transform3D(Basis(Vector3.UP, sea_yaw), c))
					_box(body, Vector3(0.35, 3.0, 0.35), c + Vector3(0, 1.5, 0))
					for k in [-1.0, 1.0]:
						var cc: Vector3 = c + side * k * 1.5 - fwd * 0.4
						cc.y = Coast.height_at(cc.x, cc.z)
						_place(batches, "chair", chair, Transform3D(Basis(Vector3.UP, sea_yaw + PI), cc))
						_box(body, Vector3(0.9, 0.5, 1.7), cc + Vector3(0, 0.3, 0), sea_yaw)
					var tc: Vector3 = c + side * 3.4 + fwd * 0.6
					tc.y = Coast.height_at(tc.x, tc.z) + 0.02
					_place(batches, "towel", towel, Transform3D(Basis(Vector3.UP, sea_yaw + rng.randf_range(-0.3, 0.3)), tc))
					if rng.randf() < 0.4:
						var bc: Vector3 = c + side * -3.2 + fwd * 1.4
						bc.y = Coast.height_at(bc.x, bc.z) + 0.1
						_place(batches, "ball", ball, Transform3D(Basis(Vector3.UP, 0.0) * Basis.from_scale(Vector3.ONE * 0.35), bc))
					sets += 1
				z2 += step2
			x2 += step2
	# ---- lifeguard towers, one every ~600 m of shore
	var tp := _parts(TOWER)
	var tg := _group(tp, func(_nm: String) -> bool: return true)
	var towers: Array = []
	for part in [[MAIN_BOX, 100.0], [ISL_BOX, 100.0]]:
		var bb3: Rect2 = part[0]
		var step3: float = part[1]
		var x3 := bb3.position.x
		while x3 < bb3.end.x:
			var z3 := bb3.position.y
			while z3 < bb3.end.y:
				var d3 := Coast.inland(x3, z3)
				if d3 > 40.0 and d3 < 52.0 and not _near_bridge(x3, z3) and not ISL_BOX.has_point(Vector2(x3, z3)):
					var ok := true
					for o in towers:
						if (o as Vector2).distance_to(Vector2(x3, z3)) < 600.0: ok = false
					if ok: towers.append(Vector2(x3, z3))
				z3 += step3
			x3 += step3
	for tv in towers:
		var tpos: Vector2 = tv
		var e2 := 4.0
		var gx2 := Coast.inland(tpos.x + e2, tpos.y) - Coast.inland(tpos.x - e2, tpos.y)
		var gz2 := Coast.inland(tpos.x, tpos.y + e2) - Coast.inland(tpos.x, tpos.y - e2)
		var yaw2 := atan2(-gx2, -gz2)
		var s2 := 4.6 / maxf(tg.h, 0.1)
		var ty := Coast.height_at(tpos.x, tpos.y)
		_place(batches, "tower", tg, Transform3D(Basis(Vector3.UP, yaw2) * Basis.from_scale(Vector3.ONE * s2), Vector3(tpos.x, ty, tpos.y)))
		_box(body, Vector3(3.2, 4.6, 3.2), Vector3(tpos.x, ty + 2.3, tpos.y), yaw2)
	_flush(w, batches, true)
	print("coast props: %d palms, %d beach sets, %d lifeguard towers (%d ms)" % [palm_count, sets, towers.size(), Time.get_ticks_msec() - t0])

const MAIN_BOX := Rect2(-960.0, -1520.0, 2920.0, 2440.0)
const ISL_BOX := Rect2(-640.0, 1700.0, 1680.0, 1000.0)

static func _near_bridge(x: float, z: float) -> bool:
	if Coast.near_pool(x, z, 7.0): return true                # nothing is planted in a canal, pond or channel
	return z > 600.0 and z < 1900.0 and absf(x) < 40.0

const BRIDGE := "res://assets/bridge/modular_road_bridge.glb"
const BRIDGE_YAW := 44.8592           # the model is turned this much in its file
const BRIDGE_DECK := Vector3(18.4, 3282.24, -30.9)     # centre of the deck's top surface, in the model's aligned units
const BRIDGE_W := 3072.0              # footpath-to-footpath width in model units
const BRIDGE_L := 3989.0              # length of one span in model units
const BRIDGE_LIFT := 16.0             # how high the middle of the bridge stands above the road at the shore
const BRIDGE_RAMP := 700.0            # length of the climb from the mainland (long, so there is headroom over the beach)
const BRIDGE_RAMP_OUT := 340.0        # the descent onto the island
const BRIDGE_LANDING := 4.0          # the bridge starts this far inland so it overlaps the shore end of the road

## The road to the island: the supplied "modular road bridge" span (deck, footpaths, railings and a concrete pier)
## repeated along the water crossing. Each span is solid.
## Height of the deck above the shore road at distance t along a crossing of length total: a smooth hump.
static func _lift(t: float, total: float) -> float:
	var k := minf(smoothstep(0.0, BRIDGE_RAMP, t), smoothstep(0.0, BRIDGE_RAMP_OUT, total - t))
	return BRIDGE_LIFT * k

static func _bridge(w: World) -> void:
	var body := StaticBody3D.new()
	body.name = "Bridge"
	body.collision_layer = 1
	w.static_root.add_child(body)
	var rng2 := Coast.bridge_range()
	var z_in := rng2.x
	var z_out := rng2.y
	var s := 11.8 / BRIDGE_W
	var span := BRIDGE_L * s
	var n := maxi(1, int(round((z_out - z_in) / span)))
	var zs := (z_out - z_in) / (n * span)           # stretch so the spans fit the crossing exactly
	# the model's parts, turned upright and re-centred on the deck
	var fix := Transform3D(Basis(Vector3.UP, deg_to_rad(BRIDGE_YAW)), Vector3.ZERO)
	var norm := Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -BRIDGE_DECK)
	var parts := _parts(BRIDGE)
	var group: Array = []
	var faces := PackedVector3Array()
	for p in parts:
		var xf: Transform3D = norm * fix * (p.xf as Transform3D)
		group.append({"mesh": p.mesh, "xf": xf})
		for v in (p.mesh as Mesh).get_faces():
			faces.append(xf * v)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var batches := {}
	var total := z_out - z_in
	var concrete := w._mat("res://assets/airport/tex/Concrete034.jpg", 0.3, Color(0.78, 0.78, 0.8))
	var lamp_every := 4
	for i in range(n):
		var zc := z_in + (i + 0.5) * span * zs
		var h := _lift(zc - z_in, total)
		var slope := (_lift(zc - z_in + 2.0, total) - _lift(zc - z_in - 2.0, total)) / 4.0
		var base := Transform3D(Basis(Vector3.RIGHT, -atan(slope)) * Basis.from_scale(Vector3(1, 1, zs)), Vector3(0, 0.08 + h, zc))
		_place(batches, "bridge", {"parts": group}, base)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = base
		body.add_child(cs)
		# a pier from the seabed up to the underside of the raised deck
		var bed := Coast.height_at(0.0, zc)
		var top := h - 1.6
		var ph := top - bed
		if ph > 0.6 and i % 2 == 0:
			var pm := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(5.2, ph, 2.4)
			pm.mesh = bm
			pm.material_override = concrete
			pm.position = Vector3(0, bed + ph * 0.5, zc)
			w.static_root.add_child(pm)
			var pc := CollisionShape3D.new()
			var pb := BoxShape3D.new()
			pb.size = bm.size
			pc.shape = pb
			pc.position = pm.position
			body.add_child(pc)
		if i % lamp_every == 2:
			for sx in [-1.0, 1.0]:
				RoadKit.lamp_at(w, body, Vector2(sx * 5.4, zc), Vector2(0.0, zc), h + 0.08)
	_flush(w, batches, true)
	print("bridge: %d spans of the modular road bridge over %.0f m" % [n, z_out - z_in])
