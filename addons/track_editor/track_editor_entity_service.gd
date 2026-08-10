@tool
class_name TrackEditorEntityService
extends RefCounted

const Selection := preload(
	"res://addons/track_editor/track_editor_selection.gd"
)

var _session_ref: WeakRef
var _session: RefCounted:
	get:
		return _session_ref.get_ref()


func _init(session: RefCounted) -> void:
	_session_ref = weakref(session)


func get_node(selection: RefCounted) -> Node3D:
	if _session == null or _session.track == null or selection == null:
		return null
	return _session.track.get_node_or_null(selection.node_path) as Node3D


func move_to_track_position(
	selection: RefCounted,
	track_position: Vector3
) -> bool:
	if selection == null or _session == null or _session.track == null:
		return false
	match selection.kind:
		Selection.Kind.ROUTE_POINT:
			return _move_route_point(selection.point_index, track_position)
		Selection.Kind.ITEM:
			return _move_item(selection, track_position)
		Selection.Kind.PROP:
			return _move_prop(selection, track_position)
		Selection.Kind.SHORTCUT_MIDPOINT:
			return _move_shortcut_midpoint(selection, track_position)
		_:
			return false


func update_route_point(index: int, position: Vector3) -> bool:
	return _move_route_point(index, position)


func update_item_progress(selection: RefCounted, progress: float) -> bool:
	var marker := get_node(selection) as Marker3D
	if marker == null:
		return false
	_session.anchor_item_spawn(marker, progress)
	return true


func update_prop_anchor(
	selection: RefCounted,
	progress: float,
	lateral: float,
	height: float,
	rotation_degrees_y: float
) -> bool:
	var prop := get_node(selection)
	if prop == null:
		return false
	_session.anchor_prop(
		prop,
		progress,
		lateral,
		height,
		rotation_degrees_y
	)
	return true


func update_shortcut_midpoint(
	selection: RefCounted,
	longitudinal: float,
	lateral: float,
	height: float
) -> bool:
	var shortcut := get_node(selection) as TrackShortcut
	if shortcut == null or not shortcut.route_anchor_enabled:
		return false
	shortcut.midpoint_longitudinal_offset = longitudinal
	shortcut.midpoint_lateral_offset = lateral
	shortcut.midpoint_height_offset = height
	_session.recalculate_route_dependents()
	return true


func fit_shortcut_midpoint(
	selection: RefCounted,
	longitudinal: float,
	lateral: float,
	height: float
) -> Dictionary:
	var shortcut := get_node(selection) as TrackShortcut
	if shortcut == null or not shortcut.route_anchor_enabled:
		return _fit_result(
			&"rejected",
			"No se pudo editar el atajo seleccionado.",
			shortcut
		)
	var original := _capture_shortcut_shape(shortcut)
	_apply_shortcut_shape(
		shortcut,
		longitudinal,
		lateral,
		height,
		original,
		1.0
	)
	var requested_safety := TrackLevelValidator.get_shortcut_safety(
		_session.track,
		shortcut
	)
	if bool(requested_safety.safe):
		return _fit_result(&"accepted", "Forma segura.", shortcut)

	var best_candidate: Dictionary = {}
	var best_score := INF
	var lateral_candidates := PackedFloat32Array([
		lateral,
		lateral * 0.85,
		lateral * 0.7,
		lateral * 1.15,
		lateral * 1.3,
		float(original.lateral),
	])
	var longitudinal_candidates := PackedFloat32Array([
		longitudinal,
		longitudinal - 2.0,
		longitudinal + 2.0,
		longitudinal - 4.0,
		longitudinal + 4.0,
		float(original.longitudinal),
	])
	for candidate_lateral in lateral_candidates:
		for candidate_longitudinal in longitudinal_candidates:
			for handle_multiplier in [1.0, 1.2, 1.4]:
				_apply_shortcut_shape(
					shortcut,
					candidate_longitudinal,
					candidate_lateral,
					height,
					original,
					handle_multiplier
				)
				var safety := TrackLevelValidator.get_shortcut_safety(
					_session.track,
					shortcut
				)
				if not bool(safety.safe):
					continue
				var score := (
					absf(candidate_longitudinal - longitudinal)
					+ absf(candidate_lateral - lateral)
					+ absf(handle_multiplier - 1.0) * 4.0
					+ maxf(
						0.0,
						absf(candidate_longitudinal - float(original.longitudinal))
						- 12.0
					) * 3.0
					+ maxf(
						0.0,
						absf(candidate_lateral - float(original.lateral))
						- 12.0
					) * 3.0
				)
				if score < best_score:
					best_score = score
					best_candidate = {
						"longitudinal": candidate_longitudinal,
						"lateral": candidate_lateral,
						"handle_multiplier": handle_multiplier,
					}
	if best_candidate.is_empty():
		_restore_shortcut_shape(shortcut, original)
		return _fit_result(
			&"rejected",
			String(requested_safety.message),
			shortcut
		)
	_apply_shortcut_shape(
		shortcut,
		float(best_candidate.longitudinal),
		float(best_candidate.lateral),
		height,
		original,
		float(best_candidate.handle_multiplier)
	)
	return _fit_result(
		&"adjusted",
		"Forma ajustada para mantener una salida segura.",
		shortcut
	)


