class_name DevMode
extends CanvasLayer
## Developer mode. F1 help | F3 stats overlay | F4 free-fly camera | F5 god mode | F6 render debug view | F7 teleport to next place |
## F8 fast time (x40) | F9 spawn a car in front | F10 all weapons | G weapon grip editor | B weather | N skip 2 h.

const VIEWS := [Viewport.DEBUG_DRAW_DISABLED, Viewport.DEBUG_DRAW_UNSHADED, Viewport.DEBUG_DRAW_OVERDRAW, Viewport.DEBUG_DRAW_WIREFRAME]
const VIEW_NAMES := ["normal", "unshaded", "overdraw", "wireframe"]

var label: Label
var help: Label
var show_stats := false
var show_help := false
var god := false
var fly := false
var fast_time := false
var view_i := 0
var poi_i := 0
var fly_cam: Camera3D
var fly_yaw := 0.0
var fly_pitch := 0.0
var _prev_cam: Camera3D

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_debug_generate_wireframes(true)
	label = Label.new()
	label.position = Vector2(14, 10)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#c8ffb0"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.visible = false
	add_child(label)
	help = Label.new()
	help.position = Vector2(14, 300)
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color("#ffe9a0"))
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 6)
	help.text = "DEV MODE\\nF1 help   F3 stats   F4 free camera (WASD, Q/E, Shift = fast, mouse look)\\nF5 god mode   F6 debug view   F7 teleport to next place   F8 fast time x40\\nF9 spawn a car   F10 all weapons   G grip editor   B weather   N skip 2 hours".replace("\\n", "\n")
	help.visible = false
	add_child(help)
	fly_cam = Camera3D.new()
	fly_cam.far = 5000.0
	add_child(fly_cam)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and fly:
		fly_yaw -= event.relative.x * 0.003
		fly_pitch = clampf(fly_pitch - event.relative.y * 0.003, -1.5, 1.5)
		return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_F1: show_help = not show_help
		KEY_F3: show_stats = not show_stats
		KEY_F4: _toggle_fly()
		KEY_F5:
			god = not god
			Game.message.emit("God mode %s" % ("ON" if god else "off"))
		KEY_F6:
			view_i = (view_i + 1) % VIEWS.size()
			get_viewport().debug_draw = VIEWS[view_i]
			Game.message.emit("View: %s" % VIEW_NAMES[view_i])
		KEY_F7: _teleport()
		KEY_F8:
			fast_time = not fast_time
			Game.message.emit("Fast time %s" % ("ON" if fast_time else "off"))
		KEY_F9: _spawn_car()
		KEY_F10: _give_all_weapons()
		KEY_G:
			var ge := get_tree().current_scene.get_node_or_null("GripEditorNode")
			if ge == null:
				var g := GripEditor.new()
				g.name = "GripEditorNode"
				get_tree().current_scene.add_child(g)
	help.visible = show_help
	label.visible = show_stats

