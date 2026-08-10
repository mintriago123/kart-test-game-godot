@tool
class_name TrackEditorEntityService
extends RefCounted

const Selection := preload(
	"res://addons/track_editor/track_editor_selection.gd"
)
const META_PROP_BASE_SCALE := &"track_editor_prop_base_scale"
const META_PROP_SCALE_MULTIPLIER := &"track_editor_prop_scale_multiplier"
const META_ASSET_ID := &"track_editor_asset_id"
const ASSET_LIBRARY_PATH := "res://assets/track/track_asset_library.tres"
const MIN_PROP_SCALE_MULTIPLIER := 0.5
const MAX_PROP_SCALE_MULTIPLIER := 3.0
const MIN_SHORTCUT_PROGRESS_GAP := 0.001
const SHORTCUT_HANDLE_MIN := 0.0
const SHORTCUT_HANDLE_MAX := 100.0

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
		Selection.Kind.SHORTCUT_ENTRY, \
		Selection.Kind.SHORTCUT_EXIT, \
		Selection.Kind.SHORTCUT_MIDPOINT, \
		Selection.Kind.SHORTCUT_ENTRY_TANGENT, \
		Selection.Kind.SHORTCUT_EXIT_TANGENT, \
		Selection.Kind.SHORTCUT_MIDPOINT_IN_TANGENT, \
		Selection.Kind.SHORTCUT_MIDPOINT_OUT_TANGENT:
			return _move_shortcut_control(selection, track_position)
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
	rotation_degrees_y: float,
	scale_multiplier: float = NAN
) -> bool:
	var prop := get_node(selection)
	if (
		prop == null
		or not is_finite(progress)
		or not is_finite(lateral)
		or not is_finite(height)
		or not is_finite(rotation_degrees_y)
		or (not is_nan(scale_multiplier) and not is_finite(scale_multiplier))
	):
		return false
	if not is_nan(scale_multiplier):
		_apply_prop_scale(prop, scale_multiplier)
	_session.anchor_prop(
		prop,
		progress,
		lateral,
		height,
		rotation_degrees_y
	)
	return true


func update_prop_scale(
	selection: RefCounted,
	scale_multiplier: float
) -> bool:
	var prop := get_node(selection)
	if prop == null or not is_finite(scale_multiplier):
		return false
	_apply_prop_scale(prop, scale_multiplier)
	return true


func initialize_prop_scale(
	prop: Node3D,
	base_scale: Vector3,
	scale_multiplier: float
) -> bool:
	if (
		prop == null
		or not _is_valid_scale(base_scale)
		or not is_finite(scale_multiplier)
	):
		return false
	var clamped_multiplier := clampf(
		scale_multiplier,
		MIN_PROP_SCALE_MULTIPLIER,
		MAX_PROP_SCALE_MULTIPLIER
	)
	prop.set_meta(META_PROP_BASE_SCALE, base_scale)
	prop.set_meta(META_PROP_SCALE_MULTIPLIER, clamped_multiplier)
	prop.scale = base_scale * clamped_multiplier
	return true


func set_prop_asset_id(prop: Node3D, asset_id: StringName) -> void:
	if prop == null or asset_id.is_empty():
		return
	prop.set_meta(META_ASSET_ID, asset_id)


func get_prop_asset_entry(prop: Node3D) -> TrackAssetEntry:
	if prop == null:
		return null
	var library := load(ASSET_LIBRARY_PATH) as TrackAssetLibrary
	if library == null:
		return null
	if prop.has_meta(META_ASSET_ID):
		var metadata_id := StringName(prop.get_meta(META_ASSET_ID, &""))
		var metadata_entry := library.get_entry(metadata_id)
		if metadata_entry != null:
			return metadata_entry
	return library.get_entry_for_scene_path(prop.scene_file_path)


