class_name AiDriver
extends Node

var kart: Kart
var race_manager: RaceManager
var racing_line: RacingLine
var racer: RacerDefinition
var race_seed := 0

var _tuning: AiTuning
var _personality: AiPersonality
var _buff: DifficultyBuff

var _steering: AiSteeringController
var _speed_planner: AiSpeedPlanner
var _drift: AiDriftDecision
var _shortcut: AiShortcutPlanner
var _items: AiItemDecision
var _recovery: AiRecoveryState
var _sensors: AiSensors

var _item_cooldown := 2.0
var _last_checkpoint_index := -1
var _best_checkpoint_distance := INF
var _checkpoint_stall_time := 0.0
var _projection_hint := -1
var _last_projection_distance := -1.0
var _projection_progress_valid := false
var _branch_projection_hint := -1
var _last_branch_projection_distance := -1.0
var _branch_projection_progress_valid := false
var _active_branch_id := -1
var _decided_branches: Dictionary = {}
var _current_section_id := -1
var _section_variation := {}
var _smoothed_throttle := 0.0
var _smoothed_brake := 0.0
var _steering_target := 0.0
var _smoothed_steer := 0.0
var _strategy_timer := 0.0
var _debug_log_timer := 0.0
var _telemetry_frame := 0
var _last_target_speed := 0.0
var _filtered_target_speed := 0.0
var _target_speed_initialized := false
var _last_safe_speed := 0.0
var _last_target_curvature := 0.0
var _last_recovery_reason := ""
var _recovery_reason_pending := false
var _last_completed_checkpoint_count := -1
var _telemetry: AiTelemetryRecorder

var telemetry := {
	"lateral_error": 0.0,
	"target_speed": 0.0,
	"safe_speed": 0.0,
	"target_curvature": 0.0,
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
	"recovery_reason": "",
	"recovery_count": 0,
}


func setup(
	controlled_kart: Kart,
	manager: RaceManager,
	line_or_legacy_offset: Variant = null,
	racer_definition: RacerDefinition = null,
	seed: int = 0,
	difficulty: DifficultyDefinition = null,
	tuning: AiTuning = null
) -> void:
	kart = controlled_kart
	race_manager = manager
	if line_or_legacy_offset is RacingLine:
		racing_line = line_or_legacy_offset
	racer = racer_definition
	race_seed = seed

	_tuning = tuning if tuning != null else _load_default_tuning()

	if racer == null:
		racer = RacerDefinition.create(
			&"legacy", kart.racer_name, kart.body_color, kart.stats,
			AiProfile.new()
		)
	elif difficulty != null:
		var effective := RacerDefinition.create(
			racer.id, racer.display_name, racer.body_color, racer.kart_stats,
			difficulty.apply_to(racer.ai_profile)
		)
		effective.portrait = racer.portrait
		effective.default_kart_visual = racer.default_kart_visual
		racer = effective

	if racer != null and racer.ai_profile != null:
		_personality = racer.ai_profile.personality
		_buff = racer.ai_profile.buff

	_steering = AiSteeringController.new()
	_steering.tuning = _tuning
	_steering.kart = kart

	_speed_planner = AiSpeedPlanner.new()
	_speed_planner.tuning = _tuning
	_speed_planner.kart = kart

	_drift = AiDriftDecision.new()
	_drift.tuning = _tuning

	_shortcut = AiShortcutPlanner.new()

	_items = AiItemDecision.new()
	_items.tuning = _tuning
	_items.kart = kart
	_items.race_manager = race_manager

	_recovery = AiRecoveryState.new()

	_sensors = AiSensors.new()
	_sensors.tuning = _tuning
	_sensors.kart = kart

	if kart != null:
		kart.recovered.connect(_handle_recovery)
		kart.hit_received.connect(_handle_impact)
		kart.barrier_contact.connect(_handle_barrier_contact)

	if _tuning != null and _tuning.enable_telemetry_recording:
		_telemetry = AiTelemetryRecorder.new()
		_telemetry.open_for_race(race_seed, racer.id, _tuning.telemetry_flush_interval)
		if race_manager != null and not race_manager.race_completed.is_connected(_close_telemetry):
			race_manager.race_completed.connect(_close_telemetry)


func _close_telemetry(_result: Variant = null) -> void:
	if _telemetry != null:
		_telemetry.close()
		_telemetry = null