func _toggle_fly() -> void:
	fly = not fly
	var pl := Game.player as Node3D
	if fly:
		_prev_cam = get_viewport().get_camera_3d()
		fly_cam.global_transform = _prev_cam.global_transform if _prev_cam != null else fly_cam.global_transform
		var e := fly_cam.global_transform.basis.get_euler()
		fly_yaw = e.y
		fly_pitch = e.x
		fly_cam.current = true
		if pl != null: pl.set_physics_process(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		if _prev_cam != null and is_instance_valid(_prev_cam): _prev_cam.current = true
		if pl != null: pl.set_physics_process(true)

func _teleport() -> void:
	var pois: Array = Game.world.pois
	if pois.is_empty(): return
	var p: Dictionary = pois[poi_i % pois.size()]
	poi_i += 1
	var pos := Vector3(p.pos.x, 0.0, p.pos.z)
	pos.y = maxf(CityData.height_at(pos.x, pos.z), 0.0) + 3.0
	if fly:
		fly_cam.global_position = pos + Vector3(0, 40, 60)
	elif Game.in_heli != null:
		(Game.in_heli as Node3D).global_position = pos + Vector3(0, 30, 0)
	elif Game.in_car != null:
		(Game.in_car as Car).global_position = pos + Vector3(0, 1.0, 0)
		(Game.in_car as Car).linear_velocity = Vector3.ZERO
	elif Game.player != null:
		(Game.player as Node3D).global_position = pos
	Game.message.emit("Teleport: %s" % p.name)

## Every gun, melee weapon and throwable with plenty of ammo; switch with Q.
func _give_all_weapons() -> void:
	for g in GunShop.GUNS:
		Game.guns_owned[String(g[0])] = maxi(int(Game.guns_owned.get(String(g[0]), 0)), 500)
	for e in GunShop.EXTRAS:
		Game.guns_owned[String(e[0])] = maxi(int(Game.guns_owned.get(String(e[0]), 0)), 1 if String(e[7]) == "MELEE" else 20)
	Game.ammo_reserve = maxi(Game.ammo_reserve, 5000)
	Game.message.emit("DEV: all weapons given - press Q to switch")

func _spawn_car() -> void:
	var pl := Game.player as Node3D
	if pl == null: return
	var kinds := Car.DEFS.keys()
	var car := Car.new()
	Game.world.get_parent().add_child(car)
	var fwd := Vector3(sin((Game.player as Player).face), 0, cos((Game.player as Player).face))
	car.global_position = pl.global_position + fwd * 6.0 + Vector3(0, 1.2, 0)
	car.rotation.y = (Game.player as Player).face
	car.setup(kinds[randi() % kinds.size()], "", false)

func _process(delta: float) -> void:
	if god: Game.health = 100.0
	if fast_time and Game.weather != null:
		(Game.weather as Weather).hour = fmod((Game.weather as Weather).hour + delta * 40.0 * 24.0 / Weather.DAY_SECONDS, 24.0)
	if fly:
		var b := Basis.from_euler(Vector3(fly_pitch, fly_yaw, 0.0))
		var v := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): v -= b.z
		if Input.is_physical_key_pressed(KEY_S): v += b.z
		if Input.is_physical_key_pressed(KEY_A): v -= b.x
		if Input.is_physical_key_pressed(KEY_D): v += b.x
		if Input.is_physical_key_pressed(KEY_E): v += Vector3.UP
		if Input.is_physical_key_pressed(KEY_Q): v -= Vector3.UP
		var speed := 160.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 30.0
		fly_cam.global_transform = Transform3D(b, fly_cam.global_position + v * speed * delta)
	if label.visible:
		label.text = _stats()

func _stats() -> String:
	var fp := Game.get_focus_pos()
	var zn := ["sea", "beach", "urban", "downtown", "park", "desert", "mountain", "airport", "industrial", "lake", "stadium"]
	var wx := Game.weather as Weather
	var t := get_tree()
	var pl := Game.player as Player
	var lines := [
		"FPS %d   frame %.1f ms   draw calls %d   objects %d   vertices %dk" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)) / 1000],
		"pos %.0f, %.0f, %.0f   ground %.1f   zone %s   water %s" % [fp.x, fp.y, fp.z, CityData.height_at(fp.x, fp.z), zn[CityData.zone_at(fp.x, fp.z)], str(CityData.is_water(fp.x, fp.z))],
		"player state %s   health %.0f   wanted %d   money %d   swimming %s   in car %s" % [str(pl.state) if pl != null else "-", Game.health, Game.wanted, Game.money, str(pl.swimming) if pl != null else "-", str(Game.in_car != null)],
		"peds %d   cops on foot %d   parked/player cars %d   traffic %d   police cars %d" % [t.get_nodes_in_group("peds").size(), t.get_nodes_in_group("cops").size(), t.get_nodes_in_group("cars").size(), t.get_nodes_in_group("traffic").size(), t.get_nodes_in_group("police").size()],
		"time %s   weather %s   rain %.2f   storm %.2f   night %.2f" % [wx.clock_text() if wx != null else "-", wx.state if wx != null else "-", wx.rain if wx != null else 0.0, wx.storm if wx != null else 0.0, wx.night_amount() if wx != null else 0.0],
		"god %s   free cam %s   view %s   fast time %s   (F1 = keys)" % [str(god), str(fly), VIEW_NAMES[view_i], str(fast_time)],
	]
	return "\n".join(lines)
