class_name AiSpeedPlanner
extends RefCounted

var tuning: AiTuning
var kart: Kart


func compute_lookahead(speed: float, reaction_delay: float, lookahead_max_multiplier: float) -> float:
	var lookahead := tuning.lookahead_base + speed * (tuning.lookahead_speed_factor + reaction_delay)
	return clampf(lookahead, tuning.lookahead_min, tuning.lookahead_max * lookahead_max_multiplier)


func compute_safe_speed(sample, lateral_error: float, sensors: Dictionary, line_ratio: float) -> float:
	if kart == null:
		return 0.0
	var maximum := kart.stats.max_speed
	var line_limit := maximum * clampf(line_ratio, tuning.safe_speed_line_ratio_floor, 1.0)
	var curvature := absf(sample.curvature)
	var turn_limit := maximum
	if curvature > 0.001:
		var lateral_capacity := maxf(
			kart.stats.steering_speed * kart.stats.grip * tuning.safe_speed_lateral_capacity_factor,
			1.0
		)
		turn_limit = sqrt(lateral_capacity / curvature)
	var lateral_ratio := clampf(
		absf(lateral_error) / maxf(sample.available_width, 0.5),
		0.0,
		1.0
	)
	var lateral_limit := maximum * lerpf(1.0, tuning.safe_speed_lateral_loss_floor, lateral_ratio)
	var front_ratio := float(sensors.front)
	var front_distance := front_ratio * lerpf(
		tuning.sensor_min_range,
		tuning.sensor_max_range,
		clampf(kart.get_horizontal_speed() / maxf(maximum, 0.1), 0.0, 1.0)
	)
	var barrier_limit := maximum
	if front_ratio < tuning.safe_speed_barrier_activation_ratio:
		barrier_limit = sqrt(maxf(
			2.0 * kart.stats.braking * maxf(front_distance - tuning.safe_speed_barrier_brake_distance, 0.0),
			0.0
		))
	return clampf(
		minf(line_limit, minf(turn_limit, minf(lateral_limit, barrier_limit))),
		maximum * tuning.safe_speed_min_ratio,
		maximum
	)


func compute_target_speed(
	safe_speed: float,
	aggression: float,
	top_speed_bias: float,
	is_wall_recovery: bool,
	max_speed: float,
	wall_recovery_ratio: float
) -> float:
	var target := safe_speed * lerpf(tuning.aggression_safe_speed_min, tuning.aggression_safe_speed_max, aggression) * (1.0 + top_speed_bias)
	if is_wall_recovery:
		target = minf(target, max_speed * wall_recovery_ratio)
	return target


func wanted_throttle(speed_error: float, max_speed: float) -> float:
	var wanted := speed_error / maxf(max_speed * tuning.throttle_speed_ratio, 1.0)
	# Deadband: when the kart is essentially at target speed the safe_speed
	# jitters ±0.5 m/s frame-to-frame from curvature/section variation. If we
	# translated that straight into throttle, the kart would oscillate between
	# 0 and 0.1 every few frames (the "brinquito"). Below the deadband we
	# coast; above it we ask for full throttle again.
	if absf(speed_error) < tuning.throttle_deadband:
		return 0.0
	return clampf(wanted, 0.0, 1.0)


func wanted_brake(speed_error: float, max_speed: float) -> float:
	var wanted := -speed_error / maxf(max_speed * tuning.brake_speed_ratio, 1.0)
	# Same deadband idea on the brake side so coasting just below target
	# doesn't pulse brake every frame.
	if speed_error > -tuning.brake_deadband:
		return 0.0
	return clampf(wanted, 0.0, 1.0)


func clamp_throttle_under_threat(throttle: float, sensors: Dictionary) -> float:
	if float(sensors.front) < 0.22:
		return minf(throttle, tuning.sensor_threat_throttle_ceiling)
	return throttle


func clamp_brake_under_threat(brake: float, sensors: Dictionary) -> float:
	if float(sensors.front) < 0.22:
		return maxf(brake, lerpf(tuning.sensor_threat_brake_floor, 1.0, 1.0 - float(sensors.front)))
	return brake


func update_throttle(current: float, wanted: float, response_multiplier: float, delta: float) -> float:
	return move_toward(current, wanted, delta * tuning.throttle_smooth_rate * response_multiplier)


func update_brake(current: float, wanted: float, response_multiplier: float, delta: float) -> float:
	return move_toward(current, wanted, delta * tuning.brake_smooth_rate * response_multiplier)


func clamp_throttle_when_braking(throttle: float, brake: float) -> float:
	if brake > tuning.brake_overrides_throttle_threshold:
		return minf(throttle, tuning.brake_overrides_throttle_ceiling)
	return throttle
