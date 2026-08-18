class_name KartStatusTimerController
extends RefCounted

var _launch_bog_remaining := 0.0
var _stun_remaining := 0.0
var _invulnerable_remaining := 0.0
var _landing_compression_remaining := 0.0


func update(delta: float) -> void:
	_launch_bog_remaining = maxf(_launch_bog_remaining - delta, 0.0)
	_stun_remaining = maxf(_stun_remaining - delta, 0.0)
	_invulnerable_remaining = maxf(_invulnerable_remaining - delta, 0.0)
	_landing_compression_remaining = maxf(_landing_compression_remaining - delta, 0.0)


func apply_hitstun(duration: float, invulnerability_duration: float) -> void:
	_stun_remaining = duration
	_invulnerable_remaining = invulnerability_duration


func start_launch_bog(duration: float) -> void:
	_launch_bog_remaining = duration


func start_landing_compression(duration: float) -> void:
	_landing_compression_remaining = duration


func clear_invulnerability() -> void:
	_invulnerable_remaining = 0.0


func clear_landing_compression() -> void:
	_landing_compression_remaining = 0.0


func reset() -> void:
	_launch_bog_remaining = 0.0
	_stun_remaining = 0.0
	_invulnerable_remaining = 0.0
	_landing_compression_remaining = 0.0


func clear_effects() -> void:
	reset()


func is_stunned() -> bool:
	return _stun_remaining > 0.0


func is_invulnerable() -> bool:
	return _invulnerable_remaining > 0.0


func is_launch_bogged() -> bool:
	return _launch_bog_remaining > 0.0


func get_stun_remaining() -> float:
	return _stun_remaining


func get_landing_compression_ratio(duration: float) -> float:
	return clampf(_landing_compression_remaining / duration, 0.0, 1.0)
