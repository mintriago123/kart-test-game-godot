class_name AiTelemetryRecorder
extends RefCounted

var _file: FileAccess
var _buffer: PackedStringArray
var _frame_count := 0
var _flush_interval := 30
var _path := ""


func open_for_race(race_seed: int, ai_id: StringName, flush_interval: int = 30) -> void:
	_flush_interval = flush_interval
	var safe_id := str(ai_id).replace(".", "_").replace(":", "_").replace("/", "_")
	_path = "user://ai_telemetry_%d_%s.csv" % [race_seed, safe_id]
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		push_warning("AiTelemetryRecorder could not open %s" % _path)
		return
	_file.store_line("frame,time,ai_id,speed,target_speed,speed_error,"
		+ "throttle,brake,steer,recovery_state,drift_committed,"
		+ "sens_front,sens_left,sens_right,section_id,wall_recovery_time")


func get_recorded_path() -> String:
	return _path


func record(
	frame: int,
	time: float,
	ai_id: StringName,
	speed: float,
	target_speed: float,
	speed_error: float,
	throttle: float,
	brake: float,
	steer: float,
	recovery_state: int,
	drift_committed: bool,
	sens_front: float,
	sens_left: float,
	sens_right: float,
	section_id: int,
	wall_recovery_time: float
) -> void:
	if _file == null:
		return
	var line := "%d,%.3f,%s,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f,%d,%s,%.2f,%.2f,%.2f,%d,%.2f" % [
		frame, time, str(ai_id), speed, target_speed, speed_error,
		throttle, brake, steer, recovery_state, str(drift_committed),
		sens_front, sens_left, sens_right, section_id, wall_recovery_time
	]
	_buffer.append(line)
	_frame_count += 1
	if _frame_count >= _flush_interval:
		flush()


func flush() -> void:
	if _file == null:
		return
	for line in _buffer:
		_file.store_line(line)
	_buffer.clear()
	_frame_count = 0


func close() -> void:
	flush()
	if _file != null:
		_file.close()
		_file = null


static func list_recordings() -> PackedStringArray:
	var dir := DirAccess.open("user://")
	if dir == null:
		return PackedStringArray()
	var result := PackedStringArray()
	for file in dir.get_files():
		if file.begins_with("ai_telemetry_") and file.ends_with(".csv"):
			result.append(file)
	return result


static func clear_recordings() -> int:
	var dir := DirAccess.open("user://")
	if dir == null:
		return 0
	var count := 0
	for file in dir.get_files():
		if file.begins_with("ai_telemetry_") and file.ends_with(".csv"):
			dir.remove(file)
			count += 1
	return count
