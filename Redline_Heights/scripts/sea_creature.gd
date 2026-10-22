class_name SeaCreature
extends Node3D
## An animated animal travelling round a smooth closed loop: sea animals swim in a band of water (checked when they are made, so they
## never leave it), birds circle in the air. It faces the way it travels, plays its own swim / flight animation and bobs a little.

var pts := PackedVector2Array()
var cum := PackedFloat32Array()
var length := 0.0
var speed := 3.0
var s := 0.0
var yaw := 0.0
var t := randf() * 10.0
var base_y := -0.8
var bob := 0.15
var tilt := 0.03
var model: Node3D
var leap := false               # dolphins: every few seconds an arc out of the water
var ground := false             # a land animal: it follows the terrain height and does not bob
var yaw0 := 0.0                # turns the model's own front to +z

## loop: corner points (world x, z). Returns false (and builds nothing) if `ok` rejects any point of the smoothed path.
func setup(node: Node3D, loop: Array[Vector2], spd: float, phase: float, y: float, yaw_offset: float, ok: Callable) -> bool:
	model = node
	add_child(model)
	model.rotation.y = yaw_offset              # the holder from BeachLife._fit: only scale, so the model's own built-in rotation is kept
	speed = spd
	base_y = y
	var p: Array[Vector2] = loop.duplicate()
	for it in 3:
		var q: Array[Vector2] = []
		for i in range(p.size()):
			var a := p[i]
			var b := p[(i + 1) % p.size()]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	pts = PackedVector2Array(p)
	cum = PackedFloat32Array()
	length = 0.0
	for i in range(pts.size()):
		cum.append(length)
		length += pts[i].distance_to(pts[(i + 1) % pts.size()])
	# check the whole smoothed path, every 4 m
	var d := 0.0
	while d < length:
		var q2 := _sample(d)
		if not bool(ok.call(q2)): return false
		d += 4.0
	s = fposmod(phase, 1.0) * length
	_place(0.0)
	return true

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
	return a.lerp(b, (d - cum[lo]) / maxf(a.distance_to(b), 0.0001))

func _place(delta: float) -> void:
	var here := _sample(s)
	var ahead := _sample(s + 5.0)
	var want := atan2(ahead.x - here.x, ahead.y - here.y)
	yaw = want if delta <= 0.0 else lerp_angle(yaw, want, clampf(delta * 4.0, 0.0, 1.0))
	position = Vector3(here.x, (maxf(Coast.height_at(here.x, here.y), -0.3) + 0.02) if ground else base_y, here.y)

## Plays the first animation whose name contains `want` (or the first one) in a loop.
static func play_loop(root: Node, want := "", speed_scale := 1.0) -> void:
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		var a := ap as AnimationPlayer
		var list := a.get_animation_list()
		if list.is_empty(): continue
		var pick := String(list[0])
		for n in list:
			if want != "" and String(n).contains(want): pick = String(n)
		a.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
		a.speed_scale = speed_scale
		a.play(pick)

func _process(delta: float) -> void:
	t += delta
	s += speed * delta
	_place(delta)
	if not ground:
		var y := base_y + sin(t * 1.4) * bob
		if base_y < 5.0:
			# a swimmer never goes into the seabed: it rides at least 0.35 m above the bottom and stays under the surface
			y = minf(maxf(y, Coast.height_at(position.x, position.z) + 0.35), -0.25)
		if leap:
			var ph := fposmod(t + float(get_instance_id() % 7), 9.0)
			if ph < 1.5:
				var k := ph / 1.5
				y = -0.3 + sin(k * PI) * 2.0
				rotation.x = cos(k * PI) * -0.5
			else:
				rotation.x = lerpf(rotation.x, 0.0, 0.2)
		position.y = y
	rotation.y = yaw
	rotation.z = 0.0 if ground else sin(t * 1.1) * tilt
