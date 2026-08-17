class_name KartRecoveryController
extends Node

var kart: Kart
var respawn_transform := Transform3D.IDENTITY
var recovery_count := 0
var last_recovery_position := Vector3.ZERO
var last_recovery_reason := ""
var _stuck_time := 0.0
var _movement_sample_time := 0.0
var _movement_sample_distance := 0.0
var _last_motion_position := Vector3.ZERO


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart
	respawn_transform = kart.global_transform
	reset_sampling()


func set_respawn_transform(value: Transform3D) -> void:
	respawn_transform = value
	reset_sampling()


func reset_to_last_checkpoint(reason: String) -> void:
	last_recovery_position = kart.global_position
	last_recovery_reason = reason
	kart.set_shortcut_surface_enabled(false)
	kart.global_transform = respawn_transform
	kart.velocity = Vector3.ZERO
	kart._drive_state = Kart.DriveState.AIR
	kart._drift_controller.side = 0.0
	kart._drift_controller.charge = 0.0
	kart._drift_controller.low_quality_time = 0.0
	kart._input_controller.previous_drift = kart._input_controller.drift
	kart._status_timers.landing_compression_remaining = 0.0
	kart._collision_response.reset()
	kart.floor_snap_length = 0.0
	reset_sampling()
	recovery_count += 1
	kart.recovered.emit()


func reset_sampling() -> void:
	_stuck_time = 0.0
	_movement_sample_time = 0.0
	_movement_sample_distance = 0.0
	if kart != null:
		_last_motion_position = kart.global_position


func update(delta: float) -> void:
	if kart == null:
		return
	if kart.global_position.y < -2.5:
		kart.reset_to_last_checkpoint("fell")
		return
	var horizontal_motion := Vector2(
		kart.global_position.x - _last_motion_position.x,
		kart.global_position.z - _last_motion_position.z
	).length()
	_last_motion_position = kart.global_position
	if not kart.is_control_enabled or kart.get_throttle_input() <= 0.5:
		reset_sampling()
		return
	_movement_sample_time += delta
	_movement_sample_distance += horizontal_motion
	if _movement_sample_time < 1.25:
		return
	if _movement_sample_distance < 1.2:
		_stuck_time += _movement_sample_time
	else:
		_stuck_time = maxf(_stuck_time - _movement_sample_time * 1.5, 0.0)
	_movement_sample_time = 0.0
	_movement_sample_distance = 0.0
	if _stuck_time >= 3.0:
		kart.reset_to_last_checkpoint("stalled")
