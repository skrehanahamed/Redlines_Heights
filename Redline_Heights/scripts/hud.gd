class_name HUD
extends CanvasLayer
## Heads-up display: wanted stars, money, health, speedometer, minimap, prompts, pause, death screen.

const UI := "res://assets/ui/alpha/"
var font_title: Font = load("res://assets/ui/fonts/BebasNeue-Regular.ttf")
var font_body: Font = load("res://assets/ui/fonts/Inter-Variable.ttf")

var stars: Array[TextureRect] = []
var money_label: Label
var health_bar: ProgressBar
var armor_bar: ProgressBar
var speed_label: Label
var car_label: Label
var prompt_label: Label
var toast_label: Label
var banner: TextureRect
var pause_panel: Control
var minimap_tex: ColorRect
var mini_arrow: TextureRect
var mini_mat: ShaderMaterial
var weapon_label: Label
var clock_label: Label
var fps_label: Label
var _fps_t := 0.0
var toast_t := 0.0
var map_texture: Texture2D
var city_half := 260.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.money_changed.connect(func(v): money_label.text = "$ %d" % v)
	Game.health_changed.connect(func(v): health_bar.value = v)
	Game.hurt.connect(_on_hurt)
	Game.wanted_changed.connect(_update_stars)
	Game.message.connect(toast)
	money_label.text = "$ %d" % Game.money
	_update_stars(Game.wanted)

func _label(size: int, color := Color.WHITE, title := false) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font_title if title else font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _icon(name: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = load(UI + name + ".png") as Texture2D
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _place(c: Control, preset: int, offset: Vector2, sz: Vector2) -> void:
	var a := Vector2.ZERO
	match preset:
		Control.PRESET_TOP_RIGHT: a = Vector2(1, 0)
		Control.PRESET_BOTTOM_LEFT: a = Vector2(0, 1)
		Control.PRESET_BOTTOM_RIGHT: a = Vector2(1, 1)
		Control.PRESET_CENTER_TOP: a = Vector2(0.5, 0)
		Control.PRESET_CENTER_BOTTOM: a = Vector2(0.5, 1)
		Control.PRESET_CENTER: a = Vector2(0.5, 0.5)
	c.anchor_left = a.x
	c.anchor_right = a.x
	c.anchor_top = a.y
	c.anchor_bottom = a.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + sz.x
	c.offset_bottom = offset.y + sz.y
	c.grow_horizontal = Control.GROW_DIRECTION_END
	c.grow_vertical = Control.GROW_DIRECTION_END

func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = 100
	b.value = 100
	b.show_percentage = false
	b.custom_minimum_size = Vector2(170, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.05, 0.05, 0.05)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# --- top right: stars, money, health
	var tr := VBoxContainer.new()
	_place(tr, Control.PRESET_TOP_RIGHT, Vector2(-300, 16), Vector2(280, 200))
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(tr)
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_END
	star_row.add_theme_constant_override("separation", 2)
	tr.add_child(star_row)
	for i in range(6):
		var s := _icon("icon_star_empty", 36)
		stars.append(s)
		star_row.add_child(s)
	var mrow := HBoxContainer.new()
	mrow.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(mrow)
	money_label = _label(34, Color("#9fe870"), true)
	mrow.add_child(money_label)
	mrow.add_child(_icon("icon_money", 36))
	var hrow := HBoxContainer.new()
	hrow.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(hrow)
	health_bar = _bar(Color("#d8261c"))
	hrow.add_child(health_bar)
	hrow.add_child(_icon("icon_health", 28))
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(arow)
	armor_bar = _bar(Color("#4a78c0"))
	armor_bar.value = 0
	arow.add_child(armor_bar)
	arow.add_child(_icon("icon_armor", 28))
	weapon_label = _label(22, Color("#f3d9a0"), true)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(weapon_label)
	# --- bottom left: speed
	var bl := VBoxContainer.new()
	_place(bl, Control.PRESET_BOTTOM_LEFT, Vector2(24, -140), Vector2(300, 120))
	root.add_child(bl)
	car_label = _label(26, Color("#f3d9a0"), true)
	bl.add_child(car_label)
	speed_label = _label(62, Color.WHITE, true)
	bl.add_child(speed_label)
	# --- minimap bottom right
	var mm := Control.new()
	mm.name = "Minimap"
	_place(mm, Control.PRESET_BOTTOM_RIGHT, Vector2(-MINI - 24, -MINI - 24), Vector2(MINI, MINI))
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mm)
	minimap_tex = ColorRect.new()
	minimap_tex.color = Color.WHITE
	minimap_tex.size = Vector2(MINI - 20, MINI - 20)
	minimap_tex.position = Vector2(10, 10)
	minimap_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm.add_child(minimap_tex)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D map_tex : filter_linear;
