class_name AiDriver
extends Node

enum DriveState {
	DRIVING,
	AVOIDING_WALL,
	WALL_RECOVERY,
}

const WALL_RECOVERY_CONTACT_TIME := 0.4
const WALL_RECOVERY_RESET_TIME := 2.0
const CONTACT_GRACE := 0.16
const SENSOR_MINIMUM_RANGE := 5.0
const SENSOR_MAXIMUM_RANGE := 14.0

var kart: Kart
var race_manager: RaceManager
var racing_line: RacingLine
var racer: RacerDefinition
var race_seed := 0
var telemetry := {
	"lateral_error": 0.0,
	"target_speed": 0.0,
	"actual_speed": 0.0,
	"braking_time": 0.0,
	"drift_time": 0.0,
	"impacts": 0,
	"shortcut_decisions": 0,
	"recoveries": 0,
	"barrier_contacts": 0,
	"barrier_contact_time": 0.0,
	"avoidance_time": 0.0,
	"maximum_lateral_error": 0.0,
	"wall_recoveries": 0,
	"hard_resets": 0,
}

var _item_cooldown := 2.0
var _last_checkpoint_index := -1
var _best_checkpoint_distance := INF
var _checkpoint_stall_time := 0.0
var _observed_item: ItemDefinition
var _held_item_time := 0.0
var _projection_hint := -1
var _branch_projection_hint := -1
var _active_branch_id := -1
var _decided_branches: Dictionary = {}
var _current_section_id := -1
var _section_variation := {}
var _drift_section_id := -1
var _drift_committed := false
var _smoothed_throttle := 0.0
var _smoothed_brake := 0.0
var _correction_remaining := 0.0
var _previous_velocity := Vector3.ZERO
var _drive_state := DriveState.DRIVING
var _barrier_contact_time := 0.0
var _contact_grace_remaining := 0.0
var _recovery_time := 0.0
var _contact_normal := Vector3.ZERO
var _smoothed_steer := 0.0


func setup(
	controlled_kart: Kart,
	manager: RaceManager,
	line_or_legacy_offset: Variant = null,
	racer_definition: RacerDefinition = null,
	seed: int = 0,
	difficulty: DifficultyDefinition = null
) -> void:
	kart = controlled_kart
	race_manager = manager
	if line_or_legacy_offset is RacingLine:
		racing_line = line_or_legacy_offset
	racer = racer_definition
	race_seed = seed
	if racer == null:
		racer = RacerDefinition.create(
			&"legacy", kart.racer_name, kart.body_color, kart.stats,
			AiProfile.new()
		)
	elif difficulty != null:
		var effective := RacerDefinition.create(racer.id, racer.display_name, racer.body_color, racer.kart_stats, difficulty.apply_to(racer.ai_profile))
		effective.portrait = racer.portrait
		effective.default_kart_visual = racer.default_kart_visual
		racer = effective
	if kart != null:
		kart.recovered.connect(_handle_recovery)
		kart.hit_received.connect(_handle_impact)
		kart.barrier_contact.connect(_handle_barrier_contact)


