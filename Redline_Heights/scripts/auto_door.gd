class_name AutoDoor
extends Node3D
## Automatic sliding glass doors for any shop, hotel or house. Built in the building's own frame: the doorway is centred on x = 0
## in the wall plane z = 0, the outside is +z. The two glass wings slide apart sideways, inside the wall, when the player (or
## a pedestrian) is near the doorway, and close again when they leave. The doorway itself has no collision, only the wings do
## while closed.

const OPEN_SPEED := 1.7
var door_w := 3.0
var door_h := 2.5
var left: Node3D
var right: Node3D
var wing_w := 1.5
var body: StaticBody3D
var open_t := 0.0
var is_open := false
var audio: AudioStreamPlayer3D
var snd_open: AudioStream
var snd_close: AudioStream
var _closed_sound_pending := false

func setup(p_w: float, p_h: float, glass: Material, frame: Material) -> void:
	door_w = p_w
	door_h = p_h
	wing_w = door_w * 0.5
	snd_open = load("res://assets/audio/guns_and_gameplay/door_tech_open_01.ogg") as AudioStream
	snd_close = load("res://assets/audio/vehicles/door_close_01.ogg") as AudioStream
	audio = AudioStreamPlayer3D.new()
	audio.position = Vector3(0, 1.5, 0)
	audio.max_distance = 25.0
	audio.unit_size = 6.0
	audio.volume_db = -3.0
	add_child(audio)
	body = StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	left = _wing(glass, frame, -1.0)
	right = _wing(glass, frame, 1.0)

func _wing(glass: Material, frame: Material, side: float) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var g := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(wing_w, door_h, 0.04)
	g.mesh = bm
	g.material_override = glass
	g.position = Vector3(side * wing_w * 0.5, door_h * 0.5, 0.0)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(g)
	for r in [[Vector3(wing_w, 0.08, 0.07), Vector3(side * wing_w * 0.5, door_h - 0.04, 0.0)], [Vector3(wing_w, 0.12, 0.07), Vector3(side * wing_w * 0.5, 0.06, 0.0)],
			[Vector3(0.06, door_h, 0.07), Vector3(side * 0.03, door_h * 0.5, 0.0)], [Vector3(0.06, door_h, 0.07), Vector3(side * (wing_w - 0.03), door_h * 0.5, 0.0)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = r[0]
		m.mesh = b
		m.material_override = frame
		m.position = r[1]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(m)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(wing_w, door_h, 0.1)
	cs.shape = bs
	cs.position = Vector3(side * wing_w * 0.5, door_h * 0.5, 0.0)
	cs.name = "col_%d" % int(side)
	body.add_child(cs)
	return n

func _process(delta: float) -> void:
	var near := false
	var margin := 0.6 if is_open else 0.0
	var pl := Game.player as Node3D
	if pl != null and is_instance_valid(pl):
		var lp := to_local(pl.global_position)
		near = absf(lp.x) < door_w * 0.5 + 1.2 + margin and lp.z > -3.0 - margin and lp.z < 3.4 + margin and absf(lp.y) < 2.5
	if not near:
		for p in get_tree().get_nodes_in_group("peds"):
			var lp2 := to_local((p as Node3D).global_position)
			if absf(lp2.x) < door_w * 0.5 + 0.6 and absf(lp2.z) < 2.0 and absf(lp2.y) < 2.0:
				near = true
				break
	if near != is_open:
		is_open = near
		if is_open:
			_closed_sound_pending = true
			audio.stream = snd_open
			audio.pitch_scale = randf_range(0.96, 1.04)
			audio.play()
	open_t = move_toward(open_t, 1.0 if is_open else 0.0, delta * OPEN_SPEED)
	var e := smoothstep(0.0, 1.0, open_t)
	left.position.x = -e * wing_w * 0.98
	right.position.x = e * wing_w * 0.98
	# the wings only block the doorway while (nearly) closed
	for ch in body.get_children():
		(ch as CollisionShape3D).disabled = open_t > 0.15
	if not is_open and open_t <= 0.02 and _closed_sound_pending:
		_closed_sound_pending = false
		audio.stream = snd_close
		audio.pitch_scale = randf_range(0.95, 1.05)
		audio.play()
