class_name AiDecision
extends RefCounted

var throttle: float = 0.0
var brake: float = 0.0
var steer: float = 0.0
var drift: bool = false
var use_item: bool = false


func _init(throttle_value: float = 0.0, brake_value: float = 0.0,
		steer_value: float = 0.0, drift_value: bool = false,
		use_item_value: bool = false) -> void:
	throttle = throttle_value
	brake = brake_value
	steer = steer_value
	drift = drift_value
	use_item = use_item_value
