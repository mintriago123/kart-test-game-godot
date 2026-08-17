class_name KartBoostController
extends Node

var kart: Kart
var _remaining := 0.0
var _power := 0.0


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func update(delta: float) -> void:
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining <= 0.0:
		_power = 0.0


func activate(duration: float, power: float) -> void:
	var previous_power := _power if _remaining > 0.0 else 0.0
	_remaining = maxf(_remaining, duration)
	_power = maxf(_power, power)
	var forward := -kart.global_transform.basis.z.normalized()
	kart.velocity += forward * maxf(power - previous_power, 0.0)
	if power > previous_power:
		kart.presentation_boost_started.emit(clampf(power / maxf(kart.stats.max_speed * 0.5, 0.1), 0.0, 1.0))


func clear() -> void:
	_remaining = 0.0
	_power = 0.0


func is_active() -> bool:
	return _remaining > 0.0


func get_power() -> float:
	return _power