func _capture_shortcut_shape(shortcut: TrackShortcut) -> Dictionary:
	return {
		"longitudinal": shortcut.midpoint_longitudinal_offset,
		"lateral": shortcut.midpoint_lateral_offset,
		"height": shortcut.midpoint_height_offset,
		"entry_handle": shortcut.entry_handle_length,
		"exit_handle": shortcut.exit_handle_length,
		"midpoint_in_handle": shortcut.midpoint_in_handle_length,
		"midpoint_out_handle": shortcut.midpoint_out_handle_length,
	}


func _restore_shortcut_shape(
	shortcut: TrackShortcut,
	shape: Dictionary
) -> void:
	shortcut.entry_handle_length = float(shape.entry_handle)
	shortcut.exit_handle_length = float(shape.exit_handle)
	shortcut.midpoint_in_handle_length = float(shape.midpoint_in_handle)
	shortcut.midpoint_out_handle_length = float(shape.midpoint_out_handle)
	shortcut.midpoint_longitudinal_offset = float(shape.longitudinal)
	shortcut.midpoint_lateral_offset = float(shape.lateral)
	shortcut.midpoint_height_offset = float(shape.height)
	_session.recalculate_route_dependents()


func _apply_shortcut_shape(
	shortcut: TrackShortcut,
	longitudinal: float,
	lateral: float,
	height: float,
	base_shape: Dictionary,
	handle_multiplier: float
) -> void:
	shortcut.midpoint_longitudinal_offset = longitudinal
	shortcut.midpoint_lateral_offset = lateral
	shortcut.midpoint_height_offset = height
	shortcut.entry_handle_length = (
		float(base_shape.entry_handle) * handle_multiplier
	)
	shortcut.exit_handle_length = (
		float(base_shape.exit_handle) * handle_multiplier
	)
	shortcut.midpoint_in_handle_length = (
		float(base_shape.midpoint_in_handle) * handle_multiplier
	)
	shortcut.midpoint_out_handle_length = (
		float(base_shape.midpoint_out_handle) * handle_multiplier
	)
	_session.recalculate_route_dependents()


func _fit_result(
	status: StringName,
	message: String,
	shortcut: TrackShortcut
) -> Dictionary:
	return {
		"status": status,
		"message": message,
		"longitudinal": (
			shortcut.midpoint_longitudinal_offset if shortcut != null else 0.0
		),
		"lateral": shortcut.midpoint_lateral_offset if shortcut != null else 0.0,
		"height": shortcut.midpoint_height_offset if shortcut != null else 0.0,
	}


func duplicate(selection: RefCounted) -> RefCounted:
	if selection == null or selection.kind not in [
		Selection.Kind.ITEM,
		Selection.Kind.PROP,
	]:
		return Selection.none()
	var source := get_node(selection)
	if source == null or source.get_parent() == null:
		return Selection.none()
	var copy := source.duplicate() as Node3D
	if copy == null:
		return Selection.none()
	copy.name = _unique_name(source.get_parent(), source.name)
	source.get_parent().add_child(copy)
	copy.owner = _session.track
	if selection.kind == Selection.Kind.PROP:
		var lateral := float(copy.get_meta(_session.META_ANCHOR_LATERAL, 0.0))
		copy.set_meta(_session.META_ANCHOR_LATERAL, lateral + 2.0)
		_session.recalculate_route_dependents()
	return Selection.node(
		selection.kind,
		_session.track.get_path_to(copy)
	)


