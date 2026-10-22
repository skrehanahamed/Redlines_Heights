class_name RadioUI
extends CanvasLayer
## GTA V style radio interface: a station logo banner when you tune in, and a radio wheel while R is held.

const HOLD_TIME := 0.25
const WHEEL_R := 250.0

var radio: Radio
var _banner: Control
var _b_logo: RadioLogo
var _b_name: Label
var _b_tag: Label
var _b_title: Label
var _banner_t := 0.0
var _wheel: Control
var _logos: Array[RadioLogo] = []
var _w_name: Label
var _w_tag: Label
var _w_song: Label
var _sel := 0
var _mouse := Vector2.ZERO
var _held := 0.0
var _open := false

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# banner, top left
	_banner = Control.new()
	_banner.position = Vector2(34, 120)
	_banner.size = Vector2(520, 100)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_b_logo = RadioLogo.new()
	_b_logo.size = Vector2(92, 92)
	_banner.add_child(_b_logo)
	_b_name = _lbl(34, Color.WHITE)
	_b_name.position = Vector2(108, 4)
	_banner.add_child(_b_name)
	_b_tag = _lbl(20, Color("#ffd84a"))
	_b_tag.position = Vector2(110, 42)
	_banner.add_child(_b_tag)
	_b_title = _lbl(20, Color("#e8e8e8"))
	_b_title.position = Vector2(110, 66)
	_b_title.custom_minimum_size = Vector2(400, 0)
	_banner.add_child(_b_title)
	# wheel
	_wheel = Control.new()
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.visible = false
	root.add_child(_wheel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.add_child(dim)
	var centre := Control.new()
	centre.set_anchors_preset(Control.PRESET_CENTER)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.add_child(centre)
	var n := radio.channel_count() + 1
	for i in range(n):
		var lg := RadioLogo.new()
		lg.size = Vector2(96, 96)
		var a := -PI * 0.5 + TAU * float(i) / n
		lg.position = Vector2(cos(a), sin(a)) * WHEEL_R - lg.size * 0.5
		lg.pivot_offset = lg.size * 0.5
		if i < radio.channel_count():
			var c: Dictionary = Radio.CHANNELS[i]
			lg.setup(c)
		else:
			lg.setup({"name": "Radio Off", "a": "#3a3d44", "b": "#101216", "glyph": "OFF", "style": 7})
		centre.add_child(lg)
		_logos.append(lg)
	_w_name = _lbl(28, Color.WHITE)
	_w_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_w_name.position = Vector2(-170, -30)
	_w_name.size = Vector2(340, 34)
	_w_name.clip_text = true
	_w_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	centre.add_child(_w_name)
	_w_song = _lbl(17, Color("#eeeeee"))
	_w_song.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_w_song.position = Vector2(-170, 6)
	_w_song.size = Vector2(340, 24)
	_w_song.clip_text = true
	_w_song.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	centre.add_child(_w_song)
	_w_tag = _lbl(15, Color("#ffd84a"))
	_w_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_w_tag.position = Vector2(-170, 30)
	_w_tag.size = Vector2(340, 22)
	centre.add_child(_w_tag)
	radio.icon_ready.connect(_on_icon)
	for ci in range(radio.channel_count()):
		if radio.icons[ci] != null: _on_icon(ci, radio.icons[ci])
	radio.channel_changed.connect(_on_channel)
	radio.title_changed.connect(_on_title)

func _lbl(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_font_override("font", load("res://assets/ui/fonts/BebasNeue-Regular.ttf"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _on_icon(i: int, tex: Texture2D) -> void:
	_logos[i].uv_r = 0.5 if Radio.CHANNELS[i].has("local_icon") else 0.46
	_logos[i].set_icon(tex)
	if radio.idx == i:
		_b_logo.uv_r = _logos[i].uv_r
		_b_logo.set_icon(tex)

func _on_channel(i: int) -> void:
	if i >= 0: _b_logo.uv_r = 0.5 if Radio.CHANNELS[i].has("local_icon") else 0.46
	_b_logo.set_icon(null if i < 0 else radio.icons[i])
	if i < 0:
		_b_logo.setup({"name": "Radio Off", "a": "#3a3d44", "b": "#101216", "glyph": "OFF", "style": 7})
		_b_name.text = "RADIO OFF"
		_b_tag.text = ""
	else:
		var c: Dictionary = Radio.CHANNELS[i]
		_b_logo.setup(c)
		_b_name.text = String(c.name)
		_b_tag.text = c.tag
	_b_title.text = ""
	_banner_t = 4.5

func _on_title(t: String) -> void:
	_b_title.text = t
	if radio.idx >= 0 and radio.on:
		_banner_t = maxf(_banner_t, 3.5)

func _input(event: InputEvent) -> void:
	if _open and event is InputEventMouseMotion:
		_mouse += (event as InputEventMouseMotion).relative
		if _mouse.length() > 140.0: _mouse = _mouse.normalized() * 140.0

func _process(delta: float) -> void:
	_banner_t = maxf(0.0, _banner_t - delta)
	_banner.modulate.a = lerpf(_banner.modulate.a, 1.0 if _banner_t > 0.0 else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	_banner.position.x = lerpf(_banner.position.x, 34.0 if _banner_t > 0.0 else -40.0, clampf(delta * 8.0, 0.0, 1.0))
	var in_car := Game.in_car != null
	var down := in_car and Input.is_action_pressed("radio")
	if down:
		_held += delta
		if _held >= HOLD_TIME and not _open:
			_open = true
			_mouse = Vector2.ZERO
			_sel = radio.idx if radio.on else radio.channel_count()
			_wheel.visible = true
			Engine.time_scale = 0.25
	else:
		if _open:
			_open = false
			_wheel.visible = false
			Engine.time_scale = 1.0
			if _sel >= radio.channel_count(): radio.turn_off()
			elif _sel != radio.idx or not radio.on: radio.tune(_sel)
		elif _held > 0.0 and _held < HOLD_TIME and in_car:
			radio.next_channel()
		_held = 0.0
	if _open:
		var n := _logos.size()
		if _mouse.length() > 40.0:
			var a := fposmod(_mouse.angle() + PI * 0.5, TAU)
			_sel = int(round(a / (TAU / n))) % n
		for i in range(n):
			var target := 1.45 if i == _sel else (1.0 if i != (radio.idx if radio.on else n - 1) else 1.12)
			_logos[i].scale = _logos[i].scale.lerp(Vector2.ONE * target, clampf(delta * 14.0 / maxf(Engine.time_scale, 0.1) * 0.3, 0.0, 1.0))
			_logos[i].dim = 1.0 if i == _sel else 0.6
			_logos[i].set_gray(0.0 if i == _sel else 0.92)
			_logos[i].queue_redraw()
		if _sel >= radio.channel_count():
			_w_name.text = "Radio Off"
			_w_song.text = ""
			_w_tag.text = ""
		else:
			var c: Dictionary = Radio.CHANNELS[_sel]
			_w_name.text = String(c.name)
			_w_song.text = radio.title if _sel == radio.idx and radio.on else ""
			_w_tag.text = String(c.tag)
