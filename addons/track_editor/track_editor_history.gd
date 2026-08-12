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


func discard_latest_snapshot() -> void:
	if _undo_states.is_empty():
		return
	_undo_states.pop_back()
	_session.history_changed.emit(can_undo(), can_redo())


func undo() -> void:
	if not can_undo():
		return
	_redo_states.append(_capture_track_state())
	var state := _undo_states.pop_back()
	_restore_track_state(state)
	_session.route_changed.emit()
	_session.history_changed.emit(can_undo(), can_redo())


func redo() -> void:
	if not can_redo():
		return
	_undo_states.append(_capture_track_state())
	var state := _redo_states.pop_back()
	_restore_track_state(state)
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
		"collections": {},
	}
	if _session.track == null:
		return state
	var route: Path3D = _session.track.get_main_route()
	if route != null and route.curve != null:
		state.route_curve = route.curve.duplicate(true) as Curve3D
	state.start_point_index = _session.track.start_point_index
	for container_name in [&"Shortcuts", &"ItemSpawns", &"Props"]:
		state.collections[container_name] = _capture_collection(container_name)
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
	var collections: Dictionary = state.get("collections", {})
	for container_name in [&"Shortcuts", &"ItemSpawns", &"Props"]:
		_restore_collection(
			container_name,
			collections.get(container_name, []) as Array
		)
	_session._set_dirty(bool(state.get("is_dirty", true)))


func _capture_collection(container_name: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var container: Node = _session.track.get_node_or_null(NodePath(container_name))
	if container == null:
		return result
	for child in container.get_children():
		if child is Node3D:
			var packed := PackedScene.new()
			if packed.pack(child) != OK:
				continue
			result.append({
				"name": child.name,
				"snapshot": packed,
			})
	return result


func _restore_collection(
	container_name: StringName,
	states: Array
) -> void:
	var container: Node = _session.track.get_node_or_null(NodePath(container_name))
	if container == null:
		return
	var desired_names: Dictionary = {}
	for state in states:
		desired_names[StringName(state.name)] = true
	for child in container.get_children():
		if not desired_names.has(child.name):
			container.remove_child(child)
			child.free()
	for state in states:
		var packed := state.get("snapshot") as PackedScene
		if packed == null:
			continue
		var snapshot := packed.instantiate() as Node3D
		if snapshot == null:
			continue
		var existing := container.get_node_or_null(NodePath(state.name)) as Node3D
		if existing != null and existing.get_script() == snapshot.get_script():
			_restore_node_from_snapshot(existing, snapshot)
			snapshot.free()
			continue
		container.add_child(snapshot)
		snapshot.owner = _session.track


func _restore_node_from_snapshot(node: Node3D, snapshot: Node3D) -> void:
	node.transform = snapshot.transform
	if node is TrackShortcut and snapshot is TrackShortcut:
		var shortcut := node as TrackShortcut
		var saved_shortcut := snapshot as TrackShortcut
		shortcut.shortcut_id = saved_shortcut.shortcut_id
		shortcut.display_name = saved_shortcut.display_name
		shortcut.route_anchor_enabled = saved_shortcut.route_anchor_enabled
		shortcut.entry_progress = saved_shortcut.entry_progress
		shortcut.exit_progress = saved_shortcut.exit_progress
		shortcut.midpoint_lateral_offset = saved_shortcut.midpoint_lateral_offset
		shortcut.midpoint_longitudinal_offset = saved_shortcut.midpoint_longitudinal_offset
		shortcut.midpoint_height_offset = saved_shortcut.midpoint_height_offset
		shortcut.entry_handle_length = saved_shortcut.entry_handle_length
		shortcut.exit_handle_length = saved_shortcut.exit_handle_length
		shortcut.midpoint_in_handle_length = saved_shortcut.midpoint_in_handle_length
		shortcut.midpoint_out_handle_length = saved_shortcut.midpoint_out_handle_length
		shortcut.curve = (
			saved_shortcut.curve.duplicate(true) as Curve3D
			if saved_shortcut.curve != null
			else null
		)
	_restore_anchor_metadata(node, snapshot)


func _restore_anchor_metadata(node: Node3D, snapshot: Node3D) -> void:
	if snapshot.has_meta(_session.META_ANCHOR_PROGRESS):
		_session._set_route_anchor_metadata(
			node,
			float(snapshot.get_meta(_session.META_ANCHOR_PROGRESS)),
			float(snapshot.get_meta(_session.META_ANCHOR_LATERAL, 0.0)),
			float(snapshot.get_meta(_session.META_ANCHOR_HEIGHT, 0.0)),
			float(snapshot.get_meta(_session.META_ANCHOR_ROTATION, 0.0))
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
	_restore_prop_scale_metadata(node, snapshot)


func _restore_prop_scale_metadata(node: Node3D, snapshot: Node3D) -> void:
	for metadata_key in [
		_session.META_PROP_BASE_SCALE,
		_session.META_PROP_SCALE_MULTIPLIER,
		_session.META_ASSET_ID,
	]:
		if snapshot.has_meta(metadata_key):
			node.set_meta(metadata_key, snapshot.get_meta(metadata_key))
		elif node.has_meta(metadata_key):
			node.remove_meta(metadata_key)
