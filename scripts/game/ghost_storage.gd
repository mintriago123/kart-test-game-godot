class_name GhostStorage
extends RefCounted

const MAGIC := 0x4D4B4748
const MAX_DURATION := 60.0 * 60.0
const MAX_SAMPLES := 40000
const TIME_TOLERANCE := 0.25

var root_path := "user://ghosts"


func has_compatible(track_id: StringName, fingerprint: String, cc_id: StringName, laps: int) -> bool:
	return load_compatible(track_id, fingerprint, cc_id, laps) != null


func load_compatible(track_id: StringName, fingerprint: String, cc_id: StringName, laps: int) -> GhostRecording:
	if fingerprint.is_empty():
		return null
	var recording := _read_file(_path_for(track_id, cc_id))
	if not _validate(recording):
		return null
	if recording.track_id != track_id or recording.cc_id != cc_id:
		return null
	if recording.total_laps != laps or recording.track_fingerprint != fingerprint:
		return null
	return recording


func save_atomic(recording: GhostRecording) -> Error:
	if not _validate(recording) or recording.track_fingerprint.is_empty():
		return ERR_INVALID_DATA
	var error := DirAccess.make_dir_recursive_absolute(root_path)
	if error != OK:
		return error
	var final_path := _path_for(recording.track_id, recording.cc_id)
	var temporary_path := final_path + ".tmp"
	error = _write_file(temporary_path, recording)
	if error != OK:
		return error
	var check := _read_file(temporary_path)
	if not _validate(check) or check.track_fingerprint != recording.track_fingerprint:
		DirAccess.remove_absolute(temporary_path)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(final_path):
		var backup_path := final_path + ".bak"
		DirAccess.remove_absolute(backup_path)
		error = DirAccess.rename_absolute(final_path, backup_path)
		if error != OK:
			DirAccess.remove_absolute(temporary_path)
			return error
		error = DirAccess.rename_absolute(temporary_path, final_path)
		if error != OK:
			DirAccess.rename_absolute(backup_path, final_path)
			return error
		DirAccess.remove_absolute(backup_path)
		return OK
	return DirAccess.rename_absolute(temporary_path, final_path)


func _write_file(path: String, recording: GhostRecording) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_32(MAGIC)
	file.store_16(recording.format_version)
	file.store_pascal_string(str(recording.track_id))
	file.store_pascal_string(recording.track_fingerprint)
	file.store_pascal_string(str(recording.cc_id))
	file.store_16(recording.total_laps)
	file.store_double(recording.total_time)
	file.store_double(recording.sample_interval)
	file.store_16(recording.lap_times.size())
	for lap_time in recording.lap_times:
		file.store_double(lap_time)
	file.store_32(recording.samples.size())
	for sample in recording.samples:
		file.store_double(sample.time)
		file.store_float(sample.position.x)
		file.store_float(sample.position.y)
		file.store_float(sample.position.z)
		file.store_float(sample.rotation.x)
		file.store_float(sample.rotation.y)
		file.store_float(sample.rotation.z)
		file.store_float(sample.rotation.w)
		file.store_8(sample.drive_state)
		file.store_8(1 if sample.discontinuity else 0)
		file.store_double(sample.progress)
	return file.get_error()


func _read_file(path: String) -> GhostRecording:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 16 or file.get_32() != MAGIC:
		return null
	var recording := GhostRecording.new()
	recording.format_version = file.get_16()
	recording.track_id = StringName(file.get_pascal_string())
	recording.track_fingerprint = file.get_pascal_string()
	recording.cc_id = StringName(file.get_pascal_string())
	recording.total_laps = file.get_16()
	recording.total_time = file.get_double()
	recording.sample_interval = file.get_double()
	var lap_count := file.get_16()
	if lap_count > 64:
		return null
	for index in lap_count:
		recording.lap_times.append(file.get_double())
	var sample_count := file.get_32()
	if sample_count == 0 or sample_count > MAX_SAMPLES:
		return null
	for index in sample_count:
		if file.get_position() + 46 > file.get_length():
			return null
		var sample := GhostSample.new()
		sample.time = file.get_double()
		sample.position = Vector3(file.get_float(), file.get_float(), file.get_float())
		sample.rotation = Quaternion(file.get_float(), file.get_float(), file.get_float(), file.get_float())
		sample.drive_state = file.get_8()
		sample.discontinuity = file.get_8() != 0
		sample.progress = file.get_double()
		recording.samples.append(sample)
	return recording if file.get_error() in [OK, ERR_FILE_EOF] else null


func _validate(recording: GhostRecording) -> bool:
	if recording == null or recording.format_version != GhostRecording.FORMAT_VERSION:
		return false
	if recording.track_id.is_empty() or recording.cc_id.is_empty() or recording.total_laps <= 0:
		return false
	if not is_finite(recording.total_time) or recording.total_time <= 0.0 or recording.total_time > MAX_DURATION:
		return false
	if not is_finite(recording.sample_interval) or recording.sample_interval <= 0.0:
		return false
	if recording.samples.is_empty() or recording.samples.size() > MAX_SAMPLES:
		return false
	var previous_time := -1.0
	for sample in recording.samples:
		if sample == null or not is_finite(sample.time) or sample.time < previous_time:
			return false
		if not sample.position.is_finite() or not sample.rotation.is_finite() or not is_finite(sample.progress):
			return false
		var length := sample.rotation.length()
		if length < 0.99 or length > 1.01 or sample.drive_state < 0 or sample.drive_state > GhostSample.DriveState.DRIFT_BOOSTING:
			return false
		previous_time = sample.time
	return recording.samples[0].time <= TIME_TOLERANCE and absf(previous_time - recording.total_time) <= TIME_TOLERANCE


func _path_for(track_id: StringName, cc_id: StringName) -> String:
	return "%s/%s_%s.ghost" % [root_path, _safe_name(str(track_id)), _safe_name(str(cc_id))]


static func _safe_name(value: String) -> String:
	var safe := ""
	for character in value.to_lower():
		safe += character if character in "abcdefghijklmnopqrstuvwxyz0123456789-_" else "_"
	return safe if not safe.is_empty() else "track"
