class_name AiRecoveryState
extends RefCounted

enum DriveState { DRIVING, AVOIDING_WALL, WALL_RECOVERY }

var state: int = DriveState.DRIVING
var contact_normal: Vector3 = Vector3.ZERO
var contact_grace_remaining: float = 0.0
var barrier_contact_time: float = 0.0
var recovery_time: float = 0.0
var correction_remaining: float = 0.0


func update(delta: float, tuning: AiTuning) -> bool:
	contact_grace_remaining = maxf(contact_grace_remaining - delta, 0.0)
	if contact_grace_remaining > 0.0:
		barrier_contact_time += delta
	else:
		barrier_contact_time = 0.0
		if state == DriveState.WALL_RECOVERY:
			state = DriveState.DRIVING
			recovery_time = 0.0
	if barrier_contact_time >= tuning.wall_recovery_contact_time and state != DriveState.WALL_RECOVERY:
		state = DriveState.WALL_RECOVERY
		recovery_time = 0.0
	if state == DriveState.WALL_RECOVERY:
		recovery_time += delta
		if recovery_time >= tuning.wall_recovery_reset_time:
			return true
	correction_remaining = maxf(correction_remaining - delta, 0.0)
	return false


func notify_barrier_contact(normal: Vector3, continuing_contact: bool, tuning: AiTuning) -> void:
	contact_normal = normal
	contact_grace_remaining = tuning.contact_grace


func notify_impact(correction_seconds: float) -> void:
	correction_remaining = maxf(correction_remaining, correction_seconds)


func notify_recovery(correction_seconds: float) -> void:
	correction_remaining = correction_seconds
	state = DriveState.DRIVING
	barrier_contact_time = 0.0
	recovery_time = 0.0


func notify_drift_cancelled() -> void:
	if state == DriveState.WALL_RECOVERY:
		recovery_time = 0.0
