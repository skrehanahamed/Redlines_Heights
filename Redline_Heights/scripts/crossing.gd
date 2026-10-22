class_name Crossing
extends Node3D
## A level crossing from the supplied model: booms, signals, pedestrian gates and flashing lights, driven by train distance.

var s_cross := 0.0
var _lamps: Array = []
var _lamp_mats: Array = []
var _closed := false
var _angle := 75.0          # boom 'up' angle used for timing (the model's own raise is ARM_UP degrees)
var _blink := 0.0
var _bell: AudioStreamPlayer3D
const MODEL := "res://assets/rail/level_crossing.glb"
const ARM_UP := 52.9                           # how far the booms are raised in the model file (degrees)
const ROAD_C := Vector2(6.3, -4.5)             # middle of the road (x) and of the double track (z), in the model's space
const HINGE_A := Vector3(0.05, 1.77, 0.02 + SPREAD)     # boom 1 hinge (it swings out towards +x)
const HINGE_B := Vector3(12.6, 1.77, -8.89 - SPREAD)    # boom 2 hinge (it swings out towards -x)
const BOOM_LEN := 6.2
const SPREAD := 4.2                            # each side's signals, booms and fences are moved this far away from the rails

var _arm_nodes: Array = []                     # [boom 1 node, boom 2 node]
var _arm_rest: Array = []                      # their transforms relative to the unit
var _pivots: Array = []                        # invisible collision booms, same pivots as the real ones
var _unit: Node3D
var _blockers: Array = []                      # full-width invisible bars: nothing gets onto the tracks while closed

## The whole supplied level crossing (two booms, signal heads, pedestrian gates and fences) laid over the road, turned
## so the model's road runs along road_dir and its tracks sit on the real ones. Booms really swing down; while a train
## is near, a full-width invisible barrier also holds back cars and people (the model's booms only cover half the road each).
func setup(w: World, s: float, at: Vector2, road_dir: Vector2, track2: float) -> void:
	s_cross = s
	var a := Rail.at(s)
	var d: Vector2 = a[1]
	var n := Vector2(d.y, -d.x)
	var centre := (a[0] as Vector2) + n * (track2 * 0.5)          # middle of the two tracks
	_bell = RailAudio.player(self, RailAudio.bell(), 140.0, 14.0, 2.0)
	_bell.position = Vector3(centre.x, 2.5, centre.y)
	var yaw := atan2(road_dir.x, road_dir.y)
	var rot := Basis(Vector3.UP, yaw)
	var inst := (load(MODEL) as PackedScene).instantiate() as Node3D
	_unit = Node3D.new()
	_unit.rotation.y = yaw
	_unit.position = Vector3(centre.x, 0.1, centre.y) - rot * Vector3(ROAD_C.x, 0.0, ROAD_C.y)
	add_child(_unit)
	_unit.add_child(inst)
	# move each side's equipment away from the tracks (the model puts the booms only ~1 m from the outer rails):
	# every top-level piece goes the way of the side of the tracks it stands on
	var root_n := inst.find_child("RootNode", true, false)
	for ch in root_n.get_children():
		var node := ch as Node3D
		if node == null: continue
		var old := _rel(node)
		var zc := 0.0
		var cnt := 0
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			zc += (_rel(m) * m.mesh.get_aabb().get_center()).z
			cnt += 1
		if cnt == 0: continue
		zc /= cnt
		var dz := SPREAD if zc > ROAD_C.y else -SPREAD
		root_n.remove_child(node)
		node.owner = null
		_unit.add_child(node)
		node.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, dz)) * old
	for nm in ["holder_lod0_006", "holder_lod0_003"]:
		var arm := _unit.find_child(nm, true, false) as Node3D
		_arm_nodes.append(arm)
		_arm_rest.append(_rel(arm))
	# solid posts and fences (the booms are handled separately)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	_unit.add_child(body)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var nm := String(m.name)
		if nm.begins_with("holder_lod0") or nm.begins_with("lights_lod0"): continue
		var xf := _rel(m)
		var faces: PackedVector3Array = m.mesh.get_faces()
		var out := PackedVector3Array()
		out.resize(faces.size())
		for i in range(faces.size()): out[i] = xf * faces[i]
		var sh := ConcavePolygonShape3D.new()
		sh.set_faces(out)
		var cs := CollisionShape3D.new()
		cs.shape = sh
		body.add_child(cs)
	# collision booms
	for k in range(2):
		var pv := StaticBody3D.new()
		pv.collision_layer = 1
		pv.position = HINGE_A if k == 0 else HINGE_B
		_unit.add_child(pv)
		var cs2 := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(BOOM_LEN, 0.3, 0.3)
		cs2.shape = bs
		cs2.position = Vector3(BOOM_LEN * 0.5 * (1.0 if k == 0 else -1.0), 0, 0)
		pv.add_child(cs2)
		_pivots.append(pv)
	# full-width barriers just outside the booms, active only while closed
	for zz in [1.4 + SPREAD, -10.4 - SPREAD]:
		var bb := StaticBody3D.new()
		bb.collision_layer = 0
		bb.position = Vector3(ROAD_C.x, 1.1, zz)
		_unit.add_child(bb)
		var cs3 := CollisionShape3D.new()
		var b3 := BoxShape3D.new()
		b3.size = Vector3(17.0, 2.2, 0.4)
		cs3.shape = b3
		bb.add_child(cs3)
		_blockers.append(bb)
	# the signal heads are the model's own: each head's mesh is cut into its left and right lamp half, each with its own
	# glowing copy of the material, and the two halves flash alternately while the crossing is closed
	for mi in _unit.find_children("lights_lod0*", "MeshInstance3D", true, false):
		_split_head(mi as MeshInstance3D)

