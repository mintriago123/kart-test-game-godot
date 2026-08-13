class_name GhostRecorder
extends Node

const SAMPLE_INTERVAL := 0.1

var recording: GhostRecording
var _manager: RaceManager
var _kart: Kart
var _active := false
var _next_sample_time := 0.0
var _pending_discontinuity := false
var _last_drive_state := -1


func setup(manager: RaceManager, kart: Kart, track_id: StringName, fingerprint: String, cc_id: StringName, laps: int) -> void:
	_manager = manager
	_kart = kart
	recording = GhostRecording.new()
	recording.track_id = track_id
	recording.track_fingerprint = fingerprint
	recording.cc_id = cc_id
	recording.total_laps = laps
	manager.race_started.connect(start)
	manager.lap_completed.connect(_on_lap_completed)
	kart.recovered.connect(_on_recovered)


func start() -> void:
	if _active or recording == null:
		return
	_active = true
	_next_sample_time = 0.0
	_capture(true)


func finish(result: RaceResult) -> GhostRecording:
	if not _active or result == null or result.player_result == null:
		return null
	_capture(true)
	_active = false
	recording.total_time = result.player_result.finish_time
	recording.lap_times.assign(result.player_result.lap_times)
	if not recording.samples.is_empty():
		recording.samples[-1].time = recording.total_time
	return recording


func cancel() -> void:
	_active = false
	recording = null


func _process(_delta: float) -> void:
	if not _active or _manager == null or _manager.state != RaceManager.RaceState.RACING:
		return
	var state := _get_drive_state()
	if state != _last_drive_state:
		_capture(true)
	while _manager.race_time + 0.0001 >= _next_sample_time:
		_capture(false)
		_next_sample_time += SAMPLE_INTERVAL


func _capture(force: bool) -> void:
	if not _active or _kart == null or _manager == null:
		return
	var now := _manager.race_time
	if not force and not recording.samples.is_empty() and absf(recording.samples[-1].time - now) < 0.0001:
		return
	var sample := GhostSample.new()
	sample.time = now
	sample.position = _kart.global_position
	sample.rotation = _kart.global_basis.get_rotation_quaternion().normalized()
	sample.drive_state = _get_drive_state()
	sample.discontinuity = _pending_discontinuity
	sample.progress = _manager.get_racer_progress(_kart)
	# Recovery can move the kart backwards inside the current segment.  Ghost
	# progress is a timeline coordinate, so keep it monotonic for delta lookup.
	if not recording.samples.is_empty():
		sample.progress = maxf(sample.progress, recording.samples[-1].progress)
	_pending_discontinuity = false
	_last_drive_state = sample.drive_state
	recording.samples.append(sample)


func _get_drive_state() -> int:
	var drifting := _kart != null and _kart.is_drifting_for_ghost()
	var boosting := _kart != null and _kart.is_boosting_for_ghost()
	if drifting and boosting:
		return GhostSample.DriveState.DRIFT_BOOSTING
	if drifting:
		return GhostSample.DriveState.DRIFTING
	return GhostSample.DriveState.BOOSTING if boosting else GhostSample.DriveState.NORMAL


func _on_lap_completed(racer: Node, _lap: int, _time: float) -> void:
	if racer == _kart:
		_capture(true)


func _on_recovered() -> void:
	_pending_discontinuity = true
	_capture(true)