func restore_prop_recommended_scale(selection: RefCounted) -> bool:
	var prop := get_node(selection)
	var entry := get_prop_asset_entry(prop)
	if prop == null or entry == null:
		return false
	var scale_result := entry.resolve_base_scale()
	var recommended_scale: Vector3 = scale_result.scale
	if not _is_valid_scale(recommended_scale):
		return false
	set_prop_asset_id(prop, entry.id)
	return initialize_prop_scale(prop, recommended_scale, 1.0)


func calibrate_known_props() -> Dictionary:
	var result := {"affected": 0, "omitted": 0}
	if _session == null or _session.track == null:
		return result
	var props: Node = _session.track.get_node_or_null("Props")
	if props == null:
		return result
	for child in props.get_children():
		var prop := child as Node3D
		if prop == null:
			continue
		var entry := get_prop_asset_entry(prop)
		if entry == null:
			result.omitted += 1
			continue
		var scale_result := entry.resolve_base_scale()
		var recommended_scale: Vector3 = scale_result.scale
		if not _is_valid_scale(recommended_scale):
			result.omitted += 1
			continue
		set_prop_asset_id(prop, entry.id)
		initialize_prop_scale(prop, recommended_scale, 1.0)
		result.affected += 1
	return result


func _apply_prop_scale(prop: Node3D, scale_multiplier: float) -> void:
	var base_scale := prop.scale
	if prop.has_meta(META_PROP_BASE_SCALE):
		var saved_base_scale = prop.get_meta(META_PROP_BASE_SCALE)
		if (
			saved_base_scale is Vector3
			and _is_valid_scale(saved_base_scale as Vector3)
		):
			base_scale = saved_base_scale as Vector3
	var clamped_multiplier := clampf(
		scale_multiplier,
		MIN_PROP_SCALE_MULTIPLIER,
		MAX_PROP_SCALE_MULTIPLIER
	)
	prop.set_meta(META_PROP_BASE_SCALE, base_scale)
	prop.set_meta(META_PROP_SCALE_MULTIPLIER, clamped_multiplier)
	prop.scale = base_scale * clamped_multiplier


func _is_valid_scale(value: Vector3) -> bool:
	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
		and absf(value.x) > 0.000001
		and absf(value.y) > 0.000001
		and absf(value.z) > 0.000001
	)


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
	return fit_shortcut_shape(selection, {
		"midpoint_longitudinal": longitudinal,
		"midpoint_lateral": lateral,
		"midpoint_height": height,
	})


func fit_shortcut_shape(
	selection: RefCounted,
	requested_shape: Dictionary
) -> Dictionary:
	var shortcut := get_node(selection) as TrackShortcut
	if shortcut == null or not shortcut.route_anchor_enabled:
		return _fit_result(
			&"rejected",
			"No se pudo editar el atajo seleccionado.",
			shortcut
		)
	var original := _capture_shortcut_shape(shortcut)
	var requested := original.duplicate()
	var aliases := {
		"longitudinal": "midpoint_longitudinal",
		"lateral": "midpoint_lateral",
		"height": "midpoint_height",
		"entry_handle_length": "entry_handle",
		"exit_handle_length": "exit_handle",
		"midpoint_in_handle_length": "midpoint_in_handle",
		"midpoint_out_handle_length": "midpoint_out_handle",
	}
	for key in requested_shape:
		var normalized_key: Variant = aliases.get(key, key)
		if requested.has(normalized_key):
			requested[normalized_key] = requested_shape[key]
	var validation_message := _validate_shortcut_shape(requested)
	if not validation_message.is_empty():
		return _fit_result(&"rejected", validation_message, shortcut)
	if not _has_valid_shortcut_order(requested):
		return _fit_result(
			&"rejected",
			"La entrada debe quedar antes que la salida sin cruzar la meta.",
			shortcut
		)
	_apply_shortcut_shape(shortcut, requested)
	var requested_safety := TrackLevelValidator.get_shortcut_safety(
		_session.track,
		shortcut
	)
	if bool(requested_safety.safe):
		shortcut.set_meta(&"editor_safety_checked", true)
		return _fit_result(&"accepted", "Forma segura.", shortcut)

	var best_candidate := _find_safe_shape_between(
		shortcut,
		requested,
		original
	)
	if best_candidate.is_empty():
		_restore_shortcut_shape(shortcut, original)
		return _fit_result(
			&"rejected",
			String(requested_safety.message),
			shortcut
		)
	_apply_shortcut_shape(shortcut, best_candidate)
	shortcut.set_meta(&"editor_safety_checked", true)
	return _fit_result(
		&"adjusted",
		"Forma ajustada para mantener una salida segura.",
		shortcut
	)


