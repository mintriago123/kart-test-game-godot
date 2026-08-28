extends SceneTree

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var diff := DifficultyDefinition.new()
	diff.id = &"test"
	diff.precision_multiplier = 1.5
	diff.aggression_multiplier = 1.5
	diff.reaction_time_multiplier = 0.5
	diff.risk_multiplier = 1.2
	diff.item_efficiency_multiplier = 1.3
	diff.drift_usage_multiplier = 1.4
	diff.top_speed_bias = 0.05
	diff.response_multiplier = 1.4
	diff.lookahead_max_multiplier = 1.5
	diff.wall_recovery_speed_ratio = 0.5
	diff.avoidance_weight_max = 0.95
	diff.launch_aggression_bias = -0.1

	var base := AiProfile.create(0.8, 0.5, 0.6, 0.5, 0.5, 0.7, 0.2, 0.0)
	var applied := diff.apply_to(base)

	_check(applied.personality.precision == 1.0,
		"precision clamped at 1.0 (0.8 * 1.5 = 1.2 → 1.0)")
	_check(absf(applied.personality.aggression - 0.75) < 0.0001,
		"aggression scaled (0.5 * 1.5 = 0.75)")
	_check(absf(applied.personality.drift_usage - 0.84) < 0.0001,
		"drift_usage scaled (0.6 * 1.4 = 0.84)")
	_check(absf(applied.personality.risk_tolerance - 0.6) < 0.0001,
		"risk_tolerance scaled (0.5 * 1.2 = 0.6)")
	_check(absf(applied.personality.shortcut_probability - 0.6) < 0.0001,
		"shortcut_probability scaled (0.5 * 1.2 = 0.6)")
	_check(absf(applied.personality.item_efficiency - 0.91) < 0.0001,
		"item_efficiency scaled (0.7 * 1.3 = 0.91)")
	_check(absf(applied.personality.reaction_time - 0.1) < 0.0001,
		"reaction_time scaled (0.2 * 0.5 = 0.1)")

	_check(absf(applied.buff.top_speed_bias - 0.05) < 0.0001,
		"buff.top_speed_bias applied (base 0 + 0.05)")
	_check(absf(applied.buff.response_multiplier - 1.4) < 0.0001,
		"buff.response_multiplier passed through")
	_check(absf(applied.buff.lookahead_max_multiplier - 1.5) < 0.0001,
		"buff.lookahead_max_multiplier passed through")
	_check(absf(applied.buff.wall_recovery_speed_ratio - 0.5) < 0.0001,
		"buff.wall_recovery_speed_ratio passed through")
	_check(absf(applied.buff.avoidance_weight_max - 0.95) < 0.0001,
		"buff.avoidance_weight_max passed through")
	_check(absf(applied.buff.launch_aggression_bias - (-0.1)) < 0.0001,
		"buff.launch_aggression_bias passed through")

	var empty_diff := DifficultyDefinition.new()
	empty_diff.id = &"empty"
	var applied_empty := empty_diff.apply_to(null)
	_check(applied_empty.personality.reaction_time >= 0.05,
		"reaction_time floor at 0.05 on empty diff")
	_check(absf(applied_empty.buff.top_speed_bias - 0.0) < 0.0001,
		"buff.top_speed_bias defaults to 0")

	if _failures == 0:
		print("DifficultyBuff apply_to tests passed.")
		quit(0)
	else:
		push_error("%d DifficultyBuff tests failed." % _failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)
