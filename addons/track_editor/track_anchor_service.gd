@tool
class_name TrackAnchorService
extends RefCounted

const META_ANCHOR_PROGRESS := &"track_editor_anchor_progress"
const META_ANCHOR_LATERAL := &"track_editor_anchor_lateral"
const META_ANCHOR_HEIGHT := &"track_editor_anchor_height"
const META_ANCHOR_ROTATION := &"track_editor_anchor_rotation"

var _session_ref: WeakRef
var _session: RefCounted:
	get:
		return _session_ref.get_ref()


func _init(session: RefCounted) -> void:
	_session_ref = weakref(session)


func recalculate_route_dependents() -> void:
	var route := _get_usable_route()
	if route == null:
		return
	for shortcut in _session.track.get_shortcuts():
		if not shortcut.route_anchor_enabled:
			continue
		var entry_sample := _sample_route_in_node(
			shortcut.entry_progress,
			shortcut
		)
		var exit_sample := _sample_route_in_node(
			shortcut.exit_progress,
			shortcut
		)
		shortcut.rebuild_from_route(
			entry_sample.position,
			entry_sample.forward,
			exit_sample.position,
			exit_sample.forward
		)
	var item_spawns: Node = _session.track.get_node_or_null("ItemSpawns")
	if item_spawns != null:
		for child in item_spawns.get_children():
			if child is Marker3D and child.has_meta(META_ANCHOR_PROGRESS):
				_reposition_anchored_node(child as Node3D, false)
	var props: Node = _session.track.get_node_or_null("Props")
	if props != null:
		for child in props.get_children():
			if child is Node3D and child.has_meta(META_ANCHOR_PROGRESS):
				_reposition_anchored_node(child as Node3D, true)


func configure_shortcut_anchor(shortcut: TrackShortcut) -> bool:
	var route := _get_usable_route()
	if shortcut == null or route == null or shortcut.curve == null:
		return false
	if shortcut.curve.point_count < 3:
		return false
	var final_index := shortcut.curve.point_count - 1
	var entry_point := _node_point_to_route_local(
		shortcut,
		shortcut.curve.get_point_position(0)
	)
	var exit_point := _node_point_to_route_local(
		shortcut,
		shortcut.curve.get_point_position(final_index)
	)
	var route_length := route.curve.get_baked_length()
	if route_length <= 0.001:
		return false
	shortcut.entry_progress = (
		route.curve.get_closest_offset(entry_point) / route_length
	)
	shortcut.exit_progress = (
		route.curve.get_closest_offset(exit_point) / route_length
	)

	var entry_sample := _sample_route_in_node(
		shortcut.entry_progress,
		shortcut
	)
	var exit_sample := _sample_route_in_node(
		shortcut.exit_progress,
		shortcut
	)
	var midpoint := shortcut.curve.get_point_position(
		shortcut.curve.point_count / 2
	)
	var entry_position: Vector3 = entry_sample.position
	var exit_position: Vector3 = exit_sample.position
	var direct := exit_position - entry_position
	var horizontal_direct := Vector3(direct.x, 0.0, direct.z)
	if horizontal_direct.length_squared() <= 0.0001:
		return false
	horizontal_direct = horizontal_direct.normalized()
	var lateral := Vector3(-horizontal_direct.z, 0.0, horizontal_direct.x)
	var midpoint_base := entry_position.lerp(exit_position, 0.5)
	var midpoint_delta := midpoint - midpoint_base
	shortcut.midpoint_longitudinal_offset = midpoint_delta.dot(
		horizontal_direct
	)
	shortcut.midpoint_lateral_offset = midpoint_delta.dot(lateral)
	shortcut.midpoint_height_offset = midpoint_delta.y
	shortcut.entry_handle_length = shortcut.curve.get_point_out(0).length()
	shortcut.exit_handle_length = shortcut.curve.get_point_in(
		final_index
	).length()
	var middle_index := shortcut.curve.point_count / 2
	shortcut.midpoint_in_handle_length = shortcut.curve.get_point_in(
		middle_index
	).length()
	shortcut.midpoint_out_handle_length = shortcut.curve.get_point_out(
		middle_index
	).length()
	shortcut.route_anchor_enabled = true
	return shortcut.rebuild_from_route(
		entry_position,
		entry_sample.forward,
		exit_position,
		exit_sample.forward
	)


func anchor_item_spawn(marker: Marker3D, progress: float) -> void:
	if marker == null:
		return
	set_route_anchor_metadata(marker, progress, 0.0, 0.0, 0.0)
	_reposition_anchored_node(marker, false)


func anchor_prop(
	prop: Node3D,
	progress: float,
	lateral_offset: float,
	height_offset: float,
	rotation_degrees_y: float
) -> void:
	if prop == null:
		return
	set_route_anchor_metadata(
		prop,
		progress,
		lateral_offset,
		height_offset,
		rotation_degrees_y
	)
	_reposition_anchored_node(prop, true)


func get_route_progress_for_control_point(point_index: int) -> float:
	var route := _get_usable_route()
	if (
		route == null
		or point_index < 0
		or point_index >= route.curve.point_count
	):
		return 0.0
	var route_length := route.curve.get_baked_length()
	if route_length <= 0.001:
		return 0.0
	return (
		route.curve.get_closest_offset(
			route.curve.get_point_position(point_index)
		)
		/ route_length
	)


