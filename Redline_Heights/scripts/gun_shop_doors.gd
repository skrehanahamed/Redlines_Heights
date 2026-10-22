class_name GunShopDoors
extends Node3D

## Animated automatic commercial storefront double-doors for Redline Ammo.
## Slides open sideways (in front of the shop windows) when the player approaches the entrance,
## and closes when the player moves away. Sliding never sweeps through the player like a swing door did. Plays authentic door audio.

var left_wing: Node3D
var right_wing: Node3D
var audio: AudioStreamPlayer3D

var snd_open: AudioStream
var snd_close: AudioStream

var dc := 0.0
var z1 := 0.0
var gy := 0.0
var open_t := 0.0
var is_open := false
var was_open := false
var closing_sound_played := true
var wing_w_slide := 1.0
var door_w_half := 1.0
const FRONT := 0.075              # the wings run just outside the glass line

const OPEN_ANGLE_DEG := 84.0

func setup(p_dc: float, p_z1: float, p_gy: float, door_w: float, door_mat: Material, trim_mat: Material) -> void:
	dc = p_dc
	z1 = p_z1
	gy = p_gy
	
	snd_open = load("res://assets/audio/guns_and_gameplay/door_tech_open_01.ogg") as AudioStream
	snd_close = load("res://assets/audio/vehicles/door_close_01.ogg") as AudioStream
	
	audio = AudioStreamPlayer3D.new()
	audio.position = Vector3(dc, gy + 1.2, z1 - 0.1)
	audio.max_distance = 25.0
	audio.unit_size = 6.0
	audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	audio.volume_db = -2.0
	add_child(audio)
	
	var wing_w := (door_w * 0.5) - 0.03
	var wing_h := 2.12
	wing_w_slide = wing_w + 0.06
	door_w_half = door_w * 0.5
	
	# Left Wing Pivot (hinged on left door jamb)
	left_wing = Node3D.new()
	left_wing.position = Vector3(dc - door_w * 0.5 + 0.03, gy, z1 + FRONT)
	add_child(left_wing)
	_build_wing_mesh(left_wing, wing_w, wing_h, door_mat, trim_mat, true)
	
	# Right Wing Pivot (hinged on right door jamb)
	right_wing = Node3D.new()
	right_wing.position = Vector3(dc + door_w * 0.5 - 0.03, gy, z1 + FRONT + 0.05)
	right_wing.rotation.y = PI
	add_child(right_wing)
	_build_wing_mesh(right_wing, wing_w, wing_h, door_mat, trim_mat, false)

func _build_wing_mesh(parent: Node3D, w: float, h: float, door_mat: Material, trim_mat: Material, _is_left: bool) -> void:
	# Glass door panel with double-sided texture (no collision block so player enters freely when open)
	
	# Glass door panel with double-sided texture
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, 0.035)
	mi.mesh = bm
	mi.material_override = door_mat
	mi.position = Vector3(w * 0.5, h * 0.5, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	
	# Aluminum perimeter edge frame
	var frame_m: Material = trim_mat
	# Top & bottom rails
	var rail_top := MeshInstance3D.new()
	var rtm := BoxMesh.new()
	rtm.size = Vector3(w, 0.08, 0.05)
	rail_top.mesh = rtm
	rail_top.material_override = trim_mat
	rail_top.position = Vector3(w * 0.5, h - 0.04, 0.0)
	parent.add_child(rail_top)
	
	var rail_bot := MeshInstance3D.new()
	var rbm := BoxMesh.new()
	rbm.size = Vector3(w, 0.14, 0.05)
	rail_bot.mesh = rbm
	rail_bot.material_override = trim_mat
	rail_bot.position = Vector3(w * 0.5, 0.07, 0.0)
	parent.add_child(rail_bot)
	
	# Push bar handle across middle (customer entry push side)
	var bar := MeshInstance3D.new()
	var barm := BoxMesh.new()
	barm.size = Vector3(w * 0.82, 0.05, 0.06)
	bar.mesh = barm
	bar.material_override = trim_mat
	bar.position = Vector3(w * 0.5, 1.05, 0.045)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bar)
	
	# Vertical pull handle on unhinged edge
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.035, 0.45, 0.07)
	handle.mesh = hm
	handle.material_override = trim_mat
	handle.position = Vector3(w * 0.88, 1.05, -0.045)
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(handle)

func _process(delta: float) -> void:
	var player_pos := Vector3.ZERO
	var has_player := false
	
	if Game.player != null and is_instance_valid(Game.player):
		player_pos = Game.player.global_position
		has_player = true
	
	# Detection zone with a margin on the way out so the doors never flutter at the edge
	var in_range := false
	if has_player:
		var mx := 2.9 if is_open else 2.2
		var mz_front := 3.6 if is_open else 2.8
		var dz := player_pos.z - (z1 - 0.2)
		in_range = absf(player_pos.x - dc) < mx and dz < mz_front and dz > -3.0 and absf(player_pos.y - gy) < 2.5
	
	if in_range != is_open:
		is_open = in_range
		if is_open:
			closing_sound_played = false
			if snd_open and audio and is_inside_tree():
				audio.stream = snd_open
				audio.pitch_scale = randf_range(0.96, 1.04)
				audio.play()
	
	var target_t := 1.0 if is_open else 0.0
	open_t = move_toward(open_t, target_t, delta * 1.7)
	
	var ease_t := smoothstep(0.0, 1.0, open_t)
	if left_wing:
		left_wing.position.x = dc - 1.0 + 0.03 - ease_t * wing_w_slide - (door_w_half - 1.0)
	if right_wing:
		right_wing.position.x = dc + 1.0 - 0.03 + ease_t * wing_w_slide + (door_w_half - 1.0)
	
	# Play closing latch sound when doors touch closed
	if not is_open and open_t <= 0.02 and not closing_sound_played:
		closing_sound_played = true
		if snd_close and audio and is_inside_tree():
			audio.stream = snd_close
			audio.pitch_scale = randf_range(0.95, 1.05)
			audio.play()
