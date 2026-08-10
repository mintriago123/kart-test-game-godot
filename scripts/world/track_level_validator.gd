class_name TrackLevelValidator
extends RefCounted

const JunctionBuilder = preload("res://scripts/world/track_junction_builder.gd")
const SHORTCUT_ROUTE_CLEARANCE := (
	CoastalTrack.ROAD_WIDTH * 0.5
	+ CoastalTrack.SHORTCUT_WIDTH * 0.5
)
const SHORTCUT_MINIMUM_TURN_RADIUS := 8.0


static func inspect(track) -> Array[TrackValidationIssue]:
	var issues: Array[TrackValidationIssue] = []
	if track.track_id.is_empty():
		_append_issue(
			issues,
			&"track_id_missing",
			"La pista necesita un identificador.",
			NodePath(".")
		)
	if track.display_name.strip_edges().is_empty():
		_append_issue(
			issues,
			&"display_name_missing",
			"La pista necesita un nombre visible.",
			NodePath(".")
		)

	var main_route: Path3D = track.get_main_route()
	var validation_route: Array[Vector3] = []
	if main_route == null:
		_append_issue(
			issues,
			&"route_missing",
			"Falta el nodo MainRoute de tipo Path3D.",
			NodePath("MainRoute")
		)
	elif main_route.curve == null or main_route.curve.point_count < 4:
		_append_issue(
			issues,
			&"route_point_count",
			"MainRoute necesita al menos cuatro puntos.",
			NodePath("MainRoute")
		)
	elif not main_route.curve.closed:
		_append_issue(
			issues,
			&"route_not_closed",
			"MainRoute debe ser una curva cerrada.",
			NodePath("MainRoute")
		)
	elif main_route.curve.get_baked_length() < 120.0:
		_append_issue(
			issues,
			&"route_too_short",
			"La ruta principal debe medir al menos 120 metros.",
			NodePath("MainRoute")
		)
	else:
		if track.start_point_index >= main_route.curve.point_count:
			_append_issue(
				issues,
				&"start_point_invalid",
				"La salida apunta a un punto que ya no existe.",
				NodePath("MainRoute")
			)
		validation_route = track._apply_start_offset(
			track._sample_path(main_route, true)
		)

	var shortcut_ids: Dictionary = {}
	var shortcuts: Array[TrackShortcut] = track.get_shortcuts()
	for shortcut in shortcuts:
		var shortcut_path: NodePath = track.get_path_to(shortcut)
		var shortcut_transform: Transform3D = track._get_transform_relative_to_track(shortcut)
		var shortcut_position := shortcut_transform.origin
		if shortcut.curve != null and shortcut.curve.point_count > 0:
			shortcut_position = shortcut_transform * shortcut.curve.get_point_position(
				shortcut.curve.point_count / 2
			)
		if shortcut.display_name.strip_edges().is_empty():
			_append_issue(
				issues,
				&"shortcut_name_missing",
				"El atajo %d necesita un nombre." % shortcut.shortcut_id,
				shortcut_path,
				shortcut_position
			)
		if shortcut.shortcut_id in shortcut_ids:
			_append_issue(
				issues,
				&"shortcut_id_duplicate",
				(
					"El identificador de atajo %d está repetido."
					% shortcut.shortcut_id
				),
				shortcut_path,
				shortcut_position
			)
		shortcut_ids[shortcut.shortcut_id] = true
		if shortcut.curve == null or shortcut.curve.point_count < 3:
			_append_issue(
				issues,
				&"shortcut_point_count",
				"%s necesita al menos tres puntos."
				% shortcut.display_name,
				shortcut_path,
				shortcut_position
			)
		elif shortcut.curve.closed:
			_append_issue(
				issues,
				&"shortcut_not_open",
				"%s debe ser una curva abierta." % shortcut.display_name,
				shortcut_path,
				shortcut_position
			)
		elif not validation_route.is_empty():
			var shortcut_errors := validate_shortcut(
				track,
				shortcut,
				validation_route
			)
			for shortcut_error in shortcut_errors:
				var issue_code := &"shortcut_connection"
				if "meta" in shortcut_error or "sale antes" in shortcut_error:
					issue_code = &"shortcut_order"
				elif "contravía" in shortcut_error:
					issue_code = &"shortcut_direction"
				elif "se superpone" in shortcut_error:
					issue_code = &"shortcut_route_overlap"
				_append_issue(
					issues,
					issue_code,
					shortcut_error,
					shortcut_path,
					shortcut_position
				)
			if shortcut_errors.is_empty():
				_append_junction_warning(
					issues,
					track,
					shortcut,
					validation_route,
					shortcut_path,
					shortcut_position
				)

	var props: Node = track.get_node_or_null("Props")
	if props == null:
		_append_issue(
			issues,
			&"props_missing",
			"Falta el nodo Props.",
			NodePath("Props")
		)
	var item_spawns: Node = track.get_node_or_null("ItemSpawns")
	if item_spawns == null:
		_append_issue(
			issues,
			&"items_missing",
			"Falta el nodo ItemSpawns.",
			NodePath("ItemSpawns")
		)
	elif item_spawns.get_child_count() < 4:
		_append_issue(
			issues,
			&"item_count",
			"ItemSpawns necesita al menos cuatro marcadores.",
			NodePath("ItemSpawns")
		)
	elif not validation_route.is_empty():
		for child in item_spawns.get_children():
			var item_path: NodePath = track.get_path_to(child)
			if not child is Marker3D:
				_append_issue(
					issues,
					&"item_type",
					"%s debe ser Marker3D." % child.name,
					item_path,
					(
						track._get_transform_relative_to_track(child).origin
						if child is Node3D
						else Vector3.ZERO
					)
				)
				continue
			var marker_position: Vector3 = track._get_transform_relative_to_track(
				child as Node3D
			).origin
			if (
				_distance_to_route_points_2d(
					marker_position,
					validation_route
				) > CoastalTrack.ROAD_WIDTH * 0.5
			):
				_append_issue(
					issues,
					&"item_off_route",
					"%s está fuera de la carretera." % child.name,
					item_path,
					marker_position
				)
	return issues