func reset_shortcut_safe(selection: RefCounted) -> Dictionary:
	var shortcut := get_node(selection) as TrackShortcut
	if shortcut == null or not shortcut.route_anchor_enabled:
		return _fit_result(&"rejected", "No se pudo restablecer el atajo.", shortcut)
	var original := _capture_shortcut_shape(shortcut)
	var safety := TrackLevelValidator.get_shortcut_safety(_session.track, shortcut)
	if bool(safety.safe) and _has_valid_shortcut_order(original):
		return _fit_result(&"accepted", "El atajo ya tiene una forma segura.", shortcut)
	var candidate := _find_any_safe_shape(shortcut, original)
	if candidate.is_empty():
		_restore_shortcut_shape(shortcut, original)
		return _fit_result(
			&"rejected",
			"No existe una forma segura para esos anclajes.",
			shortcut
		)
	_apply_shortcut_shape(shortcut, candidate)
	shortcut.set_meta(&"editor_safety_checked", true)
	return _fit_result(&"adjusted", "Se restableció una forma segura.", shortcut)


func rename_shortcut(selection: RefCounted, display_name: String) -> bool:
	var shortcut := get_node(selection) as TrackShortcut
	var normalized_name := display_name.strip_edges()
	if shortcut == null or normalized_name.is_empty():
		return false
	shortcut.display_name = normalized_name
	return true


