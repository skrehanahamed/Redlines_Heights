class_name GolfNpc
extends Node3D
## A club employee or member of Redline Golf Club: a Mixamo-rigged character that loops a downloaded idle clip (talking, standing, sitting)
## and, when given a patrol, walks between its points and pauses at each one. Solid for the player (a capsule on the world layer).

var anim: AnimationPlayer
var model: Node3D
var clip := "Idle"
var patrol: Array[Vector3] = []
var _wp := 0
var _pause := 0.0
var _cur := ""
var _face := 0.0
var _body: StaticBody3D
const WALK_SPEED := 1.25

static func make(w: World, id: String, pos: Vector3, yaw: float, clip_name: String, route: Array = [], solid := true) -> GolfNpc:
	var n := GolfNpc.new()
	n.clip = clip_name
	for p in route: n.patrol.append(p)
	w.static_root.add_child(n)
	n.position = pos
	n._face = yaw
	n.model = Game.load_character(id)
	n.add_child(n.model)
	n.model.rotation.y = yaw
	n.anim = AnimationPlayer.new()
	n.model.add_child(n.anim)
	n.anim.root_node = NodePath("..")
	n.anim.add_animation_library("", Game.get_anim_library(id))
	n._play(clip_name)
	n.anim.seek(randf() * 2.0)
	if solid:
		n._body = StaticBody3D.new()
		n._body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.7 if not clip_name.contains("Sitting") else 1.2
		cs.shape = cap
		cs.position = Vector3(0, cap.height * 0.5, 0)
		n._body.add_child(cs)
		n.add_child(n._body)
	n.set_process(not n.patrol.is_empty())
	return n

func _play(name: String, speed := 1.0) -> void:
	if _cur == name: return
	_cur = name
	if anim.has_animation(name):
		var a := anim.get_animation(name)
		a.loop_mode = Animation.LOOP_LINEAR
		anim.play(name, 0.25, speed)

func _process(delta: float) -> void:
	if patrol.is_empty(): return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0: _wp = (_wp + 1) % patrol.size()
		return
	var target := patrol[_wp]
	var d := target - position
	d.y = 0.0
	if d.length() < 0.12:
		_pause = randf_range(4.0, 8.0)
		_play(clip)
		return
	_play("Walk")
	var dir := d.normalized()
	position += dir * WALK_SPEED * delta
	_face = lerp_angle(_face, atan2(dir.x, dir.z), clampf(delta * 5.0, 0.0, 1.0))
	model.rotation.y = _face