func _physics_process(delta: float) -> void:
	if kart == null or race_manager == null or race_manager.route_points.is_empty():
		return
	if racing_line == null or not racing_line.is_valid():
		_legacy_drive(delta)
		return
	_item_cooldown = maxf(_item_cooldown - delta, 0.0)
	_correction_remaining = maxf(_correction_remaining - delta, 0.0)
	_update_contact_state(delta)
	_update_held_item_time(delta)
	var next_index := race_manager.get_next_checkpoint_index(kart)
	var next_checkpoint := race_manager.route_points[next_index]
	var checkpoint_distance := kart.global_position.distance_to(next_checkpoint)
	if _update_progress_recovery(delta, next_index, checkpoint_distance):
		return
	var projection := racing_line.project(kart.global_position, _projection_hint)
	_projection_hint = projection.sample_index
	_update_shortcut_choice(projection.distance)
	if _active_branch_id >= 0:
		var branch_projection := racing_line.project_branch(kart.global_position, _active_branch_id, _branch_projection_hint)
		if branch_projection.sample_index >= 0:
			projection = branch_projection
			_branch_projection_hint = projection.sample_index
		var active_branch := racing_line.get_branch(_active_branch_id)
		if (
			active_branch == null
			or projection.distance >= active_branch.samples[-1].distance - 2.0
			or projection.distance_squared > 64.0
		):
			_active_branch_id = -1
			_branch_projection_hint = -1
			projection = racing_line.project(kart.global_position, _projection_hint)
	var current_sample := racing_line.sample_at_distance(projection.distance, _active_branch_id)
	if current_sample == null:
		_legacy_drive(delta)
		return
	_update_section_variation(current_sample.section_id)
	var profile := racer.ai_profile
	var speed := kart.get_horizontal_speed()
	var reaction_delay := profile.reaction_time + float(_section_variation.get("reaction", 0.0))
	var lookahead := clampf(5.5 + speed * (0.34 + reaction_delay), 7.0, 19.0)
	var target_sample := racing_line.sample_at_distance(projection.distance + lookahead, _active_branch_id)
	if target_sample == null:
		target_sample = current_sample
	var right := Vector3.UP.cross(target_sample.forward).normalized()
	var correction_factor := clampf(_correction_remaining / 4.5, 0.0, 1.0)
	var available_variation := maxf(target_sample.available_width - absf(target_sample.lateral_offset), 0.0)
	var section_offset := clampf(
		float(_section_variation.get("offset", 0.0)),
		-available_variation,
		available_variation
	) * (1.0 - correction_factor)
	if _drive_state != DriveState.DRIVING:
		section_offset = 0.0
	var target := target_sample.position + right * section_offset
	var forward := -kart.global_transform.basis.z.normalized()
	var to_target := (target - kart.global_position).normalized()
	var angular_error := -forward.cross(to_target).y
	var lateral_gain := lerpf(0.09, 0.16, profile.precision + correction_factor * (1.0 - profile.precision))
	var line_steer := clampf(angular_error * 1.9 - projection.lateral_error * lateral_gain - target_sample.curvature * 2.4, -1.0, 1.0)
	var sensors := _sense_barriers(speed)
	var steer := _apply_barrier_steering(line_steer, sensors, target_sample.forward)
	steer = _apply_racer_avoidance(steer, forward)
	var steer_response := lerpf(4.5, 8.5, 1.0 - profile.reaction_time)
	_smoothed_steer = move_toward(_smoothed_steer, steer, delta * steer_response)
	steer = _smoothed_steer
	var safe_line_ratio := racing_line.get_minimum_speed_ratio(projection.distance, lookahead + 9.0)
	var speed_ratio := minf(
		safe_line_ratio,
		safe_line_ratio
		+ float(_section_variation.get("speed", 0.0))
		+ float(_section_variation.get("braking", 0.0))
	)
	speed_ratio -= correction_factor * 0.12
	var safe_speed := _calculate_safe_speed(
		target_sample, projection.lateral_error, sensors, speed_ratio
	)
	# Aggression approaches the safe limit; it never raises that limit.
	var target_speed := safe_speed * lerpf(0.96, 1.0, profile.aggression)
	if _drive_state == DriveState.WALL_RECOVERY:
		target_speed = minf(target_speed, kart.stats.max_speed * 0.3)
	var speed_error := target_speed - speed
	var wanted_throttle := clampf(speed_error / maxf(kart.stats.max_speed * 0.16, 1.0), 0.0, 1.0)
	var wanted_brake := clampf(-speed_error / maxf(kart.stats.max_speed * 0.13, 1.0), 0.0, 1.0)
	if float(sensors.front) < 0.22:
		wanted_throttle = minf(wanted_throttle, 0.18)
		wanted_brake = maxf(wanted_brake, lerpf(0.45, 1.0, 1.0 - float(sensors.front)))
	if _drive_state == DriveState.WALL_RECOVERY:
		wanted_throttle = minf(wanted_throttle, 0.32)
		wanted_brake = maxf(wanted_brake, 0.12 if speed > target_speed else 0.0)
	_smoothed_throttle = move_toward(_smoothed_throttle, wanted_throttle, delta * 2.8)
	_smoothed_brake = move_toward(_smoothed_brake, wanted_brake, delta * 3.8)
	if _smoothed_brake > 0.08:
		_smoothed_throttle = minf(_smoothed_throttle, 0.15)
	var should_drift := _update_drift_decision(current_sample, steer, speed, safe_speed, sensors)
	var should_use_item := _should_use_item(forward) if _drive_state != DriveState.WALL_RECOVERY else false
	if should_use_item:
		_item_cooldown = lerpf(4.8, 2.4, profile.item_efficiency)
	kart.set_drive_input(_smoothed_throttle, _smoothed_brake, steer, should_drift, should_use_item)
	telemetry.lateral_error = projection.lateral_error
	telemetry.target_speed = target_speed
	telemetry.actual_speed = speed
	telemetry.braking_time += delta if _smoothed_brake > 0.2 else 0.0
	telemetry.drift_time += delta if should_drift else 0.0
	telemetry.avoidance_time += delta if _drive_state != DriveState.DRIVING else 0.0
	telemetry.maximum_lateral_error = maxf(telemetry.maximum_lateral_error, absf(projection.lateral_error))
	_previous_velocity = kart.velocity


