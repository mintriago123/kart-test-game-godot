class_name AiDriftDecision
extends RefCounted

var tuning: AiTuning
var current_section_id: int = -1
var committed: bool = false


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
	if (
		drive_state != AiRecoveryState.DriveState.DRIVING
		or float(sensors.front) < tuning.drift_sensor_front_min
		or float(sensors.left) < tuning.drift_sensor_side_min
		or float(sensors.right) < tuning.drift_sensor_side_min
		or absf(lateral_error) > sample.available_width * tuning.drift_lateral_error_ratio
		or speed > safe_speed
	):
		committed = false
		return false
	if sample.section_id != current_section_id:
		current_section_id = sample.section_id
		committed = (
			absf(sample.curvature) > tuning.drift_curvature_threshold
			and absf(steer) > tuning.drift_steer_threshold
			and speed > max_speed * tuning.drift_speed_ratio_threshold
			and section_allows_drift
			and drift_usage > 0.0
		)
	if committed and (
		absf(sample.curvature) < tuning.drift_curvature_release
		or absf(steer) < tuning.drift_steer_release
	):
		committed = false
	return committed


func reset() -> void:
	current_section_id = -1
	committed = false