uniform vec2 center = vec2(0.5, 0.5);
uniform float zoom = 0.26;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p);
	vec2 uv = center + p * zoom;
	vec4 c = texture(map_tex, uv);
	COLOR = vec4(c.rgb * 0.95, d < 0.5 ? 1.0 : 0.0);
}
"""
	mini_mat = ShaderMaterial.new()
	mini_mat.shader = shader
	minimap_tex.material = mini_mat
	var frame := _icon("minimap_frame", MINI)
	frame.size = Vector2(MINI, MINI)
	mm.add_child(frame)
	mini_arrow = _icon("map_player", 26)
	mini_arrow.position = Vector2(MINI * 0.5 - 13, MINI * 0.5 - 13)
	mini_arrow.pivot_offset = Vector2(13, 13)
	mm.add_child(mini_arrow)
	clock_label = _label(30, Color("#ffe9b0"), true)
	_place(clock_label, Control.PRESET_BOTTOM_RIGHT, Vector2(-MINI - 24, -MINI - 74), Vector2(MINI, 60))
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(clock_label)
	fps_label = Label.new()
	fps_label.position = Vector2(12, 8)
	fps_label.add_theme_font_size_override("font_size", 18)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 6)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fps_label)
	# --- prompts
	prompt_label = _label(26, Color.WHITE, true)
	_place(prompt_label, Control.PRESET_CENTER_BOTTOM, Vector2(-200, -190), Vector2(400, 40))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_label)
	toast_label = _label(30, Color("#ffd84a"), true)
	_place(toast_label, Control.PRESET_CENTER_TOP, Vector2(-300, 70), Vector2(600, 40))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast_label)
	# --- banner (death / busted)
	banner = TextureRect.new()
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(banner, Control.PRESET_CENTER, Vector2(-450, -110), Vector2(900, 220))
	banner.visible = false
	root.add_child(banner)
	# --- crosshair
	var ch := Crosshair.new()
	ch.name = "Crosshair"
	_place(ch, Control.PRESET_CENTER, Vector2(-32, -32), Vector2(64, 64))
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.visible = false
	root.add_child(ch)
	# --- pause menu
	pause_panel = _build_pause()
	root.add_child(pause_panel)

func _build_pause() -> Control:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, 0.6)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	var v := VBoxContainer.new()
	_place(v, Control.PRESET_CENTER, Vector2(-160, -190), Vector2(320, 380))
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	var t := _label(72, Color("#e8321c"), true)
	t.text = "PAUSED"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for entry in [["RESUME", "resume"], ["MAIN MENU", "menu"], ["QUIT GAME", "quit"]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(300, 52)
		b.add_theme_font_override("font", font_title)
		b.add_theme_font_size_override("font_size", 34)
		b.pressed.connect(_pause_action.bind(entry[1]))
		v.add_child(b)
	var hint := _label(18, Color(1, 1, 1, 0.8))
	hint.text = "WASD move  |  Shift sprint  |  Space jump / handbrake  |  E enter/exit car\nMouse look  |  LMB punch  |  L lights  |  H horn  |  R radio (hold R: wheel)  |  Backspace flip car  |  F11 fullscreen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	return c

func _pause_action(what: String) -> void:
	match what:
		"resume": set_paused(false)
		"menu":
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		"quit": get_tree().quit()

func set_paused(p: bool) -> void:
	get_tree().paused = p
	pause_panel.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and not pause_panel.visible and not Game.dead:
		_toggle_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and map_open:
		_toggle_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toast(text: String) -> void:
	toast_label.text = text
	toast_t = 3.0

func show_banner(name: String, secs := 3.0) -> void:
	banner.texture = load(UI + name + ".png") as Texture2D
	banner.visible = true
	await get_tree().create_timer(secs).timeout
	banner.visible = false

func _update_stars(n: int) -> void:
	for i in range(stars.size()):
		stars[i].texture = load(UI + ("icon_star_full" if i < n else "icon_star_empty") + ".png") as Texture2D

var map_pois: Array = []

func set_pois(list: Array) -> void:
	map_pois = list

func set_map(tex: Texture2D, half: float, mini: Texture2D = null) -> void:
	map_texture = tex
	city_half = half
	mini_mat.set_shader_parameter("map_tex", mini if mini != null else tex)
	mini_mat.set_shader_parameter("zoom", MINI_SPAN / (half * 2.0))   # the minimap shows about MINI_SPAN metres across

func _process(delta: float) -> void:
	toast_t = maxf(0.0, toast_t - delta)
	toast_label.modulate.a = clampf(toast_t, 0.0, 1.0)
	var car := Game.in_car as Car
	var heli := Game.in_heli as Chopper
	if heli != null:
		speed_label.text = "%d m" % roundi(maxf(heli.height_above_ground(), 0.0))
		car_label.text = "%s  %d km/h" % [heli.hud_name, roundi(heli.vel.length() * 3.6)]
		prompt_label.text = heli.hud_help
	elif car != null:
		speed_label.text = "%d km/h" % roundi(absf(car.speed_ms) * 3.6)
		car_label.text = String(car.def.name).to_upper()
		prompt_label.text = "E - exit" + ("  |  X - siren (%s)" % ("on" if car.siren_on else "off") + ("  |  Y - rear / side doors" if car.def.has("amb") else "") if car.def.has("emerg") else "")
	else:
		speed_label.text = ""
		car_label.text = ""
		var pl := Game.player as Player
		var near: Car = pl.nearest_car() if pl != null and is_instance_valid(pl) else null
		var at_shop: bool = pl != null and is_instance_valid(pl) and Game.in_car == null and GunShop.near_counter(pl.global_position)
		if at_shop and not Game.dead:
			prompt_label.text = "E - Browse Redline Ammo"
		elif pl != null and is_instance_valid(pl) and not Game.dead and pl.nearest_heli(7.0) != null:
			prompt_label.text = pl.nearest_heli(7.0).enter_text
		elif near != null and not Game.dead:
			prompt_label.text = "E - enter %s" % near.def.name
		elif pl != null and is_instance_valid(pl) and not Game.dead and pl.nearest_traffic() != null:
			prompt_label.text = "E / F - carjack"
		else:
			prompt_label.text = ""
	_fps_t -= delta
	if _fps_t <= 0.0 and fps_label != null:
		_fps_t = 0.25
		var f := Engine.get_frames_per_second()
		fps_label.text = "%d FPS" % f
		fps_label.add_theme_color_override("font_color", Color("#7dff7d") if f >= 55 else (Color("#ffd84a") if f >= 35 else Color("#ff5a4a")))
	if Game.weather != null and clock_label != null:
		var wx := Game.weather as Weather
		clock_label.text = "%s  %s" % [wx.clock_text(), Weather.STATE_NAMES[wx.state].to_upper()]
		if wx.night_amount() > 0.4:
			clock_label.text += "\n" + wx.moon_text().to_upper()
	armor_bar.value = Game.armor
	weapon_label.text = Game.weapon_text
	var chn := get_node_or_null("Control/Crosshair")
	if chn == null:
		for n in get_children():
			chn = n.get_node_or_null("Crosshair")
	if chn != null: chn.visible = Game.aiming and not get_tree().paused
	health_bar.value = Game.health
	# minimap follows the player / car
	var focus := Vector3.ZERO
	var heading := 0.0
	if car != null:
		focus = car.global_position
		heading = atan2(car.forward_dir().x, car.forward_dir().z)
	elif Game.player != null and is_instance_valid(Game.player):
		focus = (Game.player as Node3D).global_position
		heading = (Game.player as Player).face
	var u := 0.5 + focus.x / (city_half * 2.0)
	var v := 0.5 + focus.z / (city_half * 2.0)
	mini_mat.set_shader_parameter("center", Vector2(u, v))
	mini_arrow.rotation = -heading + PI
	_update_full_map()


# --- blood splatter on screen when the player takes a big hit ---
var _blood: ColorRect
var _blood_tw: Tween

func _on_hurt(amount: float) -> void:
	if amount < 5.0: return
	if _blood == null:
		_blood = ColorRect.new()
		_blood.set_anchors_preset(Control.PRESET_FULL_RECT)
		_blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
float h(vec2 p) { return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float edge = smoothstep(0.35, 0.95, length(uv - 0.5) * 1.5);
	float blobs = 0.0;
	for (int i = 0; i < 9; i++) {
		vec2 c = vec2(h(vec2(float(i), 1.0)), h(vec2(float(i), 7.0)));
		float r = 0.05 + 0.08 * h(vec2(float(i), 3.0));
		blobs = max(blobs, smoothstep(r, r * 0.55, length((uv - c) * vec2(1.6, 1.0))));
	}
	float a = clamp(edge * 0.8 + blobs * 0.85, 0.0, 1.0) * amount;
	COLOR = vec4(0.45, 0.0, 0.02, a);
}"""
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_blood.material = mat
		add_child(_blood)
	var m := _blood.material as ShaderMaterial
	m.set_shader_parameter("seed", randf() * 10.0)
	if _blood_tw and _blood_tw.is_valid(): _blood_tw.kill()
	m.set_shader_parameter("amount", clampf(amount / 25.0, 0.35, 1.0))
	_blood_tw = create_tween()
	_blood_tw.tween_interval(0.5)
	_blood_tw.tween_method(func(v: float): m.set_shader_parameter("amount", v), clampf(amount / 25.0, 0.35, 1.0), 0.0, 2.5)


