class_name UiInputModeController
extends Node

signal mode_changed(mode: StringName)

const TOUCH := &"touch"
const KEYBOARD := &"keyboard"
const GAMEPAD := &"gamepad"

var mode: StringName = TOUCH if DisplayServer.is_touchscreen_available() else KEYBOARD


func _unhandled_input(event: InputEvent) -> void:
	var next_mode := mode
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		next_mode = TOUCH
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_mode = GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		next_mode = KEYBOARD
	set_mode(next_mode)


func set_mode(next_mode: StringName) -> void:
	if next_mode not in [TOUCH, KEYBOARD, GAMEPAD] or next_mode == mode:
		return
	mode = next_mode
	mode_changed.emit(mode)


func get_prompt(action: StringName) -> String:
	if mode == TOUCH:
		return "TOCAR"
	if mode == GAMEPAD:
		return {&"ui_accept": "A", &"ui_cancel": "B", &"pause": "☰"}.get(action, "BOTÓN")
	return {&"ui_accept": "ENTER", &"ui_cancel": "ESC", &"pause": "ESC"}.get(action, str(action).to_upper())