static func validate_shortcut(
	track,
	shortcut: TrackShortcut,
	validation_route: Array[Vector3]
) -> PackedStringArray:
	var errors := PackedStringArray()
	var shortcut_points: Array[Vector3] = track._sample_path(
		shortcut,
		false
	)
	var entry_index := _find_closest_index_in_points(
		shortcut_points[0],
		validation_route
	)
	var exit_index := _find_closest_index_in_points(
		shortcut_points[-1],
		validation_route
	)
	if (
		_distance_to_route_points_2d(
			shortcut_points[0],
			validation_route
		) > 1.5
		or _distance_to_route_points_2d(
			shortcut_points[-1],
			validation_route
		) > 1.5
	):
		errors.append(
			"%s debe comenzar y terminar sobre MainRoute."
			% shortcut.display_name
		)
	if entry_index >= exit_index:
		errors.append(
			"%s cruza la línea de meta o sale antes de entrar."
			% shortcut.display_name
		)
		return errors
	if not shortcut_follows_route_direction(shortcut_points, validation_route):
		errors.append(
			"%s entra o sale a contravía." % shortcut.display_name
		)
	var corridor_clearance := get_shortcut_corridor_clearance(
		shortcut_points,
		validation_route
	)
	if (
		has_shortcut_route_crossing(shortcut_points, validation_route)
		or (
			corridor_clearance >= 0.0
			and corridor_clearance < SHORTCUT_ROUTE_CLEARANCE
		)
	):
		errors.append(
			"%s se superpone a MainRoute fuera de sus conexiones."
			% shortcut.display_name
		)
	return errors


