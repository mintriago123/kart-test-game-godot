extends SceneTree

var _failures := 0


func _initialize() -> void:
	var controller := AiSteeringController.new()
	controller.tuning = AiTuning.defaults()
	var clear_sensors := {"front": 1.0, "left": 1.0, "right": 1.0}
	var blocked_sensors := {"front": 0.2, "left": 1.0, "right": 1.0}

	_check(
		is_zero_approx(controller.stabilize_straight_target(-0.4, 0.4, 0.0, clear_sensors)),
		"straight steering crosses zero before changing sign"
	)
	_check(
		is_zero_approx(controller.stabilize_straight_output(0.4, -0.08, 0.0, clear_sensors)),
		"smoothed straight steering crosses zero before changing sign"
	)
	_check(
		is_equal_approx(controller.stabilize_straight_target(-0.4, 0.4, 0.02, clear_sensors), -0.4),
		"curved steering keeps its emergency-free response"
	)
	_check(
		is_equal_approx(controller.stabilize_straight_target(-0.4, 0.4, 0.0, blocked_sensors), -0.4),
		"threatened steering keeps its immediate response"
	)
	if _failures == 0:
		print("AiSteeringController tests passed.")
		quit(0)
	else:
		push_error("%d AiSteeringController tests failed." % _failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)
