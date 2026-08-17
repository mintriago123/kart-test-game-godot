class_name KartStatusTimerController
extends Node

var launch_bog_remaining := 0.0
var stun_remaining := 0.0
var invulnerable_remaining := 0.0
var landing_compression_remaining := 0.0


func update(delta: float) -> void:
	launch_bog_remaining = maxf(launch_bog_remaining - delta, 0.0)
	stun_remaining = maxf(stun_remaining - delta, 0.0)
	invulnerable_remaining = maxf(invulnerable_remaining - delta, 0.0)
	landing_compression_remaining = maxf(landing_compression_remaining - delta, 0.0)


func clear_effects() -> void:
	launch_bog_remaining = 0.0
	stun_remaining = 0.0
	invulnerable_remaining = 0.0
	landing_compression_remaining = 0.0


func is_stunned() -> bool:
	return stun_remaining > 0.0


func is_invulnerable() -> bool:
	return invulnerable_remaining > 0.0
