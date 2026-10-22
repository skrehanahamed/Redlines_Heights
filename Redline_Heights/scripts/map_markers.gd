class_name MapMarkers
extends Control
## Icons for the places that matter, drawn over the full-screen map.

var pois: Array = []
var half := 3500.0
var side := 640.0
var font: Font

const STYLE := {
	"police": {"c": Color("#2b55c8"), "g": "P"}, "hospital": {"c": Color("#e02a2a"), "g": "+"}, "fire": {"c": Color("#e8641c"), "g": "F"},
	"gas": {"c": Color("#e8b81c"), "g": "G"}, "stadium": {"c": Color("#8a2a8a"), "g": "S"}, "airport": {"c": Color("#3a6a8a"), "g": "A"}, "heli": {"c": Color("#2a8a5a"), "g": "H"},
}

func _draw() -> void:
	if font == null:
		font = load("res://assets/ui/fonts/BebasNeue-Regular.ttf") as Font
	for p in pois:
		if not STYLE.has(p.kind): continue
		var st: Dictionary = STYLE[p.kind]
		var at := Vector2((p.pos.x + half) / (half * 2.0), (p.pos.z + half) / (half * 2.0)) * side
		draw_circle(at, 12.0, Color(0, 0, 0, 0.55))
		draw_circle(at, 10.0, Color.WHITE)
		draw_circle(at, 8.0, st.c)
		if p.kind == "hospital":
			draw_rect(Rect2(at - Vector2(1.8, 5.5), Vector2(3.6, 11.0)), Color.WHITE)
			draw_rect(Rect2(at - Vector2(5.5, 1.8), Vector2(11.0, 3.6)), Color.WHITE)
		else:
			var gw := font.get_string_size(st.g, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, at + Vector2(-gw * 0.5, 5.0), st.g, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