func _physics_process(delta: float) -> void:
	if kart == null or race_manager == null or race_manager.route_points.is_empty():
		return
	if racing_line == null or not racing_line.is_valid():
		_legacy_drive()
		return

	_strategy_timer += delta
	var strategy_tick := 1.0 / maxf(_tuning.strategy_tick_hz, 1.0)
	if _strategy_timer >= strategy_tick:
		_run_strategy()
		_strategy_timer = 0.0

	if _recovery.update(delta, _tuning):
		kart.reset_to_last_checkpoint("wall_recovery")

	_items.update(delta)

	var frame := _perceive_frame()
	if frame.should_reset:
		return

	var decision := _decide(frame, delta)
	_actuate(decision)
	_record_telemetry(frame, decision, delta)
	_maybe_debug_log(delta)


func _run_strategy() -> void:
	_update_shortcut_choice()
	_update_section_variation()


func _perceive_frame() -> PerceivedFrame:
	var next_index := race_manager.get_next_checkpoint_index(kart)
	var next_checkpoint := race_manager.route_points[next_index]
	var checkpoint_distance := kart.global_position.distance_to(next_checkpoint)
	if _update_progress_recovery(checkpoint_distance):
		return PerceivedFrame.new(true)
	var completed_checkpoint_count := race_manager.get_completed_checkpoint_count(kart)
	var crossed_finish := (
		_last_completed_checkpoint_count >= 0
		and completed_checkpoint_count > _last_completed_checkpoint_count
		and next_index == 1
	)
	_last_completed_checkpoint_count = completed_checkpoint_count
	var allow_lap_wrap := (
		crossed_finish
		or (
			_projection_progress_valid
			and _last_projection_distance > racing_line.total_length * 0.75
			and next_index == 1
		)
	)

	var projection := racing_line.project(
		kart.global_position,
		_projection_hint,
		_last_projection_distance if _projection_progress_valid else -1.0,
		allow_lap_wrap
	)
	_projection_hint = projection.sample_index
	if projection.sample_index >= 0:
		_last_projection_distance = projection.distance
		_projection_progress_valid = true
	_update_shortcut_choice_at(projection.distance)

	if _active_branch_id >= 0:
		var branch_projection := racing_line.project_branch(
			kart.global_position,
			_active_branch_id,
			_branch_projection_hint,
			_last_branch_projection_distance if _branch_projection_progress_valid else -1.0
		)
		if branch_projection.sample_index >= 0:
			projection = branch_projection
			_branch_projection_hint = projection.sample_index
			_last_branch_projection_distance = projection.distance
			_branch_projection_progress_valid = true
		var active_branch := racing_line.get_branch(_active_branch_id)
		if (
			active_branch == null
			or projection.distance >= active_branch.samples[-1].distance - 2.0
			or projection.distance_squared > 64.0
		):
			_active_branch_id = -1
			_branch_projection_hint = -1
			_last_branch_projection_distance = -1.0
			_branch_projection_progress_valid = false
			projection = racing_line.project(
				kart.global_position,
				_projection_hint,
				_last_projection_distance if _projection_progress_valid else -1.0,
				false
			)

	var current_sample := racing_line.sample_at_distance(projection.distance, _active_branch_id)
	if current_sample == null:
		return PerceivedFrame.new(true)

	_update_section_variation_for(current_sample.section_id)

	var speed := kart.get_horizontal_speed()
	var reaction_delay := _personality.reaction_time + float(_section_variation.get("reaction", 0.0))
	var lookahead := _speed_planner.compute_lookahead(speed, reaction_delay, _buff.lookahead_max_multiplier)
	var sensors := _sensors.sense(speed)
	return PerceivedFrame.new(false, speed, reaction_delay, lookahead, projection, sensors)


