@tool
class_name TrackEditorEditController
extends RefCounted

const Selection := preload("res://addons/track_editor/track_editor_selection.gd")

var _session_ref: WeakRef
var _session: RefCounted:
	get:
		return _session_ref.get_ref()


func _init(session: RefCounted) -> void:
	_session_ref = weakref(session)


func create_surface(data: Dictionary) -> Dictionary:
	_session.snapshot_track_for_undo()
	var zone: TrackSurfaceZone = _session.create_surface_zone(data)
	if zone == null:
		_session.discard_latest_snapshot()
		return {"ok": false}
	_session.mark_dirty()
	return {
		"ok": true,
		"selection": Selection.node(
			Selection.Kind.SURFACE,
			_session.track.get_path_to(zone)
		),
	}


func update_surface(selection: RefCounted, data: Dictionary) -> Dictionary:
	_session.snapshot_track_for_undo()
	if not _session.update_surface_zone(selection, data):
		_session.discard_latest_snapshot()
		return {"ok": false, "changed": false}
	_session.mark_dirty()
	return {"ok": true, "changed": true}


func delete_surface(selection: RefCounted) -> Dictionary:
	_session.snapshot_track_for_undo()
	if not _session.delete_surface_zone(selection):
		_session.discard_latest_snapshot()
		return {"ok": false}
	_session.mark_dirty()
	return {"ok": true}


func delete_entity(selection: RefCounted) -> Dictionary:
	_session.snapshot_track_for_undo()
	if not _session.delete_entity(selection):
		_session.discard_latest_snapshot()
		return {"ok": false}
	_session.mark_dirty()
	_session.recalculate_route_dependents()
	return {"ok": true}


func duplicate_entity(selection: RefCounted) -> Dictionary:
	_session.snapshot_track_for_undo()
	var duplicated: RefCounted = _session.duplicate_entity(selection)
	if duplicated == null or duplicated.is_empty():
		_session.discard_latest_snapshot()
		return {"ok": false}
	_session.mark_dirty()
	return {"ok": true, "selection": duplicated}
