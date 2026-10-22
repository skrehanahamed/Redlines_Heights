class_name Boat
extends Node3D
## A boat cruising round a smooth loop (a rounded version of the corner points it is given), in its own lane and facing the way it
## travels, or lying at a mooring when it has no loop. Purely decorative: it bobs a little on the water. Every boat is in the group
## "boats" so the drawbridge knows when to open.

var pts := PackedVector2Array()        # the smooth closed path
var cum := PackedFloat32Array()        # distance along it at each point
var length := 0.0
var speed := 5.0
var s := 0.0
var yaw := 0.0
var t := randf() * 10.0
var water_y := -0.55
var lift := 0.0
var hull: MeshInstance3D
var moored := false

## Which way the bow points in the mesh's own frame, as the yaw that turns it to +z (the travel direction).
static func bow_yaw(mesh: Mesh) -> float:
	var verts := PackedVector3Array()
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			verts.append_array(arr[Mesh.ARRAY_VERTEX])
	if verts.is_empty(): return 0.0
	var bb := mesh.get_aabb()
	var along_x := bb.size.x > bb.size.z
	var ctr := bb.get_center()
	var half := (bb.size.x if along_x else bb.size.z) * 0.5
	var wide_pos := 0.0
	var wide_neg := 0.0
	var n_pos := 0
	var n_neg := 0
	for v in verts:
		var tt: float = (v.x - ctr.x) if along_x else (v.z - ctr.z)
		var lat: float = absf(v.z - ctr.z) if along_x else absf(v.x - ctr.x)
		if tt > half * 0.45:
			wide_pos += lat
			n_pos += 1
		elif tt < -half * 0.45:
			wide_neg += lat
			n_neg += 1
	var bow_pos := (wide_pos / maxf(n_pos, 1)) < (wide_neg / maxf(n_neg, 1))      # the narrower end is the bow
	# bow direction in mesh space
	var b := Vector2(1.0 if bow_pos else -1.0, 0.0) if along_x else Vector2(0.0, 1.0 if bow_pos else -1.0)
	return -atan2(b.x, b.y)

func setup(mesh: Mesh, loop: Array[Vector2], spd: float, phase: float, lift_m: float, lane := 0.0, bow_override := NAN) -> void:
	hull = MeshInstance3D.new()
	hull.mesh = mesh
	hull.rotation.y = bow_yaw(mesh) if is_nan(bow_override) else bow_override
	add_child(hull)
	add_to_group("boats")
	speed = spd
	lift = lift_m
	if loop.size() < 2:
		moored = true
		if loop.size() == 1: global_position = Vector3(loop[0].x, water_y + lift, loop[0].y)
		return
	_build_path(loop, lane)
	s = fposmod(phase, 1.0) * length
	_place(0.0)

func _build_path(loop: Array[Vector2], lane: float) -> void:
	var p: Array[Vector2] = loop.duplicate()
	for it in 3:                                            # Chaikin corner cutting: round every corner
		var q: Array[Vector2] = []
		for i in range(p.size()):
			var a := p[i]
			var b := p[(i + 1) % p.size()]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	pts = PackedVector2Array()
	if absf(lane) > 0.01:
		for i in range(p.size()):
			var d := (p[(i + 1) % p.size()] - p[(i - 1 + p.size()) % p.size()]).normalized()
			pts.append(p[i] + Vector2(d.y, -d.x) * lane)       # to the boat's right
	else:
		pts = PackedVector2Array(p)
	cum = PackedFloat32Array()
	length = 0.0
	for i in range(pts.size()):
		cum.append(length)
		length += pts[i].distance_to(pts[(i + 1) % pts.size()])

func _sample(dist: float) -> Vector2:
	var d := fposmod(dist, length)
	var lo := 0
	var hi := pts.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if cum[mid] <= d: lo = mid
		else: hi = mid - 1
	var a := pts[lo]
	var b := pts[(lo + 1) % pts.size()]
	var seg := maxf(a.distance_to(b), 0.0001)
	return a.lerp(b, (d - cum[lo]) / seg)

func _place(delta: float) -> void:
	var here := _sample(s)
	var ahead := _sample(s + 6.0)
	var want := atan2(ahead.x - here.x, ahead.y - here.y)
	yaw = want if delta <= 0.0 else lerp_angle(yaw, want, clampf(delta * 5.0, 0.0, 1.0))
	global_position = Vector3(here.x, water_y + lift, here.y)

func _process(delta: float) -> void:
	t += delta
	if not moored:
		s += speed * delta
		_place(delta)
	position.y = water_y + lift + sin(t * 1.3) * 0.05
	rotation.y = yaw
	rotation.z = sin(t * 1.1) * 0.015
	rotation.x = sin(t * 0.9) * 0.012
