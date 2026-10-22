extends Node
## All key bindings in one place (registered in code so they are easy to read and change).

func _ready() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("sprint", [KEY_SHIFT])
	_key("walk_slow", [KEY_CTRL])
	_key("jump", [KEY_SPACE])
	_key("handbrake", [KEY_SPACE])
	_key("interact", [KEY_E, KEY_F])
	_key("toggle_lights", [KEY_L])
	_key("horn", [KEY_H])
	_key("radio", [KEY_R])
	_key("reset_car", [KEY_BACKSPACE])
	_key("pause", [KEY_ESCAPE])
	_key("weapon_next", [KEY_Q])
	_key("reload", [KEY_R])
	_key("siren", [KEY_X])
	_key("rear_doors", [KEY_Y])
	_key("map", [KEY_M])
	_key("weather_next", [KEY_B])
	_key("time_skip", [KEY_N])
	_key("moon_next", [KEY_K])
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)

func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)

func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
