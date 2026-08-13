class_name InputDeviceCoordinator
extends Node

signal device_changed(mode: StringName, device_id: int)
signal family_changed(family: StringName)

const AUTOMATIC := &"automatic"
const KEYBOARD := &"keyboard"
const XBOX := &"xbox"
const PLAYSTATION := &"playstation"
const NINTENDO := &"nintendo"
const GENERIC := &"generic"

var mode: StringName = KEYBOARD
var device_id := -1
var manual_family: StringName = AUTOMATIC
var detected_family: StringName = KEYBOARD

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.5:
			return
		_set_device(&"gamepad", event.device)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		_set_device(KEYBOARD if not event is InputEventScreenTouch else &"touch", -1)

func set_manual_family(family: StringName) -> void:
	if family not in [AUTOMATIC, XBOX, PLAYSTATION, NINTENDO, GENERIC]:
		return
	manual_family = family
	_apply_prompt_family()
	family_changed.emit(get_visual_family())

func get_visual_family() -> StringName:
	return detected_family if manual_family == AUTOMATIC else manual_family

func _set_device(next_mode: StringName, next_id: int) -> void:
	if next_mode == mode and next_id == device_id:
		return
	mode = next_mode
	device_id = next_id
	detected_family = _detect_family(next_id) if next_id >= 0 else KEYBOARD
	_apply_prompt_family()
	device_changed.emit(mode, device_id)
	family_changed.emit(get_visual_family())

func _detect_family(id: int) -> StringName:
	var name := Input.get_joy_name(id).to_lower()
	if "nintendo" in name or "switch" in name:
		return NINTENDO
	if "dualshock" in name or "dualsense" in name or "playstation" in name or " ps" in name:
		return PLAYSTATION
	if "xbox" in name or "xinput" in name:
		return XBOX
	return GENERIC

func _apply_prompt_family() -> void:
	var manager := get_node_or_null("/root/PromptManager")
	if manager == null:
		return
	var family := get_visual_family()
	manager.preferred_icons = {
		KEYBOARD: InputPrompt.Icons.KEYBOARD,
		XBOX: InputPrompt.Icons.XBOX,
		PLAYSTATION: InputPrompt.Icons.SONY,
		NINTENDO: InputPrompt.Icons.NINTENDO,
		GENERIC: InputPrompt.Icons.XBOX,
	}.get(family, InputPrompt.Icons.AUTOMATIC)

func _on_joy_connection_changed(id: int, connected: bool) -> void:
	if connected or id != device_id:
		return
	var connected_ids := Input.get_connected_joypads()
	if connected_ids.is_empty():
		_set_device(KEYBOARD, -1)
	else:
		_set_device(&"gamepad", int(connected_ids.front()))
