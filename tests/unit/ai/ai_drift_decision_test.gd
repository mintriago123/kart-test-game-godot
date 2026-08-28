extends SceneTree

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tuning := AiTuning.defaults()
	var decision := AiDriftDecision.new()
	decision.tuning = tuning
	var sample := _make_sample(0.05)
	var sensors := {"front": 0.5, "left": 0.5, "right": 0.5}

	_check(decision.update(sample, 0.5, 20.0, 25.0, sensors, 0.0,
			AiRecoveryState.DriveState.DRIVING, 30.0, 0.8, true) == true,
		"commits drift on tight curve with sufficient steer")

	_check(decision.update(sample, 0.05, 20.0, 25.0, sensors, 0.0,
			AiRecoveryState.DriveState.DRIVING, 30.0, 0.8, true) == false,
		"releases drift when steer drops below release threshold")

	var gentle_sample := _make_sample(0.005)
	decision.committed = false
	decision.current_section_id = -1
	_check(decision.update(gentle_sample, 0.5, 20.0, 25.0, sensors, 0.0,
			AiRecoveryState.DriveState.DRIVING, 30.0, 0.8, true) == false,
		"does not commit on gentle curve below threshold")

	var obstacle_sensors := {"front": 0.1, "left": 0.5, "right": 0.5}
	decision.committed = false
	decision.current_section_id = -1
	_check(decision.update(sample, 0.5, 20.0, 25.0, obstacle_sensors, 0.0,
			AiRecoveryState.DriveState.DRIVING, 30.0, 0.8, true) == false,
		"does not commit when front sensor detects wall")

	var wall_sensors := {"front": 0.5, "left": 0.05, "right": 0.5}
	decision.committed = false
	decision.current_section_id = -1
	_check(decision.update(sample, 0.5, 20.0, 25.0, wall_sensors, 0.0,
			AiRecoveryState.DriveState.DRIVING, 30.0, 0.8, true) == false,
		"does not commit when left sensor detects wall")

	_check(decision.update(sample, 0.5, 20.0, 25.0, sensors, 0.0,
			AiRecoveryState.DriveState.WALL_RECOVERY, 30.0, 0.8, true) == false,
		"does not commit during wall recovery state")

	if _failures == 0:
		print("AiDriftDecision tests passed.")
		quit(0)
	else:
		push_error("%d AiDriftDecision tests failed." % _failures)
		quit(1)


func _make_sample(curvature: float) -> RacingLineSample:
	var sample := RacingLineSample.new()
	sample.section_id = 0
	sample.position = Vector3.ZERO
	sample.forward = Vector3.FORWARD
	sample.curvature = curvature
	sample.available_width = 6.0
	sample.lateral_offset = 0.0
	return sample


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)
