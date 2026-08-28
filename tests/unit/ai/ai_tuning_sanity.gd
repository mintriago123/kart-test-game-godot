extends SceneTree

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tuning := AiTuning.defaults()
	_check(tuning.steer_response_max >= tuning.steer_response_min,
		"steer_response_max >= steer_response_min")
	_check(tuning.lookahead_max > tuning.lookahead_min,
		"lookahead_max > lookahead_min")
	_check(tuning.throttle_smooth_rate > 0.0,
		"throttle_smooth_rate is positive")
	_check(tuning.brake_smooth_rate > 0.0,
		"brake_smooth_rate is positive")
	_check(tuning.safe_speed_min_ratio > 0.0 and tuning.safe_speed_min_ratio < 1.0,
		"safe_speed_min_ratio in (0, 1)")
	_check(tuning.sensor_max_range > tuning.sensor_min_range,
		"sensor_max_range > sensor_min_range")
	_check(tuning.strategy_tick_hz > 0.0,
		"strategy_tick_hz is positive")
	_check(tuning.racer_avoidance_weight_ceiling > tuning.racer_avoidance_weight_floor,
		"avoidance weight ceiling > floor")
	if _failures == 0:
		print("AiTuning sanity tests passed.")
		quit(0)
	else:
		push_error("%d AiTuning tests failed." % _failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)