static func shortcut_follows_route_direction(
	shortcut_points: Array[Vector3],
	validation_route: Array[Vector3]
) -> bool:
	if shortcut_points.size() < 3 or validation_route.size() < 3:
		return false
	var entry_index := _find_closest_index_in_points(
		shortcut_points[0],
		validation_route
	)
	var exit_index := _find_closest_index_in_points(
		shortcut_points[-1],
		validation_route
	)
	var route_entry_forward := (
		validation_route[(entry_index + 1) % validation_route.size()]
		- validation_route[
			(entry_index - 1 + validation_route.size())
			% validation_route.size()
		]
	)
	var route_exit_forward := (
		validation_route[(exit_index + 1) % validation_route.size()]
		- validation_route[
			(exit_index - 1 + validation_route.size())
			% validation_route.size()
		]
	)
	var shortcut_entry_forward := shortcut_points[2] - shortcut_points[0]
	var shortcut_exit_forward := (
		shortcut_points[-1] - shortcut_points[shortcut_points.size() - 3]
	)
	route_entry_forward.y = 0.0
	route_exit_forward.y = 0.0
	shortcut_entry_forward.y = 0.0
	shortcut_exit_forward.y = 0.0
	return (
		route_entry_forward.normalized().dot(
			shortcut_entry_forward.normalized()
		) >= 0.75
		and route_exit_forward.normalized().dot(
			shortcut_exit_forward.normalized()
		) >= 0.75
	)


static func has_shortcut_route_crossing(
	shortcut_points: Array[Vector3],
	validation_route: Array[Vector3]
) -> bool:
	if shortcut_points.size() < 3 or validation_route.size() < 3:
		return false
	var total_length := 0.0
	for point_index in range(1, shortcut_points.size()):
		total_length += shortcut_points[point_index - 1].distance_to(
			shortcut_points[point_index]
		)
	var progress := 0.0
	for point_index in range(1, shortcut_points.size()):
		var shortcut_start := shortcut_points[point_index - 1]
		var shortcut_finish := shortcut_points[point_index]
		var segment_length := shortcut_start.distance_to(shortcut_finish)
		var segment_middle := progress + segment_length * 0.5
		progress += segment_length
		if (
			segment_middle < SHORTCUT_ROUTE_CLEARANCE
			or total_length - segment_middle < SHORTCUT_ROUTE_CLEARANCE
		):
			continue
		var shortcut_start_2d := Vector2(shortcut_start.x, shortcut_start.z)
		var shortcut_finish_2d := Vector2(shortcut_finish.x, shortcut_finish.z)
		for route_index in validation_route.size():
			var route_start := validation_route[route_index]
			var route_finish := validation_route[
				(route_index + 1) % validation_route.size()
			]
			if Geometry2D.segment_intersects_segment(
				shortcut_start_2d,
				shortcut_finish_2d,
				Vector2(route_start.x, route_start.z),
				Vector2(route_finish.x, route_finish.z)
			) != null:
				return true
	return false


static func get_shortcut_corridor_clearance(
	shortcut_points: Array[Vector3],
	validation_route: Array[Vector3]
) -> float:
	if shortcut_points.size() < 3 or validation_route.size() < 3:
		return -1.0
	var builder := JunctionBuilder.new(
		validation_route,
		CoastalTrack.ROAD_WIDTH,
		CoastalTrack.SHORTCUT_WIDTH
	)
	var entry_junction := builder.build(shortcut_points, true)
	var exit_junction := builder.build(shortcut_points, false)
	if not entry_junction.is_valid or not exit_junction.is_valid:
		return -1.0
	var first_index: int = entry_junction.shortcut_transition_index
	var final_index: int = exit_junction.shortcut_transition_index
	if first_index < 0 or final_index < first_index:
		return -1.0
	var minimum_clearance := INF
	for point_index in range(first_index, final_index + 1):
		minimum_clearance = minf(
			minimum_clearance,
			_distance_to_route_points_2d(
				shortcut_points[point_index],
				validation_route
			)
		)
	return minimum_clearance


