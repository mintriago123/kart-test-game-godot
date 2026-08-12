extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tokens_and_input_modes()
	await _test_settings_screen()
	await _test_pause_contract()
	_test_reduced_motion_persistence()
	quit(1 if failed else 0)


func _test_tokens_and_input_modes() -> void:
	_check(UiTokens.TOUCH_TARGET >= 48, "Shared controls preserve the 48 px touch target.")
	var controller := UiInputModeController.new()
	root.add_child(controller)
	controller.set_mode(UiInputModeController.GAMEPAD)
	_check(controller.mode == &"gamepad" and controller.get_prompt(&"ui_accept") == "A", "Input mode exposes gamepad prompts.")
	controller.set_mode(UiInputModeController.KEYBOARD)
	_check(controller.get_prompt(&"ui_cancel") == "ESC", "Input mode exposes keyboard prompts.")
	controller.queue_free()


func _test_settings_screen() -> void:
	var screen := SettingsScreen.new()
	root.add_child(screen)
	await process_frame
	var settings := GameSettings.new()
	settings.ui_reduced_motion = true
	screen.apply_snapshot(settings)
	_check(screen._controls.size() == 10, "Reusable settings screen exposes every settings group.")
	_check((screen._controls.reduced_motion as CheckButton).button_pressed, "Settings snapshot includes reduced motion.")
	var emitted := [false]
	screen.reduced_motion_changed.connect(func(_enabled: bool) -> void: emitted[0] = true)
	(screen._controls.reduced_motion as CheckButton).toggled.emit(false)
	_check(emitted[0], "Reduced motion changes emit through the reusable screen.")
	screen.queue_free()
	await process_frame


func _test_pause_contract() -> void:
	var overlay := RaceFlowOverlay.new()
	root.add_child(overlay)
	overlay.build_interface()
	await process_frame
	_check(overlay.has_signal("resume_requested") and overlay.has_signal("restart_requested"), "Pause overlay preserves resume and restart contracts.")
	_check(overlay.has_signal("settings_requested") and overlay.has_signal("controls_requested") and overlay.has_signal("quit_requested"), "Pause overlay exposes settings, controls, and quit contracts.")
	var actions := overlay.pause_overlay.find_children("*", "Button", true, false)
	var touch_safe := actions.size() == 5
	for action in actions:
		touch_safe = touch_safe and (action as Button).custom_minimum_size.y >= 48.0
	_check(touch_safe, "All pause actions meet the minimum touch target.")
	overlay.queue_free()
	await process_frame


func _test_reduced_motion_persistence() -> void:
	var path := "user://ui_redesign_test.cfg"
	var settings := GameSettings.new()
	settings.settings_path = path
	settings.ui_reduced_motion = true
	settings.save_to_disk()
	var loaded := GameSettings.new()
	loaded.settings_path = path
	loaded.load_from_disk()
	_check(loaded.ui_reduced_motion, "Reduced motion persists in GameSettings.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failed = true
		push_error("FAIL: " + message)
