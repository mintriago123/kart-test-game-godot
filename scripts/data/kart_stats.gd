class_name KartStats
extends Resource

@export var max_speed: float = 25.0
@export var reverse_speed: float = 8.0
@export var acceleration: float = 18.0
@export var braking: float = 28.0
@export var steering_speed: float = 2.2
@export var grip: float = 9.0
@export var drift_grip: float = 2.8
@export var boost_power: float = 11.0


static func create(
	speed: float,
	acceleration_force: float,
	steering: float,
	traction: float
) -> KartStats:
	var stats := KartStats.new()
	stats.max_speed = speed
	stats.acceleration = acceleration_force
	stats.steering_speed = steering
	stats.grip = traction
	return stats


func copy() -> KartStats:
	var copied_stats := KartStats.new()
	copied_stats.max_speed = max_speed
	copied_stats.reverse_speed = reverse_speed
	copied_stats.acceleration = acceleration
	copied_stats.braking = braking
	copied_stats.steering_speed = steering_speed
	copied_stats.grip = grip
	copied_stats.drift_grip = drift_grip
	copied_stats.boost_power = boost_power
	return copied_stats