func _decide(frame: PerceivedFrame, delta: float) -> AiDecision:
	var projection: Variant = frame.projection
	var current_sample := racing_line.sample_at_distance(projection.distance, _active_branch_id)
	var target_sample := racing_line.sample_at_distance(projection.distance + frame.lookahead, _active_branch_id)
	if target_sample == null:
		target_sample = current_sample

	var right := target_sample.forward.cross(Vector3.UP).normalized()
	var correction_factor := clampf(_recovery.correction_remaining / 4.5, 0.0, 1.0)
	var available_variation := maxf(target_sample.available_width - absf(target_sample.lateral_offset), 0.0)
	var section_offset := clampf(
		float(_section_variation.get("offset", 0.0)),
		-available_variation,
		available_variation
	) * (1.0 - correction_factor)
	if _recovery.state != AiRecoveryState.DriveState.DRIVING:
		section_offset = 0.0
	var target := target_sample.position + right * section_offset
	var forward := -kart.global_transform.basis.z.normalized()

	var safe_line_ratio := racing_line.get_minimum_speed_ratio(projection.distance, frame.lookahead + 9.0)
	var speed_ratio := minf(
		safe_line_ratio,
		safe_line_ratio
		+ float(_section_variation.get("speed", 0.0))
		+ float(_section_variation.get("braking", 0.0))
	)
	speed_ratio -= correction_factor * 0.12

	var safe_speed := _speed_planner.compute_safe_speed(
		target_sample, projection.lateral_error, frame.sensors, speed_ratio
	)
	var raw_target_speed := _speed_planner.compute_target_speed(
		safe_speed,
		_personality.aggression,
		_buff.top_speed_bias,
		_recovery.state == AiRecoveryState.DriveState.WALL_RECOVERY,
		kart.stats.max_speed,
		_buff.wall_recovery_speed_ratio
	)
	if not _target_speed_initialized:
		_filtered_target_speed = raw_target_speed
		_target_speed_initialized = true
	else:
		_filtered_target_speed = _speed_planner.update_target_speed(
			_filtered_target_speed, raw_target_speed, delta
		)

	# Acceleration follows the filtered target. Braking always sees the raw
	# descending target so a newly discovered corner or barrier is acted on in
	# the same frame instead of waiting for the upward/downward filter.
	var acceleration_error := _filtered_target_speed - frame.speed
	var braking_error := raw_target_speed - frame.speed
	var wanted_throttle := _speed_planner.wanted_throttle(acceleration_error, kart.stats.max_speed)
	var wanted_brake := _speed_planner.wanted_brake(braking_error, kart.stats.max_speed)
	wanted_throttle = _speed_planner.clamp_throttle_under_threat(wanted_throttle, frame.sensors)
	wanted_brake = _speed_planner.clamp_brake_under_threat(wanted_brake, frame.sensors)
	if _recovery.state == AiRecoveryState.DriveState.WALL_RECOVERY:
		wanted_throttle = minf(wanted_throttle, _tuning.wall_recovery_throttle_ceiling)
		wanted_brake = maxf(wanted_brake,
			_tuning.wall_recovery_brake_min if frame.speed > raw_target_speed else 0.0)

	var line_steer := _steering.compute_line_steer(
		target, forward, projection.lateral_error,
		target_sample.curvature, correction_factor, _personality.precision,
		target_sample.available_width
	)
	var steer := _steering.apply_barrier_steering(
		line_steer, frame.sensors, target_sample.forward,
		_recovery.contact_normal, _recovery.state
	)
	if _recovery.state == AiRecoveryState.DriveState.WALL_RECOVERY:
		# The contact-normal arc is an emergency escape command. Do not delay it
		# behind either steering filter while the kart is pressed into a wall.
		_steering_target = steer
		_smoothed_steer = steer
	else:
		steer = _steering.apply_racer_avoidance(
			steer, forward, race_manager.racers, kart.participant_slot,
			_buff.avoidance_weight_max
		)
		steer = _steering.stabilize_straight_target(
			steer, _steering_target, target_sample.curvature, frame.sensors
		)
		_steering_target = _steering.update_target_steer(
			steer, _steering_target, delta
		)
		var previous_smoothed_steer := _smoothed_steer
		_smoothed_steer = _steering.update_smoothed_steer(
			_steering_target, _smoothed_steer, _personality.reaction_time,
			_buff.response_multiplier, delta
		)
		_smoothed_steer = _steering.stabilize_straight_output(
			_smoothed_steer, previous_smoothed_steer,
			target_sample.curvature, frame.sensors
		)

	_smoothed_throttle = _speed_planner.update_throttle(
		_smoothed_throttle, wanted_throttle, _buff.response_multiplier, delta
	)
	_smoothed_brake = _speed_planner.update_brake(
		_smoothed_brake, wanted_brake, _buff.response_multiplier, delta
	)
	_smoothed_throttle = _speed_planner.clamp_throttle_when_braking(
		_smoothed_throttle, _smoothed_brake
	)

	var section_allows_drift := not bool(_section_variation.get("omit_drift", false))
	var should_drift := _drift.update(
		target_sample, _smoothed_steer, frame.speed, safe_speed,
		frame.sensors, projection.lateral_error,
		_recovery.state, kart.stats.max_speed,
		_personality.drift_usage, section_allows_drift
	)
	var should_use_item := false
	if _recovery.state != AiRecoveryState.DriveState.WALL_RECOVERY:
		should_use_item = _items.should_use(forward, _recovery.state)
		if should_use_item and kart.held_item != null:
			var cooldown := lerpf(_tuning.item_cooldown_max, _tuning.item_cooldown_min, _personality.item_efficiency)
			_items.notify_item_used(kart.held_item, cooldown)
			_item_cooldown = cooldown

	_last_target_speed = _filtered_target_speed
	_last_safe_speed = safe_speed
	_last_target_curvature = target_sample.curvature
	telemetry.safe_speed = safe_speed
	telemetry.target_curvature = target_sample.curvature
	return AiDecision.new(_smoothed_throttle, _smoothed_brake, _smoothed_steer, should_drift, should_use_item)


