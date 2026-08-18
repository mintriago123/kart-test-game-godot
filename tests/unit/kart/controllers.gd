extends SceneTree

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pre_ready_defaults()
	_test_status_timers()
	_test_drift_reset()
	_test_boost_lifecycle()
	_test_recovery_sampling_reset()
	quit(1 if _has_failed else 0)


func _test_pre_ready_defaults() -> void:
	var kart := Kart.new()
	_check(
		kart.get_drive_state() == Kart.DriveState.AIR
		and kart.get_current_surface() != null
		and kart.held_item == null
		and kart.recovery_count == 0
		and is_zero_approx(kart.get_shield_remaining()),
		"Kart exposes coherent state defaults before entering the SceneTree."
	)
	kart.free()


func _test_status_timers() -> void:
	var status := KartStatusTimerController.new()
	status.apply_hitstun(0.8, 1.8)
	status.start_launch_bog(0.4)
	status.start_landing_compression(0.18)
	status.update(0.3)
	_check(
		is_equal_approx(status.get_stun_remaining(), 0.5)
		and status.is_invulnerable()
		and status.is_launch_bogged()
		and is_zero_approx(status.get_landing_compression_ratio(0.18)),
		"Status timers advance independently and clamp expired effects to zero."
	)
	status.reset()
	_check(
		not status.is_stunned()
		and not status.is_invulnerable()
		and not status.is_launch_bogged(),
		"Status reset clears every temporary effect."
	)


func _test_drift_reset() -> void:
	var kart := Kart.new()
	root.add_child(kart)
	kart.set_physics_process(false)
	var drift := KartDriftController.new()
	drift.setup(kart)
	kart.velocity = Vector3(2.0, 0.0, -10.0)
	drift.update_charge(0.7, 1.0)
	_check(
		drift.get_level() == 1
		and drift.get_charge() > 0.0
		and drift.get_presentation_quality() > 0.0,
		"Drift charge remains testable without adding its controller to the tree."
	)
	drift.reset()
	_check(
		drift.get_level() == 0
		and is_zero_approx(drift.get_charge())
		and is_zero_approx(drift.get_side()),
		"Drift reset clears its complete logical state."
	)
	kart.free()


func _test_boost_lifecycle() -> void:
	var kart := Kart.new()
	root.add_child(kart)
	kart.set_physics_process(false)
	var boost := KartBoostController.new()
	boost.setup(kart)
	boost.activate(0.5, 4.0)
	_check(
		boost.is_active()
		and is_equal_approx(boost.get_power(), 4.0)
		and is_equal_approx(kart.get_horizontal_speed(), 4.0),
		"Boost activation applies its initial impulse outside the SceneTree."
	)
	boost.update(0.5)
	_check(
		not boost.is_active() and is_zero_approx(boost.get_power()),
		"Boost expiration clears its power."
	)
	kart.free()


func _test_recovery_sampling_reset() -> void:
	var kart := Kart.new()
	root.add_child(kart)
	kart.set_physics_process(false)
	var recovery := KartRecoveryController.new()
	recovery.setup(kart)
	kart.is_control_enabled = true
	kart.set_drive_input(1.0, 0.0, 0.0, false, false)
	recovery.update(1.25)
	recovery.update(1.25)
	recovery.set_respawn_transform(kart.global_transform)
	recovery.update(1.25)
	recovery.update(1.25)
	_check(
		recovery.recovery_count == 0,
		"Changing the respawn transform clears accumulated stuck samples."
	)
	recovery.update(1.25)
	_check(
		recovery.recovery_count == 1
		and recovery.last_recovery_reason == "stalled",
		"Recovery still triggers after a fresh stationary sample window."
	)
	kart.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_has_failed = true
	push_error("FAIL: %s" % message)
