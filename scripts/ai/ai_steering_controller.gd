class_name AiSteeringController
extends RefCounted

var tuning: AiTuning
var kart: Kart


func compute_line_steer(
	target_position: Vector3,
	forward: Vector3,
	lateral_error: float,
	curvature: float,
	correction_factor: float,
	precision: float,
	available_width: float = 6.85
) -> float:
	if kart == null:
		return 0.0
	var to_target := (target_position - kart.global_position).normalized()
	var angular_error := -forward.cross(to_target).y
	var lateral_gain := lerpf(
		tuning.steering_lateral_gain_min,
		tuning.steering_lateral_gain_max,
		precision + correction_factor * (1.0 - precision)
	)
	var steer := clampf(
		angular_error * tuning.steering_angular_gain
		- lateral_error * lateral_gain
		- curvature * tuning.steering_curvature_gain,
		-tuning.line_steer_max_magnitude,
		tuning.line_steer_max_magnitude
	)
	var lateral_ratio := absf(lateral_error) / maxf(available_width, 0.5)
	var recovery_weight := inverse_lerp(
		tuning.steering_lateral_recovery_start_ratio,
		tuning.steering_lateral_recovery_end_ratio,
		lateral_ratio
	)
	if recovery_weight > 0.0:
		var recovery_target := -signf(lateral_error) * tuning.line_steer_max_magnitude
		steer = lerpf(
			steer,
			recovery_target,
			clampf(recovery_weight * tuning.steering_lateral_recovery_gain, 0.0, 1.0)
		)
	return steer


func apply_barrier_steering(
	line_steer: float,
	sensors: Dictionary,
	line_forward: Vector3,
	contact_normal: Vector3,
	drive_state: int
) -> float:
	if kart == null:
		return line_steer
	var front := float(sensors.front)
	var left := float(sensors.left)
	var right := float(sensors.right)
	if drive_state == AiRecoveryState.DriveState.WALL_RECOVERY:
		var tangent := contact_normal.cross(Vector3.UP).normalized()
		if tangent.dot(line_forward) < 0.0:
			tangent = -tangent
		var forward := -kart.global_transform.basis.z.normalized()
		return clampf(
			-forward.cross((tangent + contact_normal * tuning.barrier_steering_contact_bias).normalized()).y
			* tuning.barrier_steering_arc_gain,
			-tuning.line_steer_max_magnitude,
			tuning.line_steer_max_magnitude
		)
	var front_threat := clampf((tuning.barrier_threat_front_start - front) / tuning.barrier_threat_front_range, 0.0, 1.0)
	var side_threat := clampf((tuning.barrier_threat_side_start - minf(left, right)) / tuning.barrier_threat_side_range, 0.0, 1.0)
	var threat := maxf(front_threat, side_threat)
	if threat <= 0.0:
		return line_steer
	var avoidance := 0.0
	if front < tuning.barrier_threat_front_start:
		avoidance = -1.0 if left > right else 1.0
	else:
		avoidance = clampf((right - left) * tuning.barrier_threat_response_curve, -1.0, 1.0)
	var weight := lerpf(tuning.barrier_threat_weight_min, 1.0, threat)
	return lerpf(line_steer, avoidance, weight)


func apply_racer_avoidance(
	line_steer: float,
	forward: Vector3,
	racers: Array,
	participant_slot: int,
	weight_max: float
) -> float:
	if racers.is_empty():
		return line_steer
	var kart_pos := kart.global_position
	var right := kart.global_transform.basis.x.normalized()
	var nearest_distance := INF
	var nearest_lateral := 0.0
	for candidate_value in racers:
		var candidate := candidate_value as Kart
		if candidate == null or candidate == kart:
			continue
		var offset := candidate.global_position - kart_pos
		offset.y = 0.0
		var distance := offset.length()
		if distance < 0.1 or distance > tuning.racer_avoidance_distance:
			continue
		var forward_distance := offset.dot(forward)
		var lateral_distance := offset.dot(right)
		if forward_distance <= tuning.racer_avoidance_forward_min:
			continue
		if absf(lateral_distance) > tuning.racer_avoidance_lateral_max:
			continue
		if forward.dot(offset / distance) < tuning.racer_avoidance_forward_dot or distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_lateral = lateral_distance
	if not is_finite(nearest_distance):
		return line_steer
	var avoidance_side := 0.0
	if absf(nearest_lateral) > tuning.racer_avoidance_lateral_sign_threshold:
		avoidance_side = -signf(nearest_lateral)
	else:
		var grid_row := maxi(participant_slot, 0) / 2
		avoidance_side = 1.0 if grid_row % 2 == 1 else -1.0
	var weight := clampf(
		(tuning.racer_avoidance_distance - nearest_distance) / 7.5,
		tuning.racer_avoidance_weight_floor,
		weight_max
	)
	return lerpf(line_steer, avoidance_side, weight)


func stabilize_straight_target(
	target_steer: float,
	current_target: float,
	curvature: float,
	sensors: Dictionary
) -> float:
	var minimum_sensor := minf(
		float(sensors.get("front", 1.0)),
		minf(float(sensors.get("left", 1.0)), float(sensors.get("right", 1.0)))
	)
	if (
		absf(curvature) > tuning.steering_straight_curvature_max
		or minimum_sensor < tuning.steering_straight_sensor_min
	):
		return target_steer
	var deadband := tuning.steering_straight_sign_deadband
	if (
		absf(current_target) > deadband
		and absf(target_steer) > deadband
		and signf(current_target) != signf(target_steer)
	):
		# Cross zero before changing sides. This prevents a clear straight from
		# alternating left/right commands when the projected line moves by one
		# sample, while retaining full response in bends and near barriers.
		return 0.0
	return target_steer


func stabilize_straight_output(
	steer: float,
	previous_steer: float,
	curvature: float,
	sensors: Dictionary
) -> float:
	var minimum_sensor := minf(
		float(sensors.get("front", 1.0)),
		minf(float(sensors.get("left", 1.0)), float(sensors.get("right", 1.0)))
	)
	var deadband := tuning.steering_straight_sign_deadband
	if (
		absf(curvature) <= tuning.steering_straight_curvature_max
		and minimum_sensor >= tuning.steering_straight_sensor_min
		and absf(previous_steer) > deadband
		and absf(steer) > deadband
		and signf(previous_steer) != signf(steer)
	):
		return 0.0
	return steer


func update_target_steer(target_steer: float, current_target: float, delta: float) -> float:
	return move_toward(
		current_target,
		target_steer,
		maxf(tuning.steering_target_response_hz, 0.0) * maxf(delta, 0.0)
	)


func update_smoothed_steer(
	target_steer: float,
	current_smoothed: float,
	reaction_time: float,
	response_multiplier: float,
	delta: float
) -> float:
	var response := lerpf(
		tuning.steer_response_min,
		tuning.steer_response_max,
		1.0 - reaction_time
	) * response_multiplier
	return move_toward(current_smoothed, target_steer, delta * response)