func _actuate(decision: AiDecision) -> void:
	kart.set_drive_input(decision.throttle, decision.brake, decision.steer, decision.drift, decision.use_item)


func _record_telemetry(frame: PerceivedFrame, decision: AiDecision, delta: float) -> void:
	if frame.projection != null:
		telemetry.lateral_error = frame.projection.lateral_error
		telemetry.maximum_lateral_error = maxf(
			telemetry.maximum_lateral_error, absf(frame.projection.lateral_error)
		)
	telemetry.target_speed = _last_target_speed
	telemetry.actual_speed = frame.speed
	telemetry.recovery_reason = _last_recovery_reason
	telemetry.recovery_count = kart.recovery_count
	telemetry.braking_time += delta if _smoothed_brake > 0.2 else 0.0
	telemetry.drift_time += delta if decision.drift else 0.0
	telemetry.avoidance_time += 0.0 if _recovery.state == AiRecoveryState.DriveState.DRIVING else delta
	telemetry.barrier_contact_time = _recovery.barrier_contact_time

	if _telemetry != null:
		_telemetry_frame += 1
		var sens_front := 1.0
		var sens_left := 1.0
		var sens_right := 1.0
		if frame.sensors != null:
			sens_front = float(frame.sensors.get("front", 1.0))
			sens_left = float(frame.sensors.get("left", 1.0))
			sens_right = float(frame.sensors.get("right", 1.0))
		_telemetry.record(
			_telemetry_frame,
			Time.get_ticks_msec() / 1000.0,
			racer.id,
			frame.speed,
			_last_target_speed,
			_last_target_speed - frame.speed,
			_smoothed_throttle,
			_smoothed_brake,
			_smoothed_steer,
			_recovery.state,
			_drift.committed,
			sens_front,
			sens_left,
			sens_right,
			_current_section_id,
			_recovery.recovery_time,
			Engine.get_physics_frames(),
			frame.projection.sample_index if frame.projection != null else -1,
			frame.projection.distance if frame.projection != null else 0.0,
			frame.projection.lateral_error if frame.projection != null else 0.0,
			_last_safe_speed,
			_last_target_curvature,
			_last_recovery_reason if _recovery_reason_pending else "",
			kart.recovery_count,
			kart.global_position.x,
			kart.global_position.y,
			kart.global_position.z
		)
		_recovery_reason_pending = false


func _update_progress_recovery(checkpoint_distance: float) -> bool:
	var next_index := race_manager.get_next_checkpoint_index(kart)
	if next_index != _last_checkpoint_index:
		_last_checkpoint_index = next_index
		_best_checkpoint_distance = checkpoint_distance
		_checkpoint_stall_time = 0.0
		return false
	if checkpoint_distance < _best_checkpoint_distance - _tuning.progress_recovery_distance:
		_best_checkpoint_distance = checkpoint_distance
		_checkpoint_stall_time = 0.0
		return false
	if not kart.is_control_enabled:
		return false
	_checkpoint_stall_time += 1.0 / 60.0
	if _checkpoint_stall_time < _tuning.progress_stall_seconds:
		return false
	kart.reset_to_last_checkpoint("navigation")
	_best_checkpoint_distance = INF
	_checkpoint_stall_time = 0.0
	return true


func _update_shortcut_choice() -> void:
	pass


func _update_shortcut_choice_at(distance: float) -> void:
	if _active_branch_id >= 0 or _recovery.correction_remaining > 0.0 or _recovery.state != AiRecoveryState.DriveState.DRIVING:
		return
	var new_branch := _shortcut.select_branch(
		racing_line,
		distance,
		race_manager.get_completed_checkpoint_count(kart),
		race_seed,
		racer.id,
		_personality,
		_decided_branches
	)
	if new_branch >= 0:
		telemetry.shortcut_decisions += 1
		_active_branch_id = new_branch
		_branch_projection_hint = -1
		_last_branch_projection_distance = -1.0
		_branch_projection_progress_valid = false


