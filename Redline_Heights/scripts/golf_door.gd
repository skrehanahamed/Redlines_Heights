class_name GolfDoor
extends Node3D
## The clubhouse's arched entrance door: the model's two door surfaces hang on a hinge pivot and swing into the hall while the player
## (or the car they drive) is within `radius`, and swing shut again when they leave. No collision on the leaf - the hall is always enterable.

var base_yaw := 0.0
var open_angle := 1.62
var radius := 7.0
var _t := 0.0

func _process(delta: float) -> void:
	var p := Game.get_focus_pos()
	var near := Vector2(global_position.x - p.x, global_position.z - p.z).length() < radius
	_t = move_toward(_t, 1.0 if near else 0.0, delta * 1.3)
	rotation.y = base_yaw + open_angle * smoothstep(0.0, 1.0, _t)