func _split_head(m: MeshInstance3D) -> void:
	var src := m.get_active_material(0) as BaseMaterial3D
	if src == null or m.mesh == null: return
	var arr := m.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		idx = PackedInt32Array()
		for i in range(verts.size()): idx.append(i)
	var xf := _rel(m)
	var cx := (xf * m.mesh.get_aabb().get_center()).x
	var halves: Array = [[], []]
	for t in range(0, idx.size(), 3):
		var c := (xf * verts[idx[t]] + xf * verts[idx[t + 1]] + xf * verts[idx[t + 2]]) / 3.0
		(halves[0 if c.x < cx else 1] as Array).append_array([idx[t], idx[t + 1], idx[t + 2]])
	var out := ArrayMesh.new()
	for h in range(2):
		var ids: Array = halves[h]
		if ids.is_empty(): continue
		var remap := {}
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nu := PackedVector2Array()
		var ni := PackedInt32Array()
		for i in ids:
			if not remap.has(i):
				remap[i] = nv.size()
				nv.append(verts[i])
				if not norms.is_empty(): nn.append(norms[i])
				if not uvs.is_empty(): nu.append(uvs[i])
			ni.append(remap[i])
		var a2 := []
		a2.resize(Mesh.ARRAY_MAX)
		a2[Mesh.ARRAY_VERTEX] = nv
		if not nn.is_empty(): a2[Mesh.ARRAY_NORMAL] = nn
		if not nu.is_empty(): a2[Mesh.ARRAY_TEX_UV] = nu
		a2[Mesh.ARRAY_INDEX] = ni
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		var lm := src.duplicate() as BaseMaterial3D
		lm.emission_enabled = true
		lm.emission_texture = lm.albedo_texture
		lm.emission = Color(1, 0.12, 0.08)
		lm.emission_energy_multiplier = 0.0
		out.surface_set_material(out.get_surface_count() - 1, lm)
		_lamp_mats.append(lm)
	m.mesh = out

## Transform of a node relative to the unit (the crossing may not be in the tree yet).
func _rel(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != _unit:
		if cur is Node3D: t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

func _pose(angle_deg: float) -> void:
	var down := ARM_UP * (1.0 - clampf(angle_deg / _angle, 0.0, 1.0))
	for k in range(2):
		var hinge: Vector3 = HINGE_A if k == 0 else HINGE_B
		var sgn := -1.0 if k == 0 else 1.0
		var rot := Basis(Vector3(0, 0, 1), sgn * deg_to_rad(down))
		var around := Transform3D(rot, hinge - rot * hinge)
		(_arm_nodes[k] as Node3D).global_transform = _unit.global_transform * around * (_arm_rest[k] as Transform3D)
		(_pivots[k] as Node3D).rotation = Vector3(0, 0, sgn * deg_to_rad(down))

var _cur := 0.0            # boom angle: _angle = fully up, 0 = down
func _ready() -> void:
	_cur = _angle
	_pose(_angle)

func _process(delta: float) -> void:
	var want := false
	for t in get_tree().get_nodes_in_group("trains"):
		var dd: float = absf(fposmod((t as Train).s_now() - s_cross + Rail.loop_len * 0.5, Rail.loop_len) - Rail.loop_len * 0.5)
		if dd < 160.0:
			want = true
	if "--gatesdown" in OS.get_cmdline_user_args(): want = true
	_closed = want
	if _closed and not _bell.playing: _bell.play()
	elif not _closed and _bell.playing and _cur > _angle - 1.0: _bell.stop()
	_cur = move_toward(_cur, 0.0 if _closed else _angle, 60.0 * delta)
	_pose(_cur)
	# the full-width barrier holds from the moment the booms start down until they are fully up again
	for b in _blockers:
		(b as StaticBody3D).collision_layer = 1 if _cur < _angle - 3.0 else 0
	_blink += delta
	var on := _closed or _cur < _angle - 1.0
	for i in range(_lamp_mats.size()):
		var lit := on and (int(_blink * 2.2) + i) % 2 == 0
		(_lamp_mats[i] as BaseMaterial3D).emission_energy_multiplier = 14.0 if lit else 0.0
