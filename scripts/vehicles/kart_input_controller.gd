class_name KartInputController
extends RefCounted

var kart: Kart
var _throttle := 0.0
var _brake := 0.0
var _steer := 0.0
var _drift := false
var _previous_drift := false
var _use_item_requested := false
var _last_frame := RacerInputSource.empty_frame()


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func update() -> void:
	if kart.input_source != null:
		_read_input_source()
	elif kart.is_player:
		_read_player_input()


func set_frame(new_throttle: float, new_brake: float, new_steer: float, new_drift: bool, use_item_now: bool) -> void:
	_throttle = clampf(new_throttle, 0.0, 1.0)
	_brake = clampf(new_brake, 0.0, 1.0)
	_steer = clampf(new_steer, -1.0, 1.0)
	_drift = new_drift
	_use_item_requested = _use_item_requested or use_item_now
	_last_frame = {
		"throttle": _throttle,
		"brake": _brake,
		"steer": _steer,
		"drift": _drift,
		"use_item": use_item_now,
	}


func consume_use_item_request() -> bool:
	var requested := _use_item_requested
	_use_item_requested = false
	return requested


func consume_drift_pressed() -> bool:
	var was_pressed := _drift and not _previous_drift
	_previous_drift = _drift
	return was_pressed


func reset_drift_state() -> void:
	_previous_drift = _drift


func get_throttle() -> float:
	return _throttle


func get_brake() -> float:
	return _brake


func get_steer() -> float:
	return _steer


func is_drift_pressed() -> bool:
	return _drift


func get_last_frame() -> Dictionary:
	return _last_frame.duplicate()


func _read_player_input() -> void:
	set_frame(
		Input.get_action_strength(&"accelerate"),
		Input.get_action_strength(&"brake"),
		Input.get_axis(&"steer_left", &"steer_right"),
		Input.is_action_pressed(&"drift"),
		Input.is_action_just_pressed(&"use_item")
	)


func _read_input_source() -> void:
	var frame := kart.input_source.sample()
	set_frame(
		float(frame.get("throttle", 0.0)),
		float(frame.get("brake", 0.0)),
		float(frame.get("steer", 0.0)),
		bool(frame.get("drift", false)),
		bool(frame.get("use_item", false))
	)
