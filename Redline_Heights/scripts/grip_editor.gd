class_name GripEditor
extends CanvasLayer
## Dev tool (G): pick a weapon and a pose, drag the weapon into the right place in the hand, save. The offsets go to
## data/weapon_grips.json and are applied on top of the automatic hold.
##  Tab / Shift+Tab  next / previous weapon      1 idle  2 aim  3 run  4 swing (melee)
##  Left mouse drag  move the weapon (screen plane)      Ctrl + left drag  rotate      mouse wheel  move forward / back
##  Middle drag      turn the camera      arrows / PgUp PgDn  fine move      Shift + arrows  fine rotate      R reset pose
##  S save to file      G close

const POSES := ["idle", "aim", "run", "swing"]
var player: Player
var ids: Array = []
var idx := 0
var pose_i := 0
var label: Label
var dragging := false
var rotating := false
var orbit := false

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = Game.player as Player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for g in GunShop.GUNS: ids.append(String(g[0]))
	for e in GunShop.EXTRAS: ids.append(String(e[0]))
	label = Label.new()
	label.position = Vector2(14, 200)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#c8ffb0"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	Game.ammo_reserve = 5000
	for id in ids: Game.guns_owned[id] = maxi(int(Game.guns_owned.get(id, 0)), 99)
	_apply()

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.edit_pose = ""
		player.force_aim = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply() -> void:
	var id := String(ids[idx])
	player.equip(id)
	player.edit_pose = POSES[pose_i]
	player.force_aim = POSES[pose_i] == "aim" and player.weapon == 1
	player.grip_off = Weapons.grip_offset(id, POSES[pose_i])

func _cur_id() -> String:
	return String(ids[idx])

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	player.velocity = Vector3.ZERO
	var o := player.grip_off.origin
	var e := player.grip_off.basis.get_euler()
	var saved := Weapons.grips().has("%s|%s" % [_cur_id(), POSES[pose_i]])
	label.text = "GRIP EDITOR   %s  /  %s %s\noffset  x %.3f  y %.3f  z %.3f   rot  %.1f  %.1f  %.1f\nTab weapon   1 idle  2 aim  3 run  4 swing   drag = move   Ctrl+drag = rotate   wheel = forward/back\nMiddle drag = camera   arrows/PgUp/PgDn = nudge (Shift = rotate)   R reset   S SAVE   G close" % [
		_cur_id(), POSES[pose_i].to_upper(), "(saved)" if saved else "(not saved)", o.x, o.y, o.z, rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)]

func _nudge(world_delta: Vector3) -> void:
	player.grip_off.origin += player.held_base.basis.inverse() * world_delta

func _rotate(axis_world: Vector3, ang: float) -> void:
	var r := Basis(axis_world.normalized(), ang)
	var base_b := player.held_base.basis
	var cur := base_b * player.grip_off.basis
	var nb := base_b.inverse() * (r * cur)
	player.grip_off.basis = nb.orthonormalized()

func _unhandled_input(ev: InputEvent) -> void:
	var cam := Game.camera as Camera3D
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var step := 0.005
		var shift := Input.is_key_pressed(KEY_SHIFT)
		match ev.keycode:
			KEY_G:
				queue_free()
				get_viewport().set_input_as_handled()
				return
			KEY_TAB:
				idx = (idx + (ids.size() - 1 if shift else 1)) % ids.size()
				_apply()
			KEY_1, KEY_2, KEY_3, KEY_4:
				pose_i = int(ev.keycode - KEY_1)
				_apply()
			KEY_R:
				player.grip_off = Transform3D.IDENTITY
			KEY_S:
				Weapons.set_grip(_cur_id(), POSES[pose_i], player.grip_off)
				Weapons.save_grips()
				Game.message.emit("Grip saved: %s / %s" % [_cur_id(), POSES[pose_i]])
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN:
				if cam == null: return
				var d := Vector3.ZERO
				match ev.keycode:
					KEY_LEFT: d = -cam.global_transform.basis.x
					KEY_RIGHT: d = cam.global_transform.basis.x
					KEY_UP: d = cam.global_transform.basis.y
					KEY_DOWN: d = -cam.global_transform.basis.y
					KEY_PAGEUP: d = -cam.global_transform.basis.z
					KEY_PAGEDOWN: d = cam.global_transform.basis.z
				if shift:
					_rotate(cam.global_transform.basis.y if ev.keycode in [KEY_LEFT, KEY_RIGHT] else (cam.global_transform.basis.x if ev.keycode in [KEY_UP, KEY_DOWN] else -cam.global_transform.basis.z), (0.03 if ev.keycode in [KEY_RIGHT, KEY_DOWN, KEY_PAGEUP] else -0.03))
				else:
					_nudge(d * step)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			dragging = ev.pressed
			rotating = ev.pressed and Input.is_key_pressed(KEY_CTRL)
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			orbit = ev.pressed
		elif ev.pressed and cam != null and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_nudge(-cam.global_transform.basis.z * (0.01 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else -0.01))
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion and cam != null:
		if orbit:
			cam.yaw -= ev.relative.x * 0.006
			cam.pitch = clampf(cam.pitch + ev.relative.y * 0.006, -0.15, 1.25)
		elif dragging and rotating:
			_rotate(cam.global_transform.basis.y, ev.relative.x * 0.01)
			_rotate(cam.global_transform.basis.x, ev.relative.y * 0.01)
		elif dragging:
			_nudge((cam.global_transform.basis.x * ev.relative.x - cam.global_transform.basis.y * ev.relative.y) * 0.0025)
		get_viewport().set_input_as_handled()
