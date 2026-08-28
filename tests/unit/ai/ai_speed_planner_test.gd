extends SceneTree

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tuning := AiTuning.defaults()
	var kart := _make_kart()
	var planner := AiSpeedPlanner.new()
	planner.tuning = tuning
	planner.kart = kart

	_check(planner.compute_lookahead(0.0, 0.0, 1.0) >= tuning.lookahead_min,
		"lookahead at zero speed respects floor")
	_check(planner.compute_lookahead(50.0, 0.0, 1.0) <= tuning.lookahead_max,
		"lookahead at high speed respects ceiling")
	_check(planner.compute_lookahead(70.0, 0.0, 1.5) > planner.compute_lookahead(70.0, 0.0, 1.0),
		"lookahead scales with multiplier")

	_check(planner.wanted_throttle(20.0, 25.0) > 0.0,
		"positive speed_error produces positive throttle")
	_check(planner.wanted_throttle(-20.0, 25.0) == 0.0,
		"negative speed_error clamps throttle to 0")
	_check(planner.wanted_brake(-20.0, 25.0) > 0.0,
		"negative speed_error produces brake")
	_check(planner.wanted_brake(20.0, 25.0) == 0.0,
		"positive speed_error clamps brake to 0")

	_check(planner.clamp_throttle_when_braking(1.0, 0.5) < 1.0,
		"throttle is clamped when brake is high")
	_check(planner.clamp_throttle_when_braking(1.0, 0.0) == 1.0,
		"throttle is unchanged when brake is zero")

	var response_mult := 1.4
	_check(planner.update_throttle(0.0, 1.0, response_mult, 1.0) > 0.5,
		"throttle smooths toward target over time")
	_check(planner.update_brake(0.0, 1.0, response_mult, 1.0) > 0.5,
		"brake smooths toward target over time")

	_check(planner.compute_target_speed(20.0, 1.0, 0.06, false, 25.0, 0.3) > 20.0,
		"target_speed with full aggression + top_speed_bias exceeds safe_speed")
	_check(planner.compute_target_speed(20.0, 0.0, 0.0, true, 25.0, 0.5) <= 12.5,
		"wall recovery caps target at recovery_ratio * max_speed")

	if _failures == 0:
		print("AiSpeedPlanner tests passed.")
		quit(0)
	else:
		push_error("%d AiSpeedPlanner tests failed." % _failures)
		quit(1)


func _make_kart() -> Kart:
	var kart := Kart.new()
	var stats := KartStats.new()
	stats.max_speed = 25.0
	stats.reverse_speed = 8.0
	stats.acceleration = 18.0
	stats.braking = 28.0
	stats.steering_speed = 2.2
	stats.grip = 9.0
	stats.drift_grip = 2.8
	kart.stats = stats
	return kart


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)
