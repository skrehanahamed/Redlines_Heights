class_name GunMenu
extends CanvasLayer
## GTA V style gun-shop menu: the camera moves to the gun wall, a card list with icons on the left, big rotating preview in the
## middle, specification bars on the right, BACK / PURCHASE at the bottom.

const CATS := ["PISTOLS", "SMGS", "RIFLES", "SHOTGUNS", "SNIPERS", "HEAVY", "MELEE", "THROWN", "AMMO"]
const BLUE := Color(0.1, 0.55, 0.95)
const ROWS := 6
const CARD_H := 96.0

static var icons := {}              # gun id -> ImageTexture (rendered once)

var cat := 0
var sel := 0
var list: Array = []
var top := 0
var cards: Array[Control] = []
var tab_nodes: Array[Control] = []
var money_label: Label
var name_label: Label
var sub_label: Label
var stat_box: VBoxContainer
var status: Label
var buy_btn: Label
var holder: Node3D
var pack: Node3D
var preview_id := ""
var shop_cam: Camera3D
var prev_cam: Camera3D
var drag := false
var open := false
var hud_node: CanvasLayer
var hud_was := true

static func toggle_for(parent: Node) -> void:
	parent.add_child(GunMenu.new())

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	open = true
	pack = (load(GunShop.PACK) as PackedScene).instantiate() as Node3D
	prev_cam = get_viewport().get_camera_3d()
	if prev_cam != null:
		shop_cam = Camera3D.new()
		get_tree().current_scene.add_child(shop_cam)
		shop_cam.fov = 62.0
		var kp := GunShop.keeper_pos
		shop_cam.global_position = Vector3(kp.x - 1.6, kp.y + 1.7, kp.z + 3.4)
		shop_cam.look_at(Vector3(kp.x + 0.6, kp.y + 1.45, kp.z - 4.0), Vector3.UP)
		shop_cam.make_current()
	var scn := get_tree().current_scene
	if scn.get("hud") is CanvasLayer:
		hud_node = scn.get("hud")
		hud_was = hud_node.visible
		hud_node.visible = false
	_build_ui()
	_refresh()
	_render_icons()

func _exit_tree() -> void:
	if is_instance_valid(pack): pack.free()
	if is_instance_valid(shop_cam): shop_cam.queue_free()

