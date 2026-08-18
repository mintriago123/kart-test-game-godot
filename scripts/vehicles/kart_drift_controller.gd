class_name KartDriftController
extends RefCounted

var kart: Kart
var _grace_remaining := 0.0
var _low_quality_time := 0.0
var _presentation_quality := 0.0
var _charge := 0.0
var _side := 0.0


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func try_start_hop(steer: float) -> bool:
	var forward := -kart.global_transform.basis.z.normalized()
	var forward_speed := Vector3(kart.velocity.x, 0.0, kart.velocity.z).dot(forward)
	if absf(forward_speed) <= Kart.DRIFT_MINIMUM_SPEED:
		return false
	_side = 1.0 if steer >= 0.0 else -1.0
	kart._drive_state = Kart.DriveState.DRIFT_HOP
	refresh_hop_grace()
	kart.velocity.y = Kart.DRIFT_HOP_SPEED
	kart.floor_snap_length = 0.0
	return true


func update_charge(delta: float, steer: float) -> void:
	var local_velocity := kart.global_transform.basis.inverse() * kart.velocity
	var steer_quality := clampf(inverse_lerp(0.12, 0.55, absf(steer)), 0.0, 1.0)
	var slip_quality := clampf(inverse_lerp(0.3, 1.8, absf(local_velocity.x)), 0.0, 1.0)
	var quality := minf(steer_quality, slip_quality)
	_presentation_quality = quality
	if _grace_remaining > 0.0:
		quality = maxf(quality, kart.driving_tuning.minimum_drift_quality)
	if quality >= kart.driving_tuning.minimum_drift_quality:
		_low_quality_time = 0.0
		var rate := lerpf(0.5, 1.0, inverse_lerp(kart.driving_tuning.minimum_drift_quality, 1.0, quality))
		_charge = minf(_charge + delta * rate, kart.driving_tuning.drift_level_times[-1])
	else:
		_low_quality_time += delta
		if _low_quality_time > kart.driving_tuning.low_quality_grace:
			_charge = maxf(_charge - kart.driving_tuning.charge_loss_per_second * delta, 0.0)
		if _low_quality_time >= kart.driving_tuning.low_quality_cancel:
			cancel()
			return
	var level := get_level()
	var previous := 0.0 if level == 0 else kart.driving_tuning.drift_level_times[level - 1]
	var next := kart.driving_tuning.drift_level_times[min(level, kart.driving_tuning.drift_level_times.size() - 1)]
	kart.drift_charge_changed.emit(level, clampf(inverse_lerp(previous, next, _charge), 0.0, 1.0), quality)


func get_level() -> int:
	var level := 0
	for threshold in kart.driving_tuning.drift_level_times:
		if _charge >= threshold:
			level += 1
	return level


func release() -> void:
	var boost_level := get_level()
	if boost_level > 0:
		kart._activate_boost(
			kart.driving_tuning.mini_turbo_durations[boost_level - 1] * kart.stats.mini_turbo_duration_multiplier * kart._get_boost_multiplier(),
			kart.driving_tuning.mini_turbo_powers[boost_level - 1] * kart._get_boost_multiplier() * kart.current_surface.boost_multiplier
		)
		kart.mini_turbo_released.emit(boost_level)
	_clear_active_drift()
	if kart._drive_state == Kart.DriveState.DRIFT:
		kart._drive_state = Kart.DriveState.GROUND
	kart.boost_changed.emit(0.0)
	kart.drift_charge_changed.emit(0, 0.0, 0.0)


func cancel() -> void:
	_clear_active_drift()
	kart._drive_state = Kart.DriveState.GROUND if kart.is_on_floor() else Kart.DriveState.AIR
	kart.boost_changed.emit(0.0)
	kart.drift_charge_changed.emit(0, 0.0, 0.0)


func update(delta: float) -> void:
	_grace_remaining = maxf(_grace_remaining - delta, 0.0)


func reset() -> void:
	_grace_remaining = 0.0
	_clear_active_drift()


func reset_for_recovery() -> void:
	_low_quality_time = 0.0
	_charge = 0.0
	_side = 0.0


func _clear_active_drift() -> void:
	_low_quality_time = 0.0
	_presentation_quality = 0.0
	_charge = 0.0
	_side = 0.0


func refresh_hop_grace() -> void:
	_grace_remaining = kart.driving_tuning.hop_grace


func is_active() -> bool:
	return _side != 0.0


func get_side() -> float:
	return _side


func get_charge() -> float:
	return _charge


func get_presentation_quality() -> float:
	return _presentation_quality
