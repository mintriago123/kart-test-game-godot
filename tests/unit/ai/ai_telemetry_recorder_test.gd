extends SceneTree

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AiTelemetryRecorder.clear_recordings()

	var recorder := AiTelemetryRecorder.new()
	recorder.open_for_race(12345, &"coral.test:ai", 5)
	_check(recorder.get_recorded_path().begins_with("user://ai_telemetry_12345_"),
		"recorded path starts with user://ai_telemetry_12345_")

	recorder.record(
		1, 0.0, &"coral", 10.0, 38.5, 28.5,
		0.625, 0.0, 0.15, 0, false,
		0.45, 0.65, 0.62, 3, 0.0,
		99, 42, 123.456, -1.25, 24.5, 0.031, "stalled", 2, 1.0, 2.0, 3.0
	)
	recorder.record(
		2, 0.1, &"coral", 11.2, 38.5, 27.3,
		0.61, 0.0, -0.85, 0, false,
		0.31, 0.20, 0.85, 3, 0.0
	)
	recorder.close()

	var path := recorder.get_recorded_path()
	var absolute_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "recorder wrote a readable file at %s" % path)
	if file != null:
		var header := file.get_line()
		_check(header.begins_with("frame,time,ai_id,speed,target_speed,speed_error"),
			"header starts with expected column names")
		_check(header.contains("throttle,brake,steer,recovery_state,drift_committed"),
			"header includes driver command columns")
		_check(header.contains("sens_front,sens_left,sens_right,section_id,wall_recovery_time"),
			"header includes sensor and section columns")
		_check(header.ends_with("engine_frame,projection_sample_index,projection_distance,lateral_error,safe_speed,target_curvature,recovery_reason,recovery_count,position_x,position_y,position_z"),
			"new diagnostic columns are appended to the CSV")

		var line1 := file.get_line()
		_check(line1.begins_with("1,0.000,coral,10.00,38.50,28.50"),
			"first data row has expected frame/time/ai/speed/target/error fields")
		_check(line1.ends_with("99,42,123.456,-1.250,24.500,0.031,stalled,2,1.000,2.000,3.000"),
			"first data row records projection, recovery, and position diagnostics")

		var line2 := file.get_line()
		_check(line2.begins_with("2,0.100,coral,11.20,38.50,27.30"),
			"second data row has expected fields")
		_check(line2.contains("0.610"), "second row contains throttle value 0.610")
		_check(line2.contains("-0.850"), "second row contains steer value -0.850")

		file.close()

	AiTelemetryRecorder.clear_recordings()
	var after := AiTelemetryRecorder.list_recordings()
	_check(after.is_empty(), "clear_recordings() removed all CSV files")

	if _failures == 0:
		print("AiTelemetryRecorder tests passed.")
		quit(0)
	else:
		push_error("%d AiTelemetryRecorder tests failed." % _failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)
