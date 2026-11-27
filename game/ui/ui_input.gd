extends RefCounted

## 기존 진행이 선택 화면을 거치지 않아도 같은 UI 입력을 사용한다.
static func ensure() -> void:
	var mappings := {"ui_accept": JOY_BUTTON_A, "ui_left": JOY_BUTTON_DPAD_LEFT,
		"ui_right": JOY_BUTTON_DPAD_RIGHT, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN}
	for action in mappings:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = mappings[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)

	for action in ["camp_left","camp_right","camp_up","camp_down"]:
		if not InputMap.has_action(action): InputMap.add_action(action,.2)
		var keys: Array = {"camp_left":[KEY_A,KEY_LEFT],"camp_right":[KEY_D,KEY_RIGHT],"camp_up":[KEY_W,KEY_UP],"camp_down":[KEY_S,KEY_DOWN]}[action]
		for key in keys:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)
		var motion := InputEventJoypadMotion.new()
		motion.device = -1
		motion.axis = JOY_AXIS_LEFT_X if action in ["camp_left","camp_right"] else JOY_AXIS_LEFT_Y
		motion.axis_value = -1 if action in ["camp_left","camp_up"] else 1
		if not InputMap.action_has_event(action,motion): InputMap.action_add_event(action,motion)

		var dpad := InputEventJoypadButton.new()
		dpad.device = -1
		dpad.button_index = {"camp_left":JOY_BUTTON_DPAD_LEFT,"camp_right":JOY_BUTTON_DPAD_RIGHT,"camp_up":JOY_BUTTON_DPAD_UP,"camp_down":JOY_BUTTON_DPAD_DOWN}[action]
		if not InputMap.action_has_event(action,dpad): InputMap.action_add_event(action,dpad)
