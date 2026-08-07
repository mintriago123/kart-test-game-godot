@tool
class_name TrackEditorHistory
extends RefCounted

const HISTORY_LIMIT := 40

var _session_ref: WeakRef
var _session: RefCounted:
	get:
		return _session_ref.get_ref()

var _undo_states: Array[Dictionary] = []
var _redo_states: Array[Dictionary] = []


func _init(session: RefCounted) -> void:
	_session_ref = weakref(session)


func reset() -> void:
	_undo_states.clear()
	_redo_states.clear()


func snapshot_track() -> void:
	if _session.track == null or _session.track.get_main_route() == null:
		return
	_undo_states.append(_capture_track_state())
	if _undo_states.size() > HISTORY_LIMIT:
		_undo_states.pop_front()
	_redo_states.clear()
	_session.history_changed.emit(can_undo(), can_redo())


func undo() -> void:
	if not can_undo():
		return
	_redo_states.append(_capture_track_state())
	_restore_track_state(_undo_states.pop_back())
	_session.route_changed.emit()
	_session.history_changed.emit(can_undo(), can_redo())


func redo() -> void:
	if not can_redo():
		return
	_undo_states.append(_capture_track_state())
	_restore_track_state(_redo_states.pop_back())
	_session.route_changed.emit()
	_session.history_changed.emit(can_undo(), can_redo())


func can_undo() -> bool:
	return not _undo_states.is_empty()


func can_redo() -> bool:
	return not _redo_states.is_empty()


func _capture_track_state() -> Dictionary:
	var state := {
		"is_dirty": _session.is_dirty,
		"route_curve": null,
		"start_point_index": 0,
		"shortcuts": [],
		"items": [],
		"props": [],
	}
	if _session.track == null:
		return state
	var route: Path3D = _session.track.get_main_route()
	if route != null and route.curve != null:
		state.route_curve = route.curve.duplicate(true) as Curve3D
	state.start_point_index = _session.track.start_point_index
	for shortcut in _session.track.get_shortcuts():
		(state.shortcuts as Array).append({
			"node": shortcut,
			"curve": (
				shortcut.curve.duplicate(true) as Curve3D
				if shortcut.curve != null
				else null
			),
			"route_anchor_enabled": shortcut.route_anchor_enabled,
			"entry_progress": shortcut.entry_progress,
			"exit_progress": shortcut.exit_progress,
			"midpoint_lateral_offset": shortcut.midpoint_lateral_offset,
			"midpoint_longitudinal_offset": shortcut.midpoint_longitudinal_offset,
			"midpoint_height_offset": shortcut.midpoint_height_offset,
			"entry_handle_length": shortcut.entry_handle_length,
			"exit_handle_length": shortcut.exit_handle_length,
			"midpoint_in_handle_length": shortcut.midpoint_in_handle_length,
			"midpoint_out_handle_length": shortcut.midpoint_out_handle_length,
		})
	var item_spawns: Node = _session.track.get_node_or_null("ItemSpawns")
	if item_spawns != null:
		for child in item_spawns.get_children():
			if child is Node3D:
				(state.items as Array).append(
					_capture_anchored_node(child as Node3D)
				)
	var props: Node = _session.track.get_node_or_null("Props")
	if props != null:
		for child in props.get_children():
			if child is Node3D:
				(state.props as Array).append(
					_capture_anchored_node(child as Node3D)
				)
	return state


func _restore_track_state(state: Dictionary) -> void:
	if _session.track == null:
		return
	var route: Path3D = _session.track.get_main_route()
	var route_curve := state.get("route_curve") as Curve3D
	if route != null and route_curve != null:
		route.curve = route_curve.duplicate(true) as Curve3D
	_session.track.start_point_index = int(
		state.get("start_point_index", 0)
	)
	for shortcut_state in state.get("shortcuts", []):
		var shortcut := shortcut_state.get("node") as TrackShortcut
		if not is_instance_valid(shortcut):
			continue
		var shortcut_curve := shortcut_state.get("curve") as Curve3D
		shortcut.curve = (
			shortcut_curve.duplicate(true) as Curve3D
			if shortcut_curve != null
			else null
		)
		shortcut.route_anchor_enabled = bool(shortcut_state.route_anchor_enabled)
		shortcut.entry_progress = float(shortcut_state.entry_progress)
		shortcut.exit_progress = float(shortcut_state.exit_progress)
		shortcut.midpoint_lateral_offset = float(
			shortcut_state.midpoint_lateral_offset
		)
		shortcut.midpoint_longitudinal_offset = float(
			shortcut_state.midpoint_longitudinal_offset
		)
		shortcut.midpoint_height_offset = float(
			shortcut_state.midpoint_height_offset
		)
		shortcut.entry_handle_length = float(shortcut_state.entry_handle_length)
		shortcut.exit_handle_length = float(shortcut_state.exit_handle_length)
		shortcut.midpoint_in_handle_length = float(
			shortcut_state.midpoint_in_handle_length
		)
		shortcut.midpoint_out_handle_length = float(
			shortcut_state.midpoint_out_handle_length
		)
	for node_state in state.get("items", []):
		_restore_anchored_node(node_state)
	for node_state in state.get("props", []):
		_restore_anchored_node(node_state)
	_session._set_dirty(bool(state.get("is_dirty", true)))


func _capture_anchored_node(node: Node3D) -> Dictionary:
	return {
		"node": node,
		"transform": node.transform,
		"has_anchor": node.has_meta(_session.META_ANCHOR_PROGRESS),
		"progress": node.get_meta(_session.META_ANCHOR_PROGRESS, 0.0),
		"lateral": node.get_meta(_session.META_ANCHOR_LATERAL, 0.0),
		"height": node.get_meta(_session.META_ANCHOR_HEIGHT, 0.0),
		"rotation": node.get_meta(_session.META_ANCHOR_ROTATION, 0.0),
	}


func _restore_anchored_node(state: Dictionary) -> void:
	var node := state.get("node") as Node3D
	if not is_instance_valid(node):
		return
	node.transform = state.transform
	if bool(state.has_anchor):
		_session._set_route_anchor_metadata(
			node,
			float(state.progress),
			float(state.lateral),
			float(state.height),
			float(state.rotation)
		)
	else:
		for metadata_key in [
			_session.META_ANCHOR_PROGRESS,
			_session.META_ANCHOR_LATERAL,
			_session.META_ANCHOR_HEIGHT,
			_session.META_ANCHOR_ROTATION,
		]:
			if node.has_meta(metadata_key):
				node.remove_meta(metadata_key)