func _update_section_variation(section_id: int) -> void:
	if section_id == _current_section_id:
		return
	_current_section_id = section_id
	var lap := int(
		race_manager.get_completed_checkpoint_count(kart)
		/ maxi(race_manager.route_points.size(), 1)
	)
	var rng := RandomNumberGenerator.new()
	var key := "%d|%s|%d|%d" % [race_seed, racer.id, lap, section_id]
	rng.seed = key.hash()
	var error_scale := 1.0 - racer.ai_profile.precision
	_section_variation = {
		"offset": rng.randf_range(-1.25, 1.25) * error_scale,
		"speed": rng.randf_range(-0.1, 0.06) * error_scale,
		"braking": rng.randf_range(-0.08, 0.08) * error_scale,
		"reaction": rng.randf_range(0.0, 0.16) * error_scale,
		"omit_drift": rng.randf() > racer.ai_profile.drift_usage,
	}
	_drift_section_id = -1
	_drift_committed = false


func _update_drift_decision(sample: RacingLineSample, steer: float, speed: float, safe_speed: float, sensors: Dictionary) -> bool:
	if (
		_drive_state != DriveState.DRIVING
		or float(sensors.front) < 0.24
		or float(sensors.left) < 0.14
		or float(sensors.right) < 0.14
		or absf(telemetry.lateral_error) > sample.available_width * 0.55
		or speed > safe_speed
	):
		_drift_committed = false
		return false
	if sample.section_id != _drift_section_id:
		_drift_section_id = sample.section_id
		_drift_committed = (
			absf(sample.curvature) > 0.018
			and absf(steer) > 0.32
			and speed > kart.stats.max_speed * 0.34
			and not bool(_section_variation.get("omit_drift", false))
		)
	if _drift_committed and (absf(sample.curvature) < 0.007 or absf(steer) < 0.12):
		_drift_committed = false
	return _drift_committed


func _update_shortcut_choice(distance: float) -> void:
	if _active_branch_id >= 0 or _correction_remaining > 0.0 or _drive_state != DriveState.DRIVING:
		return
	# Shortcut eligibility is driven by authored branch risk and the AI profile.
	# Race class affects the shared driving parameters through Kart.stats.
	for branch in racing_line.shortcut_branches:
		var key := "%d:%d" % [race_manager.get_completed_checkpoint_count(kart), branch.shortcut_id]
		if _decided_branches.has(key):
			continue
		var approach := branch.entry_distance - distance
		if approach < 0.0:
			approach += racing_line.total_length
		if approach > 18.0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = ("%d|%s|shortcut|%s" % [race_seed, racer.id, key]).hash()
		var profile := racer.ai_profile
		var safe_risk_ceiling := profile.risk_tolerance
		var eligible := (
			profile.precision >= branch.minimum_precision
			and branch.risk <= safe_risk_ceiling
		)
		var risk_factor := clampf(1.0 - maxf(branch.risk - profile.risk_tolerance, 0.0), 0.0, 1.0)
		var selected := eligible and rng.randf() < profile.shortcut_probability * risk_factor
		_decided_branches[key] = selected
		telemetry.shortcut_decisions += 1
		if selected:
			_active_branch_id = branch.shortcut_id
			_branch_projection_hint = -1
		return


func _handle_recovery() -> void:
	_correction_remaining = 4.5
	_active_branch_id = -1
	_branch_projection_hint = -1
	telemetry.recoveries += 1
	if kart.last_recovery_reason == "navigation" or kart.last_recovery_reason == "wall_recovery":
		telemetry.hard_resets += 1
	_drive_state = DriveState.DRIVING
	_barrier_contact_time = 0.0
	_recovery_time = 0.0


func _handle_impact() -> void:
	_correction_remaining = maxf(_correction_remaining, 2.5)
	telemetry.impacts += 1


func _handle_barrier_contact(normal: Vector3, _incident_ratio: float, continuing_contact: bool) -> void:
	_contact_normal = normal
	_contact_grace_remaining = CONTACT_GRACE
	if not continuing_contact:
		telemetry.barrier_contacts += 1