func get_route_anchor_for_position(track_position: Vector3) -> Dictionary:
	var route := _get_usable_route()
	if route == null:
		return {}
	var route_length := route.curve.get_baked_length()
	var route_position := route.transform.affine_inverse() * track_position
	var offset := route.curve.get_closest_offset(route_position)
	var progress := offset / route_length
	var sample := _sample_route_in_node(progress, _session.track)
	var forward: Vector3 = sample.forward
	var lateral_axis := Vector3(-forward.z, 0.0, forward.x)
	if lateral_axis.length_squared() <= 0.0001:
		lateral_axis = Vector3.RIGHT
	else:
		lateral_axis = lateral_axis.normalized()
	var delta := track_position - (sample.position as Vector3)
	return {
		"progress": progress,
		"lateral": delta.dot(lateral_axis),
		"height": delta.y,
	}


func migrate_legacy_anchors() -> Dictionary:
	var counts := {"shortcuts": 0, "items": 0}
	var route := _get_usable_route()
	if route == null:
		return counts
	var shortcuts_to_repair: Array[TrackShortcut] = []
	for shortcut in _session.track.get_shortcuts():
		if (
			not shortcut.route_anchor_enabled
			and shortcut.curve != null
			and shortcut.curve.point_count >= 3
		):
			shortcuts_to_repair.append(shortcut)
	var items_to_repair: Array[Marker3D] = []
	var item_spawns: Node = _session.track.get_node_or_null("ItemSpawns")
	if item_spawns != null:
		for child in item_spawns.get_children():
			if (
				child is Marker3D
				and not child.has_meta(META_ANCHOR_PROGRESS)
			):
				items_to_repair.append(child as Marker3D)
	if shortcuts_to_repair.is_empty() and items_to_repair.is_empty():
		return counts

	_session.snapshot_track_for_undo()
	for shortcut in shortcuts_to_repair:
		if configure_shortcut_anchor(shortcut):
			counts.shortcuts += 1
	for marker in items_to_repair:
		var route_point := _node_point_to_route_local(marker, Vector3.ZERO)
		var route_length := route.curve.get_baked_length()
		var progress := (
			route.curve.get_closest_offset(route_point) / route_length
		)
		anchor_item_spawn(marker, progress)
		counts.items += 1
	return counts


func set_route_anchor_metadata(
	node: Node3D,
	progress: float,
	lateral_offset: float,
	height_offset: float,
	rotation_degrees_y: float
) -> void:
	node.set_meta(META_ANCHOR_PROGRESS, wrapf(progress, 0.0, 1.0))
	node.set_meta(META_ANCHOR_LATERAL, lateral_offset)
	node.set_meta(META_ANCHOR_HEIGHT, height_offset)
	node.set_meta(META_ANCHOR_ROTATION, rotation_degrees_y)


func _reposition_anchored_node(
	node: Node3D,
	restore_rotation: bool
) -> void:
	if not node.has_meta(META_ANCHOR_PROGRESS):
		return
	var parent := node.get_parent() as Node3D
	if parent == null:
		return
	var sample := _sample_route_in_node(
		float(node.get_meta(META_ANCHOR_PROGRESS)),
		parent
	)
	var forward: Vector3 = sample.forward
	var lateral := Vector3(-forward.z, 0.0, forward.x)
	if lateral.length_squared() <= 0.0001:
		lateral = Vector3.RIGHT
	else:
		lateral = lateral.normalized()
	node.position = (
		sample.position
		+ lateral * float(node.get_meta(META_ANCHOR_LATERAL, 0.0))
		+ Vector3.UP * float(node.get_meta(META_ANCHOR_HEIGHT, 0.0))
	)
	if restore_rotation:
		node.rotation_degrees.y = float(
			node.get_meta(META_ANCHOR_ROTATION, 0.0)
		)


func _sample_route_in_node(
	progress: float,
	target_node: Node3D
) -> Dictionary:
	var route := _get_usable_route()
	if route == null or target_node == null:
		return {"position": Vector3.ZERO, "forward": Vector3.FORWARD}
	var route_length := route.curve.get_baked_length()
	var normalized_progress := wrapf(progress, 0.0, 1.0)
	var sample_offset := normalized_progress * route_length
	var epsilon := minf(maxf(route_length * 0.002, 0.05), 0.5)
	var previous_offset := fposmod(sample_offset - epsilon, route_length)
	var next_offset := fposmod(sample_offset + epsilon, route_length)
	var route_position := route.curve.sample_baked(sample_offset, true)
	var previous_position := route.curve.sample_baked(previous_offset, true)
	var next_position := route.curve.sample_baked(next_offset, true)
	var route_to_track := _get_transform_relative_to_track(route)
	var track_to_target := _get_transform_relative_to_track(
		target_node
	).affine_inverse()
	var target_position := track_to_target * (route_to_track * route_position)
	var target_previous := (
		track_to_target * (route_to_track * previous_position)
	)
	var target_next := track_to_target * (route_to_track * next_position)
	var forward := target_next - target_previous
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	return {"position": target_position, "forward": forward}


func _node_point_to_route_local(
	node: Node3D,
	point: Vector3
) -> Vector3:
	var route := _get_usable_route()
	if route == null:
		return Vector3.ZERO
	var point_in_track := _get_transform_relative_to_track(node) * point
	return (
		_get_transform_relative_to_track(route).affine_inverse()
		* point_in_track
	)


func _get_transform_relative_to_track(node: Node3D) -> Transform3D:
	var relative_transform := Transform3D.IDENTITY
	var current_node := node
	while current_node != null and current_node != _session.track:
		relative_transform = current_node.transform * relative_transform
		current_node = current_node.get_parent() as Node3D
	return relative_transform


func _get_usable_route() -> Path3D:
	var route: Path3D = (
		_session.track.get_main_route()
		if _session.track != null
		else null
	)
	if (
		route == null
		or route.curve == null
		or route.curve.point_count < 2
		or route.curve.get_baked_length() <= 0.001
	):
		return null
	return route
