class_name DrawBridge
extends Node3D
## A two-leaf lift bridge (a bascule) carrying a road over a boat channel. The leaves stay down for traffic; when a boat comes
## within range both leaves swing up, the boat sails through, and they come down again. The road is solid while the leaves are
## down (and the leaves are solid while they move). Signal lamps at both ends show red while it is open.

var xc := 0.0
var z0 := 0.0
var z1 := 0.0
var leaf_a: Node3D
var leaf_b: Node3D
var open_t := 0.0
var range_m := 46.0
var lamps: Array[MeshInstance3D] = []
var red_mat: StandardMaterial3D
var green_mat: StandardMaterial3D
var snd: AudioStreamPlayer3D
var _last_open := false
const MAX_ANGLE := 1.3
const SPEED := 0.22                # opening takes about 4.5 s

func build(p_xc: float, p_z0: float, p_z1: float, road_w: float, walk_w: float, asphalt: Material, walk: Material, steel: Material, rails: Material) -> void:
	xc = p_xc
	z0 = p_z0
	z1 = p_z1
	position = Vector3(xc, 0.0, 0.0)
	var half := (z1 - z0) * 0.5
	leaf_a = _leaf(z0, 0.0, half, road_w, walk_w, asphalt, walk, steel, rails)
	leaf_b = _leaf(z1, PI, half, road_w, walk_w, asphalt, walk, steel, rails)
	red_mat = StandardMaterial3D.new()
	red_mat.albedo_color = Color(0.4, 0.05, 0.05)
	red_mat.emission_enabled = true
	red_mat.emission = Color(1.0, 0.1, 0.05)
	red_mat.emission_energy_multiplier = 3.0
	green_mat = StandardMaterial3D.new()
	green_mat.albedo_color = Color(0.05, 0.35, 0.1)
	green_mat.emission_enabled = true
	green_mat.emission = Color(0.1, 1.0, 0.3)
	green_mat.emission_energy_multiplier = 1.6
	for sz in [z0 - 1.0, z1 + 1.0]:
		for sx in [-(road_w * 0.5 + 1.0), road_w * 0.5 + 1.0]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.2, 3.0, 0.2)
			post.mesh = pm
			post.material_override = steel
			post.position = Vector3(sx, 1.5, sz)
			add_child(post)
			var lamp := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.4, 0.4, 0.4)
			lamp.mesh = lm
			lamp.material_override = green_mat
			lamp.position = Vector3(sx, 3.2, sz)
			add_child(lamp)
			lamps.append(lamp)
	snd = AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/guns_and_gameplay/switch_on.ogg") as AudioStream
	snd.max_distance = 120.0
	snd.unit_size = 20.0
	snd.position = Vector3(0.0, 2.0, (z0 + z1) * 0.5)
	add_child(snd)

func _leaf(hinge_z: float, yaw: float, length: float, road_w: float, walk_w: float, asphalt: Material, walk: Material, steel: Material, rails: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 0.0, hinge_z)
	pivot.rotation.y = yaw
	add_child(pivot)
	var mb := {}
	var hw := road_w * 0.5
	var tot := hw + walk_w
	Miami._box(mb, steel, Vector3(-tot, -0.9, 0.0), Vector3(tot, 0.04, length), 0.3)
	Miami._quad(mb, asphalt, Vector3(-hw, 0.05, length), Vector3(hw, 0.05, length), Vector3(hw, 0.05, 0.0), Vector3(-hw, 0.05, 0.0), 0.12)
	for sx in [-1.0, 1.0]:
		var a := hw if sx > 0.0 else -tot
		var b := tot if sx > 0.0 else -hw
		Miami._quad(mb, walk, Vector3(a, 0.2, length), Vector3(b, 0.2, length), Vector3(b, 0.2, 0.0), Vector3(a, 0.2, 0.0), 0.2)
		Miami._box(mb, steel, Vector3(a if sx < 0.0 else b - 0.2, 0.05, 0.0), Vector3((a + 0.2) if sx < 0.0 else b, 0.2, length), 0.3)
		Miami._box(mb, rails, Vector3(tot * sx - 0.1, 0.2, 0.0), Vector3(tot * sx + 0.1, 1.15, length), 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = Miami._finish(mb)
	var body := AnimatableBody3D.new()
	body.collision_layer = 1
	body.add_child(mi)
	for part in [[Vector3(road_w + 2.0 * walk_w, 0.95, length), Vector3(0.0, -0.43, length * 0.5)], [Vector3(road_w + 2.0 * walk_w, 0.2, length), Vector3(0.0, 0.1, length * 0.5)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = part[0]
		cs.shape = bs
		cs.position = part[1]
		body.add_child(cs)
	pivot.add_child(body)
	return pivot

func _boat_near() -> bool:
	for b in get_tree().get_nodes_in_group("boats"):
		var p := (b as Node3D).global_position
		if absf(p.z - (z0 + z1) * 0.5) < 14.0 and absf(p.x - xc) < range_m + (8.0 if open_t > 0.05 else 0.0):
			return true
	return false

func _process(delta: float) -> void:
	var want := _boat_near()
	open_t = move_toward(open_t, 1.0 if want else 0.0, delta * SPEED)
	var e := smoothstep(0.0, 1.0, open_t)
	leaf_a.rotation.x = -e * MAX_ANGLE
	leaf_b.rotation.x = -e * MAX_ANGLE
	var shut := open_t < 0.01
	for l in lamps: l.material_override = green_mat if shut else red_mat
	if want != _last_open:
		_last_open = want
		if snd != null and is_inside_tree(): snd.play()
