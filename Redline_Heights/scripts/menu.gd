extends Control
## Main menu: background art, logo, buttons.

var font_title: Font = load("res://assets/ui/fonts/BebasNeue-Regular.ttf")
var font_body: Font = load("res://assets/ui/fonts/Inter-Variable.ttf")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/menu_bg.png") as Texture2D
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo_transparent.png") as Texture2D
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.position = Vector2(-380, 30)
	logo.size = Vector2(760, 285)
	add_child(logo)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-170, 20)
	box.size = Vector2(340, 300)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_button(box, "NEW GAME", _start)
	_button(box, "CONTROLS", _controls)
	_button(box, "QUIT", func(): get_tree().quit())
	var info := Label.new()
	info.text = "Redline Heights  -  prototype"
	info.add_theme_font_override("font", font_body)
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info.position = Vector2(20, -34)
	add_child(info)
	var music := AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/oga/lofi-hip-hop/lofihiphop.ogg") as AudioStream
	music.volume_db = -8.0
	music.autoplay = true
	add_child(music)

func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 62)
	b.add_theme_font_override("font", font_title)
	b.add_theme_font_size_override("font_size", 40)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.1, 0.78)
	normal.set_border_width_all(3)
	normal.border_color = Color("#e8321c")
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#e8321c")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(cb)
	parent.add_child(b)

func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _controls() -> void:
	var d := AcceptDialog.new()
	d.title = "Controls"
	d.dialog_text = "WASD - move / drive\nShift - sprint     Ctrl - walk\nSpace - jump / handbrake\nMouse - look around\nLeft mouse - punch\nE - enter / exit car\nL - headlights    H - horn    R - radio\nBackspace - flip the car upright\nF11 - fullscreen / window\nEsc - pause"
	add_child(d)
	d.popup_centered()
