class_name Crosshair
extends Control
## Aiming reticle: four ticks and a dot that open up while the pistol fires.

var spread := 0.0

func _process(delta: float) -> void:
	var p := Game.player as Player
	var target := 0.0
	if p != null and is_instance_valid(p):
		target = clampf(p.shot_anim_t * 40.0, 0.0, 12.0)
	spread = lerpf(spread, target, clampf(18.0 * delta, 0.0, 1.0))
	if visible:
		queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var col := Color(1, 1, 1, 0.9)
	var shadow := Color(0, 0, 0, 0.6)
	var gap := 7.0 + spread
	var len := 9.0
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var a: Vector2 = c + d * gap
		var b: Vector2 = c + d * (gap + len)
		draw_line(a + Vector2(1, 1), b + Vector2(1, 1), shadow, 4.0)
		draw_line(a, b, col, 2.0)
	draw_circle(c + Vector2(1, 1), 2.5, shadow)
	draw_circle(c, 1.8, Color(0.95, 0.2, 0.15, 0.95))
