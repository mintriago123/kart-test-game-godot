class_name RacerInputSource
extends RefCounted

const ACTION_ACCELERATE := &"accelerate"
const ACTION_BRAKE := &"brake"
const ACTION_STEER_LEFT := &"steer_left"
const ACTION_STEER_RIGHT := &"steer_right"
const ACTION_DRIFT := &"drift"
const ACTION_USE_ITEM := &"use_item"

var device_type: StringName = RaceParticipantConfig.DEVICE_KEYBOARD
var device_id := -1
var enabled := true
var _previous_item_pressed := false
var _virtual_action_strengths: Dictionary = {}


static func for_participant(participant: RaceParticipantConfig) -> RacerInputSource:
	if participant == null or not participant.is_human():
		return null
	if participant.control_type == RaceParticipantConfig.ControlType.REMOTE:
		var network_source := NetworkRacerInputSource.new()
		network_source.device_type = RaceParticipantConfig.DEVICE_NETWORK
		network_source.device_id = participant.peer_id
		return network_source
	var source := RacerInputSource.new()
	source.device_type = participant.device_type
	source.device_id = participant.device_id
	return source


func sample() -> Dictionary:
	if not enabled:
		return empty_frame()
	var item_pressed := get_action_strength(ACTION_USE_ITEM) > 0.5
	var frame := {
		"throttle": get_action_strength(ACTION_ACCELERATE),
		"brake": get_action_strength(ACTION_BRAKE),
		"steer": get_action_strength(ACTION_STEER_RIGHT) - get_action_strength(ACTION_STEER_LEFT),
		"drift": get_action_strength(ACTION_DRIFT) > 0.5,
		"use_item": item_pressed and not _previous_item_pressed,
	}
	_previous_item_pressed = item_pressed
	return frame


func get_action_strength(action: StringName) -> float:
	var strength := float(_virtual_action_strengths.get(action, 0.0))
	for event in InputMap.action_get_events(action):
		if not accepts_event(event):
			continue
		strength = maxf(strength, _event_strength(event))
	return clampf(strength, 0.0, 1.0)


func set_virtual_action_strength(action: StringName, strength: float) -> void:
	var clamped_strength := clampf(strength, 0.0, 1.0)
	if is_zero_approx(clamped_strength):
		_virtual_action_strengths.erase(action)
	else:
		_virtual_action_strengths[action] = clamped_strength


func clear_virtual_actions() -> void:
	_virtual_action_strengths.clear()
	_previous_item_pressed = false


func accepts_event(event: InputEvent) -> bool:
	if device_type == RaceParticipantConfig.DEVICE_KEYBOARD:
		return event is InputEventKey or event is InputEventMouseButton
	if device_type == RaceParticipantConfig.DEVICE_GAMEPAD:
		return (
			(event is InputEventJoypadButton or event is InputEventJoypadMotion)
			and (event.device < 0 or event.device == device_id)
		)
	return false


func _event_strength(event: InputEvent) -> float:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return float(Input.is_physical_key_pressed(code))
	if event is InputEventMouseButton:
		return float(Input.is_mouse_button_pressed((event as InputEventMouseButton).button_index))
	if event is InputEventJoypadButton:
		return float(Input.is_joy_button_pressed(device_id, (event as InputEventJoypadButton).button_index))
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var value := Input.get_joy_axis(device_id, motion.axis) * signf(motion.axis_value)
		var deadzone := InputMap.action_get_deadzone(_find_action_for_event(event))
		return inverse_lerp(deadzone, 1.0, value) if value > deadzone else 0.0
	return 0.0


func _find_action_for_event(event: InputEvent) -> StringName:
	for action in [ACTION_ACCELERATE, ACTION_BRAKE, ACTION_STEER_LEFT, ACTION_STEER_RIGHT, ACTION_DRIFT, ACTION_USE_ITEM]:
		for assigned in InputMap.action_get_events(action):
			if assigned.is_match(event):
				return action
	return &""


static func empty_frame() -> Dictionary:
	return {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "drift": false, "use_item": false}


class NetworkRacerInputSource:
	extends RacerInputSource
	var sequence := -1
	var _frame := RacerInputSource.empty_frame()

	func push_frame(next_sequence: int, frame: Dictionary) -> bool:
		if next_sequence <= sequence:
			return false
		sequence = next_sequence
		_frame = {
			"throttle": clampf(float(frame.get("throttle", 0.0)), 0.0, 1.0),
			"brake": clampf(float(frame.get("brake", 0.0)), 0.0, 1.0),
			"steer": clampf(float(frame.get("steer", 0.0)), -1.0, 1.0),
			"drift": bool(frame.get("drift", false)),
			"use_item": bool(frame.get("use_item", false)),
		}
		return true

	func sample() -> Dictionary:
		var result := _frame.duplicate()
		_frame["use_item"] = false
		return result
