class_name RadioLogo
extends Control
## A round station logo drawn in code (original artwork, not any real broadcaster's): gradient disc, ring, a pattern per
## station and its initials.

var data: Dictionary = {}
var dim := 1.0
var icon: Texture2D
var icon_bg := Color.WHITE
var uv_r := 0.46
var gray := 0.0

func _ready() -> void:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float gray = 0.0;\nvoid fragment() { float l = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11)); COLOR.rgb = mix(COLOR.rgb, vec3(l * 0.9), gray); }"
	var m := ShaderMaterial.new()
	m.shader = sh
	material = m

func set_gray(g: float) -> void:
	gray = g
	(material as ShaderMaterial).set_shader_parameter("gray", g)

func set_icon(t: Texture2D) -> void:
	icon = t
	if t != null:
		var im := t.get_image()
		var w := im.get_width() - 1
		var h := im.get_height() - 1
		icon_bg = (im.get_pixel(2, 2) + im.get_pixel(w - 2, 2) + im.get_pixel(2, h - 2) + im.get_pixel(w - 2, h - 2)) * 0.25
		icon_bg.a = 1.0
	queue_redraw()

func setup(d: Dictionary) -> void:
	data = d
	queue_redraw()

func _draw() -> void:
	if data.is_empty(): return
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var ca := Color(String(data.a))
	var cb := Color(String(data.b))
	# soft shadow
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.45))
	# gradient disc: stacked circles from the dark rim to the bright centre
	var steps := 14
	for i in range(steps):
		var t := float(i) / (steps - 1)
		draw_circle(c, r * (1.0 - t * 0.9), cb.lerp(ca, t).darkened(1.0 - dim) if dim < 1.0 else cb.lerp(ca, t))
	if icon != null:
		# the logo is cropped to the disc (corners and any square frame fall outside it)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for k in range(65):
			var a := TAU * k / 64.0
			var off := Vector2(cos(a), sin(a))
			pts.append(c + off * r * 0.98)
			uvs.append(Vector2(0.5, 0.5) + off * uv_r)
		draw_colored_polygon(pts, Color(1, 1, 1, dim), uvs, icon)
		draw_arc(c, r - 1.5, 0.0, TAU, 64, Color(1, 1, 1, 0.95 * dim), 3.0)
		return
	var line := Color(1, 1, 1, 0.55 * dim)
	var style := int(data.get("style", 0))
	match style:
		0:   # cassette / waveform
			for k in range(-3, 4):
				var h := r * (0.18 + 0.09 * (3 - absi(k)))
				draw_line(c + Vector2(k * r * 0.17, -h), c + Vector2(k * r * 0.17, h), line, 2.0)
		1:   # sun rays
			for k in range(12):
				var a := TAU * k / 12.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.6, c + Vector2(cos(a), sin(a)) * r * 0.84, line, 2.5)
		2:   # vinyl grooves
			for k in range(3):
				draw_arc(c, r * (0.55 + k * 0.12), 0.0, TAU, 48, line, 1.6)
		3:   # diamonds
			var p := PackedVector2Array([c + Vector2(0, -r * 0.82), c + Vector2(r * 0.82, 0), c + Vector2(0, r * 0.82), c + Vector2(-r * 0.82, 0), c + Vector2(0, -r * 0.82)])
			draw_polyline(p, line, 2.0)
		4:   # drum rings
			draw_arc(c, r * 0.8, 0.2, PI - 0.2, 24, line, 2.5)
			draw_arc(c, r * 0.8, PI + 0.2, TAU - 0.2, 24, line, 2.5)
		5:   # waves
			for k in range(3):
				var pts := PackedVector2Array()
				for s in range(21):
					var x := lerpf(-r * 0.7, r * 0.7, s / 20.0)
					pts.append(c + Vector2(x, r * (0.52 + k * 0.1) + sin(s * 0.9 + k) * r * 0.05))
				draw_polyline(pts, line, 1.8)
		6:   # lotus / moon crescent
			draw_arc(c + Vector2(r * 0.12, -r * 0.05), r * 0.78, PI * 0.55, PI * 1.45, 28, line, 3.0)
			for k in range(5):
				draw_circle(c + Vector2(cos(k * 1.7) * r * 0.62, sin(k * 2.3) * r * 0.62), 1.8, line)
		_:
			pass
	draw_arc(c, r - 1.5, 0.0, TAU, 64, Color(1, 1, 1, 0.9 * dim), 3.0)
	var font: Font = load("res://assets/ui/fonts/BebasNeue-Regular.ttf")
	var txt := String(data.get("glyph", ""))
	var fs := int(r * (0.85 if txt.length() <= 1 else (0.62 if txt.length() == 2 else 0.5)))
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := c + Vector2(-ts.x * 0.5, ts.y * 0.28)
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, dim))