func _grad(left: bool) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.88), Color(0, 0, 0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0) if left else Vector2(1, 0)
	gt.fill_to = Vector2(1, 0) if left else Vector2(0, 0)
	gt.width = 256
	gt.height = 4
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _build_ui() -> void:
	# laid out for 1920x1080 and scaled to the window
	var vs := get_viewport().get_visible_rect().size
	var sc := minf(vs.x / 1920.0, vs.y / 1080.0)
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	root.scale = Vector2.ONE * sc
	root.position = Vector2((vs.x - 1920.0 * sc) * 0.5, (vs.y - 1080.0 * sc) * 0.5)
	add_child(root)
	# the shop behind the menu is blurred (and darkened towards the edges) so the gun is the only sharp thing
	var blur := ColorRect.new()
	blur.size = Vector2(1920, 1080)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap, repeat_disable;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(scr, uv, 3.5).rgb * 0.4;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		c += textureLod(scr, uv + vec2(cos(a), sin(a)) * 0.012, 3.0).rgb * 0.075;
	}
	float v = smoothstep(0.25, 0.85, distance(uv, vec2(0.5, 0.5)));
	COLOR = vec4(c * mix(0.75, 0.45, v), 1.0);
}"""
	var bm := ShaderMaterial.new()
	bm.shader = sh
	blur.material = bm
	root.add_child(blur)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.0)
	shade.size = Vector2(1920, 1080)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var gl := _grad(true)
	gl.size = Vector2(620, 1080)
	root.add_child(gl)
	var gr := _grad(false)
	gr.position = Vector2(1300, 0)
	gr.size = Vector2(620, 1080)
	root.add_child(gr)
	# preview
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size = Vector2(1920, 1080)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.position = Vector3(0, 0, 2.6)
	cam.fov = 40.0
	var lt := DirectionalLight3D.new()
	lt.rotation_degrees = Vector3(-30, 25, 0)
	lt.light_energy = 1.8
	vp.add_child(lt)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.9
	vp.add_child(env)
	holder = Node3D.new()
	vp.add_child(holder)
	# left column
	var left := VBoxContainer.new()
	left.position = Vector2(30, 70)
	left.custom_minimum_size = Vector2(480, 0)
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)
	left.add_child(_label("WEAPONS", 52, BLUE))
	var tabs := HFlowContainer.new()
	tabs.custom_minimum_size = Vector2(480, 0)
	tabs.add_theme_constant_override("h_separation", 12)
	left.add_child(tabs)
	for i in CATS.size():
		var t := _label(CATS[i], 18, Color(0.6, 0.6, 0.6))
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		t.gui_input.connect(_tab_input.bind(i))
		tabs.add_child(t)
		tab_nodes.append(t)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.3)
	line.custom_minimum_size = Vector2(480, 2)
	left.add_child(line)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	lv.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_child(lv)
	for i in ROWS:
		var c := PanelContainer.new()
		c.custom_minimum_size = Vector2(480, CARD_H)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.gui_input.connect(_card_input.bind(i))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(h)
		var ic := TextureRect.new()
		ic.name = "icon"
		ic.custom_minimum_size = Vector2(110, 80)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var tv := VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tv)
		var n := _label("", 24, Color.WHITE)
		n.name = "name"
		tv.add_child(n)
		var p := _label("", 17, Color(0.75, 0.75, 0.75))
		p.name = "price"
		tv.add_child(p)
		lv.add_child(c)
		cards.append(c)
	# right column
	var right := VBoxContainer.new()
	right.position = Vector2(1410, 70)
	right.custom_minimum_size = Vector2(480, 0)
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)
	name_label = _label("", 46, BLUE)
	right.add_child(name_label)
	sub_label = _label("", 22, Color.WHITE)
	right.add_child(sub_label)
	var line2 := ColorRect.new()
	line2.color = Color(1, 1, 1, 0.3)
	line2.custom_minimum_size = Vector2(480, 2)
	right.add_child(line2)
	right.add_child(_label("SPECIFICATIONS", 26, Color.WHITE))
	stat_box = VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 12)
	right.add_child(stat_box)
	money_label = _label("", 34, Color(0.5, 0.9, 0.5))
	money_label.position = Vector2(1700, 10)
	root.add_child(money_label)
	# bottom
	status = _label("", 22, Color(1, 0.85, 0.3))
	status.position = Vector2(780, 880)
	root.add_child(status)
	var bar := HBoxContainer.new()
	bar.position = Vector2(740, 960)
	bar.add_theme_constant_override("separation", 40)
	root.add_child(bar)
	var back := _button("✕  BACK")
	back.gui_input.connect(func(e): if _clicked(e): _close())
	bar.add_child(back)
	buy_btn = _button("✓  PURCHASE")
	buy_btn.gui_input.connect(func(e): if _clicked(e): _buy())
	bar.add_child(buy_btn)
	root.add_child(_label("W/S select    A/D category    ENTER purchase    ESC back    mouse wheel scrolls    hold RMB to rotate", 15, Color(0.8, 0.8, 0.8)))
	root.get_child(root.get_child_count() - 1).position = Vector2(30, 1040)

func _button(t: String) -> Label:
	var b := _label(t, 28, Color.WHITE)
	b.custom_minimum_size = Vector2(200, 56)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.6)
	st.border_color = Color(1, 1, 1, 0.5)
	st.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", st)
	return b

static func _clicked(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT

func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _tab_input(ev: InputEvent, i: int) -> void:
	if _clicked(ev):
		cat = i
		sel = 0
		top = 0
		_refresh()

func _card_input(ev: InputEvent, i: int) -> void:
	if _clicked(ev):
		var idx := top + i
		if idx < list.size():
			sel = idx
			_refresh()

## Stat bars (0..1) per gun: derived from its class and price so heavier, dearer guns hit harder.
func _stats(it: Dictionary) -> Array:
	var c := String(it.cat)
	var pr := clampf(float(it.price) / 9000.0, 0.0, 1.0)
	match c:
		"PISTOLS": return [["DAMAGE", 0.2 + pr * 1.5, "%d HP" % (14 + int(pr * 40))], ["FIRE RATE", 0.35 + pr * 0.6, "%d RPM" % (180 + int(pr * 300))], ["CLIP SIZE", 0.25 + pr * 0.5, "%d" % (8 + int(pr * 12))], ["RANGE", 0.25 + pr * 0.8, "%d M" % (60 + int(pr * 80))]]
		"SMGS": return [["DAMAGE", 0.2 + pr * 1.2, "%d HP" % (12 + int(pr * 30))], ["FIRE RATE", 0.7 + pr * 0.3, "%d RPM" % (700 + int(pr * 600))], ["CLIP SIZE", 0.4 + pr * 0.5, "%d" % (25 + int(pr * 40))], ["RANGE", 0.3 + pr * 0.9, "%d M" % (70 + int(pr * 80))]]
		"RIFLES": return [["DAMAGE", 0.35 + pr * 0.9, "%d HP" % (20 + int(pr * 30))], ["FIRE RATE", 0.6 + pr * 0.3, "%d RPM" % (600 + int(pr * 300))], ["CLIP SIZE", 0.4 + pr * 0.4, "%d" % (20 + int(pr * 20))], ["RANGE", 0.6 + pr * 0.4, "%d M" % (180 + int(pr * 100))]]
		"SHOTGUNS": return [["DAMAGE", 0.6 + pr * 0.4, "%d HP" % (60 + int(pr * 60))], ["FIRE RATE", 0.2 + pr * 0.6, "%d RPM" % (80 + int(pr * 200))], ["CLIP SIZE", 0.15 + pr * 0.5, "%d" % (4 + int(pr * 16))], ["RANGE", 0.2, "40 M"]]
		"SNIPERS": return [["DAMAGE", 0.7 + pr * 0.3, "%d HP" % (90 + int(pr * 90))], ["FIRE RATE", 0.1 + pr * 0.1, "%d RPM" % (30 + int(pr * 20))], ["CLIP SIZE", 0.1 + pr * 0.1, "%d" % (5 + int(pr * 5))], ["RANGE", 0.95, "800 M"]]
		"HEAVY": return [["DAMAGE", 0.5 + pr * 0.4, "%d HP" % (30 + int(pr * 20))], ["FIRE RATE", 0.8 + pr * 0.2, "%d RPM" % (600 + int(pr * 3000))], ["CLIP SIZE", 0.9, "%d" % int(it.ammo)], ["RANGE", 0.7, "300 M"]]
	if c == "MELEE": return [["DAMAGE", clampf(float(it.price) / 350.0, 0.2, 1.0), "%d HP" % (20 + int(float(it.price) / 8.0))], ["ATTACK SPEED", clampf(1.0 - float(it.price) / 450.0, 0.2, 0.9), "FAST" if float(it.price) < 200.0 else "MEDIUM"], ["REACH", clampf(float(it.price) / 400.0, 0.2, 0.9), "%.1f M" % (0.6 + float(it.price) / 400.0)]]
	if c == "THROWN": return [["BLAST DAMAGE", 0.9 if int(it.price) > 150 else 0.6, "%d HP" % (120 if int(it.price) > 150 else 70)], ["RADIUS", 0.6 if int(it.price) > 150 else 0.4, "%d M" % (8 if int(it.price) > 150 else 5)], ["IN A SET OF", 0.3, "%d" % int(it.ammo)]]
	return [["ROUNDS", 0.6, "%d" % int(it.ammo)]]

func _refresh() -> void:
	list = GunShop.items.filter(func(it): return String(it.cat) == CATS[cat])
	sel = clampi(sel, 0, maxi(0, list.size() - 1))
	if sel < top: top = sel
	if sel >= top + ROWS: top = sel - ROWS + 1
	top = clampi(top, 0, maxi(0, list.size() - ROWS))
	money_label.text = "$%d" % Game.money
	for i in tab_nodes.size():
		var n := 0
		for it in GunShop.items:
			if String(it.cat) == CATS[i]: n += 1
		(tab_nodes[i] as Label).text = "%s %d" % [CATS[i], n]
		(tab_nodes[i] as Label).add_theme_color_override("font_color", Color.WHITE if i == cat else Color(0.55, 0.55, 0.55))
	for i in ROWS:
		var c := cards[i]
		var idx := top + i
		c.visible = idx < list.size()
		if not c.visible: continue
		var it: Dictionary = list[idx]
		var on := idx == sel
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.25, 0.25, 0.28, 0.85) if on else Color(0.12, 0.12, 0.14, 0.75)
		st.border_color = BLUE
		st.border_width_left = 5 if on else 0
		st.set_content_margin_all(8)
		c.add_theme_stylebox_override("panel", st)
		var owned := int(Game.guns_owned.get(String(it.id), 0)) > 0
		(c.find_child("name", true, false) as Label).text = String(it.name).to_upper() + ("   (OWNED)" if owned else "")
		(c.find_child("price", true, false) as Label).text = "Store Price: $%d" % int(it.price)
		(c.find_child("icon", true, false) as TextureRect).texture = icons.get(String(it.id))
	if list.is_empty(): return
	var cur: Dictionary = list[sel]
	name_label.text = String(cur.name).to_upper()
	sub_label.text = "Store Price: $%d" % int(cur.price)
	var afford := Game.money >= int(cur.price)
	buy_btn.add_theme_color_override("font_color", Color.WHITE if afford else Color(0.5, 0.5, 0.5))
	for ch in stat_box.get_children(): ch.queue_free()
	for s in _stats(cur):
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var hb := HBoxContainer.new()
		var a := _label(s[0], 20, Color.WHITE)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(a)
		hb.add_child(_label(s[2], 20, Color.WHITE))
		row.add_child(hb)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(480, 12)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = minf(float(s[1]), 1.0)
		var fg := StyleBoxFlat.new()
		fg.bg_color = Color.WHITE
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.25)
		bar.add_theme_stylebox_override("fill", fg)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)
		stat_box.add_child(row)
	_set_preview(cur)

func _set_preview(it: Dictionary) -> void:
	if preview_id == String(it.id): return
	preview_id = String(it.id)
	for c in holder.get_children(): c.queue_free()
	holder.rotation = Vector3.ZERO
	if preview_id == "ammo":
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.3, 0.3)
		m.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.3, 0.2)
		m.material_override = mat
		holder.add_child(m)
		holder.scale = Vector3.ONE
		return
	var made := GunShop.make_extra(preview_id) if preview_id.begins_with("x_") else GunShop.make_gun(pack, preview_id)
	if made.is_empty(): return
	var node: Node3D = made.node
	var sz: Vector3 = made.bb.size
	holder.scale = Vector3.ONE * (0.75 / maxf(maxf(sz.x, sz.y), maxf(sz.z, 0.01)))
	if preview_id.begins_with("x_"):
		# melee weapons and throwables stand upright on the display and turn around their own axis
		var up := Node3D.new()
		up.add_child(node)
		up.rotation.z = -PI * 0.5 if String(it.cat) == "THROWN" else PI * 0.5
		holder.scale = Vector3.ONE * ((0.8 if String(it.cat) == "THROWN" else 1.1) / maxf(maxf(sz.x, sz.y), maxf(sz.z, 0.01)))
		holder.add_child(up)
		return
	node.rotation.y = 0.0 if sz.x >= sz.z else PI * 0.5
	holder.add_child(node)

## Renders one small picture per gun (once, kept for later visits) for the cards.
func _render_icons() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(220, 160)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.position = Vector3(0, 0, 2.0)
	cam.fov = 36.0
	var lt := DirectionalLight3D.new()
	lt.rotation_degrees = Vector3(-30, 25, 0)
	lt.light_energy = 1.8
	vp.add_child(lt)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	vp.add_child(env)
	var pk := (load(GunShop.PACK) as PackedScene).instantiate() as Node3D
	for it in GunShop.items:
		var id := String(it.id)
		if icons.has(id) or id == "ammo": continue
		var made := GunShop.make_extra(id) if id.begins_with("x_") else GunShop.make_gun(pk, id)
		if made.is_empty(): continue
		var node: Node3D = made.node
		var sz: Vector3 = made.bb.size
		var holder2 := Node3D.new()
		holder2.scale = Vector3.ONE * (1.5 / maxf(maxf(sz.x, sz.y), maxf(sz.z, 0.01)))
		node.rotation.y = 0.0 if sz.x >= sz.z else PI * 0.5
		holder2.add_child(node)
		vp.add_child(holder2)
		for i in 3: await get_tree().process_frame
		if not is_instance_valid(self) or not open: break
		icons[id] = ImageTexture.create_from_image(vp.get_texture().get_image())
		holder2.queue_free()
		_refresh()
	pk.free()
	if is_instance_valid(vp): vp.queue_free()

func _process(delta: float) -> void:
	if is_instance_valid(holder) and not drag: holder.rotation.y += delta * 0.7

static func _key(e: InputEvent, k: Key) -> bool:
	return e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == k

func _unhandled_input(event: InputEvent) -> void:
	if not open: return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: drag = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _move(1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: _move(-1)
		return
	if event is InputEventMouseMotion and drag:
		holder.rotation.y += event.relative.x * 0.01
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		_close()
	elif event.is_action_pressed("ui_down") or _key(event, KEY_S): _move(1)
	elif event.is_action_pressed("ui_up") or _key(event, KEY_W): _move(-1)
	elif event.is_action_pressed("ui_right") or _key(event, KEY_D):
		cat = (cat + 1) % CATS.size()
		sel = 0
		top = 0
		_refresh()
	elif event.is_action_pressed("ui_left") or _key(event, KEY_A):
		cat = (cat + CATS.size() - 1) % CATS.size()
		sel = 0
		top = 0
		_refresh()
	elif event.is_action_pressed("ui_accept"):
		_buy()

func _shift_cat(d: int) -> void:
	cat = (cat + d + CATS.size()) % CATS.size()
	sel = 0
	top = 0
	_refresh()

func _move(d: int) -> void:
	sel = clampi(sel + d, 0, maxi(0, list.size() - 1))
	_refresh()

func _buy() -> void:
	if list.is_empty(): return
	var it: Dictionary = list[sel]
	var before := Game.money
	GunShop.buy(it)
	var ok := Game.money < before
	status.text = ("PURCHASED  %s" % String(it.name).to_upper()) if ok else "NOT ENOUGH MONEY"
	status.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if ok else Color(0.95, 0.3, 0.3))
	_refresh()

func _close() -> void:
	if not open: return
	open = false
	if is_instance_valid(hud_node): hud_node.visible = hud_was
	if is_instance_valid(prev_cam): prev_cam.make_current()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
