class_name KartMotor
extends Node

var kart: Kart


static func get_steering_factor(speed: float, maximum_speed: float) -> float:
	var speed_ratio := clampf(absf(speed) / maxf(maximum_speed, 0.1), 0.0, 1.0)
	if speed_ratio <= 0.4:
		return lerpf(0.45, 1.0, speed_ratio / 0.4)
	var high_speed_weight := (speed_ratio - 0.4) / 0.6
	return lerpf(1.0, 0.72, high_speed_weight)


static func get_acceleration_factor(speed: float, maximum_speed: float) -> float:
	var speed_ratio := clampf(maxf(speed, 0.0) / maxf(maximum_speed, 0.1), 0.0, 1.2)
	return maxf(1.0 - 0.82 * pow(speed_ratio, 1.5), 0.12)


static func get_rolling_resistance(speed: float) -> float:
	return Kart.ROLLING_RESISTANCE_BASE + maxf(speed, 0.0) * Kart.ROLLING_RESISTANCE_SPEED_FACTOR


static func calculate_barrier_velocity(
	incoming_velocity: Vector3,
	collision_normal: Vector3
) -> Vector3:
	var horizontal_velocity := Vector3(incoming_velocity.x, 0.0, incoming_velocity.z)
	var incoming_speed := horizontal_velocity.length()
	var wall_normal := Vector3(collision_normal.x, 0.0, collision_normal.z).normalized()
	if incoming_speed <= 0.001 or wall_normal.is_zero_approx():
		return incoming_velocity
	var incident_ratio := clampf(-horizontal_velocity.normalized().dot(wall_normal), 0.0, 1.0)
	var retention := 1.0
	if incident_ratio <= 0.2:
		retention = lerpf(1.0, 0.85, incident_ratio / 0.2)
	else:
		var frontal_weight := clampf(inverse_lerp(0.2, 0.8, incident_ratio), 0.0, 1.0)
		retention = lerpf(0.85, 0.55, frontal_weight)
	var retained_speed := incoming_speed * retention
	var tangent := horizontal_velocity.slide(wall_normal)
	if tangent.length_squared() <= 0.0001:
		tangent = wall_normal.cross(Vector3.UP)
		if tangent.dot(horizontal_velocity) < 0.0:
			tangent = -tangent
	var result := tangent.normalized() * retained_speed
	result.y = incoming_velocity.y
	return result


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func apply_ground_drive(delta: float, throttle: float, brake: float, steer: float) -> void:
	var forward := -kart.global_transform.basis.z.normalized()
	var horizontal_velocity := Vector3(kart.velocity.x, 0.0, kart.velocity.z)
	var forward_speed := horizontal_velocity.dot(forward)
	if brake > 0.0:
		if forward_speed > 0.5:
			var braked_speed := move_toward(forward_speed, 0.0, kart.stats.braking * brake * delta)
			kart.velocity += forward * (braked_speed - forward_speed)
		else:
			kart.velocity -= forward * kart.stats.braking * 0.36 * brake * delta
	elif throttle > 0.0:
		var acceleration_factor := get_acceleration_factor(forward_speed, kart.stats.max_speed)
		kart.velocity += forward * kart.stats.acceleration * kart.current_surface.acceleration_multiplier * acceleration_factor * throttle * delta

	var speed := Vector2(kart.velocity.x, kart.velocity.z).length()
	var steering_factor := get_steering_factor(speed, kart.stats.max_speed)
	var steering_command := steer
	var is_drifting := kart._drive_state == Kart.DriveState.DRIFT
	if is_drifting:
		var is_turning_inward := steer * kart._drift_controller.side >= 0.0
		var countersteer_scale := 1.08 if is_turning_inward else 0.72
		steering_command = clampf(kart._drift_controller.side * 0.3 + steer * countersteer_scale, -1.35, 1.35)
	var yaw_change := steering_command * kart.stats.steering_speed * steering_factor * delta
	kart.rotation.y -= yaw_change

	forward = -kart.global_transform.basis.z.normalized()
	horizontal_velocity = Vector3(kart.velocity.x, 0.0, kart.velocity.z)
	if not horizontal_velocity.is_zero_approx():
		var tire_response := 0.18 if is_drifting else clampf(kart.stats.grip / 9.2, 0.78, 1.08)
		horizontal_velocity = horizontal_velocity.rotated(Vector3.UP, -yaw_change * tire_response)
	var lateral_velocity := horizontal_velocity - forward * horizontal_velocity.dot(forward)
	var traction := kart.stats.drift_grip * kart.current_surface.drift_grip_multiplier if is_drifting else kart.stats.grip * kart.current_surface.grip_multiplier
	horizontal_velocity -= lateral_velocity * minf(traction * delta, 1.0)
	var resistance_scale := 0.35 if throttle > 0.0 and brake <= 0.0 else 1.0
	var resistance := get_rolling_resistance(horizontal_velocity.length()) * resistance_scale * kart.current_surface.rolling_resistance_multiplier
	horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, resistance * delta)
	horizontal_velocity = apply_soft_speed_limit(horizontal_velocity, delta)
	kart.velocity.x = horizontal_velocity.x
	kart.velocity.z = horizontal_velocity.z