# ---------------------------------------------------------------- full-screen map (M)
var map_open := false
var map_panel: Control
var map_arrow: TextureRect
var map_box: Control
const MAP_SIDE := 640.0
const MINI := 310.0           # minimap size on screen (px)
const MINI_SPAN := 200.0      # metres of the world it shows across

func _toggle_map() -> void:
	if map_panel == null:
		_build_map()
	map_open = not map_open
	map_panel.visible = map_open
	get_tree().paused = map_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_open else Input.MOUSE_MODE_CAPTURED

func _build_map() -> void:
	map_panel = Control.new()
	map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_panel.visible = false
	map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.06, 0.09, 0.93)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_panel.add_child(bg)
	var title := _label(54, Color("#ffd84a"), true)
	title.text = "REDLINE HEIGHTS"
	_place(title, Control.PRESET_CENTER_TOP, Vector2(-300, 10), Vector2(600, 60))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_panel.add_child(title)
	# the map itself, in a frame
	map_box = Control.new()
	_place(map_box, Control.PRESET_CENTER, Vector2(-MAP_SIDE * 0.5 - 150.0, -MAP_SIDE * 0.5 + 25.0), Vector2(MAP_SIDE, MAP_SIDE))
	map_panel.add_child(map_box)
	var border := ColorRect.new()
	border.color = Color("#e8d9a8")
	border.position = Vector2(-6, -6)
	border.size = Vector2(MAP_SIDE + 12, MAP_SIDE + 12)
	map_box.add_child(border)
	var tr := TextureRect.new()
	tr.texture = map_texture
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(MAP_SIDE, MAP_SIDE)
	map_box.add_child(tr)
	var markers := MapMarkers.new()
	markers.pois = map_pois
	markers.half = city_half
	markers.side = MAP_SIDE
	markers.size = Vector2(MAP_SIDE, MAP_SIDE)
	map_box.add_child(markers)
	map_arrow = _icon("map_player", 34)
	map_arrow.pivot_offset = Vector2(17, 17)
	map_box.add_child(map_arrow)
	# compass
	var compass := _label(40, Color.WHITE, true)
	compass.text = "N"
	compass.position = Vector2(MAP_SIDE - 44, 8)
	map_box.add_child(compass)
	var north := ColorRect.new()
	north.color = Color("#e8321c")
	north.position = Vector2(MAP_SIDE - 30, 56)
	north.size = Vector2(4, 26)
	map_box.add_child(north)
	# scale bar
	var bar_px := 200.0 / (city_half * 2.0) * MAP_SIDE
	var bar := ColorRect.new()
	bar.color = Color.WHITE
	bar.position = Vector2(14, MAP_SIDE - 26)
	bar.size = Vector2(bar_px, 4)
	map_box.add_child(bar)
	var bar_l := _label(22, Color.WHITE, true)
	bar_l.text = "200 m"
	bar_l.position = Vector2(14, MAP_SIDE - 56)
	map_box.add_child(bar_l)
	# legend
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 8)
	_place(legend, Control.PRESET_CENTER, Vector2(MAP_SIDE * 0.5 - 120.0, -MAP_SIDE * 0.5 + 40.0), Vector2(300, 520))
	map_panel.add_child(legend)
	var head := _label(32, Color("#ffd84a"), true)
	head.text = "LEGEND"
	legend.add_child(head)
	for entry in [["police", "Police Station", Color("#2b55c8"), "P"], ["hospital", "Hospital", Color("#e02a2a"), "+"], ["fire", "Fire Station", Color("#e8641c"), "F"],
			["gas", "Gas Station", Color("#e8b81c"), "G"], ["stadium", "Stadium", Color("#8a2a8a"), "S"], ["airport", "Airport", Color("#3a6a8a"), "A"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(30, 30)
		var sb := StyleBoxFlat.new()
		sb.bg_color = entry[2]
		sb.set_corner_radius_all(15)
		sb.border_color = Color.WHITE
		sb.set_border_width_all(3)
		dot.add_theme_stylebox_override("panel", sb)
		var g := _label(22, Color.WHITE, true)
		g.text = entry[3]
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.size = Vector2(30, 30)
		dot.add_child(g)
		row.add_child(dot)
		var t := _label(28, Color.WHITE, true)
		t.text = entry[1]
		row.add_child(t)
		legend.add_child(row)
	var you := HBoxContainer.new()
	you.add_theme_constant_override("separation", 12)
	var you_i := _icon("map_player", 30)
	you.add_child(you_i)
	var you_t := _label(28, Color.WHITE, true)
	you_t.text = "You"
	you.add_child(you_t)
	legend.add_child(you)
	var hint := _label(24, Color("#9fb4c4"), false)
	hint.text = "M / Esc - close map"
	_place(hint, Control.PRESET_CENTER_BOTTOM, Vector2(-150, -40), Vector2(300, 30))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_panel.add_child(hint)

func _update_full_map() -> void:
	if not map_open or map_arrow == null: return
	var car := Game.in_car as Car
	var focus := Vector3.ZERO
	var heading := 0.0
	if car != null:
		focus = car.global_position
		heading = atan2(car.forward_dir().x, car.forward_dir().z)
	elif Game.player != null and is_instance_valid(Game.player):
		focus = (Game.player as Node3D).global_position
		heading = (Game.player as Player).face
	var u := 0.5 + focus.x / (city_half * 2.0)
	var v := 0.5 + focus.z / (city_half * 2.0)
	map_arrow.position = Vector2(u, v) * MAP_SIDE - Vector2(17, 17)
	map_arrow.rotation = -heading + PI
