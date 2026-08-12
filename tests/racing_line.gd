extends SceneTree

var _failures := 0


func _init() -> void:
	var route: Array[Vector3] = []
	for index in 24:
		var angle := TAU * float(index) / 24.0
		route.append(Vector3(cos(angle) * 35.0, 0.25, sin(angle) * 35.0))
	var first := RacingLineBuilder.build(route, [], "test-track")
	var second := RacingLineBuilder.build(route, [], "test-track")
	_check(first.is_valid(), "A closed finite route produces a racing line.")
	_check(first.samples.size() == second.samples.size(), "Generation is deterministic.")
	_check(is_equal_approx(first.total_length, second.total_length), "Deterministic lines have equal length.")
	var ordered := true
	var finite_and_safe := true
	for index in first.samples.size():
		var sample := first.samples[index]
		if index > 0:
			ordered = ordered and sample.distance > first.samples[index - 1].distance
		finite_and_safe = (
			finite_and_safe
			and is_finite(sample.position.x)
			and is_equal_approx(sample.forward.length(), 1.0)
			and absf(sample.lateral_offset) <= sample.available_width
		)
		_check(sample.position.is_equal_approx(second.samples[index].position), "Matching input produces matching samples.")
	_check(ordered, "Sample distances are strictly increasing.")
	_check(finite_and_safe, "Samples are finite, normalized, and inside the safe width.")
	var narrow_line := RacingLineBuilder.build(route, [], "narrow", 6.0)
	var narrow_safe := narrow_line.is_valid()
	for sample in narrow_line.samples:
		narrow_safe = (
			narrow_safe
			and is_equal_approx(sample.available_width, 1.1)
			and absf(sample.lateral_offset) <= sample.available_width
		)
	_check(narrow_safe, "The 1.9 m edge margin constrains every generated offset.")
	var projection := first.project(route[4])
	_check(projection.sample_index >= 0, "Positions project onto the line.")
	var invalid := RacingLineBuilder.build([Vector3.ZERO, Vector3.ONE], [], "invalid")
	_check(not invalid.is_valid(), "Routes that are too short are rejected.")
	if _failures == 0:
		print("Racing line tests passed.")
		quit(0)
	else:
		push_error("%d racing line tests failed." % _failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
