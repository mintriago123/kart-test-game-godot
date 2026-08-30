@tool
class_name TrackEditorPublicationController
extends RefCounted

signal state_changed(state: StringName)

var state: StringName = &"sin_pista"

var _session_ref: WeakRef
var _session: RefCounted:
	get:
		return _session_ref.get_ref()


func _init(session: RefCounted) -> void:
	_session_ref = weakref(session)
	_refresh_state()


func get_state() -> StringName:
	_refresh_state()
	return state


func publish(laps: int, description: String) -> Error:
	var error: Error = _session.publish(laps, description)
	_refresh_state()
	return error


func refresh() -> void:
	_refresh_state()


func _refresh_state() -> void:
	var next_state: StringName = &"sin_pista"
	if _session != null and _session.track != null:
		if _session.is_published:
			next_state = (
				&"publicada_con_cambios"
				if _session.is_dirty
				else &"publicada"
			)
		else:
			next_state = &"borrador"
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)
