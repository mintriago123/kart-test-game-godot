@tool
class_name TrackEditorExternalController
extends RefCounted

signal changes_detected(changes: Dictionary)

const POLL_INTERVAL_SECONDS := 1.0

var _session_ref: WeakRef
var _session: RefCounted:
	get:
		return _session_ref.get_ref()
var _elapsed := 0.0


func _init(session: RefCounted) -> void:
	_session_ref = weakref(session)


func process(delta: float) -> bool:
	if _session == null or _session.track == null:
		return false
	_elapsed += maxf(delta, 0.0)
	if _elapsed < POLL_INTERVAL_SECONDS:
		return false
	_elapsed = fmod(_elapsed, POLL_INTERVAL_SECONDS)
	poll()
	return true


func poll() -> Dictionary:
	if _session == null or _session.track == null:
		return {}
	var changes: Dictionary = _session.get_external_changes()
	changes_detected.emit(changes)
	return changes


func reset() -> void:
	_elapsed = 0.0