func _update_contact_state(delta: float) -> void:
	_contact_grace_remaining = maxf(_contact_grace_remaining - delta, 0.0)
	if _contact_grace_remaining > 0.0:
		_barrier_contact_time += delta
		telemetry.barrier_contact_time += delta
	else:
		_barrier_contact_time = 0.0
		if _drive_state == DriveState.WALL_RECOVERY:
			_drive_state = DriveState.DRIVING
			_recovery_time = 0.0
	if _barrier_contact_time >= WALL_RECOVERY_CONTACT_TIME and _drive_state != DriveState.WALL_RECOVERY:
		_drive_state = DriveState.WALL_RECOVERY
		_recovery_time = 0.0
		_drift_committed = false
		telemetry.wall_recoveries += 1
	if _drive_state == DriveState.WALL_RECOVERY:
		_recovery_time += delta
		if _recovery_time >= WALL_RECOVERY_RESET_TIME:
			kart.reset_to_last_checkpoint("wall_recovery")


func _sense_barriers(speed: float) -> Dictionary:
	var forward := -kart.global_transform.basis.z.normalized()
	var right := kart.global_transform.basis.x.normalized()
	var speed_ratio := clampf(speed / maxf(kart.stats.max_speed, 0.1), 0.0, 1.0)
	var sensor_range := lerpf(SENSOR_MINIMUM_RANGE, SENSOR_MAXIMUM_RANGE, speed_ratio)
	var side_range := lerpf(3.5, 5.0, speed_ratio)
	var origin := kart.global_position + Vector3.UP * 0.55
	return {
		"front": _cast_barrier_sensor(origin, forward, sensor_range),
		"left": _cast_barrier_sensor(origin - right * 0.55, (forward * 0.35 - right).normalized(), side_range),
		"right": _cast_barrier_sensor(origin + right * 0.55, (forward * 0.35 + right).normalized(), side_range),
	}


func _cast_barrier_sensor(origin: Vector3, direction: Vector3, length: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * length, PhysicsLayers.BARRIERS)
	query.exclude = [kart.get_rid()]
	var hit := kart.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	return clampf(origin.distance_to(hit.position) / length, 0.0, 1.0)


func _apply_barrier_steering(line_steer: float, sensors: Dictionary, line_forward: Vector3) -> float:
	var front := float(sensors.front)
	var left := float(sensors.left)
	var right := float(sensors.right)
	if _drive_state == DriveState.WALL_RECOVERY:
		var tangent := _contact_normal.cross(Vector3.UP).normalized()
		if tangent.dot(line_forward) < 0.0:
			tangent = -tangent
		var forward := -kart.global_transform.basis.z.normalized()
		return clampf(-forward.cross((tangent + _contact_normal * 0.3).normalized()).y * 2.4, -1.0, 1.0)
	var front_threat := clampf((0.24 - front) / 0.18, 0.0, 1.0)
	var side_threat := clampf((0.16 - minf(left, right)) / 0.11, 0.0, 1.0)
	var threat := maxf(front_threat, side_threat)
	if threat <= 0.0:
		_drive_state = DriveState.DRIVING
		return line_steer
	_drive_state = DriveState.AVOIDING_WALL
	var avoidance := 0.0
	if front < 0.24:
		avoidance = -1.0 if left > right else 1.0
	else:
		avoidance = clampf((right - left) * 1.8, -1.0, 1.0)
	var weight := lerpf(0.25, 1.0, threat)
	return lerpf(line_steer, avoidance, weight)


func _calculate_safe_speed(sample: RacingLineSample, lateral_error: float, sensors: Dictionary, line_ratio: float) -> float:
	var maximum := kart.stats.max_speed
	var line_limit := maximum * clampf(line_ratio, 0.52, 1.0)
	var curvature := absf(sample.curvature)
	var turn_limit := maximum
	if curvature > 0.001:
		var lateral_capacity := maxf(kart.stats.steering_speed * kart.stats.grip * 1.45, 1.0)
		turn_limit = sqrt(lateral_capacity / curvature)
	var lateral_ratio := clampf(absf(lateral_error) / maxf(sample.available_width, 0.5), 0.0, 1.0)
	var lateral_limit := maximum * lerpf(1.0, 0.58, lateral_ratio)
	var front_ratio := float(sensors.front)
	var front_distance := front_ratio * lerpf(SENSOR_MINIMUM_RANGE, SENSOR_MAXIMUM_RANGE, clampf(kart.get_horizontal_speed() / maxf(maximum, 0.1), 0.0, 1.0))
	var barrier_limit := maximum
	if front_ratio < 0.3:
		barrier_limit = sqrt(maxf(2.0 * kart.stats.braking * maxf(front_distance - 1.6, 0.0), 0.0))
	return clampf(minf(line_limit, minf(turn_limit, minf(lateral_limit, barrier_limit))), maximum * 0.22, maximum)