static func get_shortcut_minimum_turn_radius(
	shortcut_points: Array[Vector3],
	validation_route: Array[Vector3] = []
) -> float:
	if shortcut_points.size() < 5:
		return 0.0
	var first_index := 0
	var final_index := shortcut_points.size() - 1
	if validation_route.size() >= 3:
		var builder := JunctionBuilder.new(
			validation_route,
			CoastalTrack.ROAD_WIDTH,
			CoastalTrack.SHORTCUT_WIDTH
		)
		var entry_junction := builder.build(shortcut_points, true)
		var exit_junction := builder.build(shortcut_points, false)
		if entry_junction.is_valid and exit_junction.is_valid:
			first_index = entry_junction.shortcut_transition_index
			final_index = exit_junction.shortcut_transition_index
	var sample_stride := maxi(1, shortcut_points.size() / 24)
	var minimum_radius := INF
	for point_index in range(
		first_index + sample_stride,
		final_index - sample_stride + 1,
		sample_stride
	):
		var first := Vector2(
			shortcut_points[point_index - sample_stride].x,
			shortcut_points[point_index - sample_stride].z
		)
		var middle := Vector2(
			shortcut_points[point_index].x,
			shortcut_points[point_index].z
		)
		var final := Vector2(
			shortcut_points[point_index + sample_stride].x,
			shortcut_points[point_index + sample_stride].z
		)
		var first_length := first.distance_to(middle)
		var second_length := middle.distance_to(final)
		var chord_length := first.distance_to(final)
		var doubled_area := absf((middle - first).cross(final - first))
		if (
			first_length <= 0.001
			or second_length <= 0.001
			or chord_length <= 0.001
			or doubled_area <= 0.0001
		):
			continue
		minimum_radius = minf(
			minimum_radius,
			first_length * second_length * chord_length
			/ (2.0 * doubled_area)
		)
	return minimum_radius


static func get_shortcut_safety(
	track,
	shortcut: TrackShortcut
) -> Dictionary:
	var result := {
		"safe": false,
		"code": &"shortcut_geometry_unsafe",
		"message": "La forma del atajo no es segura.",
		"turn_radius": 0.0,
		"clearance": -1.0,
	}
	if track == null or shortcut == null or shortcut.curve == null:
		return result
	var main_route: Path3D = track.get_main_route()
	if main_route == null or main_route.curve == null:
		return result
	var shortcut_points: Array[Vector3] = track._sample_path(shortcut, false)
	var validation_route: Array[Vector3] = track._apply_start_offset(
		track._sample_path(main_route, true)
	)
	if shortcut_points.size() < 3 or validation_route.size() < 3:
		return result
	result.turn_radius = get_shortcut_minimum_turn_radius(
		shortcut_points,
		validation_route
	)
	result.clearance = get_shortcut_corridor_clearance(
		shortcut_points,
		validation_route
	)
	if float(result.turn_radius) < SHORTCUT_MINIMUM_TURN_RADIUS:
		result.code = &"shortcut_turn_too_tight"
		result.message = "%s tiene una curva demasiado cerrada." % shortcut.display_name
		return result
	if (
		float(result.clearance) < SHORTCUT_ROUTE_CLEARANCE
		or has_shortcut_route_crossing(shortcut_points, validation_route)
	):
		result.code = &"shortcut_corridor_too_narrow"
		result.message = "%s no conserva separación suficiente de la carretera." % shortcut.display_name
		return result
	var junction_builder := JunctionBuilder.new(
		validation_route,
		CoastalTrack.ROAD_WIDTH,
		CoastalTrack.SHORTCUT_WIDTH
	)
	var entry_junction := junction_builder.build(shortcut_points, true)
	var exit_junction := junction_builder.build(shortcut_points, false)
	if not entry_junction.is_valid or not exit_junction.is_valid:
		result.code = &"shortcut_junction_unsafe"
		result.message = "%s no permite una entrada y salida seguras." % shortcut.display_name
		return result
	var first_index: int = entry_junction.shortcut_transition_index
	var final_index: int = exit_junction.shortcut_transition_index
	if first_index < 0 or final_index < first_index:
		return result
	var center_section: Array[Vector3] = []
	for point_index in range(first_index, final_index + 1):
		center_section.append(shortcut_points[point_index])
	var barrier_offset := (
		CoastalTrack.SHORTCUT_WIDTH * 0.5
		+ TrackBarrierBuilder.SHORTCUT_BARRIER_SHOULDER
	)
	for lateral_offset in [-barrier_offset, barrier_offset]:
		var barrier_chain := TrackBarrierBuilder.build_open_offset_chain(
			center_section,
			lateral_offset
		)
		if not TrackBarrierBuilder.is_open_chain_safe(barrier_chain):
			result.code = &"shortcut_barrier_self_intersection"
			result.message = "%s doblaría una barrera sobre sí misma." % shortcut.display_name
			return result
	result.safe = true
	result.code = &""
	result.message = "Forma segura."
	return result


