class_name KartInputController
extends Node

var kart: Kart
var throttle := 0.0
var brake := 0.0
var steer := 0.0
var drift := false
var previous_drift := false
var use_item_requested := false
var last_frame := RacerInputSource.empty_frame()


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func update() -> void:
	if kart.input_source != null:
		_read_input_source()
	elif kart.is_player:
		_read_player_input()


func set_frame(new_throttle: float, new_brake: float, new_steer: float, new_drift: bool, use_item_now: bool) -> void:
	throttle = clampf(new_throttle, 0.0, 1.0)
	brake = clampf(new_brake, 0.0, 1.0)
	steer = clampf(new_steer, -1.0, 1.0)
	drift = new_drift
	use_item_requested = use_item_requested or use_item_now
	last_frame = {
		"throttle": throttle,
		"brake": brake,
		"steer": steer,
		"drift": drift,
		"use_item": use_item_now,
	}


func consume_use_item_request() -> bool:
	var requested := use_item_requested
	use_item_requested = false
	return requested


func _read_player_input() -> void:
	kart.set_drive_input(
		Input.get_action_strength(&"accelerate"),
		Input.get_action_strength(&"brake"),
		Input.get_axis(&"steer_left", &"steer_right"),
		Input.is_action_pressed(&"drift"),
		Input.is_action_just_pressed(&"use_item")
	)


func _read_input_source() -> void:
	var frame := kart.input_source.sample()
	kart.set_drive_input(
		float(frame.get("throttle", 0.0)),
		float(frame.get("brake", 0.0)),
		float(frame.get("steer", 0.0)),
		bool(frame.get("drift", false)),
		bool(frame.get("use_item", false))
	)
