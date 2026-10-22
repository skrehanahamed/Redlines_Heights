class_name CashPickup
extends Node3D
## A spinning green banknote dropped by a dead ped. Walk (or drive) over it to collect.

var value := 20
var life := 40.0
var armed_t := 1.0          # cannot be collected until it has landed
var _t := 0.0
var _mesh: MeshInstance3D

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.015, 0.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.75, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 0.15)
	mat.emission_energy_multiplier = 0.8
	bm.material = mat
	_mesh.mesh = bm
	add_child(_mesh)
	# toss the note out sideways in a little arc
	var toss := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(1.2, 2.2)
	var start := position
	var tw := create_tween()
	tw.tween_method(func(k: float): position = start + toss * k + Vector3(0, sin(k * PI) * 0.8, 0), 0.0, 1.0, 0.7)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 1.0, 0.5)
	glow.light_energy = 0.6
	glow.omni_range = 2.5
	add_child(glow)

func _process(delta: float) -> void:
	_t += delta
	life -= delta
	armed_t -= delta
	_mesh.rotation.y += 3.0 * delta
	_mesh.position.y = sin(_t * 3.0) * 0.08
	if life <= 0.0:
		queue_free()
		return
	if armed_t > 0.0:
		return
	var near := false
	if Game.in_car != null and is_instance_valid(Game.in_car):
		near = (Game.in_car as Node3D).global_position.distance_to(global_position) < 3.0
	elif Game.player != null and is_instance_valid(Game.player):
		near = (Game.player as Node3D).global_position.distance_to(global_position - Vector3(0, 0.45, 0)) < 1.4
	if near:
		Game.money += value
		Fx.popup(get_parent(), global_position + Vector3(0, 0.6, 0), "+$%d" % value, Color(0.4, 1.0, 0.45))
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/guns_and_gameplay/item_pickup_01.ogg") as AudioStream
		get_parent().add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
		queue_free()
