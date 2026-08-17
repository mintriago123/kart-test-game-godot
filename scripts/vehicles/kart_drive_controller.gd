class_name KartDriveController
extends Node

var kart: Kart


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func physics_step(delta: float) -> void:
	kart._update_timers(delta)
	kart._input_controller.update()
	if kart._input_controller.consume_use_item_request():
		if kart.allow_item_execution:
			kart.use_item()

	var can_drive := kart.is_control_enabled and not kart._status_timers.is_stunned()
	kart._launch_controller.capture_input()
	var throttle := (
		kart._input_controller.throttle
		if can_drive and kart._status_timers.launch_bog_remaining <= 0.0
		else 0.0
	)
	var brake := kart._input_controller.brake if can_drive else 0.0
	var steer := kart._input_controller.steer if can_drive else 0.0
	var was_on_floor := kart.is_on_floor()
	var drift_was_pressed := (
		kart._input_controller.drift
		and not kart._input_controller.previous_drift
	)
	kart._input_controller.previous_drift = kart._input_controller.drift
	if not can_drive and kart._drift_controller.side != 0.0:
		kart._release_drift()
	if was_on_floor and kart._drive_state == Kart.DriveState.AIR:
		kart._drive_state = (
			Kart.DriveState.DRIFT
			if kart._input_controller.drift and kart._drift_controller.side != 0.0
			else Kart.DriveState.GROUND
		)

	var hop_started := false
	if was_on_floor and drift_was_pressed and can_drive:
		hop_started = kart._try_start_drift_hop(steer)
	if not kart._input_controller.drift and kart._drift_controller.side != 0.0:
		kart._release_drift()

	var is_ground_driving := was_on_floor and kart._drive_state != Kart.DriveState.DRIFT_HOP
	if is_ground_driving:
		kart._motor.apply_ground_drive(delta, throttle, brake, steer)
	else:
		kart._motor.apply_air_drive(delta, steer, hop_started)
	if kart._drive_state == Kart.DriveState.DRIFT and kart._input_controller.drift:
		kart._drift_controller.update_charge(delta, steer)

	kart._motor.update_floor_snap()
	var velocity_before_move := kart.velocity
	kart.move_and_slide()
	kart._collision_response.process(velocity_before_move)
	kart._motor.update_drive_state_after_move(was_on_floor)
	var is_drifting := (
		kart._drive_state == Kart.DriveState.DRIFT
		or kart._drive_state == Kart.DriveState.DRIFT_HOP
	)
	kart._animate_visual(delta, steer, is_drifting)
	kart._recovery_controller.update(delta)