func _capture_shortcut_shape(shortcut: TrackShortcut) -> Dictionary:
	return {
		"entry_progress": shortcut.entry_progress,
		"exit_progress": shortcut.exit_progress,
		"midpoint_longitudinal": shortcut.midpoint_longitudinal_offset,
		"midpoint_lateral": shortcut.midpoint_lateral_offset,
		"midpoint_height": shortcut.midpoint_height_offset,
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
	shortcut.entry_progress = float(shape.entry_progress)
	shortcut.exit_progress = float(shape.exit_progress)
	shortcut.midpoint_longitudinal_offset = float(shape.midpoint_longitudinal)
	shortcut.midpoint_lateral_offset = float(shape.midpoint_lateral)
	shortcut.midpoint_height_offset = float(shape.midpoint_height)
	_session.recalculate_route_dependents()


func _apply_shortcut_shape(
	shortcut: TrackShortcut,
	shape: Dictionary
) -> void:
	shortcut.entry_progress = float(shape.entry_progress)
	shortcut.exit_progress = float(shape.exit_progress)
	shortcut.midpoint_longitudinal_offset = float(shape.midpoint_longitudinal)
	shortcut.midpoint_lateral_offset = float(shape.midpoint_lateral)
	shortcut.midpoint_height_offset = float(shape.midpoint_height)
	shortcut.entry_handle_length = float(shape.entry_handle)
	shortcut.exit_handle_length = float(shape.exit_handle)
	shortcut.midpoint_in_handle_length = float(shape.midpoint_in_handle)
	shortcut.midpoint_out_handle_length = float(shape.midpoint_out_handle)
	_session.recalculate_route_dependents()


func _validate_shortcut_shape(shape: Dictionary) -> String:
	for key in shape:
		if not shape[key] is float and not shape[key] is int:
			return "Todos los valores del atajo deben ser numéricos."
		if not is_finite(float(shape[key])):
			return "El atajo contiene un valor no finito."
	for progress_key in [&"entry_progress", &"exit_progress"]:
		var progress := float(shape[progress_key])
		if progress < 0.0 or progress > 1.0:
			return "Los progresos de entrada y salida deben estar entre 0 y 100 %."
	for handle_key in [
		&"entry_handle",
		&"exit_handle",
		&"midpoint_in_handle",
		&"midpoint_out_handle",
	]:
		var handle_length := float(shape[handle_key])
		if handle_length < SHORTCUT_HANDLE_MIN or handle_length > SHORTCUT_HANDLE_MAX:
			return "Las tangentes deben medir entre 0 y 100 m."
	return ""


func _has_valid_shortcut_order(shape: Dictionary) -> bool:
	var route := _session.track.get_main_route() as Path3D
	if route == null or route.curve == null:
		return false
	var start_progress: float = _session.get_route_progress_for_control_point(
		_session.track.start_point_index
	)
	var entry_from_start := fposmod(
		float(shape.entry_progress) - start_progress,
		1.0
	)
	var exit_from_start := fposmod(
		float(shape.exit_progress) - start_progress,
		1.0
	)
	return exit_from_start - entry_from_start >= MIN_SHORTCUT_PROGRESS_GAP


func _find_safe_shape_between(
	shortcut: TrackShortcut,
	requested: Dictionary,
	original: Dictionary
) -> Dictionary:
	var first_safe := -1.0
	var previous_weight := 0.0
	for step_index in range(1, 25):
		var weight := float(step_index) / 24.0
		var candidate := _interpolate_shortcut_shape(requested, original, weight)
		if not _has_valid_shortcut_order(candidate):
			previous_weight = weight
			continue
		_apply_shortcut_shape(shortcut, candidate)
		if bool(TrackLevelValidator.get_shortcut_safety(_session.track, shortcut).safe):
			first_safe = weight
			break
		previous_weight = weight
	if first_safe < 0.0:
		return {}
	var lower := previous_weight
	var upper := first_safe
	var best := _interpolate_shortcut_shape(requested, original, upper)
	for _iteration in 7:
		var weight := (lower + upper) * 0.5
		var candidate := _interpolate_shortcut_shape(requested, original, weight)
		_apply_shortcut_shape(shortcut, candidate)
		if bool(TrackLevelValidator.get_shortcut_safety(_session.track, shortcut).safe):
			upper = weight
			best = candidate
		else:
			lower = weight
	return best


func _interpolate_shortcut_shape(
	from_shape: Dictionary,
	to_shape: Dictionary,
	weight: float
) -> Dictionary:
	var result := {}
	for key in from_shape:
		result[key] = lerpf(float(from_shape[key]), float(to_shape[key]), weight)
	return result


func _find_any_safe_shape(
	shortcut: TrackShortcut,
	base_shape: Dictionary
) -> Dictionary:
	if not _has_valid_shortcut_order(base_shape):
		return {}
	var lateral_sign := signf(float(base_shape.midpoint_lateral))
	if is_zero_approx(lateral_sign):
		lateral_sign = 1.0
	for side_sign in [lateral_sign, -lateral_sign]:
		for lateral_distance in [8.0, 12.0, 18.0, 25.0, 34.0, 45.0, 60.0]:
			for longitudinal in [0.0, -4.0, 4.0, -8.0, 8.0]:
				for endpoint_handle in [8.0, 12.0, 18.0, 26.0, 36.0]:
					var candidate := base_shape.duplicate()
					candidate.midpoint_lateral = side_sign * lateral_distance
					candidate.midpoint_longitudinal = longitudinal
					candidate.entry_handle = endpoint_handle
					candidate.exit_handle = endpoint_handle
					candidate.midpoint_in_handle = clampf(endpoint_handle * 0.65, 6.0, 24.0)
					candidate.midpoint_out_handle = candidate.midpoint_in_handle
					_apply_shortcut_shape(shortcut, candidate)
					if bool(TrackLevelValidator.get_shortcut_safety(_session.track, shortcut).safe):
						return candidate
	return {}


func _fit_result(
	status: StringName,
	message: String,
	shortcut: TrackShortcut
) -> Dictionary:
	return {
		"status": status,
		"message": message,
		"entry_progress": shortcut.entry_progress if shortcut != null else 0.0,
		"exit_progress": shortcut.exit_progress if shortcut != null else 0.0,
		"longitudinal": (
			shortcut.midpoint_longitudinal_offset if shortcut != null else 0.0
		),
		"lateral": shortcut.midpoint_lateral_offset if shortcut != null else 0.0,
		"height": shortcut.midpoint_height_offset if shortcut != null else 0.0,
		"entry_handle": shortcut.entry_handle_length if shortcut != null else 0.0,
		"exit_handle": shortcut.exit_handle_length if shortcut != null else 0.0,
		"midpoint_in_handle": shortcut.midpoint_in_handle_length if shortcut != null else 0.0,
		"midpoint_out_handle": shortcut.midpoint_out_handle_length if shortcut != null else 0.0,
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


func _move_shortcut_control(
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
	var shape := _capture_shortcut_shape(shortcut)
	if selection.kind == Selection.Kind.SHORTCUT_ENTRY:
		var entry_anchor: Dictionary = _session.get_route_anchor_for_position(track_position)
		if entry_anchor.is_empty():
			return false
		shape.entry_progress = float(entry_anchor.progress)
		return _is_fit_success(fit_shortcut_shape(selection, shape))
	if selection.kind == Selection.Kind.SHORTCUT_EXIT:
		var exit_anchor: Dictionary = _session.get_route_anchor_for_position(track_position)
		if exit_anchor.is_empty():
			return false
		shape.exit_progress = float(exit_anchor.progress)
		return _is_fit_success(fit_shortcut_shape(selection, shape))
	if selection.kind in [
		Selection.Kind.SHORTCUT_ENTRY_TANGENT,
		Selection.Kind.SHORTCUT_EXIT_TANGENT,
		Selection.Kind.SHORTCUT_MIDPOINT_IN_TANGENT,
		Selection.Kind.SHORTCUT_MIDPOINT_OUT_TANGENT,
	]:
		return _move_shortcut_tangent(
			shortcut,
			selection,
			track_position,
			shape
		)
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
	shape.midpoint_longitudinal = delta.dot(horizontal)
	shape.midpoint_lateral = delta.dot(lateral_axis)
	shape.midpoint_height = delta.y
	return _is_fit_success(fit_shortcut_shape(selection, shape))


func _move_shortcut_tangent(
	shortcut: TrackShortcut,
	selection: RefCounted,
	track_position: Vector3,
	shape: Dictionary
) -> bool:
	var point_index := 0
	var tangent := shortcut.curve.get_point_out(0)
	var shape_key := &"entry_handle"
	match selection.kind:
		Selection.Kind.SHORTCUT_EXIT_TANGENT:
			point_index = shortcut.curve.point_count - 1
			tangent = shortcut.curve.get_point_in(point_index)
			shape_key = &"exit_handle"
		Selection.Kind.SHORTCUT_MIDPOINT_IN_TANGENT:
			point_index = shortcut.curve.point_count / 2
			tangent = shortcut.curve.get_point_in(point_index)
			shape_key = &"midpoint_in_handle"
		Selection.Kind.SHORTCUT_MIDPOINT_OUT_TANGENT:
			point_index = shortcut.curve.point_count / 2
			tangent = shortcut.curve.get_point_out(point_index)
			shape_key = &"midpoint_out_handle"
	if tangent.length_squared() <= 0.000001:
		return false
	var local_target := shortcut.transform.affine_inverse() * track_position
	var anchor := shortcut.curve.get_point_position(point_index)
	shape[shape_key] = clampf(
		(local_target - anchor).dot(tangent.normalized()),
		SHORTCUT_HANDLE_MIN,
		SHORTCUT_HANDLE_MAX
	)
	return _is_fit_success(fit_shortcut_shape(selection, shape))


func _is_fit_success(result: Dictionary) -> bool:
	return result.get("status", &"rejected") in [&"accepted", &"adjusted"]


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
