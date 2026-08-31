class_name AiDriftDecision
extends RefCounted

var tuning: AiTuning
var current_section_id: int = -1
var committed: bool = false
var _lock_timer: int = 0
var _hold_timer: int = 0


func update(
	sample,
	steer: float,
	speed: float,
	safe_speed: float,
	sensors: Dictionary,
	lateral_error: float,
	drive_state: int,
	max_speed: float,
	drift_usage: float,
	section_allows_drift: bool
) -> bool:
	var front := float(sensors.get("front", 1.0))
	var left := float(sensors.get("left", 1.0))
	var right := float(sensors.get("right", 1.0))
	var outside_lane: bool = absf(lateral_error) > sample.available_width * tuning.drift_lateral_error_ratio
	var ordinary_safety: bool = (
		drive_state != AiRecoveryState.DriveState.DRIVING
		or front < tuning.drift_sensor_front_min
		or left < tuning.drift_sensor_side_min
		or right < tuning.drift_sensor_side_min
		or outside_lane
		or speed > safe_speed
	)
	var extreme_safety: bool = (
		drive_state == AiRecoveryState.DriveState.WALL_RECOVERY
		or front < tuning.drift_extreme_front_min
		or left < tuning.drift_extreme_side_min
		or right < tuning.drift_extreme_side_min
		or absf(lateral_error) > sample.available_width * tuning.drift_extreme_lateral_error_ratio
	)
	if committed:
		_hold_timer = maxi(_hold_timer - 1, 0)
		if extreme_safety or (ordinary_safety and _hold_timer == 0):
			committed = false
			_hold_timer = 0
			_lock_timer = tuning.drift_lock_frames
			return false
		if _hold_timer > 0:
			return true
		if (
			absf(sample.curvature) < tuning.drift_curvature_cancel
			or absf(steer) < tuning.drift_steer_cancel
		):
			committed = false
			_lock_timer = tuning.drift_lock_frames
		return committed
	if ordinary_safety:
		committed = false
		_lock_timer = tuning.drift_lock_frames
		return false
	if _lock_timer > 0:
		_lock_timer -= 1
		return false
	if sample.section_id != current_section_id:
		current_section_id = sample.section_id
		committed = (
			absf(sample.curvature) > tuning.drift_curvature_commit
			and absf(steer) > tuning.drift_steer_commit
			and speed > max_speed * tuning.drift_speed_ratio_threshold
			and section_allows_drift
			and drift_usage > 0.0
		)
		if committed:
			_hold_timer = tuning.drift_min_hold_frames
			_lock_timer = 0
	if committed and (
		absf(sample.curvature) < tuning.drift_curvature_release
		or absf(steer) < tuning.drift_steer_release
	):
		committed = false
		_lock_timer = tuning.drift_lock_frames
	return committed


func reset() -> void:
	current_section_id = -1
	committed = false
	_lock_timer = 0
	_hold_timer = 0
