class_name InputSetup
## Sets up the controls in code so they're easy to read and change.
## Keyboard and an Xbox-style gamepad both work.


static func ensure_actions() -> void:
	_action("accelerate", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("reverse", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action("steer_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("steer_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("brake", [_key(KEY_SPACE), _button(JOY_BUTTON_B)])
	_action("reset_vehicle", [_key(KEY_R), _button(JOY_BUTTON_Y)])
	_action("next_vehicle", [_key(KEY_TAB), _button(JOY_BUTTON_BACK)])
	_action("garage", [_key(KEY_G), _button(JOY_BUTTON_START)])


static func _action(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for e in events:
		InputMap.action_add_event(action, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
