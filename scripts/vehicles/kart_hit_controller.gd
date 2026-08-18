class_name KartHitController
extends RefCounted

var kart: Kart


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func receive_hit(duration: float, threat: Node = null) -> Kart.HitResult:
	if kart._status_timers.is_invulnerable():
		return Kart.HitResult.IGNORED
	if kart._shield_controller.is_active():
		kart._shield_controller.clear_shield()
		kart.hit_blocked.emit(threat)
		return Kart.HitResult.BLOCKED
	kart._status_timers.apply_hitstun(duration, duration + 1.0)
	kart.velocity *= 0.45
	kart.rotation.y += PI * 0.3
	kart.hit_received.emit()
	return Kart.HitResult.APPLIED