func _legacy_drive(delta: float) -> void:
	_item_cooldown = maxf(_item_cooldown - delta, 0.0)
	_update_held_item_time(delta)
	var next_index := race_manager.get_next_checkpoint_index(kart)
	var checkpoint := race_manager.route_points[next_index]
	var checkpoint_distance := kart.global_position.distance_to(checkpoint)
	if _update_progress_recovery(delta, next_index, checkpoint_distance):
		return
	var speed := kart.get_horizontal_speed()
	var speed_ratio := clampf(speed / maxf(kart.stats.max_speed, 0.1), 0.0, 1.2)
	var high_speed_class := kart.race_class != null and kart.race_class.id == &"200"
	var lookahead_steps := clampi(
		2 + roundi(speed_ratio * 1.5) + (1 if high_speed_class else 0),
		2,
		5
	)
	var lookahead_index := (next_index + lookahead_steps) % race_manager.route_points.size()
	var target := race_manager.route_points[lookahead_index]
	var forward := -kart.global_transform.basis.z.normalized()
	var to_target := (target - kart.global_position).normalized()
	var steer := clampf(-forward.cross(to_target).y * 2.2, -1.0, 1.0)
	var alignment := forward.dot(to_target)
	var brake := 0.0
	var throttle := 1.0
	var corner_alignment_threshold := 0.72 if high_speed_class else 0.69
	var corner_speed_ratio := 0.65 if high_speed_class else 0.72
	if alignment < -0.1:
		throttle = 0.0
		brake = 1.0 if speed > kart.stats.max_speed * 0.08 else 0.7
		if speed <= kart.stats.max_speed * 0.08:
			steer = -steer
	elif alignment < corner_alignment_threshold and speed > kart.stats.max_speed * corner_speed_ratio:
		brake = 0.7 if high_speed_class else 0.55
		throttle = 0.15 if high_speed_class else 0.25
	elif alignment < 0.82:
		throttle = 0.72
	var sensors := _sense_barriers(speed)
	steer = _apply_barrier_steering(steer, sensors, to_target)
	steer = _apply_racer_avoidance(steer, forward)
	_smoothed_steer = move_toward(_smoothed_steer, steer, delta * 8.0)
	steer = _smoothed_steer
	if float(sensors.front) < 0.22:
		throttle = minf(throttle, 0.12)
		brake = maxf(brake, 0.8)
	if _drive_state == DriveState.WALL_RECOVERY:
		throttle = minf(throttle, 0.3)
		brake = maxf(brake, 0.1)
	var drift := (
		_drive_state == DriveState.DRIVING
		and absf(steer) > 0.48
		and speed > kart.stats.max_speed * 0.38
		and checkpoint_distance < maxf(18.0, speed * (1.0 if high_speed_class else 0.8))
	)
	var use_item := _should_use_item(forward) if _drive_state != DriveState.WALL_RECOVERY else false
	if use_item:
		_item_cooldown = 3.5
	kart.set_drive_input(throttle, brake, steer, drift, use_item)
	telemetry.target_speed = kart.stats.max_speed * corner_speed_ratio if brake > 0.0 else kart.stats.max_speed
	telemetry.actual_speed = speed
	telemetry.braking_time += delta if brake > 0.2 else 0.0
	telemetry.drift_time += delta if drift else 0.0
	telemetry.avoidance_time += delta if _drive_state != DriveState.DRIVING else 0.0


