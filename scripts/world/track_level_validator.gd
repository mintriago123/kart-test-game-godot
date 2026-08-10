class_name TrackLevelValidator
extends RefCounted

const JunctionBuilder = preload("res://scripts/world/track_junction_builder.gd")


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
	var shortcut_entry_forward: Vector3 = (
		shortcut_points[2] - shortcut_points[0]
	)
	var shortcut_exit_forward: Vector3 = (
		shortcut_points[-1]
		- shortcut_points[shortcut_points.size() - 3]
	)
	route_entry_forward.y = 0.0
	route_exit_forward.y = 0.0
	shortcut_entry_forward.y = 0.0
	shortcut_exit_forward.y = 0.0
	if (
		route_entry_forward.normalized().dot(
			shortcut_entry_forward.normalized()
		) < 0.75
		or route_exit_forward.normalized().dot(
			shortcut_exit_forward.normalized()
		) < 0.75
	):
		errors.append(
			"%s entra o sale a contravía." % shortcut.display_name
		)
	return errors


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