func apply_air_drive(delta: float, steer: float, hop_started: bool) -> void:
	if not hop_started:
		kart.velocity.y -= Kart.GRAVITY * delta
	var speed := Vector2(kart.velocity.x, kart.velocity.z).length()
	var steering_factor := get_steering_factor(speed, kart.stats.max_speed)
	var yaw_change := steer * kart.stats.steering_speed * steering_factor * Kart.AIR_STEERING_RATIO * delta
	kart.rotation.y -= yaw_change
	var horizontal_velocity := Vector3(kart.velocity.x, 0.0, kart.velocity.z)
	if not horizontal_velocity.is_zero_approx():
		horizontal_velocity = horizontal_velocity.rotated(Vector3.UP, -yaw_change)
		kart.velocity.x = horizontal_velocity.x
		kart.velocity.z = horizontal_velocity.z


func apply_soft_speed_limit(horizontal_velocity: Vector3, delta: float) -> Vector3:
	var speed_limit := kart.stats.max_speed
	if kart._boost_controller.is_active():
		speed_limit += kart._boost_controller.get_power()
	var forward := -kart.global_transform.basis.z.normalized()
	var forward_speed := horizontal_velocity.dot(forward)
	var soft_limit := speed_limit * Kart.SOFT_LIMIT_START_RATIO
	if forward_speed > soft_limit:
		horizontal_velocity -= forward * ((forward_speed - soft_limit) * minf(Kart.SOFT_LIMIT_RESPONSE * delta, 1.0))
	elif forward_speed < -kart.stats.reverse_speed:
		horizontal_velocity = horizontal_velocity.limit_length(kart.stats.reverse_speed)
	return horizontal_velocity


func update_drive_state_after_move(was_on_floor: bool) -> void:
	if kart.is_on_floor():
		if not was_on_floor:
			kart.presentation_landed.emit(clampf(absf(kart.velocity.y) / 12.0, 0.0, 1.0))
			var landed_from_drift_hop := kart._drive_state == Kart.DriveState.DRIFT_HOP
			stabilize_landing()
			kart._status_timers.landing_compression_remaining = Kart.LANDING_COMPRESSION_DURATION
			kart._drive_state = Kart.DriveState.DRIFT if kart._input_controller.drift and kart._drift_controller.side != 0.0 else Kart.DriveState.GROUND
			if landed_from_drift_hop and kart._drive_state == Kart.DriveState.DRIFT:
				kart._drift_controller.grace_remaining = kart.driving_tuning.hop_grace
	elif kart._drive_state != Kart.DriveState.DRIFT_HOP:
		kart._drive_state = Kart.DriveState.AIR


func update_floor_snap() -> void:
	var can_snap := (
		kart._drive_state != Kart.DriveState.DRIFT_HOP
		and kart.velocity.y <= 0.05
		and kart.velocity.y >= -Kart.MAXIMUM_SNAP_FALL_SPEED
	)
	kart.floor_snap_length = Kart.FLOOR_SNAP_DISTANCE if can_snap else 0.0


func stabilize_landing() -> void:
	var horizontal_velocity := Vector3(kart.velocity.x, 0.0, kart.velocity.z)
	var speed := horizontal_velocity.length()
	if speed <= 0.1:
		return
	var forward := -kart.global_transform.basis.z.normalized()
	if horizontal_velocity.normalized().dot(forward) <= 0.0:
		return
	var stable_direction := horizontal_velocity.normalized().slerp(forward, 0.14).normalized()
	kart.velocity.x = stable_direction.x * speed
	kart.velocity.z = stable_direction.z * speed
