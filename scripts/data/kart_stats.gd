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