func _apply_racer_avoidance(line_steer: float, forward: Vector3) -> float:
	# A full eight-kart grid puts several rivals directly behind each other. Let
	# AI karts choose an overtaking side before CharacterBody collision can turn
	# a stationary local player into a permanent roadblock.
	var nearest_distance := INF
	var nearest_lateral := 0.0
	var right := kart.global_transform.basis.x.normalized()
	for candidate_value in race_manager.racers:
		var candidate := candidate_value as Kart
		if candidate == null or candidate == kart:
			continue
		var offset := candidate.global_position - kart.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < 0.1 or distance > 10.0:
			continue
		var forward_distance := offset.dot(forward)
		var lateral_distance := offset.dot(right)
		if forward_distance <= 0.5 or absf(lateral_distance) > 2.8:
			continue
		if forward.dot(offset / distance) < 0.72 or distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_lateral = lateral_distance
	if not is_finite(nearest_distance):
		return line_steer
	var avoidance_side := 0.0
	if absf(nearest_lateral) > 0.25:
		avoidance_side = -signf(nearest_lateral)
	else:
		var grid_row := maxi(kart.participant_slot, 0) / 2
		avoidance_side = 1.0 if grid_row % 2 == 1 else -1.0
	var weight := clampf((10.0 - nearest_distance) / 7.5, 0.0, 0.9)
	return lerpf(line_steer, avoidance_side, weight)


func _update_progress_recovery(
	delta: float,
	checkpoint_index: int,
	checkpoint_distance: float
) -> bool:
	if checkpoint_index != _last_checkpoint_index:
		_last_checkpoint_index = checkpoint_index
		_best_checkpoint_distance = checkpoint_distance
		_checkpoint_stall_time = 0.0
		return false
	if checkpoint_distance < _best_checkpoint_distance - 0.75:
		_best_checkpoint_distance = checkpoint_distance
		_checkpoint_stall_time = 0.0
		return false
	if not kart.is_control_enabled:
		return false
	_checkpoint_stall_time += delta
	if _checkpoint_stall_time < 4.0:
		return false
	kart.reset_to_last_checkpoint("navigation")
	_best_checkpoint_distance = INF
	_checkpoint_stall_time = 0.0
	return true


func _should_use_item(forward: Vector3) -> bool:
	if kart.held_item == null or _item_cooldown > 0.0:
		return false
	match kart.held_item.type:
		ItemDefinition.ItemType.BOOST:
			return _horizontal_speed() < kart.stats.max_speed * 0.9
		ItemDefinition.ItemType.TURBO_COCONUT:
			return _has_aligned_racer_ahead(forward, 22.0, 0.82)
		ItemDefinition.ItemType.SEA_BUBBLE:
			return true
		ItemDefinition.ItemType.SLIPPERY_PEEL:
			return _has_racer_behind(forward, 14.0) or _held_item_time >= 4.0
		ItemDefinition.ItemType.HOMING_PINEAPPLE:
			if _has_aligned_racer_ahead(forward, 40.0, 0.2):
				return true
			if _held_item_time >= 6.0:
				kart.request_straight_launch()
				return true
		ItemDefinition.ItemType.TROPICAL_WAVE:
			return (
				_has_visible_racer_in_range(kart.held_item.area_radius)
				or _held_item_time >= 6.0
			)
	return false


func _update_held_item_time(delta: float) -> void:
	if kart.held_item == null:
		_observed_item = null
		_held_item_time = 0.0
		return
	if kart.held_item != _observed_item:
		_observed_item = kart.held_item
		_held_item_time = 0.0
		return
	_held_item_time += delta


func _horizontal_speed() -> float:
	return Vector2(kart.velocity.x, kart.velocity.z).length()


func _has_aligned_racer_ahead(
	forward: Vector3,
	max_distance: float,
	minimum_alignment: float
) -> bool:
	var target := race_manager.get_racer_ahead(kart) as Node3D
	if target == null:
		return false
	var to_target := target.global_position - kart.global_position
	to_target.y = 0.0
	return (
		to_target.length() < max_distance
		and not to_target.is_zero_approx()
		and forward.dot(to_target.normalized()) > minimum_alignment
	)


func _has_racer_behind(forward: Vector3, max_distance: float) -> bool:
	for racer in race_manager.racers:
		var target := racer as Node3D
		if target == null or target == kart:
			continue
		var to_target := target.global_position - kart.global_position
		to_target.y = 0.0
		if (
			to_target.length() < max_distance
			and not to_target.is_zero_approx()
			and forward.dot(to_target.normalized()) < -0.55
		):
			return true
	return false


func _has_visible_racer_in_range(max_distance: float) -> bool:
	var origin := kart.global_position + Vector3.UP * 0.65
	for racer in race_manager.racers:
		var target := racer as Node3D
		if target == null or target == kart:
			continue
		var target_point := target.global_position + Vector3.UP * 0.65
		if (
			origin.distance_to(target_point) <= max_distance
			and ItemExecutor.has_clear_line_of_sight(
				kart.get_world_3d(),
				origin,
				target_point
			)
		):
			return true
	return false
