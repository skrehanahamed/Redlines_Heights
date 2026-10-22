class_name SlideGate
extends Node3D
## A sliding gate leaf: slides sideways along its track and opens when the player (on foot or driving) comes within `radius`, closes again after.
## The leaf carries an AnimatableBody3D so it is solid for walkers and vehicles wherever it is.

var centre := Vector2.ZERO     # middle of the opening (world x, z)
var open_dx := -17.0           # how far the leaf slides when open (along x, metres)
var radius := 24.0
var _t := 0.0

func _process(delta: float) -> void:
	var p: Vector3 = Game.get_focus_pos()
	var near := Vector2(centre.x - p.x, centre.y - p.z).length() < radius
	_t = move_toward(_t, 1.0 if near else 0.0, delta * 0.45)
	position.x = lerpf(_home, _home + open_dx, smoothstep(0.0, 1.0, _t))
	# the leaf is solid only while it is (almost) shut: a moving collider that lags the picture left an invisible wall in the gateway
	if solid_shape != null:
		solid_shape.set_deferred("disabled", _t > 0.04)

var _home := 0.0
var solid_shape: CollisionShape3D = null

func _ready() -> void:
	_home = position.x