func delete(selection: RefCounted) -> bool:
	if selection == null or _session == null or _session.track == null:
		return false
	if selection.kind == Selection.Kind.ROUTE_POINT:
		var route := _session.track.get_main_route() as Path3D
		if (
			route == null
			or route.curve == null
			or route.curve.point_count <= 4
			or selection.point_index < 0
			or selection.point_index >= route.curve.point_count
		):
			return false
		route.curve.remove_point(selection.point_index)
		_smooth_curve(route.curve)
		_session.track.start_point_index = mini(
			_session.track.start_point_index,
			route.curve.point_count - 1
		)
		_session.recalculate_route_dependents()
		return true
	var target := get_node(selection)
	if target == null or target.get_parent() == null:
		return false
	target.get_parent().remove_child(target)
	target.free()
	return true


func _move_route_point(index: int, track_position: Vector3) -> bool:
	var route := _session.track.get_main_route() as Path3D
	if (
		route == null
		or route.curve == null
		or index < 0
		or index >= route.curve.point_count
	):
		return false
	var route_position := route.transform.affine_inverse() * track_position
	route.curve.set_point_position(index, route_position)
	_smooth_curve(route.curve)
	return true


func _move_item(
	selection: RefCounted,
	track_position: Vector3
) -> bool:
	var marker := get_node(selection) as Marker3D
	if marker == null:
		return false
	var anchor: Dictionary = _session.get_route_anchor_for_position(track_position)
	if anchor.is_empty():
		return false
	_session.anchor_item_spawn(marker, float(anchor.progress))
	return true


func _move_prop(
	selection: RefCounted,
	track_position: Vector3
) -> bool:
	var prop := get_node(selection)
	if prop == null:
		return false
	var anchor: Dictionary = _session.get_route_anchor_for_position(track_position)
	if anchor.is_empty():
		return false
	_session.anchor_prop(
		prop,
		float(anchor.progress),
		float(anchor.lateral),
		float(anchor.height),
		prop.rotation_degrees.y
	)
	return true


func _move_shortcut_midpoint(
	selection: RefCounted,
	track_position: Vector3
) -> bool:
	var shortcut := get_node(selection) as TrackShortcut
	if (
		shortcut == null
		or shortcut.curve == null
		or shortcut.curve.point_count < 3
	):
		return false
	if not shortcut.route_anchor_enabled:
		_session.configure_shortcut_anchor(shortcut)
	var entry := shortcut.curve.get_point_position(0)
	var exit := shortcut.curve.get_point_position(shortcut.curve.point_count - 1)
	var direct := exit - entry
	var horizontal := Vector3(direct.x, 0.0, direct.z)
	if horizontal.length_squared() <= 0.0001:
		return false
	horizontal = horizontal.normalized()
	var lateral_axis := Vector3(-horizontal.z, 0.0, horizontal.x)
	var base := entry.lerp(exit, 0.5)
	var local_position := shortcut.transform.affine_inverse() * track_position
	var delta := local_position - base
	shortcut.midpoint_longitudinal_offset = delta.dot(horizontal)
	shortcut.midpoint_lateral_offset = delta.dot(lateral_axis)
	shortcut.midpoint_height_offset = delta.y
	_session.recalculate_route_dependents()
	return true


func _smooth_curve(curve: Curve3D) -> void:
	for point_index in curve.point_count:
		var previous := curve.get_point_position(
			(point_index - 1 + curve.point_count) % curve.point_count
		)
		var next := curve.get_point_position(
			(point_index + 1) % curve.point_count
		)
		var tangent := (next - previous) / 6.0
		curve.set_point_in(point_index, -tangent)
		curve.set_point_out(point_index, tangent)


func _unique_name(parent: Node, source_name: String) -> String:
	var base := source_name.trim_suffix("Copy") + "Copy"
	var candidate := base
	var suffix := 2
	while parent.has_node(NodePath(candidate)):
		candidate = "%s%d" % [base, suffix]
		suffix += 1
	return candidate
