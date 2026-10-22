@tool
extends SceneTree

func _init() -> void:
	var x_east := 491.0
	var z0 := -8.8
	var gy := 0.1
	var pole_x := x_east - 0.5
	var pole_z := z0 - 0.2
	
	var light_scale := 0.72
	var t := Transform3D.IDENTITY
	t = t.scaled(Vector3.ONE * light_scale)
	t = t.rotated(Vector3.UP, PI * 0.92)
	t.origin = Vector3(pole_x, gy, pole_z)
	
	var head_local := Vector3(2.24, 10.13, 0.0)
	var head_world: Vector3 = t * head_local
	print("Accurate Head World Position: ", head_world)
	print("Height above ground: ", head_world.y - gy)
	print("Offset from pole base: ", Vector2(head_world.x - pole_x, head_world.z - pole_z))
	quit(0)
