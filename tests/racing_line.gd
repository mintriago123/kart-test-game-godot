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
	var segment_line := RacingLine.new()
	segment_line.total_length = 30.0
	for sample_data in [
		[0.0, Vector3(0.0, 0.0, 0.0)],
		[10.0, Vector3(10.0, 0.0, 0.0)],
		[20.0, Vector3(10.0, 0.0, 10.0)],
	]:
		var sample := RacingLineSample.new()
		sample.distance = sample_data[0]
		sample.position = sample_data[1]
		sample.forward = Vector3.RIGHT if sample_data[0] < 10.0 else Vector3.BACK
		segment_line.samples.append(sample)
	var midpoint := segment_line.project(Vector3(4.0, 0.0, 1.0))
	_check(
		midpoint.sample_index == 0
		and is_equal_approx(midpoint.distance, 4.0)
		and is_equal_approx(midpoint.lateral_error, 1.0),
		"Projection uses the nearest segment and interpolates its distance."
	)
	var progressed := segment_line.project(Vector3(8.0, 0.0, 0.0), 0)
	var regressed := segment_line.project(Vector3(1.0, 0.0, 0.0), 0, progressed.distance)
	_check(
		regressed.progress_clamped and regressed.distance >= progressed.distance,
		"Projection progress stays monotonic while a lap is in progress."
	)
	var wrapped := segment_line.project(Vector3(0.5, 0.0, 0.0), 0, progressed.distance, true)
	_check(wrapped.distance < progressed.distance, "Finish-line wrap can reset projection progress.")
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