static func _append_issue(
	issues: Array[TrackValidationIssue],
	code: StringName,
	message: String,
	target_path: NodePath,
	world_position := Vector3.ZERO
) -> void:
	for issue in issues:
		if issue.code == code and issue.target_path == target_path:
			return
	issues.append(
		TrackValidationIssue.create(
			code,
			message,
			TrackValidationIssue.Severity.ERROR,
			target_path,
			world_position
		)
	)


static func _append_junction_warning(
	issues: Array[TrackValidationIssue],
	track,
	shortcut: TrackShortcut,
	validation_route: Array[Vector3],
	shortcut_path: NodePath,
	shortcut_position: Vector3
) -> void:
	var shortcut_points: Array[Vector3] = track._sample_path(shortcut, false)
	var builder := JunctionBuilder.new(
		validation_route,
		CoastalTrack.ROAD_WIDTH,
		CoastalTrack.SHORTCUT_WIDTH
	)
	var fallback_labels := PackedStringArray()
	var warning_position := shortcut_position
	for junction_data in [
		[builder.build(shortcut_points, true), "entrada"],
		[builder.build(shortcut_points, false), "salida"],
	]:
		var junction = junction_data[0]
		if junction.is_valid:
			continue
		fallback_labels.append(
			"%s (%s)" % [junction_data[1], junction.fallback_reason]
		)
		if not junction.world_position.is_zero_approx():
			warning_position = junction.world_position
	if fallback_labels.is_empty():
		return
	issues.append(
		TrackValidationIssue.create(
			&"shortcut_junction_fallback",
			"%s usará una unión recta en %s."
			% [shortcut.display_name, " y ".join(fallback_labels)],
			TrackValidationIssue.Severity.WARNING,
			shortcut_path,
			warning_position
		)
	)


static func _distance_to_route_points_2d(
	point: Vector3,
	points: Array[Vector3]
) -> float:
	var flattened_point := Vector2(point.x, point.z)
	var minimum_distance := INF
	for point_index in points.size():
		var next_index := (point_index + 1) % points.size()
		minimum_distance = minf(
			minimum_distance,
			_point_to_segment_distance_2d(
				flattened_point,
				Vector2(points[point_index].x, points[point_index].z),
				Vector2(points[next_index].x, points[next_index].z)
			)
		)
	return minimum_distance


static func _find_closest_index_in_points(
	point: Vector3,
	points: Array[Vector3]
) -> int:
	var closest_index := 0
	var closest_distance := INF
	for point_index in points.size():
		var distance := point.distance_squared_to(points[point_index])
		if distance < closest_distance:
			closest_distance = distance
			closest_index = point_index
	return closest_index


static func _point_to_segment_distance_2d(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(segment_start)
	var weight := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return point.distance_to(segment_start + segment * weight)