func _update_section_variation() -> void:
	pass


func _update_section_variation_for(section_id: int) -> void:
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
	var error_scale := 1.0 - _personality.precision
	_section_variation = {
		"offset": rng.randf_range(-_tuning.section_offset_range, _tuning.section_offset_range) * error_scale,
		"speed": rng.randf_range(_tuning.section_speed_min, _tuning.section_speed_max) * error_scale,
		"braking": rng.randf_range(-_tuning.section_braking_range, _tuning.section_braking_range) * error_scale,
		"reaction": rng.randf_range(0.0, _tuning.section_reaction_max) * error_scale,
		"omit_drift": rng.randf() > _personality.drift_usage,
	}


func _handle_recovery() -> void:
	_recovery.notify_recovery(_tuning.recovery_correction_seconds)
	_drift.reset()
	_active_branch_id = -1
	_branch_projection_hint = -1
	_last_branch_projection_distance = -1.0
	_branch_projection_progress_valid = false
	_projection_hint = -1
	_last_projection_distance = -1.0
	_projection_progress_valid = false
	_steering_target = 0.0
	_smoothed_steer = 0.0
	_smoothed_throttle = 0.0
	_smoothed_brake = 0.0
	_last_recovery_reason = kart.last_recovery_reason
	_recovery_reason_pending = true
	telemetry.recoveries += 1
	telemetry.recovery_reason = _last_recovery_reason
	telemetry.recovery_count = kart.recovery_count
	if kart.last_recovery_reason == "navigation" or kart.last_recovery_reason == "wall_recovery":
		telemetry.hard_resets += 1


func _handle_impact() -> void:
	_recovery.notify_impact(_tuning.impact_correction_seconds)
	telemetry.impacts += 1


func _handle_barrier_contact(normal: Vector3, _incident_ratio: float, continuing_contact: bool) -> void:
	_recovery.notify_barrier_contact(normal, continuing_contact, _tuning)
	if not continuing_contact:
		telemetry.barrier_contacts += 1


func _legacy_drive() -> void:
	if kart == null:
		return
	push_warning("AI kart ", kart.racer_id, " has no racing line. Using minimal legacy fallback.")
	kart.set_drive_input(0.5, 0.0, 0.0, false, false)


# --- Compatibility wrappers used by tests/ai_barrier_avoidance.gd ---

func _sense_barriers(speed: float) -> Dictionary:
	_ensure_subsystems()
	return _sensors.sense(speed)


func _apply_barrier_steering(line_steer: float, sensors: Dictionary, line_forward: Vector3) -> float:
	_ensure_subsystems()
	return _steering.apply_barrier_steering(
		line_steer, sensors, line_forward, Vector3.ZERO,
		AiRecoveryState.DriveState.DRIVING
	)


func _load_default_tuning() -> AiTuning:
	if ResourceLoader.exists("res://tuning/ai_tuning.tres"):
		var loaded := load("res://tuning/ai_tuning.tres") as AiTuning
		if loaded != null:
			return loaded
	return AiTuning.defaults()


func _ensure_subsystems() -> void:
	if _sensors == null:
		if _tuning == null:
			_tuning = AiTuning.defaults()
		_sensors = AiSensors.new()
		_sensors.tuning = _tuning
		_sensors.kart = kart
	if _steering == null:
		if _tuning == null:
			_tuning = AiTuning.defaults()
		_steering = AiSteeringController.new()
		_steering.tuning = _tuning
		_steering.kart = kart


func _maybe_debug_log(delta: float) -> void:
	if _tuning == null or not _tuning.enable_debug_logging:
		return
	_debug_log_timer += delta
	if _debug_log_timer < _tuning.debug_log_interval:
		return
	_debug_log_timer = 0.0
	var item_id := "none" if kart == null or kart.held_item == null else str(kart.held_item.type)
	print("[AI:%s] speed=%.1f target=%.1f steer=%.2f recovery=%d item=%s"
		% [racer.id if racer != null else "?",
		kart.get_horizontal_speed() if kart != null else 0.0,
		_last_target_speed,
		_smoothed_steer,
		_recovery.state,
		item_id])


# --- Compatibility wrappers used by tests/item_behaviors.gd ---

func _should_use_item(forward: Vector3) -> bool:
	if _items == null:
		return false
	_items.update(0.0)
	return _items.should_use(forward, AiRecoveryState.DriveState.DRIVING)
